import { Router, Request, Response } from 'express';
import { SignJWT, importPKCS8 } from 'jose';
import { supabaseAdmin } from '../../services/supabase';
import { authMiddleware } from '../middleware/auth';

const router = Router();
router.use(authMiddleware);

const PRODUCT_IDS = [
  'com.deepdivedevotions.monthly',
  'com.deepdivedevotions.annual',
];

// App Store Server API environments
const APP_STORE_PROD_URL = 'https://api.storekit.itunes.apple.com';
const APP_STORE_SANDBOX_URL = 'https://api.storekit-sandbox.itunes.apple.com';

/** Generate a JWT for App Store Server API requests */
async function generateAppStoreJWT(): Promise<string> {
  const keyId = process.env.APP_STORE_KEY_ID!;
  const issuerId = process.env.APP_STORE_ISSUER_ID!;
  const bundleId = process.env.APP_BUNDLE_ID || 'com.deepdivedevotions';
  const privateKeyBase64 = process.env.APP_STORE_PRIVATE_KEY_BASE64!;

  if (!keyId || !issuerId || !privateKeyBase64) {
    throw new Error('Missing App Store Server API credentials');
  }

  const privateKeyPem = Buffer.from(privateKeyBase64, 'base64').toString('utf-8');
  const privateKey = await importPKCS8(privateKeyPem, 'ES256');

  return new SignJWT({
    bid: bundleId,
  })
    .setProtectedHeader({ alg: 'ES256', kid: keyId, typ: 'JWT' })
    .setIssuer(issuerId)
    .setIssuedAt()
    .setExpirationTime('1h')
    .setAudience('appstoreconnect-v1')
    .sign(privateKey);
}

interface VerificationResult {
  valid: boolean;
  productId: string | null;
  expiresDate: Date | null;
  transactionId: string | null;
  environment: string;
}

/** Verify a JWS transaction with Apple's App Store Server API */
async function verifyTransaction(jwsTransaction: string): Promise<VerificationResult> {
  const jwt = await generateAppStoreJWT();
  const isProd = process.env.NODE_ENV === 'production';
  const baseUrl = isProd ? APP_STORE_PROD_URL : APP_STORE_SANDBOX_URL;

  // Decode JWS payload to get transaction ID (for the API call)
  const [, payloadB64] = jwsTransaction.split('.');
  const payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf-8'));
  const transactionId = payload.transactionId as string;

  const url = `${baseUrl}/inApps/v1/transactions/${transactionId}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${jwt}` },
  });

  if (!response.ok) {
    // Try sandbox if prod fails (handles sandbox receipts submitted to prod)
    if (isProd && response.status === 404) {
      const sandboxResponse = await fetch(
        `${APP_STORE_SANDBOX_URL}/inApps/v1/transactions/${transactionId}`,
        { headers: { Authorization: `Bearer ${jwt}` } }
      );
      if (!sandboxResponse.ok) {
        throw new Error(`App Store API error: ${sandboxResponse.status}`);
      }
      const sandboxData = await sandboxResponse.json() as { signedTransactionInfo: string };
      return decodeTransactionInfo(sandboxData.signedTransactionInfo, 'Sandbox');
    }
    throw new Error(`App Store API error: ${response.status} ${await response.text()}`);
  }

  const data = await response.json() as { signedTransactionInfo: string };
  return decodeTransactionInfo(data.signedTransactionInfo, isProd ? 'Production' : 'Sandbox');
}

function decodeTransactionInfo(signedInfo: string, environment: string): VerificationResult {
  const [, payloadB64] = signedInfo.split('.');
  const payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf-8'));

  const revocationDate = payload.revocationDate;
  if (revocationDate) {
    return { valid: false, productId: null, expiresDate: null, transactionId: null, environment };
  }

  const expiresDateMs = payload.expiresDate as number | undefined;
  const expiresDate = expiresDateMs ? new Date(expiresDateMs) : null;

  const expired = expiresDate ? expiresDate < new Date() : false;

  return {
    valid: !expired,
    productId: payload.productId as string,
    expiresDate,
    transactionId: payload.transactionId as string,
    environment,
  };
}

