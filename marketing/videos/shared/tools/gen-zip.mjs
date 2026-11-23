#!/usr/bin/env node
// Deterministic generator for promo Zip puzzles B, C, D.
// Usage: node tools/gen-zip.mjs   (writes zip-puzzle-{b,c,d}.json next to validate-zip.mjs)
// Paths are fixed shapes; numbers and walls are picked by a seeded PRNG.
// Seeds: see the seed values printed on each run (D also searched upward until the wrong-attempt checks pass).
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

// B and C: twisty Hamiltonian paths found by seeded "backbite" moves starting from a snake,
// accepted only when turns >= 28, no straight run > 4 cells, and the flow is clearly
// vertical (B) or horizontal (C). The seed is searched upward from the base seed.
function shapeStats(p) {
  const d = p.slice(1).map((c, i) => [c[0] - p[i][0], c[1] - p[i][1]]);
  let turns = 0, run = 2, maxRun = 2, vert = 0;
  d.forEach((x, i) => { if (x[1] === 0) vert++; if (!i) return;
    if (x[0] !== d[i - 1][0] || x[1] !== d[i - 1][1]) { turns++; run = 2; } else maxRun = Math.max(maxRun, ++run); });
  return { turns, maxRun, vert };
}
function twisty(vertical, baseSeed) {
  for (let seed = baseSeed; ; seed++) {
    const rand = rng(seed);
    let p = [];
    for (let a = 0; a < N; a++) for (let b = 0; b < N; b++) { const x = a % 2 ? N - 1 - b : b; p.push(vertical ? [x, a] : [a, x]); }
    for (let it = 0; it < 4000; it++) {
      if (rand() < 0.5) p.reverse();
      const t = p[63], j = p.findIndex((c) => Math.abs(c[0] - t[0]) + Math.abs(c[1] - t[1]) === 1 && c !== p[62]);
      const nb = []; p.forEach((c, i) => { if (i < 62 && Math.abs(c[0] - t[0]) + Math.abs(c[1] - t[1]) === 1) nb.push(i); });
      if (!nb.length) continue; const k = nb[Math.floor(rand() * nb.length)];
      p = p.slice(0, k + 1).concat(p.slice(k + 1).reverse());
    }
    const s = shapeStats(p);
    if (s.turns >= 28 && s.maxRun <= 4 && (vertical ? s.vert >= 38 : s.vert <= 25)) { console.log(`${vertical ? 'B' : 'C'} path seed: ${seed}`); return { p, seed }; }
  }
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

const tb = twisty(true, 1), tc = twisty(false, 1);
const out = { b: decorate(tb.p, 11), c: decorate(tc.p, 7) };
let s = 3, d;
for (;; s++) { d = decorate(pathD(), s, { earlyWall: true }); if (okD(d)) break; }
out.d = d; console.log(`D seed used: ${s}`);
for (const [k, v] of Object.entries(out)) writeFileSync(join(here, `zip-puzzle-${k}.json`), JSON.stringify(v) + '\n');
