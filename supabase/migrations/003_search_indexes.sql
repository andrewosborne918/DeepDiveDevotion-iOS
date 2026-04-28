-- ============================================================
-- FULL-TEXT SEARCH
-- ============================================================

-- Add tsvector column for search
ALTER TABLE public.episodes ADD COLUMN search_vector TSVECTOR;

-- GIN index on search_vector
CREATE INDEX idx_episodes_search ON public.episodes USING GIN (search_vector);

-- Trigger to auto-update search_vector on insert/update
CREATE OR REPLACE FUNCTION episodes_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.scripture_reference, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.book_name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(LEFT(NEW.transcript, 100000), '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER episodes_search_update
  BEFORE INSERT OR UPDATE ON public.episodes
  FOR EACH ROW EXECUTE FUNCTION episodes_search_vector_update();

-- Backfill existing rows
UPDATE public.episodes SET updated_at = updated_at;

-- ============================================================
-- SEARCH HIGHLIGHT FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION get_search_highlights(query_text TEXT, episode_ids UUID[])
RETURNS TABLE(id UUID, highlight TEXT) AS $$
  SELECT
    e.id,
    ts_headline(
      'english',
      COALESCE(e.description, '') || ' ' || COALESCE(LEFT(e.transcript, 50000), ''),
      websearch_to_tsquery('english', query_text),
      'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=15, MaxFragments=2'
    )
  FROM public.episodes e
  WHERE e.id = ANY(episode_ids);
$$ LANGUAGE SQL STABLE;

-- ============================================================
-- BOOKS AGGREGATION VIEW
-- ============================================================
CREATE OR REPLACE VIEW public.books_summary AS
SELECT
  book_name,
  testament,
  COUNT(*) AS episode_count
FROM public.episodes
WHERE book_name IS NOT NULL
  AND processed = TRUE
GROUP BY book_name, testament
ORDER BY
  CASE testament WHEN 'OT' THEN 0 ELSE 1 END,
  MIN(episode_number);
