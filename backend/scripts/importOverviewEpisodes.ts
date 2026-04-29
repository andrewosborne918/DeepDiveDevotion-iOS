/**
 * Import "Book Overview" episodes into Supabase and upload their audio to R2.
 *
 * Overview episodes are those in the CSV where the title has no "Book Chapter:" pattern
 * (e.g. "Genesis Explained: ..."). They are stored with:
 *   - episode_number: 5001–5066 (avoids conflicting with chapter episodes)
 *   - chapter_number: 0  (sentinel value meaning "overview")
 *
 * Usage:
 *   npx ts-node scripts/importOverviewEpisodes.ts
 *   npx ts-node scripts/importOverviewEpisodes.ts --dry-run
 *   npx ts-node scripts/importOverviewEpisodes.ts --skip-audio   (DB only, no R2 upload)
 */

import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { parse } from 'csv-parse/sync';
import { createClient } from '@supabase/supabase-js';
import { S3Client, HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';

dotenv.config({ path: path.join(__dirname, '../.env') });

type CsvRow = Record<string, string>;

const CSV_PATH =
  '/Users/aosborne1/Desktop/DeepDiveDevotions-App/Deep Dive Devotions - Main Schedule.csv';

const AUDIO_DIR =
  process.env.AUDIO_EPISODES_PATH ||
  '/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Edited Audio/Episodes';

const OVERVIEW_EP_OFFSET = 5000; // overview episodes get ids 5001–5066

const BOOK_ALIASES: Record<string, string> = {
  '1st Samuel': '1 Samuel', '2nd Samuel': '2 Samuel',
  '1st Kings': '1 Kings', '2nd Kings': '2 Kings',
  '1st Chronicles': '1 Chronicles', '2nd Chronicles': '2 Chronicles',
  '1st Corinthians': '1 Corinthians', '2nd Corinthians': '2 Corinthians',
  '1st Thessalonians': '1 Thessalonians', '2nd Thessalonians': '2 Thessalonians',
  '1st Timothy': '1 Timothy', '2nd Timothy': '2 Timothy',
  '1st Peter': '1 Peter', '2nd Peter': '2 Peter',
  '1st John': '1 John', '2nd John': '2 John', '3rd John': '3 John',
  'Song of Songs': 'Song of Solomon',
};

const OT_BOOKS = new Set([
  'genesis','exodus','leviticus','numbers','deuteronomy','joshua','judges','ruth',
  '1 samuel','2 samuel','1 kings','2 kings','1 chronicles','2 chronicles','ezra',
  'nehemiah','esther','job','psalms','proverbs','ecclesiastes','song of solomon',
  'isaiah','jeremiah','lamentations','ezekiel','daniel','hosea','joel','amos',
  'obadiah','jonah','micah','nahum','habakkuk','zephaniah','haggai','zechariah','malachi',
]);

const DRY_RUN = process.argv.includes('--dry-run');
const SKIP_AUDIO = process.argv.includes('--skip-audio');

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const s3 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_ENDPOINT!,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});

/** Title patterns that indicate a chapter-specific episode, not an overview */
function isChapterEpisode(title: string): boolean {
  // "Genesis 1:", "Exodus 12:", "1 Samuel 3:", etc.
  return /\b\d+:/.test(title) || /Chapter \d+/i.test(title);
}

function normalizeBookName(raw: string): string {
  const t = (raw || '').trim();
  return BOOK_ALIASES[t] ?? t;
}

function buildThumbnailUrl(filename: string | null): string | null {
  if (!filename) return null;
  const base = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
  return `${base}/storage/v1/object/public/thumbnails/${encodeURIComponent(filename)}`;
}

async function existsInR2(key: string): Promise<boolean> {
  try {
    await s3.send(new HeadObjectCommand({ Bucket: process.env.R2_BUCKET!, Key: key }));
    return true;
  } catch { return false; }
}

async function uploadToR2(localPath: string, key: string): Promise<void> {
  const stream = fs.createReadStream(localPath);
  const size = fs.statSync(localPath).size;
  await s3.send(new PutObjectCommand({
    Bucket: process.env.R2_BUCKET!,
    Key: key,
    Body: stream,
    ContentType: 'audio/mp4',
    ContentLength: size,
  }));
}

