// Generates index.html + compositions/*.html for Video B "3 puzzles a day".
// The output is plain static HTML (what Studio edits). Re-running this OVERWRITES
// any Studio edits to those files: edit here, or stop using this script.
// Usage: node tools/build.mjs   (run from the project dir)
//
// The Zip puzzle is copied into this project (tools/zip-puzzle.json, from
// ../shared/zip-puzzle.json) so the project stands alone.
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
  mistDeep: "#334155",
  ember: "#FF6B2C",
  sky: "#38BDF8",
  teal: "#2DD4BF",
  star: "#FBBF24",
  number: "#FB7185",
};

// ---------- geometry (1080x1920) ----------
const W = 1080;
const H = 1920;
const BOARD = 840;
const BX = (W - BOARD) / 2; // 120
const BY = 480; // boards 480..1320 (inside 168..1330)
const fx = (v) => Math.round(v * 100) / 100;

// =====================================================================
// Zip board (copied from video A: lib/features/zip/game/zip_game.dart look)
// =====================================================================
const N = puzzle.size;
const CELL = BOARD / N; // 105
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
const pathIndexOf = new Map(puzzle.path.map(([r, c], i) => [`${r},${c}`, i]));

function zipSvg(prefix, { drawn }) {
  const cells = [];
  for (let r = 0; r < N; r++)
    for (let c = 0; c < N; c++)
      cells.push(`<rect x="${c * CELL + 3}" y="${r * CELL + 3}" width="${CELL - 6}" height="${CELL - 6}" rx="12" fill="${C.paper}"/>`);
  const walls = puzzle.walls.map(({ a, b }) => {
    const inset = CELL * 0.16;
    let x1, y1, x2, y2;
    if (a[0] === b[0]) {
      const x = Math.max(a[1], b[1]) * CELL;
      x1 = x2 = x;
      y1 = a[0] * CELL + inset;
      y2 = (a[0] + 1) * CELL - inset;
    } else {
      const y = Math.max(a[0], b[0]) * CELL;
      y1 = y2 = y;
      x1 = a[1] * CELL + inset;
      x2 = (a[1] + 1) * CELL - inset;
    }
    return `<line x1="${fx(x1)}" y1="${fx(y1)}" x2="${fx(x2)}" y2="${fx(y2)}" stroke="${C.onInk}" stroke-opacity="0.88" stroke-width="13" stroke-linecap="round"/>`;
  });
  const grads = [];
  const segs = [];
  for (let i = 0; i < puzzle.path.length - 1; i++) {
    const [x1, y1] = center(puzzle.path[i]);
    const [x2, y2] = center(puzzle.path[i + 1]);
    grads.push(
      `<linearGradient id="${prefix}-g${i}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${colorAt(i)}"/><stop offset="1" stop-color="${colorAt(i + 1)}"/></linearGradient>`,
    );
    segs.push(
      `<line data-seg="${i}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="url(#${prefix}-g${i})" stroke-width="${fx(RIBBON)}" stroke-linecap="round" stroke-dasharray="${fx(CELL)} ${fx(CELL + 2)}" stroke-dashoffset="${drawn ? 0 : fx(CELL)}"${drawn ? "" : ` opacity="0"`}/>`,
    );
  }
  const nums = puzzle.numbers.map((n) => {
    const [x, y] = center([n.r, n.c]);
    return `<text data-num="${n.n}" data-idx="${pathIndexOf.get(`${n.r},${n.c}`)}" x="${x}" y="${y}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="800" font-size="${fx(CELL * 0.4)}" fill="${drawn ? C.onInk : C.number}" stroke="${C.ink}" stroke-width="${drawn ? 8 : 0}" stroke-linejoin="round" paint-order="stroke">${n.n}</text>`;
  });
  const last = center(puzzle.path[drawn ? puzzle.path.length - 1 : 0]);
  const tipColor = drawn ? colorAt(puzzle.path.length - 1) : C.ember;
  return `<svg id="${prefix}-svg" viewBox="0 0 ${BOARD} ${BOARD}" width="${BOARD}" height="${BOARD}" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="${prefix}-glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="14"/></filter>
          ${grads.join("\n          ")}
        </defs>
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="${C.wall}" stroke="${C.outline}" stroke-width="2"/>
        <g>${cells.join("")}</g>
        <g id="${prefix}-ribbon">
          ${segs.join("\n          ")}
        </g>
        <g id="${prefix}-tip" opacity="${drawn ? 1 : 0}">
          <circle id="${prefix}-tipglow" cx="${last[0]}" cy="${last[1]}" r="38" fill="${tipColor}" opacity="0.55" filter="url(#${prefix}-glow)"/>
          <circle id="${prefix}-tipdot" cx="${last[0]}" cy="${last[1]}" r="${fx(RIBBON * 0.42)}" fill="${tipColor}" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5"/>
        </g>
        <g>${walls.join("")}</g>
        <g id="${prefix}-nums">${nums.join("")}</g>
      </svg>`;
}

