// Generates index.html + compositions/*.html for Video D "Brain meter".
// The output is plain static HTML (what Studio edits). Re-running this OVERWRITES
// any Studio edits to those files: edit here, or stop using this script.
// Usage: node tools/build.mjs   (run from the project dir)
//
// The Zip puzzle is copied into this project (tools/zip-puzzle.json, from
// ../shared/zip-puzzle.json, unchanged) so the project stands alone.
// Board, ribbon, walls, type, CTA pill, music set-up and sfx levels are copied
// from videos A-C (C is the closest relative). The two fail moves are computed
// from the puzzle here and proven illegal; the build throws if either is legal.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const puzzle = JSON.parse(fs.readFileSync(path.join(here, "zip-puzzle.json"), "utf8"));

// ---------- brand (lib/core/theme/app_theme.dart ZipColors) ----------
const C = {
  ink: "#0F172A",
  onInk: "#F8FAFC",
  inkSoft: "#94A3B8",
  paper: "#243044",
  wall: "#1E293B",
  outline: "#475569",
  ember: "#FF6B2C",
  teal: "#2DD4BF",
  number: "#FB7185",
  red: "#F87171",
  skin: "#FFC9A3",
  skinLight: "#FFE4D2",
};

// ---------- geometry (1080x1920) ----------
const W = 1080;
const H = 1920;
const FPS = 30;
const BOARD = 780; // as C: 150..930 x 530..1310, inside 168..1330
const BX = (W - BOARD) / 2;
const BY = 530;
const fx = (v) => Math.round(v * 1000) / 1000;

// =====================================================================
// Zip rules + the fail moves (computed, then proven illegal)
// =====================================================================
const N = puzzle.size;
const key = ([r, c]) => `${r},${c}`;
const edge = (a, b) => [key(a), key(b)].sort().join("|");
const wallSet = new Map(puzzle.walls.map((w, i) => [edge(w.a, w.b), i]));
const numAt = new Map(puzzle.numbers.map((n) => [key([n.r, n.c]), n.n]));
const cellOfNum = new Map(puzzle.numbers.map((n) => [n.n, [n.r, n.c]]));
const inGrid = ([r, c]) => r >= 0 && r < N && c >= 0 && c < N;
const nbrs = ([r, c]) => [[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]].filter(inGrid);

// First rule a drawn line breaks, or null if every step so far is legal.
function firstViolation(cells) {
  if (numAt.get(key(cells[0])) !== 1) return { step: 0, rule: "start" };
  const seen = new Set([key(cells[0])]);
  let lastNum = 1;
  for (let i = 1; i < cells.length; i++) {
    const a = cells[i - 1];
    const b = cells[i];
    if (Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) !== 1) return { step: i, rule: "adjacent" };
    if (wallSet.has(edge(a, b))) return { step: i, rule: "wall" };
    if (seen.has(key(b))) return { step: i, rule: "revisit" };
    seen.add(key(b));
    const n = numAt.get(key(b));
    if (n !== undefined) {
      if (n !== lastNum + 1) return { step: i, rule: "order" };
      lastNum = n;
    }
  }
  return null;
}
const lastNumIn = (cells) => cells.reduce((m, c) => Math.max(m, numAt.get(key(c)) ?? 0), 0);

const P = puzzle.path;
if (firstViolation(P) !== null || P.length !== N * N) throw new Error("solution path is not legal");

// Fail #1: follow the true path for a few steps, then step across a listed wall.
// The earliest path cell (after the first 3 steps) with an unvisited neighbour behind a wall.
let fail1 = null;
for (let i = 3; i < P.length && !fail1; i++) {
  const visited = new Set(P.slice(0, i + 1).map(key));
  for (const nb of nbrs(P[i]))
    if (wallSet.has(edge(P[i], nb)) && !visited.has(key(nb))) {
      fail1 = { at: i, cells: [...P.slice(0, i + 1), nb], wall: wallSet.get(edge(P[i], nb)) };
      break;
    }
}
if (!fail1) throw new Error("fail #1: no wall next to the path");

// Fail #2: get further, then reach number k+2 before number k+1 (a short detour
// through free cells that skips k+1). Starts from the furthest cell before k+1.
let fail2 = null;
for (let k = lastNumIn(fail1.cells); k + 2 <= puzzle.numbers.length && !fail2; k++) {
  const j = P.findIndex((c) => key(c) === key(cellOfNum.get(k + 1)));
  const target = key(cellOfNum.get(k + 2));
  for (let i = j - 1; i > fail1.at && !fail2; i--) {
    const visited = new Set(P.slice(0, i + 1).map(key));
    // BFS through free, unnumbered cells, no walls, up to 5 steps, ending on k+2.
    const prev = new Map([[key(P[i]), null]]);
    let frontier = [P[i]];
    for (let d = 0; d < 5 && !fail2; d++) {
      const next = [];
      for (const c of frontier)
        for (const nb of nbrs(c)) {
          const kk = key(nb);
          if (prev.has(kk) || visited.has(kk) || wallSet.has(edge(c, nb))) continue;
          if (numAt.has(kk) && kk !== target) continue;
          prev.set(kk, key(c));
          if (kk === target) {
            const det = [];
            for (let q = kk; q !== key(P[i]); q = prev.get(q)) det.unshift(q.split(",").map(Number));
            if (det.length >= 2) fail2 = { at: i, cells: [...P.slice(0, i + 1), ...det], skipped: k + 1, reached: k + 2 };
          } else next.push(nb);
        }
      frontier = next;
    }
  }
}
if (!fail2) throw new Error("fail #2: no out-of-order detour found");

// Proofs: every step before the last is legal, the last breaks the named rule.
{
  const v1 = firstViolation(fail1.cells);
  if (!v1 || v1.rule !== "wall" || v1.step !== fail1.cells.length - 1)
    throw new Error(`fail #1 is not a wall crossing on its last step: ${JSON.stringify(v1)}`);
  const v2 = firstViolation(fail2.cells);
  if (!v2 || v2.rule !== "order" || v2.step !== fail2.cells.length - 1)
    throw new Error(`fail #2 is not an out-of-order number on its last step: ${JSON.stringify(v2)}`);
  if (!(fail2.cells.length > fail1.cells.length)) throw new Error("fail #2 must get further than fail #1");
}

// =====================================================================
// Zip board (copied from videos A-C: lib/features/zip/game/zip_game.dart look)
// =====================================================================
const CELL = BOARD / N; // 97.5
const RIBBON = CELL * 0.46;
const center = ([r, c]) => [(c + 0.5) * CELL, (r + 0.5) * CELL];
// App ribbon colours (lib/features/zip/game/zip_path_ribbon.dart)
const STOPS = [C.ember, "#FFC53D", "#FF4D6D", "#E879F9"];
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const lerp = (a, b, t) => {
  const A = hex(a);
  const B = hex(b);
  return "#" + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, "0")).join("");
};
const colorAt = (i) => {
  if (i <= 0) return STOPS[0];
  const w = (i / 4) % STOPS.length;
  const k = Math.floor(w) % STOPS.length;
  return lerp(STOPS[k], STOPS[(k + 1) % STOPS.length], w - Math.floor(w));
};

