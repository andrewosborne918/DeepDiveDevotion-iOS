-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- ============================================================
-- EPISODES TABLE
-- ============================================================
CREATE TABLE public.episodes (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  episode_number      INTEGER NOT NULL UNIQUE,
  title               TEXT NOT NULL,
  description         TEXT,
  publish_date        DATE,
  file_name           TEXT,
  audio_url           TEXT,
  video_url           TEXT,
  youtube_url         TEXT,
  thumbnail_url       TEXT,
  scripture_reference TEXT,
  book_name           TEXT,
  chapter_number      INTEGER,
  verse_range         TEXT,
  testament           TEXT CHECK (testament IN ('OT', 'NT')),
  transcript          TEXT,
  premium             BOOLEAN NOT NULL DEFAULT TRUE,
  processed           BOOLEAN NOT NULL DEFAULT FALSE,
  duration_seconds    INTEGER,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- USERS TABLE (extends Supabase auth.users)
-- ============================================================
CREATE TABLE public.users (
  id                   UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                TEXT,
  apple_user_id        TEXT UNIQUE,
  display_name         TEXT,
  subscription_status  TEXT NOT NULL DEFAULT 'none'
                         CHECK (subscription_status IN ('none', 'active', 'expired', 'grace')),
  subscription_expiry  TIMESTAMPTZ,
  subscription_product TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- USER PROGRESS TABLE
-- ============================================================
CREATE TABLE public.user_progress (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  episode_id     UUID NOT NULL REFERENCES public.episodes(id) ON DELETE CASCADE,
  audio_position NUMERIC(10, 2) NOT NULL DEFAULT 0,
  video_position NUMERIC(10, 2) NOT NULL DEFAULT 0,
  completed_at   TIMESTAMPTZ,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, episode_id)
);

-- ============================================================
-- FAVORITES TABLE
-- ============================================================
CREATE TABLE public.favorites (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES public.episodes(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, episode_id)
);

-- ============================================================
-- SYNC LOG TABLE
-- ============================================================
CREATE TABLE public.sync_log (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  started_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at   TIMESTAMPTZ,
  episodes_synced INTEGER,
  errors         JSONB,
  status         TEXT CHECK (status IN ('running', 'success', 'failed'))
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_episodes_book_name      ON public.episodes (book_name);
CREATE INDEX idx_episodes_testament      ON public.episodes (testament);
CREATE INDEX idx_episodes_publish_date   ON public.episodes (publish_date DESC);
CREATE INDEX idx_episodes_episode_number ON public.episodes (episode_number);
CREATE INDEX idx_episodes_premium        ON public.episodes (premium);
CREATE INDEX idx_episodes_book_trgm      ON public.episodes USING GIN (book_name gin_trgm_ops);

CREATE INDEX idx_user_progress_user_id   ON public.user_progress (user_id);
CREATE INDEX idx_user_progress_episode   ON public.user_progress (episode_id);
CREATE INDEX idx_favorites_user_id       ON public.favorites (user_id);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER episodes_updated_at
  BEFORE UPDATE ON public.episodes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER progress_updated_at
  BEFORE UPDATE ON public.user_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- AUTO-CREATE users RECORD ON SIGN UP
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
