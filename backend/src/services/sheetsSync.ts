import { google } from 'googleapis';
import { supabaseAdmin } from './supabase';
import { parseScriptureReference } from './scriptureParser';
import { RawSheetEpisode } from '../types';
import dotenv from 'dotenv';

dotenv.config();

const SPREADSHEET_ID = process.env.GOOGLE_SHEETS_ID!;
const GCS_BUCKET = process.env.GCS_BUCKET || 'deep-dive-podcast-assets';
const MAIN_SHEET = 'Main Schedule';
const BUILD_SHEET = 'Build';

// Free episodes (not premium) — first 3
const FREE_EPISODE_COUNT = 3;

type MainColumnKey =
  | 'episodeNumber'
  | 'title'
  | 'publishDate'
  | 'fileName'
  | 'description'
  | 'processed'
  | 'youtubeUrl'
  | 'transcript';

// Accept multiple known header spellings to survive sheet format changes.
const MAIN_HEADER_ALIASES: Record<MainColumnKey, string[]> = {
  episodeNumber: ['Episode Number', 'episode_number', 'Order'],
  title: ['Title', 'Episode'],
  publishDate: ['Publish Date', 'publish_date'],
  fileName: ['File Name', 'FILE', 'File'],
  description: ['Description', 'description'],
  processed: ['Processed', 'processed'],
  youtubeUrl: ['YouTubeURL', 'YouTube URL', 'youtube_url'],
  transcript: ['Transcript', 'TRANSCRIPT'],
};

// Column indices for Build tab (0-based)
const BUILD_COLS = {
  ORDER: 0,      // A — matches episode number
  FILE: 1,       // B
  EPISODE: 2,    // C
  BOOK: 3,       // D
  PROMPT: 4,     // E
  TRANSCRIPT: 5, // F
};

function getGoogleAuthClient() {
  const base64Json = process.env.GOOGLE_SERVICE_ACCOUNT_JSON_BASE64;
  if (!base64Json) {
    throw new Error('Missing GOOGLE_SERVICE_ACCOUNT_JSON_BASE64 environment variable');
  }
  const credentials = JSON.parse(Buffer.from(base64Json, 'base64').toString('utf-8'));
  return new google.auth.GoogleAuth({
    credentials,
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets.readonly',
    ],
  });
}

/** Normalize date strings to YYYY-MM-DD format */
function normalizeDate(raw: string): string | null {
  if (!raw || !raw.trim()) return null;
  const trimmed = raw.trim();

  // Already YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;

  // MM/DD/YYYY
  const mdyMatch = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (mdyMatch) {
    const [, m, d, y] = mdyMatch;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  // M/D/YY
  const mdyShortMatch = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2})$/);
  if (mdyShortMatch) {
    const [, m, d, yy] = mdyShortMatch;
    const y = parseInt(yy) < 50 ? `20${yy}` : `19${yy}`;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  // Try native Date parse as last resort
  const d = new Date(trimmed);
  if (!isNaN(d.getTime())) {
    return d.toISOString().split('T')[0];
  }

  return null;
}

/** Construct public GCS URL for episode audio */
function buildAudioUrl(publishDate: string, fileName: string): string {
  const encodedFileName = encodeURIComponent(`${fileName}.m4a`);
  return `https://storage.googleapis.com/${GCS_BUCKET}/episodes/${publishDate}/${encodedFileName}`;
}

/** Construct public GCS URL for episode video */
function buildVideoUrl(publishDate: string, fileName: string): string {
  const encodedFileName = encodeURIComponent(`${fileName}.mp4`);
  return `https://storage.googleapis.com/${GCS_BUCKET}/episodes/${publishDate}/${encodedFileName}`;
}

/** Construct public GCS URL for thumbnail */
function buildThumbnailUrl(bookName: string, chapterNumber: number | null): string {
  const filename = chapterNumber
    ? `${bookName} ${chapterNumber}.png`
    : `${bookName}.png`;
  return `https://storage.googleapis.com/${GCS_BUCKET}/thumbnails/${encodeURIComponent(filename)}`;
}

