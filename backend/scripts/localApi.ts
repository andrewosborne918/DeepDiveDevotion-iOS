import express, { Request, Response } from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { parse } from 'csv-parse/sync';
import { parseScriptureReference } from '../src/services/scriptureParser';

type CsvRow = Record<string, string>;

type Episode = {
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
  locked: boolean;
};

const PORT = parseInt(process.env.LOCAL_API_PORT || '3100', 10);
const CSV_PATH = process.env.LOCAL_CSV_PATH || '/Users/aosborne1/Desktop/DeepDiveDevotions-App/Deep Dive Devotions - Main Schedule.csv';
const AUDIO_DIR = process.env.AUDIO_EPISODES_PATH || '/Users/aosborne1/Library/CloudStorage/GoogleDrive-andrewosborne918@gmail.com/My Drive/Deep Dive Devotions/Edited Audio/Episodes';
const BASE_URL = `http://localhost:${PORT}`;

const app = express();
app.use(cors({ origin: '*' }));

function normalizeBool(raw: string): boolean {
  const value = (raw || '').trim().toLowerCase();
  return ['yes', 'true', '1', 'y'].includes(value);
}

function normalizeDate(raw: string): string | null {
  if (!raw || !raw.trim()) return null;
  const trimmed = raw.trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
  const d = new Date(trimmed);
  if (!isNaN(d.getTime())) return d.toISOString().split('T')[0];
  return trimmed;
}

function readRows(csvPath: string): CsvRow[] {
  const content = fs.readFileSync(csvPath, 'utf-8');
  return parse(content, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
    bom: true,
    relax_column_count: true,
  }) as CsvRow[];
}

function buildAudioMap(audioDir: string): Map<number, string> {
  const map = new Map<number, string>();
  if (!fs.existsSync(audioDir)) return map;

  for (const name of fs.readdirSync(audioDir)) {
    if (!name.toLowerCase().endsWith('.m4a')) continue;
    const match = name.match(/^(\d+)\s+/);
    if (!match) continue;
    const ep = parseInt(match[1], 10);
    if (!isNaN(ep) && !map.has(ep)) map.set(ep, name);
  }
  return map;
}

function chooseChapterRow(rows: CsvRow[]): CsvRow {
  const withChapter = rows.find((row) => {
    const title = row['Title'] || '';
    const parsed = parseScriptureReference(title);
    return parsed.chapterNumber != null;
  });
  return withChapter || rows[rows.length - 1];
}

function buildEpisodes(): Episode[] {
  const rows = readRows(CSV_PATH);
  const grouped = new Map<number, CsvRow[]>();
  const audioMap = buildAudioMap(AUDIO_DIR);

  for (const row of rows) {
    const num = parseInt(row['Episode Number'] || '', 10);
    if (isNaN(num)) continue;
    if (!grouped.has(num)) grouped.set(num, []);
    grouped.get(num)?.push(row);
  }

  const episodes: Episode[] = [];

  for (const [episodeNumber, group] of grouped.entries()) {
    const row = chooseChapterRow(group);
    const title = (row['Title'] || '').trim();
    if (!title) continue;

    const parsed = parseScriptureReference(title);
    const fileName = ((row['File Name'] || '').trim() || audioMap.get(episodeNumber) || null);

    episodes.push({
      id: String(episodeNumber),
      episode_number: episodeNumber,
      title,
      description: (row['Description'] || '').trim() || null,
      publish_date: normalizeDate(row['Publish Date'] || ''),
      file_name: fileName,
      audio_url: fileName ? `${BASE_URL}/v1/media/audio/${episodeNumber}` : null,
      video_url: null,
      youtube_url: (row['YouTubeURL'] || '').trim() || null,
      thumbnail_url: (row['Thumbnail'] || '').trim() || null,
      scripture_reference: parsed.chapterNumber ? `${parsed.bookName} ${parsed.chapterNumber}` : parsed.bookName,
      book_name: parsed.bookName,
      chapter_number: parsed.chapterNumber,
      testament: parsed.testament,
      transcript: (row['Transcript'] || '').trim() || null,
      premium: false,
      processed: normalizeBool(row['Processed'] || ''),
      locked: false,
    });
  }

  return episodes.sort((a, b) => a.episode_number - b.episode_number);
}

