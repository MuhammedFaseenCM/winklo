# Account Deletion Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `docs/delete-account/` with Google Sign-In and a Cloudflare Worker that verifies the Firebase ID token and immediately wipes that user’s Firestore data, R2 avatar, and Auth account for Play Data Safety.

**Architecture:** Static page on Cloudflare Pages + GitHub Pages calls `POST /v1/delete-account` with a Bearer Firebase ID token. New Worker `workers/account-deletion` verifies the JWT (avatar-upload pattern), uses a service account for Firestore/Auth Admin (admin-api `google_auth` pattern), deletes R2 `avatars/{uid}.jpg`, writes `deletion_requests/{id}` audit, returns `{ ok: true }`.

**Tech Stack:** Cloudflare Workers (TypeScript + Wrangler + Vitest + jose), Firestore REST, Identity Toolkit `accounts:delete`, R2 binding, Firebase Web SDK (CDN) on static HTML, existing Pages deploy for `docs/`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-10-09-account-deletion-page-design.md`
- Canonical Play URL: `https://winklo.pages.dev/delete-account/`
- Mirror: `https://muhammedfaseencm.github.io/winklo/delete-account/`
- CORS allowlist only those two origins (plus `http://localhost:8787` / `http://127.0.0.1:8787` for local Worker+page testing is OK in wrangler `[vars]` override, not production)
- Confirm body must be exactly `{ "confirm": "DELETE" }`
- No in-app Flutter delete button in this plan (optional `AppUrls` only if tiny; prefer skip)
- Commits only when the user asks (skip commit steps unless explicitly requested)
- Worker package mirrors `workers/avatar-upload` layout and deps

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `workers/account-deletion/package.json` | Worker package scripts + jose/vitest/wrangler |
| `workers/account-deletion/tsconfig.json` | TS config |
| `workers/account-deletion/wrangler.toml` | Worker name, R2 binding, `FIREBASE_PROJECT_ID` |
| `workers/account-deletion/src/firebase_auth.ts` | Verify Firebase ID token → `{ uid, email }` |
| `workers/account-deletion/src/google_auth.ts` | Parse SA JSON + OAuth access token (datastore + identitytoolkit) |
| `workers/account-deletion/src/cors.ts` | Origin allowlist + CORS headers |
| `workers/account-deletion/src/paths.ts` | Pure helpers: avatar key, game ids, path builders |
| `workers/account-deletion/src/firestore_wipe.ts` | Admin wipe of user-owned Firestore docs |
| `workers/account-deletion/src/auth_delete.ts` | Identity Toolkit delete user |
| `workers/account-deletion/src/audit.ts` | Write `deletion_requests` audit doc |
| `workers/account-deletion/src/delete_account.ts` | Orchestrate R2 → Firestore → Auth → audit |
| `workers/account-deletion/src/index.ts` | HTTP router `POST /v1/delete-account` |
| `workers/account-deletion/src/*.test.ts` | Unit tests |
| `docs/delete-account/index.html` | Sign-in + confirm UI |
| `docs/privacy/index.html` | Point deletion section at new page |
| `docs/index.html` | Footer “Delete account” link |
| `firestore/firestore.rules` | Deny all client access to `deletion_requests` |
| `play/data_safety.csv` | Both deletion URLs → Pages canonical |
| `play/app_content_answers.txt` | Same + copy update |
| `README.md` | Retire GitHub-only deletion limitation |
| `FIREBASE.md` | Document Worker + deletion page |

---

### Task 1: Worker scaffold + pure helpers (auth JWT, paths, CORS)

**Files:**
- Create: `workers/account-deletion/package.json`
- Create: `workers/account-deletion/tsconfig.json`
- Create: `workers/account-deletion/wrangler.toml`
- Create: `workers/account-deletion/src/firebase_auth.ts`
- Create: `workers/account-deletion/src/google_auth.ts`
- Create: `workers/account-deletion/src/cors.ts`
- Create: `workers/account-deletion/src/paths.ts`
- Test: `workers/account-deletion/src/paths.test.ts`
- Test: `workers/account-deletion/src/cors.test.ts`

