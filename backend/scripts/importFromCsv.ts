import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { parse } from 'csv-parse/sync';
import { parseScriptureReference, OT_BOOKS } from '../src/services/scriptureParser';

dotenv.config({ path: path.join(__dirname, '../.env') });

type CsvRow = Record<string, string>;

const DEFAULT_CSV_PATH =
  '/Users/aosborne1/Desktop/DeepDiveDevotions-App/Deep Dive Devotions - Main Schedule.csv';

const FREE_EPISODE_COUNT = 3;

const DEFAULT_AUDIO_DIR =
  '/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Edited Audio/Episodes';

type CandidateEpisode = {
  episodeNumber: number;
  title: string;
  description: string | null;
  publishDate: string | null;
  fileName: string | null;
  youtubeUrl: string | null;
  transcript: string | null;
  thumbnailUrl: string | null;
  processedFlag: boolean;
  bookName: string;
  chapterNumber: number | null;
  testament: 'OT' | 'NT';
  scriptureReference: string;
  hasAudio: boolean;
};

const BOOK_ALIASES: Record<string, string> = {
  '1st Samuel': '1 Samuel',
  '2nd Samuel': '2 Samuel',
  '1st Kings': '1 Kings',
  '2nd Kings': '2 Kings',
  '1st Chronicles': '1 Chronicles',
  '2nd Chronicles': '2 Chronicles',
  '1st Corinthians': '1 Corinthians',
  '2nd Corinthians': '2 Corinthians',
  '1st Thessalonians': '1 Thessalonians',
  '2nd Thessalonians': '2 Thessalonians',
  '1st Timothy': '1 Timothy',
  '2nd Timothy': '2 Timothy',
  '1st Peter': '1 Peter',
  '2nd Peter': '2 Peter',
  '1st John': '1 John',
  '2nd John': '2 John',
  '3rd John': '3 John',
  'Song of Songs': 'Song of Solomon',
};

const OT_SET = new Set(OT_BOOKS.map(book => book.toLowerCase()));

function buildThumbnailUrl(filename: string | null): string | null {
  if (!filename) return null;
  const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
  if (!supabaseUrl) return null;
  return `${supabaseUrl}/storage/v1/object/public/thumbnails/${encodeURIComponent(filename)}`;
}

function normalizeDate(raw: string): string | null {
  if (!raw || !raw.trim()) return null;
  const trimmed = raw.trim();

  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;

  const mdyMatch = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (mdyMatch) {
    const [, m, d, y] = mdyMatch;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  const mdyShortMatch = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2})$/);
  if (mdyShortMatch) {
    const [, m, d, yy] = mdyShortMatch;
    const y = parseInt(yy, 10) < 50 ? `20${yy}` : `19${yy}`;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  const d = new Date(trimmed);
  if (!isNaN(d.getTime())) {
    return d.toISOString().split('T')[0];
  }

  return null;
}

function normalizeBool(raw: string): boolean {
  const value = (raw || '').trim().toLowerCase();
  return ['yes', 'true', '1', 'y'].includes(value);
}

function normalizeBookName(raw: string): string {
  const trimmed = (raw || '').trim();
  if (!trimmed) return 'Unknown';
  return BOOK_ALIASES[trimmed] ?? trimmed;
}

function detectTestament(bookName: string): 'OT' | 'NT' {
  return OT_SET.has(bookName.toLowerCase()) ? 'OT' : 'NT';
}

