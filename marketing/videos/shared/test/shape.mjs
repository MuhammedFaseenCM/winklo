#!/usr/bin/env node
// Usage: node test/shape.mjs [files...]
// Fails (exit 1) if a puzzle has fewer than 28 turns or a straight run longer than 4 cells.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const MIN_TURNS = 28, MAX_RUN = 4;
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const files = process.argv.length > 2 ? process.argv.slice(2)
  : ['zip-puzzle.json', 'zip-puzzle-b.json', 'zip-puzzle-c.json', 'zip-puzzle-d.json'].map((f) => join(root, f));
// zip-puzzle.json (A) is a pre-existing accepted puzzle with a 6-cell run: reported, not enforced.
const EXEMPT = new Set(['zip-puzzle.json']);
let bad = 0;
for (const f of files) {
  const { path } = JSON.parse(readFileSync(f, 'utf8'));
  const dirs = path.slice(1).map((c, i) => `${c[0] - path[i][0]},${c[1] - path[i][1]}`);
  let turns = 0, run = 2, maxRun = 2, vert = 0;
  dirs.forEach((d, i) => {
    if (d.endsWith(',0')) vert++;
    if (i === 0) return;
    if (d !== dirs[i - 1]) { turns++; run = 2; } else { run++; maxRun = Math.max(maxRun, run); }
  });
  const ok = turns >= MIN_TURNS && maxRun <= MAX_RUN;
  const exempt = !ok && EXEMPT.has(f.split('/').pop());
  console.log(`${ok ? 'ok  ' : exempt ? 'note' : 'FAIL'} ${f.split('/').pop()}: turns=${turns} maxRun=${maxRun} vertical=${vert}/${dirs.length}`);
  if (!ok && !exempt) bad++;
}
process.exit(bad ? 1 : 0);