// =====================================================================
// Path Words board (lib/features/path_words/game/path_words_game.dart look)
// sparse 6x6 letter grid; "." = no letter (ink wash). PUZZLE is traced.
// =====================================================================
const PW = ["D....W", "APUZ.I", "I..Z.N", "L..LE.", "Y.....", "..FUN."];
const PW_WORD = [
  [1, 1],
  [1, 2],
  [1, 3],
  [2, 3],
  [3, 3],
  [3, 4],
];
const PWN = 6;
const PWC = BOARD / PWN; // 140
// Path colour: sky, from the app's pathColors palette; fill per _fillColor().
function hslFill(h) {
  let [r, g, b] = hex(h).map((v) => v / 255);
  const mx = Math.max(r, g, b);
  const mn = Math.min(r, g, b);
  const l = (mx + mn) / 2;
  const d = mx - mn;
  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
  let hue = 0;
  if (d) {
    if (mx === r) hue = ((g - b) / d) % 6;
    else if (mx === g) hue = (b - r) / d + 2;
    else hue = (r - g) / d + 4;
    hue *= 60;
    if (hue < 0) hue += 360;
  }
  const s2 = Math.min(0.85, Math.max(0.4, s * 0.78));
  const l2 = 0.38;
  const c2 = (1 - Math.abs(2 * l2 - 1)) * s2;
  const x = c2 * (1 - Math.abs(((hue / 60) % 2) - 1));
  const m = l2 - c2 / 2;
  const [r1, g1, b1] =
    hue < 60 ? [c2, x, 0] : hue < 120 ? [x, c2, 0] : hue < 180 ? [0, c2, x] : hue < 240 ? [0, x, c2] : hue < 300 ? [x, 0, c2] : [c2, 0, x];
  return "#" + [r1, g1, b1].map((v) => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("");
}
const PW_COLOR = C.sky;
const PW_FILL = hslFill(PW_COLOR);
const pwIndex = new Map(PW_WORD.map(([r, c], i) => [`${r},${c}`, i]));

function pwSvg(prefix) {
  const grid = [];
  for (let i = 1; i < PWN; i++) {
    grid.push(`<line x1="${i * PWC}" y1="0" x2="${i * PWC}" y2="${BOARD}" stroke="${C.mistDeep}" stroke-width="2"/>`);
    grid.push(`<line x1="0" y1="${i * PWC}" x2="${BOARD}" y2="${i * PWC}" stroke="${C.mistDeep}" stroke-width="2"/>`);
  }
  const unused = [];
  const letters = [];
  for (let r = 0; r < PWN; r++)
    for (let c = 0; c < PWN; c++) {
      const ch = PW[r][c];
      if (ch === ".") {
        unused.push(`<rect x="${c * PWC}" y="${r * PWC}" width="${PWC}" height="${PWC}" fill="${C.ink}" fill-opacity="0.72"/>`);
        continue;
      }
      const i = pwIndex.get(`${r},${c}`);
      letters.push(
        `<text${i !== undefined ? ` data-pw="${i}"` : ""} x="${(c + 0.5) * PWC}" y="${(r + 0.5) * PWC}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="800" font-size="${fx(PWC * 0.4)}" letter-spacing="0.4" fill="${C.onInk}">${ch}</text>`,
      );
    }
  // Path cells: one rect each, grown from the side the trace enters.
  const inset = PWC * 0.1;
  const size = PWC - inset * 2;
  const cells = PW_WORD.map(([r, c], i) => {
    const x = c * PWC + inset;
    const y = r * PWC + inset;
    return `<rect data-cell="${i}" x="${x}" y="${y}" width="${fx(size)}" height="${fx(size)}" rx="${fx(PWC * 0.18)}" fill="${PW_FILL}" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="${fx(PWC * 0.03)}" opacity="0"/>`;
  });
  const [sr, sc] = PW_WORD[0];
  const scx = (sc + 0.5) * PWC;
  const scy = (sr + 0.5) * PWC;
  return `<svg id="${prefix}-svg" viewBox="0 0 ${BOARD} ${BOARD}" width="${BOARD}" height="${BOARD}" xmlns="http://www.w3.org/2000/svg">
        <defs><clipPath id="${prefix}-clip"><rect width="${BOARD}" height="${BOARD}" rx="22"/></clipPath></defs>
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="${C.wall}"/>
        <g clip-path="url(#${prefix}-clip)">${unused.join("")}</g>
        <g>${grid.join("")}</g>
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="none" stroke="${C.outline}" stroke-width="2"/>
        <g id="${prefix}-cells">${cells.join("")}</g>
        <g id="${prefix}-ring" opacity="0">
          <circle cx="${scx}" cy="${scy}" r="${fx(PWC * 0.34)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.92" stroke-width="${fx(PWC * 0.07)}"/>
          <circle cx="${scx}" cy="${scy}" r="${fx(PWC * 0.34)}" fill="none" stroke="${PW_COLOR}" stroke-opacity="0.55" stroke-width="${fx(PWC * 0.035)}"/>
        </g>
        <rect id="${prefix}-glow" x="2.5" y="2.5" width="${BOARD - 5}" height="${BOARD - 5}" rx="20" fill="none" stroke="${C.teal}" stroke-width="7" opacity="0"/>
        <g id="${prefix}-letters">${letters.join("")}</g>
      </svg>`;
}

// =====================================================================
// Sudoku 6x6, 2x3 boxes (lib/features/sudoku/game/sudoku_game.dart look)
// =====================================================================
const SD = ["123456", "456123", "231564", "564231", "312645", "645312"];
// Fill order: row 2 completes (flash), then the bottom-right box (flash),
// then the rest (solved).
const FILLS = [
  [2, 1],
  [2, 4],
  [4, 3],
  [4, 5],
  [5, 4],
  [0, 3],
  [1, 0],
  [3, 2],
  [5, 1],
];
const FILL_AT = [0.55, 0.85, 1.45, 1.72, 1.99, 2.6, 2.84, 3.08, 3.32];
const ROW_FLASH = { at: 1.05, cells: [0, 1, 2, 3, 4, 5].map((c) => [2, c]) };
const BOX_FLASH = { at: 2.19, cells: [4, 5].flatMap((r) => [3, 4, 5].map((c) => [r, c])) };
const SOLVED_AT = 3.55;
{
  // Verify the solution: rows, columns and 2x3 boxes each hold 1..6 once.
  const ok = (arr) => arr.slice().sort().join("") === "123456";
  for (let r = 0; r < 6; r++) if (!ok(SD[r].split(""))) throw new Error(`row ${r}`);
  for (let c = 0; c < 6; c++) if (!ok(SD.map((row) => row[c]))) throw new Error(`col ${c}`);
  for (let br = 0; br < 6; br += 2)
    for (let bc = 0; bc < 6; bc += 3) {
      const v = [];
      for (let r = br; r < br + 2; r++) for (let c = bc; c < bc + 3; c++) v.push(SD[r][c]);
      if (!ok(v)) throw new Error(`box ${br},${bc}`);
    }
  // Row 2 is complete after the first two fills; the box after the next three.
  const filledBy = (k) => new Set(FILLS.slice(0, k).map(([r, c]) => `${r},${c}`));
  const empty = new Set(FILLS.map(([r, c]) => `${r},${c}`));
  const complete = (cells, k) => cells.every(([r, c]) => !empty.has(`${r},${c}`) || filledBy(k).has(`${r},${c}`));
  if (!complete(ROW_FLASH.cells, 2) || complete(ROW_FLASH.cells, 1)) throw new Error("row flash order");
  if (!complete(BOX_FLASH.cells, 5) || complete(BOX_FLASH.cells, 4)) throw new Error("box flash order");
}
const SDN = 6;
const SDC = BOARD / SDN; // 140
const fillIndex = new Map(FILLS.map(([r, c], i) => [`${r},${c}`, i]));

function sdSvg(prefix, { solved }) {
  const washes = [];
  const digits = [];
  for (let r = 0; r < SDN; r++)
    for (let c = 0; c < SDN; c++) {
      const x = c * SDC;
      const y = r * SDC;
      washes.push(`<rect data-wash="${r},${c}" x="${x + 3}" y="${y + 3}" width="${SDC - 6}" height="${SDC - 6}" rx="12" fill="${C.teal}" opacity="0"/>`);
      const fi = fillIndex.get(`${r},${c}`);
      const given = fi === undefined;
      const shown = given || solved;
      digits.push(
        `<text${given ? "" : ` data-fill="${fi}"`} x="${x + SDC / 2}" y="${y + SDC / 2 + 2}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="${given ? 700 : 600}" font-size="${fx(SDC * 0.48)}" fill="${given ? C.onInk : C.sky}"${shown ? "" : ` opacity="0"`}>${SD[r][c]}</text>`,
      );
    }
  const lines = [];
  for (let i = 0; i <= SDN; i++) {
    const v = i % 3 === 0; // boxCols = 3 -> thick vertical every 3
    const h = i % 2 === 0; // boxRows = 2 -> thick horizontal every 2
    if (i > 0 && i < SDN) {
      lines.push(`<line x1="${i * SDC}" y1="0" x2="${i * SDC}" y2="${BOARD}" stroke="${v ? C.onInk : C.mistDeep}" stroke-opacity="${v ? 0.55 : 1}" stroke-width="${v ? 5 : 2}"/>`);
      lines.push(`<line x1="0" y1="${i * SDC}" x2="${BOARD}" y2="${i * SDC}" stroke="${h ? C.onInk : C.mistDeep}" stroke-opacity="${h ? 0.55 : 1}" stroke-width="${h ? 5 : 2}"/>`);
    }
  }
  return `<svg id="${prefix}-svg" viewBox="0 0 ${BOARD} ${BOARD}" width="${BOARD}" height="${BOARD}" xmlns="http://www.w3.org/2000/svg">
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="${C.paper}" fill-opacity="0.92"/>
        <rect id="${prefix}-sel" x="3" y="3" width="${SDC - 6}" height="${SDC - 6}" rx="12" fill="${C.sky}" opacity="0"/>
        <g id="${prefix}-washes">${washes.join("")}</g>
        <g>${lines.join("")}</g>
        <rect width="${BOARD}" height="${BOARD}" rx="22" fill="none" stroke="${C.onInk}" stroke-opacity="0.55" stroke-width="5"/>
        <g id="${prefix}-digits">${digits.join("")}</g>
      </svg>`;
}

// =====================================================================
// shared scene scaffolding
// =====================================================================
const FONT = `@font-face { font-family: Lexend; src: url('assets/fonts/Lexend-Variable.ttf'); font-weight: 100 900; }`;
const ROOT_CSS = `#root { position: absolute; inset: 0; overflow: hidden; font-family: Lexend, sans-serif; color: ${C.onInk};
        background: radial-gradient(1200px 900px at 50% 42%, #16213A 0%, ${C.ink} 70%); }`;
const BOARD_CSS = (id) =>
  `#${id} { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; }
      #${id} svg { display: block; filter: drop-shadow(0 8px 0 rgba(0,0,0,0.35)); }`;
// Game header: "PUZZLE n OF 3" kicker + the game's name in its colour.
const HEAD_CSS = (p, color) => `
      #${p}-kicker { position: absolute; left: 0; right: 0; top: 196px; text-align: center; font-size: 36px; font-weight: 600; letter-spacing: 0.18em; color: ${C.inkSoft}; line-height: 1; }
      #${p}-title { position: absolute; left: 0; right: 0; top: 246px; text-align: center; font-size: 104px; font-weight: 800; letter-spacing: -0.02em; line-height: 1; color: ${color}; }`;
const headHtml = (p, n, name, varId) => `<div id="${p}-kicker">PUZZLE ${n} OF 3</div>
      <div id="${p}-title" data-var-text="${varId}">${name}</div>`;
// Header in: per-word blur in. Out: blur swap.
const headIn = (p, at) =>
  `tl.fromTo("#${p}-kicker", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.16, ease: "power4.out" }, ${at});
    tl.fromTo("#${p}-title", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, ${fx(at + 0.07)});`;
const headOut = (p, at) =>
  `tl.to(["#${p}-kicker", "#${p}-title"], { opacity: 0, filter: "blur(8px)", duration: 0.16, ease: "power2.in", stagger: 0.03 }, ${at});`;

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
  hook: [0, 2.2],
  zip: [2.2, 5.2],
  words: [7.4, 5.4],
  sudoku: [12.8, 5.4],
  features: [18.2, 5.1],
  cta: [23.3, 2.5],
};
const TOTAL = fx(T.cta[0] + T.cta[1]); // 25.8
const sfx = []; // { id, src, t, v, d }