function extractChapterNumber(title: string, canonicalBook: string): number | null {
  const parsed = parseScriptureReference(title);
  if (parsed.chapterNumber != null && parsed.bookName.toLowerCase() === canonicalBook.toLowerCase()) {
    return parsed.chapterNumber;
  }

  const escaped = canonicalBook.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const directRegex = new RegExp(`${escaped}\\s+(\\d+)`, 'i');
  const directMatch = title.match(directRegex);
  if (directMatch) {
    const n = parseInt(directMatch[1], 10);
    if (!isNaN(n)) return n;
  }

  const fallback = title.match(/\b(\d{1,3})\b/g) ?? [];
  if (fallback.length === 0) return null;
  if (/^\d\s/.test(canonicalBook) && fallback.length >= 2) {
    const secondNumber = fallback[1];
    if (!secondNumber) return null;
    const n = parseInt(secondNumber, 10);
    return isNaN(n) ? null : n;
  }
  const firstNumber = fallback[0];
  if (!firstNumber) return null;
  const n = parseInt(firstNumber, 10);
  return isNaN(n) ? null : n;
}

function normalizeAudioFileName(raw: string | null): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return trimmed.toLowerCase().endsWith('.m4a') ? trimmed : `${trimmed}.m4a`;
}

function buildAudioIndex(audioDir: string): Map<number, string> {
  const map = new Map<number, string>();
  if (!fs.existsSync(audioDir)) return map;

  const entries = fs.readdirSync(audioDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!entry.name.toLowerCase().endsWith('.m4a')) continue;

    const match = entry.name.match(/^(\d+)\s+/);
    if (!match) continue;

    const episodeNumber = parseInt(match[1], 10);
    if (isNaN(episodeNumber)) continue;
    if (!map.has(episodeNumber)) {
      map.set(episodeNumber, entry.name);
    }
  }

  return map;
}

function resolveAudioFileName(preferredFromCsv: string | null, episodeNumber: number, audioIndex: Map<number, string>): string | null {
  if (preferredFromCsv) {
    return preferredFromCsv;
  }
  return audioIndex.get(episodeNumber) ?? null;
}

function candidateScore(candidate: CandidateEpisode): number {
  let score = 0;
  if (candidate.chapterNumber != null) score += 100;
  if (candidate.processedFlag) score += 15;
  if (candidate.hasAudio) score += 20;
  if ((candidate.transcript?.length ?? 0) > 500) score += 10;
  if (candidate.bookName !== 'Unknown') score += 8;
  return score;
}

function readCsvRows(csvPath: string): CsvRow[] {
  const content = fs.readFileSync(csvPath, 'utf-8');
  return parse(content, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
    bom: true,
    relax_column_count: true,
  }) as CsvRow[];
}

