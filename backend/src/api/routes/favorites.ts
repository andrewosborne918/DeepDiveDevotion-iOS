import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../../services/supabase';
import { authMiddleware } from '../middleware/auth';

const router = Router();
router.use(authMiddleware);

// GET /favorites — all favorited episodes (full objects)
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabaseAdmin
      .from('favorites')
      .select('episode_id, created_at, episodes(*)')
      .eq('user_id', req.userId!)
      .order('created_at', { ascending: false });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    // Check if user is subscribed for content locking
    const { data: user } = await supabaseAdmin
      .from('users')
      .select('subscription_status, subscription_expiry')
      .eq('id', req.userId!)
      .single();

    const subscribed = user?.subscription_status === 'active' || user?.subscription_status === 'grace';

    const episodes = (data || []).map(fav => {
      const joined = fav.episodes as unknown;
      const ep = Array.isArray(joined)
        ? (joined[0] as Record<string, unknown> | undefined)
        : (joined as Record<string, unknown> | null);
      if (!ep) return null;
      const locked = ep.premium && !subscribed;
      return {
        ...ep,
        audio_url: locked ? null : ep.audio_url,
        video_url: locked ? null : ep.video_url,
        transcript: locked ? null : ep.transcript,
        locked,
        favorited_at: fav.created_at,
      };
    }).filter(Boolean);

    res.json({ data: episodes });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// POST /favorites/:episodeId
router.post('/:episodeId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { episodeId } = req.params;

    // Verify episode exists
    const { data: episode } = await supabaseAdmin
      .from('episodes')
      .select('id')
      .eq('id', episodeId)
      .single();

    if (!episode) {
      res.status(404).json({ error: 'Episode not found' });
      return;
    }

    const { error } = await supabaseAdmin
      .from('favorites')
      .upsert({ user_id: req.userId!, episode_id: episodeId }, { onConflict: 'user_id,episode_id', ignoreDuplicates: true });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(201).json({ success: true });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// DELETE /favorites/:episodeId
router.delete('/:episodeId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { episodeId } = req.params;

    const { error } = await supabaseAdmin
      .from('favorites')
      .delete()
      .eq('user_id', req.userId!)
      .eq('episode_id', episodeId);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