// groups: [{ name, cells }] - each is its own set of ribbon segments.
function zipSvg(prefix, groups, { size = BOARD, x, y } = {}) {
  const cells = [];
  for (let r = 0; r < N; r++)
    for (let c = 0; c < N; c++)
      cells.push(`<rect x="${c * CELL + 3}" y="${r * CELL + 3}" width="${CELL - 6}" height="${CELL - 6}" rx="12" fill="${C.paper}"/>`);
  const walls = puzzle.walls.map(({ a, b }, wi) => {
    const inset = CELL * 0.16;
    let x1, y1, x2, y2;
    if (a[0] === b[0]) {
      const xx = Math.max(a[1], b[1]) * CELL;
      x1 = x2 = xx;
      y1 = a[0] * CELL + inset;
      y2 = (a[0] + 1) * CELL - inset;
    } else {
      const yy = Math.max(a[0], b[0]) * CELL;
      y1 = y2 = yy;
      x1 = a[1] * CELL + inset;
      x2 = (a[1] + 1) * CELL - inset;
    }
    return `<line data-wall="${wi}" x1="${fx(x1)}" y1="${fx(y1)}" x2="${fx(x2)}" y2="${fx(y2)}" stroke="${C.onInk}" stroke-opacity="0.88" stroke-width="13" stroke-linecap="round"/>`;
  });
  const grads = [];
  const segGroups = groups.map(({ name, cells: seq }) => {
    const segs = [];
    for (let i = 0; i < seq.length - 1; i++) {
      const [x1, y1] = center(seq[i]);
      const [x2, y2] = center(seq[i + 1]);
      const gid = `${prefix}-${name}-g${i}`;
      grads.push(
        `<linearGradient id="${gid}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${colorAt(i)}"/><stop offset="1" stop-color="${colorAt(i + 1)}"/></linearGradient>`,
      );
      segs.push(
        `<line data-seg="${i}" data-stroke="url(#${gid})" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="url(#${gid})" stroke-width="${fx(RIBBON)}" stroke-linecap="round" stroke-dasharray="${fx(CELL)} ${fx(CELL + 2)}" stroke-dashoffset="${fx(CELL)}" opacity="0"/>`,
      );
    }
    return `<g id="${prefix}-rib-${name}">${segs.join("")}</g>`;
  });
  const nums = puzzle.numbers.map((n) => {
    const [cx, cy] = center([n.r, n.c]);
    return `<text data-num="${n.n}" data-cell="${n.r},${n.c}" x="${cx}" y="${cy}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="800" font-size="${fx(CELL * 0.4)}" fill="${C.number}" stroke="${C.ink}" stroke-width="0" stroke-linejoin="round" paint-order="stroke">${n.n}</text>`;
  });
  const s = center(P[0]);
  const pos = x !== undefined ? ` x="${x}" y="${y}"` : "";
  return `<svg id="${prefix}-svg"${pos} viewBox="0 0 ${BOARD} ${BOARD}" width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="${prefix}-glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="14"/></filter>
          ${grads.join("\n          ")}
        </defs>
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="${C.wall}" stroke="${C.outline}" stroke-width="2"/>
        <g>${cells.join("")}</g>
        ${segGroups.join("\n        ")}
        <g id="${prefix}-tip" opacity="0">
          <circle id="${prefix}-tipglow" cx="${s[0]}" cy="${s[1]}" r="38" fill="${C.ember}" opacity="0.55" filter="url(#${prefix}-glow)"/>
          <circle id="${prefix}-tipdot" cx="${s[0]}" cy="${s[1]}" r="${fx(RIBBON * 0.42)}" fill="${C.ember}" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5"/>
        </g>
        <g id="${prefix}-walls">${walls.join("")}</g>
        <g id="${prefix}-nums">${nums.join("")}</g>
      </svg>`;
}

// =====================================================================
// Drawn art: the pointer hand and the brain (simple vector shapes, ours)
// =====================================================================
// Pointer hand, index finger up, tilted -15deg about the fingertip (39,6).
// Outline trick: every shape stroked thick in ink first, then filled on top,
// so the outline is the union's. Sleeve cuff in ember.
const HAND_VB = [8, -6, 150, 182];
const HAND_SCALE = 0.85; // 127.5 x 154.7 px, ~8% of the frame height
const HAND_W = fx(HAND_VB[2] * HAND_SCALE);
const HAND_H = fx(HAND_VB[3] * HAND_SCALE);
const HAND_TIP = [fx((39 - HAND_VB[0]) * HAND_SCALE), fx((6 - HAND_VB[1]) * HAND_SCALE)];
function handSvg(id) {
  const shapes = [
    `<rect x="24" y="4" width="30" height="88" rx="15"/>`,
    `<rect x="18" y="62" width="92" height="82" rx="28"/>`,
    `<rect x="52" y="56" width="24" height="42" rx="12"/>`,
    `<rect x="74" y="60" width="22" height="40" rx="11"/>`,
    `<rect x="93" y="66" width="19" height="36" rx="9.5"/>`,
    `<rect x="2" y="88" width="46" height="28" rx="14" transform="rotate(-24 24 102)"/>`,
  ].join("");
  return `<svg id="${id}" viewBox="${HAND_VB.join(" ")}" width="${HAND_W}" height="${HAND_H}" xmlns="http://www.w3.org/2000/svg">
          <g transform="rotate(-15 39 6)">
            <rect x="28" y="132" width="72" height="36" rx="10" fill="${C.ember}" stroke="${C.ink}" stroke-width="6"/>
            <g fill="${C.ink}" stroke="${C.ink}" stroke-width="12" stroke-linejoin="round">${shapes}</g>
            <g fill="${C.skin}">${shapes}</g>
            <rect x="30" y="10" width="18" height="18" rx="8" fill="${C.skinLight}"/>
            <g stroke="${C.ink}" stroke-width="4" stroke-linecap="round" fill="none">
              <path d="M75 72 V92"/><path d="M94 77 V96"/><path d="M54 98 Q66 106 80 102"/>
            </g>
          </g>
        </svg>`;
}

// The brain: two pink lobes, folds, a centre line and a face (smile / frown).
function brainSvg(p) {
  const lobes = [
    `<circle cx="38" cy="38" r="26"/>`,
    `<circle cx="60" cy="30" r="25"/>`,
    `<circle cx="82" cy="38" r="26"/>`,
    `<circle cx="32" cy="60" r="24"/>`,
    `<circle cx="88" cy="60" r="24"/>`,
    `<ellipse cx="60" cy="64" rx="40" ry="28"/>`,
  ].join("");
  return `<svg viewBox="-4 -2 128 104" width="128" height="104" xmlns="http://www.w3.org/2000/svg">
          <g fill="${C.ink}" stroke="${C.onInk}" stroke-width="12" stroke-linejoin="round">${lobes}</g>
          <g fill="#F9A8D4">${lobes}</g>
          <g stroke="#DB2777" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.8">
            <path d="M60 10 V92"/>
            <path d="M26 34 Q36 26 44 34"/><path d="M76 34 Q84 26 94 34"/>
            <path d="M18 62 Q26 54 32 62"/><path d="M88 62 Q94 54 102 62"/>
          </g>
          <circle cx="47" cy="58" r="5" fill="${C.ink}"/><circle cx="73" cy="58" r="5" fill="${C.ink}"/>
          <path id="${p}-smile" d="M50 72 Q60 82 70 72" stroke="${C.ink}" stroke-width="4.5" stroke-linecap="round" fill="none"/>
          <path id="${p}-frown" d="M50 78 Q60 69 70 78" stroke="${C.ink}" stroke-width="4.5" stroke-linecap="round" fill="none" opacity="0"/>
        </svg>`;
}

