import { FALLBACK_NOUNS } from './fallback_nouns';
import {
  MIN_NOUN_COUNT,
  TARGET_NOUN_COUNT,
  normalizeNouns,
} from './nouns';

/** Current Workers AI catalog — plain llama-3.1-8b-instruct is deprecated. */
const MODEL = '@cf/meta/llama-3.2-3b-instruct';

const PROMPT = `List ${TARGET_NOUN_COUNT} common English NOUNS as a JSON array.
Each item: lowercase letters a-z only, length exactly 3 or 4 or 5 characters.
Include many 3-letter and 4-letter nouns (cat, dog, tree, bird, stone, river…).
Output ONLY the JSON array. No markdown fences. No commentary.`;

export async function generateNounCandidates(
  ai: Ai,
  dateId: string,
): Promise<string[]> {
  const merged = new Set<string>();
  try {
    for (let attempt = 0; attempt < 3; attempt++) {
      const batch = await runOnce(ai, attempt);
      for (const w of batch) merged.add(w);
      if (merged.size >= MIN_NOUN_COUNT) break;
    }
  } catch {
    // Fall through to filler below.
  }

  // Guarantee a cacheable pool; shuffle filler by dateId for daily variety.
  for (const w of shuffleForDate(FALLBACK_NOUNS, dateId)) {
    if (merged.size >= TARGET_NOUN_COUNT) break;
    merged.add(w);
  }

  return [...merged].sort();
}

function shuffleForDate(
  words: readonly string[],
  dateId: string,
): string[] {
  const out = [...words];
  let seed = 0;
  for (let i = 0; i < dateId.length; i++) {
    seed = (seed * 31 + dateId.charCodeAt(i)) >>> 0;
  }
  for (let i = out.length - 1; i > 0; i--) {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    const j = seed % (i + 1);
    const tmp = out[i]!;
    out[i] = out[j]!;
    out[j] = tmp;
  }
  return out;
}

async function runOnce(ai: Ai, attempt: number): Promise<string[]> {
  const result = await ai.run(MODEL, {
    messages: [
      { role: 'system', content: 'You output a JSON array of strings only.' },
      {
        role: 'user',
        content:
          attempt === 0
            ? PROMPT
            : `${PROMPT}\nDifferent nouns than before. Focus on length 3 and 4.`,
      },
    ],
    max_tokens: 2048,
    temperature: 0.9,
  });

  const text = extractText(result);
  const json = extractJsonArray(text);
  return normalizeNouns(json);
}

function extractText(result: unknown): string {
  if (typeof result === 'string') return result;
  if (result && typeof result === 'object') {
    const r = result as Record<string, unknown>;
    if (typeof r.response === 'string') return r.response;
    if (typeof r.text === 'string') return r.text;
  }
  return '';
}

function extractJsonArray(text: string): unknown {
  const start = text.indexOf('[');
  const end = text.lastIndexOf(']');
  if (start < 0 || end < start) return [];
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
}
