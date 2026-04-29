import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

import episodesRouter from './api/routes/episodes';
import searchRouter from './api/routes/search';
import authRouter from './api/routes/auth';
import subscriptionsRouter from './api/routes/subscriptions';
import progressRouter from './api/routes/progress';
import favoritesRouter from './api/routes/favorites';
import mediaRouter from './api/routes/media';
import { syncSecretMiddleware } from './api/middleware/auth';
import { runSync } from './services/sheetsSync';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security
app.use(helmet());
app.use(express.json({ limit: '1mb' }));

// CORS — restrict to your app domains in production
app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ['https://deepdivedevotions.com']
    : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Sync-Secret'],
}));

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});
app.use('/v1/', apiLimiter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Internal sync endpoint (protected by shared secret, called by Cloud Scheduler)
app.post('/internal/sync', syncSecretMiddleware, async (_req, res) => {
  try {
    console.log('Sync triggered via HTTP');
    // Run async without waiting so the HTTP response returns quickly
    runSync().then(result => {
      console.log('Sync complete:', result);
    }).catch(err => {
      console.error('Sync error:', err);
    });
    res.json({ message: 'Sync started' });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// API routes
app.use('/v1/episodes', episodesRouter);
app.use('/v1/search', searchRouter);
app.use('/v1/auth', authRouter);
app.use('/v1/subscriptions', subscriptionsRouter);
app.use('/v1/progress', progressRouter);
app.use('/v1/favorites', favoritesRouter);
app.use('/v1/media', mediaRouter);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Deep Dive Devotions API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Local network: http://10.101.106.217:${PORT}/v1`);
});

export default app;
