import { Router, Request, Response } from 'express';
import fs from 'fs';
import path from 'path';

const router = Router();

const DEFAULT_AUDIO_DIR =
  '/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Edited Audio/Episodes';

function getAudioDir(): string {
  return process.env.AUDIO_EPISODES_PATH || DEFAULT_AUDIO_DIR;
}

function findAudioPathForEpisode(episodeNumber: number): string | null {
  const audioDir = getAudioDir();
  if (!fs.existsSync(audioDir)) return null;

  const entries = fs.readdirSync(audioDir, { withFileTypes: true });
  const prefix = `${episodeNumber} `;

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!entry.name.toLowerCase().endsWith('.m4a')) continue;
    if (!entry.name.startsWith(prefix)) continue;
    return path.join(audioDir, entry.name);
  }

  return null;
}

router.get('/audio/:episodeNumber', (req: Request, res: Response): void => {
  const episodeNumber = parseInt(req.params.episodeNumber, 10);
  if (isNaN(episodeNumber) || episodeNumber < 1) {
    res.status(400).json({ error: 'Invalid episode number' });
    return;
  }

  const filePath = findAudioPathForEpisode(episodeNumber);
  if (!filePath || !fs.existsSync(filePath)) {
    res.status(404).json({ error: 'Audio file not found' });
    return;
  }

  const stat = fs.statSync(filePath);
  const total = stat.size;
  const range = req.headers.range;

  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Content-Type', 'audio/mp4');
  res.setHeader('Cache-Control', 'public, max-age=3600');

  if (!range) {
    res.setHeader('Content-Length', total);
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  const match = range.match(/bytes=(\d*)-(\d*)/);
  if (!match) {
    res.status(416).json({ error: 'Invalid range header' });
    return;
  }

  const start = match[1] ? parseInt(match[1], 10) : 0;
  const end = match[2] ? parseInt(match[2], 10) : total - 1;

  if (isNaN(start) || isNaN(end) || start > end || end >= total) {
    res.status(416).json({ error: 'Requested range not satisfiable' });
    return;
  }

  const chunkSize = end - start + 1;
  res.status(206);
  res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
  res.setHeader('Content-Length', chunkSize);

  fs.createReadStream(filePath, { start, end }).pipe(res);
});

export default router;
