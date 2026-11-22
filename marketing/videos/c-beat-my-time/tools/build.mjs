// Generates index.html + compositions/*.html for Video C "Beat my time".
// The output is plain static HTML (what Studio edits). Re-running this OVERWRITES
// any Studio edits to those files: edit here, or stop using this script.
// Usage: node tools/build.mjs   (run from the project dir)
//
// The Zip puzzle is copied into this project (tools/zip-puzzle.json, from
// ../shared/zip-puzzle.json, unchanged) so the project stands alone.
// Board, ribbon, type, CTA lockup and sfx levels are copied from videos A and B.
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
};

// ---------- geometry (1080x1920) ----------
const W = 1080;
const H = 1920;
const FPS = 30;
// Board is 780 (A/B use 840) so the big clock fits above it: 540..1320, inside 168..1330.
const BOARD = 780;
const BX = (W - BOARD) / 2; // 150
const BY = 540;
const fx = (v) => Math.round(v * 1000) / 1000;

// =====================================================================
// Zip board (copied from videos A/B: lib/features/zip/game/zip_game.dart look)
// =====================================================================
const N = puzzle.size;
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
// The big clock. Each glyph sits in a fixed-width slot, so the digits never
// shift as they change (tabular, whatever the font's own figures do).
// =====================================================================
const CLOCK_FONT = 220; // hero size; the hook shows it at x0.6 = 132 px
const CLOCK_HOOK_SCALE = 0.6;
const CLOCK_TOP = 266; // hero box 266..486 (line-height 1)
const clockHtml = (p, text) => {
  const [m, s] = text.split(":");
  return `<div id="${p}-clock" class="clock" data-layout-allow-overflow><span class="cd" id="${p}-m">${m}</span><span class="cc">:</span><span class="cd" id="${p}-s1">${s[0]}</span><span class="cd" id="${p}-s2">${s[1]}</span></div>`;
};
const CLOCK_CSS = (p) => `
      #${p}-clock { position: absolute; left: 0; right: 0; top: ${CLOCK_TOP}px; height: ${CLOCK_FONT}px; text-align: center; font-size: ${CLOCK_FONT}px; font-weight: 700; line-height: 1; letter-spacing: 0; font-variant-numeric: tabular-nums; white-space: nowrap; transform-origin: 50% 50%; }
      #${p}-clock .cd { display: inline-block; width: 0.62em; text-align: center; }
      #${p}-clock .cc { display: inline-block; width: 0.3em; text-align: center; position: relative; top: -0.06em; }`;

// =====================================================================
// shared scene scaffolding
// =====================================================================
const FONT = `@font-face { font-family: Lexend; src: url('assets/fonts/Lexend-Variable.ttf'); font-weight: 100 900; }`;
const ROOT_CSS = `#root { position: absolute; inset: 0; overflow: hidden; font-family: Lexend, sans-serif; color: ${C.onInk};
        background: radial-gradient(1200px 900px at 50% 42%, #16213A 0%, ${C.ink} 70%); }`;
const BOARD_CSS = (id) =>
  `#${id} { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; }
      #${id} svg { display: block; filter: drop-shadow(0 8px 0 rgba(0,0,0,0.35)); }`;
const KICKER_CSS = (id, color) =>
  `#${id} { position: absolute; left: 0; right: 0; top: 196px; text-align: center; font-size: 36px; font-weight: 600; letter-spacing: 0.18em; line-height: 1; color: ${color}; }`;
const RING_CSS = (id) =>
  `#${id} { position: absolute; left: ${BX - 6}px; top: ${BY - 6}px; width: ${BOARD + 12}px; height: ${BOARD + 12}px; border-radius: 26px; border: 6px solid ${C.teal}; }`;

