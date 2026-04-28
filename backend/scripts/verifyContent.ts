import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { parse } from 'csv-parse/sync';
import { parseScriptureReference } from '../src/services/scriptureParser';

dotenv.config({ path: path.join(__dirname, '../.env') });

type EpisodeCheckRow = {
  bookName: string;
  chapterNumber: number | null;
  testament: 'OT' | 'NT';
  transcript: string | null;
  processed: boolean;
  fileName: string | null;
  audioUrl: string | null;
};

type CsvRow = Record<string, string>;

const DEFAULT_CSV_PATH =
  '/Users/aosborne1/Desktop/DeepDiveDevotions-App/Deep Dive Devotions - Main Schedule.csv';

const SAMPLE_BOOKS = ['Genesis', 'Exodus', 'Matthew', 'John', 'Romans', 'Revelation'];

function normalizeBool(raw: string): boolean {
  const value = (raw || '').trim().toLowerCase();
  return ['yes', 'true', '1', 'y'].includes(value);
}

function toInt(raw: string): number | null {
  const n = parseInt((raw || '').trim(), 10);
  return Number.isNaN(n) ? null : n;
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

function rowsFromCsv(csvPath: string, processedOnly: boolean): EpisodeCheckRow[] {
  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV not found at: ${csvPath}`);
  }

  const rows = readCsvRows(csvPath);
  const output: EpisodeCheckRow[] = [];

  for (const row of rows) {
    const processed = normalizeBool(row['Processed']);
    if (processedOnly && !processed) continue;

    const title = (row['Title'] || '').trim();
    if (!title) continue;

    const scripture = parseScriptureReference(title);

    output.push({
      bookName: scripture.bookName,
      chapterNumber: scripture.chapterNumber,
      testament: scripture.testament,
      transcript: (row['Transcript'] || '').trim() || null,
      processed,
      fileName: (row['File Name'] || '').trim() || null,
      audioUrl: null,
    });
  }

  return output;
}

async function rowsFromSupabase(): Promise<EpisodeCheckRow[]> {
  const { supabaseAdmin } = await import('../src/services/supabase');

  const rows: EpisodeCheckRow[] = [];
  const pageSize = 1000;
  let from = 0;

  while (true) {
    const to = from + pageSize - 1;
    const { data, error } = await supabaseAdmin
      .from('episodes')
      .select('book_name, chapter_number, testament, transcript, processed, file_name, audio_url')
      .eq('processed', true)
      .range(from, to);

    if (error) {
      throw new Error(`Supabase query failed: ${error.message}`);
    }

    if (!data || data.length === 0) break;

    for (const row of data) {
      if (!row.book_name || !row.testament) continue;
      rows.push({
        bookName: row.book_name,
        chapterNumber: row.chapter_number,
        testament: row.testament,
        transcript: row.transcript,
        processed: row.processed,
        fileName: row.file_name,
        audioUrl: row.audio_url,
      });
    }

    if (data.length < pageSize) break;
    from += pageSize;
  }

  return rows;
}

function analyze(rows: EpisodeCheckRow[], source: string): void {
  const byTestament = { OT: 0, NT: 0 };
  const books = new Map<string, Set<number>>();

  let missingTranscript = 0;
  let missingChapter = 0;
  let playableRows = 0;

  for (const row of rows) {
    byTestament[row.testament] += 1;

    if (!row.transcript || !row.transcript.trim()) {
      missingTranscript += 1;
    }

    if (row.chapterNumber == null) {
      missingChapter += 1;
    } else {
      if (!books.has(row.bookName)) books.set(row.bookName, new Set<number>());
      books.get(row.bookName)?.add(row.chapterNumber);
    }

    if ((row.audioUrl && row.audioUrl.trim()) || (row.fileName && row.fileName.trim())) {
      playableRows += 1;
    }
  }

  const total = rows.length;
  const transcriptPct = total > 0 ? ((total - missingTranscript) / total) * 100 : 0;
  const chapterPct = total > 0 ? ((total - missingChapter) / total) * 100 : 0;
  const playablePct = total > 0 ? (playableRows / total) * 100 : 0;

  console.log(`Source: ${source}`);
  console.log(`Processed episodes checked: ${total}`);
  console.log(`Testament split: OT=${byTestament.OT}, NT=${byTestament.NT}`);
  console.log(`Unique books represented: ${books.size}`);
  console.log(`Transcript coverage: ${(transcriptPct).toFixed(2)}%`);
  console.log(`Chapter parse coverage: ${(chapterPct).toFixed(2)}%`);
  console.log(`Playable row coverage (audio_url or file_name): ${(playablePct).toFixed(2)}%`);

  console.log('Sample book chapter availability:');
  for (const book of SAMPLE_BOOKS) {
    const chapters = books.get(book);
    const count = chapters ? chapters.size : 0;
    const max = chapters && chapters.size > 0 ? Math.max(...chapters) : 0;
    console.log(`  - ${book}: chapters=${count}, maxChapter=${max}`);
  }

  if (missingTranscript > 0 || missingChapter > 0) {
    console.log('Warnings:');
    if (missingTranscript > 0) {
      console.log(`  - Missing transcript rows: ${missingTranscript}`);
    }
    if (missingChapter > 0) {
      console.log(`  - Missing chapter parse rows: ${missingChapter}`);
    }
  } else {
    console.log('No transcript/chapter parsing gaps detected in processed rows.');
  }
}

async function main() {
  const mode = process.argv[2] || 'csv';
  const processedOnly = process.argv.includes('--processed-only');

  if (mode === 'supabase') {
    const rows = await rowsFromSupabase();
    analyze(rows, 'supabase');
    return;
  }

  const csvPath = process.argv[3] || DEFAULT_CSV_PATH;
  const rows = rowsFromCsv(csvPath, processedOnly);
  analyze(rows, `csv:${csvPath}`);
}

main().catch((error) => {
  console.error('Verification failed:', (error as Error).message);
  process.exit(1);
});