// =====================================================================
// shared scene scaffolding
// =====================================================================
const FONT = `@font-face { font-family: Lexend; src: url('assets/fonts/Lexend-Variable.ttf'); font-weight: 100 900; }`;
const GROUND = `radial-gradient(1200px 900px at 50% 42%, #16213A 0%, ${C.ink} 70%)`;
const ROOT_CSS = `#root { position: absolute; inset: 0; overflow: hidden; font-family: Lexend, sans-serif; color: ${C.onInk}; background: ${GROUND}; }`;

function scene(id, css, body, script) {
  return `<template>
  <style>
      ${FONT}
      ${ROOT_CSS}
      ${css}
  </style>
  <div id="root" data-composition-id="${id}" data-width="${W}" data-height="${H}">
      ${body}
  </div>
  <script>
${script}
    window.__timelines["${id}"] = tl;
  </script>
</template>
`;
}

// Scene slots (absolute seconds)
const T = {
  brain: [0, 19.0],
  install: [19.0, 4.4],
  phone: [23.4, 6.6],
};
const TOTAL = fx(T.phone[0] + T.phone[1]); // 30.0
const sfx = []; // { id, src, t, v, d }

// =====================================================================
// brain (0–19 s): hook, fail #1, fail #2, solve -> Genius
// =====================================================================
// A hit lands 1/3 frame before a frame boundary, so the first frame at or after
// it shows the hit whatever the float rounding.
const snap = (t) => (Math.ceil(t * FPS) - 1 / 3) / FPS;
const HOOK_TAP = 0.5; // hand presses "1"
// Fail #1
const A0 = 1.15;
const dA = 0.14;
const nA = fail1.cells.length - 1; // legal steps + 1 illegal
const A_LEGAL_END = A0 + (nA - 1) * dA;
const A1 = A_LEGAL_END + 0.3; // a beat of hesitation before the bad step
const HIT1 = snap(A1 + 0.26);
const R1 = HIT1 + 0.62;
const RET = 0.6;
// Fail #2
const B0 = R1 + RET + 0.55;
const dB = 0.115;
const nB = fail2.cells.length - 1;
const nBLegal = fail2.at; // steps along the true path
const B_LEGAL_END = B0 + nBLegal * dB;
const HIT2 = snap(B_LEGAL_END + (nB - nBLegal) * 0.16);
const R2 = HIT2 + 0.62;
// Solve
const S0 = R2 + RET + 0.5;
const nS = P.length - 1;
const HIT3 = snap(S0 + 5.6);
const GENIUS_POP = HIT3 + 0.12;
const OUT = T.brain[1] - 0.45; // fall away
if (HIT3 > 17.6 || OUT - GENIUS_POP < 1.0) throw new Error(`brain timing off: HIT3=${HIT3}`);

const easeS = (x) => {
  const u = Math.max(0, Math.min(1, x));
  return 0.5 * u + 0.5 * u * u * (3 - 2 * u);
};
const invEase = (y) => {
  let lo = 0;
  let hi = 1;
  for (let k = 0; k < 60; k++) {
    const mid = (lo + hi) / 2;
    if (easeS(mid) < y) lo = mid;
    else hi = mid;
  }
  return (lo + hi) / 2;
};
const GROUPS = {
  A: {
    cells: fail1.cells,
    kf: [
      { t0: A0, t1: A_LEGAL_END, p0: 0, p1: nA - 1, e: "lin" },
      { t0: A1, t1: HIT1, p0: nA - 1, p1: nA, e: "lin" },
      { t0: R1, t1: R1 + RET, p0: nA, p1: 0, e: "inout" },
    ],
    hit: HIT1,
    red: nA - 1,
    wall: fail1.wall,
    redCell: null,
  },
  B: {
    cells: fail2.cells,
    kf: [
      { t0: B0, t1: B_LEGAL_END, p0: 0, p1: nBLegal, e: "lin" },
      { t0: B_LEGAL_END, t1: HIT2, p0: nBLegal, p1: nB, e: "lin" },
      { t0: R2, t1: R2 + RET, p0: nB, p1: 0, e: "inout" },
    ],
    hit: HIT2,
    red: nB - 1,
    wall: null,
    redCell: key(fail2.cells[nB]),
  },
  S: {
    cells: P,
    kf: [{ t0: S0, t1: HIT3, p0: 0, p1: nS, e: "solve" }],
    hit: HIT3,
    red: null,
    wall: null,
    redCell: null,
  },
};
// When the forward draw reaches path index idx (for meter steps and taps).
function reachTime(g, idx) {
  for (const k of g.kf) {
    if (k.p1 <= k.p0 || idx < k.p0 || idx > k.p1) continue;
    const u = (idx - k.p0) / (k.p1 - k.p0);
    return k.t0 + (k.t1 - k.t0) * (k.e === "solve" ? invEase(u) : u);
  }
  return null;
}
// Meter: 0..1 across the track; labels sit at the quarter centres.
const M0 = 0.12;
const M_LOW = 0.03;
const M_TOP = 0.92;
const meterKeys = [];
for (const name of ["A", "B"]) {
  const g = GROUPS[name];
  g.cells.forEach((c, i) => {
    const n = numAt.get(key(c));
    if (n === 2 || n === 3) {
      if (i <= g.red) meterKeys.push({ t: fx(reachTime(g, i)), v: n === 2 ? 0.28 : 0.4, d: 0.3, e: "back" });
    }
  });
  meterKeys.push({ t: fx(g.hit + 0.15), v: M_LOW, d: 0.6, e: "inout" });
}
P.forEach((c, i) => {
  const n = numAt.get(key(c));
  if (n && n >= 2) meterKeys.push({ t: fx(reachTime(GROUPS.S, i)), v: fx(M_LOW + ((n - 1) / 7) * (M_TOP - M_LOW)), d: 0.3, e: "back" });
});
meterKeys.sort((a, b) => a.t - b.t);
for (let i = 1; i < meterKeys.length; i++)
  if (meterKeys[i].t < meterKeys[i - 1].t + meterKeys[i - 1].d - 1e-6) throw new Error("meter keys overlap");

// Meter geometry
const TRACK_X = 110;
const TRACK_W = 860;
const TRACK_Y = 352;
const TRACK_H = 32;
const LABELS = ["Sleepy", "Warming up", "Sharp", "Genius"];

