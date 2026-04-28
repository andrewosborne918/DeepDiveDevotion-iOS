import { ParsedScripture } from '../types';

// All 66 canonical Bible books in canonical order
const OT_BOOKS: string[] = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
  'Haggai', 'Zechariah', 'Malachi',
];

const NT_BOOKS: string[] = [
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
  '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
];

// Alternate spellings/abbreviations mapped to canonical names
const BOOK_ALIASES: Record<string, string> = {
  'psalm': 'Psalms',
  'psalms': 'Psalms',
  'song of songs': 'Song of Solomon',
  'song of solomon': 'Song of Solomon',
  'songs of solomon': 'Song of Solomon',
  'sos': 'Song of Solomon',
  'revelations': 'Revelation',
  '1st samuel': '1 Samuel',
  '2nd samuel': '2 Samuel',
  '1st kings': '1 Kings',
  '2nd kings': '2 Kings',
  '1st chronicles': '1 Chronicles',
  '2nd chronicles': '2 Chronicles',
  '1st corinthians': '1 Corinthians',
  '2nd corinthians': '2 Corinthians',
  '1st thessalonians': '1 Thessalonians',
  '2nd thessalonians': '2 Thessalonians',
  '1st timothy': '1 Timothy',
  '2nd timothy': '2 Timothy',
  '1st peter': '1 Peter',
  '2nd peter': '2 Peter',
  '1st john': '1 John',
  '2nd john': '2 John',
  '3rd john': '3 John',
};

const ALL_BOOKS = [...OT_BOOKS, ...NT_BOOKS];
const OT_SET = new Set(OT_BOOKS.map(b => b.toLowerCase()));

// Build sorted list longest-first so "Song of Solomon" matches before "Solomon"
const SORTED_BOOKS = [...ALL_BOOKS].sort((a, b) => b.length - a.length);

function canonicalize(name: string): string {
  const lower = name.toLowerCase().trim();
  return BOOK_ALIASES[lower] ?? ALL_BOOKS.find(b => b.toLowerCase() === lower) ?? name;
}

function getTestament(bookName: string): 'OT' | 'NT' {
  return OT_SET.has(bookName.toLowerCase()) ? 'OT' : 'NT';
}

/**
 * Parses a scripture reference from an episode title.
 *
 * Handles patterns like:
 *   "Genesis 1 - In the Beginning"
 *   "Genesis 1: How God Created the World"
 *   "Psalm 23 – The Lord is my Shepherd"
 *   "1 Kings 3 - Solomon's Wisdom"
 *   "Song of Solomon 1 - Introduction"
 *   "Genesis 1:1-5 The Creation Account"
 *   "John 3:16"
 */
export function parseScriptureReference(title: string): ParsedScripture {
  const titleTrimmed = title.trim();

  // Build regex pattern from all known books (longest first to avoid partial matches)
  const bookPattern = SORTED_BOOKS.map(b =>
    b.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  ).join('|');

  // Pattern: (BookName) (chapter)?(:(verse(-verse)?))? optionally followed by dash/colon/space
  const regex = new RegExp(
    `^(${bookPattern})\\s+(\\d+)(?::(\\d+(?:-\\d+)?))?`,
    'i'
  );

  const match = titleTrimmed.match(regex);

  if (match) {
    const rawBook = match[1];
    const chapterStr = match[2];
    const verseRange = match[3] ?? null;

    const bookName = canonicalize(rawBook);
    const chapterNumber = parseInt(chapterStr, 10);
    const testament = getTestament(bookName);

    let scriptureReference = `${bookName} ${chapterNumber}`;
    if (verseRange) {
      scriptureReference += `:${verseRange}`;
    }

    return { bookName, chapterNumber, verseRange, scriptureReference, testament };
  }

  // Fallback: try to match any known book name without chapter
  const bookOnlyRegex = new RegExp(`^(${bookPattern})`, 'i');
  const bookMatch = titleTrimmed.match(bookOnlyRegex);
  if (bookMatch) {
    const bookName = canonicalize(bookMatch[1]);
    const testament = getTestament(bookName);
    return {
      bookName,
      chapterNumber: null,
      verseRange: null,
      scriptureReference: bookName,
      testament,
    };
  }

  // Cannot parse — return unknown
  return {
    bookName: 'Unknown',
    chapterNumber: null,
    verseRange: null,
    scriptureReference: title,
    testament: 'OT',
  };
}

export { OT_BOOKS, NT_BOOKS, ALL_BOOKS };