let episodes = buildEpisodes();
console.log(`Loaded ${episodes.length} episodes from CSV`);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', source: 'local-csv' });
});

app.get('/v1/episodes', (req: Request, res: Response) => {
  const page = Math.max(1, parseInt((req.query.page as string) || '1', 10));
  const limit = Math.max(1, Math.min(100, parseInt((req.query.limit as string) || '20', 10)));
  const book = (req.query.book as string) || null;
  const testament = (req.query.testament as string) || null;
  const sort = (req.query.sort as string) || 'episode_number';
  const order = ((req.query.order as string) || 'asc').toLowerCase();

  let filtered = [...episodes];
  if (book) filtered = filtered.filter((ep) => ep.book_name?.toLowerCase() === book.toLowerCase());
  if (testament) filtered = filtered.filter((ep) => ep.testament === testament);

  if (sort === 'episode_number') filtered.sort((a, b) => a.episode_number - b.episode_number);
  if (sort === 'title') filtered.sort((a, b) => a.title.localeCompare(b.title));
  if (sort === 'publish_date') filtered.sort((a, b) => (a.publish_date || '').localeCompare(b.publish_date || ''));
  if (order === 'desc') filtered.reverse();

  const offset = (page - 1) * limit;
  const data = filtered.slice(offset, offset + limit);

  res.json({
    data,
    meta: {
      page,
      limit,
      total: filtered.length,
      total_pages: Math.ceil(filtered.length / limit),
    },
  });
});

app.get('/v1/episodes/books', (_req, res) => {
  const map = new Map<string, { book_name: string; testament: string; episode_count: number }>();

  for (const ep of episodes) {
    if (!ep.book_name || !ep.testament) continue;
    if (!map.has(ep.book_name)) {
      map.set(ep.book_name, { book_name: ep.book_name, testament: ep.testament, episode_count: 0 });
    }
    map.get(ep.book_name)!.episode_count += 1;
  }

  res.json({ data: Array.from(map.values()) });
});

app.get('/v1/episodes/book/:bookName', (req, res) => {
  const { bookName } = req.params;
  const filtered = episodes.filter((ep) => ep.book_name?.toLowerCase() === bookName.toLowerCase());
  res.json({ book_name: bookName, episodes: filtered });
});

app.get('/v1/episodes/:id', (req, res) => {
  const { id } = req.params;
  const ep = episodes.find((item) => item.id === id || item.episode_number === parseInt(id, 10));
  if (!ep) {
    res.status(404).json({ error: 'Episode not found' });
    return;
  }
  res.json(ep);
});

app.get('/v1/media/audio/:episodeNumber', (req, res) => {
  const episodeNumber = parseInt(req.params.episodeNumber, 10);
  if (isNaN(episodeNumber)) {
    res.status(400).json({ error: 'Invalid episode number' });
    return;
  }

  const fileName = buildAudioMap(AUDIO_DIR).get(episodeNumber);
  if (!fileName) {
    res.status(404).json({ error: 'Audio file not found' });
    return;
  }

  const filePath = path.join(AUDIO_DIR, fileName);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: 'Audio file missing' });
    return;
  }

  const stat = fs.statSync(filePath);
  const total = stat.size;
  const range = req.headers.range;

  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Content-Type', 'audio/mp4');

  if (!range) {
    res.setHeader('Content-Length', total);
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  const match = range.match(/bytes=(\d*)-(\d*)/);
  if (!match) {
    res.status(416).json({ error: 'Invalid range' });
    return;
  }

  const start = match[1] ? parseInt(match[1], 10) : 0;
  const end = match[2] ? parseInt(match[2], 10) : total - 1;
  if (start > end || end >= total) {
    res.status(416).json({ error: 'Requested range not satisfiable' });
    return;
  }

  res.status(206);
  res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
  res.setHeader('Content-Length', end - start + 1);

  fs.createReadStream(filePath, { start, end }).pipe(res);
});

app.post('/v1/internal/reload', (_req, res) => {
  episodes = buildEpisodes();
  res.json({ ok: true, episodes: episodes.length });
});

app.listen(PORT, () => {
  console.log(`Local CSV API running at http://localhost:${PORT}`);
});