const brainCss = (p) => `
      #${p}-head { position: absolute; left: 40px; right: 40px; top: 188px; text-align: center; font-size: 92px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
      #${p}-head .hl { color: ${C.ember}; }
      #${p}-track { position: absolute; left: ${TRACK_X}px; top: ${TRACK_Y}px; width: ${TRACK_W}px; height: ${TRACK_H}px; border-radius: ${TRACK_H / 2}px; background: ${C.paper}; box-shadow: inset 0 0 0 2px ${C.outline}; overflow: hidden; }
      #${p}-fill { position: absolute; left: 0; top: 0; height: 100%; width: ${fx(M0 * TRACK_W)}px; border-radius: ${TRACK_H / 2}px;
        background: linear-gradient(90deg, ${C.ember} 0px, #FFC53D ${TRACK_W * 0.45}px, ${C.teal} ${TRACK_W}px); background-size: ${TRACK_W}px 100%; background-repeat: no-repeat; }
      #${p}-track .tick { position: absolute; top: 6px; width: 4px; height: ${TRACK_H - 12}px; border-radius: 2px; background: ${C.ink}; opacity: 0.55; }
      #${p}-brain { position: absolute; left: ${TRACK_X - 64}px; top: ${TRACK_Y + TRACK_H / 2 - 54}px; width: 128px; height: 104px; transform-origin: 64px 60px; }
      #${p}-brain svg { display: block; }
      .${p}-lab { position: absolute; top: 432px; width: 240px; text-align: center; font-size: 34px; font-weight: 600; line-height: 1; color: ${C.inkSoft}; white-space: nowrap; }
      #${p}-stage { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; }
      #${p}-board { position: absolute; left: 0; top: 0; width: ${BOARD}px; height: ${BOARD}px; }
      #${p}-board svg { display: block; filter: drop-shadow(0 8px 0 rgba(0,0,0,0.35)); }
      #${p}-flash { position: absolute; left: 0; top: 0; width: ${BOARD}px; height: ${BOARD}px; border-radius: 22px; background: ${C.teal}; opacity: 0; }
      #${p}-ring { position: absolute; left: -6px; top: -6px; width: ${BOARD + 12}px; height: ${BOARD + 12}px; border-radius: 26px; border: 6px solid ${C.teal}; opacity: 0; }
      .${p}-cring { position: absolute; left: 0; top: 0; width: 92px; height: 92px; border-radius: 50%; border: 6px solid ${C.ember}; opacity: 0; }
      #${p}-redring { border-color: ${C.red}; }
      #${p}-hand { position: absolute; left: 0; top: 0; width: ${HAND_W}px; height: ${HAND_H}px; transform-origin: ${HAND_TIP[0]}px ${HAND_TIP[1]}px; }
      #${p}-hand svg { display: block; filter: drop-shadow(0 10px 8px rgba(0,0,0,0.35)); }
      #${p}-genius { position: absolute; left: 190px; top: 820px; width: 700px; height: 200px; border-radius: 100px; background: rgba(15,23,42,0.92); border: 6px solid ${C.teal};
        display: flex; align-items: center; justify-content: center; font-size: 140px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; color: ${C.teal}; opacity: 0; }`;

const brainHtml = (p, { genius = true } = {}) => `<div id="${p}-head"${genius ? "" : " data-layout-allow-overlap"}>Train your <span class="hl">brain</span></div>
      <div id="${p}-meter">
        <div id="${p}-track"><div id="${p}-fill"></div>${[1, 2, 3].map((k) => `<div class="tick" style="left:${fx((k / 4) * TRACK_W - 2)}px"></div>`).join("")}</div>
        ${LABELS.map((l, k) => `<div id="${p}-lab${k}" class="${p}-lab" style="left:${fx(TRACK_X + ((k + 0.5) / 4) * TRACK_W - 120)}px">${l}</div>`).join("\n        ")}
        <div id="${p}-brain">${brainSvg(p)}</div>
      </div>
      <div id="${p}-stage" data-layout-allow-overflow>
        <div id="${p}-board">${zipSvg(p, Object.entries(GROUPS).map(([name, g]) => ({ name, cells: g.cells })))}</div>
        <div id="${p}-flash"></div>
        <div id="${p}-ring"></div>
        <div id="${p}-hookring" class="${p}-cring"></div>
        <div id="${p}-redring" class="${p}-cring"></div>
        <div id="${p}-hand">${handSvg(`${p}-handsvg`)}</div>
      </div>${genius ? `\n      <div id="${p}-genius" data-layout-allow-overlap>Genius!</div>` : ""}`;

