# Admin Levels 2b (World editor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In winklo-admin, an admin can create a level world, generate its boards with a difficulty ramp, edit each level's board and target time, save it safely against concurrent edits, and publish, unpublish or delete worlds under the rules that keep every level number fixed.

**Architecture:** admin-api gains a pure module (`level_worlds_write.ts`: coordinate conversion and world checks) and write methods on `LevelsStore` (full read with `updateTime`, preconditioned save, publish/unpublish, delete), exposed as five routes. The SPA gains a world page at `/levels/:game/worlds/:order` that edits a local draft (header fields, a level list, a level modal hosting the existing `ZipBoardEditor`) and saves through React Query mutations; boards for a whole world come from a new `levelRamp` plus exact counts in the existing seeded `generateZip`, run one board at a time in the existing generator web worker.

**Tech Stack:** winklo-admin — React 19, react-router 7, TanStack Query v5, UI kit in `src/ui`, Cloudflare Worker (TypeScript) on the Firestore REST API, vitest. No app (Flutter) changes.

**Spec:** `docs/superpowers/specs/2026-11-02-admin-levels-design.md`, section 2 "Worlds (the editor) — plan 2b" and section 3 "Worlds tab" / "Generate world". This plan changes one detail of the spec: the world page route is `/levels/:game/worlds/:order` (the spec's `/levels/zip/:order` would sit beside `/levels/zip/players/:uid`; the explicit `worlds` segment reads better). Task 11 updates the spec.

---

## Ground rules (every task)

- Worktree: `~/Developments/personal/winklo-admin/.worktrees/admin-levels-2b` on branch `feat/admin-levels-2b`, created from `main` in Task 1 Step 1. The repo's default branch is `main`.
- Commit trailer, exactly: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `git add` by explicit path. Never stage `package-lock.json`. Never push or deploy (no `wrangler deploy`).
- Gates. SPA: `npm run lint` (oxlint, cap 26 — never raise it), `npm run check:ui`, `npm run typecheck:tests`, `npm test`, `npm run build`, `npm run check:bundle`. Worker: `cd workers/admin-api && npm run typecheck && npm test` (the root `npm test` does not run Worker tests).
- Worker errors: any thrown `Error` whose message doesn't start with `firestore_`, `token_`, `fcm_`, `rc_`, `auth_` or `ga4_` becomes 401 in the catch at the end of `index.ts`. New Firestore failures throw `firestore_…`; expected refusals are returned as JSON with a status, never thrown.
- SPA data goes through `fromSource(domain, real, mock)`; page tests run in mock mode (`localStorage winklo_mock_admin='true'`, `winklo_mock_latency='0'`, `resetMockStores()` after each).
- CSS: tokens only (no hex/rgb/hsl; only `var(--…)` declared in `src/styles/tokens.css`), classes prefixed `.lv-`, `--text-3` text ≥ 12px. No emoji. Read every real UI component before using it (`src/ui/*`); don't change shared components without reporting it.
- Before running tests, make sure no stale vitest/vite processes point at the worktree.

## The data

`level_worlds/{game}_{order}` (as plan 1 defined it, and as World 1 was seeded):

```jsonc
{
  "game": "zip", "order": 2, "published": false, "theme": "metro", "title": "Metro",
  "levels": [
    {
      "id": "zip_2_01", "size": 5,
      "numbers": { "0,0": 1, "4,4": 6 },
      "walls": [ { "a": "1,2", "b": "1,3" } ],
      "solution": [ "0,0", "0,1" ],
      "targetSeconds": 30
    }
  ],
  "updatedAt": "<server time>", "updatedByUid": "…", "updatedByEmail": "…"
}
```

- Firestore forbids an array directly inside an array, so `solution` cells and wall ends are stored as `"r,c"` strings. The app's `Cell.fromJson` reads `"r,c"`, `[r, c]` and `{row, col}`, so all three are safe to read; the Worker always **writes** `"r,c"` and always **returns** `[r, c]` to the SPA (the shape `ZipLevelData` and `ZipBoardEditor` use).
- The SPA's board type is the existing `ZipLevelData` (`src/pages/content/types.ts`); a world level is `ZipLevelData & { id: string; targetSeconds: number | null }`. `order`, `difficulty` and `special` from the CMS shape are dropped on save.

## File map

| File | Responsibility |
|---|---|
| `workers/admin-api/src/level_worlds_write.ts` (create) | Pure: coordinate conversion both ways, `levelId`, `checkWorld` (issues list), publish-order and delete rules |
| `workers/admin-api/src/levels.ts` (modify) | `LevelsStore`: `world(game, order)` (full, with `updateTime`), `saveWorld`, `setPublished`, `deleteWorld`; `WorldStaleError` |
| `workers/admin-api/src/index.ts` (modify) | Routes: GET/PUT/DELETE `/v1/levels/:game/worlds/:order`, POST `…/publish`, POST `…/unpublish` |
| `src/lib/adminApi.ts` (modify) | `LevelWorld` types and five fetchers |
| `src/lib/errors.ts` (modify) | Copy for `world_changed`, `world_exists`, `publish_order`, `unpublish_order`, `world_locked`, `world_published`, `world_not_found` |
| `src/mocks/levels.ts` (modify) | A stateful world store the mock writes go through, with the same rules |
| `src/queries/keys.ts`, `src/queries/levels.ts` (modify) | `qk.levels.world`, `useLevelWorld`, `useSaveLevelWorld`, `usePublishLevelWorld`, `useUnpublishLevelWorld`, `useDeleteLevelWorld` |
| `src/pages/content/generators/levelRamp.ts` (create) | Per-size ramp bounds, `levelRamp(size, index, count)`, `suggestedTargetSeconds(size)`, `worldLevelSeed(order, index, attempt)` |
| `src/pages/content/generators/generateZip.ts`, `generatorProtocol.ts` (modify) | Optional exact `counts: {numbers, walls}` |
| `src/pages/levels/useGenerateWorld.ts` (create) | Runs the ramp board by board in the generator worker, validates each, reports progress, cancellable |
| `src/pages/levels/worldDraft.ts` (create) | Pure draft helpers: new world defaults, renumber ids, move/add/remove, dirty check, payload |
| `src/pages/levels/WorldEditorPage.tsx` (create) | The world page: load, header form, level list, save, publish/unpublish/delete, unsaved guard |
| `src/pages/levels/LevelEditModal.tsx` (create) | One level: `ZipBoardEditor` + target time |
| `src/pages/levels/GenerateWorldModal.tsx` (create) | Size + count in, progress, cancel |
| `src/pages/levels/WorldsTab.tsx` (modify) | Cards link to their world page; New world button |
| `src/routes.tsx` (modify) | `levelWorld` page at `levels/:game/worlds/:order` |
| `src/pages/levels/levels.css` (modify) | Editor styles |

---

### Task 1: Pure world rules in the Worker (`level_worlds_write.ts`)

**Files:**
- Create: `workers/admin-api/src/level_worlds_write.ts`
- Test: `workers/admin-api/src/level_worlds_write.test.ts`

- [ ] **Step 1: Create the worktree**

```bash
cd ~/Developments/personal/winklo-admin
git status --short            # expect only "?? docs/winklo.code-workspace"; leave it
git worktree add -b feat/admin-levels-2b .worktrees/admin-levels-2b main
cd .worktrees/admin-levels-2b && npm ci && (cd workers/admin-api && npm ci)
(cd workers/admin-api && npm test 2>&1 | tail -3)
```

Expected: Worker suite passes on the clean tree.

- [ ] **Step 2: Write the failing tests**

`workers/admin-api/src/level_worlds_write.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import {
  boardFromStored,
  boardToStored,
  checkDelete,
  checkPublish,
  checkUnpublish,
  checkWorld,
  levelId,
  LEVEL_THEMES,
  MAX_WORLD_LEVELS,
  type WorldInput,
} from './level_worlds_write';

const board = (id: string, size = 4) => ({
  id,
  size,
  numbers: { '0,0': 1, '3,0': 2 },
  walls: [{ a: [0, 1] as [number, number], b: [0, 2] as [number, number] }],
  solution: Array.from({ length: size * size }, (_, i) => [Math.floor(i / size), i % size] as [number, number]),
  targetSeconds: 20 as number | null,
});

const world = (over: Partial<WorldInput> = {}): WorldInput => ({
  theme: 'ink',
  title: 'Ink',
  levels: [board('zip_1_01'), board('zip_1_02')],
  ...over,
});

describe('levelId', () => {
  it('is {game}_{order}_{nn}', () => {
    expect(levelId('zip', 1, 0)).toBe('zip_1_01');
    expect(levelId('zip', 3, 19)).toBe('zip_3_20');
  });
});

describe('board coordinates', () => {
  it('stores cells and wall ends as "r,c" strings and reads every form back as [r, c]', () => {
    const stored = boardToStored(board('zip_1_01'));
    expect(stored.solution?.[1]).toBe('0,1');
    expect(stored.walls[0]).toEqual({ a: '0,1', b: '0,2' });
    expect(stored.numbers).toEqual({ '0,0': 1, '3,0': 2 });
    expect(stored).not.toHaveProperty('difficulty');

    const back = boardFromStored(stored);
    expect(back.solution?.[1]).toEqual([0, 1]);
    expect(back.walls[0]).toEqual({ a: [0, 1], b: [0, 2] });

    // The app also writes [r,c] (inside a map) and {row,col}; firestoreValueToJs turns {row,col} into [r,c].
    expect(boardFromStored({ ...stored, walls: [{ a: [2, 3], b: [2, 4] }] }).walls[0]).toEqual({ a: [2, 3], b: [2, 4] });
  });

  it('drops a malformed cell instead of guessing', () => {
    const back = boardFromStored({ ...boardToStored(board('zip_1_01')), solution: ['0,0', 'x', [1, 'y']] });
    expect(back.solution).toEqual([[0, 0]]);
  });

  it('keeps a missing target as null and drops a target below 1', () => {
    expect(boardFromStored({ ...boardToStored(board('zip_1_01')), targetSeconds: 0 }).targetSeconds).toBeNull();
    expect(boardToStored({ ...board('zip_1_01'), targetSeconds: null })).not.toHaveProperty('targetSeconds');
  });
});

describe('checkWorld', () => {
  it('accepts a good draft world', () => {
    expect(checkWorld('zip', 1, world(), null)).toEqual([]);
  });

  it('checks theme, title, level count, ids, sizes and targets', () => {
    const issues = checkWorld(
      'zip',
      1,
      world({
        theme: 'lava',
        title: '  ',
        levels: [board('zip_1_02'), { ...board('zip_1_02', 5), targetSeconds: 0.5 }, { ...board('zip_1_03'), size: 9 }],
      }),
      null,
    );
    const paths = issues.map((i) => i.path);
    expect(paths).toContain('theme');
    expect(paths).toContain('title');
    expect(paths).toContain('levels.0.id');
    expect(paths).toContain('levels.1.size');
    expect(paths).toContain('levels.1.targetSeconds');
    expect(paths).toContain('levels.2.size');
  });

  it('refuses an empty world and one over the maximum', () => {
    expect(checkWorld('zip', 1, world({ levels: [] }), null).map((i) => i.path)).toContain('levels');
    const many = Array.from({ length: MAX_WORLD_LEVELS + 1 }, (_, i) => board(levelId('zip', 1, i)));
    expect(checkWorld('zip', 1, world({ levels: many }), null).map((i) => i.path)).toContain('levels');
  });

  it('a published world keeps the same ids in the same order', () => {
    const stored = { published: true, levelIds: ['zip_1_01', 'zip_1_02'] };
    expect(checkWorld('zip', 1, world(), stored)).toEqual([]);
    const swapped = world({ levels: [board('zip_1_02'), board('zip_1_01')] });
    expect(checkWorld('zip', 1, swapped, stored).map((i) => i.path)).toContain('levels');
    const added = world({ levels: [board('zip_1_01'), board('zip_1_02'), board('zip_1_03')] });
    expect(checkWorld('zip', 1, added, stored).map((i) => i.path)).toContain('levels');
  });

  it('runs the CMS shape checks on each board', () => {
    const bad = { ...board('zip_1_01'), numbers: [] as unknown as Record<string, number> };
    expect(checkWorld('zip', 1, world({ levels: [bad] }), null).some((i) => i.path.startsWith('levels.0'))).toBe(true);
  });

  it('knows the five themes', () => {
    expect(LEVEL_THEMES).toEqual(['ink', 'metro', 'embroidery', 'neon', 'sparkler']);
  });
});

describe('publish order', () => {
  const w = (order: number, published: boolean) => ({ order, published });

  it('publishes world n only when world n − 1 is published', () => {
    expect(checkPublish(1, [w(1, false)])).toBeNull();
    expect(checkPublish(2, [w(1, true), w(2, false)])).toBeNull();
    expect(checkPublish(2, [w(1, false), w(2, false)])).toEqual({ error: 'publish_order', blockedBy: 1 });
    expect(checkPublish(3, [w(1, true), w(3, false)])).toEqual({ error: 'publish_order', blockedBy: 2 });
  });

  it('unpublishes world n only while world n + 1 is unpublished', () => {
    expect(checkUnpublish(2, [w(1, true), w(2, true), w(3, false)])).toBeNull();
    expect(checkUnpublish(1, [w(1, true), w(2, true)])).toEqual({ error: 'unpublish_order', blockedBy: 2 });
  });

  it('deletes only a draft with no world after it', () => {
    expect(checkDelete(2, [w(1, true), w(2, false)])).toBeNull();
    expect(checkDelete(1, [w(1, false), w(2, false)])).toEqual({ error: 'world_not_last', blockedBy: 2 });
    expect(checkDelete(1, [w(1, true)])).toEqual({ error: 'world_published' });
  });
});
```

- [ ] **Step 3: Run to see them fail**

Run: `cd workers/admin-api && npx vitest run src/level_worlds_write.test.ts`
Expected: FAIL — module missing.

- [ ] **Step 4: Write the module**

`workers/admin-api/src/level_worlds_write.ts`:

```ts
import { validateCmsDocument } from './content_cms';

/** The world themes the app can draw. Anything else draws a plain backdrop there; the editor only offers these. */
export const LEVEL_THEMES = ['ink', 'metro', 'embroidery', 'neon', 'sparkler'] as const;
export type LevelTheme = (typeof LEVEL_THEMES)[number];

/** Levels per world. The app's map and the 1 MB doc limit both stay comfortable well past this. */
export const MAX_WORLD_LEVELS = 40;

export type Cell = [number, number];
export type BoardWall = { a: Cell; b: Cell };

/** A world level as the SPA edits it: the CMS Zip board plus an id and a target. */
export type WorldLevelBoard = {
  id: string;
  size: number;
  numbers: Record<string, number>;
  walls: BoardWall[];
  solution?: Cell[];
  targetSeconds: number | null;
};

export type WorldInput = { theme: string; title: string; levels: WorldLevelBoard[] };

export type WorldIssue = { path: string; message: string };

/** What a save needs to know about the stored world (null when there is none). */
export type StoredWorldFacts = { published: boolean; levelIds: string[] } | null;

export type OrderRefusal =
  | { error: 'publish_order'; blockedBy: number }
  | { error: 'unpublish_order'; blockedBy: number }
  | { error: 'world_not_last'; blockedBy: number }
  | { error: 'world_published' };

export function levelId(game: string, order: number, index: number): string {
  return `${game}_${order}_${String(index + 1).padStart(2, '0')}`;
}

function cellToString(c: Cell): string {
  return `${c[0]},${c[1]}`;
}

/** "r,c", [r, c] (as read back from {row,col} too) → [r, c]; anything else → null. */
function cellFromAny(v: unknown): Cell | null {
  if (typeof v === 'string') {
    const m = /^(\d+),(\d+)$/.exec(v.trim());
    return m ? [Number(m[1]), Number(m[2])] : null;
  }
  if (Array.isArray(v) && v.length === 2 && Number.isInteger(v[0]) && Number.isInteger(v[1])) {
    return [v[0] as number, v[1] as number];
  }
  return null;
}

/** The stored shape: cells and wall ends as "r,c" strings (Firestore forbids arrays in arrays). */
export function boardToStored(b: WorldLevelBoard): Record<string, unknown> {
  return {
    id: b.id,
    size: b.size,
    numbers: b.numbers,
    walls: b.walls.map((w) => ({ a: cellToString(w.a), b: cellToString(w.b) })),
    ...(b.solution && b.solution.length > 0 ? { solution: b.solution.map(cellToString) } : {}),
    ...(b.targetSeconds !== null ? { targetSeconds: b.targetSeconds } : {}),
  };
}

/** The editor shape: [r, c] everywhere; malformed cells and walls are dropped, a target below 1 is null. */
export function boardFromStored(raw: Record<string, unknown>): WorldLevelBoard {
  const numbers: Record<string, number> = {};
  const n = raw.numbers;
  if (n && typeof n === 'object' && !Array.isArray(n)) {
    for (const [k, v] of Object.entries(n as Record<string, unknown>)) {
      if (typeof v === 'number' && Number.isInteger(v)) numbers[k] = v;
    }
  }
  const walls: BoardWall[] = [];
  if (Array.isArray(raw.walls)) {
    for (const w of raw.walls) {
      const m = w && typeof w === 'object' ? (w as Record<string, unknown>) : {};
      const a = cellFromAny(m.a);
      const b = cellFromAny(m.b);
      if (a && b) walls.push({ a, b });
    }
  }
  const solution = Array.isArray(raw.solution)
    ? raw.solution.map(cellFromAny).filter((c): c is Cell => c !== null)
    : undefined;
  const t = raw.targetSeconds;
  return {
    id: typeof raw.id === 'string' ? raw.id : '',
    size: typeof raw.size === 'number' ? Math.trunc(raw.size) : 0,
    numbers,
    walls,
    ...(solution && solution.length > 0 ? { solution } : {}),
    targetSeconds: typeof t === 'number' && Number.isFinite(t) && t >= 1 ? Math.trunc(t) : null,
  };
}

/** Every reason a save is refused, as {path, message} (the SPA shows them per field). Empty means valid. */
export function checkWorld(game: string, order: number, input: WorldInput, stored: StoredWorldFacts): WorldIssue[] {
  const issues: WorldIssue[] = [];
  if (!(LEVEL_THEMES as readonly string[]).includes(input.theme)) {
    issues.push({ path: 'theme', message: `Theme must be one of ${LEVEL_THEMES.join(', ')}.` });
  }
  if (typeof input.title !== 'string' || input.title.trim() === '') {
    issues.push({ path: 'title', message: 'Give the world a title.' });
  }
  const levels = Array.isArray(input.levels) ? input.levels : [];
  if (levels.length === 0 || levels.length > MAX_WORLD_LEVELS) {
    issues.push({ path: 'levels', message: `A world has 1 to ${MAX_WORLD_LEVELS} levels.` });
  }
  const size = levels[0]?.size;
  levels.forEach((level, i) => {
    const want = levelId(game, order, i);
    if (level.id !== want) issues.push({ path: `levels.${i}.id`, message: `Level ${i + 1} must have id ${want}.` });
    if (!Number.isInteger(level.size) || level.size < 4 || level.size > 8) {
      issues.push({ path: `levels.${i}.size`, message: 'Board size must be 4 to 8.' });
    } else if (level.size !== size) {
      issues.push({ path: `levels.${i}.size`, message: `Every board in a world has the world's size (${size} × ${size}).` });
    }
    const t = level.targetSeconds;
    if (t !== null && !(Number.isInteger(t) && t >= 1)) {
      issues.push({ path: `levels.${i}.targetSeconds`, message: 'Target time is a whole number of seconds, at least 1, or empty.' });
    }
    const shape = validateCmsDocument('zip_levels', { size: level.size, numbers: level.numbers, walls: level.walls });
    if (!shape.ok) for (const message of shape.issues) issues.push({ path: `levels.${i}`, message });
  });
  if (stored?.published) {
    const ids = levels.map((l) => l.id);
    const same = ids.length === stored.levelIds.length && ids.every((id, i) => id === stored.levelIds[i]);
    if (!same) {
      issues.push({ path: 'levels', message: 'A published world keeps its levels: no adding, removing or reordering.' });
    }
  }
  return issues;
}