/** Update user subscription status in Supabase */
async function updateUserSubscription(
  userId: string,
  result: VerificationResult
): Promise<void> {
  const status = result.valid ? 'active' : 'expired';
  await supabaseAdmin
    .from('users')
    .update({
      subscription_status: status,
      subscription_expiry: result.expiresDate?.toISOString() ?? null,
      subscription_product: result.productId ?? null,
    })
    .eq('id', userId);
}

// POST /subscriptions/validate
router.post('/validate', async (req: Request, res: Response): Promise<void> => {
  try {
    const { jws_transaction, product_id } = req.body;

    if (!jws_transaction) {
      res.status(400).json({ error: 'jws_transaction is required' });
      return;
    }

    if (product_id && !PRODUCT_IDS.includes(product_id)) {
      res.status(400).json({ error: 'Invalid product_id' });
      return;
    }

    const result = await verifyTransaction(jws_transaction);
    await updateUserSubscription(req.userId!, result);

    // Fetch updated user record
    const { data: user } = await supabaseAdmin
      .from('users')
      .select('subscription_status, subscription_expiry, subscription_product')
      .eq('id', req.userId!)
      .single();

    res.json({
      valid: result.valid,
      subscription_status: user?.subscription_status ?? 'none',
      subscription_expiry: user?.subscription_expiry ?? null,
      subscription_product: user?.subscription_product ?? null,
    });
  } catch (err) {
    console.error('Subscription validation error:', err);
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /subscriptions/restore
router.post('/restore', async (req: Request, res: Response): Promise<void> => {
  try {
    const { transactions } = req.body as { transactions: Array<{ jws_transaction: string }> };

    if (!transactions || !Array.isArray(transactions) || transactions.length === 0) {
      res.status(400).json({ error: 'transactions array is required' });
      return;
    }

    // Verify all transactions and find the most recent active one
    const results: VerificationResult[] = [];
    for (const tx of transactions) {
      try {
        const result = await verifyTransaction(tx.jws_transaction);
        if (result.valid) results.push(result);
      } catch {
        // Skip invalid transactions
      }
    }

    // Pick the latest expiry date among valid transactions
    const bestResult = results
      .filter(r => r.valid && r.expiresDate)
      .sort((a, b) => (b.expiresDate?.getTime() ?? 0) - (a.expiresDate?.getTime() ?? 0))[0];

    if (bestResult) {
      await updateUserSubscription(req.userId!, bestResult);
    } else {
      await updateUserSubscription(req.userId!, {
        valid: false, productId: null, expiresDate: null, transactionId: null, environment: 'unknown',
      });
    }

    const { data: user } = await supabaseAdmin
      .from('users')
      .select('subscription_status, subscription_expiry, subscription_product')
      .eq('id', req.userId!)
      .single();

    res.json({
      restored: !!bestResult,
      subscription_status: user?.subscription_status ?? 'none',
      subscription_expiry: user?.subscription_expiry ?? null,
      subscription_product: user?.subscription_product ?? null,
    });
  } catch (err) {
    console.error('Restore purchases error:', err);
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /subscriptions/status
router.get('/status', async (req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .select('subscription_status, subscription_expiry, subscription_product')
      .eq('id', req.userId!)
      .single();

    if (error || !data) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Auto-expire if past expiry date
    let status = data.subscription_status;
    if (status === 'active' && data.subscription_expiry && new Date(data.subscription_expiry) < new Date()) {
      status = 'expired';
      await supabaseAdmin
        .from('users')
        .update({ subscription_status: 'expired' })
        .eq('id', req.userId!);
    }

    res.json({
      subscription_status: status,
      subscription_expiry: data.subscription_expiry,
      subscription_product: data.subscription_product,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
