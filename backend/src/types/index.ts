export interface Episode {
  id: string;
  episode_number: number;
  title: string;
  description: string | null;
  publish_date: string | null;
  file_name: string | null;
  audio_url: string | null;
  video_url: string | null;
  youtube_url: string | null;
  thumbnail_url: string | null;
  scripture_reference: string | null;
  book_name: string | null;
  chapter_number: number | null;
  testament: 'OT' | 'NT' | null;
  transcript: string | null;
  premium: boolean;
  processed: boolean;
  created_at: string;
  updated_at: string;
}

export interface EpisodePublic extends Omit<Episode, 'transcript'> {
  locked: boolean;
  transcript?: string | null;
}

export interface BookSummary {
  book_name: string;
  testament: 'OT' | 'NT' | null;
  episode_count: number;
}

export interface UserRecord {
  id: string;
  email: string | null;
  apple_user_id: string | null;
  display_name: string | null;
  subscription_status: 'none' | 'active' | 'expired' | 'grace';
  subscription_expiry: string | null;
  subscription_product: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProgressRecord {
  episode_id: string;
  audio_position: number;
  video_position: number;
  completed_at: string | null;
  updated_at: string;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  total_pages: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: PaginationMeta;
}

export interface RawSheetEpisode {
  episodeNumber: number;
  title: string;
  description: string;
  publishDate: string;
  fileName: string;
  youtubeUrl: string | null;
  transcript: string | null;
  processed: boolean;
}

export interface ParsedScripture {
  bookName: string;
  chapterNumber: number | null;
  verseRange: string | null;
  scriptureReference: string;
  testament: 'OT' | 'NT';
}

declare global {
  namespace Express {
    interface Request {
      userId?: string;
    }
  }
}