type OrderFact = { order: number; published: boolean };

export function checkPublish(order: number, worlds: OrderFact[]): OrderRefusal | null {
  if (order === 1) return null;
  const before = worlds.find((w) => w.order === order - 1);
  return before?.published ? null : { error: 'publish_order', blockedBy: order - 1 };
}

export function checkUnpublish(order: number, worlds: OrderFact[]): OrderRefusal | null {
  const after = worlds.find((w) => w.order === order + 1);
  return after?.published ? { error: 'unpublish_order', blockedBy: order + 1 } : null;
}

export function checkDelete(order: number, worlds: OrderFact[]): OrderRefusal | null {
  const self = worlds.find((w) => w.order === order);
  if (self?.published) return { error: 'world_published' };
  const later = worlds.filter((w) => w.order > order).sort((a, b) => a.order - b.order)[0];
  return later ? { error: 'world_not_last', blockedBy: later.order } : null;
}
```

Check `validateCmsDocument`'s signature in `content_cms.ts` (it returns `{ ok: true } | { ok: false; error; issues: string[] }`) and adjust the call if needed.

- [ ] **Step 5: Run to see them pass**

Run: `cd workers/admin-api && npx vitest run src/level_worlds_write.test.ts && npm run typecheck`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add workers/admin-api/src/level_worlds_write.ts workers/admin-api/src/level_worlds_write.test.ts
git commit -m "feat(worker): level world rules — coordinates, checks, publish order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `LevelsStore` writes

**Files:**
- Modify: `workers/admin-api/src/levels.ts` (`LevelsStore`; `FirestoreDoc` gains `updateTime?`)
- Test: `workers/admin-api/src/levels.test.ts`

Firestore REST facts this task relies on:
- `PATCH {root}/level_worlds/{id}?updateMask.fieldPaths=…&currentDocument.updateTime=<ts>` writes only if the doc's update time is exactly `<ts>`; `currentDocument.exists=false` writes only if the doc doesn't exist. The PATCH response body is the written document, including `updateTime`.
- A failed precondition is rejected; Google's docs don't pin the HTTP status (it is usually 400 with `FAILED_PRECONDITION` in the body; `exists=false` on an existing doc can come back `ALREADY_EXISTS`/409). So `saveWorld` treats a non-OK response as **stale** when the status is 409 or 412 or the body contains `FAILED_PRECONDITION`, `ALREADY_EXISTS` or `NOT_FOUND`; anything else is a `firestore_` error.
- `GET {root}/level_worlds/{id}` returns `{name, fields, createTime, updateTime}`; 404 when missing.

- [ ] **Step 1: Write the failing tests** (append to `levels.test.ts`, which already has `ROOT`, `int`, `str`, `ts`, `map` helpers and `afterEach(vi.unstubAllGlobals)`)

```ts
import { WorldStaleError } from './levels';