// The runtime: render(t) is a pure function of scene time. The phone scene
// calls the same code once at t=0 for the loop frame, so it matches frame 0.
const brainRuntime = (p) => `
    const D = ${JSON.stringify({
      cell: CELL,
      groups: Object.fromEntries(Object.entries(GROUPS).map(([n, g]) => [n, { ...g, hit: fx(g.hit) }])),
      switchB: fx(B0 - 0.2),
      switchS: fx(S0 - 0.2),
      hookTap: HOOK_TAP,
      m0: M0,
      meter: meterKeys,
      trackW: TRACK_W,
      hit3: fx(HIT3),
      genius: fx(GENIUS_POP),
      out: fx(OUT),
      tip: HAND_TIP,
      fails: [fx(HIT1), fx(HIT2)],
    })};
    const $ = (id) => document.getElementById("${p}-" + id);
    const STOPS = ${JSON.stringify(STOPS.map(hex))};
    const RED = "${C.red}", WHITE = "${C.onInk}", NUM = "${C.number}", SOFT = "${C.inkSoft}", TEAL = "${C.teal}", EMBER = "${C.ember}";
    const clamp = (v) => Math.max(0, Math.min(1, v));
    const E = {
      lin: (u) => u,
      inout: (u) => (u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2),
      solve: (u) => 0.5 * u + 0.5 * u * u * (3 - 2 * u),
      back: (u) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(u - 1, 3) + c1 * Math.pow(u - 1, 2); },
    };
    const out4 = (x) => 1 - Math.pow(1 - clamp(x), 4);
    const in3 = (x) => Math.pow(clamp(x), 3);
    const smooth = (x) => { const u = clamp(x); return u * u * (3 - 2 * u); };
    function colorAt(i) {
      if (i <= 0) i = 0;
      const w = (i / 4) % STOPS.length, k = Math.floor(w) % STOPS.length, f = w - Math.floor(w);
      const a = STOPS[k], b = STOPS[(k + 1) % STOPS.length];
      return "rgb(" + a.map((v, j) => Math.round(v + (b[j] - v) * f)).join(",") + ")";
    }
    const G = {};
    for (const name of ["A", "B", "S"]) {
      G[name] = Object.assign({}, D.groups[name], { segs: Array.from(document.querySelectorAll("#${p}-rib-" + name + " [data-seg]")) });
    }
    const nums = Array.from(document.querySelectorAll("#${p}-nums [data-num]"));
    const walls = Array.from(document.querySelectorAll("#${p}-walls [data-wall]"));
    const labs = [0, 1, 2, 3].map((k) => $("lab" + k));
    const tip = $("tip"), tipGlow = $("tipglow"), tipDot = $("tipdot");
    const hand = $("hand"), stage = $("stage"), board = $("board");
    const brain = $("brain"), fill = $("fill"), smile = $("smile"), frown = $("frown");
    const hookRing = $("hookring"), redRing = $("redring"), flash = $("flash"), ring = $("ring");
    const genius = $("genius"), head = $("head"), meter = $("meter");
    const centre = (c) => [(c[1] + 0.5) * D.cell, (c[0] + 0.5) * D.cell];
    function pAt(g, t) {
      let p = g.kf[0].p0;
      for (const k of g.kf) {
        if (t < k.t0) break;
        p = k.p0 + (k.p1 - k.p0) * E[k.e](clamp((t - k.t0) / (k.t1 - k.t0)));
      }
      return p;
    }
    // 1 while the hand is down drawing, eased at both ends.
    function pressAt(t) {
      let v = 0;
      v = Math.max(v, smooth((t - (D.hookTap - 0.1)) / 0.1) * (1 - smooth((t - (D.hookTap + 0.12)) / 0.15)));
      for (const name of ["A", "B", "S"]) {
        const kf = G[name].kf;
        for (const k of kf) v = Math.max(v, smooth((t - (k.t0 - 0.12)) / 0.12) * (1 - smooth((t - k.t1 - 0.05) / 0.15)));
      }
      return v;
    }
    function meterAt(t) {
      let from = D.m0, v = D.m0;
      for (const k of D.meter) {
        if (t < k.t) break;
        v = from + (k.v - from) * E[k.e](clamp((t - k.t) / k.d));
        from = k.v;
      }
      return v;
    }
    function render(t) {
      const name = t < D.switchB ? "A" : t < D.switchS ? "B" : "S";
      const g = G[name];
      const p = pAt(g, t);
      const hit = t >= g.hit;
      for (const other of ["A", "B", "S"]) {
        const og = G[other];
        for (let i = 0; i < og.segs.length; i++) {
          const f = other === name ? clamp(p - i) : 0;
          const s = og.segs[i];
          s.setAttribute("opacity", f > 0 ? "1" : "0");
          s.setAttribute("stroke-dashoffset", String(D.cell * (1 - f)));
          s.setAttribute("stroke", og.red === i && t >= og.hit ? RED : s.dataset.stroke);
        }
      }
      // tip
      const i = Math.min(Math.floor(p), g.cells.length - 1);
      const f = p - i;
      const a = centre(g.cells[i]), b = centre(g.cells[Math.min(i + 1, g.cells.length - 1)]);
      const x = a[0] + (b[0] - a[0]) * f, y = a[1] + (b[1] - a[1]) * f;
      const red = g.red !== null && hit && p > g.red;
      const col = red ? RED : colorAt(p);
      for (const el of [tipGlow, tipDot]) { el.setAttribute("cx", x); el.setAttribute("cy", y); el.setAttribute("fill", col); }
      tip.setAttribute("opacity", p > 0.05 ? "1" : String(clamp(p / 0.05)));
      // numbers light up as the line passes them; the out-of-order one goes red
      const idxOf = new Map(g.cells.map((c, k) => [c[0] + "," + c[1], k]));
      for (const n of nums) {
        const k = idxOf.get(n.dataset.cell);
        const on = k !== undefined && p > 0.02 && p >= k - 0.35;
        const bad = g.redCell === n.dataset.cell && hit && on;
        n.setAttribute("fill", bad ? RED : on ? WHITE : NUM);
        n.setAttribute("stroke-width", on ? "8" : "0");
      }
      for (const w of walls) w.setAttribute("stroke", g.wall !== null && String(g.wall) === w.dataset.wall && hit && p > g.red ? RED : WHITE);
      // red ring on the offending cell, fading as the line wipes back
      if (g.red !== null && hit && p > g.red) {
        // wall fail: ring the crossed wall (mid-step); order fail: ring the number reached
        const e = centre(g.cells[g.red + 1]), s0 = centre(g.cells[g.red]);
        const c = g.wall !== null ? [(e[0] + s0[0]) / 2, (e[1] + s0[1]) / 2] : e;
        const h = t - g.hit;
        redRing.style.opacity = String(out4(h / 0.12) * clamp(p - g.red));
        redRing.style.transform = "translate(" + (c[0] - 46) + "px," + (c[1] - 46) + "px) scale(" + (1 + 0.5 * Math.exp(-10 * h)) + ")";
      } else redRing.style.opacity = "0";
      // hook ring on "1" as the hand presses it
      const c1 = centre(g.cells[0]);
      const hr = t - D.hookTap;
      hookRing.style.opacity = hr >= 0 ? String(out4(hr / 0.25) * (1 - smooth((hr - 0.5) / 0.2))) : "0";
      hookRing.style.transform = "translate(" + (c1[0] - 46) + "px," + (c1[1] - 46) + "px) scale(" + (hr >= 0 ? 1 + 0.8 * Math.exp(-9 * hr) : 1.8) + ")";
      // board shake on each fail: ~8 px, damped
      let sx = 0;
      for (const fh of D.fails) { const h = t - fh; if (h >= 0 && h < 0.8) sx += 8 * Math.exp(-6 * h) * Math.sin(2 * Math.PI * 8 * h); }
      // hand rides the tip; lifts and grows a touch when not pressing
      const lift = 1 - pressAt(t);
      const away = smooth((t - (D.hit3 + 0.2)) / 0.55);
      // on a fail the hand recoils off the bad move so the red reads, then rides the wipe back
      let rec = 0;
      if (g.red !== null && t >= g.hit) rec = out4((t - g.hit) / 0.18) * (1 - smooth((t - g.kf[2].t0) / 0.25));
      const hx = x + 10 * lift + 260 * away + 70 * rec, hy = y + 16 * lift + 420 * away + 120 * rec;
      hand.style.transform = "translate(" + (hx - D.tip[0]) + "px," + (hy - D.tip[1]) + "px) scale(" + (1 + 0.07 * lift) + ")";
      hand.style.opacity = String(1 - away);
      // solve: teal flash, ring, bump; Genius pop
      const h3 = t - D.hit3;
      flash.style.opacity = h3 >= 0 ? String(0.5 * Math.pow(1 - clamp(h3 / 0.6), 2)) : "0";
      ring.style.opacity = h3 >= 0 ? String(out4(h3 / 0.3)) : "0";
      const bump = h3 >= 0 ? 1 + 0.025 * Math.exp(-6 * h3) * Math.cos(12 * h3) : 1;
      // fall away at the end of the scene
      const o = in3((t - D.out) / 0.4);
      stage.style.transform = "translate(" + sx + "px," + 220 * o + "px) scale(" + bump + ")";
      stage.style.opacity = String(1 - o);
      stage.style.filter = "blur(" + 14 * o + "px)";
      for (const el of [head, meter]) { el.style.opacity = String(1 - o); el.style.filter = "blur(" + 8 * o + "px)"; }
      if (genius) {
        const hg = t - D.genius;
        const pop = hg >= 0 ? 1 - Math.exp(-7 * hg) * Math.cos(13 * hg) : 0;
        genius.style.opacity = String((hg >= 0 ? out4(hg / 0.12) : 0) * (1 - o));
        genius.style.transform = "scale(" + Math.max(0, pop) + ")";
        genius.style.filter = "blur(" + 10 * o + "px)";
      }
      // meter
      const m = meterAt(t);
      fill.style.width = (m * D.trackW) + "px";
      let wob = 0, sad = 0;
      for (const fh of D.fails) { const h = t - fh; if (h >= 0 && h < 1.6) { wob += 10 * Math.exp(-4 * h) * Math.sin(14 * h); sad = Math.max(sad, 1 - smooth((h - 1.2) / 0.3)); } }
      const geniusBob = h3 >= 0 ? 1 + 0.18 * Math.exp(-6 * h3) * Math.cos(14 * h3) : 1;
      brain.style.transform = "translateX(" + (m * D.trackW) + "px) rotate(" + wob + "deg) scale(" + geniusBob + ")";
      smile.setAttribute("opacity", String(1 - sad));
      frown.setAttribute("opacity", String(sad));
      const act = Math.min(3, Math.floor(m * 4));
      labs.forEach((l, k) => { l.style.color = k === act ? (k === 3 && h3 >= 0 ? TEAL : WHITE) : SOFT; });
    }`;

const brain = scene(
  "brain",
  brainCss("brain"),
  brainHtml("brain"),
  `    const tl = gsap.timeline({ paused: true });
${brainRuntime("brain")}
    const state = { t: 0 };
    render(0);
    // One linear driver over the whole scene; render(t) is a pure function of it.
    tl.fromTo(state, { t: 0 }, { t: ${T.brain[1]}, duration: ${T.brain[1]}, ease: "none", onUpdate: () => render(state.t) }, 0);`,
);
// sfx: hook tap, path taps every 4 steps, rejects, success, Genius pop
sfx.push({ id: "hook", src: "tap", t: fx(HOOK_TAP + 0.033), v: 0.7 });
{
  const vols = [0.5, 0.7, 0.6, 0.75];
  let n = 0;
  for (const [name, last] of [["A", nA - 1], ["B", nB - 1], ["S", nS - 1]]) {
    for (let k = 4; k <= last; k += 4)
      sfx.push({ id: `tap-${name}${k}`, src: "tap", t: fx(reachTime(GROUPS[name], k) + 0.033), v: vols[n++ % vols.length] });
  }
}
// reject peaks 0.017 s in; land its peak one frame after the red frame
sfx.push({ id: "reject-1", src: "reject", t: fx(HIT1 + 0.033 - 0.017), v: 1, d: 0.53 });
sfx.push({ id: "reject-2", src: "reject", t: fx(HIT2 + 0.033 - 0.017), v: 1, d: 0.53 });
sfx.push({ id: "success", src: "success", t: fx(HIT3 + 0.033), v: 1, d: 0.54 });
// "clear" peaks at 0.166 s: land on the Genius pop's first overshoot (~0.12 s)
sfx.push({ id: "genius-pop", src: "clear", t: fx(GENIUS_POP + 0.12 + 0.033 - 0.166), v: 0.75, d: 0.49 });

