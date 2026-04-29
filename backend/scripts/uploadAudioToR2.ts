/**
 * Upload all .m4a audio files to Cloudflare R2 and update Supabase audio_url values.
 *
 * Usage:
 *   npx ts-node scripts/uploadAudioToR2.ts
 *
 * Options:
 *   --dry-run    List files that would be uploaded without actually uploading
 *   --skip-db    Upload files but skip updating Supabase audio_url
 */

import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { S3Client, HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: path.join(__dirname, '../.env') });

const {
  R2_ENDPOINT,
  R2_ACCESS_KEY_ID,
  R2_SECRET_ACCESS_KEY,
  R2_BUCKET,
  R2_PUBLIC_URL,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  AUDIO_EPISODES_PATH,
} = process.env;

// Validate required env vars
const missing = [
  'R2_ENDPOINT', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY',
  'R2_BUCKET', 'R2_PUBLIC_URL', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'AUDIO_EPISODES_PATH',
].filter(k => !process.env[k]);
if (missing.length) {
  console.error('Missing env vars:', missing.join(', '));
  process.exit(1);
}

const DRY_RUN = process.argv.includes('--dry-run');
const SKIP_DB = process.argv.includes('--skip-db');
const CONCURRENCY = 5; // parallel uploads

const s3 = new S3Client({
  region: 'auto',
  endpoint: R2_ENDPOINT!,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID!,
    secretAccessKey: R2_SECRET_ACCESS_KEY!,
  },
});

const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);

/** Extract the episode number (leading digits) from a filename like "123 Episode Title.m4a" */
function extractEpisodeNumber(filename: string): number | null {
  const match = filename.match(/^(\d+)/);
  return match ? parseInt(match[1], 10) : null;
}

/** Check if an object already exists in R2 */
async function existsInR2(key: string): Promise<boolean> {
  try {
    await s3.send(new HeadObjectCommand({ Bucket: R2_BUCKET!, Key: key }));
    return true;
  } catch {
    return false;
  }
}

/** Upload a single file to R2 */
async function uploadFile(localPath: string, key: string): Promise<void> {
  const fileStream = fs.createReadStream(localPath);
  const stat = fs.statSync(localPath);
  await s3.send(new PutObjectCommand({
    Bucket: R2_BUCKET!,
    Key: key,
    Body: fileStream,
    ContentType: 'audio/mp4',
    ContentLength: stat.size,
  }));
}

/** Update audio_url in Supabase for a given episode number */
async function updateSupabaseUrl(episodeNumber: number, publicUrl: string): Promise<void> {
  const { error } = await supabase
    .from('episodes')
    .update({ audio_url: publicUrl })
    .eq('episode_number', episodeNumber);
  if (error) throw new Error(`Supabase update failed for ep ${episodeNumber}: ${error.message}`);
}

/** Run up to `concurrency` async tasks at a time */
async function runWithConcurrency<T>(
  tasks: Array<() => Promise<T>>,
  concurrency: number
): Promise<void> {
  let index = 0;
  async function worker() {
    while (index < tasks.length) {
      const task = tasks[index++];
      await task();
    }
  }
  await Promise.all(Array.from({ length: concurrency }, worker));
}

async function main() {
  const audioDir = AUDIO_EPISODES_PATH!;

  if (!fs.existsSync(audioDir)) {
    console.error(`Audio directory not found: ${audioDir}`);
    process.exit(1);
  }

  const allFiles = fs.readdirSync(audioDir)
    .filter(f => f.endsWith('.m4a'))
    .sort(); // alphabetical — same order as media.ts findAudioPathForEpisode

  // Deduplicate: for each episode number, keep only the first alphabetical match
  // (mirrors the behavior of findAudioPathForEpisode in media.ts)
  const episodeMap = new Map<number, string>();
  for (const filename of allFiles) {
    const epNum = extractEpisodeNumber(filename);
    if (epNum !== null && !episodeMap.has(epNum)) {
      episodeMap.set(epNum, filename);
    }
  }

  const files = Array.from(episodeMap.entries()).sort((a, b) => a[0] - b[0]);
  const skippedDuplicates = allFiles.length - files.length;

  console.log(`Found ${allFiles.length} .m4a files → ${files.length} unique episodes` +
    (skippedDuplicates > 0 ? ` (${skippedDuplicates} duplicates skipped)` : ''));
  if (DRY_RUN) console.log('[DRY RUN] No files will be uploaded or DB updated.\n');

  let uploaded = 0;
  let skipped = 0;
  let failed = 0;
  let dbUpdated = 0;

  const tasks = files.map(([episodeNumber, filename]) => async () => {

    const localPath = path.join(audioDir, filename);
    const r2Key = `audio/${episodeNumber}.m4a`;
    const publicUrl = `${R2_PUBLIC_URL}/audio/${episodeNumber}.m4a`;

    if (DRY_RUN) {
      console.log(`  [DRY RUN] Would upload: ${filename} → ${r2Key}`);
      return;
    }

    try {
      const alreadyExists = await existsInR2(r2Key);
      if (alreadyExists) {
        process.stdout.write(`  ✓ Already exists: ${r2Key}\n`);
        skipped++;
      } else {
        process.stdout.write(`  ↑ Uploading: ${filename} → ${r2Key} ... `);
        await uploadFile(localPath, r2Key);
        process.stdout.write('done\n');
        uploaded++;
      }

      if (!SKIP_DB) {
        await updateSupabaseUrl(episodeNumber, publicUrl);
        dbUpdated++;
      }
    } catch (err) {
      console.error(`  ✗ FAILED: ${filename} — ${(err as Error).message}`);
      failed++;
    }
  });

  await runWithConcurrency(tasks, CONCURRENCY);

  console.log('\n=== Upload Complete ===');
  console.log(`  Uploaded:    ${uploaded}`);
  console.log(`  Skipped:     ${skipped}`);
  console.log(`  Failed:      ${failed}`);
  if (!SKIP_DB) console.log(`  DB updated:  ${dbUpdated}`);
}

main();