**Interfaces:**
- Produces:

```ts
// firebase_auth.ts
export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<{ uid: string; email: string | null }>;

// google_auth.ts
export type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
};
export function parseServiceAccountJson(raw: string): ServiceAccount;
export async function getGoogleAccessToken(
  sa: ServiceAccount,
  scopes?: string[],
): Promise<string>;
// Default scopes: datastore + identitytoolkit only

// cors.ts
export const ALLOWED_ORIGINS: readonly string[];
export function corsHeadersFor(origin: string | null): Record<string, string>;
export function isOriginAllowed(origin: string | null): boolean;

// paths.ts
export const LEADERBOARD_GAMES: readonly ['zip', 'path_words', 'sudoku'];
export function avatarObjectKey(uid: string): string; // avatars/{uid}.jpg
export function userDocPath(projectId: string, uid: string): string;
```

- [ ] **Step 1: Create package files**

`workers/account-deletion/package.json`:

```json
{
  "name": "winklo-account-deletion",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250901.0",
    "typescript": "^5.6.0",
    "vitest": "^3.0.0",
    "wrangler": "^4.0.0"
  },
  "dependencies": {
    "jose": "^5.9.0"
  }
}
```

`wrangler.toml`:

```toml
name = "winklo-account-deletion"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[[r2_buckets]]
binding = "AVATARS"
bucket_name = "winklo-avatars"

[vars]
FIREBASE_PROJECT_ID = "brain-zip-app"
```

`tsconfig.json` — copy from `workers/avatar-upload/tsconfig.json`.

- [ ] **Step 2: Write failing paths/cors tests**

```ts
// src/paths.test.ts
import { describe, expect, it } from 'vitest';
import { avatarObjectKey, LEADERBOARD_GAMES } from './paths';

describe('paths', () => {
  it('avatar key', () => {
    expect(avatarObjectKey('abc')).toBe('avatars/abc.jpg');
  });
  it('games', () => {
    expect([...LEADERBOARD_GAMES]).toEqual(['zip', 'path_words', 'sudoku']);
  });
});
```

```ts
// src/cors.test.ts
import { describe, expect, it } from 'vitest';
import { corsHeadersFor, isOriginAllowed } from './cors';

describe('cors', () => {
  it('allows Pages + github.io', () => {
    expect(isOriginAllowed('https://winklo.pages.dev')).toBe(true);
    expect(isOriginAllowed('https://muhammedfaseencm.github.io')).toBe(true);
    expect(isOriginAllowed('https://evil.example')).toBe(false);
  });
  it('echoes allowed origin', () => {
    const h = corsHeadersFor('https://winklo.pages.dev');
    expect(h['Access-Control-Allow-Origin']).toBe('https://winklo.pages.dev');
  });
});
```

- [ ] **Step 3: Run tests — expect FAIL (modules missing)**

Run: `cd workers/account-deletion && npm install && npm test`  
Expected: FAIL cannot find modules / exports

- [ ] **Step 4: Implement helpers**

`firebase_auth.ts` — same JWKS verify as avatar-upload; also return `email` from `payload.email` if string else `null`.

`google_auth.ts` — copy from winklo-admin `workers/admin-api/src/google_auth.ts` but default scopes only:

```ts
const DEFAULT_SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/identitytoolkit',
];
```

`cors.ts`:

```ts
export const ALLOWED_ORIGINS = [
  'https://winklo.pages.dev',
  'https://muhammedfaseencm.github.io',
] as const;

export function isOriginAllowed(origin: string | null): boolean {
  return !!origin && (ALLOWED_ORIGINS as readonly string[]).includes(origin);
}

export function corsHeadersFor(origin: string | null): Record<string, string> {
  const allow = isOriginAllowed(origin) ? origin! : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    Vary: 'Origin',
  };
}
```

`paths.ts`:

