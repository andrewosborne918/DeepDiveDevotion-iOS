import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../../services/supabase';
import { authMiddleware } from '../middleware/auth';

const router = Router();
router.use(authMiddleware);

// GET /progress — all user progress
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabaseAdmin
      .from('user_progress')
      .select('episode_id, audio_position, video_position, completed_at, updated_at')
      .eq('user_id', req.userId!)
      .order('updated_at', { ascending: false });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ data: data || [] });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// PUT /progress/:episodeId — upsert progress for a specific episode
router.put('/:episodeId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { episodeId } = req.params;
    const { audio_position, video_position, completed_at } = req.body;

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
      .from('user_progress')
      .upsert({
        user_id: req.userId!,
        episode_id: episodeId,
        ...(audio_position !== undefined && { audio_position: Math.max(0, Number(audio_position)) }),
        ...(video_position !== undefined && { video_position: Math.max(0, Number(video_position)) }),
        ...(completed_at !== undefined && { completed_at }),
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id,episode_id' });

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