// Hook copy: "Today's Zip." / "Beat my time." with the clock under it.
// l1 64 px at 184, l2 108 px ember at 256, clock (132 px) centred at y 452.
const HOOK_CLOCK_CY = 452;
const HERO_CLOCK_CY = CLOCK_TOP + CLOCK_FONT / 2; // 376
const HOOK_DY = HOOK_CLOCK_CY - HERO_CLOCK_CY; // 76
const HOOK_CSS = `
      .hook-text { position: absolute; left: 40px; right: 40px; top: 180px; text-align: center; line-height: 1; font-weight: 700; letter-spacing: -0.02em; }
      .hook-text .l1 { display: block; font-size: 66px; }
      .hook-text .l2 { display: block; font-size: 112px; font-weight: 800; color: ${C.ember}; margin-top: 8px; }`;
const hookTextHtml = (p) => `<div id="${p}-text" class="hook-text">
        <span class="l1" data-var-text="hookLine1">Today's Zip.</span>
        <span class="l2" data-var-text="hookLine2">Beat my time.</span>
      </div>`;

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
  hook: [0, 1.6],
  solve: [1.6, 10.6],
  move: [12.2, 3.0],
  cta: [15.2, 4.6],
};
const TOTAL = fx(T.cta[0] + T.cta[1]); // 19.8
const sfx = []; // { id, src, t, v, d }

// =====================================================================
// hook (0–1.6s): frame 0 = the whole hook, clock at 0:00 over the empty board
// =====================================================================
const startCell = center(puzzle.path[0]);
const hook = scene(
  "hook",
  `${HOOK_CSS}
      ${CLOCK_CSS("hook")}
      ${BOARD_CSS("hook-board")}
      #hook-ring { position: absolute; left: ${BX + startCell[0] - 44}px; top: ${BY + startCell[1] - 44}px; width: 88px; height: 88px; border-radius: 50%; border: 5px solid ${C.ember}; opacity: 0; }`,
  `${hookTextHtml("hook")}
      ${clockHtml("hook", "0:00")}
      <div id="hook-board">${zipSvg("hook", { drawn: false })}</div>
      <div id="hook-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    // The clock sits small under the hook copy (same element size as the hero clock, scaled).
    tl.set("#hook-clock", { y: ${HOOK_DY}, scale: ${CLOCK_HOOK_SCALE} }, 0);
    // One-shot cue: a ring lands on "1", where the line starts.
    tl.fromTo("#hook-ring", { opacity: 0, scale: 1.8 }, { opacity: 1, scale: 1, duration: 0.45, ease: "expo.out" }, 0.8);
    tl.to("#hook-ring", { opacity: 0, duration: 0.15, ease: "power2.in" }, 1.42);
    tl.set({}, {}, ${fx(T.hook[1] - 0.01)});`,
);
sfx.push({ id: "hook", src: "tap", t: 0.83, v: 0.7 });

// =====================================================================
// solve (1.6–12.2s): the ribbon draws all 63 steps while the clock counts
// 0:00 -> 0:47 from solve progress; the solve frame shows 0:47, the teal
// flash and the clock's pop.
// =====================================================================
const STEPS = puzzle.path.length - 1; // 63
const SOLVE_SECONDS = 47;
const DRAW_START = 0.3; // abs 1.9
// The draw ends 1/3 frame before a frame boundary, so the first frame at or
// after it (the solve frame) is past the end on any float rounding: p = 63.
const DRAW_END = 9.09; // abs 10.69 -> solve frame = abs 10.7 = frame 321
const DRAW_DUR = fx(DRAW_END - DRAW_START);
const SOLVE_FRAME = Math.ceil((T.solve[0] + DRAW_END) * FPS); // 321
const SOLVE_ABS = SOLVE_FRAME / FPS;
// Ribbon ease: half linear, half smoothstep, so the clock never stalls at the ends.
const easeP = (x) => {
  const u = Math.max(0, Math.min(1, x));
  return 0.5 * u + 0.5 * u * u * (3 - 2 * u);
};
const clockAtLocal = (t) => Math.floor((SOLVE_SECONDS * STEPS * easeP((t - DRAW_START) / DRAW_DUR)) / STEPS + 1e-9);
// Inverse of easeP by bisection (for sfx timing).
const invEase = (y) => {
  let lo = 0;
  let hi = 1;
  for (let k = 0; k < 60; k++) {
    const mid = (lo + hi) / 2;
    if (easeP(mid) < y) lo = mid;
    else hi = mid;
  }
  return (lo + hi) / 2;
};
const stepTime = (k) => DRAW_START + DRAW_DUR * invEase(k / STEPS);
// Verify: the solve frame is the first frame that reads 0:47.
{
  const local = (f) => f / FPS - T.solve[0];
  const before = clockAtLocal(local(SOLVE_FRAME - 1));
  const at = clockAtLocal(local(SOLVE_FRAME));
  if (!(before === 46 && at === 47)) throw new Error(`clock check failed: ${before} -> ${at}`);
}