```ts
export const LEADERBOARD_GAMES = ['zip', 'path_words', 'sudoku'] as const;

export function avatarObjectKey(uid: string): string {
  return `avatars/${uid}.jpg`;
}

export function userDocPath(projectId: string, uid: string): string {
  return `projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
}
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `cd workers/account-deletion && npm test`  
Expected: PASS

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add workers/account-deletion
git commit -m "feat: scaffold account-deletion Worker helpers"
```

---

### Task 2: Firestore wipe + Auth delete + audit modules

**Files:**
- Create: `workers/account-deletion/src/firestore_wipe.ts`
- Create: `workers/account-deletion/src/auth_delete.ts`
- Create: `workers/account-deletion/src/audit.ts`
- Test: `workers/account-deletion/src/firestore_wipe.test.ts`

**Interfaces:**
- Consumes: `LEADERBOARD_GAMES`, `userDocPath` from `paths.ts`
- Produces:

```ts
export type WipeResult = { ok: boolean; errorMessage?: string };

export async function wipeUserFirestore(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<WipeResult>;

export async function deleteAuthUser(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<void>; // 404 = success

export async function writeDeletionAudit(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
  email: string | null;
  requestedAt: string; // ISO
  completedAt: string;
  status: 'completed' | 'partial' | 'failed';
  steps: { firestore: boolean; r2: boolean; auth: boolean };
  errorMessage: string | null;
}): Promise<void>;
```

- [ ] **Step 1: Write failing unit tests for path/query helpers exported from wipe**

Export pure builders from `firestore_wipe.ts` for testability:

```ts
export function allTimeLeaderboardPath(
  projectId: string,
  root: 'leaderboards' | 'leaderboards_debug',
  game: string,
  uid: string,
): string;

export function dailyEntryPath(
  projectId: string,
  root: 'leaderboards' | 'leaderboards_debug',
  game: string,
  dayId: string,
  uid: string,
): string;
```

```ts
// firestore_wipe.test.ts
import { describe, expect, it } from 'vitest';
import { allTimeLeaderboardPath, dailyEntryPath } from './firestore_wipe';

describe('firestore paths', () => {
  it('all_time', () => {
    expect(allTimeLeaderboardPath('p', 'leaderboards', 'zip', 'u1')).toContain(
      '/leaderboards/zip/all_time/u1',
    );
  });
  it('daily entry', () => {
    expect(
      dailyEntryPath('p', 'leaderboards_debug', 'sudoku', '2026-10-09', 'u1'),
    ).toContain('/leaderboards_debug/sudoku/daily/2026-10-09/entries/u1');
  });
});
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `cd workers/account-deletion && npm test`  
Expected: FAIL missing exports

- [ ] **Step 3: Implement wipe / auth / audit**

`firestore_wipe.ts` algorithm (Admin REST, `Authorization: Bearer ${accessToken}`):

1. For each subcollection name in `game_days`, `game_days_debug`, `game_streaks`, `game_streaks_debug`:
   - `GET .../documents/users/{uid}/{sub}?pageSize=300` (paginate with `nextPageToken`)
   - `DELETE` each document name returned
2. `DELETE` `users/{uid}` (ignore 404)
3. For each root in `leaderboards`, `leaderboards_debug` and each game in `LEADERBOARD_GAMES`:
   - `DELETE` all_time doc (ignore 404)
   - `GET .../{root}/{game}/daily?pageSize=300` list day docs; for each dayId `DELETE .../daily/{dayId}/entries/{uid}` (ignore 404)
4. Run structured query for `issue_reports` where `uid ==` requester; delete each match
5. Best-effort `daily_activity`: list top-level docs under `daily_activity` (paginate, max 60 pages × 100); for each dayId `DELETE daily_activity/{dayId}/users/{uid}` (ignore 404). If listing throws, set wipe `ok: false` with message `daily_activity_partial` but still continue other steps already done — overall WipeResult `ok` false only if a **required** step fails (user doc / leaderboards / issue_reports). Treat daily_activity failure as soft: record in `errorMessage` but `ok: true` if required steps succeeded (caller marks `partial` via orchestration — see Task 3).

Simpler contract for v1: `wipeUserFirestore` returns `{ ok, errorMessage?, softWarnings?: string[] }`. Soft warnings for daily_activity only.

`auth_delete.ts` — same as admin-api `deleteAuthUser` (POST Identity Toolkit `accounts:delete`, 404 OK).

`audit.ts` — `POST https://firestore.googleapis.com/v1/projects/{id}/databases/(default)/documents/deletion_requests` with fields map (string/timestamp/boolean/mapValue). Use server timestamps as ISO `timestampValue` strings from caller.

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd workers/account-deletion && npm test`  
Expected: PASS

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add workers/account-deletion/src
git commit -m "feat: account-deletion Firestore wipe and Auth delete"
```

---

### Task 3: Orchestrator + HTTP handler

**Files:**
- Create: `workers/account-deletion/src/delete_account.ts`
- Create: `workers/account-deletion/src/index.ts`
- Test: `workers/account-deletion/src/delete_account.test.ts`
- Test: `workers/account-deletion/src/index.test.ts` (optional: test confirm parsing / CORS OPTIONS via exported helpers)

**Interfaces:**
- Consumes: wipe, auth delete, audit, verifyFirebaseIdToken, parseServiceAccountJson, getGoogleAccessToken, avatarObjectKey, corsHeadersFor
- Produces:

```ts
export interface Env {
  AVATARS: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string; // secret
}

export async function runDeleteAccount(opts: {
  env: Env;
  uid: string;
  email: string | null;
}): Promise<{ httpStatus: number; body: { ok?: true; error?: string } }>;
```

- [ ] **Step 1: Write failing orchestrator test with mocks**

```ts
import { describe, expect, it, vi } from 'vitest';

// Prefer testing a pure `summarizeStatus(steps)` helper:
import { summarizeStatus } from './delete_account';

describe('summarizeStatus', () => {
  it('completed when all true', () => {
    expect(
      summarizeStatus({ firestore: true, r2: true, auth: true }),
    ).toBe('completed');
  });
  it('failed when firestore and auth false', () => {
    expect(
      summarizeStatus({ firestore: false, r2: true, auth: false }),
    ).toBe('failed');
  });
  it('partial when some true some false', () => {
    expect(
      summarizeStatus({ firestore: true, r2: false, auth: true }),
    ).toBe('partial');
  });
});
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement `delete_account.ts` + `index.ts`**

Orchestration order (match spec):

1. `requestedAt = new Date().toISOString()`
2. R2: `await env.AVATARS.delete(avatarObjectKey(uid))` — catch → `steps.r2 = false`
3. Parse SA + access token
4. Firestore wipe → `steps.firestore`
5. Auth delete → `steps.auth` (404 OK)
6. `status = summarizeStatus(steps)`; if softWarnings length > 0 and status === `completed`, downgrade to `partial`
7. Write audit (best-effort; log failure but still return based on wipe)
8. If `status === 'failed'` return 500 `{ error: 'delete_failed' }`; else 200 `{ ok: true }`

`index.ts`:

```ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const cors = corsHeadersFor(origin);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    if (request.method === 'GET' && new URL(request.url).pathname === '/v1/health') {
      return Response.json({ ok: true }, { headers: cors });
    }

    if (request.method !== 'POST' || new URL(request.url).pathname !== '/v1/delete-account') {
      return new Response('Not found', { status: 404, headers: cors });
    }

    if (origin && !isOriginAllowed(origin)) {
      return Response.json({ error: 'origin_not_allowed' }, { status: 403, headers: cors });
    }

    const token = parseBearer(request);
    if (!token) return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });

    let uid: string;
    let email: string | null;
    try {
      ({ uid, email } = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID));
    } catch {
      return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
    }

    let body: { confirm?: string };
    try {
      body = (await request.json()) as { confirm?: string };
    } catch {
      return Response.json({ error: 'invalid_json' }, { status: 400, headers: cors });
    }
    if (body.confirm !== 'DELETE') {
      return Response.json({ error: 'confirm_required' }, { status: 400, headers: cors });
    }

    if (!env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim()) {
      return Response.json({ error: 'misconfigured' }, { status: 500, headers: cors });
    }

    const result = await runDeleteAccount({ env, uid, email });
    return Response.json(result.body, { status: result.httpStatus, headers: cors });
  },
};
```

Rate limit (simple): module-level `Map<string, number>` of uid → last attempt ms; if last < 10_000 ms ago and previous was error, return 429. Skip if overengineering — optional 10-line guard is enough.

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd workers/account-deletion && npm test`

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add workers/account-deletion
git commit -m "feat: account-deletion Worker HTTP API"
```

---

### Task 4: Firestore rules for `deletion_requests`

**Files:**
- Modify: `firestore/firestore.rules` (add match block near other collections)
- Modify: `FIREBASE.md` (short note under Data Safety / privacy)

- [ ] **Step 1: Add rules**

```
match /deletion_requests/{id} {
  allow read, write: if false;
}
```

Place after `issue_reports` block.

- [ ] **Step 2: Deploy rules**

Run: `firebase deploy --only firestore:rules`  
Expected: Deploy complete

- [ ] **Step 3: Document in FIREBASE.md** — one subsection: Worker-only audit collection; clients denied.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add firestore/firestore.rules FIREBASE.md
git commit -m "chore: deny client access to deletion_requests"
```

