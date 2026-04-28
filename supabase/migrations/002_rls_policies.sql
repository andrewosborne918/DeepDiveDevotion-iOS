-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

ALTER TABLE public.episodes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_log      ENABLE ROW LEVEL SECURITY;

-- Episodes: anyone can read, only service_role can write
CREATE POLICY "episodes_public_read"
  ON public.episodes FOR SELECT
  USING (true);

CREATE POLICY "episodes_service_insert"
  ON public.episodes FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "episodes_service_update"
  ON public.episodes FOR UPDATE
  USING (auth.role() = 'service_role');

CREATE POLICY "episodes_service_delete"
  ON public.episodes FOR DELETE
  USING (auth.role() = 'service_role');

-- Users: users can read/update their own row; service_role has full access
CREATE POLICY "users_own_read"
  ON public.users FOR SELECT
  USING (auth.uid() = id OR auth.role() = 'service_role');

CREATE POLICY "users_own_update"
  ON public.users FOR UPDATE
  USING (auth.uid() = id OR auth.role() = 'service_role');

CREATE POLICY "users_service_insert"
  ON public.users FOR INSERT
  WITH CHECK (auth.role() = 'service_role' OR auth.uid() = id);

-- User Progress: users manage their own rows
CREATE POLICY "progress_own_read"
  ON public.user_progress FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "progress_own_insert"
  ON public.user_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "progress_own_update"
  ON public.user_progress FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "progress_own_delete"
  ON public.user_progress FOR DELETE
  USING (auth.uid() = user_id);

-- Favorites: users manage their own rows
CREATE POLICY "favorites_own_read"
  ON public.favorites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "favorites_own_insert"
  ON public.favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_own_delete"
  ON public.favorites FOR DELETE
  USING (auth.uid() = user_id);

-- Sync log: service_role only
CREATE POLICY "sync_log_service"
  ON public.sync_log FOR ALL
  USING (auth.role() = 'service_role');
