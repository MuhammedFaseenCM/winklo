export const MIN_NOUN_COUNT = 80;
export const TARGET_NOUN_COUNT = 150;

const NOUN_RE = /^[a-z]{3,5}$/;

export function normalizeNouns(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const set = new Set<string>();
  for (const item of input) {
    if (typeof item !== 'string') continue;
    const w = item.trim().toLowerCase();
    if (NOUN_RE.test(w)) set.add(w);
  }
  return [...set].sort();
}

export function hasEnoughNouns(words: string[]): boolean {
  return words.length >= MIN_NOUN_COUNT;
}