// =====================================================================
// hook (0–2.2s): "3 puzzles. / Every day. / Free." over the three boards
// =====================================================================
const SLOT = 316;
const SLOT_GAP = 26;
const SLOT_X = [0, 1, 2].map((i) => 40 + i * (SLOT + SLOT_GAP)); // 40, 382, 724
const SLOT_Y = 690;
const MSCALE = SLOT / BOARD;
const ms = fx(MSCALE * 10000) / 10000;
const hook = scene(
  "hook",
  `#hook-text { position: absolute; left: 40px; right: 40px; top: 186px; text-align: center; line-height: 1.02; font-weight: 800; letter-spacing: -0.03em; font-size: 124px; }
      #hook-text span { display: block; }
      #hook-l2 { color: ${C.ember}; }
      #hook-l3 { color: ${C.teal}; }
      .hook-mini { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; }
      .hook-mini svg { display: block; }
      .hook-label { position: absolute; top: ${SLOT_Y + SLOT + 26}px; width: ${SLOT + 40}px; text-align: center; font-size: 40px; font-weight: 700; line-height: 1; }
      #hook-lab1 { left: ${SLOT_X[0] - 20}px; color: ${C.ember}; }
      #hook-lab2 { left: ${SLOT_X[1] - 20}px; color: ${C.sky}; }
      #hook-lab3 { left: ${SLOT_X[2] - 20}px; color: ${C.teal}; }
      #hook-ring { position: absolute; left: ${SLOT_X[0] - 10}px; top: ${SLOT_Y - 10}px; width: ${SLOT + 20}px; height: ${SLOT + 20}px; border-radius: 22px; border: 5px solid ${C.ember}; opacity: 0; }`,
  `<div id="hook-text">
        <span id="hook-l1" data-var-text="hookLine1">3 puzzles.</span>
        <span id="hook-l2" data-var-text="hookLine2">Every day.</span>
        <span id="hook-l3" data-var-text="hookLine3">Free.</span>
      </div>
      <div id="hook-m2" class="hook-mini" data-layout-ignore>${pwSvg("hook-pw")}</div>
      <div id="hook-m3" class="hook-mini" data-layout-ignore>${sdSvg("hook-sd", { solved: false })}</div>
      <div id="hook-m1" class="hook-mini" data-layout-ignore>${zipSvg("hook-zip", { drawn: false })}</div>
      <div id="hook-ring"></div>
      <div id="hook-lab1" class="hook-label">Zip</div>
      <div id="hook-lab2" class="hook-label">Path Words</div>
      <div id="hook-lab3" class="hook-label">Sudoku</div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Frame 0 is the whole hook: three lines + the three boards, already on screen.
    const slot = (x) => ({ x: x - ${BX}, y: ${SLOT_Y - BY}, scale: ${ms}, transformOrigin: "0px 0px" });
    // One-shot cue: a ring picks Zip, the first of the three.
    tl.fromTo("#hook-ring", { opacity: 0, scale: 1.15 }, { opacity: 1, scale: 1, duration: 0.4, ease: "expo.out" }, 0.9);
    tl.to("#hook-ring", { opacity: 0, duration: 0.15, ease: "power2.in" }, 1.45);
    // Out: the copy and the other two boards clear; Zip grows into the stage.
    tl.to("#hook-text span", { opacity: 0, filter: "blur(8px)", duration: 0.18, ease: "power2.in", stagger: 0.05 }, 1.45);
    tl.to(["#hook-lab1", "#hook-lab2", "#hook-lab3"], { opacity: 0, filter: "blur(8px)", duration: 0.16, ease: "power2.in" }, 1.45);
    tl.fromTo("#hook-m2", { ...slot(${SLOT_X[1]}), opacity: 1, filter: "blur(0px)" }, { y: ${SLOT_Y - BY + 80}, opacity: 0, filter: "blur(10px)", duration: 0.3, ease: "power3.in" }, 1.5);
    tl.fromTo("#hook-m3", { ...slot(${SLOT_X[2]}), opacity: 1, filter: "blur(0px)" }, { x: ${SLOT_X[2] - BX + 120}, opacity: 0, filter: "blur(10px)", duration: 0.3, ease: "power3.in" }, 1.5);
    tl.fromTo("#hook-m1", slot(${SLOT_X[0]}), { x: 0, y: 0, scale: 1, transformOrigin: "0px 0px", duration: 0.62, ease: "power3.inOut" }, 1.55);
    tl.set({}, {}, 2.19);`,
);
sfx.push({ id: "hook", src: "tap", t: 0.93, v: 0.7 });

