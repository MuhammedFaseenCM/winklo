// Fills the landing page's "Today's boards" and the hero's live line from
// /api/today, the Pages Function in workers/site. Without it (a plain static
// server, or Firestore unavailable) both stay hidden and the page reads as a
// static page. Names come from players, so everything goes in as text.

const GAMES = ['zip', 'path_words', 'sudoku'];
const SVG_NS = 'http://www.w3.org/2000/svg';
const REFRESH_AFTER_MS = 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 8000;
const CELL = 10;

const section = document.getElementById('today');
const liveLine = document.querySelector('[data-live-line]');
const heroSet = document.querySelector('[data-hero-set]');

let loadedDay = null;
let loadedAt = 0;
let latest = null;
let loading = false;

function pad(n) {
  return String(n).padStart(2, '0');
}

/** The visitor's calendar day: the app plays `daily_YYYYMMDD` for the phone's local date. */
function localDayId(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function clock(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

function untilMidnight(now) {
  const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const minutes = Math.max(1, Math.ceil((midnight - now) / 60000));
  const h = Math.floor(minutes / 60);
  return h > 0 ? `${h}h ${pad(minutes % 60)}m` : `${minutes}m`;
}

function ago(iso, now) {
  const minutes = Math.floor((now - new Date(iso)) / 60000);
  if (!Number.isFinite(minutes) || minutes < 1) return 'just now';
  return minutes === 1 ? '1 minute ago' : `${minutes} minutes ago`;
}

function plural(n, one, many) {
  return `${n} ${n === 1 ? one : many}`;
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function svg(tag, attrs, text) {
  const node = document.createElementNS(SVG_NS, tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, String(value));
  if (text !== undefined) node.textContent = text;
  return node;
}

/** An empty board: rounded background, then the grid lines. */
function frame(size, label) {
  const w = size * CELL;
  const root = svg('svg', { viewBox: `-1 -1 ${w + 2} ${w + 2}`, role: 'img', 'aria-label': label });
  root.append(svg('rect', { class: 'b-bg', x: 0, y: 0, width: w, height: w, rx: 2.2 }));
  return root;
}

function gridLines(root, size, isThick) {
  const w = size * CELL;
  for (let i = 1; i < size; i++) {
    const at = i * CELL;
    root.append(svg('line', { class: isThick(i, 'col') ? 'b-box' : 'b-grid', x1: at, y1: 0, x2: at, y2: w }));
    root.append(svg('line', { class: isThick(i, 'row') ? 'b-box' : 'b-grid', x1: 0, y1: at, x2: w, y2: at }));
  }
}

function centeredText(className, row, col, text) {
  return svg(
    'text',
    { class: className, x: col * CELL + CELL / 2, y: row * CELL + CELL / 2, dy: '0.36em' },
    text,
  );
}

function zipBoard(board) {
  const { size, numbers, walls } = board;
  const root = frame(
    size,
    `Today's Zip: a ${size} by ${size} grid with ${numbers.length} numbers and ${walls.length} walls`,
  );
  gridLines(root, size, () => false);
  // Drawn like the app: a light bar on the cell edge, inset from the corners.
  const inset = CELL * 0.16;
  for (const [r1, c1, r2, c2] of walls) {
    const line =
      r1 === r2
        ? { x1: Math.max(c1, c2) * CELL, x2: Math.max(c1, c2) * CELL, y1: r1 * CELL + inset, y2: (r1 + 1) * CELL - inset }
        : { y1: Math.max(r1, r2) * CELL, y2: Math.max(r1, r2) * CELL, x1: c1 * CELL + inset, x2: (c1 + 1) * CELL - inset };
    root.append(svg('line', { class: 'zip-wall', ...line }));
  }
  for (const [row, col, n] of numbers) root.append(centeredText('zip-num', row, col, String(n)));
  return root;
}

function sudokuBoard(board) {
  const { size, boxRows, boxCols, given } = board;
  const givens = given.filter((n) => n > 0).length;
  const root = frame(size, `Today's Sudoku: a ${size} by ${size} grid with ${givens} digits given`);
  gridLines(root, size, (i, axis) => (axis === 'row' ? i % boxRows === 0 : i % boxCols === 0));
  given.forEach((n, i) => {
    if (n > 0) root.append(centeredText('sdk-num', Math.floor(i / size), i % size, String(n)));
  });
  return root;
}

function pathWordsBoard(board) {
  const { size, letters, words } = board;
  const root = frame(size, `Today's Path Words: a ${size} by ${size} letter grid hiding ${words} words`);
  const gap = CELL * 0.1;
  letters.forEach((letter, i) => {
    if (!letter) return;
    const row = Math.floor(i / size);
    const col = i % size;
    root.append(
      svg('rect', {
        class: 'pw-tile',
        x: col * CELL + gap,
        y: row * CELL + gap,
        width: CELL - 2 * gap,
        height: CELL - 2 * gap,
        rx: 1.6,
      }),
    );
    root.append(centeredText('pw-letter', row, col, letter));
  });
  return root;
}

const BOARDS = {
  zip: {
    draw: zipBoard,
    meta: (b) => `${b.size}×${b.size} · ${plural(b.numbers.length, 'number', 'numbers')} · ${plural(b.walls.length, 'wall', 'walls')}`,
  },
  path_words: {
    draw: pathWordsBoard,
    meta: (b) => `${b.size}×${b.size} · ${plural(b.words, 'hidden word', 'hidden words')}`,
  },
  sudoku: {
    draw: sudokuBoard,
    meta: (b) => `${b.size}×${b.size} · ${plural(b.given.filter((n) => n > 0).length, 'digit', 'digits')} given`,
  },
};

function chips(entry) {
  const list = el('span', 'chips');
  if (entry.hintFree) list.append(el('span', 'chip', 'Hint-free'));
  if (entry.flawless) list.append(el('span', 'chip', 'Flawless'));
  if (entry.streak >= 2) list.append(el('span', 'chip chip-streak', `🔥 ${entry.streak}`));
  return list;
}

function podium(top) {
  if (top.length === 0) return el('p', 'empty', 'No clears yet today. Be the first.');
  const list = el('ol', 'podium');
  top.forEach((entry, i) => {
    const row = el('li');
    row.append(el('span', `rank rank-${i + 1}`, String(i + 1)));
    const who = el('span', 'who');
    who.append(el('strong', '', entry.name), chips(entry));
    const time = el('span', 'time', clock(entry.timeSeconds));
    row.append(who, time);
    list.append(row);
  });
  return list;
}

function renderCard(card, game, today) {
  const difficulty = card.querySelector('[data-difficulty]');
  difficulty.hidden = !today.difficulty;
  difficulty.textContent = today.difficulty ?? '';

  const boardBox = card.querySelector('[data-board]');
  const meta = card.querySelector('[data-meta]');
  boardBox.replaceChildren();
  if (today.board) {
    boardBox.append(BOARDS[game].draw(today.board));
    meta.textContent = BOARDS[game].meta(today.board);
  } else {
    boardBox.append(el('p', 'board-missing', 'Today’s board is waiting in the app.'));
    meta.textContent = '';
  }

  const fastest = card.querySelector('[data-fastest]');
  const clears = card.querySelector('[data-clears]');
  fastest.hidden = today.top === null;
  if (today.top !== null) fastest.querySelector('[data-top]').replaceChildren(podium(today.top));
  clears.hidden = !today.clears;
  clears.textContent = today.clears
    ? `${plural(today.clears, 'player has', 'players have')} cleared it today`
    : '';
}

/** The parts that move with the clock: countdowns and "updated … ago". */
function tick() {
  const now = new Date();
  if (latest && localDayId(now) !== loadedDay) return load();
  if (latest && document.visibilityState === 'visible' && Date.now() - loadedAt > REFRESH_AFTER_MS) {
    load();
  }
  if (!latest) return;
  const countdown = untilMidnight(now);
  for (const node of document.querySelectorAll('[data-countdown]')) node.textContent = countdown;
  const updated = document.querySelector('[data-updated]');
  if (updated) updated.textContent = ago(latest.updatedAt, now);
}

function render(today) {
  for (const game of GAMES) {
    const card = section.querySelector(`[data-game="${game}"]`);
    if (card && today.games[game]) renderCard(card, game, today.games[game]);
  }
  const date = new Date(`${today.day}T12:00:00`);
  section.querySelector('[data-date]').textContent = new Intl.DateTimeFormat('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  }).format(date);

  // The hero's stack of today's boards (shown on wide screens only).
  if (heroSet) {
    for (const game of GAMES) {
      const tile = heroSet.querySelector(`[data-hero-board="${game}"]`);
      const board = today.games[game]?.board;
      if (!tile) continue;
      tile.hidden = !board;
      tile.replaceChildren(...(board ? [BOARDS[game].draw(board)] : []));
    }
    heroSet.hidden = !today.games.zip?.board;
  }

  const clears = GAMES.map((g) => today.games[g]?.clears ?? 0).reduce((a, b) => a + b, 0);
  liveLine.querySelector('[data-live-text]').textContent =
    clears > 0 ? `${plural(clears, 'clear', 'clears')} so far today.` : 'Today’s boards are live.';

  section.hidden = false;
  liveLine.hidden = false;
  tick();
}

async function load() {
  if (loading) return;
  loading = true;
  const day = localDayId(new Date());
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`/api/today?day=${day}`, { signal: controller.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const today = await res.json();
    if (!today || !today.games) throw new Error('Unexpected answer');
    latest = today;
    loadedDay = day;
    loadedAt = Date.now();
    render(today);
  } catch (error) {
    // Keep whatever was shown last; on a first load the section stays hidden.
    console.warn('Winklo: today’s boards are unavailable', error);
  } finally {
    clearTimeout(timer);
    loading = false;
  }
}

if (section && liveLine) {
  load();
  setInterval(tick, 30 * 1000);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') tick();
  });
}