---

### Task 5: Static deletion page

**Files:**
- Create: `docs/delete-account/index.html`

**Prereq (operator, before smoke):** Firebase Console → register **Web** app if none exists → copy `firebaseConfig`. Auth → Authorized domains: add `winklo.pages.dev` and `muhammedfaseencm.github.io`. Enable Google sign-in provider (already on for the Android app).

- [ ] **Step 1: Create page**

Self-contained HTML matching privacy tokens (`--ink`, `--on-ink`, `--muted`, `--ember`, `--wall`).

Structure:

1. Brand + h1 “Delete your Winklo account”
2. Paragraphs: immediate irreversible delete of profile, progress, leaderboard rows, issue reports, custom avatar, Auth account; Analytics/Crashlytics history may remain with Google
3. `#signed-out` panel: button “Continue with Google”
4. `#signed-in` panel (hidden): show email + uid; checkbox; text input placeholder `Type DELETE`; button “Delete my account” disabled until checkbox + input === `DELETE`
5. `#done` / `#error` panels
6. Link to `../privacy/`

Scripts (Firebase modular CDN v10+):

```html
<script type="module">
  import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
  import {
    getAuth,
    GoogleAuthProvider,
    signInWithPopup,
  } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';

  const FIREBASE_CONFIG = {
    apiKey: 'AIzaSyCINzqIpBqip2LbWDg0u-NhkCw0O138phQ',
    authDomain: 'brain-zip-app.firebaseapp.com',
    projectId: 'brain-zip-app',
    storageBucket: 'brain-zip-app.firebasestorage.app',
    messagingSenderId: '43073222004',
    appId: 'REPLACE_WITH_WEB_APP_ID', // from Firebase Console Web app
  };

  const WORKER_BASE =
    'https://winklo-account-deletion.<your-subdomain>.workers.dev';
  // After first deploy, set to the real Worker URL (or custom route).
```