// =====================================================================
// zip (2.2–7.4s): ribbon solves the board, teal flash
// =====================================================================
const Z_DRAW_START = 0.35;
const Z_DRAW_END = 4.0;
const Z_SOLVED = 4.06;
const STEPS = puzzle.path.length - 1; // 63
const inv = (y) => (y < 0.5 ? Math.sqrt(y / 2) : 1 - Math.sqrt((1 - y) / 2)); // inverse of power1.inOut
const stepTime = (k) => Z_DRAW_START + (Z_DRAW_END - Z_DRAW_START) * inv(k / STEPS);
const startCell = center(puzzle.path[0]);
const zip = scene(
  "zip",
  `${HEAD_CSS("zip", C.ember)}
      ${BOARD_CSS("zip-board")}
      #zip-flash { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; border-radius: 22px; background: ${C.teal}; opacity: 0; }
      #zip-ring { position: absolute; left: ${BX - 6}px; top: ${BY - 6}px; width: ${BOARD + 12}px; height: ${BOARD + 12}px; border-radius: 26px; border: 6px solid ${C.teal}; opacity: 0; }
      #zip-done { position: absolute; left: 50%; top: 386px; width: 300px; margin-left: -150px; height: 72px; border-radius: 36px; background: ${C.wall}; border: 3px solid ${C.teal};
        display: flex; align-items: center; justify-content: center; font-size: 40px; font-weight: 700; color: ${C.teal}; opacity: 0; }`,
  `${headHtml("zip", 1, "Zip", "zipName")}
      <div id="zip-done">Solved</div>
      <div id="zip-board">${zipSvg("zip", { drawn: false })}</div>
      <div id="zip-flash"></div>
      <div id="zip-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    const PATH = ${JSON.stringify(puzzle.path)};
    const CELL = ${CELL};
    const STEPS = ${STEPS};
    const segs = Array.from(document.querySelectorAll("#zip-ribbon [data-seg]"));
    const nums = Array.from(document.querySelectorAll("#zip-nums [data-num]"));
    const tipGlow = document.getElementById("zip-tipglow");
    const tipDot = document.getElementById("zip-tipdot");
    const STOPS = ${JSON.stringify(STOPS.map(hex))};
    function colorAt(i) {
      if (i <= 0) i = 0;
      const w = (i / 4) % STOPS.length, k = Math.floor(w) % STOPS.length, f = w - Math.floor(w);
      const a = STOPS[k], b = STOPS[(k + 1) % STOPS.length];
      return "rgb(" + a.map((v, j) => Math.round(v + (b[j] - v) * f)).join(",") + ")";
    }
    const centre = (i) => [(PATH[i][1] + 0.5) * CELL, (PATH[i][0] + 0.5) * CELL];
    const state = { p: 0 };
    function render() {
      const p = state.p;
      for (let i = 0; i < segs.length; i++) {
        const f = Math.max(0, Math.min(1, p - i));
        segs[i].setAttribute("opacity", f > 0 ? "1" : "0");
        segs[i].setAttribute("stroke-dashoffset", String(CELL * (1 - f)));
      }
      const i = Math.min(Math.floor(p), STEPS);
      const f = p - i;
      const a = centre(i), b = centre(Math.min(i + 1, STEPS));
      const x = a[0] + (b[0] - a[0]) * f, y = a[1] + (b[1] - a[1]) * f;
      const col = colorAt(p);
      for (const el of [tipGlow, tipDot]) { el.setAttribute("cx", x); el.setAttribute("cy", y); el.setAttribute("fill", col); }
      for (const n of nums) {
        const on = p > 0.02 && p >= Number(n.dataset.idx) - 0.35;
        n.setAttribute("fill", on ? "${C.onInk}" : "${C.number}");
        n.setAttribute("stroke-width", on ? "8" : "0");
      }
    }
    render();
    ${headIn("zip", 0.02)}
    // The line starts at 1, then draws all ${STEPS} steps.
    tl.fromTo("#zip-tip", { opacity: 0, scale: 0.4, svgOrigin: "${startCell[0]} ${startCell[1]}" }, { opacity: 1, scale: 1, duration: 0.25, ease: "expo.out" }, 0.15);
    tl.fromTo(state, { p: 0 }, { p: STEPS, duration: ${fx(Z_DRAW_END - Z_DRAW_START)}, ease: "power1.inOut", onUpdate: render }, ${Z_DRAW_START});
    // Solved: teal flash, ring, "Solved" chip.
    tl.fromTo("#zip-flash", { opacity: 0 }, { opacity: 0.5, duration: 0.08, ease: "power2.out" }, ${Z_SOLVED});
    tl.to("#zip-flash", { opacity: 0, duration: 0.55, ease: "power2.out" }, ${fx(Z_SOLVED + 0.1)});
    tl.fromTo("#zip-ring", { opacity: 0, scale: 1.04 }, { opacity: 1, scale: 1, duration: 0.35, ease: "expo.out" }, ${Z_SOLVED});
    tl.fromTo("#zip-board", { scale: 1 }, { scale: 1.025, duration: 0.12, ease: "power2.out" }, ${Z_SOLVED});
    tl.to("#zip-board", { scale: 1, duration: 0.5, ease: "elastic.out(1, 0.6)" }, ${fx(Z_SOLVED + 0.12)});
    tl.fromTo("#zip-done", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.6)" }, ${fx(Z_SOLVED + 0.15)});
    // Out: blur swap; the next board lands on the same stage.
    ${headOut("zip", 4.92)}
    tl.to(["#zip-done", "#zip-ring"], { opacity: 0, duration: 0.14, ease: "power2.in" }, 4.92);
    tl.to("#zip-board", { opacity: 0, filter: "blur(8px)", duration: 0.2, ease: "power2.in" }, 4.95);
    tl.set({}, {}, ${fx(T.zip[1] - 0.01)});`,
);
for (let k = 8, n = 0; k <= 56; k += 8, n++) {
  const vols = [0.55, 0.8, 0.65, 0.9];
  sfx.push({ id: `zip-tap-${n + 1}`, src: "tap", t: fx(T.zip[0] + stepTime(k) + 0.033), v: vols[n % vols.length] });
}
sfx.push({ id: "zip-success", src: "success", t: fx(T.zip[0] + Z_SOLVED + 0.033), v: 1, d: 0.55 });

