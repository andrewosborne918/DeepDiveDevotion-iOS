# Deep Dive Devotions App — Setup Guide

Follow these steps in order. Each phase builds on the previous.

---

## Prerequisites

- Node.js 22+
- Xcode 16+
- A Supabase account (supabase.com — free tier is fine)
- Access to your existing Google Cloud project (where the pipeline runs)
- An Apple Developer account ($99/year) with App Store Connect access

---

## Phase 1: Supabase Setup (30 min)

### 1. Create Supabase project
1. Go to https://supabase.com and create a new project
2. Choose a strong database password and save it
3. Pick the US East region (closest to your GCS us-east5 bucket)

### 2. Run database migrations
In your Supabase project → SQL Editor, run these files IN ORDER:
```
supabase/migrations/001_initial_schema.sql
supabase/migrations/002_rls_policies.sql
supabase/migrations/003_search_indexes.sql
```

### 3. Enable Apple Sign In in Supabase
- Dashboard → Authentication → Providers → Apple
- Enter your Apple Services ID and Team ID
- Leave callback URL as-is (Supabase handles it)

### 4. Collect your Supabase credentials
- Project URL: `Settings → API → Project URL`
- Anon key: `Settings → API → Project API Keys → anon public`
- Service role key: `Settings → API → Project API Keys → service_role` (keep SECRET)

---

## Phase 2: Google Service Account (15 min)

### 1. Export the service account used by your existing Cloud Run jobs
```bash
# In Google Cloud Console → IAM → Service Accounts
# Find the service account used by your Cloud Run job
# Click → Keys → Add Key → JSON
# Download the JSON file
```

### 2. Verify it has the required scopes
The service account needs:
- Google Sheets API: read access to your spreadsheet
- Google Drive API: read access to the Thumbnails folder

### 3. Base64-encode it
```bash
base64 -i service-account-key.json | tr -d '\n'
# Copy the output — this is your GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
```

---

## Phase 3: Backend Setup (45 min)

### 1. Install dependencies
```bash
cd ~/Desktop/DeepDiveDevotions-App/backend
npm install
```

### 2. Create your .env file
```bash
cp .env.example .env
```

Fill in `.env` with:
- `SUPABASE_URL` — from Phase 1
- `SUPABASE_SERVICE_ROLE_KEY` — from Phase 1
- `GOOGLE_SERVICE_ACCOUNT_JSON_BASE64` — from Phase 2
- `GOOGLE_SHEETS_ID` — from your sheet URL: `docs.google.com/spreadsheets/d/SHEET_ID/edit`
- `DRIVE_THUMBNAILS_FOLDER_ID` — from the Thumbnails folder URL in Drive
- `GCS_BUCKET` — `deep-dive-podcast-assets` (already correct)
- `SYNC_SECRET` — run `openssl rand -hex 32` and paste the output

### 3. Migrate thumbnails to GCS (one-time)
```bash
npm run migrate-thumbnails
```
This copies all thumbnail PNGs from your Drive "Thumbnails" folder to
`gs://deep-dive-podcast-assets/thumbnails/` as public files.

### 4. Run first sync
```bash
npm run sync
```
Check the output — you should see episodes being upserted. Verify in Supabase:
- Table Editor → episodes → should have rows

If Google Sheets sync is unavailable, you can import directly from the local Main Schedule CSV:
```bash
npm run import-csv -- "../Deep Dive Devotions - Main Schedule.csv"
```

For a full import (including rows not currently marked Processed), with local-audio stream URLs:
```bash
export AUDIO_EPISODES_PATH="/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Edited Audio/Episodes"
export AUDIO_STREAM_BASE_URL="http://localhost:3000"
npm run import-csv -- "../Deep Dive Devotions - Main Schedule.csv"
```

Preview import results without writing to Supabase:
```bash
npm run import-csv -- "../Deep Dive Devotions - Main Schedule.csv" --dry-run
```

You can also validate content readiness (testament/book/chapter/transcript coverage) from CSV without live services:
```bash
npm run verify-content -- csv "../Deep Dive Devotions - Main Schedule.csv"
```

Limit this check to only rows marked Processed:
```bash
npm run verify-content -- csv "../Deep Dive Devotions - Main Schedule.csv" --processed-only
```

Or validate directly against Supabase after import/sync:
```bash
npm run verify-content -- supabase
```

### 5. Start the dev server
```bash
npm run dev
```

### 6. Test the API
```bash
curl http://localhost:3000/health
curl "http://localhost:3000/v1/episodes?limit=5"
curl "http://localhost:3000/v1/episodes/books"
curl "http://localhost:3000/v1/search?q=genesis+creation"
```

---

## Phase 4: App Store Connect Setup (30 min)

### 1. Register your bundle ID
- App Store Connect → Certificates, IDs & Profiles → Identifiers
- Register `com.deepdivedevotions`
- Enable: In-App Purchase, Sign In with Apple, Push Notifications, Background Modes

### 2. Create your app in App Store Connect
- My Apps → + → New App
- Bundle ID: `com.deepdivedevotions`
- SKU: `deep-dive-devotions`

### 3. Create subscription products
- Your App → In-App Purchases → Manage → +
- Product 1: Auto-Renewable Subscription
  - Reference Name: `Deep Dive Monthly`
  - Product ID: `com.deepdivedevotions.monthly`
  - Price: $4.99/month
- Product 2: Auto-Renewable Subscription
  - Reference Name: `Deep Dive Annual`
  - Product ID: `com.deepdivedevotions.annual`
  - Price: $39.99/year
  - Add 3-day free trial

### 4. Create App Store Server API key (.p8)
- App Store Connect → Users and Access → Integrations → In-App Purchase
- Generate a key, download the .p8 file
- Note your Key ID and Issuer ID

