# Admin Panel Foundation Implementation Plan

> **Note (2026-09-26):** Admin SPA, Worker, and claim tooling were extracted to a **separate repo**: [MuhammedFaseenCM/winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin). This plan remains as historical implementation notes for the player app (`isAdmin()` rules + FIREBASE.md). New admin work happens in `winklo-admin`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Winklo admin foundation — Vite+React SPA on Cloudflare Pages, Firebase Auth with `admin` custom claims, Firestore `isAdmin()` helper, claim-grant script, and `workers/admin-api` with `GET /v1/me`.

**Architecture:** Hybrid shell. The SPA signs in with Google, gates on `claims.admin === true`, and calls a Cloudflare Worker that verifies the Firebase JWT + admin claim. Privileged Firebase Admin ops stay out of the Worker for now; claim changes use a Node script with `firebase-admin`. Module pages (reports, announcements, ops, platform) are stubs only.

**Tech Stack:** Vite, React, TypeScript, React Router, Firebase JS SDK (`firebase`), Cloudflare Workers (TypeScript + Wrangler + `jose` + Vitest), Firebase Admin SDK in `tools/`, Firestore rules.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-26-admin-panel-foundation-design.md`
- Claim shape exactly `{ admin: true }` (boolean); no roles matrix
- Do **not** open `issue_reports` (or any other collection) to admin reads in this phase
- No Flutter / `lib/` changes
- Worker: no service-account secret, no FCM, no Remote Config writes
- SPA: no automated test suite; Worker has Vitest coverage for auth/`/v1/me`
- Commits only when the user asks (skip commit steps unless explicitly requested)
- Reuse JWKS verify pattern from `workers/avatar-upload/src/firebase_auth.ts`
- Firebase project id for Workers vars: `brain-zip-app` (same as avatar Worker)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `firestore/firestore.rules` | Add `isAdmin()` helper only |
| `workers/admin-api/` | New Worker: `verifyAdmin`, `GET /v1/me`, CORS allowlist |
| `tools/set-admin-claim.mjs` | Grant/revoke `admin` custom claim |
| `admin/` | Vite + React SPA (auth gate, shell, stubs) |
| `admin/README.md` | Local run, env, deploy, claim flow |
| `FIREBASE.md` | Document claims + `isAdmin()` + phase-2 note |
| `docs/superpowers/specs/2026-09-26-admin-panel-foundation-design.md` | Status → approved; plan ready |

---

### Task 1: Firestore `isAdmin()` helper + design status

**Files:**
- Modify: `firestore/firestore.rules`
- Modify: `docs/superpowers/specs/2026-09-26-admin-panel-foundation-design.md` (status line only)
- Modify: `FIREBASE.md` (short section; full docs polish can finish in Task 7)

**Interfaces:**
- Produces: rules function `isAdmin()` usable by later phases; **no new `allow` paths**

- [ ] **Step 1: Add `isAdmin()` after `isOwner`**

In `firestore/firestore.rules`, immediately after `isOwner`:

```
    function isAdmin() {
      return isSignedIn() && request.auth.token.admin == true;
    }
```

Do not change any `match` blocks (especially leave `issue_reports` as create-only / no read).

- [ ] **Step 2: Update design status**

Change the spec header status to:

```
Status: approved; plan ready
```

- [ ] **Step 3: Smoke-check rules still parse**

Run: `firebase deploy --only firestore:rules --dry-run`  
(If Firebase CLI is unavailable, open the file and confirm braces/functions still balance; deploy later with other Firebase work.)

Expected: dry-run succeeds, or file is syntactically valid.

---

### Task 2: Admin API Worker — `verifyAdmin` (TDD)

**Files:**
- Create: `workers/admin-api/package.json`
- Create: `workers/admin-api/tsconfig.json`
- Create: `workers/admin-api/vitest.config.ts`
- Create: `workers/admin-api/wrangler.toml`
- Create: `workers/admin-api/src/firebase_auth.ts`
- Create: `workers/admin-api/src/admin_auth.ts`
- Create: `workers/admin-api/src/admin_auth.test.ts`

**Interfaces:**
- Produces:

```ts
// workers/admin-api/src/firebase_auth.ts
export type FirebaseIdTokenPayload = {
  uid: string;
  email?: string;
  admin: boolean;
};

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<FirebaseIdTokenPayload>;

