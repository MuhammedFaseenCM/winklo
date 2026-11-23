#!/usr/bin/env node
// Deterministic generator for promo Zip puzzles B, C, D.
// Usage: node tools/gen-zip.mjs   (writes zip-puzzle-{b,c,d}.json next to validate-zip.mjs)
// Paths are fixed shapes; numbers and walls are picked by a seeded PRNG.
// Seeds: B=11, C=7, D=3 (D also searched upward until the wrong-attempt checks pass).
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const N = 8;
const here = join(dirname(fileURLToPath(import.meta.url)), '..');

function rng(seed) { // mulberry32
  let a = seed >>> 0;
  return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

// B: long vertical sweeps (column snake), starting bottom-left.
function pathB() {
  const p = [];
  for (let c = 0; c < N; c++) for (let i = 0; i < N; i++) p.push([c % 2 === 0 ? N - 1 - i : i, c]);
  return p;
}
// C: clockwise spiral from top-right corner inward.
function pathC() {
  const p = []; let [t, b, l, r] = [0, N - 1, 0, N - 1];
  while (t <= b && l <= r) {
    for (let c = r; c >= l; c--) p.push([t, c]); t++;       // west along top
    for (let q = t; q <= b; q++) p.push([q, l]); l++;       // south along left
    if (t <= b) { for (let c = l; c <= r; c++) p.push([b, c]); b--; }
    if (l <= r) { for (let q = b; q >= t; q--) p.push([q, r]); r--; }
  }
  return p;
}
// D: blocky zig-zags: 2x2 blocks visited in a snake over the 4x4 block grid;
// inside each block the 4 cells go round in a U/loop, chosen by backtracking so the path stays connected.
function pathD() {
  const order = [];
  for (let br = 0; br < 4; br++) for (let i = 0; i < 4; i++) order.push([br, br % 2 ? 3 - i : i]);
  const loops = (br, bc) => {
    const ring = [[0, 0], [0, 1], [1, 1], [1, 0]].map(([a, b]) => [br * 2 + a, bc * 2 + b]);
    const res = [];
    for (let s = 0; s < 4; s++) for (const d of [1, 3]) res.push([0, 1, 2, 3].map((k) => ring[(s + d * k) % 4]));
    return res;
  };
  const adj = (a, b) => Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) === 1;
  const go = (i, prev, acc) => {
    if (i === order.length) return acc;
    for (const l of loops(...order[i])) {
      if (prev && !adj(prev, l[0])) continue;
      if (i === 0 && !(l[0][0] === 0 && l[0][1] === 0)) continue;
      const r = go(i + 1, l[3], acc.concat(l)); if (r) return r;
    }
    return null;
  };
  return go(0, null, []);
}

const key = ([r, c]) => `${r},${c}`;
const ekey = (a, b) => [key(a), key(b)].sort().join('|');

function decorate(path, seed, { earlyWall = false } = {}) {
  const rand = rng(seed);
  const idx = new Map(path.map((c, i) => [key(c), i]));
  const used = new Set(path.slice(1).map((c, i) => ekey(path[i], c)));
  const isTurn = (i) => i > 0 && i < 63 && (path[i][0] - path[i - 1][0] !== path[i + 1][0] - path[i][0] ||
                                              path[i][1] - path[i - 1][1] !== path[i + 1][1] - path[i][1]);
  // candidate walls: grid edges the path does not use, with a turn cell on one side
  const cands = [];
  for (let i = 0; i < 64; i++) for (const [dr, dc] of [[0, 1], [1, 0]]) {
    const o = [path[i][0] + dr, path[i][1] + dc]; if (o[0] >= N || o[1] >= N) continue;
    const j = idx.get(key(o)); if (used.has(ekey(path[i], o))) continue;
    if (Math.abs(i - j) < 4) continue; if (!(isTurn(i) || isTurn(j))) continue;
    cands.push({ a: path[i], b: o, at: Math.min(i, j) });
  }
  const pick = (pool, taken) => pool.filter((w) => taken.every((t) => Math.abs(t.at - w.at) >= 6));
  const walls = [];
  if (earlyWall) { const e = cands.filter((w) => w.at >= 2 && w.at <= 10); walls.push(e[Math.floor(rand() * e.length)]); }
  const want = 5;
  while (walls.length < want) { const pool = pick(cands, walls); if (!pool.length) break; walls.push(pool[Math.floor(rand() * pool.length)]); }
  // numbers: 1 at start, 8 at end, six spread picks (one per ~8-step window, jittered)
  const ids = [0];
  for (let k = 1; k <= 6; k++) ids.push(Math.round(k * 63 / 7 + (rand() - 0.5) * 5));
  ids.push(63);
  return {
    size: N, path,
    numbers: ids.map((i, k) => ({ n: k + 1, r: path[i][0], c: path[i][1] })),
    walls: walls.sort((x, y) => x.at - y.at).map(({ a, b }) => ({ a, b })),
  };
}

// D wrong-attempt checks (see task 6): early wall; k+2 close to k+1 around steps 20-35.
function okD(p) {
  const idx = new Map(p.path.map((c, i) => [key(c), i]));
  const wi = p.walls.map((w) => Math.min(idx.get(key(w.a)), idx.get(key(w.b))));
  if (!wi.some((i) => i <= 12)) return false;
  const pos = p.numbers.map((x) => idx.get(key([x.r, x.c])));
  const md = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.c - b.c);
  return p.numbers.some((x, k) => k < 6 && pos[k + 1] >= 20 && pos[k + 1] <= 35 && md(p.numbers[k + 1], p.numbers[k + 2]) <= 4);
}

const out = { b: decorate(pathB(), 11), c: decorate(pathC(), 7) };
let s = 3, d;
for (;; s++) { d = decorate(pathD(), s, { earlyWall: true }); if (okD(d)) break; }
out.d = d; console.log(`D seed used: ${s}`);
for (const [k, v] of Object.entries(out)) writeFileSync(join(here, `zip-puzzle-${k}.json`), JSON.stringify(v) + '\n');
