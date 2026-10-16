# App opens A: the activity Worker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public Cloudflare Worker `winklo-activity` that records a guest's app open in `daily_activity/{day}/guests/{installId}`.

**Architecture:** One route, `POST /v1/open`. It checks the payload, rate-limits per IP and per install ID with Workers Rate Limiting bindings, then creates the doc (or, when it exists, increments `opens`) through the Firestore REST `commit` endpoint with a service-account token. Helpers are copied from `workers/leaderboard` (each Worker in this repo carries its own copy).

**Tech Stack:** TypeScript, Cloudflare Workers, `jose` (service-account JWT), vitest.

Spec: `docs/superpowers/specs/2026-10-17-app-opens-tracking-design.md` (section "Worker").

Node is not on PATH by default. Every shell step starts with:

```bash
export PATH="$HOME/.nvm/versions/node/v24.16.0/bin:$PATH"
```

---

## File structure

| File | Responsibility |
|------|----------------|
| `workers/activity/package.json`, `tsconfig.json`, `vitest.config.ts`, `wrangler.toml` | Worker project (mirrors `workers/leaderboard`) |
| `workers/activity/src/google_auth.ts` | Service-account → access token (copied from `workers/leaderboard/src/google_auth.ts`) |
| `workers/activity/src/firestore.ts` | `encodeFields`, `commit`, `ContentionError` with an `increment` transform |
| `workers/activity/src/open.ts` | Payload checks (`parseOpen`) and the create-or-increment write (`recordGuestOpen`) |
| `workers/activity/src/index.ts` | Routing, body size, rate limits, error → status |

---

### Task 1: Project scaffold

**Files:**
- Create: `workers/activity/package.json`
- Create: `workers/activity/tsconfig.json`
- Create: `workers/activity/vitest.config.ts`
- Create: `workers/activity/wrangler.toml`
- Create: `workers/activity/.gitignore`

- [ ] **Step 1: Write the files**

`workers/activity/package.json`:

```json
{
  "name": "winklo-activity",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "typecheck": "tsc -p tsconfig.json"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250901.0",
    "typescript": "^5.6.0",
    "vitest": "^3.0.0",
    "wrangler": "^4.36.0"
  },
  "dependencies": {
    "jose": "^5.9.0"
  }
}
```

`workers/activity/tsconfig.json`: copy `workers/leaderboard/tsconfig.json` unchanged.

`workers/activity/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
  },
});
```

`workers/activity/wrangler.toml`:

```toml
name = "winklo-activity"
main = "src/index.ts"
compatibility_date = "2026-09-01"

# Records guests' app opens (daily_activity/{day}/guests/{installId}).
# Secret (not in this file): FIREBASE_SERVICE_ACCOUNT_JSON, a service account
# that can write Firestore (`npx wrangler secret put
# FIREBASE_SERVICE_ACCOUNT_JSON`).
[vars]
FIREBASE_PROJECT_ID = "brain-zip-app"

# Workers Rate Limiting (wrangler 4.36+). Counters are per Cloudflare
# location and eventually consistent: a brake on scripts, not an exact quota.
# namespace_id must be unique in the Cloudflare account.
[[ratelimits]]
name = "IP_LIMIT"
namespace_id = "4101"
simple = { limit = 30, period = 60 }

[[ratelimits]]
name = "INSTALL_LIMIT"
namespace_id = "4102"
simple = { limit = 6, period = 60 }
```

`workers/activity/.gitignore`:

```
node_modules
.wrangler
.dev.vars
```

- [ ] **Step 2: Install**

Run: `cd workers/activity && npm install`
Expected: `package-lock.json` created, no errors.

- [ ] **Step 3: Commit**

```bash
git add workers/activity/package.json workers/activity/package-lock.json workers/activity/tsconfig.json workers/activity/vitest.config.ts workers/activity/wrangler.toml workers/activity/.gitignore
git commit -m "feat(activity): scaffold the activity Worker"
```

---

### Task 2: Firestore REST helpers

**Files:**
- Create: `workers/activity/src/google_auth.ts`
- Create: `workers/activity/src/firestore.ts`
- Test: `workers/activity/src/firestore.test.ts`

- [ ] **Step 1: Copy the token helper**

Copy `workers/leaderboard/src/google_auth.ts` to `workers/activity/src/google_auth.ts`. Change only its top comment to:

```ts
// Same token exchange as workers/leaderboard/src/google_auth.ts, with only the
// Firestore scope, and the token kept for the isolate's lifetime.
```

- [ ] **Step 2: Write the failing test**

`workers/activity/src/firestore.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ContentionError, commit, documentsBase, encodeFields } from './firestore';