describe('LevelsStore world writes', () => {
  const stored = {
    name: `${ROOT}/level_worlds/zip_2`,
    updateTime: '2026-11-03T10:00:00.123456Z',
    fields: {
      game: str('zip'), order: int(2), theme: str('metro'), title: str('Metro'), published: { booleanValue: false },
      levels: { arrayValue: { values: [map({
        id: str('zip_2_01'), size: int(5), targetSeconds: int(30),
        numbers: map({ '0,0': int(1), '4,4': int(2) }),
        walls: { arrayValue: { values: [map({ a: str('1,2'), b: str('1,3') })] } },
        solution: { arrayValue: { values: [str('0,0'), str('0,1')] } },
      })] } },
    },
  };

  it('reads a full world with [r,c] coordinates and its updateTime', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json(stored)));
    const w = await new LevelsStore('p', 'tok').world('zip', 2);
    expect(w).toMatchObject({ id: 'zip_2', order: 2, theme: 'metro', published: false, updateTime: '2026-11-03T10:00:00.123456Z' });
    expect(w!.levels[0]).toMatchObject({ id: 'zip_2_01', size: 5, targetSeconds: 30, walls: [{ a: [1, 2], b: [1, 3] }], solution: [[0, 0], [0, 1]] });
  });

  it('is null for a missing world', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 404 })));
    expect(await new LevelsStore('p', 'tok').world('zip', 9)).toBeNull();
  });

  it('saves with an updateTime precondition and returns the new updateTime', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    vi.stubGlobal('fetch', vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return Response.json({ ...stored, updateTime: '2026-11-03T11:00:00Z' });
    }));
    const out = await new LevelsStore('p', 'tok').saveWorld('zip', 2, {
      fields: { game: 'zip', order: 2, theme: 'metro', title: 'Metro', published: false, levels: [] },
      updateTime: '2026-11-03T10:00:00.123456Z',
    });
    expect(out.updateTime).toBe('2026-11-03T11:00:00Z');
    expect(calls[0].init.method).toBe('PATCH');
    expect(calls[0].url).toContain(`${ROOT}/level_worlds/zip_2?`);
    expect(calls[0].url).toContain('currentDocument.updateTime=2026-11-03T10%3A00%3A00.123456Z');
    expect(calls[0].url).toContain('updateMask.fieldPaths=levels');
  });

  it('creates with exists=false when there is no updateTime', async () => {
    let url = '';
    vi.stubGlobal('fetch', vi.fn(async (u: string) => { url = u; return Response.json(stored); }));
    await new LevelsStore('p', 'tok').saveWorld('zip', 2, { fields: { game: 'zip' }, updateTime: null });
    expect(url).toContain('currentDocument.exists=false');
  });

  it.each([
    [400, '{"error":{"status":"FAILED_PRECONDITION"}}'],
    [409, '{"error":{"status":"ALREADY_EXISTS"}}'],
    [412, '{}'],
  ])('a failed precondition (%i) is a WorldStaleError', async (status, body) => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(body, { status })));
    await expect(
      new LevelsStore('p', 'tok').saveWorld('zip', 2, { fields: { game: 'zip' }, updateTime: 'x' }),
    ).rejects.toBeInstanceOf(WorldStaleError);
  });

  it('any other failure is a firestore_ error', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('boom', { status: 500 })));
    await expect(
      new LevelsStore('p', 'tok').saveWorld('zip', 2, { fields: { game: 'zip' }, updateTime: 'x' }),
    ).rejects.toThrow(/^firestore_levels_save_failed:500/);
  });

  it('sets published with a precondition, and deletes with one', async () => {
    const calls: string[] = [];
    vi.stubGlobal('fetch', vi.fn(async (url: string, init: RequestInit) => {
      calls.push(`${init.method} ${url}`);
      return init.method === 'DELETE' ? new Response('{}') : Response.json(stored);
    }));
    const store = new LevelsStore('p', 'tok');
    await store.setPublished('zip', 2, true, '2026-11-03T10:00:00Z', { uid: 'ops', email: 'ops@winklo.game' });
    await store.deleteWorld('zip', 2, '2026-11-03T10:00:00Z');
    expect(calls[0]).toMatch(/^PATCH .*updateMask\.fieldPaths=published.*currentDocument\.updateTime=/);
    expect(calls[1]).toMatch(/^DELETE .*level_worlds\/zip_2\?currentDocument\.updateTime=/);
  });
});
```

- [ ] **Step 2: Run to see them fail**

Run: `cd workers/admin-api && npx vitest run src/levels.test.ts`
Expected: FAIL — `world`, `saveWorld`, `setPublished`, `deleteWorld`, `WorldStaleError` missing.

- [ ] **Step 3: Implement**

In `levels.ts`:

```ts
import { jsToFirestoreValue } from './content_cms';
import { boardFromStored, type WorldLevelBoard } from './level_worlds_write';