### 5. Base64-encode the .p8 key
```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```
Add to your backend `.env`:
- `APP_STORE_KEY_ID` = your key ID
- `APP_STORE_ISSUER_ID` = your issuer ID
- `APP_STORE_PRIVATE_KEY_BASE64` = the base64 output above

---

## Phase 5: iOS App Setup (60 min)

### 1. Open in Xcode
```bash
open ~/Desktop/DeepDiveDevotions-App/ios/DeepDiveDevotions/
```
Or create a new Xcode project:
- Open Xcode → Create New Project → iOS → App
- Product Name: `DeepDiveDevotions`
- Bundle Identifier: `com.deepdivedevotions`
- Interface: SwiftUI
- Language: Swift
- Save to: `~/Desktop/DeepDiveDevotions-App/ios/`

Then add all the Swift files from this repo to the project.

### 2. Add Swift Package dependency
- File → Add Package Dependencies
- URL: `https://github.com/supabase-community/supabase-swift`
- Version: Up to Next Major from `2.0.0`
- Add `Supabase` to your target

### 3. Configure xcconfig files
Edit `App/Debug.xcconfig`:
```
API_BASE_URL = http://localhost:3000/v1
SUPABASE_URL = https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY = eyJhbGc...
```

In Xcode project settings → Info → Configurations:
- Debug → set to `Debug.xcconfig`
- Release → set to `Release.xcconfig`

### 4. Enable capabilities in Xcode
Target → Signing & Capabilities → + Capability:
- Sign In with Apple
- In-App Purchase
- Background Modes → check "Audio, AirPlay, and Picture in Picture"
- Push Notifications (for future use)

### 5. Add StoreKit configuration file (for sandbox testing)
- File → New File → StoreKit Configuration File
- Add your two products with the same product IDs
- Scheme → Edit Scheme → Run → Options → StoreKit Configuration → select your file

### 6. Build and run on simulator
```
⌘ + R
```

---

## Phase 6: Cloud Scheduler for Auto-Sync (15 min)

After deploying your backend (e.g., Cloud Run or Railway):

```bash
# Google Cloud Scheduler — hourly sync
gcloud scheduler jobs create http deep-dive-sync \
  --schedule="0 * * * *" \
  --uri="https://your-backend-url/internal/sync" \
  --http-method=POST \
  --headers="X-Sync-Secret=YOUR_SYNC_SECRET" \
  --location=us-east5
```

---

## Deployment Options

### Option A: Deploy backend to Cloud Run (recommended — already familiar)
```bash
cd backend
docker build -t us-east5-docker.pkg.dev/YOUR_PROJECT/deep-dive-devotions/api:latest .
docker push us-east5-docker.pkg.dev/YOUR_PROJECT/deep-dive-devotions/api:latest

gcloud run deploy deep-dive-api \
  --image=us-east5-docker.pkg.dev/YOUR_PROJECT/deep-dive-devotions/api:latest \
  --region=us-east5 \
  --platform=managed \
  --allow-unauthenticated \
  --set-env-vars="SUPABASE_URL=...,SUPABASE_SERVICE_ROLE_KEY=...,..."
```

### Option B: Railway (simpler, no GCP needed)
1. Go to railway.app
2. New Project → Deploy from GitHub
3. Add env vars in Railway dashboard
4. Railway auto-deploys on push

---

## Verification Checklist

- [ ] `npm run sync` shows episodes upserted
- [ ] `curl localhost:3000/v1/episodes` returns JSON with episodes
- [ ] Audio URLs in response point to valid GCS files
- [ ] Thumbnail URLs in response return 200 OK
- [ ] iOS simulator shows episode list on Home tab
- [ ] Tapping an episode opens detail view
- [ ] Play Audio button starts playback from GCS
- [ ] Lock screen controls work
- [ ] Paywall appears for premium episodes when not subscribed
- [ ] StoreKit sandbox purchase succeeds and unlocks content
- [ ] Favorites save and persist between sessions
- [ ] Search returns relevant results with snippets

---

## Environment Variables Reference

### Backend (.env)
| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (SECRET — backend only) |
| `GOOGLE_SERVICE_ACCOUNT_JSON_BASE64` | Base64-encoded service account JSON |
| `GOOGLE_SHEETS_ID` | Spreadsheet ID from the URL |
| `GCS_BUCKET` | `deep-dive-podcast-assets` |
| `DRIVE_THUMBNAILS_FOLDER_ID` | Drive folder ID for thumbnails |
| `APP_STORE_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_KEY_ID` | .p8 key ID |
| `APP_STORE_PRIVATE_KEY_BASE64` | Base64 .p8 private key |
| `APP_BUNDLE_ID` | `com.deepdivedevotions` |
| `SYNC_SECRET` | Random secret for /internal/sync |
| `PORT` | `3000` |
| `NODE_ENV` | `development` or `production` |

### iOS (xcconfig)
| Variable | Description |
|---|---|
| `API_BASE_URL` | Backend API URL |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key (safe to include in app) |

---

## Column Mapping Reference (Google Sheet → Database)

### Main Schedule tab
| Sheet Column | DB Field | Notes |
|---|---|---|
| A | episode_number | Integer |
| B | title | Full episode title |
| C | description | Episode description |
| D | publish_date | YYYY-MM-DD |
| E | file_name | Used to construct GCS URL |
| I | processed | Must be "yes" to sync |
| J | youtube_url | Optional |

### Build tab
| Sheet Column | DB Field | Notes |
|---|---|---|
| A | (episode_number key) | Matches Main Schedule column A |
| F | transcript | Full transcript text |