async function importCsv(csvPath: string): Promise<void> {
  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV not found at: ${csvPath}`);
  }

  const includeUnprocessed = !process.argv.includes('--processed-only');
  const dryRun = process.argv.includes('--dry-run');

  const audioDirFlagIndex = process.argv.indexOf('--audio-dir');
  const audioDir = audioDirFlagIndex >= 0
    ? (process.argv[audioDirFlagIndex + 1] || '')
    : (process.env.AUDIO_EPISODES_PATH || DEFAULT_AUDIO_DIR);

  const audioBaseUrl = (process.env.AUDIO_STREAM_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');

  const rows = readCsvRows(csvPath);
  console.log(`Loaded ${rows.length} CSV rows`);

  const audioIndex = buildAudioIndex(audioDir);
  console.log(`Indexed ${audioIndex.size} local audio files from ${audioDir}`);

  const bestByEpisode = new Map<number, CandidateEpisode>();
  const upserts: Record<string, unknown>[] = [];
  let skipped = 0;

  for (const row of rows) {
    const episodeNumberRaw = row['Episode Number'];
    const title = (row['Title'] || '').trim();

    if (!episodeNumberRaw || !title) {
      skipped++;
      continue;
    }

    const episodeNumber = parseInt(episodeNumberRaw, 10);
    if (isNaN(episodeNumber)) {
      skipped++;
      continue;
    }

    const processed = normalizeBool(row['Processed'] || '');
    if (!includeUnprocessed && !processed) {
      skipped++;
      continue;
    }

    const publishDate = normalizeDate(row['Publish Date'] || '');
    const csvFileName = normalizeAudioFileName((row['File Name'] || '').trim() || null);
    const resolvedFileName = resolveAudioFileName(csvFileName, episodeNumber, audioIndex);
    const description = (row['Description'] || '').trim() || null;
    const youtubeUrl = (row['YouTubeURL'] || '').trim() || null;
    const transcript = (row['Transcript'] || '').trim() || null;
    const thumbnailFilename = (row['Thumbnail'] || '').trim() || null;
    const thumbnailUrl = buildThumbnailUrl(thumbnailFilename);

    const parsed = parseScriptureReference(title);
    const canonicalBook = normalizeBookName(row['BookName'] || parsed.bookName);
    const chapterNumber = extractChapterNumber(title, canonicalBook);
    const testament = detectTestament(canonicalBook);
    const scriptureReference = chapterNumber != null ? `${canonicalBook} ${chapterNumber}` : canonicalBook;

    const candidate: CandidateEpisode = {
      episodeNumber,
      title,
      description,
      publishDate,
      fileName: resolvedFileName,
      youtubeUrl,
      transcript,
      thumbnailUrl,
      processedFlag: processed,
      bookName: canonicalBook,
      chapterNumber,
      testament,
      scriptureReference,
      hasAudio: resolvedFileName != null,
    };

    const existing = bestByEpisode.get(episodeNumber);
    if (!existing || candidateScore(candidate) > candidateScore(existing)) {
      bestByEpisode.set(episodeNumber, candidate);
    }
  }

  for (const candidate of bestByEpisode.values()) {
    upserts.push({
      episode_number: candidate.episodeNumber,
      title: candidate.title,
      description: candidate.description,
      publish_date: candidate.publishDate,
      file_name: candidate.fileName,
      audio_url: candidate.fileName ? `${audioBaseUrl}/v1/media/audio/${candidate.episodeNumber}` : null,
      video_url: null,
      youtube_url: candidate.youtubeUrl,
      thumbnail_url: candidate.thumbnailUrl,
      scripture_reference: candidate.scriptureReference,
      book_name: candidate.bookName,
      chapter_number: candidate.chapterNumber,
      testament: candidate.testament,
      transcript: candidate.transcript,
      premium: candidate.episodeNumber > FREE_EPISODE_COUNT,
      processed: true,
    });
  }

  if (upserts.length === 0) {
    console.log('No rows found to import after filtering and dedupe.');
    return;
  }

  const chapters = upserts.filter(ep => ep.chapter_number != null).length;
  const withAudio = upserts.filter(ep => ep.audio_url != null).length;
  const withTranscript = upserts.filter(ep => ep.transcript != null).length;
  console.log(`Deduped episodes: ${upserts.length}`);
  console.log(`Episodes with chapter number: ${chapters}`);
  console.log(`Episodes with transcript: ${withTranscript}`);
  console.log(`Episodes with audio: ${withAudio}`);

  if (dryRun) {
    console.log('Dry run complete. No database writes were performed.');
    return;
  }

  const { supabaseAdmin } = await import('../src/services/supabase');

  const BATCH_SIZE = 100;
  let imported = 0;

  for (let i = 0; i < upserts.length; i += BATCH_SIZE) {
    const batch = upserts.slice(i, i + BATCH_SIZE);
    const { error } = await supabaseAdmin
      .from('episodes')
      .upsert(batch, { onConflict: 'episode_number' });

    if (error) {
      throw new Error(`Supabase upsert failed for rows ${i + 1}-${i + batch.length}: ${error.message}`);
    }

    imported += batch.length;
    console.log(`Upserted ${imported}/${upserts.length}`);
  }

  console.log('CSV import complete');
  console.log(`Imported: ${imported}`);
  console.log(`Skipped: ${skipped}`);
}

const csvPathArg = process.argv[2] || DEFAULT_CSV_PATH;

importCsv(csvPathArg)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('CSV import failed:', (error as Error).message);
    process.exit(1);
  });