// =====================================================================
// install (19.0–23.4 s): app icon, search bar types "Winklo", Play badge
// =====================================================================
const BADGE_W = 560; // >= 380; 646x250 source, uniform scale only (height auto)
// Stack (icon tile 336, bar 140, badge 217, pill 96 + gaps 70/80/70 = 1009 px),
// centred in the 168..1330 band.
const TILE = 336;
const BADGE_H = (BADGE_W * 250) / 646; // 216.7, the source aspect
const STACK_H = TILE + 70 + 140 + 80 + BADGE_H + 70 + 96;
const TILE_TOP = Math.round(168 + (1330 - 168 - STACK_H) / 2);
const BAR_TOP = TILE_TOP + TILE + 70;
const BADGE_TOP = BAR_TOP + 140 + 80;
const PILL_TOP = Math.round(BADGE_TOP + BADGE_H + 70);
if (TILE_TOP < 168 || PILL_TOP + 96 > 1330) throw new Error("install stack outside the band");
// The badge tap lands just outside its bottom-right corner, so the badge is never covered.
const BADGE_TAP = [(W + BADGE_W) / 2 + 34, Math.round(BADGE_TOP + BADGE_H + 30)];
const TYPE_T0 = 0.55;
const TYPE_DT = 0.12;
const WORD = "Winklo";
const BADGE_T = TYPE_T0 + WORD.length * TYPE_DT + 0.3; // badge lands
const install = scene(
  "install",
  `#inst-tile { position: absolute; left: ${(W - TILE) / 2}px; top: ${TILE_TOP}px; width: ${TILE}px; height: ${TILE}px; opacity: 0.3; }
      #inst-glow { position: absolute; inset: 0; border-radius: 88px; background: #2A3A57;
        box-shadow: 0 0 0 4px rgba(248,250,252,0.7), 0 0 90px 10px rgba(255,107,44,0.45); }
      #inst-icon { position: absolute; left: 18px; top: 18px; width: 300px; height: 300px; }
      #inst-bar { position: absolute; left: 90px; top: ${BAR_TOP}px; width: 900px; height: 140px; border-radius: 70px; background: ${C.onInk};
        box-shadow: 0 10px 0 rgba(0,0,0,0.35); opacity: 0; }
      #inst-mag { position: absolute; left: 44px; top: 38px; width: 64px; height: 64px; }
      #inst-ph { position: absolute; left: 132px; top: 0; height: 140px; display: flex; align-items: center; font-size: 56px; font-weight: 500; color: ${C.inkSoft}; }
      #inst-q { position: absolute; left: 132px; top: 0; height: 140px; display: flex; align-items: center; font-size: 68px; font-weight: 700; letter-spacing: -0.02em; color: ${C.ink}; }
      #inst-q .ch { font-size: 0; }
      #inst-caret { display: inline-block; width: 6px; height: 72px; margin-left: 6px; border-radius: 3px; background: ${C.ember}; }
      #inst-badge { position: absolute; left: ${(W - BADGE_W) / 2}px; top: ${BADGE_TOP}px; width: ${BADGE_W}px; opacity: 0; }
      #inst-badge img { display: block; width: ${BADGE_W}px; height: auto; }
      #inst-ring { position: absolute; left: ${BADGE_TAP[0] - 40}px; top: ${BADGE_TAP[1] - 40}px; width: 80px; height: 80px; border-radius: 50%; border: 5px solid ${C.ember}; opacity: 0; }
      #inst-pill { position: absolute; left: 280px; top: ${PILL_TOP}px; width: 520px; height: 96px; border-radius: 48px; background: ${C.ember}; color: ${C.ink};
        display: flex; align-items: center; justify-content: center; font-size: 52px; font-weight: 700; opacity: 0; }
      #inst-hand { position: absolute; left: 0; top: 0; width: ${HAND_W}px; height: ${HAND_H}px; transform-origin: ${HAND_TIP[0]}px ${HAND_TIP[1]}px; }
      #inst-hand svg { display: block; filter: drop-shadow(0 10px 8px rgba(0,0,0,0.35)); }`,
  `<div id="inst-tile"><div id="inst-glow"></div><img id="inst-icon" src="assets/app_icon.png" alt="Winklo" /></div>
      <div id="inst-bar">
        <svg id="inst-mag" viewBox="0 0 64 64"><circle cx="27" cy="27" r="18" fill="none" stroke="${C.outline}" stroke-width="7"/><path d="M40 40 L56 56" stroke="${C.outline}" stroke-width="8" stroke-linecap="round"/></svg>
        <div id="inst-ph">Search apps</div>
        <div id="inst-q">${[...WORD].map((ch, i) => `<span class="ch" id="inst-c${i}">${ch}</span>`).join("")}<span id="inst-caret"></span></div>
      </div>
      <div id="inst-badge"><img src="assets/badges/google-play-badge.png" alt="Get it on Google Play" /></div>
      <div id="inst-pill">Free on Android</div>
      <div id="inst-ring"></div>
      <div id="inst-hand" data-layout-allow-overflow>${handSvg("inst-handsvg")}</div>`,
  `    const tl = gsap.timeline({ paused: true });
    const TIP = ${JSON.stringify(HAND_TIP)};
    const at = (x, y) => ({ x: x - TIP[0], y: y - TIP[1] });
    // Icon blurs in (starts at 30% so the seam never shows an empty frame), bar follows.
    tl.fromTo("#inst-tile", { opacity: 0.3, scale: 0.7, filter: "blur(10px)" }, { opacity: 1, scale: 1, filter: "blur(0px)", duration: 0.5, ease: "expo.out" }, 0);
    tl.fromTo("#inst-bar", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.4, ease: "expo.out" }, 0.08);
    // The hand comes in and taps the bar.
    tl.fromTo("#inst-hand", { ...at(1060, 1500), scale: 1.07 }, { ...at(850, ${BAR_TOP + 92}), scale: 1.07, duration: 0.42, ease: "power3.out" }, 0.0);
    tl.to("#inst-hand", { scale: 0.94, duration: 0.07, ease: "power2.in" }, 0.42);
    tl.to("#inst-hand", { scale: 1.07, duration: 0.12, ease: "power2.out" }, 0.49);
    tl.to("#inst-bar", { scale: 0.98, duration: 0.07, yoyo: true, repeat: 1, ease: "power2.inOut" }, 0.42);
    // "Winklo" types in, letter by letter.
    tl.set("#inst-ph", { opacity: 0 }, ${TYPE_T0});
    ${[...WORD].map((_, i) => `tl.set("#inst-c${i}", { fontSize: "68px" }, ${fx(TYPE_T0 + i * TYPE_DT)});`).join("\n    ")}
    tl.set("#inst-caret", { opacity: 0 }, ${fx(BADGE_T)});
    // The hand moves to where the badge lands, the badge pops in and is tapped.
    tl.to("#inst-hand", { ...at(${BADGE_TAP[0]}, ${BADGE_TAP[1]}), duration: 0.45, ease: "power3.inOut" }, ${fx(BADGE_T - 0.25)});
    tl.fromTo("#inst-badge", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.45, ease: "back.out(1.6)" }, ${fx(BADGE_T)});
    tl.fromTo("#inst-pill", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.5)" }, ${fx(BADGE_T + 0.25)});
    tl.to("#inst-hand", { scale: 0.94, duration: 0.07, ease: "power2.in" }, ${fx(BADGE_T + 0.55)});
    tl.fromTo("#inst-ring", { opacity: 0, scale: 1.8 }, { opacity: 1, scale: 1, duration: 0.3, ease: "expo.out" }, ${fx(BADGE_T + 0.6)});
    tl.to("#inst-ring", { opacity: 0, duration: 0.2, ease: "power2.in" }, ${fx(BADGE_T + 1.15)});
    tl.to("#inst-hand", { scale: 1.07, duration: 0.12, ease: "power2.out" }, ${fx(BADGE_T + 0.62)});
    tl.to("#inst-hand", { ...at(1120, 1700), opacity: 0, duration: 0.5, ease: "power3.in" }, ${fx(BADGE_T + 1.1)});
    // Out: blur swap into the phone.
    tl.to(["#inst-tile", "#inst-bar", "#inst-badge", "#inst-pill"], { opacity: 0, filter: "blur(8px)", duration: 0.16, ease: "power2.in", stagger: 0.02 }, ${fx(T.install[1] - 0.24)});
    tl.set({}, {}, ${fx(T.install[1] - 0.01)});`,
);
sfx.push({ id: "bar-tap", src: "tap", t: fx(T.install[0] + 0.42 + 0.07 + 0.0), v: 0.7 });
for (let i = 0; i < WORD.length; i++)
  sfx.push({ id: `key-${i + 1}`, src: "tap", t: fx(T.install[0] + TYPE_T0 + i * TYPE_DT + 0.033), v: [0.45, 0.6, 0.5, 0.65][i % 4] });