// =====================================================================
// words (7.4–12.8s): PUZZLE traced cell by cell, word pops
// =====================================================================
const W_START = 0.55; // ring lands on P
const W_STEP = 0.3;
const cellAt = (i) => fx(W_START + 0.1 + i * W_STEP);
const W_FOUND = fx(cellAt(PW_WORD.length - 1) + 0.25);
const pwInset = PWC * 0.1;
const pwSize = fx(PWC - pwInset * 2);
const pwGrow = PW_WORD.map(([r, c], i) => {
  const x = fx(c * PWC + pwInset);
  const y = fx(r * PWC + pwInset);
  if (i === 0) return { from: { x, y, width: pwSize, height: pwSize }, to: {} };
  const [pr, pc] = PW_WORD[i - 1];
  if (c > pc) return { from: { x, width: 0 }, to: { width: pwSize } };
  if (c < pc) return { from: { x: fx(x + pwSize), width: 0 }, to: { x, width: pwSize } };
  if (r > pr) return { from: { y, height: 0 }, to: { height: pwSize } };
  return { from: { y: fx(y + pwSize), height: 0 }, to: { y, height: pwSize } };
});
const pwScript = pwGrow
  .map((g, i) => {
    const at = cellAt(i);
    if (i === 0)
      return `tl.fromTo('#words-cells [data-cell="0"]', { opacity: 0 }, { opacity: 1, duration: 0.12, ease: "power2.out" }, ${at});`;
    return `tl.set('#words-cells [data-cell="${i}"]', { opacity: 1 }, ${at});
    tl.fromTo('#words-cells [data-cell="${i}"]', { attr: ${JSON.stringify(g.from)} }, { attr: ${JSON.stringify({ ...g.from, ...g.to })}, duration: ${fx(W_STEP * 0.8)}, ease: "power2.out" }, ${at});`;
  })
  .join("\n    ");
const words = scene(
  "words",
  `${HEAD_CSS("words", C.sky)}
      ${BOARD_CSS("words-board")}
      #words-chip { position: absolute; left: 50%; top: 384px; width: 340px; margin-left: -170px; height: 76px; border-radius: 38px; background: ${C.wall}; border: 3px solid ${C.sky};
        display: flex; align-items: center; justify-content: center; gap: 14px; font-size: 44px; font-weight: 800; letter-spacing: 0.06em; color: ${C.sky}; opacity: 0; }
      #words-chip svg { width: 36px; height: 36px; }`,
  `${headHtml("words", 2, "Path Words", "wordsName")}
      <div id="words-chip"><svg viewBox="0 0 24 24"><path d="M4 12.5l5 5 11-11" fill="none" stroke="${C.sky}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/></svg><span data-var-text="foundWord">PUZZLE</span></div>
      <div id="words-board">${pwSvg("words")}</div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Blur swap in: the board sharpens on the stage Zip left.
    tl.fromTo("#words-board", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power2.out" }, 0);
    ${headIn("words", 0.04)}
    // Start ring lands on P, then the trace grows cell by cell.
    tl.fromTo("#words-ring", { opacity: 0 }, { opacity: 1, duration: 0.2, ease: "power2.out" }, ${W_START});
    ${pwScript}
    // Found: letters pop, the board glows teal, the word lands in its chip.
    tl.to("#words-letters [data-pw]", { attr: { "font-size": 70 }, duration: 0.12, ease: "power2.out", stagger: 0.04 }, ${W_FOUND});
    tl.to("#words-letters [data-pw]", { attr: { "font-size": 56 }, duration: 0.3, ease: "power2.out", stagger: 0.04 }, ${fx(W_FOUND + 0.12)});
    tl.to("#words-ring", { opacity: 0, duration: 0.15 }, ${W_FOUND});
    tl.fromTo("#words-glow", { opacity: 0 }, { opacity: 1, duration: 0.2, ease: "power2.out" }, ${W_FOUND});
    tl.fromTo("#words-chip", { opacity: 0, scale: 0.6, y: 20 }, { opacity: 1, scale: 1, y: 0, duration: 0.45, ease: "back.out(1.7)" }, ${fx(W_FOUND + 0.2)});
    // Out: a whip to the left; Sudoku arrives from the right.
    ${headOut("words", 5.02)}
    tl.to("#words-chip", { opacity: 0, filter: "blur(8px)", duration: 0.14, ease: "power2.in" }, 5.02);
    tl.to("#words-board", { x: -700, opacity: 0, filter: "blur(14px)", duration: 0.3, ease: "power3.in" }, 5.11);
    tl.set({}, {}, ${fx(T.words[1] - 0.01)});`,
);
PW_WORD.forEach((_, i) => {
  const vols = [0.6, 0.8, 0.65, 0.85, 0.6, 0.85];
  sfx.push({ id: `words-tap-${i + 1}`, src: "tap", t: fx(T.words[0] + cellAt(i) + 0.033), v: vols[i] });
});
sfx.push({ id: "words-success", src: "success", t: fx(T.words[0] + W_FOUND + 0.033), v: 1, d: 0.55 });
// chip lands ~0.3 s into its back.out -> clear peaks at 0.166 s
sfx.push({ id: "words-pop", src: "clear", t: fx(T.words[0] + W_FOUND + 0.2 + 0.2 - 0.166), v: 0.6, d: 0.5 });