const solve = scene(
  "solve",
  `${HOOK_CSS}
      ${CLOCK_CSS("solve")}
      ${BOARD_CSS("solve-board")}
      ${KICKER_CSS("solve-kicker", C.inkSoft)}
      ${KICKER_CSS("solve-solved", C.teal)}
      #solve-kicker, #solve-solved { opacity: 0; }
      #solve-flash { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; border-radius: 22px; background: ${C.teal}; opacity: 0; }
      ${RING_CSS("solve-ring")}
      #solve-ring { opacity: 0; }`,
  `${hookTextHtml("solve")}
      <div id="solve-kicker" data-layout-allow-overlap data-var-text="kicker">TODAY'S ZIP</div>
      <div id="solve-solved" data-var-text="solvedWord">SOLVED</div>
      ${clockHtml("solve", "0:00")}
      <div id="solve-board">${zipSvg("solve", { drawn: false })}</div>
      <div id="solve-flash"></div>
      <div id="solve-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    const PATH = ${JSON.stringify(puzzle.path)};
    const CELL = ${CELL};
    const STEPS = ${STEPS};
    const SOLVE_SECONDS = ${SOLVE_SECONDS};
    const DRAW_START = ${DRAW_START}, DRAW_DUR = ${DRAW_DUR}, HIT = ${DRAW_END};
    const HOOK_DY = ${HOOK_DY}, HOOK_SCALE = ${CLOCK_HOOK_SCALE};
    const segs = Array.from(document.querySelectorAll("#solve-ribbon [data-seg]"));
    const nums = Array.from(document.querySelectorAll("#solve-nums [data-num]"));
    const tipGlow = document.getElementById("solve-tipglow");
    const tipDot = document.getElementById("solve-tipdot");
    const tip = document.getElementById("solve-tip");
    const clock = document.getElementById("solve-clock");
    const dM = document.getElementById("solve-m");
    const d1 = document.getElementById("solve-s1");
    const d2 = document.getElementById("solve-s2");
    const flash = document.getElementById("solve-flash");
    const ring = document.getElementById("solve-ring");
    const board = document.getElementById("solve-board");
    const kicker = document.getElementById("solve-kicker");
    const solved = document.getElementById("solve-solved");
    const STOPS = ${JSON.stringify(STOPS.map(hex))};
    const TEAL = ${JSON.stringify(hex(C.teal))}, WHITE = ${JSON.stringify(hex(C.onInk))};
    function colorAt(i) {
      if (i <= 0) i = 0;
      const w = (i / 4) % STOPS.length, k = Math.floor(w) % STOPS.length, f = w - Math.floor(w);
      const a = STOPS[k], b = STOPS[(k + 1) % STOPS.length];
      return "rgb(" + a.map((v, j) => Math.round(v + (b[j] - v) * f)).join(",") + ")";
    }
    const clamp = (v) => Math.max(0, Math.min(1, v));
    const easeP = (x) => { const u = clamp(x); return 0.5 * u + 0.5 * u * u * (3 - 2 * u); };
    const inOut3 = (x) => { const u = clamp(x); return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; };
    const out4 = (x) => 1 - Math.pow(1 - clamp(x), 4);
    const centre = (i) => [(PATH[i][1] + 0.5) * CELL, (PATH[i][0] + 0.5) * CELL];
    // Everything below is a pure function of scene time t.
    function render(t) {
      const p = STEPS * easeP((t - DRAW_START) / DRAW_DUR);
      for (let i = 0; i < segs.length; i++) {
        const f = clamp(p - i);
        segs[i].setAttribute("opacity", f > 0 ? "1" : "0");
        segs[i].setAttribute("stroke-dashoffset", String(CELL * (1 - f)));
      }
      const i = Math.min(Math.floor(p), STEPS);
      const f = p - i;
      const a = centre(i), b = centre(Math.min(i + 1, STEPS));
      const x = a[0] + (b[0] - a[0]) * f, y = a[1] + (b[1] - a[1]) * f;
      const col = colorAt(p);
      for (const el of [tipGlow, tipDot]) { el.setAttribute("cx", x); el.setAttribute("cy", y); el.setAttribute("fill", col); }
      // tip lands on "1" as the scene opens
      const tipIn = out4(t / 0.25);
      tip.setAttribute("opacity", String(tipIn));
      tip.setAttribute("transform", "translate(" + x + " " + y + ") scale(" + (0.4 + 0.6 * tipIn) + ") translate(" + -x + " " + -y + ")");
      for (const n of nums) {
        const on = p > 0.02 && p >= Number(n.dataset.idx) - 0.35;
        n.setAttribute("fill", on ? "${C.onInk}" : "${C.number}");
        n.setAttribute("stroke-width", on ? "8" : "0");
      }
      // The clock: seconds from solve progress, 0..47, exactly 47 when p = 63.
      const s = Math.floor((SOLVE_SECONDS * p) / STEPS + 1e-9);
      dM.textContent = "0";
      d1.textContent = String(Math.floor(s / 10));
      d2.textContent = String(s % 10);
      // Clock rises from the hook position to hero size (0.45 -> 0.95 s).
      const m = inOut3((t - 0.45) / 0.5);
      const h = t - HIT; // time since the solve
      let pop = 1;
      if (h >= 0) pop = 1 + 0.16 * Math.exp(-7 * h) * Math.cos(15 * h);
      const sc = (HOOK_SCALE + (1 - HOOK_SCALE) * m) * pop;
      clock.style.transform = "translateY(" + (HOOK_DY * (1 - m)) + "px) scale(" + sc + ")";
      const tc = h >= 0 ? 1 : 0;
      clock.style.color = "rgb(" + WHITE.map((v, j) => Math.round(v + (TEAL[j] - v) * tc)).join(",") + ")";
      // Solve: teal flash over the board, ring holds, board bumps.
      flash.style.opacity = h >= 0 ? String(0.5 * Math.pow(1 - clamp(h / 0.6), 2)) : "0";
      ring.style.opacity = h >= 0 ? String(out4(h / 0.3)) : "0";
      const bump = h >= 0 ? 1 + 0.025 * Math.exp(-6 * h) * Math.cos(12 * h) : 1;
      board.style.transform = "scale(" + bump + ")";
      // Kicker: TODAY'S ZIP fades in under the rising clock, swaps to SOLVED on the hit.
      const kin = out4((t - 0.7) / 0.2);
      const swap = h >= 0 ? out4((h - 0.1) / 0.18) : 0;
      kicker.style.opacity = String(kin * (1 - swap));
      kicker.style.filter = "blur(" + (8 * (1 - kin) + 8 * swap) + "px)";
      solved.style.opacity = String(swap);
      solved.style.filter = "blur(" + 8 * (1 - swap) + "px)";
    }
    const state = { t: 0 };
    render(0);
    // Hook copy carried over from the hook scene, then blurs away as the clock rises.
    tl.fromTo("#solve-text .l1", { opacity: 1, filter: "blur(0px)" }, { opacity: 0, filter: "blur(8px)", duration: 0.2, ease: "power2.in" }, 0.45);
    tl.fromTo("#solve-text .l2", { opacity: 1, filter: "blur(0px)" }, { opacity: 0, filter: "blur(8px)", duration: 0.2, ease: "power2.in" }, 0.5);
    // One linear driver over the whole scene; render(t) is a pure function of it.
    tl.fromTo(state, { t: 0 }, { t: ${T.solve[1]}, duration: ${T.solve[1]}, ease: "none", onUpdate: () => render(state.t) }, 0);`,
);
// tap ticks every 4 steps (peak at 0 -> +1 frame), volumes rotate as in A/B
{
  const vols = [0.55, 0.8, 0.65, 0.9];
  for (let k = 4, n = 0; k <= 60; k += 4, n++)
    sfx.push({ id: `tap-${n + 1}`, src: "tap", t: fx(T.solve[0] + stepTime(k) + 0.033), v: vols[n % vols.length] });
}
sfx.push({ id: "success", src: "success", t: fx(SOLVE_ABS + 0.033), v: 1, d: 0.55 });