sfx.push({ id: "badge-pop", src: "clear", t: fx(T.install[0] + BADGE_T + 0.15 - 0.166 + 0.033), v: 0.85, d: 0.49 });
sfx.push({ id: "badge-tap", src: "tap", t: fx(T.install[0] + BADGE_T + 0.62), v: 0.8 });

// =====================================================================
// phone (23.4–30.0 s): a phone in a hand playing Zip; "Free daily puzzles";
// the last 0.7 s cross-fades into the hook frame so the reel loops.
// =====================================================================
const PH = { x: 210, y: 300, w: 660, h: 1320 };
const MINI = 600; // fills the 616 px screen; numbers render at 30 px
const MINI_X = (W - MINI) / 2; // 240
const MINI_Y = 520;
const PH_DRAW0 = 0.9;
const PH_HIT = snap(T.phone[0] + 3.9) - T.phone[0];
const LOOP_FADE = [T.phone[1] - 0.8, T.phone[1] - 0.1]; // 29.2 -> 29.9 abs
const SKIN = `fill="${C.skin}" stroke="#D9895F" stroke-width="6"`;
const phone = scene(
  "phone",
  `#ph-cap { position: absolute; left: 40px; right: 40px; top: 192px; text-align: center; font-size: 86px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
      #ph-cap .hl { color: ${C.ember}; }
      #ph-rig { position: absolute; left: 0; top: 0; width: ${W}px; height: ${H}px; }
      #ph-rig > svg { display: block; }
      #loop { position: absolute; inset: 0; background: ${GROUND}; opacity: 0; }
      ${brainCss("loop")}`,
  `<div id="ph-cap" data-layout-allow-overlap>Free <span class="hl" data-layout-allow-overlap>daily</span> puzzles</div>
      <div id="ph-rig" data-layout-allow-overflow>
        <svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="ph-scr" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#16213A"/><stop offset="1" stop-color="${C.ink}"/></linearGradient>
          </defs>
          <g id="ph-sway">
            <!-- palm behind the phone, wrist and cuff below it -->
            <rect x="140" y="1240" width="770" height="720" rx="170" ${SKIN}/>
            <rect x="330" y="1800" width="440" height="160" rx="30" fill="${C.ember}" stroke="${C.ink}" stroke-width="8"/>
            <!-- the phone -->
            <rect x="${PH.x}" y="${PH.y}" width="${PH.w}" height="${PH.h}" rx="84" fill="#0B1120" stroke="${C.outline}" stroke-width="5"/>
            <rect x="${PH.x + 22}" y="${PH.y + 22}" width="${PH.w - 44}" height="${PH.h - 44}" rx="64" fill="url(#ph-scr)"/>
            <rect x="${W / 2 - 75}" y="${PH.y + 40}" width="150" height="36" rx="18" fill="#0B1120"/>
            <text x="${W / 2}" y="${PH.y + 116}" text-anchor="middle" font-family="Lexend" font-weight="600" font-size="30" letter-spacing="5" fill="${C.inkSoft}">TODAY'S ZIP</text>
            <text id="ph-clock" data-layout-allow-overlap x="${W / 2}" y="${MINI_Y - 28}" text-anchor="middle" font-family="Lexend" font-weight="700" font-size="60" fill="${C.onInk}" style="font-variant-numeric: tabular-nums">0:00</text>
            ${zipSvg("ph", [{ name: "S", cells: P }], { size: MINI, x: MINI_X, y: MINI_Y })}
            <rect id="ph-flash" x="${MINI_X}" y="${MINI_Y}" width="${MINI}" height="${MINI}" rx="16" fill="${C.teal}" opacity="0"/>
            <g id="ph-chip" opacity="0">
              <rect x="${W / 2 - 130}" y="${MINI_Y + MINI + 50}" width="260" height="76" rx="38" fill="${C.teal}"/>
              <text x="${W / 2}" y="${MINI_Y + MINI + 88}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="700" font-size="40" fill="${C.ink}">Solved</text>
            </g>
            <!-- app tab bar (decoration, below the band): three game tiles, Zip lit -->
            ${[-1, 0, 1].map((k) => `<rect x="${W / 2 + k * 150 - 45}" y="${PH.y + PH.h - 170}" width="90" height="90" rx="24" fill="${k === 0 ? C.ember : C.paper}" opacity="${k === 0 ? 1 : 0.9}"/>`).join("")}
            <!-- fingers wrap the right edge over the bezel, stacked and touching; the thumb the left -->
            ${[3, 2, 1, 0].map((k) => `<rect x="${PH.x + PH.w - 54}" y="${1010 + k * 94}" width="${126 - k * 8}" height="100" rx="50" ${SKIN}/>`).join("\n            ")}
            <rect x="122" y="1277" width="260" height="96" rx="48" transform="rotate(-50.8 252 1325)" ${SKIN}/>
            <path d="M300 1262 q14 -14 30 -4" stroke="#D9895F" stroke-width="5" fill="none" stroke-linecap="round" transform="rotate(0)"/>
          </g>
        </svg>
      </div>
      <div id="loop">
      ${brainHtml("loop", { genius: false })}
      </div>`,
  `    const tl = gsap.timeline({ paused: true });
    // The loop frame: the same brain-scene code, rendered once at t = 0.
    {
${brainRuntime("loop")}
      render(0);
    }
    const PATH = ${JSON.stringify(P)};
    const CELL = ${CELL};
    const segs = Array.from(document.querySelectorAll("#ph-rib-S [data-seg]"));
    const nums = Array.from(document.querySelectorAll("#ph-nums [data-num]"));
    const idxOf = new Map(PATH.map((c, k) => [c[0] + "," + c[1], k]));
    const tip = document.getElementById("ph-tip"), tipGlow = document.getElementById("ph-tipglow"), tipDot = document.getElementById("ph-tipdot");
    const sway = document.getElementById("ph-sway"), flash = document.getElementById("ph-flash"), chip = document.getElementById("ph-chip");
    const loop = document.getElementById("loop"), clock = document.getElementById("ph-clock");
    const STOPS = ${JSON.stringify(STOPS.map(hex))};
    const clamp = (v) => Math.max(0, Math.min(1, v));
    const easeS = (u) => { u = clamp(u); return 0.5 * u + 0.5 * u * u * (3 - 2 * u); };
    const smooth = (x) => { const u = clamp(x); return u * u * (3 - 2 * u); };
    const out4 = (x) => 1 - Math.pow(1 - clamp(x), 4);
    function colorAt(i) {
      if (i <= 0) i = 0;
      const w = (i / 4) % STOPS.length, k = Math.floor(w) % STOPS.length, f = w - Math.floor(w);
      const a = STOPS[k], b = STOPS[(k + 1) % STOPS.length];
      return "rgb(" + a.map((v, j) => Math.round(v + (b[j] - v) * f)).join(",") + ")";
    }
    const centre = (i) => [(PATH[i][1] + 0.5) * CELL, (PATH[i][0] + 0.5) * CELL];
    function render2(t) {
      const p = (PATH.length - 1) * easeS((t - ${PH_DRAW0}) / ${fx(PH_HIT - PH_DRAW0)});
      for (let i = 0; i < segs.length; i++) {
        const f = clamp(p - i);
        segs[i].setAttribute("opacity", f > 0 ? "1" : "0");
        segs[i].setAttribute("stroke-dashoffset", String(CELL * (1 - f)));
      }
      const i = Math.min(Math.floor(p), PATH.length - 1), f = p - i;
      const a = centre(i), b = centre(Math.min(i + 1, PATH.length - 1));
      const x = a[0] + (b[0] - a[0]) * f, y = a[1] + (b[1] - a[1]) * f;
      for (const el of [tipGlow, tipDot]) { el.setAttribute("cx", x); el.setAttribute("cy", y); el.setAttribute("fill", colorAt(p)); }
      tip.setAttribute("opacity", String(clamp(p / 0.05)));
      for (const n of nums) {
        const on = p > 0.02 && p >= idxOf.get(n.dataset.cell) - 0.35;
        n.setAttribute("fill", on ? "${C.onInk}" : "${C.number}");
        n.setAttribute("stroke-width", on ? "8" : "0");
      }
      // the in-game clock counts with the line, 0:00 -> 0:47, teal on the solve
      const secs = Math.floor((47 * p) / (PATH.length - 1) + 1e-9);
      clock.textContent = "0:" + String(secs).padStart(2, "0");
      const h = t - ${fx(PH_HIT)};
      clock.setAttribute("fill", h >= 0 ? "${C.teal}" : "${C.onInk}");
      flash.setAttribute("opacity", h >= 0 ? String(0.5 * Math.pow(1 - clamp(h / 0.6), 2)) : "0");
      chip.setAttribute("opacity", h >= 0 ? String(out4((h - 0.1) / 0.25)) : "0");
      // held in a hand: a slow, small sway
      const r = -2.5 + 1.2 * Math.sin(1.7 * t);
      sway.setAttribute("transform", "rotate(" + r + " 540 1150)");
      // loop: cross-fade into the hook frame
      loop.style.opacity = String(smooth((t - ${fx(LOOP_FADE[0])}) / ${fx(LOOP_FADE[1] - LOOP_FADE[0])}));
    }
    const state = { t: 0 };
    render2(0);
    // Phone and hand rise into frame; the caption blurs in.
    tl.fromTo("#ph-rig", { y: 760, filter: "blur(12px)" }, { y: 0, filter: "blur(0px)", duration: 0.7, ease: "expo.out" }, 0);
    tl.fromTo("#ph-cap", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 0.3);
    tl.fromTo(state, { t: 0 }, { t: ${T.phone[1]}, duration: ${T.phone[1]}, ease: "none", onUpdate: () => render2(state.t) }, 0);`,
);
sfx.push({ id: "phone-solve", src: "success", t: fx(T.phone[0] + PH_HIT + 0.033), v: 0.6, d: 0.54 });