async function main() {
  // ── 1. Parse CSV ──────────────────────────────────────────────────────────
  const content = fs.readFileSync(CSV_PATH, 'utf-8');
  const rows: CsvRow[] = parse(content, {
    columns: true, skip_empty_lines: true, trim: true, bom: true, relax_column_count: true,
  });

  // Build audio index: episode_number → first alphabetical filename
  const audioIndex = new Map<number, string>();
  for (const file of fs.readdirSync(AUDIO_DIR).sort()) {
    if (!file.endsWith('.m4a')) continue;
    const m = file.match(/^(\d+)/);
    if (!m) continue;
    const n = parseInt(m[1], 10);
    if (!audioIndex.has(n)) audioIndex.set(n, file);
  }

  // Collect overview rows (deduplicated per BookName, prefer rows with more data)
  const overviewByBook = new Map<string, CsvRow>();
  for (const row of rows) {
    const rawBook = row['BookName']?.trim();
    if (!rawBook) continue;
    const title = row['Title'] || '';
    if (isChapterEpisode(title)) continue; // skip chapter episodes
    const book = normalizeBookName(rawBook);
    const existing = overviewByBook.get(book);
    // Prefer rows with a file name and a processed flag
    if (!existing || row['File Name'] > (existing['File Name'] || '')) {
      overviewByBook.set(book, row);
    }
  }

  // Sort books in canonical order for stable episode IDs
  const canonicalOrder = [
    'Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua','Judges','Ruth',
    '1 Samuel','2 Samuel','1 Kings','2 Kings','1 Chronicles','2 Chronicles','Ezra',
    'Nehemiah','Esther','Job','Psalms','Proverbs','Ecclesiastes','Song of Solomon',
    'Isaiah','Jeremiah','Lamentations','Ezekiel','Daniel','Hosea','Joel','Amos',
    'Obadiah','Jonah','Micah','Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi',
    'Matthew','Mark','Luke','John','Acts','Romans','1 Corinthians','2 Corinthians',
    'Galatians','Ephesians','Philippians','Colossians','1 Thessalonians','2 Thessalonians',
    '1 Timothy','2 Timothy','Titus','Philemon','Hebrews','James','1 Peter','2 Peter',
    '1 John','2 John','3 John','Jude','Revelation',
  ];

  const overviews = canonicalOrder
    .filter(b => overviewByBook.has(b))
    .map((book, idx) => ({ book, idx: idx + 1, row: overviewByBook.get(book)! }));

  console.log(`Found ${overviews.length} overview episodes\n`);
  if (DRY_RUN) console.log('[DRY RUN] Nothing will be written.\n');

  let dbUpserted = 0, audioUploaded = 0, audioSkipped = 0, errors = 0;

  for (const { book, idx, row } of overviews) {
    const episodeNumber = OVERVIEW_EP_OFFSET + idx; // 5001–5066
    const csvEpNumber = parseInt(row['Episode Number'] || '0', 10);
    const fileName = row['File Name']?.trim() || null;
    const testament = OT_BOOKS.has(book.toLowerCase()) ? 'OT' : 'NT';
    const r2Key = `audio/${episodeNumber}.m4a`;
    const audioUrl = `${process.env.R2_PUBLIC_URL}/audio/${episodeNumber}.m4a`;

    // ── 2. Upload audio to R2 ────────────────────────────────────────────
    if (!SKIP_AUDIO && !DRY_RUN) {
      // Try the CSV file name first, then fall back to audio index using the original ep number
      let localFile = fileName
        ? path.join(AUDIO_DIR, fileName)
        : (audioIndex.has(csvEpNumber) ? path.join(AUDIO_DIR, audioIndex.get(csvEpNumber)!) : null);

      // Fallback: find any file starting with "{csvEpNumber} " that does NOT have a chapter number
      if (!localFile || !fs.existsSync(localFile)) {
        const overviewFile = fs.readdirSync(AUDIO_DIR)
          .sort()
          .find(f => f.startsWith(`${csvEpNumber} `) && f.endsWith('.m4a') && !/ \d+[_.]/.test(f.slice(f.indexOf(' ') + 1)));
        localFile = overviewFile ? path.join(AUDIO_DIR, overviewFile) : null;
      }

      if (localFile && fs.existsSync(localFile)) {
        if (await existsInR2(r2Key)) {
          process.stdout.write(`  ✓ Audio already in R2: ${r2Key}\n`);
          audioSkipped++;
        } else {
          process.stdout.write(`  ↑ Uploading ${path.basename(localFile)} → ${r2Key} ... `);
          try {
            await uploadToR2(localFile, r2Key);
            process.stdout.write('done\n');
            audioUploaded++;
          } catch (err) {
            process.stdout.write(`FAILED: ${(err as Error).message}\n`);
            errors++;
          }
        }
      } else {
        console.warn(`  ⚠ No audio file found for ${book} (ep ${csvEpNumber})`);
      }
    }

    // ── 3. Upsert into Supabase ──────────────────────────────────────────
    const record = {
      episode_number: episodeNumber,
      title: row['Title'] || `${book} Overview`,
      description: row['Description'] || null,
      publish_date: null,
      file_name: fileName,
      audio_url: audioUrl,
      thumbnail_url: buildThumbnailUrl(row['Thumbnail'] || null),
      youtube_url: row['YouTubeURL'] || null,
      scripture_reference: book,
      book_name: book,
      chapter_number: 0,   // sentinel: overview episode
      testament,
      transcript: row['Transcript'] || null,
      premium: false,
      processed: true,
    };

    if (DRY_RUN) {
      console.log(`  [DRY RUN] Would upsert ep ${episodeNumber}: ${record.title.slice(0, 60)}`);
      continue;
    }

    const { error } = await supabase.from('episodes').upsert(record, { onConflict: 'episode_number' });
    if (error) {
      console.error(`  ✗ DB error for ${book}: ${error.message}`);
      errors++;
    } else {
      console.log(`  ✓ DB: ep ${episodeNumber} — ${book}`);
      dbUpserted++;
    }
  }

  console.log('\n=== Import Complete ===');
  console.log(`  DB upserted:     ${dbUpserted}`);
  console.log(`  Audio uploaded:  ${audioUploaded}`);
  console.log(`  Audio skipped:   ${audioSkipped}`);
  console.log(`  Errors:          ${errors}`);
}

main().catch(err => { console.error(err); process.exit(1); });
