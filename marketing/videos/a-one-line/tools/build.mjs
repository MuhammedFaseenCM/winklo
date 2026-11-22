// Generates index.html + compositions/*.html for Video A "One line".
// The output is plain static HTML (what Studio edits). Re-running this OVERWRITES
// any Studio edits to those files — edit here, or stop using this script.
// Usage: node tools/build.mjs   (run from the project dir)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const puzzle = JSON.parse(
  fs.readFileSync(path.resolve(root, "../shared/zip-puzzle.json"), "utf8"),
);

// ---------- brand ----------
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
  skySoft: "#163044",
  teal: "#2DD4BF",
  star: "#FBBF24",
  number: "#FB7185",
};

// ---------- geometry (1080x1920) ----------
const W = 1080;
const H = 1920;
const BOARD = 840;
const BX = (W - BOARD) / 2; // 120
const BY = 480; // board 480..1320 (inside 168..1330)
const N = puzzle.size;
const CELL = BOARD / N; // 105
const RIBBON = CELL * 0.46;
const center = ([r, c]) => [(c + 0.5) * CELL, (r + 0.5) * CELL];
const fx = (v) => Math.round(v * 100) / 100;

// App ribbon colours (lib/features/zip/game/zip_path_ribbon.dart)
const STOPS = [C.ember, "#FFC53D", "#FF4D6D", "#E879F9"];
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const lerp = (a, b, t) => {
  const A = hex(a);
  const B = hex(b);
  return (
    "#" +
    A.map((v, i) =>
      Math.round(v + (B[i] - v) * t)
        .toString(16)
        .padStart(2, "0"),
    ).join("")
  );
};
const colorAt = (i) => {
  if (i <= 0) return STOPS[0];
  const t = i / 4;
  const w = t % STOPS.length;
  const k = Math.floor(w) % STOPS.length;
  return lerp(STOPS[k], STOPS[(k + 1) % STOPS.length], w - Math.floor(w));
};

const numberAt = new Map(puzzle.numbers.map((n) => [`${n.r},${n.c}`, n.n]));
const pathIndexOf = new Map(puzzle.path.map(([r, c], i) => [`${r},${c}`, i]));

