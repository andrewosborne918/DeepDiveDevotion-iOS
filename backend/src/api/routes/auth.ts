import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../../services/supabase';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// POST /auth/apple — Apple Sign In
router.post('/apple', async (req: Request, res: Response): Promise<void> => {
  try {
    const { identity_token, authorization_code, full_name } = req.body;

    if (!identity_token) {
      res.status(400).json({ error: 'identity_token is required' });
      return;
    }

    // Sign in with Supabase using Apple ID token
    const { data, error } = await supabaseAdmin.auth.signInWithIdToken({
      provider: 'apple',
      token: identity_token,
      nonce: req.body.nonce, // Pass through if provided
    } as Parameters<typeof supabaseAdmin.auth.signInWithIdToken>[0]);

    if (error || !data.session || !data.user) {
      res.status(401).json({ error: error?.message || 'Apple sign in failed' });
      return;
    }

    // Upsert user record with display name if provided
    const displayName = full_name
      ? `${full_name.given_name || ''} ${full_name.family_name || ''}`.trim()
      : null;

    await supabaseAdmin
      .from('users')
      .upsert({
        id: data.user.id,
        email: data.user.email,
        apple_user_id: data.user.user_metadata?.sub,
        display_name: displayName || undefined,
      }, { onConflict: 'id', ignoreDuplicates: false });

    res.json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_in: data.session.expires_in,
      user: {
        id: data.user.id,
        email: data.user.email,
        display_name: displayName,
      },
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /auth/register — Email/password registration
router.post('/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password, display_name } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'email and password are required' });
      return;
    }

    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Auto-confirm for now; set to false to require email verification
    });

    if (error || !data.user) {
      res.status(400).json({ error: error?.message || 'Registration failed' });
      return;
    }

    // Update display name if provided
    if (display_name) {
      await supabaseAdmin
        .from('users')
        .update({ display_name })
        .eq('id', data.user.id);
    }

    // Sign in immediately to return a session
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError || !signInData.session) {
      res.status(500).json({ error: 'Account created but could not sign in automatically' });
      return;
    }

    res.status(201).json({
      access_token: signInData.session.access_token,
      refresh_token: signInData.session.refresh_token,
      expires_in: signInData.session.expires_in,
      user: {
        id: data.user.id,
        email: data.user.email,
        display_name: display_name ?? null,
      },
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /auth/login — Email/password sign in
router.post('/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'email and password are required' });
      return;
    }

    const { data, error } = await supabaseAdmin.auth.signInWithPassword({ email, password });

    if (error || !data.session) {
      res.status(401).json({ error: error?.message || 'Invalid credentials' });
      return;
    }

    // Fetch user record
    const { data: userRecord } = await supabaseAdmin
      .from('users')
      .select('display_name, subscription_status')
      .eq('id', data.user.id)
      .single();

    res.json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_in: data.session.expires_in,
      user: {
        id: data.user.id,
        email: data.user.email,
        display_name: userRecord?.display_name ?? null,
        subscription_status: userRecord?.subscription_status ?? 'none',
      },
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req: Request, res: Response): Promise<void> => {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      res.status(400).json({ error: 'refresh_token is required' });
      return;
    }

    const { data, error } = await supabaseAdmin.auth.refreshSession({ refresh_token });

    if (error || !data.session) {
      res.status(401).json({ error: error?.message || 'Token refresh failed' });
      return;
    }

    res.json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_in: data.session.expires_in,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /auth/me — current user profile
router.get('/me', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', req.userId!)
      .single();

    if (error || !data) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      id: data.id,
      email: data.email,
      display_name: data.display_name,
      subscription_status: data.subscription_status,
      subscription_expiry: data.subscription_expiry,
      subscription_product: data.subscription_product,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
