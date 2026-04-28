import { runSync } from '../services/sheetsSync';

// Can be run directly: ts-node src/jobs/syncJob.ts
async function main() {
  console.log(`[${new Date().toISOString()}] Starting manual sync...`);
  const result = await runSync();
  console.log('Sync result:', result);
  process.exit(result.errors.length > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Sync job failed:', err);
  process.exit(1);
});