// workers/admin-api/src/admin_auth.ts
export class AdminAuthError extends Error {
  constructor(
    readonly status: 401 | 403,
    message: string,
  );
}

export async function verifyAdmin(
  request: Request,
  projectId: string,
): Promise<FirebaseIdTokenPayload>;
```

- [ ] **Step 1: Scaffold package files**

`workers/admin-api/package.json`:

```json
{
  "name": "winklo-admin-api",
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

`workers/admin-api/wrangler.toml`:

```toml
name = "winklo-admin-api"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[vars]
FIREBASE_PROJECT_ID = "brain-zip-app"
# Comma-separated; override per env as needed
ALLOWED_ORIGINS = "http://localhost:5173"
```

`workers/admin-api/tsconfig.json` — mirror `workers/avatar-upload/tsconfig.json`.

`workers/admin-api/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
  },
});
```

- [ ] **Step 2: Write failing `verifyAdmin` tests**

```ts
// workers/admin-api/src/admin_auth.test.ts
import { describe, expect, it, vi } from 'vitest';

vi.mock('./firebase_auth', () => ({
  verifyFirebaseIdToken: vi.fn(),
}));

import { verifyFirebaseIdToken } from './firebase_auth';
import { AdminAuthError, verifyAdmin } from './admin_auth';

describe('verifyAdmin', () => {
  it('throws 401 when Authorization header is missing', async () => {
    const req = new Request('https://example.com/v1/me');
    await expect(verifyAdmin(req, 'brain-zip-app')).rejects.toMatchObject({
      status: 401,
    });
  });

  it('throws 401 when token verification fails', async () => {
    vi.mocked(verifyFirebaseIdToken).mockRejectedValueOnce(new Error('bad'));
    const req = new Request('https://example.com/v1/me', {
      headers: { Authorization: 'Bearer bad-token' },
    });
    await expect(verifyAdmin(req, 'brain-zip-app')).rejects.toMatchObject({
      status: 401,
    });
  });

  it('throws 403 when token is valid but admin claim is false', async () => {
    vi.mocked(verifyFirebaseIdToken).mockResolvedValueOnce({
      uid: 'u1',
      email: 'a@b.com',
      admin: false,
    });
    const req = new Request('https://example.com/v1/me', {
      headers: { Authorization: 'Bearer good' },
    });
    await expect(verifyAdmin(req, 'brain-zip-app')).rejects.toMatchObject({
      status: 403,
    });
  });

  it('returns payload when admin claim is true', async () => {
    vi.mocked(verifyFirebaseIdToken).mockResolvedValueOnce({
      uid: 'u1',
      email: 'a@b.com',
      admin: true,
    });
    const req = new Request('https://example.com/v1/me', {
      headers: { Authorization: 'Bearer good' },
    });
    await expect(verifyAdmin(req, 'brain-zip-app')).resolves.toEqual({
      uid: 'u1',
      email: 'a@b.com',
      admin: true,
    });
  });
});
```

- [ ] **Step 3: Run tests — expect fail**

Run:

```bash
cd workers/admin-api && npm install && npm test
```

Expected: FAIL — modules missing

- [ ] **Step 4: Implement `firebase_auth.ts` and `admin_auth.ts`**

```ts
// workers/admin-api/src/firebase_auth.ts
import { createRemoteJWKSet, jwtVerify } from 'jose';

const JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

export type FirebaseIdTokenPayload = {
  uid: string;
  email?: string;
  admin: boolean;
};

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<FirebaseIdTokenPayload> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  const uid = payload.sub;
  if (!uid) throw new Error('missing sub');
  return {
    uid,
    email: typeof payload.email === 'string' ? payload.email : undefined,
    admin: payload.admin === true,
  };
}
```

```ts
// workers/admin-api/src/admin_auth.ts
import { verifyFirebaseIdToken, type FirebaseIdTokenPayload } from './firebase_auth';

export class AdminAuthError extends Error {
  constructor(
    readonly status: 401 | 403,
    message: string,
  ) {
    super(message);
    this.name = 'AdminAuthError';
  }
}

function parseBearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
}

export async function verifyAdmin(
  request: Request,
  projectId: string,
): Promise<FirebaseIdTokenPayload> {
  const token = parseBearerToken(request);
  if (!token) {
    throw new AdminAuthError(401, 'unauthorized');
  }
  let payload: FirebaseIdTokenPayload;
  try {
    payload = await verifyFirebaseIdToken(token, projectId);
  } catch {
    throw new AdminAuthError(401, 'unauthorized');
  }
  if (!payload.admin) {
    throw new AdminAuthError(403, 'forbidden');
  }
  return payload;
}
```

- [ ] **Step 5: Run tests — expect pass**

Run: `cd workers/admin-api && npm test`  
Expected: PASS (4 tests)

---

### Task 3: Admin API Worker — `GET /v1/me` + CORS

**Files:**
- Create: `workers/admin-api/src/cors.ts`
- Create: `workers/admin-api/src/index.ts`
- Create: `workers/admin-api/src/index.test.ts`
- Modify: `workers/admin-api/src/admin_auth.test.ts` only if needed

**Interfaces:**
- Consumes: `verifyAdmin`, `AdminAuthError`
- Produces: Worker fetch handler

```ts
export interface Env {
  FIREBASE_PROJECT_ID: string;
  ALLOWED_ORIGINS: string; // comma-separated
}

// GET /v1/me → 200 { uid, email?, admin: true }
```

- [ ] **Step 1: Write CORS + route tests**

```ts
// workers/admin-api/src/index.test.ts
import { describe, expect, it, vi, beforeEach } from 'vitest';

vi.mock('./admin_auth', () => ({
  AdminAuthError: class AdminAuthError extends Error {
    constructor(
      readonly status: 401 | 403,
      message: string,
    ) {
      super(message);
    }
  },
  verifyAdmin: vi.fn(),
}));

import { AdminAuthError, verifyAdmin } from './admin_auth';
import worker from './index';

const env = {
  FIREBASE_PROJECT_ID: 'brain-zip-app',
  ALLOWED_ORIGINS: 'http://localhost:5173',
};

describe('admin-api fetch', () => {
  beforeEach(() => {
    vi.mocked(verifyAdmin).mockReset();
  });

  it('answers OPTIONS with CORS for allowed origin', async () => {
    const res = await worker.fetch(
      new Request('https://api.example/v1/me', {
        method: 'OPTIONS',
        headers: { Origin: 'http://localhost:5173' },
      }),
      env,
    );
    expect(res.status).toBe(204);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe(
      'http://localhost:5173',
    );
  });

  it('returns 401 JSON when verifyAdmin throws 401', async () => {
    vi.mocked(verifyAdmin).mockRejectedValueOnce(
      new AdminAuthError(401, 'unauthorized'),
    );
    const res = await worker.fetch(
      new Request('https://api.example/v1/me', {
        headers: { Origin: 'http://localhost:5173' },
      }),
      env,
    );
    expect(res.status).toBe(401);
  });

  it('returns 403 when verifyAdmin throws 403', async () => {
    vi.mocked(verifyAdmin).mockRejectedValueOnce(
      new AdminAuthError(403, 'forbidden'),
    );
    const res = await worker.fetch(
      new Request('https://api.example/v1/me'),
      env,
    );
    expect(res.status).toBe(403);
  });

  it('returns me payload for admin', async () => {
    vi.mocked(verifyAdmin).mockResolvedValueOnce({
      uid: 'u1',
      email: 'a@b.com',
      admin: true,
    });
    const res = await worker.fetch(
      new Request('https://api.example/v1/me', {
        headers: { Origin: 'http://localhost:5173' },
      }),
      env,
    );
    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({
      uid: 'u1',
      email: 'a@b.com',
      admin: true,
    });
  });
});
```

- [ ] **Step 2: Run tests — expect fail**

Run: `cd workers/admin-api && npm test`  
Expected: FAIL — `./index` missing

- [ ] **Step 3: Implement CORS + handler**

```ts
// workers/admin-api/src/cors.ts
export function parseAllowedOrigins(raw: string | undefined): Set<string> {
  return new Set(
    (raw ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

export function corsHeadersFor(
  request: Request,
  allowed: Set<string>,
): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (!origin || !allowed.has(origin)) {
    return {
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    };
  }
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    Vary: 'Origin',
  };
}
```

```ts
// workers/admin-api/src/index.ts
import { AdminAuthError, verifyAdmin } from './admin_auth';
import { corsHeadersFor, parseAllowedOrigins } from './cors';

export interface Env {
  FIREBASE_PROJECT_ID: string;
  ALLOWED_ORIGINS: string;
}

function jsonResponse(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return Response.json(body, { status, headers: cors });
}

const worker = {
  async fetch(request: Request, env: Env): Promise<Response> {
    const allowed = parseAllowedOrigins(env.ALLOWED_ORIGINS);
    const cors = corsHeadersFor(request, allowed);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/v1/me') {
      try {
        const me = await verifyAdmin(request, env.FIREBASE_PROJECT_ID);
        return jsonResponse(
          { uid: me.uid, email: me.email, admin: true as const },
          200,
          cors,
        );
      } catch (err) {
        if (err instanceof AdminAuthError) {
          return jsonResponse({ error: err.message }, err.status, cors);
        }
        return jsonResponse({ error: 'unauthorized' }, 401, cors);
      }
    }

    return jsonResponse({ error: 'not_found' }, 404, cors);
  },
};

export default worker;
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd workers/admin-api && npm test`  
Expected: PASS (all Task 2 + Task 3 tests)

---

### Task 4: `tools/set-admin-claim.mjs`

**Files:**
- Create: `tools/set-admin-claim.mjs`

**Interfaces:**
- CLI: `--email <addr> | --uid <uid>` and `--admin true|false`
- Credentials: same as seed script (`GOOGLE_APPLICATION_CREDENTIALS` or `play/play-service-account.json`)

- [ ] **Step 1: Implement the script**

```js
#!/usr/bin/env node
/**
 * Grant or revoke the Firebase Auth custom claim `{ admin: true }`.
 *
 * Usage (from repo root):
 *   node tools/set-admin-claim.mjs --email you@example.com --admin true
 *   node tools/set-admin-claim.mjs --email you@example.com --admin false
 *   node tools/set-admin-claim.mjs --uid <uid> --admin true
 *
 * Credentials: GOOGLE_APPLICATION_CREDENTIALS, or play/play-service-account.json
 * After changing claims, the operator must refresh their ID token (sign out/in).
 */

import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');
const require = createRequire(import.meta.url);

function parseArgs(argv) {
  const out = { email: null, uid: null, admin: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--email') out.email = argv[++i];
    else if (a === '--uid') out.uid = argv[++i];
    else if (a === '--admin') out.admin = argv[++i];
  }
  return out;
}

function parseAdminFlag(raw) {
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  throw new Error('--admin must be true or false');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if ((!args.email && !args.uid) || (args.email && args.uid)) {
    throw new Error('Provide exactly one of --email or --uid');
  }
  if (args.admin == null) {
    throw new Error('Provide --admin true|false');
  }
  const adminValue = parseAdminFlag(args.admin);

  const admin = (await import('firebase-admin')).default;
  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    resolve(root, 'play/play-service-account.json');
  if (!existsSync(credPath)) {
    throw new Error(`Service account not found: ${credPath}`);
  }
  const sa = require(credPath);
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: sa.project_id,
    });
  }

  const auth = admin.auth();
  const user = args.email
    ? await auth.getUserByEmail(args.email)
    : await auth.getUser(args.uid);

  const nextClaims = { ...(user.customClaims || {}) };
  if (adminValue) {
    nextClaims.admin = true;
  } else {
    delete nextClaims.admin;
  }

  await auth.setCustomUserClaims(user.uid, nextClaims);
  console.log(
    JSON.stringify(
      {
        uid: user.uid,
        email: user.email ?? null,
        customClaims: nextClaims,
      },
      null,
      2,
    ),
  );
  console.log(
    'Done. Operator must refresh ID token (sign out/in) before the claim applies.',
  );
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
```

- [ ] **Step 2: Dry-run argparse locally (no credentials required for help path)**

Run: `node tools/set-admin-claim.mjs`  
Expected: exits non-zero with message about `--email` / `--uid`

- [ ] **Step 3: If credentials exist, grant yourself (manual)**

Run (replace email):

```bash
node tools/set-admin-claim.mjs --email YOUR_EMAIL --admin true
```

Expected: JSON with `"admin": true` and refresh reminder.

---

### Task 5: Scaffold `admin/` Vite + React app

**Files:**
- Create: `admin/package.json`, `admin/vite.config.ts`, `admin/tsconfig.json`, `admin/tsconfig.app.json`, `admin/tsconfig.node.json`, `admin/index.html`, `admin/src/main.tsx`, `admin/src/vite-env.d.ts`, `admin/.env.example`, `admin/.gitignore`

**Interfaces:**
- Env (Vite):

```
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=
VITE_FIREBASE_APP_ID=
VITE_ADMIN_API_BASE_URL=http://127.0.0.1:8787
```

(Pull web-app Firebase values from Firebase Console → Project settings → Your apps → Web, or create a Web app if none exists.)

- [ ] **Step 1: Scaffold with Vite**

From repo root:

```bash
npm create vite@latest admin -- --template react-ts
cd admin && npm install && npm install firebase react-router-dom
```

Remove default `App.css` / Vite boilerplate logos; keep a clean `src/`.

- [ ] **Step 2: Add env typings and example**

`admin/src/vite-env.d.ts`:

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_FIREBASE_API_KEY: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN: string;
  readonly VITE_FIREBASE_PROJECT_ID: string;
  readonly VITE_FIREBASE_APP_ID: string;
  readonly VITE_ADMIN_API_BASE_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

`admin/.env.example` — keys listed above (empty values + comment pointing at Console).

`admin/.gitignore` — include `.env`, `.env.local`, `node_modules`, `dist`.

- [ ] **Step 3: Verify Vite starts**

Run: `cd admin && npm run dev`  
Expected: serves on `http://localhost:5173` without compile errors (placeholder UI OK until Task 6).

---

### Task 6: SPA auth gate, shell, routes, `/v1/me`

**Files:**
- Create: `admin/src/lib/firebase.ts`
- Create: `admin/src/lib/adminApi.ts`
- Create: `admin/src/auth/AuthProvider.tsx`
- Create: `admin/src/auth/RequireAdmin.tsx`
- Create: `admin/src/layout/AdminShell.tsx`
- Create: `admin/src/pages/LoginPage.tsx`
- Create: `admin/src/pages/AccessDeniedPage.tsx`
- Create: `admin/src/pages/DashboardPage.tsx`
- Create: `admin/src/pages/StubPage.tsx`
- Create: `admin/src/App.tsx`
- Create: `admin/src/styles.css`
- Modify: `admin/src/main.tsx`

**Interfaces:**
- Consumes: Firebase Auth Google provider; Worker `GET /v1/me`
- Auth states: `loading` | `signedOut` | `denied` | `admin`
- On enter admin shell: call `/v1/me` once; `401`/`403` → treat as denied; network error + client `admin` claim → shell + banner

- [ ] **Step 1: Firebase + admin API helpers**

```ts
// admin/src/lib/firebase.ts
import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const firebaseApp = initializeApp(firebaseConfig);
export const auth = getAuth(firebaseApp);
export const googleProvider = new GoogleAuthProvider();
```

```ts
// admin/src/lib/adminApi.ts
export type MeResponse = {
  uid: string;
  email?: string;
  admin: true;
};

export async function fetchMe(idToken: string): Promise<
  | { ok: true; me: MeResponse }
  | { ok: false; kind: 'unauthorized' | 'network' }
> {
  const base = import.meta.env.VITE_ADMIN_API_BASE_URL.replace(/\/$/, '');
  try {
    const res = await fetch(`${base}/v1/me`, {
      headers: { Authorization: `Bearer ${idToken}` },
    });
    if (res.status === 401 || res.status === 403) {
      return { ok: false, kind: 'unauthorized' };
    }
    if (!res.ok) {
      return { ok: false, kind: 'network' };
    }
    const me = (await res.json()) as MeResponse;
    return { ok: true, me };
  } catch {
    return { ok: false, kind: 'network' };
  }
}
```

- [ ] **Step 2: AuthProvider**

Implement `AuthProvider` that:

1. Subscribes to `onAuthStateChanged`
2. When user present: `const token = await user.getIdTokenResult(true)` and `const isAdmin = token.claims.admin === true`
3. Exposes `{ status, user, idToken, apiBanner, signInWithGoogle, signOut, refreshAdmin }`
4. `refreshAdmin`: get fresh ID token string, call `fetchMe`; set `apiBanner` on network failure; set status `denied` on unauthorized

Exact component shape can follow React context pattern; keep files small.

- [ ] **Step 3: Pages + shell + router**

Routes (React Router):

| Path | Element |
|------|---------|
| `/login` | `LoginPage` (Google button; if already admin → navigate `/`) |
| `/denied` | `AccessDeniedPage` |
| `/` | `RequireAdmin` → `AdminShell` → `DashboardPage` |
| `/reports`, `/announcements`, `/ops`, `/platform` | `RequireAdmin` → `AdminShell` → `StubPage` with title |
| `*` | redirect to `/` or `/login` based on auth |

`AdminShell`: side nav links + header (email, photoURL, Sign out) + optional yellow banner “API unavailable” when `apiBanner` is set. Call `refreshAdmin` once on mount when status becomes `admin`.

`StubPage`: heading + “Coming in a later phase.”

`styles.css`: simple light ops chrome (CSS variables for bg/text/border; no purple marketing theme).

- [ ] **Step 4: Wire `main.tsx`**

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './auth/AuthProvider';
import { App } from './App';
import './styles.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);
```

- [ ] **Step 5: Manual checklist**

1. `cd workers/admin-api && npm run dev`
2. `cd admin && npm run dev` (with `.env` filled)
3. Sign in without claim → Access denied
4. Run claim script → sign out/in → shell + nav stubs
5. Stop Worker → shell still loads with API banner if claim present

---

### Task 7: Docs

**Files:**
- Create: `admin/README.md`
- Modify: `FIREBASE.md` (new subsection under Authentication)
- Modify: `docs/superpowers/specs/2026-09-26-admin-panel-foundation-design.md` if any drift

- [ ] **Step 1: Write `admin/README.md`**

Cover:

- Prerequisites (Node, Firebase web app config, Auth Google provider enabled, authorized domains for `localhost`)
- Env file from `.env.example`
- `npm run dev` + Worker `npm run dev`
- Grant claim via `node tools/set-admin-claim.mjs …`
- Deploy: Cloudflare Pages (`admin/` build `npm run build`, output `dist`); Worker `npm run deploy`; update `ALLOWED_ORIGINS` and `VITE_ADMIN_API_BASE_URL` for prod
- Phase roadmap pointer to the foundation spec

- [ ] **Step 2: Update `FIREBASE.md`**

Add a short section (e.g. under Authentication):

- Custom claim `admin: true`
- Rules helper `isAdmin()` (ready; report reads deferred to admin phase 2)
- Pointer to `tools/set-admin-claim.mjs` and `admin/README.md`
- Note that FCM console remains until announcements phase

- [ ] **Step 3: Final verification**

Run:

```bash
cd workers/admin-api && npm test
cd ../admin && npm run build
```

Expected: Worker tests PASS; SPA production build succeeds.

---

## Plan self-review

| Spec requirement | Task |
|------------------|------|
| `admin/` Vite+React SPA | 5, 6 |
| Cloudflare Pages deploy docs | 7 |
| Firebase Auth Google + `admin` claim | 4, 6 |
| Claim script | 4 |
| `workers/admin-api` + `/v1/me` | 2, 3 |
| CORS allowlist | 3 |
| Firestore `isAdmin()` only | 1 |
| No issue_reports reads | 1 (explicit) |
| Auth gate + stubs | 6 |
| Worker Vitest | 2, 3 |
| SPA manual checklist only | 6 Step 5 |
| Docs | 7 |
| Player app unchanged | Global constraint |

No TBD/placeholder steps remain after writing.
