#!/usr/bin/env node
// Usage: node validate-zip.mjs <puzzle.json>
// Exits 1 with a message unless the Zip puzzle is a legal, fully solved path.
import { readFileSync } from 'node:fs';

const fail = (msg) => { console.error(`INVALID: ${msg}`); process.exit(1); };
const file = process.argv[2];
if (!file) fail('usage: validate-zip.mjs <file>');

let p;
try { p = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { fail(`cannot read/parse ${file}: ${e.message}`); }

const { size, path, numbers, walls = [] } = p;
if (!Number.isInteger(size) || size < 1) fail('size must be a positive integer');
const total = size * size;
if (!Array.isArray(path) || path.length !== total) fail(`path must have ${total} cells, got ${path?.length}`);

const key = ([r, c]) => `${r},${c}`;
const inGrid = (cell) => Array.isArray(cell) && cell.length === 2 &&
  cell.every((v) => Number.isInteger(v) && v >= 0 && v < size);

const seen = new Set();
path.forEach((cell, i) => {
  if (!inGrid(cell)) fail(`path[${i}] = ${JSON.stringify(cell)} is outside the grid`);
  if (seen.has(key(cell))) fail(`path[${i}] = ${key(cell)} is visited twice`);
  seen.add(key(cell));
});

const edge = (a, b) => [key(a), key(b)].sort().join('|');
const wallSet = new Set();
walls.forEach((w, i) => {
  if (!inGrid(w.a) || !inGrid(w.b)) fail(`wall ${i} is outside the grid`);
  if (Math.abs(w.a[0] - w.b[0]) + Math.abs(w.a[1] - w.b[1]) !== 1) fail(`wall ${i} does not separate adjacent cells`);
  wallSet.add(edge(w.a, w.b));
});

for (let i = 1; i < path.length; i++) {
  const [a, b] = [path[i - 1], path[i]];
  if (Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) !== 1) fail(`step ${i - 1}->${i} (${key(a)} -> ${key(b)}) is not orthogonally adjacent`);
  if (wallSet.has(edge(a, b))) fail(`step ${i - 1}->${i} (${key(a)} -> ${key(b)}) crosses a wall`);
}

if (!Array.isArray(numbers) || numbers.length < 2) fail('need at least 2 numbers');
const index = new Map(path.map((c, i) => [key(c), i]));
let last = -1;
numbers.forEach(({ n, r, c }, k) => {
  if (n !== k + 1) fail(`numbers must be 1..N in order; entry ${k} has n=${n}`);
  const i = index.get(key([r, c]));
  if (i === undefined) fail(`number ${n} at ${r},${c} is not on the path`);
  if (i <= last) fail(`number ${n} appears out of path order`);
  last = i;
});
if (index.get(key([numbers[0].r, numbers[0].c])) !== 0) fail('number 1 must sit on path[0]');
const end = numbers[numbers.length - 1];
if (index.get(key([end.r, end.c])) !== total - 1) fail(`number ${end.n} must sit on the last path cell`);

// ASCII render: numbered cells show the number, others show path index.
const num = new Map(numbers.map((x) => [key([x.r, x.c]), x.n]));
console.log('Path order (step index; [n] = numbered cell; | and - = walls):');
for (let r = 0; r < size; r++) {
  let row = '', under = '';
  for (let c = 0; c < size; c++) {
    const n = num.get(key([r, c]));
    const t = n ? `[${n}]` : String(index.get(key([r, c])));
    row += t.padStart(4);
    row += wallSet.has(edge([r, c], [r, c + 1])) ? '|' : ' ';
    under += wallSet.has(edge([r, c], [r + 1, c])) ? '  -- ' : '     ';
  }
  console.log(row);
  if (r < size - 1) console.log(under);
}
console.log(`OK: ${total} cells, ${numbers.length} numbers, ${walls.length} walls`);