type FirestoreDoc = { name: string; fields?: Record<string, unknown>; updateTime?: string };

/** The world changed (or appeared, or vanished) since the client loaded it. */
export class WorldStaleError extends Error {
  constructor() {
    super('world_changed');
  }
}

export type FullWorld = Omit<WorldSummary, 'levels'> & { levels: WorldLevelBoard[]; updateTime: string };

export type Actor = { uid: string; email: string | null };
```

Methods on `LevelsStore`:

```ts
  private docUrl(id: string, query: string[]): string {
    const qs = query.length ? `?${query.join('&')}` : '';
    return `https://firestore.googleapis.com/v1/${this.root()}/level_worlds/${encodeURIComponent(id)}${qs}`;
  }

  private static precondition(updateTime: string | null): string {
    return updateTime
      ? `currentDocument.updateTime=${encodeURIComponent(updateTime)}`
      : 'currentDocument.exists=false';
  }

  private static isStale(status: number, body: string): boolean {
    return status === 409 || status === 412 || /FAILED_PRECONDITION|ALREADY_EXISTS|NOT_FOUND/.test(body);
  }

  /** One world in full (boards as [r,c]), with Firestore's updateTime; null when missing or not this game's. */
  async world(game: LevelGame, order: number): Promise<FullWorld | null> {
    const doc = await this.getDoc(`level_worlds/${encodeURIComponent(`${game}_${order}`)}`);
    if (!doc) return null;
    const summary = worldFromDoc(doc.name, doc.fields);
    if (!summary || summary.game !== game) return null;
    const data = fieldsToJs(doc.fields);
    const raw = Array.isArray(data.levels) ? data.levels : [];
    return {
      ...summary,
      levels: raw.map((l) => boardFromStored(asMap(l))),
      updateTime: doc.updateTime ?? '',
    };
  }

  /**
   * Writes the given top-level fields of `{game}_{order}` (others are kept). `updateTime` null creates the doc
   * (refused if it exists); otherwise the write needs the doc's current updateTime. Returns the new updateTime.
   */
  async saveWorld(
    game: LevelGame,
    order: number,
    input: { fields: Record<string, unknown>; updateTime: string | null },
  ): Promise<{ updateTime: string }> {
    const fields: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(input.fields)) fields[k] = jsToFirestoreValue(v);
    const query = [
      ...Object.keys(fields).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`),
      LevelsStore.precondition(input.updateTime),
    ];
    const res = await fetch(this.docUrl(`${game}_${order}`, query), {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${this.accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });
    const text = await res.text();
    if (!res.ok) {
      if (LevelsStore.isStale(res.status, text)) throw new WorldStaleError();
      throw new Error(`firestore_levels_save_failed:${res.status}:${text.slice(0, 300)}`);
    }
    return { updateTime: (JSON.parse(text) as { updateTime?: string }).updateTime ?? '' };
  }

  async setPublished(game: LevelGame, order: number, published: boolean, updateTime: string, actor: Actor): Promise<{ updateTime: string }> {
    return this.saveWorld(game, order, {
      fields: { published, updatedAt: new Date().toISOString(), updatedByUid: actor.uid, updatedByEmail: actor.email },
      updateTime,
    });
  }

  async deleteWorld(game: LevelGame, order: number, updateTime: string): Promise<void> {
    const res = await fetch(this.docUrl(`${game}_${order}`, [LevelsStore.precondition(updateTime)]), {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });
    const text = await res.text();
    if (!res.ok) {
      if (LevelsStore.isStale(res.status, text)) throw new WorldStaleError();
      throw new Error(`firestore_levels_delete_failed:${res.status}:${text.slice(0, 300)}`);
    }
  }
```

Note: `jsToFirestoreValue` turns `[r,c]` array elements into `{row,col}` maps; the stored levels are already `"r,c"` strings (Task 3 converts with `boardToStored` before calling `saveWorld`), so nothing is converted twice. `updatedAt` stays an ISO string (the existing CMS writes it that way too, via `withCmsAuditFields`).

- [ ] **Step 4: Run** `cd workers/admin-api && npx vitest run src/levels.test.ts && npm run typecheck` → PASS.

- [ ] **Step 5: Commit** `feat(worker): read a full level world and save, publish and delete it with preconditions` (trailer as above).

---

### Task 3: World write routes

**Files:**
- Modify: `workers/admin-api/src/index.ts` (beside the levels GET routes, before the final 404)
- Test: `workers/admin-api/src/levels_write.routes.test.ts`

Routes (all behind `requireAdmin`; `:game` checked with `isLevelGame` → 400 `invalid_game` before auth; `:order` must match `^[1-9]\d{0,2}$` → else 400 `invalid_order`):

| Route | Body | Result |
|---|---|---|
| `GET /v1/levels/:game/worlds/:order` | — | 200 `{ world }` (a `FullWorld`) · 404 `{error:'world_not_found'}` |
| `PUT /v1/levels/:game/worlds/:order` | `{ theme, title, levels, updateTime: string \| null }` | 200 `{ updateTime }` · 400 `{error:'schema_invalid', issues:[{path,message}]}` · 409 `{error:'world_changed'}` |
| `POST …/:order/publish` | `{ updateTime }` | 200 `{ updateTime }` · 409 `{error:'publish_order', blockedBy}` · 409 `world_changed` · 404 |
| `POST …/:order/unpublish` | `{ updateTime }` | 200 `{ updateTime }` · 409 `{error:'unpublish_order', blockedBy}` · 409 `world_changed` · 404 |
| `DELETE /v1/levels/:game/worlds/:order?updateTime=<ts>` | — | 200 `{ ok: true }` · 409 `{error:'world_published'}` / `{error:'world_not_last', blockedBy}` / `world_changed` · 404 |

PUT details:
- Read the stored world first (`store.world`). If the body's `updateTime` is null and a world exists → 409 `{error:'world_exists'}`; if it's non-null and none exists → 409 `world_changed`.
- `checkWorld(game, order, body, stored ? {published, levelIds} : null)`; issues → 400 `schema_invalid` with `issues` as `{path, message}` objects (the SPA's `issuesOf` accepts them).
- Fields written: `game`, `order`, `theme`, `title.trim()`, `levels` (each through `boardToStored`), `published` (the stored value, or `false` for a new world), `updatedAt`, `updatedByUid`, `updatedByEmail`.
- `WorldStaleError` → 409 `world_changed` (catch it in the route; don't let it reach the global catch, which would say 401).
- Publish/unpublish/delete read all worlds with `store.worlds(game)` and apply `checkPublish` / `checkUnpublish` / `checkDelete` to `[{order, published}]`. Publishing an already-published world (or unpublishing a draft) returns 200 with the current `updateTime`, writing nothing.

- [ ] **Step 1: Write the failing route tests** — `workers/admin-api/src/levels_write.routes.test.ts`, with the same header as `levels.routes.test.ts` (mocked `./admin_auth`, `env` with `FIREBASE_ACCESS_TOKEN: 'test-token'`). Use a small in-memory Firestore fake for these routes so the tests read like the behaviour:

```ts
type Doc = { fields: Record<string, unknown>; updateTime: string };
function fakeFirestore(initial: Record<string, Doc> = {}) {
  const docs = new Map(Object.entries(initial));
  let clock = 0;
  const fetchMock = vi.fn(async (url: string, init: RequestInit = {}) => {
    const u = new URL(url);
    const method = init.method ?? 'GET';
    if (u.pathname.endsWith(':runQuery')) {
      return Response.json([...docs.entries()].map(([id, d]) => ({
        document: { name: `${ROOT}/level_worlds/${id}`, fields: d.fields, updateTime: d.updateTime },
      })));
    }
    const id = decodeURIComponent(u.pathname.split('/').pop()!);
    const doc = docs.get(id);
    const want = u.searchParams.get('currentDocument.updateTime');
    const mustNotExist = u.searchParams.get('currentDocument.exists') === 'false';
    if (method === 'GET') return doc ? Response.json({ name: `${ROOT}/level_worlds/${id}`, ...doc }) : new Response('{}', { status: 404 });
    if ((want && doc?.updateTime !== want) || (mustNotExist && doc)) {
      return new Response(JSON.stringify({ error: { status: 'FAILED_PRECONDITION' } }), { status: 400 });
    }
    if (method === 'DELETE') { docs.delete(id); return Response.json({}); }
    const body = JSON.parse(String(init.body)) as { fields: Record<string, unknown> };
    const updateTime = `2026-11-03T10:00:${String(++clock).padStart(2, '0')}Z`;
    docs.set(id, { fields: { ...(doc?.fields ?? {}), ...body.fields }, updateTime });
    return Response.json({ name: `${ROOT}/level_worlds/${id}`, fields: docs.get(id)!.fields, updateTime });
  });
  return { docs, fetchMock };
}
```

Tests (each stubs `fetch` with `fakeFirestore(...)`):
1. GET returns `{ world }` with `[r,c]` coordinates and `updateTime`; 404 `world_not_found`; 400 `invalid_order` for `/worlds/0` and `/worlds/abc`; 400 `invalid_game`.
2. PUT creates a new world (`updateTime: null`) → 200 with an `updateTime`; the stored doc has `published: false`, `game`, `order`, `"r,c"` strings in `levels[0].solution` and `levels[0].walls[0].a`, `updatedByUid: 'ops'`.
3. PUT with `updateTime: null` over an existing world → 409 `world_exists`.
4. PUT with a stale `updateTime` → 409 `world_changed`; with the current one → 200 and a new `updateTime`.
5. PUT with bad data → 400 `schema_invalid` with `issues` (e.g. a wrong id gives `{path:'levels.0.id', …}`).
6. PUT on a published world that reorders levels → 400 with a `levels` issue; changing a board and the target only → 200, and `published` stays true.
7. Publish world 2 while world 1 is a draft → 409 `{error:'publish_order', blockedBy:1}`; publish world 1 → 200 and stored `published: true`; then world 2 → 200.
8. Unpublish world 1 while world 2 is published → 409 `{error:'unpublish_order', blockedBy:2}`.
9. DELETE a published world → 409 `world_published`; a draft with a later world → 409 `world_not_last`; the last draft → 200 and it's gone; a stale `updateTime` → 409 `world_changed`.
10. Non-admin → 403 and no Firestore call.

Write them out in full in the file using the helpers above and `worker.fetch(new Request(…), env)`.

- [ ] **Step 2: Run to see them fail** → FAIL (404 `not_found`).

- [ ] **Step 3: Add the routes** in `index.ts`, just before the existing levels GET block:

```ts
      // Level worlds (plan 2b): one world in full, save, publish, unpublish, delete.
      const worldMatch = url.pathname.match(/^\/v1\/levels\/([a-z_]+)\/worlds\/([^/]+)(?:\/(publish|unpublish))?$/);
      if (worldMatch) {
        const [, game, orderRaw, action] = worldMatch;
        if (!isLevelGame(game)) return jsonResponse({ error: "invalid_game" }, 400, cors);
        if (!/^[1-9]\d{0,2}$/.test(orderRaw)) return jsonResponse({ error: "invalid_order" }, 400, cors);
        const order = Number(orderRaw);
        const { me, token } = await requireAdmin(request, env);
        const store = new LevelsStore(env.FIREBASE_PROJECT_ID, token);
        try {
          return await handleWorldRoute({ request, url, store, game, order, action, me, cors });
        } catch (err) {
          if (err instanceof WorldStaleError) return jsonResponse({ error: "world_changed" }, 409, cors);
          throw err;
        }
      }
```

and put `handleWorldRoute` in a new file `workers/admin-api/src/level_worlds_routes.ts` (keeps `index.ts` from growing), exporting:

```ts
export async function handleWorldRoute(ctx: {
  request: Request; url: URL; store: LevelsStore; game: LevelGame; order: number;
  action: string | undefined; me: { uid: string; email?: string | null };
  cors: Record<string, string>;
}): Promise<Response>
```

implementing the table above with `checkWorld`, `checkPublish`, `checkUnpublish`, `checkDelete`, `boardToStored`, and `Response.json(body, { status, headers: cors })` (the same thing `jsonResponse` does — import nothing from `index.ts`). Unknown method/action combinations → 404 `{error:'not_found'}`. Body parse failure → 400 `{error:'invalid_body'}`. Make sure the `worldMatch` block sits **before** the levels GET block so `/v1/levels/zip/worlds` (no order) still reaches the list route.

- [ ] **Step 4: Run** `cd workers/admin-api && npm run typecheck && npm test` → all PASS (the existing levels route tests too).

- [ ] **Step 5: Commit** `feat(worker): save, publish, unpublish and delete level worlds` (trailer).

---

### Task 4: SPA client, errors, mock store, queries

**Files:**
- Modify: `src/lib/adminApi.ts`, `src/lib/errors.ts`, `src/mocks/levels.ts` (+ `src/mocks/mockApi.ts` reset), `src/queries/keys.ts`, `src/queries/levels.ts`
- Test: `src/lib/adminApi.levels.test.ts`, `src/mocks/levels.test.ts`, `src/queries/levels.test.tsx`

- [ ] **Step 1: Types and fetchers** (`adminApi.ts`, under the Levels block — it mirrors `workers/admin-api/src/levels.ts` / `level_worlds_write.ts`):

```ts
export type LevelTheme = 'ink' | 'metro' | 'embroidery' | 'neon' | 'sparkler';
export const LEVEL_THEMES: readonly LevelTheme[] = ['ink', 'metro', 'embroidery', 'neon', 'sparkler'];
export const MAX_WORLD_LEVELS = 40;

/** A world level as the editor holds it: the CMS Zip board plus an id and a target ([r,c] coordinates). */
export type WorldLevel = Pick<ZipLevelData, 'size' | 'numbers' | 'walls' | 'solution'> & { id: string; targetSeconds: number | null };
export type LevelWorld = Omit<LevelWorldSummary, 'levels'> & { levels: WorldLevel[]; updateTime: string };
export type LevelWorldSave = { theme: string; title: string; levels: WorldLevel[]; updateTime: string | null };

export async function fetchLevelWorld(idToken: string, game: string, order: number): Promise<LevelWorld | null> { /* GET; null on code 'world_not_found' */ }
export async function saveLevelWorld(idToken: string, game: string, order: number, body: LevelWorldSave): Promise<{ updateTime: string }> { /* PUT */ }
export async function publishLevelWorld(idToken: string, game: string, order: number, updateTime: string): Promise<{ updateTime: string }> { /* POST …/publish */ }
export async function unpublishLevelWorld(idToken: string, game: string, order: number, updateTime: string): Promise<{ updateTime: string }> { /* POST …/unpublish */ }
export async function deleteLevelWorld(idToken: string, game: string, order: number, updateTime: string): Promise<void> { /* DELETE ?updateTime= */ }
```

Write each body like `fetchLevelPlayer`: `adminFetch(idToken, path, { method, body: JSON.stringify(...) })`, `if (!res.ok) throw await ApiError.fromResponse(res, 'level_world_<op>_failed_' + res.status)`, `fetchLevelWorld` returns null only for code `world_not_found`. Import `ZipLevelData` from `../pages/content/types` (check for an import cycle with `npm run typecheck:tests`; if one appears, define the board fields inline instead). Tests in `adminApi.levels.test.ts` (follow its existing fetch-stub pattern): URL and method for each; a 409 `world_changed` throws an `ApiError` with that code; GET 404 `world_not_found` → null, 404 `not_found` → throws.

- [ ] **Step 2: Error copy** in `src/lib/errors.ts` `BY_CODE` (read how `day_live` is written and match its shape):

| code | title | message |
|---|---|---|
| `world_changed` | Changed elsewhere | Someone saved this world after you opened it. Reload to see the latest, then make your change again. |
| `world_exists` | World already exists | A world with this number was created meanwhile. Reload the worlds. |
| `world_not_found` | World not found | It may have been deleted. |
| `publish_order` | Publish the earlier world first | World `{blockedBy}` has to be published before this one. |
| `unpublish_order` | Unpublish the later world first | World `{blockedBy}` is published, so this one has to stay published. |
| `world_published` | Published worlds can't be deleted | Unpublish it first. |
| `world_not_last` | Only the last world can be deleted | World `{blockedBy}` comes after this one. |

`{blockedBy}` comes from `err.details` (read `details` handling in `humanizeError`; if `BY_CODE` entries can't be functions, add a small branch for these three codes). All are `retryable: false`. Tests in the existing errors test file for two of them.

- [ ] **Step 3: Mock world store** (`src/mocks/levels.ts`): keep `MOCK_WORLDS` as the seed; add a mutable store (a `Map<number, LevelWorld>` built with `structuredClone` from full mock boards — give each mock world real boards by generating them once with `generateZip(size, { seed: order * 1000 + i })` from `../pages/content/generators/generateZip`, ids `levelId`-style, `targetSeconds` from the existing summaries) and `reset()`. `worlds(game)` now derives summaries from the store. Add `world(game, order)`, `save(game, order, body)`, `publish`, `unpublish`, `remove` that apply the **same** rules as the Worker (port `checkPublish`/`checkUnpublish`/`checkDelete` and the stale/exists checks; mock `updateTime` = `new Date(++tick).toISOString()`), throwing `new ApiError({ status: 409, code: 'world_changed', … })` etc. so the UI's error paths are exercisable in tests. Register `levelsMock.reset()` in `resetMockStores()`. Tests in `src/mocks/levels.test.ts`: save then read back; stale save → 409; publish order; delete rules.

- [ ] **Step 4: Queries** (`keys.ts`: `world: (game, order) => ['levels', 'world', game, order] as const`). In `src/queries/levels.ts`:

```ts
export function useLevelWorld(game: string, order: number, enabled = true) { /* useAuthedQuery, staleTime 0 (always fresh before editing), fromSource('levels', fetchLevelWorld, api.levels.world) */ }
export function useSaveLevelWorld(game: string, order: number) { /* useAppMutation, errorMode 'inline', successToast 'World saved', invalidate [qk.levels.all()] */ }
export function usePublishLevelWorld(game: string, order: number) { /* errorMode 'toast', successToast 'World published', invalidate all */ }
export function useUnpublishLevelWorld(game: string, order: number) { /* 'World unpublished' */ }
export function useDeleteLevelWorld(game: string, order: number) { /* errorMode 'silent' (runs inside a confirm), invalidate all */ }
```

Read `useAppMutation` and `useSaveContentDoc` (src/queries/content.ts) and follow them. Test in `src/queries/levels.test.tsx`: save through the mock then `useLevelWorld` returns the new data; a stale save surfaces `world_changed`.

- [ ] **Step 5: Gates** — `npx vitest run src/lib src/mocks src/queries`, `npm run typecheck:tests`, `npm run lint`. Commit `feat(levels): client, mock store and queries for editing level worlds` (trailer).

---

### Task 5: `levelRamp` and exact counts in `generateZip`

**Files:**
- Create: `src/pages/content/generators/levelRamp.ts`, `levelRamp.test.ts`
- Modify: `src/pages/content/generators/generateZip.ts`, `generatorProtocol.ts`, `generateZip.test.ts`

The ramp (early levels: many numbers, no walls; last levels: as sparse as the daily "Hard" band, with walls):

| size | numbers (first → last) | walls (first → last) | seconds per cell | target (cells × s, rounded) |
|---|---|---|---|---|
| 4 | 8 → 4 | 0 → 4 | 1.25 | 20 |
| 5 | 9 → 4 | 0 → 6 | 1.2 | 30 |
| 6 | 10 → 5 | 0 → 8 | 1.15 | 41 |
| 7 | 11 → 5 | 0 → 10 | 1.1 | 54 |
| 8 | 12 → 6 | 0 → 12 | 1.05 | 67 |

i.e. `maxNumbers = size + 4`, `minNumbers = max(4, size - 2)`, `maxWalls = 2 × size − 4`; for level `i` of `count`, `t = count === 1 ? 0 : i / (count − 1)`, `numbers = round(maxNumbers + (minNumbers − maxNumbers) × t)`, `walls = round(maxWalls × t)`.

- [ ] **Step 1: Failing tests** — `levelRamp.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { levelRamp, rampBounds, suggestedTargetSeconds, worldLevelSeed } from './levelRamp';
import { generateZip } from './generateZip';
import { validateZip } from '../validators/zip';

describe('levelRamp', () => {
  it('starts with many numbers and no walls, ends sparse with walls', () => {
    expect(levelRamp(4, 0, 20)).toEqual({ numbers: 8, walls: 0 });
    expect(levelRamp(4, 19, 20)).toEqual({ numbers: 4, walls: 4 });
    expect(levelRamp(8, 19, 20)).toEqual({ numbers: 6, walls: 12 });
  });

  it('is monotonic: numbers never rise, walls never fall', () => {
    for (const size of [4, 5, 6, 7, 8]) {
      const ramp = Array.from({ length: 20 }, (_, i) => levelRamp(size, i, 20));
      for (let i = 1; i < ramp.length; i++) {
        expect(ramp[i].numbers).toBeLessThanOrEqual(ramp[i - 1].numbers);
        expect(ramp[i].walls).toBeGreaterThanOrEqual(ramp[i - 1].walls);
      }
    }
  });

  it('a one-level world gets the easiest board', () => {
    expect(levelRamp(6, 0, 1)).toEqual({ numbers: rampBounds(6).maxNumbers, walls: 0 });
  });

  it('suggests targets from the board size', () => {
    expect([4, 5, 6, 7, 8].map(suggestedTargetSeconds)).toEqual([20, 30, 41, 54, 67]);
  });

  it('seeds are reproducible and distinct per level and attempt', () => {
    expect(worldLevelSeed(2, 3, 0)).toBe(worldLevelSeed(2, 3, 0));
    const seeds = new Set([0, 1, 2].flatMap((a) => Array.from({ length: 40 }, (_, i) => worldLevelSeed(2, i, a))));
    expect(seeds.size).toBe(120);
  });

  it('every ramp board generates valid with the exact counts asked', () => {
    for (const size of [4, 5, 6, 7, 8]) {
      for (let i = 0; i < 20; i++) {
        const counts = levelRamp(size, i, 20);
        const board = generateZip(size, { seed: worldLevelSeed(size, i, 0), counts });
        expect(validateZip(board).ok, `${size}×${size} level ${i}`).toBe(true);
        expect(Object.keys(board.numbers)).toHaveLength(counts.numbers);
        expect(board.walls.length).toBeLessThanOrEqual(counts.walls);
      }
    }
  });
});
```

(Walls are `≤` because `placeWalls` can only use edges off the solution path; the test pins that the board is still valid.)

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** `levelRamp.ts`:

```ts
/** Per-size bounds for a world's difficulty ramp (see plan 2b's table). */
export function rampBounds(size: number): { maxNumbers: number; minNumbers: number; maxWalls: number } {
  return { maxNumbers: size + 4, minNumbers: Math.max(4, size - 2), maxWalls: 2 * size - 4 };
}

/** Numbers fall and walls rise in a straight line from the first level to the last. */
export function levelRamp(size: number, index: number, count: number): { numbers: number; walls: number } {
  const { maxNumbers, minNumbers, maxWalls } = rampBounds(size);
  const t = count <= 1 ? 0 : index / (count - 1);
  return { numbers: Math.round(maxNumbers + (minNumbers - maxNumbers) * t), walls: Math.round(maxWalls * t) };
}

const SECONDS_PER_CELL: Record<number, number> = { 4: 1.25, 5: 1.2, 6: 1.15, 7: 1.1, 8: 1.05 };

/** A starting target time for the third star; editable per level. */
export function suggestedTargetSeconds(size: number): number {
  return Math.round(size * size * (SECONDS_PER_CELL[size] ?? 1));
}

/** Reproducible: the same world, level and attempt always give the same board. */
export function worldLevelSeed(order: number, index: number, attempt: number): number {
  return order * 1_000_000 + attempt * 1_000 + index + 1;
}
```

In `generateZip.ts`: extend `opts` with `counts?: { numbers: number; walls: number }`. When present, use `counts.numbers` (clamped to `[1, size*size]`) instead of `numberCountFor(...)`, and in `placeWalls` use `target = Math.min(candidates.length, counts.walls)` instead of the band's random range. Leave `difficulty`'s default behaviour untouched for every existing caller. In `generatorProtocol.ts`, add `counts?: { numbers: number; walls: number }` to the zip request and pass it through in `runGenerator`. Add a `generateZip.test.ts` case: with `counts`, the number count is exact and a call without `counts` gives the same board as before for a fixed seed (pin one existing seed's output length).

- [ ] **Step 4: Run** `npx vitest run src/pages/content/generators` → PASS. Gates: typecheck:tests, lint.

- [ ] **Step 5: Commit** `feat(levels): a difficulty ramp for world boards, with exact counts in generateZip` (trailer).

---

### Task 6: `useGenerateWorld`

**Files:**
- Create: `src/pages/levels/useGenerateWorld.ts`, `useGenerateWorld.test.tsx`

Behaviour: `generate({ game, order, size, count })` produces `count` levels in order. For level `i`: request `{ kind: 'zip', size, difficulty: 'easy', seed: worldLevelSeed(order, i, attempt), counts: levelRamp(size, i, count) }` from the existing generator (`useGenerator` in `src/pages/content/generators/useGenerator.ts` — read it; one run at a time, so await each before the next); check with `validateZip`; on an invalid board retry with the next attempt, at most 5 attempts, then stop with an error naming the level ("Level 7 couldn't be generated. Try again or change the size."). Each level becomes `{ id: levelId(game, order, i), size, numbers, walls, solution, targetSeconds: suggestedTargetSeconds(size) }`. Exposes `{ generate, cancel, progress: { done, total } | null, error, isRunning }`. `cancel()` aborts the current run; `generate` then rejects with an abort error the caller ignores (use the generator's `isAbortError`).

Put `levelId(game, order, index)` in `src/pages/levels/worldDraft.ts` (Task 7 creates the rest of that file; create the file here with just `levelId` if Task 7 hasn't run).

- [ ] **Step 1: Failing test** — render the hook with the inline generator (find how `useGenerator` tests force the inline client, e.g. `generatorClient.fallback.test.ts`), generate a 4×4, 5-level world, expect 5 levels with ids `zip_3_01…05`, all `validateZip` ok, targets 20, and `progress` ending `{done: 5, total: 5}`; a second run with the same inputs gives identical boards; `cancel()` mid-run leaves `isRunning` false and no error.
- [ ] **Step 2: Run → FAIL. Step 3: Implement. Step 4: Run → PASS** (`npx vitest run src/pages/levels/useGenerateWorld.test.tsx`), typecheck, lint.
- [ ] **Step 5: Commit** `feat(levels): generate a whole world of boards along the ramp` (trailer).

---

### Task 7: The world page (load, header, level list, save)

**Files:**
- Create: `src/pages/levels/worldDraft.ts` (+ test), `src/pages/levels/WorldEditorPage.tsx` (+ test)
- Modify: `src/routes.tsx` (`levelWorld: () => import('./pages/levels/WorldEditorPage')`, export `'WorldEditorPage'`, `page('levels/:game/worlds/:order', 'levelWorld')`), `src/pages/levels/WorldsTab.tsx`, `src/pages/levels/levels.css`

`worldDraft.ts` (pure, fully tested):

```ts
export type WorldDraft = { theme: LevelTheme; title: string; levels: WorldLevel[]; published: boolean; updateTime: string | null };

export function levelId(game: string, order: number, index: number): string;           // zip_2_07
export function themeForOrder(order: number): LevelTheme;                               // LEVEL_THEMES[(order-1) % 5]
export function defaultSizeForOrder(order: number): number;                             // clamp(order + 3, 4, 8)
export function newWorldDraft(order: number): WorldDraft;                               // theme for order, title = capitalised theme, no levels, published false, updateTime null
export function draftFromWorld(world: LevelWorld): WorldDraft;
export function renumber(game: string, order: number, levels: WorldLevel[]): WorldLevel[]; // ids follow position
export function moveLevel(levels: WorldLevel[], from: number, to: number): WorldLevel[];
export function removeLevel(levels: WorldLevel[], index: number): WorldLevel[];
export function isDirty(a: WorldDraft, b: WorldDraft): boolean;                          // deep compare theme/title/levels
export function nextWorldOrder(worlds: { order: number }[]): number;                    // max + 1, or 1
export function draftIssues(draft: WorldDraft): ValidationIssue[];                       // client-side mirror of the Worker's checkWorld plus validateZip on each board
export function toSave(game: string, order: number, draft: WorldDraft): LevelWorldSave; // renumbered ids, trimmed title
```

Page behaviour:
- Route params `game`, `order` (`new` is not a route — New world navigates to the next free order with `?new=1`). With `?new=1` and no stored world: start from `newWorldDraft(order)`; otherwise load `useLevelWorld` and seed the draft once from it (`useState` initialised when data first arrives; keep a `base` copy for `isDirty`).
- Header (`PageHeader`, breadcrumb leaf `World N · Theme`): Theme `Select` (the five themes), Title `Input`, a Published/Draft `Badge`, and actions: **Save** (primary; disabled when not dirty), **Generate world** (drafts only; Task 9), **Publish** / **Unpublish** and **Delete** (Task 10). Size shown read-only as `N × N` from the first level (Generate sets it).
- Level list: a `DataTable` (label "Levels in this world") — columns Level (`Level {global number}` is not known here; show `#{i+1}` and the id), Numbers (count of `numbers`), Walls (count), Target (`m:ss` via `formatSeconds` from levelsModel, or "—"), and row actions: **Edit** (Task 8's modal), and for drafts **Move up**, **Move down**, **Remove**. A published world shows a `Callout` (info): "Published worlds keep their levels. You can change boards and target times, but not add, remove or reorder levels." and hides those three actions. Drafts get an **Add level** button (opens Task 8's modal with an empty board of the world's size).
- Save: `useSaveLevelWorld(...).mutateAsync(toSave(...))`. Show client `draftIssues` before sending (as `ContentEditorModal` does: a `Callout` with the list once the user has tried to save); on success replace `base` with the saved draft (and its new `updateTime`) and drop `?new=1`; server errors render inline with `humanizeError` (a `world_changed` error offers a **Reload** button that refetches and re-seeds the draft after a `useConfirmDiscard`).
- `UnsavedChangesGuard when={dirty}` (route changes and reloads ask).
- `WorldsTab`: each card becomes a link to `/levels/{game}/worlds/{order}` (keep the `article` and its `aria-labelledby`; wrap the title in a `Link` or make the card a `CardLink` — read `src/ui/Card.tsx`); add a **New world** `Button` above the grid that navigates to `/levels/{game}/worlds/{nextWorldOrder(worlds)}?new=1`. The empty state's description becomes "Create World 1 to start." with the same button.

- [ ] **Step 1: `worldDraft` tests** (write every function's cases: renumber after move/remove, `nextWorldOrder([])` = 1, `themeForOrder(6)` = 'ink', `defaultSizeForOrder(9)` = 8, `isDirty` ignores key order, `draftIssues` flags an empty title, mixed sizes, and an invalid board).
- [ ] **Step 2: Run → FAIL; implement `worldDraft.ts`; run → PASS.**
- [ ] **Step 3: Page tests** (`WorldEditorPage.test.tsx`, mock mode; render with `renderRoute` at `/levels/zip/worlds/1` and also a route `/levels` with `<p>levels page</p>`): loads World 1 from the mock with its levels; editing the title enables Save and saving shows "World saved" and clears dirty; a published world hides Move/Remove/Add and shows the callout; `/levels/zip/worlds/4?new=1` starts an empty "World 4 · Neon" draft whose Save creates it (then the Worlds tab lists it); a stale save (change the mock store's `updateTime` underneath, e.g. through `mockApi.levels.save` in the test) shows "Changed elsewhere" with Reload. `WorldsTab` test: a card links to its world; New world goes to `?new=1` with the next order.
- [ ] **Step 4: Implement** the page, routes, WorldsTab changes and CSS (`.lv-editor`, `.lv-editor__head`, `.lv-editor__fields` — a two-column grid that becomes one column under the `--…` breakpoint the other pages use; read `platform.css` for the media query they use).
- [ ] **Step 5: Gates** (all SPA gates incl. `check:bundle` — the page must be its own lazy chunk). Commit `feat(levels): a world page to edit a world's theme, title and levels` (trailer).

---

### Task 8: Edit one level (`LevelEditModal`)

**Files:**
- Create: `src/pages/levels/LevelEditModal.tsx`, `LevelEditModal.test.tsx`
- Modify: `src/pages/levels/WorldEditorPage.tsx`

A `Modal` (size `lg`, title "Level {i+1}" or "New level") hosting the existing `ZipBoardEditor` (`src/pages/content/editors/ZipBoardEditor.tsx`, props `EditorProps<ZipLevelData>`: `data`, `onChange`, `issues`, `attempts`, `disabled`) for the board, plus a **Target time** `Field` with `<Input type="number" min={1}>` in seconds (empty = no target; hint: "Clearing at or under this time earns the third star. Empty: no time star, so the level tops out at 2."). The board size is fixed to the world's size: if `ZipBoardEditor` lets the size change, pass the world size and, on `onChange` with a different size, show an inline error "Boards in this world are {n} × {n}." and keep the old size (do not edit `ZipBoardEditor`). **Done** validates with `validateZip` (issues shown inline via the `issues`/`attempts` props) and the target (whole number ≥ 1 or empty), then returns the level to the page; **Cancel** asks `useConfirmDiscard` when changed. A new level starts from an empty board of the world's size with the suggested target, and the user generates it with the editor's own Generate button.

- [ ] Steps: failing tests (opens with the level's board and target; changing the target and Done updates the page's row; an invalid target blocks Done with a message; Cancel with changes asks first; Add level appends a generated level) → implement → gates → commit `feat(levels): edit one level's board and target time` (trailer).

---

### Task 9: Generate world (`GenerateWorldModal`)

**Files:**
- Create: `src/pages/levels/GenerateWorldModal.tsx`, `GenerateWorldModal.test.tsx`
- Modify: `src/pages/levels/WorldEditorPage.tsx`

Drafts only. Inputs: **Board size** (`Select` 4–8, default `defaultSizeForOrder(order)` or the world's current size) and **Levels** (`Input type="number"`, 1–`MAX_WORLD_LEVELS`, default 20). **Generate** — if the draft already has levels, `useConfirm` first ("Replace all {n} levels?", tone warn, confirm "Replace levels"); then `useGenerateWorld().generate(...)`, showing "Generating level {done + 1} of {total}" with a progress bar (read `src/ui` for an existing progress/`Meter` component; if none, a `<progress>` element styled in `levels.css`) and a **Stop** button (`cancel`). On success replace the draft's levels (dirty → Save enabled) and close; on error show it inline and keep the old levels.

- [ ] Steps: failing tests (generate a 4×4, 3-level world into an empty draft → 3 rows, targets 0:20; replacing asks first and keeps the old levels when declined; Stop leaves the levels unchanged; the button is absent on a published world) → implement → gates → commit `feat(levels): generate a draft world's boards along the ramp` (trailer).

---

### Task 10: Publish, unpublish, delete

**Files:**
- Modify: `src/pages/levels/WorldEditorPage.tsx` (+ test)

- **Publish** (drafts, saved and not dirty — if dirty, the button says "Save first" and is disabled): `useConfirm` — title "Publish World {n}?", body "Players will see it, and its level list will be locked: no adding, removing or reordering levels after this.", confirm "Publish". Then `usePublishLevelWorld`; the page re-seeds from the refetched world.
- **Unpublish** (published): confirm — "Unpublish World {n}?", body "Players stop seeing it. Their progress in it is kept.", confirm "Unpublish".
- **Delete** (drafts only): `useConfirm` with `typeToConfirm: 'delete'`, tone danger, `run` = the delete mutation (so the dialog shows the busy state); on success navigate to `/levels` (Worlds tab) with `bypassOnce()` from `useUnsavedChanges` so the guard doesn't ask.
- Refusals (`publish_order`, `unpublish_order`, `world_not_last`, `world_published`, `world_changed`) show the Task 4 copy as toasts (publish/unpublish) or inline in the confirm (delete).

- [ ] Steps: failing tests (publish World 3 in the mock while World 2 … use the mock's draft World 3: publish refused with "Publish the earlier world first" when World 2 is a draft — seed accordingly; publish the next-in-line draft succeeds and the badge turns Published and editing locks; unpublish the last published world succeeds; unpublish a world with a later published one is refused; delete needs typing "delete" and returns to the Worlds tab) → implement → gates → commit `feat(levels): publish, unpublish and delete worlds in order` (trailer).

---

### Task 11: Verification and hand-off

- [ ] All SPA gates and Worker gates pass on a quiet machine (no other vitest running).
- [ ] Update the spec (`docs/superpowers/specs/2026-11-02-admin-levels-design.md` in winklo, in the `feat/admin-levels-2b` docs worktree): the world page route is `/levels/:game/worlds/:order`; New world uses `?new=1`; the stale-save error code is `world_changed` (and `world_exists` for a create race); the ramp table and seed formula from Task 5; the editor fixes a world's board size (Generate sets it). Commit there.
- [ ] Mock-mode look (only if a browser can be launched on this machine; on 2026-11-03 headless Chrome and the Playwright MCP both hung here — if so, say so and skip): `/levels`, a world page, the level modal, Generate world.
- [ ] Real-data notes for the user: deploying is pushing `main` (deploy.yml publishes the site and the Worker); World 1 (seeded) opens in the editor, and its `"r,c"` strings round-trip; create World 2 as a draft, generate, tune, then publish.
- [ ] Hand off with superpowers:finishing-a-development-branch for winklo-admin `feat/admin-levels-2b` and the winklo docs branch `feat/admin-levels-2b`.