afterEach(() => vi.unstubAllGlobals());

describe('encodeFields', () => {
  it('encodes integers, strings and null', () => {
    expect(encodeFields({ opens: 1, platform: 'android', x: null })).toEqual({
      opens: { integerValue: '1' },
      platform: { stringValue: 'android' },
      x: { nullValue: null },
    });
  });
});

describe('commit', () => {
  const write = {
    update: { name: `${documentsBase('p')}/daily_activity/2026-10-17/guests/g`, fields: {} },
    currentDocument: { exists: false } as const,
  };

  it('posts the writes to :commit with the token', async () => {
    const fetchMock = vi.fn(async () => Response.json({ writeResults: [] }));
    vi.stubGlobal('fetch', fetchMock);
    await commit({ projectId: 'p', accessToken: 't', writes: [write] });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://firestore.googleapis.com/v1/projects/p/databases/(default)/documents:commit');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer t');
    expect(JSON.parse(String(init.body))).toEqual({ writes: [write] });
  });

  it('throws ContentionError when a precondition fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 })),
    );
    await expect(commit({ projectId: 'p', accessToken: 't', writes: [write] })).rejects.toBeInstanceOf(
      ContentionError,
    );
  });

  it('throws a plain error for any other failure', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('boom', { status: 500 })));
    const error = await commit({ projectId: 'p', accessToken: 't', writes: [write] }).catch((e) => e);
    expect(error).not.toBeInstanceOf(ContentionError);
    expect(String(error)).toMatch(/firestore_commit_failed:500/);
  });
});
```

- [ ] **Step 3: Run it to see it fail**

Run: `cd workers/activity && npx vitest run src/firestore.test.ts`
Expected: FAIL, cannot resolve `./firestore`.

- [ ] **Step 4: Implement**

`workers/activity/src/firestore.ts`:

```ts
/**
 * The Firestore REST calls this Worker needs: one `commit` per write, at most
 * two per open (create, then increment when the doc already exists).
 */

const FIRESTORE_API = 'https://firestore.googleapis.com/v1';

export type FirestoreValue = Record<string, unknown>;

export function documentsBase(projectId: string): string {
  return `projects/${projectId}/databases/(default)/documents`;
}

export function encodeValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  throw new Error(`Cannot encode ${typeof value}`);
}

export function encodeFields(data: Record<string, unknown>): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(data)) fields[k] = encodeValue(v);
  return fields;
}

export type Precondition = { exists: boolean };

export type FieldTransform =
  | { fieldPath: string; setToServerValue: 'REQUEST_TIME' }
  | { fieldPath: string; increment: FirestoreValue };

export type CommitWrite = {
  update: { name: string; fields: Record<string, FirestoreValue> };
  /** Without a mask the write replaces the whole doc (used to create one). */
  updateMask?: { fieldPaths: string[] };
  updateTransforms?: FieldTransform[];
  currentDocument: Precondition;
};

/** A precondition no longer held: the doc appeared, or vanished, before the commit. */
export class ContentionError extends Error {
  constructor(detail: string) {
    super(`firestore_contention:${detail}`);
  }
}

/** Status codes Firestore uses when a precondition no longer holds. */
const CONTENTION_STATUSES = new Set(['ABORTED', 'ALREADY_EXISTS', 'FAILED_PRECONDITION', 'NOT_FOUND']);