/** Read all rows from Main Schedule tab including headers */
async function readMainSchedule(sheets: ReturnType<typeof google.sheets>): Promise<string[][]> {
  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: SPREADSHEET_ID,
    range: `${MAIN_SHEET}!A1:AZ`,
  });
  return (response.data.values as string[][]) || [];
}

function normalizeHeader(header: string): string {
  return header.trim().toLowerCase();
}

function buildHeaderIndex(headerRow: string[]): Record<MainColumnKey, number | null> {
  const normalized = headerRow.map(normalizeHeader);

  const pickIndex = (aliases: string[]): number | null => {
    for (const alias of aliases) {
      const idx = normalized.indexOf(normalizeHeader(alias));
      if (idx >= 0) return idx;
    }
    return null;
  };

  return {
    episodeNumber: pickIndex(MAIN_HEADER_ALIASES.episodeNumber),
    title: pickIndex(MAIN_HEADER_ALIASES.title),
    publishDate: pickIndex(MAIN_HEADER_ALIASES.publishDate),
    fileName: pickIndex(MAIN_HEADER_ALIASES.fileName),
    description: pickIndex(MAIN_HEADER_ALIASES.description),
    processed: pickIndex(MAIN_HEADER_ALIASES.processed),
    youtubeUrl: pickIndex(MAIN_HEADER_ALIASES.youtubeUrl),
    transcript: pickIndex(MAIN_HEADER_ALIASES.transcript),
  };
}

function getCell(row: string[], index: number | null): string {
  if (index == null || index < 0 || index >= row.length) return '';
  return row[index] ?? '';
}

/** Read all rows from Build tab and return Map<episodeNumber, transcript> */
async function readBuildTab(sheets: ReturnType<typeof google.sheets>): Promise<Map<number, string>> {
  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: SPREADSHEET_ID,
    range: `${BUILD_SHEET}!A2:F`,
  });
  const rows: string[][] = (response.data.values as string[][]) || [];
  const map = new Map<number, string>();
  for (const row of rows) {
    const orderRaw = row[BUILD_COLS.ORDER];
    const transcript = row[BUILD_COLS.TRANSCRIPT];
    if (!orderRaw || !transcript) continue;
    const episodeNumber = parseInt(orderRaw, 10);
    if (!isNaN(episodeNumber)) {
      map.set(episodeNumber, transcript.trim());
    }
  }
  return map;
}

/** Parse a Main Schedule row into a structured object */
function parseMainRow(row: string[], headerIndex: Record<MainColumnKey, number | null>): RawSheetEpisode | null {
  const episodeNumberRaw = getCell(row, headerIndex.episodeNumber);
  const title = getCell(row, headerIndex.title).trim();
  const processedRaw = getCell(row, headerIndex.processed).trim().toLowerCase();

  if (!episodeNumberRaw || !title) return null;
  const episodeNumber = parseInt(episodeNumberRaw, 10);
  if (isNaN(episodeNumber)) return null;

  const processed = processedRaw === 'yes' || processedRaw === 'true' || processedRaw === '1';

  return {
    episodeNumber,
    title,
    description: getCell(row, headerIndex.description).trim(),
    publishDate: getCell(row, headerIndex.publishDate).trim(),
    fileName: getCell(row, headerIndex.fileName).trim(),
    youtubeUrl: getCell(row, headerIndex.youtubeUrl).trim() || null,
    transcript: getCell(row, headerIndex.transcript).trim() || null,
    processed,
  };
}

export interface SyncResult {
  synced: number;
  skipped: number;
  errors: string[];
}