// =====================================================================
// move (12.2–15.2s): the board falls away, "Your move." lands under 0:47
// =====================================================================
const move = scene(
  "move",
  `${CLOCK_CSS("move")}
      ${BOARD_CSS("move-board")}
      ${KICKER_CSS("move-solved", C.teal)}
      ${RING_CSS("move-ring")}
      #move-clock { color: ${C.teal}; }
      #move-line { position: absolute; left: 40px; right: 40px; top: 640px; text-align: center; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
      #move-line span { display: block; font-size: 236px; height: 250px; }
      #move-w2 { color: ${C.ember}; }`,
  `<div id="move-solved" data-var-text="solvedWord">SOLVED</div>
      ${clockHtml("move", "0:47")}
      <div id="move-stage">
        <div id="move-board">${zipSvg("move", { drawn: true })}</div>
        <div id="move-ring"></div>
      </div>
      <div id="move-line">
        <span id="move-w1" data-var-text="moveLine1">Your</span>
        <span id="move-w2" data-var-text="moveLine2">move.</span>
      </div>`,
  `    const tl = gsap.timeline({ paused: true });
    // The solved board falls away; 0:47 stays dead still as the time to beat.
    tl.fromTo("#move-stage", { y: 0, opacity: 1, filter: "blur(0px)" }, { y: 220, opacity: 0, filter: "blur(14px)", duration: 0.42, ease: "power3.in" }, 0.1);
    // "Your move." slams in word by word, then holds.
    tl.fromTo("#move-w1", { opacity: 0, scale: 1.45, filter: "blur(14px)" }, { opacity: 1, scale: 1, filter: "blur(0px)", duration: 0.34, ease: "expo.out" }, 0.42);
    tl.fromTo("#move-w2", { opacity: 0, scale: 1.45, filter: "blur(14px)" }, { opacity: 1, scale: 1, filter: "blur(0px)", duration: 0.34, ease: "expo.out" }, 0.56);
    // Out: blur swap into the CTA.
    tl.to(["#move-solved", "#move-clock", "#move-w1", "#move-w2"], { opacity: 0, filter: "blur(8px)", duration: 0.14, ease: "power2.in", stagger: 0.02 }, 2.82);
    tl.set({}, {}, ${fx(T.move[1] - 0.01)});`,
);
// "clear" pops peak at 0.166 s: land on "move." (0.56 s + ~0.1 s)
sfx.push({ id: "move-pop", src: "clear", t: fx(T.move[0] + 0.66 + 0.033 - 0.166), v: 0.6, d: 0.5 });