Wire:

- Sign-in → store `user`, show signed-in panel
- Delete click → `const idToken = await user.getIdToken()` → `POST ${WORKER_BASE}/v1/delete-account` with headers `Authorization: Bearer …`, `Content-Type: application/json`, body `{"confirm":"DELETE"}` → on 200 show done; else show error text from JSON `error` or status

Do **not** commit a fake Worker URL forever: use a clearly named constant at top of the script; README/FIREBASE.md document the production Worker URL after deploy. Prefer setting:

```js
const WORKER_BASE = 'https://winklo-account-deletion.faseencm.workers.dev';
```

only after `wrangler deploy` prints the URL (update in same PR as deploy notes).

- [ ] **Step 2: Local visual check**

Run: `cd docs && python3 -m http.server 8765`  
Open `/delete-account/` — layout matches privacy; buttons present (Sign-In will fail until authorized domain / real host).

- [ ] **Step 3: Commit** (only if user asked)

```bash
git add docs/delete-account/index.html
git commit -m "feat: add account deletion landing page"
```

---

### Task 6: Privacy, Play, landing, README

**Files:**
- Modify: `docs/privacy/index.html` (account deletion section)
- Modify: `docs/index.html` (footer)
- Modify: `play/data_safety.csv` (lines for `PSL_ACCOUNT_DELETION_URL` and `PSL_DATA_DELETION_URL`)
- Modify: `play/app_content_answers.txt`
- Modify: `README.md` (limitation #5)

- [ ] **Step 1: Privacy copy**

Replace the GitHub-issue / 30-day primary path with:

- Primary: link to `https://winklo.pages.dev/delete-account/` (and relative `../delete-account/` for mirror)
- Text: Sign in with the same Google account and confirm; deletion is immediate
- Secondary: If the page fails, open a GitHub issue

Update “Last updated” date to ship day.

- [ ] **Step 2: Landing footer**

Next to Privacy policy:

```html
<a href="delete-account/">Delete account</a>
```

- [ ] **Step 3: Play files**

Both CSV URL cells:

`https://winklo.pages.dev/delete-account/`

`app_content_answers.txt`:

- Privacy policy URL can stay Pages privacy **or** remain github privacy — out of scope; **deletion** URLs are the new page
- Note: Account/data deletion via web page with Google Sign-In; immediate wipe

- [ ] **Step 4: README**

Change limitation #5 to note web deletion page exists; optional follow-up: in-app Profile button still open.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add docs/privacy/index.html docs/index.html play/data_safety.csv play/app_content_answers.txt README.md
git commit -m "docs: point Play and privacy at account deletion page"
```

---

### Task 7: Deploy + smoke + Play re-check

**Files:** none required beyond prior tasks (ops)

- [ ] **Step 1: Set Worker secret**

```bash
cd workers/account-deletion
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
# paste same SA JSON used by winklo-admin admin-api (needs Datastore + Identity Toolkit)
```

- [ ] **Step 2: Deploy Worker**

```bash
cd workers/account-deletion && npm run deploy
```

Expected: success URL printed. Paste that URL into `docs/delete-account/index.html` `WORKER_BASE` if not already correct; redeploy docs if needed.

- [ ] **Step 3: Push docs / trigger Pages**

Push `docs/**` to `master` so Cloudflare Pages + GitHub Pages update.

- [ ] **Step 4: Firebase authorized domains**

Console → Authentication → Settings → Authorized domains → ensure `winklo.pages.dev` and `muhammedfaseencm.github.io`.

- [ ] **Step 5: Smoke test (throwaway Google account)**

1. Create/sign in test user in the Android app once (so `users/{uid}` exists) **or** sign in only on the web page
2. Open `https://winklo.pages.dev/delete-account/`
3. Continue with Google → type DELETE → delete
4. Confirm: Firebase Auth user gone; `users/{uid}` gone; R2 object gone if any
5. Repeat Sign-In check on github.io mirror (page loads; Sign-In works)

- [ ] **Step 6: curl checks**

```bash
curl -sI "https://winklo.pages.dev/delete-account/" | head -5
curl -sI "https://muhammedfaseencm.github.io/winklo/delete-account/" | head -5
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<worker>/v1/delete-account" \
  -H "Content-Type: application/json" \
  -d '{"confirm":"DELETE"}'
```

Expected: pages **200**; bare POST without token **401**.

- [ ] **Step 7: Play Console**

App content → Data safety → set both deletion URLs to `https://winklo.pages.dev/delete-account/` → Save → Publishing overview → Send for review.

---

## Spec coverage (self-review)

| Spec requirement | Task |
| --- | --- |
| Dedicated page both hosts | 5, 7 |
| Google Sign-In + confirm DELETE | 5 |
| Worker JWT verify | 1, 3 |
| R2 + Firestore + Auth wipe | 2, 3 |
| Audit `deletion_requests` | 2, 3, 4 |
| CORS allowlist | 1, 3 |
| Privacy + Play CSV updates | 6 |
| README limitation | 6 |
| Ops / authorized domains | 7 |
| No admin UI / no in-app button | Explicit non-goals — no tasks |

## Placeholder scan

No TBD/TODO left; `REPLACE_WITH_WEB_APP_ID` and Worker URL are explicit operator fill-ins in Task 5/7 (required Firebase Web app id is not in repo today — only Android `firebase_options`).