export async function runSync(): Promise<SyncResult> {
  const result: SyncResult = { synced: 0, skipped: 0, errors: [] };

  // Log sync start
  const { data: logEntry } = await supabaseAdmin
    .from('sync_log')
    .insert({ status: 'running' })
    .select('id')
    .single();

  const logId = logEntry?.id;

  try {
    const auth = getGoogleAuthClient();
    const sheets = google.sheets({ version: 'v4', auth: await auth.getClient() as never });

    console.log('Reading Main Schedule tab...');
    const mainRows = await readMainSchedule(sheets);
    console.log(`Found ${Math.max(mainRows.length - 1, 0)} rows in Main Schedule`);

    if (mainRows.length === 0) {
      throw new Error('Main Schedule tab is empty');
    }

    const headerIndex = buildHeaderIndex(mainRows[0]);
    if (headerIndex.episodeNumber == null || headerIndex.title == null) {
      throw new Error('Missing required Main Schedule headers: Episode Number and/or Title');
    }

    console.log('Reading Build tab for transcripts...');
    const transcriptMap = await readBuildTab(sheets);
    console.log(`Found ${transcriptMap.size} transcripts in Build tab`);

    // Process only rows where processed = yes
    const processedRows = mainRows
      .slice(1)
      .map(row => parseMainRow(row, headerIndex))
      .filter((r): r is RawSheetEpisode => r !== null && r.processed);

    console.log(`Processing ${processedRows.length} published episodes...`);

    // Build upsert batch
    const upsertBatch: Record<string, unknown>[] = [];

    for (const row of processedRows) {
      try {
        const publishDate = normalizeDate(row.publishDate);
        const scripture = parseScriptureReference(row.title);
        const transcript = row.transcript ?? transcriptMap.get(row.episodeNumber) ?? null;

        const audioUrl = publishDate && row.fileName
          ? buildAudioUrl(publishDate, row.fileName)
          : null;
        const videoUrl = publishDate && row.fileName
          ? buildVideoUrl(publishDate, row.fileName)
          : null;
        const thumbnailUrl = buildThumbnailUrl(scripture.bookName, scripture.chapterNumber);

        upsertBatch.push({
          episode_number: row.episodeNumber,
          title: row.title,
          description: row.description || null,
          publish_date: publishDate,
          file_name: row.fileName || null,
          audio_url: audioUrl,
          video_url: videoUrl,
          youtube_url: row.youtubeUrl || null,
          thumbnail_url: thumbnailUrl,
          scripture_reference: scripture.scriptureReference,
          book_name: scripture.bookName,
          chapter_number: scripture.chapterNumber,
          testament: scripture.testament,
          transcript: transcript,
          premium: row.episodeNumber > FREE_EPISODE_COUNT,
          processed: true,
        });
      } catch (err) {
        const msg = `Episode ${row.episodeNumber}: ${(err as Error).message}`;
        result.errors.push(msg);
        console.error(msg);
        result.skipped++;
      }
    }

    // Upsert in batches of 50
    const BATCH_SIZE = 50;
    for (let i = 0; i < upsertBatch.length; i += BATCH_SIZE) {
      const batch = upsertBatch.slice(i, i + BATCH_SIZE);
      const { error } = await supabaseAdmin
        .from('episodes')
        .upsert(batch, { onConflict: 'episode_number' });

      if (error) {
        const msg = `Batch upsert error (rows ${i}–${i + batch.length}): ${error.message}`;
        result.errors.push(msg);
        console.error(msg);
      } else {
        result.synced += batch.length;
        console.log(`Upserted batch ${Math.floor(i / BATCH_SIZE) + 1}: ${batch.length} episodes`);
      }
    }

    // Update sync log
    if (logId) {
      await supabaseAdmin
        .from('sync_log')
        .update({
          completed_at: new Date().toISOString(),
          episodes_synced: result.synced,
          errors: result.errors.length > 0 ? result.errors : null,
          status: result.errors.length === 0 ? 'success' : 'failed',
        })
        .eq('id', logId);
    }

    console.log(`Sync complete: ${result.synced} synced, ${result.skipped} skipped, ${result.errors.length} errors`);
  } catch (err) {
    const msg = `Fatal sync error: ${(err as Error).message}`;
    result.errors.push(msg);
    console.error(msg);

    if (logId) {
      await supabaseAdmin
        .from('sync_log')
        .update({
          completed_at: new Date().toISOString(),
          episodes_synced: result.synced,
          errors: result.errors,
          status: 'failed',
        })
        .eq('id', logId);
    }
  }

  return result;
}
