#!/usr/bin/env node
// Usage: node test/distinct.mjs [files...]  (default: the four promo puzzles)
// Exits 1 if any two puzzles share a path (or its reverse), numbered-cell set, or wall set.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const files = process.argv.length > 2 ? process.argv.slice(2)
  : ['zip-puzzle.json', 'zip-puzzle-b.json', 'zip-puzzle-c.json', 'zip-puzzle-d.json'].map((f) => join(root, f));
const k = ([r, c]) => `${r},${c}`;
const sig = (f) => {
  const p = JSON.parse(readFileSync(f, 'utf8'));
  const path = p.path.map(k);
  return {
    f,
    path: path.join(';'),
    rev: [...path].reverse().join(';'),
    nums: p.numbers.map((x) => k([x.r, x.c])).sort().join(';'),
    walls: (p.walls || []).map((w) => [k(w.a), k(w.b)].sort().join('|')).sort().join(';'),
  };
};
const s = files.map(sig);
let bad = 0;
for (let i = 0; i < s.length; i++) for (let j = i + 1; j < s.length; j++) {
  const [a, b] = [s[i], s[j]];
  if (a.path === b.path || a.path === b.rev) { console.error(`SAME PATH: ${a.f} / ${b.f}`); bad++; }
  if (a.nums === b.nums) { console.error(`SAME NUMBER CELLS: ${a.f} / ${b.f}`); bad++; }
  if (a.walls === b.walls) { console.error(`SAME WALLS: ${a.f} / ${b.f}`); bad++; }
}
if (bad) process.exit(1);
console.log(`distinct OK: ${s.length} puzzles`);
