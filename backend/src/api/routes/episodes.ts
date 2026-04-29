import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../../services/supabase';
import { authMiddleware } from '../middleware/auth';

const router = Router();

/** Check if the requesting user has an active subscription */
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

/** Redact premium content for locked users */
function applyLock(episode: Record<string, unknown>, locked: boolean): Record<string, unknown> {
  if (!locked) return { ...episode, locked: false };
  return {
    ...episode,
    audio_url: null,
    video_url: null,
    locked: true,
  };
}

// GET /episodes
// Query params: page, limit, book, testament, sort (episodeNumber|publishDate|title), order (asc|desc)
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const offset = (page - 1) * limit;
    const book = req.query.book as string | undefined;
    const testament = req.query.testament as string | undefined;
    const sort = (req.query.sort as string) || 'episode_number';
    const order = (req.query.order as string) === 'asc' ? true : false;
    const dateFilter = req.query.date as string | undefined; // expects YYYY-MM-DD

    const validSorts = ['episode_number', 'publish_date', 'title'];
    const sortColumn = validSorts.includes(sort) ? sort : 'episode_number';

    // Optional auth
    const authHeader = req.headers.authorization;
    let userId: string | undefined;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      userId = user?.id;
    }
    const subscribed = await isSubscribed(userId);

    let query = supabaseAdmin
      .from('episodes')
      .select('*', { count: 'exact' })
      .eq('processed', true)
      .order(sortColumn, { ascending: order })
      .range(offset, offset + limit - 1);

    if (book) query = query.ilike('book_name', book);
    if (testament && (testament === 'OT' || testament === 'NT')) {
      query = query.eq('testament', testament);
    }
    if (dateFilter && /^\d{4}-\d{2}-\d{2}$/.test(dateFilter)) {
      query = query.eq('publish_date', dateFilter);
    }

    const { data, error, count } = await query;

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    const episodes = (data || []).map(ep => {
      const locked = ep.premium && !subscribed;
      return applyLock(ep, locked);
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

// GET /episodes/books
router.get('/books', async (_req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabaseAdmin
      .from('books_summary')
      .select('*');

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }
    res.json({ data: data || [] });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /episodes/:id
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    // Optional auth
    const authHeader = req.headers.authorization;
    let userId: string | undefined;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      userId = user?.id;
    }
    const subscribed = await isSubscribed(userId);

    // Support lookup by UUID or episode number
    let query = supabaseAdmin.from('episodes').select('*');
    if (/^\d+$/.test(id)) {
      query = query.eq('episode_number', parseInt(id, 10));
    } else {
      query = query.eq('id', id);
    }

    const { data, error } = await query.single();

    if (error || !data) {
      res.status(404).json({ error: 'Episode not found' });
      return;
    }

    const locked = data.premium && !subscribed;
    res.json(applyLock(data, locked));
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /episodes/book/:bookName/chapter/:chapterNumber
router.get('/book/:bookName/chapter/:chapterNumber', async (req: Request, res: Response): Promise<void> => {
  try {
    const { bookName, chapterNumber } = req.params;
    const chapter = parseInt(chapterNumber, 10);
    if (isNaN(chapter)) {
      res.status(400).json({ error: 'Invalid chapter number' });
      return;
    }

    const authHeader = req.headers.authorization;
    let userId: string | undefined;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      userId = user?.id;
    }
    const subscribed = await isSubscribed(userId);

    const { data, error } = await supabaseAdmin
      .from('episodes')
      .select('*')
      .ilike('book_name', bookName)
      .eq('chapter_number', chapter)
      .eq('processed', true)
      .limit(1)
      .single();

    if (error || !data) {
      res.status(404).json({ error: 'Episode not found' });
      return;
    }

    const locked = data.premium && !subscribed;
    res.json(applyLock(data, locked));
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /episodes/book/:bookName
router.get('/book/:bookName', async (req: Request, res: Response): Promise<void> => {
  try {
    const { bookName } = req.params;

    const authHeader = req.headers.authorization;
    let userId: string | undefined;
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      userId = user?.id;
    }
    const subscribed = await isSubscribed(userId);

    const { data, error } = await supabaseAdmin
      .from('episodes')
      .select('*')
      .ilike('book_name', bookName)
      .eq('processed', true)
      .order('episode_number', { ascending: true });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    const episodes = (data || []).map(ep => {
      const locked = ep.premium && !subscribed;
      return applyLock(ep, locked);
    });

    res.json({ book_name: bookName, episodes });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// GET /episodes — with optional auth, mount auth middleware optionally
router.use(authMiddleware);

export default router;
