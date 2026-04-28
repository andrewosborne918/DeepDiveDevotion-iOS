/**
 * Upload thumbnail PNGs from local Google Drive sync folder → Supabase Storage.
 *
 * Usage: ts-node scripts/uploadThumbnails.ts
 * Requires: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY in .env
 */
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: path.join(__dirname, '../.env') });

const THUMBNAILS_DIR =
  '/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Thumbnails';

const BUCKET = 'thumbnails';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function ensureBucket(): Promise<void> {
  const { data: buckets, error } = await supabase.storage.listBuckets();
  if (error) throw new Error(`Failed to list buckets: ${error.message}`);

  const exists = buckets.some(b => b.name === BUCKET);
  if (!exists) {
    const { error: createError } = await supabase.storage.createBucket(BUCKET, {
      public: true,
      fileSizeLimit: 5242880, // 5MB
      allowedMimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
    });
    if (createError) throw new Error(`Failed to create bucket: ${createError.message}`);
    console.log(`Created public bucket: ${BUCKET}`);
  } else {
    console.log(`Bucket "${BUCKET}" already exists`);
  }
}

async function main(): Promise<void> {
  if (!fs.existsSync(THUMBNAILS_DIR)) {
    console.error(`Thumbnails directory not found: ${THUMBNAILS_DIR}`);
    process.exit(1);
  }

  await ensureBucket();

  const files = fs.readdirSync(THUMBNAILS_DIR).filter(f => /\.(png|jpg|jpeg|webp)$/i.test(f));
  console.log(`Found ${files.length} image files to upload`);

  let uploaded = 0;
  let skipped = 0;
  let errors = 0;

  for (const filename of files) {
    const filePath = path.join(THUMBNAILS_DIR, filename);
    const fileBuffer = fs.readFileSync(filePath);
    const ext = path.extname(filename).toLowerCase();
    const contentType = ext === '.png' ? 'image/png'
      : ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg'
      : 'image/webp';

    let uploadError: { message: string } | null = null;
    for (let attempt = 1; attempt <= 3; attempt++) {
      const { error } = await supabase.storage
        .from(BUCKET)
        .upload(filename, fileBuffer, {
          contentType,
          cacheControl: '31536000',
          upsert: false,
        });
      uploadError = error;
      if (!error) break;
      if (error.message.includes('already exists') || error.message.includes('The resource already exists')) break;
      if (attempt < 3) await new Promise(r => setTimeout(r, 2000 * attempt));
    }

    if (uploadError) {
      if (uploadError.message.includes('already exists') || uploadError.message.includes('The resource already exists')) {
        skipped++;
      } else {
        console.error(`  ERROR ${filename}: ${uploadError.message}`);
        errors++;
      }
    } else {
      uploaded++;
      if (uploaded % 50 === 0) {
        console.log(`  Progress: ${uploaded + skipped}/${files.length}`);
      }
    }
  }

  console.log(`\nUpload complete!`);
  console.log(`  Uploaded: ${uploaded}`);
  console.log(`  Skipped (already exists): ${skipped}`);
  console.log(`  Errors: ${errors}`);
  console.log(`\nThumbnails are publicly available at:`);
  console.log(`  ${supabaseUrl}/storage/v1/object/public/${BUCKET}/{filename}`);
}

main().catch(err => {
  console.error('Upload failed:', (err as Error).message);
  process.exit(1);
});