// =====================================================================
// sudoku (12.8–18.2s): empty cells fill, a row then a box flash teal, solved
// =====================================================================
const washSel = (cells) => cells.map(([r, c]) => `#sudoku-washes [data-wash="${r},${c}"]`).join(", ");
const sdFillScript = FILLS.map(([r, c], i) => {
  const at = FILL_AT[i];
  return `tl.set("#sudoku-sel", { attr: { x: ${c * SDC + 3}, y: ${r * SDC + 3} }, opacity: 0.22 }, ${fx(at - 0.14)});
    tl.fromTo('#sudoku-digits [data-fill="${i}"]', { opacity: 0, attr: { "font-size": 28 } }, { opacity: 1, attr: { "font-size": ${fx(SDC * 0.48)} }, duration: 0.24, ease: "back.out(2)" }, ${at});`;
}).join("\n    ");
const flash = (cells, at) =>
  `tl.fromTo('${washSel(cells)}', { opacity: 0 }, { opacity: 0.42, duration: 0.18, ease: "power2.out", stagger: 0.035 }, ${at});
    tl.to('${washSel(cells)}', { opacity: 0, duration: 0.4, ease: "power2.inOut", stagger: 0.035 }, ${fx(at + 0.3)});`;
const allCells = [];
for (let r = 0; r < 6; r++) for (let c = 0; c < 6; c++) allCells.push([r, c]);
const sudoku = scene(
  "sudoku",
  `${HEAD_CSS("sudoku", C.teal)}
      ${BOARD_CSS("sudoku-board")}
      #sudoku-ring { position: absolute; left: ${BX - 6}px; top: ${BY - 6}px; width: ${BOARD + 12}px; height: ${BOARD + 12}px; border-radius: 26px; border: 6px solid ${C.teal}; opacity: 0; }
      #sudoku-done { position: absolute; left: 50%; top: 386px; width: 300px; margin-left: -150px; height: 72px; border-radius: 36px; background: ${C.wall}; border: 3px solid ${C.teal};
        display: flex; align-items: center; justify-content: center; font-size: 40px; font-weight: 700; color: ${C.teal}; opacity: 0; }`,
  `${headHtml("sudoku", 3, "Sudoku", "sudokuName")}
      <div id="sudoku-done">Solved</div>
      <div id="sudoku-board">${sdSvg("sudoku", { solved: false })}</div>
      <div id="sudoku-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Whip in from the right, lands blurred and sharpens.
    tl.fromTo("#sudoku-board", { x: 700, opacity: 0.5, filter: "blur(14px)" }, { x: 0, opacity: 1, filter: "blur(0px)", duration: 0.4, ease: "expo.out" }, 0);
    ${headIn("sudoku", 0.06)}
    // Each empty cell: selected (sky), then its digit pops in.
    ${sdFillScript}
    tl.to("#sudoku-sel", { opacity: 0, duration: 0.15 }, ${fx(FILL_AT[FILL_AT.length - 1] + 0.1)});
    // Row 2 completes, then the bottom-right 2x3 box.
    ${flash(ROW_FLASH.cells, ROW_FLASH.at)}
    ${flash(BOX_FLASH.cells, BOX_FLASH.at)}
    // Solved: the whole board washes teal and holds.
    tl.fromTo('${washSel(allCells)}', { opacity: 0 }, { opacity: 0.24, duration: 0.25, ease: "power2.out", stagger: 0.012 }, ${SOLVED_AT});
    tl.fromTo("#sudoku-ring", { opacity: 0, scale: 1.04 }, { opacity: 1, scale: 1, duration: 0.35, ease: "expo.out" }, ${SOLVED_AT});
    tl.fromTo("#sudoku-board", { scale: 1 }, { scale: 1.025, duration: 0.12, ease: "power2.out" }, ${SOLVED_AT});
    tl.to("#sudoku-board", { scale: 1, duration: 0.5, ease: "elastic.out(1, 0.6)" }, ${fx(SOLVED_AT + 0.12)});
    tl.fromTo("#sudoku-done", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.6)" }, ${fx(SOLVED_AT + 0.15)});
    // Out: the board falls away (zoom out) for the features.
    ${headOut("sudoku", 5.0)}
    tl.to(["#sudoku-done", "#sudoku-ring"], { opacity: 0, duration: 0.14, ease: "power2.in" }, 5.0);
    tl.to("#sudoku-board", { scale: 0.7, opacity: 0, filter: "blur(10px)", duration: 0.3, ease: "power3.in" }, 5.05);
    tl.set({}, {}, ${fx(T.sudoku[1] - 0.01)});`,
);
FILL_AT.forEach((at, i) => {
  const vols = [0.5, 0.7, 0.55, 0.75, 0.5, 0.7, 0.55, 0.75, 0.6];
  sfx.push({ id: `sudoku-tap-${i + 1}`, src: "tap", t: fx(T.sudoku[0] + at + 0.033), v: vols[i] });
});
sfx.push({ id: "sudoku-row", src: "clear", t: fx(T.sudoku[0] + ROW_FLASH.at + 0.12 - 0.166), v: 0.5, d: 0.5 });
sfx.push({ id: "sudoku-box", src: "clear", t: fx(T.sudoku[0] + BOX_FLASH.at + 0.12 - 0.166), v: 0.5, d: 0.5 });
sfx.push({ id: "sudoku-success", src: "success", t: fx(T.sudoku[0] + SOLVED_AT + 0.033), v: 1, d: 0.55 });

