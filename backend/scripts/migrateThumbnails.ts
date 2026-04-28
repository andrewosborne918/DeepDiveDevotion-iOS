/**
 * One-time script: Copy thumbnail PNGs from Google Drive "Thumbnails" folder
 * to GCS bucket at gs://deep-dive-podcast-assets/thumbnails/
 *
 * Usage: ts-node scripts/migrateThumbnails.ts
 * Requires: GOOGLE_SERVICE_ACCOUNT_JSON_BASE64, GCS_BUCKET, DRIVE_THUMBNAILS_FOLDER_ID
 */
import { google } from 'googleapis';
import { Storage } from '@google-cloud/storage';
import dotenv from 'dotenv';
import path from 'path';
import { Readable } from 'stream';

dotenv.config({ path: path.join(__dirname, '../.env') });

const GCS_BUCKET = process.env.GCS_BUCKET || 'deep-dive-podcast-assets';
const THUMBNAILS_PREFIX = 'thumbnails/';
const DRIVE_FOLDER_ID = process.env.DRIVE_THUMBNAILS_FOLDER_ID!;

if (!DRIVE_FOLDER_ID) {
  console.error('Missing DRIVE_THUMBNAILS_FOLDER_ID environment variable');
  process.exit(1);
}

function getCredentials() {
  const base64 = process.env.GOOGLE_SERVICE_ACCOUNT_JSON_BASE64!;
  if (!base64) throw new Error('Missing GOOGLE_SERVICE_ACCOUNT_JSON_BASE64');
  return JSON.parse(Buffer.from(base64, 'base64').toString('utf-8'));
}

async function main() {
  const credentials = getCredentials();

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: [
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  });
  const authClient = await auth.getClient();
  const drive = google.drive({ version: 'v3', auth: authClient as never });

  // GCS storage using service account credentials
  const storage = new Storage({ credentials });
  const bucket = storage.bucket(GCS_BUCKET);

  console.log(`Listing files in Drive folder: ${DRIVE_FOLDER_ID}`);

  let pageToken: string | undefined;
  let totalMigrated = 0;
  let totalSkipped = 0;

  do {
    const response = await drive.files.list({
      q: `'${DRIVE_FOLDER_ID}' in parents and mimeType='image/png' and trashed=false`,
      fields: 'nextPageToken, files(id, name, size)',
      pageSize: 100,
      pageToken,
    });

    const files = response.data.files || [];
    console.log(`Found ${files.length} PNG files in this page`);

    for (const file of files) {
      if (!file.id || !file.name) continue;

      const gcsPath = `${THUMBNAILS_PREFIX}${file.name}`;
      const gcsFile = bucket.file(gcsPath);

      // Check if already exists in GCS
      const [exists] = await gcsFile.exists();
      if (exists) {
        console.log(`  SKIP (exists): ${file.name}`);
        totalSkipped++;
        continue;
      }

      try {
        console.log(`  Downloading: ${file.name} (${file.id})`);
        const driveResponse = await drive.files.get(
          { fileId: file.id, alt: 'media' },
          { responseType: 'stream' }
        );

        await new Promise<void>((resolve, reject) => {
          const writeStream = gcsFile.createWriteStream({
            metadata: {
              contentType: 'image/png',
              cacheControl: 'public, max-age=31536000',
            },
          });

          (driveResponse.data as Readable)
            .pipe(writeStream)
            .on('error', reject)
            .on('finish', resolve);
        });

        // Make the file publicly accessible
        await gcsFile.makePublic();

        const publicUrl = `https://storage.googleapis.com/${GCS_BUCKET}/${gcsPath}`;
        console.log(`  DONE: ${publicUrl}`);
        totalMigrated++;
      } catch (err) {
        console.error(`  ERROR migrating ${file.name}:`, (err as Error).message);
      }
    }

    pageToken = response.data.nextPageToken || undefined;
  } while (pageToken);

  console.log(`\nMigration complete!`);
  console.log(`  Migrated: ${totalMigrated}`);
  console.log(`  Skipped (already exists): ${totalSkipped}`);
  console.log(`\nThumbnails are now at:`);
  console.log(`  https://storage.googleapis.com/${GCS_BUCKET}/${THUMBNAILS_PREFIX}{filename}.png`);
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
