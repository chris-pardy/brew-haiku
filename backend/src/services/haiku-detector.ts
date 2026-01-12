import dictionary from "../data/syllable-dictionary.json";

const HAIKU_SIGNATURE = "via @brew-haiku.app";

// Common English stop words for language detection
const STOP_WORDS = new Set([
  "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
  "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
  "be", "have", "has", "had", "do", "does", "did", "will", "would",
  "could", "should", "may", "might", "must", "can", "this", "that",
  "it", "not", "no", "so", "if", "my", "your", "his", "her", "its",
  "our", "their", "i", "you", "he", "she", "we", "they", "me", "him",
  "us", "them",
]);

export interface HaikuResult {
  isHaiku: boolean;
  hasSignature: boolean;
  lineSyllables?: [number, number, number];
  lineWords?: [string[], string[], string[]];
  rejectionReason?: string;
}

/** Strip haiku signature, hashtags, and collapse whitespace. */
export function cleanText(text: string): string {
  let cleaned = text;

  // Remove "via @brew-haiku.app" suffix
  const sigIdx = cleaned.lastIndexOf(HAIKU_SIGNATURE);
  if (sigIdx !== -1) {
    cleaned = cleaned.slice(0, sigIdx);
  }

  // Remove hashtags
  cleaned = cleaned.replace(/#\S+/g, "");

  // Collapse whitespace (newlines become spaces too)
  cleaned = cleaned.replace(/\s+/g, " ").trim();

  return cleaned;
}

/** Reject text with non-Latin characters. */
export function isLatinScript(text: string): boolean {
  // Allow basic Latin, Latin Extended, general punctuation/symbols
  return !/[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u214F]/.test(text);
}

/** Convert a number 0-9999 to English words. */
export function numberToWords(n: number): string {
  if (n < 0 || n > 9999 || !Number.isInteger(n)) return String(n);

  const ones = [
    "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
    "seventeen", "eighteen", "nineteen",
  ];
  const tens = [
    "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
  ];

  if (n === 0) return "zero";

  let result = "";

  if (n >= 1000) {
    result += ones[Math.floor(n / 1000)] + " thousand";
    n %= 1000;
    if (n > 0) result += " ";
  }

  if (n >= 100) {
    result += ones[Math.floor(n / 100)] + " hundred";
    n %= 100;
    if (n > 0) result += " ";
  }

  if (n >= 20) {
    result += tens[Math.floor(n / 10)];
    n %= 10;
    if (n > 0) result += " " + ones[n];
  } else if (n > 0) {
    result += ones[n];
  }

  return result;
}

/** Check that enough words are common English stop words. */
export function looksEnglish(words: string[]): boolean {
  if (words.length === 0) return false;

  const stopCount = words.filter((w) => STOP_WORDS.has(w.toLowerCase())).length;

  if (words.length < 6) {
    return stopCount >= 1;
  }
  return stopCount / words.length >= 0.15;
}

/** Count syllables for a single word using dictionary + heuristic. */
export function countWordSyllables(word: string): number {
  if (!word) return 0;

  const normalized = word.toLowerCase().replace(/[^a-z']/g, "");
  if (!normalized) return 0;

  // Dictionary lookup
  const dictCount = (dictionary.words as Record<string, number>)[normalized];
  if (dictCount !== undefined) return dictCount;

  // Contraction lookup
  const contrCount = (dictionary.contractions as Record<string, number>)[normalized];
  if (contrCount !== undefined) return contrCount;

  // Vowel-counting heuristic
  return countSyllablesHeuristic(normalized);
}

/** Vowel-based heuristic fallback for syllable counting. */
function countSyllablesHeuristic(word: string): number {
  if (!word) return 0;

  const w = word.toLowerCase();
  let count = 0;
  let prevVowel = false;

  // Count vowel groups
  for (let i = 0; i < w.length; i++) {
    const isVowel = "aeiouy".includes(w[i]);
    if (isVowel && !prevVowel) {
      count++;
    }
    prevVowel = isVowel;
  }

  // Silent e at end (but not "le" which may add syllable)
  if (w.endsWith("e") && !w.endsWith("le") && w.length > 2) {
    const beforeE = w[w.length - 2];
    if (!"aeiouy".includes(beforeE)) {
      count--;
    }
  }

  // "-ed" ending: silent unless after t or d
  if (w.endsWith("ed") && w.length > 2) {
    const beforeEd = w[w.length - 3];
    if (beforeEd !== "t" && beforeEd !== "d") {
      count--;
    }
  }

  // "-eous"/"-ious" over-count
  if (w.includes("eous") || w.includes("ious")) {
    count = Math.max(1, count - 1);
  }

  return Math.max(1, count);
}

/**
 * Find any partition of word syllable counts into 3 consecutive groups
 * matching 4-6 / 6-8 / 4-6 (±1 grace on each 5-7-5 line).
 */
export function findHaikuSplit(
  syllableCounts: number[]
): { lineSyllables: [number, number, number]; splits: [number, number] } | null {
  const n = syllableCounts.length;
  if (n < 3) return null;

  // Build prefix sums
  const prefix = new Array(n + 1);
  prefix[0] = 0;
  for (let i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + syllableCounts[i];
  }

  const total = prefix[n];
  // Total must be in range 14-20 (4+6+4 to 6+8+6)
  if (total < 14 || total > 20) return null;

  for (let i = 1; i < n; i++) {
    const line1 = prefix[i];
    if (line1 < 4) continue;
    if (line1 > 6) break;

    for (let j = i + 1; j < n; j++) {
      const line2 = prefix[j] - prefix[i];
      if (line2 < 6) continue;
      if (line2 > 8) break;

      const line3 = prefix[n] - prefix[j];
      if (line3 >= 4 && line3 <= 6) {
        return {
          lineSyllables: [line1, line2, line3],
          splits: [i, j],
        };
      }
    }
  }

  return null;
}

/** Full haiku detection pipeline. */
export function detectHaiku(text: string): HaikuResult {
  const hasSignature = text.trim().endsWith(HAIKU_SIGNATURE);
  const cleaned = cleanText(text);

  if (!cleaned) {
    return { isHaiku: false, hasSignature, rejectionReason: "empty text" };
  }

  if (!isLatinScript(cleaned)) {
    return { isHaiku: false, hasSignature, rejectionReason: "non-latin script" };
  }

  // Extract words: split on whitespace, convert numbers, strip punctuation
  const rawTokens = cleaned.split(/\s+/);
  const words: string[] = [];

  for (const token of rawTokens) {
    // Try to parse as number
    const num = Number(token.replace(/[^0-9]/g, ""));
    if (/^\d+$/.test(token) && num >= 0 && num <= 9999) {
      words.push(...numberToWords(num).split(/\s+/));
    } else {
      // Strip punctuation but keep apostrophes
      const cleaned = token.replace(/[^a-zA-Z']/g, "");
      if (cleaned && cleaned !== "'") {
        words.push(cleaned);
      }
    }
  }

  if (words.length < 3) {
    return { isHaiku: false, hasSignature, rejectionReason: "too few words" };
  }

  if (!looksEnglish(words)) {
    return { isHaiku: false, hasSignature, rejectionReason: "not english" };
  }

  const syllableCounts = words.map(countWordSyllables);
  const result = findHaikuSplit(syllableCounts);

  if (!result) {
    return { isHaiku: false, hasSignature, rejectionReason: "no valid 5-7-5 partition" };
  }

  const { lineSyllables, splits } = result;
  const lineWords: [string[], string[], string[]] = [
    words.slice(0, splits[0]),
    words.slice(splits[0], splits[1]),
    words.slice(splits[1]),
  ];

  return { isHaiku: true, hasSignature, lineSyllables, lineWords };
}