// Board SVG. prefix keeps ids unique across the assembled page.
function boardSvg(prefix, { drawn }) {
  const cells = [];
  for (let r = 0; r < N; r++)
    for (let c = 0; c < N; c++)
      cells.push(
        `<rect x="${c * CELL + 3}" y="${r * CELL + 3}" width="${CELL - 6}" height="${CELL - 6}" rx="12" fill="${C.paper}"/>`,
      );
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
    const hidden = drawn ? "" : ` opacity="0"`;
    const dash = drawn ? "0" : fx(CELL);
    segs.push(
      `<line data-seg="${i}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="url(#${prefix}-g${i})" stroke-width="${fx(RIBBON)}" stroke-linecap="round" stroke-dasharray="${fx(CELL)} ${fx(CELL + 2)}" stroke-dashoffset="${dash}"${hidden}/>`,
    );
  }
  const nums = puzzle.numbers.map((n) => {
    const [x, y] = center([n.r, n.c]);
    const onPath = drawn;
    return `<text data-num="${n.n}" data-idx="${pathIndexOf.get(`${n.r},${n.c}`)}" x="${x}" y="${y}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="800" font-size="${fx(CELL * 0.4)}" fill="${onPath ? C.onInk : C.number}" stroke="${C.ink}" stroke-width="${onPath ? 8 : 0}" stroke-linejoin="round" paint-order="stroke">${n.n}</text>`;
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

const FONT = `@font-face { font-family: Lexend; src: url('assets/fonts/Lexend-Variable.ttf'); font-weight: 100 900; }`;
const ROOT_CSS = `#root { position: absolute; inset: 0; overflow: hidden; font-family: Lexend, sans-serif; color: ${C.onInk};
        background: radial-gradient(1200px 900px at 50% 42%, #16213A 0%, ${C.ink} 70%); }`;
const BOARD_CSS = (id) =>
  `#${id} { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; }
      #${id} svg { display: block; filter: drop-shadow(0 8px 0 rgba(0,0,0,0.35)); }`;

const HOOK_CSS = `
      .hook-text { position: absolute; left: 60px; right: 60px; top: 182px; text-align: center; line-height: 1.04; font-weight: 700; letter-spacing: -0.02em; }
      .hook-text .l1, .hook-text .l3 { display: block; font-size: 66px; }
      .hook-text .l2 { display: block; font-size: 110px; font-weight: 800; color: ${C.ember}; margin: 2px 0 2px; }`;
const hookTextHtml = (p) => `<div id="${p}-text" class="hook-text">
        <span class="l1" data-var-text="hookLine1">Can you draw</span>
        <span class="l2" data-var-text="hookLine2">ONE line</span>
        <span class="l3" data-var-text="hookLine3">through every square?</span>
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

// ---------- hook (0–2s) ----------
const startCell = center(puzzle.path[0]);
const hook = scene(
  "hook",
  `${HOOK_CSS}
      ${BOARD_CSS("hook-board")}
      #hook-ring { position: absolute; left: ${BX + startCell[0] - 46}px; top: ${BY + startCell[1] - 46}px; width: 92px; height: 92px; border-radius: 50%; border: 5px solid ${C.ember}; opacity: 0; }`,
  `${hookTextHtml("hook")}
      <div id="hook-board">${boardSvg("hook", { drawn: false })}</div>
      <div id="hook-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Frame 0 is the full hook: text + empty board already on screen.
    // One-shot cue: a ring lands on "1" — where the line starts.
    tl.fromTo("#hook-ring", { opacity: 0, scale: 1.8 }, { opacity: 1, scale: 1, duration: 0.45, ease: "expo.out" }, 0.9);
    tl.to("#hook-ring", { opacity: 0, duration: 0.2, ease: "power2.in" }, 1.75);`,
);

// ---------- solve (2–10s, 8s) ----------
const DRAW_START = 0.15;
const DRAW_END = 7.6;
const STEPS = puzzle.path.length - 1; // 63
// inverse of power1.inOut
const inv = (y) => (y < 0.5 ? Math.sqrt(y / 2) : 1 - Math.sqrt((1 - y) / 2));
const stepTime = (k) => DRAW_START + (DRAW_END - DRAW_START) * inv(k / STEPS);

const solve = scene(
  "solve",
  `${HOOK_CSS}
      ${BOARD_CSS("solve-board")}
      #solve-label { position: absolute; left: 0; right: 0; top: 196px; text-align: center; font-size: 36px; font-weight: 600; letter-spacing: 0.18em; color: ${C.inkSoft}; opacity: 0; }
      #solve-timer { position: absolute; left: 0; right: 0; top: 250px; text-align: center; font-size: 120px; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; opacity: 0; }`,
  `${hookTextHtml("solve")}
      <div id="solve-label" data-var-text="zipLabel">TODAY'S ZIP</div>
      <div id="solve-timer">0:00</div>
      <div id="solve-board">${boardSvg("solve", { drawn: false })}</div>`,
  `    const tl = gsap.timeline({ paused: true });
    const PATH = ${JSON.stringify(puzzle.path)};
    const CELL = ${CELL};
    const STEPS = ${STEPS};
    const SOLVE_SECONDS = 47;
    const segs = Array.from(document.querySelectorAll("#solve-ribbon [data-seg]"));
    const nums = Array.from(document.querySelectorAll("#solve-nums [data-num]"));
    const tipGlow = document.getElementById("solve-tipglow");
    const tipDot = document.getElementById("solve-tipdot");
    const timer = document.getElementById("solve-timer");
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
      const s = Math.floor((SOLVE_SECONDS * p) / STEPS);
      timer.textContent = "0:" + String(s).padStart(2, "0");
    }
    render();
    // Hook text carried over from the hook scene, then a blur swap to the clock.
    tl.to("#solve-text", { opacity: 0, filter: "blur(8px)", duration: 0.2, ease: "power2.in" }, 0.5);
    tl.fromTo("#solve-label", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out" }, 0.68);
    tl.fromTo("#solve-timer", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out" }, 0.74);
    // The line starts at 1: tip lands, then the ribbon draws all ${STEPS} steps.
    tl.fromTo("#solve-tip", { opacity: 0, scale: 0.4, svgOrigin: "${startCell[0]} ${startCell[1]}" }, { opacity: 1, scale: 1, duration: 0.25, ease: "expo.out" }, 0);
    tl.fromTo(state, { p: 0 }, { p: STEPS, duration: ${fx(DRAW_END - DRAW_START)}, ease: "power1.inOut", onUpdate: render }, ${DRAW_START});
    tl.set({}, {}, 7.99);`,
);

// tap ticks every 4 steps (scene-local times + 2s offset; tap peaks at 0 -> +1 frame)
const taps = [];
for (let k = 4, n = 0; k <= 60; k += 4, n++) {
  const vols = [0.55, 0.8, 0.65, 0.9];
  taps.push({ t: fx(2 + stepTime(k) + 0.033), v: vols[n % vols.length] });
}

// ---------- payoff (10–12s) ----------
const endCell = center(puzzle.path[puzzle.path.length - 1]);
const payoff = scene(
  "payoff",
  `${BOARD_CSS("payoff-board")}
      #payoff-label { position: absolute; left: 0; right: 0; top: 196px; text-align: center; font-size: 36px; font-weight: 600; letter-spacing: 0.18em; color: ${C.inkSoft}; }
      #payoff-solved { position: absolute; left: 0; right: 0; top: 178px; text-align: center; font-size: 64px; font-weight: 700; line-height: 1; color: ${C.teal}; opacity: 0; }
      #payoff-timer { position: absolute; left: 0; right: 0; top: 250px; text-align: center; font-size: 120px; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; }
      #payoff-chip { position: absolute; left: 50%; top: 386px; width: 300px; margin-left: -150px; height: 76px; border-radius: 38px; background: ${C.wall}; border: 3px solid ${C.star};
        display: flex; align-items: center; justify-content: center; gap: 14px; font-size: 40px; font-weight: 700; opacity: 0; }
      #payoff-chip svg { width: 38px; height: 38px; }
      #payoff-flash { position: absolute; left: ${BX}px; top: ${BY}px; width: ${BOARD}px; height: ${BOARD}px; border-radius: 22px; background: ${C.teal}; opacity: 0; }
      #payoff-ring { position: absolute; left: ${BX - 6}px; top: ${BY - 6}px; width: ${BOARD + 12}px; height: ${BOARD + 12}px; border-radius: 26px; border: 6px solid ${C.teal}; opacity: 0; }`,
  `<div id="payoff-label">TODAY'S ZIP</div>
      <div id="payoff-solved" data-var-text="solvedWord">Solved</div>
      <div id="payoff-timer" data-var-text="solveTime">0:47</div>
      <div id="payoff-chip"><svg viewBox="0 0 24 24"><path fill="${C.star}" d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 9.4l6.6-.8z"/></svg><span data-var-text="rankText">#3 today</span></div>
      <div id="payoff-board">${boardSvg("payoff", { drawn: true })}</div>
      <div id="payoff-flash"></div>
      <div id="payoff-ring"></div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Solve lands: teal flash over the board, ring holds.
    tl.fromTo("#payoff-flash", { opacity: 0 }, { opacity: 0.5, duration: 0.08, ease: "power2.out" }, 0);
    tl.to("#payoff-flash", { opacity: 0, duration: 0.55, ease: "power2.out" }, 0.1);
    tl.fromTo("#payoff-ring", { opacity: 0, scale: 1.04 }, { opacity: 1, scale: 1, duration: 0.35, ease: "expo.out" }, 0);
    tl.fromTo("#payoff-board", { scale: 1 }, { scale: 1.025, duration: 0.12, ease: "power2.out" }, 0);
    tl.to("#payoff-board", { scale: 1, duration: 0.5, ease: "elastic.out(1, 0.6)" }, 0.12);
    // Label swaps to "Solved"; the clock turns teal-white and stays put.
    tl.to("#payoff-label", { opacity: 0, filter: "blur(8px)", duration: 0.13, ease: "power2.in" }, 0.05);
    tl.fromTo("#payoff-solved", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out" }, 0.12);
    tl.fromTo("#payoff-timer", { color: "${C.onInk}" }, { color: "${C.teal}", duration: 0.3, ease: "power2.inOut" }, 0.05);
    // Rank chip pops (sfx "clear" lines up with this).
    tl.fromTo("#payoff-chip", { opacity: 0, scale: 0.6, y: -10 }, { opacity: 1, scale: 1, y: 0, duration: 0.5, ease: "back.out(1.6)" }, 0.6);
    // Out: top copy blurs away just before the CTA scene.
    tl.to(["#payoff-solved", "#payoff-timer", "#payoff-chip"], { opacity: 0, filter: "blur(8px)", duration: 0.16, ease: "power2.in", stagger: 0.04 }, 1.78);
    tl.set({}, {}, 1.99);`,
);

// ---------- cta (12–16.6s) ----------
// All three games side by side under "3 free puzzles. Every day.", then the logo.
// Path Words: 4x4, the word DAILY traced in sky.
const PW = ["WORD", "DAIL", "PENY", "MINK"];
const PW_WORD = [
  [1, 0],
  [1, 1],
  [1, 2],
  [1, 3],
  [2, 3],
];
const PWN = 4;
const PWC = 168;
const PWG = 12;
const pwPos = (r, c) => [c * (PWC + PWG), r * (PWC + PWG)];
const pwInWord = new Set(PW_WORD.map(([r, c]) => `${r},${c}`));
const pwRects = [];
const pwTexts = [];
for (let r = 0; r < PWN; r++)
  for (let c = 0; c < PWN; c++) {
    const [x, y] = pwPos(r, c);
    const on = pwInWord.has(`${r},${c}`);
    pwRects.push(
      `<rect ${on ? `class="pw-hit" ` : ""}x="${x}" y="${y}" width="${PWC}" height="${PWC}" rx="24" fill="${C.paper}" stroke="${C.sky}" stroke-width="0"/>`,
    );
    pwTexts.push(
      `<text x="${x + PWC / 2}" y="${y + PWC / 2}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="700" font-size="88" fill="${C.onInk}">${PW[r][c]}</text>`,
    );
  }
const pwPts = PW_WORD.map(([r, c]) => {
  const [x, y] = pwPos(r, c);
  return `${x + PWC / 2},${y + PWC / 2}`;
}).join(" ");
const pwLen = (PW_WORD.length - 1) * (PWC + PWG);
const PWSIZE = PWN * PWC + (PWN - 1) * PWG; // 708

// Sudoku 6x6, 2x3 boxes (valid solution)
const SD = ["123456", "456123", "231564", "564231", "312645", "645312"];
const GIVEN = ["1.3..6", ".5.1.3", "2..5.4", "5.4..1", ".1.6.5", "6..3.2"];
const LAST = new Set(["3,4", "4,4", "5,1"]); // pop in as the card lands
const SC = 112;
const SG = 4;
const sdX = (c) => c * (SC + SG) + (c >= 3 ? 12 : 0);
const sdY = (r) => r * (SC + SG) + Math.floor(r / 2) * 12;
const SDW = sdX(5) + SC;
const SDH = sdY(5) + SC;
const sdCells = [];
for (let r = 0; r < 6; r++)
  for (let c = 0; c < 6; c++) {
    const given = GIVEN[r][c] !== ".";
    const last = LAST.has(`${r},${c}`);
    sdCells.push(
      `<rect x="${sdX(c)}" y="${sdY(r)}" width="${SC}" height="${SC}" rx="12" fill="${given ? C.paper : "#134E4A"}"/>`,
      `<text ${last ? `class="sd-last" ` : ""}x="${sdX(c) + SC / 2}" y="${sdY(r) + SC / 2}" text-anchor="middle" dominant-baseline="central" font-family="Lexend" font-weight="${given ? 700 : 600}" font-size="60" fill="${given ? C.onInk : C.teal}">${SD[r][c]}</text>`,
    );
  }

// Three slots in a row, all inside y 168–1330.
const SLOT = 316;
const SLOT_GAP = 26;
const SLOT_X = [0, 1, 2].map((i) => 40 + i * (SLOT + SLOT_GAP)); // 40, 382, 724
const SLOT_Y = 600;
const MINI_PAD = 16;
const ZIP_SCALE = SLOT / BOARD;
const cta = scene(
  "cta",
  `${BOARD_CSS("cta-zip")}
      .cta-line { position: absolute; left: 40px; right: 40px; text-align: center; font-size: 88px; font-weight: 700; line-height: 1; letter-spacing: -0.02em; opacity: 0; }
      #cta-l1 { top: 196px; }
      #cta-l2 { top: 300px; color: ${C.ember}; }
      .cta-slot { position: absolute; top: ${SLOT_Y}px; width: ${SLOT}px; height: ${SLOT + 90}px; opacity: 0; }
      .cta-mini { position: absolute; left: 0; top: 0; width: ${SLOT}px; height: ${SLOT}px; border-radius: 18px; background: ${C.wall}; border: 2px solid ${C.outline}; filter: drop-shadow(0 6px 0 rgba(0,0,0,0.35)); }
      .cta-mini svg { position: absolute; left: ${MINI_PAD - 2}px; top: ${MINI_PAD - 2}px; width: ${SLOT - MINI_PAD * 2}px; height: ${SLOT - MINI_PAD * 2}px; }
      .cta-label { position: absolute; left: -20px; right: -20px; top: ${SLOT + 26}px; text-align: center; font-size: 40px; font-weight: 700; line-height: 1; }
      #cta-s1 { left: ${SLOT_X[0]}px; } #cta-s1 .cta-label { color: ${C.ember}; }
      #cta-s2 { left: ${SLOT_X[1]}px; } #cta-s2 .cta-label { color: ${C.sky}; }
      #cta-s3 { left: ${SLOT_X[2]}px; } #cta-s3 .cta-label { color: ${C.teal}; }
      #cta-logo { position: absolute; left: 0; right: 0; top: 520px; height: 680px; opacity: 0; }
      #cta-icon { position: absolute; left: 50%; top: 0; width: 320px; height: 320px; margin-left: -160px; }
      #cta-name { position: absolute; left: 0; right: 0; top: 350px; text-align: center; font-size: 132px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; }
      #cta-pill { position: absolute; left: 50%; top: 528px; width: 520px; margin-left: -260px; height: 96px; border-radius: 48px; background: ${C.ember}; color: ${C.ink};
        display: flex; align-items: center; justify-content: center; font-size: 52px; font-weight: 700; }`,
  `<div id="cta-l1" class="cta-line" data-var-text="ctaLine1">3 free puzzles.</div>
      <div id="cta-l2" class="cta-line" data-var-text="ctaLine2">Every day.</div>
      <div id="cta-s1" class="cta-slot"><div class="cta-label">Zip</div></div>
      <div id="cta-s2" class="cta-slot">
        <div class="cta-mini" data-layout-ignore>
          <svg viewBox="0 0 ${PWSIZE} ${PWSIZE}" xmlns="http://www.w3.org/2000/svg">
            ${pwRects.join("\n            ")}
            <polyline id="cta-pw-trace" points="${pwPts}" fill="none" stroke="${C.sky}" stroke-opacity="0.6" stroke-width="44" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="${pwLen} ${pwLen + 10}" stroke-dashoffset="${pwLen}"/>
            ${pwTexts.join("\n            ")}
          </svg>
        </div>
        <div class="cta-label">Path Words</div>
      </div>
      <div id="cta-s3" class="cta-slot">
        <div class="cta-mini" data-layout-ignore>
          <svg viewBox="0 0 ${SDW} ${SDH}" xmlns="http://www.w3.org/2000/svg">
            ${sdCells.join("\n            ")}
          </svg>
        </div>
        <div class="cta-label">Sudoku</div>
      </div>
      <div id="cta-zip" data-layout-ignore>${boardSvg("cta", { drawn: true })}</div>
      <div id="cta-logo">
        <img id="cta-icon" src="assets/app_icon.png" alt="Winklo" />
        <div id="cta-name" data-var-text="brandName">Winklo</div>
        <div id="cta-pill" data-var-text="ctaPill">Free on Android</div>
      </div>`,
  `    const tl = gsap.timeline({ paused: true });
    // Copy: the claim, in two beats; holds to the end.
    tl.fromTo("#cta-l1", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out" }, 0.04);
    tl.fromTo("#cta-l2", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.18, ease: "power4.out" }, 0.5);
    // Carry across: the solved Zip board shrinks into the first slot.
    tl.fromTo("#cta-zip", { x: 0, y: 0, scale: 1, transformOrigin: "0px 0px" },
      { x: ${SLOT_X[0] - BX}, y: ${SLOT_Y - BY}, scale: ${fx(ZIP_SCALE * 10000) / 10000}, transformOrigin: "0px 0px", duration: 0.5, ease: "power3.inOut" }, 0);
    // Slots land in a stagger, each with its game's name.
    tl.fromTo("#cta-s1", { opacity: 0 }, { opacity: 1, duration: 0.2, ease: "power2.out" }, 0.35);
    tl.fromTo("#cta-s2", { opacity: 0, y: 60, filter: "blur(10px)" }, { opacity: 1, y: 0, filter: "blur(0px)", duration: 0.4, ease: "expo.out" }, 0.3);
    tl.fromTo("#cta-s3", { opacity: 0, y: 60, filter: "blur(10px)" }, { opacity: 1, y: 0, filter: "blur(0px)", duration: 0.4, ease: "expo.out" }, 0.45);
    // Each game acts once: a word traces, the last Sudoku digits pop in.
    tl.fromTo("#cta-s2 .pw-hit", { attr: { fill: "${C.paper}", "stroke-width": 0 } }, { attr: { fill: "${C.skySoft}", "stroke-width": 6 }, duration: 0.12, stagger: 0.07 }, 0.6);
    tl.fromTo("#cta-pw-trace", { attr: { "stroke-dashoffset": ${pwLen} } }, { attr: { "stroke-dashoffset": 0 }, duration: 0.4, ease: "power2.inOut" }, 0.6);
    tl.fromTo("#cta-s3 .sd-last", { opacity: 0, attr: { "font-size": 24 } }, { opacity: 1, attr: { "font-size": 60 }, duration: 0.22, ease: "back.out(2)", stagger: 0.1 }, 0.8);
    // All three together until 2.05 s, then they clear for the logo.
    tl.to("#cta-zip", { opacity: 0, filter: "blur(10px)", duration: 0.2, ease: "power3.in" }, 2.05);
    tl.to(["#cta-s1", "#cta-s2", "#cta-s3"], { opacity: 0, y: -30, filter: "blur(10px)", duration: 0.2, ease: "power3.in", stagger: 0.04 }, 2.05);
    // Logo lockup lands and holds (>= 2 s).
    tl.fromTo("#cta-logo", { opacity: 0 }, { opacity: 1, duration: 0.12, ease: "power2.out" }, 2.35);
    tl.fromTo("#cta-icon", { scale: 0.7, filter: "blur(10px)" }, { scale: 1, filter: "blur(0px)", duration: 0.5, ease: "expo.out" }, 2.35);
    tl.fromTo("#cta-name", { opacity: 0, filter: "blur(8px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 2.43);
    tl.fromTo("#cta-pill", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(1.5)" }, 2.52);
    tl.set({}, {}, 4.59);`,
);

// ---------- index ----------
const vars = [
  ["hookLine1", "Hook line 1", "Can you draw"],
  ["hookLine2", "Hook line 2 (ember)", "ONE line"],
  ["hookLine3", "Hook line 3", "through every square?"],
];
const audio = [];
let ai = 0;
// hook: one quiet tick as the ring lands on "1" (0.9 s), so the open is not silent
audio.push(`<audio id="sfx-hook" class="clip" src="assets/sfx/tap.ogg" data-start="0.93" data-duration="0.01" data-track-index="2" data-volume="0.7"></audio>`);
for (const t of taps) {
  audio.push(
    `<audio id="sfx-tap-${++ai}" class="clip" src="assets/sfx/tap.ogg" data-start="${t.t}" data-duration="0.01" data-track-index="2" data-volume="${t.v}"></audio>`,
  );
}
audio.push(
  `<audio id="sfx-success" class="clip" src="assets/sfx/success.ogg" data-start="10.03" data-duration="0.55" data-track-index="2" data-volume="1"></audio>`,
  // clear peaks at 0.166 s: chip lands at 10.6 -> start 10.6 + 0.033 - 0.166
  `<audio id="sfx-chip" class="clip" src="assets/sfx/clear.ogg" data-start="10.47" data-duration="0.5" data-track-index="3" data-volume="0.7"></audio>`,
  `<audio id="sfx-card-1" class="clip" src="assets/sfx/tap.ogg" data-start="12.33" data-duration="0.01" data-track-index="2" data-volume="0.6"></audio>`,
  `<audio id="sfx-card-2" class="clip" src="assets/sfx/tap.ogg" data-start="12.48" data-duration="0.01" data-track-index="2" data-volume="0.5"></audio>`,
  // logo lands at 14.35 -> pop (clear peaks at 0.166 s)
  `<audio id="sfx-logo" class="clip" src="assets/sfx/clear.ogg" data-start="14.22" data-duration="0.5" data-track-index="2" data-volume="0.85"></audio>`,
);

const index = `<!doctype html>
<html lang="en" data-composition-variables='${JSON.stringify(
  vars.map(([id, label, def]) => ({ id, type: "string", label, default: def })),
)}'>
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
    <div id="root" data-composition-id="main" data-start="0" data-duration="16.6" data-width="${W}" data-height="${H}">
      <div id="hook" data-composition-id="hook" data-composition-src="compositions/hook.html" data-start="0" data-duration="2" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>
      <div id="solve" data-composition-id="solve" data-composition-src="compositions/solve.html" data-start="2" data-duration="8" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>
      <div id="payoff" data-composition-id="payoff" data-composition-src="compositions/payoff.html" data-start="10" data-duration="2" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>
      <div id="cta" data-composition-id="cta" data-composition-src="compositions/cta.html" data-start="12" data-duration="4.6" data-track-index="1" data-track-kind="graphics" data-width="${W}" data-height="${H}"></div>
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
fs.writeFileSync(path.join(root, "compositions/hook.html"), hook);
fs.writeFileSync(path.join(root, "compositions/solve.html"), solve);
fs.writeFileSync(path.join(root, "compositions/payoff.html"), payoff);
fs.writeFileSync(path.join(root, "compositions/cta.html"), cta);
console.log("taps", taps);
