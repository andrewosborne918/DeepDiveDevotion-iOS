import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../../services/supabase';

const router = Router();

async function isSubscribed(userId: string | undefined): Promise<boolean> {
  if (!userId) return false;
  const { data } = await supabaseAdmin
    .from('users')
    .select('subscription_status, subscription_expiry')
    .eq('id', userId)
    .single();
  if (!data) return false;
  if (data.subscription_status !== 'active' && data.subscription_status !== 'grace') return false;
  if (data.subscription_expiry && new Date(data.subscription_expiry) < new Date()) return false;
  return true;
}

// GET /search?q=genesis+creation&book=Genesis&page=1&limit=20
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const q = (req.query.q as string || '').trim();
    if (q.length < 2) {
      res.json({ data: [], meta: { page: 1, limit: 20, total: 0, total_pages: 0 } });
      return;
    }

    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const offset = (page - 1) * limit;
    const book = req.query.book as string | undefined;

    // Optional auth
    const authHeader = req.headers.authorization;
    let userId: string | undefined;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      userId = user?.id;
    }
    const subscribed = await isSubscribed(userId);

    // Full-text search using websearch syntax (supports AND, OR, phrase)
    let query = supabaseAdmin
      .from('episodes')
      .select('id, episode_number, title, description, publish_date, audio_url, video_url, thumbnail_url, scripture_reference, book_name, chapter_number, testament, premium, processed', { count: 'exact' })
      .eq('processed', true)
      .textSearch('search_vector', q, { type: 'websearch', config: 'english' })
      .order('episode_number', { ascending: true })
      .range(offset, offset + limit - 1);

    if (book) query = query.ilike('book_name', book);

    const { data, error, count } = await query;

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    // Fetch highlights for results
    const episodeIds = (data || []).map(ep => ep.id);
    let highlights: Record<string, string> = {};
    if (episodeIds.length > 0) {
      const { data: hlData } = await supabaseAdmin.rpc('get_search_highlights', {
        query_text: q,
        episode_ids: episodeIds,
      });
      if (hlData) {
        for (const hl of hlData) {
          highlights[hl.id] = hl.highlight;
        }
      }
    }

    const episodes = (data || []).map(ep => {
      const locked = ep.premium && !subscribed;
      return {
        ...ep,
        audio_url: locked ? null : ep.audio_url,
        video_url: locked ? null : ep.video_url,
        locked,
        highlight: highlights[ep.id] ?? null,
      };
    });

    res.json({
      data: episodes,
      meta: {
        page,
        limit,
        total: count ?? 0,
        total_pages: Math.ceil((count ?? 0) / limit),
      },
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