// =====================================================================
// index
// =====================================================================
const MUSIC_VOL = 0.8;
// Per-sound trim over the bed. Starts from C's levels; trimmed ~1.5 dB (and the bed
// raised to 0.8) so the mix lands in -16..-14 LUFS with true peak <= -1.5 dBTP.
const SFX_GAIN = { tap: 0.6, success: 0.55, clear: 0.6, reject: 0.42 };
sfx.sort((a, b) => a.t - b.t);
const laneEnd = { 2: -1, 3: -1 };
const audio = sfx.map((s) => {
  const d = s.d ?? 0.01;
  const lane = laneEnd[2] <= s.t ? 2 : 3;
  laneEnd[lane] = s.t + d;
  return `<audio id="sfx-${s.id}" class="clip" src="assets/sfx/${s.src}.ogg" data-start="${s.t}" data-duration="${d}" data-track-index="${lane}" data-volume="${fx(s.v * SFX_GAIN[s.src])}"></audio>`;
});
// Music bed: "Curiositys Arrival" by Steven Booth (CC BY 3.0), a 32 s excerpt
// (assets/music/CREDIT.md). Own lane, as in A-C.
audio.push(
  `<audio id="music" class="clip" src="assets/music/curiositys-arrival.mp3" data-start="0" data-duration="${TOTAL}" data-track-index="4" data-volume="${MUSIC_VOL}" data-fade-in="0.2" data-fade-out="1.5"></audio>`,
);
const host = (id, [start, dur]) =>
  `<div id="${id}" data-composition-id="${id}" data-composition-src="compositions/${id}.html" data-start="${start}" data-duration="${dur}" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>`;

const index = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=${W}, height=${H}" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; background: ${C.ink}; }
      #root { width: 100%; height: 100%; position: relative; background: ${C.ink}; }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="${TOTAL}" data-width="${W}" data-height="${H}">
      ${Object.entries(T)
        .map(([id, slot]) => host(id, slot))
        .join("\n      ")}
      ${audio.join("\n      ")}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({ paused: true });
    </script>
  </body>
</html>
`;

fs.mkdirSync(path.join(root, "compositions"), { recursive: true });
fs.writeFileSync(path.join(root, "index.html"), index);
for (const [name, html] of Object.entries({ brain, install, phone }))
  fs.writeFileSync(path.join(root, `compositions/${name}.html`), html);
console.log(`fail #1: ${fail1.at} true steps, then ${key(fail1.cells[fail1.cells.length - 2])} -> ${key(fail1.cells[fail1.cells.length - 1])} across wall ${fail1.wall}`);
console.log(`fail #2: ${fail2.at} true steps, then ${fail2.cells.slice(fail2.at + 1).map(key).join(" -> ")} reaches ${fail2.reached} before ${fail2.skipped}`);
console.log(`hits: ${fx(HIT1)} ${fx(HIT2)} ${fx(HIT3)} (frames ${Math.ceil(HIT1 * FPS)} ${Math.ceil(HIT2 * FPS)} ${Math.ceil(HIT3 * FPS)}); total ${TOTAL}`);
console.log(sfx.map((s) => `${s.id}@${s.t}`).join(" "));