// =====================================================================
// features (18.2–23.3s): leaderboard, streak, hints cost time
// =====================================================================
const F = [
  { at: 0.0, out: 1.5 },
  { at: 1.62, out: 3.05 },
  { at: 3.17, out: 4.9 },
];
const STAR = `<path fill="${C.star}" d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 9.4l6.6-.8z"/>`;
const FLAME = `<path fill="${C.star}" d="M12 1.8c.6 3.3 2.6 5 4.4 6.9 1.6 1.7 2.9 3.6 2.9 6.4 0 4.2-3.3 7.1-7.3 7.1s-7.3-2.9-7.3-7c0-2.6 1.2-4.6 2.9-6.1.1 1.6.8 2.9 2 3.6-.3-4.4 1-8.1 2.4-10.9z"/><path fill="${C.ember}" d="M12.1 11.4c.4 1.8 1.5 2.7 2.4 3.7.8.9 1.3 1.8 1.3 3.1 0 2.1-1.7 3.6-3.8 3.6s-3.8-1.5-3.8-3.6c0-1.6.8-2.8 1.9-3.6.1.9.5 1.5 1.1 1.9-.1-2 .3-3.7.9-5.1z"/>`;
const BULB = `<path fill="none" stroke="${C.star}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.6 10.8c.7.5 1.1 1.3 1.1 2.2h5c0-.9.4-1.7 1.1-2.2A6 6 0 0 0 12 3z"/>`;
const rows = [
  ["1", "Maya", "0:38", false],
  ["2", "Arjun", "0:44", false],
  ["3", "You", "0:47", true],
  ["4", "Leo", "0:52", false],
];
const features = scene(
  "features",
  `.feat-head { position: absolute; left: 40px; right: 40px; top: 230px; text-align: center; font-size: 100px; font-weight: 800; letter-spacing: -0.03em; line-height: 1.04; opacity: 0; }
      .feat-head span { display: block; }
      #feat-h1 .acc { color: ${C.sky}; } #feat-h2 .acc { color: ${C.star}; } #feat-h3 .acc { color: ${C.teal}; }
      #feat-h3 { font-size: 92px; }
      .feat-vis { position: absolute; left: 0; right: 0; top: 560px; height: 680px; opacity: 0; }
      #feat-board { position: absolute; left: 140px; width: 800px; top: 40px; border-radius: 28px; background: ${C.wall}; border: 2px solid ${C.outline}; padding: 26px 28px; }
      #feat-board .cap { font-size: 32px; font-weight: 600; color: ${C.inkSoft}; letter-spacing: 0.14em; margin: 0 0 18px 8px; line-height: 1; }
      .lb-row { display: flex; align-items: center; height: 104px; padding: 0 26px; border-radius: 20px; margin-top: 12px; background: ${C.paper}; font-size: 44px; font-weight: 700; }
      .lb-row .rk { width: 70px; color: ${C.inkSoft}; }
      .lb-row .nm { flex: 1; }
      .lb-row .tm { font-variant-numeric: tabular-nums; }
      .lb-row.me { background: #3A241C; border: 3px solid ${C.ember}; }
      .lb-row.me .rk { color: ${C.star}; }
      .lb-row.me svg { width: 40px; height: 40px; margin-right: 14px; }
      #feat-flame { position: absolute; left: 200px; top: 80px; width: 340px; height: 400px; }
      #feat-days { position: absolute; left: 560px; top: 110px; width: 360px; font-size: 230px; font-weight: 800; line-height: 1; color: ${C.onInk}; font-variant-numeric: tabular-nums; }
      #feat-dayslab { position: absolute; left: 566px; top: 360px; font-size: 48px; font-weight: 700; color: ${C.star}; line-height: 1; }
      #feat-week { position: absolute; left: 150px; top: 540px; width: 780px; display: flex; justify-content: space-between; }
      #feat-week i { display: block; width: 92px; height: 92px; border-radius: 46px; background: ${C.star}; }
      #feat-week i.off { background: ${C.paper}; border: 3px solid ${C.outline}; }
      #feat-hint { position: absolute; left: 160px; top: 90px; width: 760px; height: 300px; border-radius: 28px; background: ${C.wall}; border: 2px solid ${C.outline}; }
      #feat-btn { position: absolute; left: 50px; top: 50px; width: 200px; height: 200px; border-radius: 100px; background: ${C.paper}; border: 4px solid ${C.star}; display: flex; align-items: center; justify-content: center; }
      #feat-btn svg { width: 110px; height: 110px; }
      #feat-clock { position: absolute; left: 300px; top: 70px; font-size: 150px; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; }
      #feat-cliplab { position: absolute; left: 306px; top: 228px; font-size: 34px; font-weight: 600; color: ${C.inkSoft}; letter-spacing: 0.12em; line-height: 1; }
      #feat-chip { position: absolute; left: 700px; top: 36px; width: 260px; height: 110px; border-radius: 55px; background: ${C.number}; color: ${C.ink};
        display: flex; align-items: center; justify-content: center; font-size: 64px; font-weight: 800; opacity: 0; }`,
  `<div id="feat-h1" class="feat-head"><span>Daily</span><span class="acc">leaderboard</span></div>
      <div id="feat-v1" class="feat-vis">
        <div id="feat-board">
          <div class="cap">TODAY'S ZIP</div>
          ${rows
            .map(
              ([rk, nm, tm, me], i) =>
                `<div id="feat-row${i + 1}" class="lb-row${me ? " me" : ""}"><span class="rk">${me ? `<svg viewBox="0 0 24 24">${STAR}</svg>` : rk}</span><span class="nm">${me ? `#${rk} You` : nm}</span><span class="tm">${tm}</span></div>`,
            )
            .join("\n          ")}
        </div>
      </div>
      <div id="feat-h2" class="feat-head"><span>Keep your</span><span class="acc">streak</span></div>
      <div id="feat-v2" class="feat-vis">
        <svg id="feat-flame" viewBox="0 0 24 24">${FLAME}</svg>
        <div id="feat-days">12</div>
        <div id="feat-dayslab">day streak</div>
        <div id="feat-week">${[1, 1, 1, 1, 1, 1, 0].map((on, i) => `<i id="feat-d${i + 1}"${on ? "" : ` class="off"`}></i>`).join("")}</div>
      </div>
      <div id="feat-h3" class="feat-head"><span>Hints cost time,</span><span class="acc">not lockouts</span></div>
      <div id="feat-v3" class="feat-vis">
        <div id="feat-hint">
          <div id="feat-btn"><svg viewBox="0 0 24 24">${BULB}</svg></div>
          <div id="feat-clock">0:47</div>
          <div id="feat-cliplab">YOUR TIME</div>
        </div>
        <div id="feat-chip">+10s</div>
      </div>`,
  `    const tl = gsap.timeline({ paused: true });
    const inHead = (sel, at) => tl.fromTo(sel + " span", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.16, ease: "power4.out", stagger: 0.08 }, at);
    const showHead = (sel, at) => { tl.set(sel, { opacity: 1 }, at); inHead(sel, at); };
    const outBeat = (head, vis, at) => {
      tl.to(head + " span", { opacity: 0, filter: "blur(8px)", duration: 0.13, ease: "power2.in", stagger: 0.03 }, at);
      tl.to(vis, { opacity: 0, y: -24, filter: "blur(8px)", duration: 0.16, ease: "power2.in" }, at);
    };
    // 1. Daily leaderboard: the card lands, "You" row pops.
    showHead("#feat-h1", ${fx(F[0].at + 0.05)});
    tl.fromTo("#feat-v1", { opacity: 0, y: 80 }, { opacity: 1, y: 0, duration: 0.45, ease: "expo.out" }, ${F[0].at + 0.1});
    tl.fromTo(["#feat-row1", "#feat-row2", "#feat-row4"], { opacity: 0, x: -30 }, { opacity: 1, x: 0, duration: 0.3, ease: "expo.out", stagger: 0.06 }, ${F[0].at + 0.18});
    tl.fromTo("#feat-row3", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.45, ease: "back.out(1.7)" }, ${F[0].at + 0.45});
    outBeat("#feat-h1", "#feat-v1", ${F[0].out});
    // 2. Keep your streak: flame lights, the count rolls 11 -> 12, the week fills.
    showHead("#feat-h2", ${F[1].at});
    tl.set("#feat-v2", { opacity: 1 }, ${F[1].at});
    tl.fromTo("#feat-flame", { scale: 0.4, opacity: 0, transformOrigin: "50% 90%" }, { scale: 1, opacity: 1, duration: 0.5, ease: "back.out(1.6)" }, ${F[1].at + 0.05});
    tl.fromTo(["#feat-days", "#feat-dayslab"], { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out", stagger: 0.06 }, ${F[1].at + 0.12});
    tl.set("#feat-days", { textContent: "11" }, ${F[1].at});
    tl.set("#feat-days", { textContent: "12" }, ${fx(F[1].at + 0.55)});
    tl.fromTo("#feat-days", { scale: 1 }, { scale: 1.12, duration: 0.1, ease: "power2.out", transformOrigin: "0% 50%" }, ${fx(F[1].at + 0.55)});
    tl.to("#feat-days", { scale: 1, duration: 0.35, ease: "power2.out" }, ${fx(F[1].at + 0.65)});
    tl.fromTo("#feat-week i", { opacity: 0, scale: 0.5 }, { opacity: 1, scale: 1, duration: 0.25, ease: "back.out(2)", stagger: 0.05 }, ${F[1].at + 0.2});
    outBeat("#feat-h2", "#feat-v2", ${fx(F[2].at - 0.12)});
    // 3. Hints cost time: tap the hint, "+10s" pops, the clock jumps 0:47 -> 0:57.
    showHead("#feat-h3", ${F[2].at});
    tl.fromTo("#feat-v3", { opacity: 0, y: 80 }, { opacity: 1, y: 0, duration: 0.45, ease: "expo.out" }, ${fx(F[2].at + 0.05)});
    tl.fromTo("#feat-btn", { scale: 1 }, { scale: 0.88, duration: 0.08, ease: "power2.in" }, ${fx(F[2].at + 0.6)});
    tl.to("#feat-btn", { scale: 1, duration: 0.3, ease: "back.out(2)" }, ${fx(F[2].at + 0.68)});
    tl.fromTo("#feat-chip", { opacity: 0, scale: 0.5, y: 30 }, { opacity: 1, scale: 1, y: 0, duration: 0.45, ease: "back.out(1.8)" }, ${fx(F[2].at + 0.68)});
    tl.set("#feat-clock", { textContent: "0:47", color: "${C.onInk}" }, ${F[2].at});
    tl.set("#feat-clock", { textContent: "0:57" }, ${fx(F[2].at + 0.85)});
    tl.fromTo("#feat-clock", { color: "${C.number}" }, { color: "${C.onInk}", duration: 0.6, ease: "power2.out" }, ${fx(F[2].at + 0.85)});
    outBeat("#feat-h3", "#feat-v3", ${F[2].out});
    tl.set({}, {}, ${fx(T.features[1] - 0.01)});`,
);
// pops: "You" row, streak count, +10s chip (clear peaks at 0.166 s)
sfx.push({ id: "feat-pop-1", src: "clear", t: fx(T.features[0] + F[0].at + 0.45 + 0.2 - 0.166), v: 0.6, d: 0.5 });
sfx.push({ id: "feat-pop-2", src: "clear", t: fx(T.features[0] + F[1].at + 0.55 + 0.033 - 0.166), v: 0.6, d: 0.5 });
sfx.push({ id: "feat-pop-3", src: "clear", t: fx(T.features[0] + F[2].at + 0.68 + 0.2 - 0.166), v: 0.65, d: 0.5 });
sfx.push({ id: "feat-hint-tap", src: "tap", t: fx(T.features[0] + F[2].at + 0.6 + 0.033), v: 0.8 });