// =====================================================================
// cta (15.2–19.8s): logo lockup (as B) + "New puzzle at midnight", held >= 2 s
// =====================================================================
const LOGO_TOP = 360;
const cta = scene(
  "cta",
  `#cta-logo { position: absolute; left: 0; right: 0; top: ${LOGO_TOP}px; height: 800px; opacity: 0; }
      #cta-icon { position: absolute; left: 50%; top: 0; width: 320px; height: 320px; margin-left: -160px; }
      #cta-name { position: absolute; left: 0; right: 0; top: 350px; text-align: center; font-size: 132px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; }
      #cta-pill { position: absolute; left: 50%; top: 528px; width: 520px; margin-left: -260px; height: 96px; border-radius: 48px; background: ${C.ember}; color: ${C.ink};
        display: flex; align-items: center; justify-content: center; font-size: 52px; font-weight: 700; }
      #cta-sub { position: absolute; left: 40px; right: 40px; top: ${LOGO_TOP + 700}px; text-align: center; font-size: 60px; font-weight: 600; letter-spacing: -0.01em; line-height: 1; color: ${C.onInk}; opacity: 0; }`,
  `<div id="cta-logo">
        <img id="cta-icon" src="assets/app_icon.png" alt="Winklo" />
        <div id="cta-name" data-var-text="brandName">Winklo</div>
        <div id="cta-pill" data-var-text="ctaPill">Free on Android</div>
      </div>
      <div id="cta-sub" data-var-text="ctaSub">New puzzle at midnight</div>`,
  `    const tl = gsap.timeline({ paused: true });
    tl.fromTo("#cta-logo", { opacity: 0.3 }, { opacity: 1, duration: 0.12, ease: "power2.out" }, 0);
    tl.fromTo("#cta-icon", { scale: 0.7, filter: "blur(10px)" }, { scale: 1, filter: "blur(0px)", duration: 0.5, ease: "expo.out" }, 0);
    tl.fromTo("#cta-name", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 0.12);
    tl.fromTo("#cta-pill", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.5)" }, 0.2);
    tl.fromTo("#cta-sub", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 0.5);
    tl.set({}, {}, ${fx(T.cta[1] - 0.01)});`,
);
sfx.push({ id: "logo", src: "clear", t: fx(T.cta[0] + 0.12 - 0.166 + 0.1), v: 0.85, d: 0.5 });