/** Applies [writes] atomically; throws [ContentionError] when a precondition failed. */
export async function commit(opts: {
  projectId: string;
  accessToken: string;
  writes: CommitWrite[];
}): Promise<void> {
  const res = await fetch(`${FIRESTORE_API}/${documentsBase(opts.projectId)}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${opts.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes: opts.writes }),
  });
  if (res.ok) {
    await res.text();
    return;
  }
  const text = await res.text();
  let status = '';
  try {
    status = (JSON.parse(text) as { error?: { status?: string } }).error?.status ?? '';
  } catch {
    // Not JSON; fall through to a plain failure.
  }
  if (CONTENTION_STATUSES.has(status)) throw new ContentionError(status);
  throw new Error(`firestore_commit_failed:${res.status}:${text.slice(0, 300)}`);
}
```

- [ ] **Step 5: Run the tests**

Run: `cd workers/activity && npx vitest run src/firestore.test.ts`
Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
git add workers/activity/src/google_auth.ts workers/activity/src/firestore.ts workers/activity/src/firestore.test.ts
git commit -m "feat(activity): Firestore commit and token helpers"
```

---

### Task 3: Payload checks and the guest write

**Files:**
- Create: `workers/activity/src/open.ts`
- Test: `workers/activity/src/open.test.ts`

- [ ] **Step 1: Write the failing test**

`workers/activity/src/open.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { dayIsOpenNow, guestDocName, INSTALL_ID_PATTERN, parseOpen, recordGuestOpen } from './open';

const NOW = Date.parse('2026-10-17T10:00:00Z');
const ID = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const good = { installId: ID, dayId: '2026-10-17', platform: 'android', appVersion: '1.1.0', build: 19 };

describe('parseOpen', () => {
  it('accepts a well-formed open', () => {
    expect(parseOpen(good, NOW)).toEqual(good);
  });

  it.each([
    ['not an object', 'x'],
    ['an array', [good]],
    ['a non-v4 install id', { ...good, installId: '3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b' }],
    ['an uppercase install id', { ...good, installId: ID.toUpperCase() }],
    ['a made-up day', { ...good, dayId: '2026-02-31' }],
    ['a day outside the window', { ...good, dayId: '2026-10-19' }],
    ['an unknown platform', { ...good, platform: 'web' }],
    ['an empty version', { ...good, appVersion: '' }],
    ['a version with spaces', { ...good, appVersion: '1.1 beta' }],
    ['a 33-character version', { ...good, appVersion: '1'.repeat(33) }],
    ['a fractional build', { ...good, build: 1.5 }],
    ['a negative build', { ...good, build: -1 }],
    ['a huge build', { ...good, build: 10_000_001 }],
    ['a string build', { ...good, build: '19' }],
  ])('refuses %s', (_name, body) => {
    expect(parseOpen(body, NOW)).toBeNull();
  });

  it('exports the install ID pattern the app and the rules share', () => {
    expect(INSTALL_ID_PATTERN).toBe('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  });
});

describe('dayIsOpenNow', () => {
  it('covers device-local days from UTC−12 to UTC+14', () => {
    expect(dayIsOpenNow('2026-10-17', NOW)).toBe(true);
    expect(dayIsOpenNow('2026-10-16', NOW)).toBe(true); // UTC−12 is still on the 16th until 12:00 UTC
    expect(dayIsOpenNow('2026-10-18', NOW)).toBe(true); // UTC+14 reaches the 18th at 10:00 UTC
    expect(dayIsOpenNow('2026-10-15', NOW)).toBe(false);
    expect(dayIsOpenNow('2026-10-19', NOW)).toBe(false);
  });
});

describe('recordGuestOpen', () => {
  afterEach(() => vi.unstubAllGlobals());

  const open = parseOpen(good, NOW)!;
  const name = guestDocName('p', open);

  it('creates the doc with opens 1 and both times set by the server', async () => {
    const fetchMock = vi.fn(async () => Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    await recordGuestOpen({ projectId: 'p', accessToken: 't', open });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const body = JSON.parse(String((fetchMock.mock.calls[0] as unknown as [string, RequestInit])[1].body));
    expect(body.writes).toEqual([
      {
        update: {
          name,
          fields: {
            installId: { stringValue: ID },
            platform: { stringValue: 'android' },
            appVersion: { stringValue: '1.1.0' },
            build: { integerValue: '19' },
            opens: { integerValue: '1' },
          },
        },
        updateTransforms: [
          { fieldPath: 'firstOpenAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
        ],
        currentDocument: { exists: false },
      },
    ]);
    expect(name).toBe('projects/p/databases/(default)/documents/daily_activity/2026-10-17/guests/' + ID);
  });

  it('increments opens and moves lastOpenAt when the doc already exists', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 }))
      .mockResolvedValueOnce(Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    await recordGuestOpen({ projectId: 'p', accessToken: 't', open });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const body = JSON.parse(String((fetchMock.mock.calls[1] as unknown as [string, RequestInit])[1].body));
    expect(body.writes).toEqual([
      {
        update: {
          name,
          fields: {
            platform: { stringValue: 'android' },
            appVersion: { stringValue: '1.1.0' },
            build: { integerValue: '19' },
          },
        },
        updateMask: { fieldPaths: ['platform', 'appVersion', 'build'] },
        updateTransforms: [
          { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'opens', increment: { integerValue: '1' } },
        ],
        currentDocument: { exists: true },
      },
    ]);
  });

  it('lets other failures through', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('no', { status: 403 })));
    await expect(recordGuestOpen({ projectId: 'p', accessToken: 't', open })).rejects.toThrow(
      /firestore_commit_failed:403/,
    );
  });
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd workers/activity && npx vitest run src/open.test.ts`
Expected: FAIL, cannot resolve `./open`.

- [ ] **Step 3: Implement**

`workers/activity/src/open.ts`:

```ts
import { commit, ContentionError, documentsBase, encodeFields, type CommitWrite } from './firestore';

export const PLATFORMS = ['ios', 'android', 'other'] as const;
export type Platform = (typeof PLATFORMS)[number];

/**
 * A lowercase UUID v4, as the app makes it. The same pattern is in
 * firestore/firestore.rules and lib/data/repositories/activity_install_id.dart;
 * test/firestore/activity_pins_test.dart keeps the three in step.
 */
export const INSTALL_ID_PATTERN = '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
const INSTALL_ID = new RegExp(INSTALL_ID_PATTERN);
const DAY_ID = /^\d{4}-\d{2}-\d{2}$/;
const APP_VERSION = /^[0-9A-Za-z.+-]{1,32}$/;
export const MAX_BUILD = 10_000_000;
const HOUR_MS = 60 * 60 * 1000;

export type GuestOpen = {
  installId: string;
  dayId: string;
  platform: Platform;
  appVersion: string;
  build: number;
};

function isRealDay(dayId: string): boolean {
  if (!DAY_ID.test(dayId)) return false;
  const ms = Date.parse(`${dayId}T00:00:00Z`);
  return !Number.isNaN(ms) && new Date(ms).toISOString().slice(0, 10) === dayId;
}

/**
 * Whether some device can be on [dayId] right now. Device clocks run from
 * UTC−12 to UTC+14, so a day is open from 14 h before its UTC midnight to
 * 36 h after (the leaderboard Worker's window).
 */
export function dayIsOpenNow(dayId: string, now: number): boolean {
  const midnight = Date.parse(`${dayId}T00:00:00Z`);
  return now >= midnight - 14 * HOUR_MS && now < midnight + 36 * HOUR_MS;
}

/** The open in [body], or null when any field is missing or out of bounds. */
export function parseOpen(body: unknown, now: number): GuestOpen | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const { installId, dayId, platform, appVersion, build } = body as Record<string, unknown>;
  if (typeof installId !== 'string' || !INSTALL_ID.test(installId)) return null;
  if (typeof dayId !== 'string' || !isRealDay(dayId) || !dayIsOpenNow(dayId, now)) return null;
  if (typeof platform !== 'string' || !(PLATFORMS as readonly string[]).includes(platform)) return null;
  if (typeof appVersion !== 'string' || !APP_VERSION.test(appVersion)) return null;
  if (typeof build !== 'number' || !Number.isInteger(build) || build < 0 || build > MAX_BUILD) return null;
  return { installId, dayId, platform: platform as Platform, appVersion, build };
}

export function guestDocName(projectId: string, open: GuestOpen): string {
  return `${documentsBase(projectId)}/daily_activity/${open.dayId}/guests/${open.installId}`;
}

function createWrite(name: string, open: GuestOpen): CommitWrite {
  return {
    update: {
      name,
      fields: encodeFields({
        installId: open.installId,
        platform: open.platform,
        appVersion: open.appVersion,
        build: open.build,
        opens: 1,
      }),
    },
    updateTransforms: [
      { fieldPath: 'firstOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  };
}

function incrementWrite(name: string, open: GuestOpen): CommitWrite {
  return {
    update: {
      name,
      fields: encodeFields({ platform: open.platform, appVersion: open.appVersion, build: open.build }),
    },
    updateMask: { fieldPaths: ['platform', 'appVersion', 'build'] },
    updateTransforms: [
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'opens', increment: { integerValue: '1' } },
    ],
    currentDocument: { exists: true },
  };
}

/** Creates the day's guest doc, or counts one more open on it when it exists. */
export async function recordGuestOpen(opts: {
  projectId: string;
  accessToken: string;
  open: GuestOpen;
}): Promise<void> {
  const name = guestDocName(opts.projectId, opts.open);
  try {
    await commit({ projectId: opts.projectId, accessToken: opts.accessToken, writes: [createWrite(name, opts.open)] });
  } catch (e) {
    if (!(e instanceof ContentionError)) throw e;
    await commit({ projectId: opts.projectId, accessToken: opts.accessToken, writes: [incrementWrite(name, opts.open)] });
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `cd workers/activity && npx vitest run src/open.test.ts`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add workers/activity/src/open.ts workers/activity/src/open.test.ts
git commit -m "feat(activity): check a guest open and write it"
```

---

### Task 4: Routing, body size and rate limits

**Files:**
- Create: `workers/activity/src/index.ts`
- Test: `workers/activity/src/index.test.ts`

- [ ] **Step 1: Write the failing test**

`workers/activity/src/index.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { MAX_BODY_BYTES, route, type Deps, type Env, type Limiter } from './index';

const NOW = Date.parse('2026-10-17T10:00:00Z');
const ID = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const good = { installId: ID, dayId: '2026-10-17', platform: 'ios', appVersion: '1.1.0', build: 19 };

function limiter(success = true): Limiter & { keys: string[] } {
  const keys: string[] = [];
  return {
    keys,
    limit: vi.fn(async ({ key }: { key: string }) => {
      keys.push(key);
      return { success };
    }),
  };
}

function env(patch: Partial<Env> = {}): Env {
  return {
    FIREBASE_PROJECT_ID: 'p',
    FIREBASE_SERVICE_ACCOUNT_JSON: '{}',
    IP_LIMIT: limiter(),
    INSTALL_LIMIT: limiter(),
    ...patch,
  };
}

const deps: Deps = { now: () => NOW, accessToken: async () => 'tok' };

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request('https://activity.example/v1/open', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '203.0.113.9', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('route', () => {
  it('answers the health check', async () => {
    const res = await route(new Request('https://activity.example/v1/health'), env(), deps);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
  });

  it('404s anything else', async () => {
    const res = await route(new Request('https://activity.example/v1/open'), env(), deps);
    expect(res.status).toBe(404);
  });

  it('records a good open and says ok', async () => {
    const fetchMock = vi.fn(async () => Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    const e = env();
    const res = await route(post(good), e, deps);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect((e.IP_LIMIT as ReturnType<typeof limiter>).keys).toEqual(['ip:203.0.113.9']);
    expect((e.INSTALL_LIMIT as ReturnType<typeof limiter>).keys).toEqual([`install:${ID}`]);
  });

  it('refuses a bad body with 400 and writes nothing', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    for (const body of ['not json', { ...good, platform: 'web' }]) {
      const res = await route(post(body), env(), deps);
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({ error: 'bad_request' });
    }
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('refuses a body over the size limit', async () => {
    const res = await route(post({ ...good, pad: 'x'.repeat(MAX_BODY_BYTES) }), env(), deps);
    expect(res.status).toBe(400);
  });

  it('429s when the IP is over its limit, before reading the body', async () => {
    const install = limiter();
    const res = await route(post(good), env({ IP_LIMIT: limiter(false), INSTALL_LIMIT: install }), deps);
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ error: 'rate_limited' });
    expect(install.keys).toEqual([]);
  });

  it('429s when the install is over its limit', async () => {
    const res = await route(post(good), env({ INSTALL_LIMIT: limiter(false) }), deps);
    expect(res.status).toBe(429);
  });

  it('still records when a limiter is missing or fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json({})));
    const broken: Limiter = { limit: async () => Promise.reject(new Error('down')) };
    const res = await route(post(good), env({ IP_LIMIT: undefined, INSTALL_LIMIT: broken }), deps);
    expect(res.status).toBe(200);
  });

  it('503s when Firestore or the token fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('down', { status: 500 })));
    expect((await route(post(good), env(), deps)).status).toBe(503);
    const noToken: Deps = { now: () => NOW, accessToken: async () => Promise.reject(new Error('bad sa')) };
    const res = await route(post(good), env(), noToken);
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: 'unavailable' });
  });
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd workers/activity && npx vitest run src/index.test.ts`
Expected: FAIL, cannot resolve `./index`.

- [ ] **Step 3: Implement**

`workers/activity/src/index.ts`:

```ts
import { getGoogleAccessToken, parseServiceAccountJson } from './google_auth';
import { parseOpen, recordGuestOpen } from './open';

/** The slice of a Workers Rate Limiting binding this Worker uses. */
export type Limiter = { limit(options: { key: string }): Promise<{ success: boolean }> };

export interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string;
  /** 30 / 60 s per client IP (wrangler.toml). */
  IP_LIMIT?: Limiter;
  /** 6 / 60 s per install ID. */
  INSTALL_LIMIT?: Limiter;
}

/** What the route needs from outside, injectable for tests. */
export type Deps = {
  now: () => number;
  accessToken: (env: Env) => Promise<string>;
};

const defaultDeps: Deps = {
  now: Date.now,
  accessToken: (env) => getGoogleAccessToken(parseServiceAccountJson(env.FIREBASE_SERVICE_ACCOUNT_JSON)),
};

/** An open is under 200 bytes; anything far bigger is refused unread. */
export const MAX_BODY_BYTES = 2 * 1024;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

/** A missing or failing limiter lets the open through: counting matters more than the brake. */
async function allowed(limiter: Limiter | undefined, key: string): Promise<boolean> {
  if (!limiter) return true;
  try {
    return (await limiter.limit({ key })).success;
  } catch (e) {
    console.error('rate_limit_failed', e instanceof Error ? e.message : e);
    return true;
  }
}

export async function route(request: Request, env: Env, deps: Deps = defaultDeps): Promise<Response> {
  const { pathname } = new URL(request.url);
  if (request.method === 'GET' && pathname === '/v1/health') return json({ ok: true });
  if (request.method !== 'POST' || pathname !== '/v1/open') return new Response('Not found', { status: 404 });

  const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
  if (!(await allowed(env.IP_LIMIT, `ip:${ip}`))) return json({ error: 'rate_limited' }, 429);

  const declared = Number(request.headers.get('Content-Length') ?? '0');
  if (declared > MAX_BODY_BYTES) return json({ error: 'bad_request' }, 400);
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: 'bad_request' }, 400);
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const open = parseOpen(body, deps.now());
  if (!open) return json({ error: 'bad_request' }, 400);

  if (!(await allowed(env.INSTALL_LIMIT, `install:${open.installId}`))) return json({ error: 'rate_limited' }, 429);

  try {
    const accessToken = await deps.accessToken(env);
    await recordGuestOpen({ projectId: env.FIREBASE_PROJECT_ID, accessToken, open });
  } catch (e) {
    console.error('guest_open_failed', e instanceof Error ? e.message : e);
    return json({ error: 'unavailable' }, 503);
  }
  return json({ ok: true });
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return route(request, env);
  },
} satisfies ExportedHandler<Env>;
```

- [ ] **Step 4: Run all Worker tests and the type check**

Run: `cd workers/activity && npx vitest run && npx tsc -p tsconfig.json`
Expected: every test passes; `tsc` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add workers/activity/src/index.ts workers/activity/src/index.test.ts
git commit -m "feat(activity): POST /v1/open with rate limits"
```