// =====================================================================
// cta (23.3–25.8s): logo lockup, held >= 2 s
// =====================================================================
const cta = scene(
  "cta",
  `#cta-line { position: absolute; left: 40px; right: 40px; top: 250px; text-align: center; font-size: 72px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.05; opacity: 0; }
      #cta-line .acc { color: ${C.ember}; }
      #cta-logo { position: absolute; left: 0; right: 0; top: 520px; height: 680px; opacity: 0; }
      #cta-icon { position: absolute; left: 50%; top: 0; width: 320px; height: 320px; margin-left: -160px; }
      #cta-name { position: absolute; left: 0; right: 0; top: 350px; text-align: center; font-size: 132px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; }
      #cta-pill { position: absolute; left: 50%; top: 528px; width: 520px; margin-left: -260px; height: 96px; border-radius: 48px; background: ${C.ember}; color: ${C.ink};
        display: flex; align-items: center; justify-content: center; font-size: 52px; font-weight: 700; }`,
  `<div id="cta-line"><span data-var-text="ctaLine">3 puzzles. </span><span class="acc">Every day.</span></div>
      <div id="cta-logo">
        <img id="cta-icon" src="assets/app_icon.png" alt="Winklo" />
        <div id="cta-name" data-var-text="brandName">Winklo</div>
        <div id="cta-pill" data-var-text="ctaPill">Free on Android</div>
      </div>`,
  `    const tl = gsap.timeline({ paused: true });
    tl.fromTo("#cta-logo", { opacity: 0 }, { opacity: 1, duration: 0.12, ease: "power2.out" }, 0.04);
    tl.fromTo("#cta-icon", { scale: 0.7, filter: "blur(10px)" }, { scale: 1, filter: "blur(0px)", duration: 0.5, ease: "expo.out" }, 0.04);
    tl.fromTo("#cta-name", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 0.12);
    tl.fromTo("#cta-pill", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.5)" }, 0.2);
    tl.fromTo("#cta-line", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 0.3);
    tl.set({}, {}, ${fx(T.cta[1] - 0.01)});`,
);
sfx.push({ id: "logo", src: "clear", t: fx(T.cta[0] + 0.12 - 0.166 + 0.1), v: 0.85, d: 0.5 });

// =====================================================================
// index
// =====================================================================
const vars = [
  ["hookLine1", "Hook line 1", "3 puzzles."],
  ["hookLine2", "Hook line 2 (ember)", "Every day."],
  ["hookLine3", "Hook line 3 (teal)", "Free."],
];
// Lanes: taps on lane 2; any clip that overlaps a lane-2 clip goes on lane 3.
sfx.sort((a, b) => a.t - b.t);
const laneEnd = { 2: -1, 3: -1 };
const audio = sfx.map((s) => {
  const d = s.d ?? 0.01;
  const lane = laneEnd[2] <= s.t ? 2 : 3;
  laneEnd[lane] = s.t + d;
  return `<audio id="sfx-${s.id}" class="clip" src="assets/sfx/${s.src}.ogg" data-start="${s.t}" data-duration="${d}" data-track-index="${lane}" data-volume="${s.v}"></audio>`;
});
const host = (id, [start, dur]) =>
  `<div id="${id}" data-composition-id="${id}" data-composition-src="compositions/${id}.html" data-start="${start}" data-duration="${dur}" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>`;

const index = `<!doctype html>
<html lang="en" data-composition-variables='${JSON.stringify(vars.map(([id, label, def]) => ({ id, type: "string", label, default: def })))}'>
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
for (const [name, html] of Object.entries({ hook, zip, words, sudoku, features, cta }))
  fs.writeFileSync(path.join(root, `compositions/${name}.html`), html);
console.log("total", TOTAL, "pw fill", PW_FILL);
console.log(sfx.map((s) => `${s.id}@${s.t}`).join(" "));