// =====================================================================
// index
// =====================================================================
const vars = [
  ["hookLine1", "Hook line 1", "Today's Zip."],
  ["hookLine2", "Hook line 2 (ember)", "Beat my time."],
];
const MUSIC_VOL = 0.78;
// Per-sound trim over the bed, as in video B.
const SFX_GAIN = { tap: 0.72, success: 0.62, clear: 0.7 };
sfx.sort((a, b) => a.t - b.t);
const laneEnd = { 2: -1, 3: -1 };
const audio = sfx.map((s) => {
  const d = s.d ?? 0.01;
  const lane = laneEnd[2] <= s.t ? 2 : 3;
  laneEnd[lane] = s.t + d;
  return `<audio id="sfx-${s.id}" class="clip" src="assets/sfx/${s.src}.ogg" data-start="${s.t}" data-duration="${d}" data-track-index="${lane}" data-volume="${fx(s.v * SFX_GAIN[s.src])}"></audio>`;
});
// Music bed: "Curiositys Arrival" by Steven Booth (CC BY 3.0), a 32 s excerpt
// (assets/music/CREDIT.md). Own lane, as in A and B.
audio.push(
  `<audio id="music" class="clip" src="assets/music/curiositys-arrival.mp3" data-start="0" data-duration="${TOTAL}" data-track-index="4" data-volume="${MUSIC_VOL}" data-fade-in="0.2" data-fade-out="1.5"></audio>`,
);
const host = (id, [start, dur]) =>
  `<div id="${id}" data-composition-id="${id}" data-composition-src="compositions/${id}.html" data-start="${start}" data-duration="${dur}" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>`;

const index = `<!doctype html>
<html lang="en" data-composition-variables='${JSON.stringify(vars.map(([id, label, def]) => ({ id, type: "string", label, default: def }))).replace(/'/g, "&#39;")}'>
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
for (const [name, html] of Object.entries({ hook, solve, move, cta }))
  fs.writeFileSync(path.join(root, `compositions/${name}.html`), html);
console.log("total", TOTAL, "solve frame", SOLVE_FRAME, "=", fx(SOLVE_ABS), "s");
console.log(sfx.map((s) => `${s.id}@${s.t}`).join(" "));
