# App opens from our own records, with who opened — design

Date: 2026-10-17
Status: approved (user: "go ahead", 2026-10-17)
Repos: winklo (app, rules, new `workers/activity`) + winklo-admin (console, admin-api Worker)
Builds on: `2026-10-05-daily-app-opens-design.md`

## Goal

The Ops Console's **App opens** comes only from Winklo's own records, never GA4, and an operator can see **who opened the app on a given day**: every signed-in player and every guest device, with platform, app version, how many times they opened and when.

## What exists today

- The app writes `daily_activity/{yyyy-MM-dd}/users/{uid}` (`uid`, `firstOpenAt`, `lastOpenAt`, `platform`) on cold start, resume and sign-in, at most once per 5 minutes, for signed-in users only (`RecordAppOpen`, `AppOpenLifecycle`, `ActivityRepositoryImpl`).
- The admin dashboard counts that subcollection and falls back to GA4 `activeUsers` whenever the count is 0 (`fetchAppOpenMetric` in `src/lib/dashboardKpis.ts`). It shows no names.
- Guests (Home works without sign-in; only game routes redirect) are never recorded.

## Decisions

| Topic | Choice |
|-------|--------|
| Who counts | Signed-in players **and** guests |
| Guest identity | An app-generated install ID (random UUID v4 in SharedPreferences). Play Data Safety already declares "Device or other IDs". |
| Guest write path | A new public Worker `workers/activity` (`winklo-activity`), rate-limited, writing with a service account. Rejected: unauthenticated Firestore writes (rules can't rate-limit; one script could fill a day with fake guests) and Firebase Anonymous Auth (every "signed in" check, Registered users, leaderboards and account deletion would see anonymous accounts). |
| Signed-in write path | Unchanged: the app writes Firestore directly. 1.0.0+16 builds keep working. |
| Row details | Platform, app version + build, opens that day, first open, last open; signed-in rows add name, email, avatar, admin badge |
| "Opens" | Recorded opens: cold start, resume or sign-in, at most one per 5 minutes per identity |
| GA4 | Gone from the App opens card. The Analytics page stays on GA4 for sessions and events. |
| Debug builds | Share `daily_activity` as before (README "Debug data is only partly separate") |

## Data model

```
daily_activity/{yyyy-MM-dd}/users/{uid}            # owner writes (app)
  uid, firstOpenAt, lastOpenAt, platform           # as before
  opens: int          # NEW: 1 on create, +1 per recorded open (FieldValue.increment)
  appVersion: string  # NEW: "1.1.0" (PackageInfo.version)
  build: int          # NEW: 19 (PackageInfo.buildNumber)
  installId: string   # NEW: the device's install ID, links a guest row to the player

daily_activity/{yyyy-MM-dd}/guests/{installId}     # Worker writes only
  installId, firstOpenAt, lastOpenAt, platform, opens, appVersion, build
```

- Docs written by older builds lack the new fields; the console shows "—".
- One doc per identity per day, so doc count = unique openers.
- A guest who signs in later that day has both a guest doc and a user doc. The console keeps them as two populations and marks the guest row "Signed in later as <name>" when a user doc that day has the same `installId`. The card total is signed in + guests.
- Day ids stay device-local `yyyy-MM-dd` (`leaderboardDayId`), like the leaderboards.

## App (winklo)

### Identity-aware throttle

The throttle today is one timestamp for everyone, so a guest open followed by a sign-in within 5 minutes would drop the signed-in record. The throttle remembers **who** it recorded (`u:<uid>` or `g:<installId>`) and **when**. A recorded open within 5 minutes is skipped only when it is the same identity **and** the same day id; a different identity or a new day records straight away.

### Cold start waits for auth

`AppOpenLifecycle.start()` pings straight away today, before Firebase has restored the session, so with guests counted every signed-in cold start would also log a guest open. The first ping now waits for the first `authStateChanges()` event (Firebase emits the restored state once it knows). Resume pings and null→uid sign-in pings stay as they are.

### Pieces

| Layer | Change |
|-------|--------|
| `domain/repositories/activity_repository.dart` | `lastRecorded()` → `RecordedOpen?` (`at`, `key`); `markRecorded(at, key)`; `installId()`; `recordOpen(...)` gains `installId`; new `recordGuestOpen({installId, dayId, platform})` |
| `domain/usecases/record_app_open.dart` | Signed in → `recordOpen`; signed out → `recordGuestOpen`. Identity-aware throttle. Analytics `app_open` as before. |
| `data/repositories/activity_repository_impl.dart` | Install ID (generated once with `Random.secure()`), app version/build from `PackageInfo` (injectable), `opens` (1, then `FieldValue.increment(1)`), guest open through the client |
| `data/clients/activity/` | `GuestActivityClient` + `HttpGuestActivityClient` (`POST {base}/v1/open`, 10 s timeout) |
| `core/config/activity_config.dart` | `ACTIVITY_BASE_URL` dart-define, default `https://winklo-activity.winklo.workers.dev`; empty = guests not recorded |
| `core/lifecycle/app_open_lifecycle.dart` | First ping on the first auth event |
| `core/di/app_repositories.dart` | Wire the client into `ActivityRepositoryImpl` |

Errors stay best-effort: nothing blocks the UI; a failed write does not advance the throttle.

## Worker (`workers/activity`, `winklo-activity`)

- `GET /v1/health` → `{ok: true}`. `POST /v1/open`, no auth, body ≤ 2 KB:
  `{installId, dayId, platform, appVersion, build}`.
- Checks (else 400 `bad_request`): `installId` is a lowercase UUID v4; `dayId` is a real `yyyy-MM-dd` whose midnight UTC is in the device-local window (`now >= midnight − 14 h && now < midnight + 36 h`, the leaderboard Worker's window); `platform` ∈ `ios|android|other`; `appVersion` matches `^[0-9A-Za-z.+-]{1,32}$`; `build` is an integer 0…10 000 000.
- Body: read as a stream and refused (400) once over 2 KiB, with or without a `Content-Length`.
- Rate limits (Workers Rate Limiting bindings; 429 `rate_limited`): 30 / 60 s per client, 6 / 60 s per install ID, and 10 / 60 s per client for opens that create a new guest doc. A client is the `CF-Connecting-IP` for IPv4, and its /64 (the first four groups of the expanded address) for IPv6, since one subscriber holds a whole /64 and could otherwise rotate addresses. A missing or failing limiter lets the open through.
- Write: increment first. One `commit` (`currentDocument.exists = true`) updates `platform`, `appVersion`, `build`, sets `lastOpenAt` to request time and increments `opens` by 1; a repeat open costs only this. If the doc doesn't exist, the new-guest limit is checked (over it: 429, nothing created); otherwise a second `commit` creates the doc (`currentDocument.exists = false`, `opens: 1`, `firstOpenAt`/`lastOpenAt` = request time). If that create finds the doc made in between, the increment is sent once more. Firestore failure → 503 `unavailable`.
- Reply `{ok: true}`. The app treats anything else as "not recorded" and retries on the next open.
- Secret `FIREBASE_SERVICE_ACCOUNT_JSON`; var `FIREBASE_PROJECT_ID = "brain-zip-app"`. Helpers copied from `workers/leaderboard` (same convention as the other Workers).

## Firestore rules

- `daily_activity/{dayId}/users/{uid}` accepts the new optional keys: `opens` int 1…100 000 (create: 1; update: not below the stored value), `appVersion` string ≤ 32, `build` int 0…10 000 000, `installId` matching the UUID v4 pattern. Old-shape writes still pass.
- `daily_activity/{dayId}/guests/{installId}`: admin read, no client writes.
- Rules tests in `firestore/rules_test/activity.test.ts`.

## Admin (winklo-admin)

### Dashboard card

- Counts `users` and `guests` for the day (two count aggregations). Value = signed in + guests; sub-line `12 signed in · 4 guests`.
- Footer: the existing date stepper and a **See who opened** link to `/activity?day=<day>`. The GA4 link and the GA4 fallback go (`fetchAppOpenMetric`, `fetchGa4ActiveUsers` in `src/lib`). The admin-api `/v1/analytics/active-users` route stays for now (unused, harmless).

### App opens page (`/activity`, nav: Overview → App opens)

- Header: title, description, refresh indicator, date stepper (`?day=`, default browser-local today, max today).
- **14-day strip**: stacked bars (signed in / guests) for the 14 days ending today (or ending at the selected day when it is older). Clicking a bar selects its day.
- **Stats**: Signed in, Guests, Opens (sum of `opens`; notes how many rows came from builds that don't count), Platforms (android / iOS / other).
- **Tabs** `?who=users|guests`:
  - Signed in: player (avatar, name, email, Admin badge), platform, version, opens, first open, last open. Search `?q=` on name, email, uid. Row → `/platform?q=<email or uid>`.
  - Guests: device (short install ID + copy), platform, version, opens, first open, last open, "Signed in later as <name>".
- Reads at most 500 docs per population for the day, newest `lastOpenAt` first; at 500 the page says the list is cut off.
- Profiles: `users/{uid}` in batches of 30 (`documentId() in`). Emails: new admin-api `POST /v1/platform/users/lookup` (`{uids}` ≤ 100 per call → Identity Toolkit `accounts:lookup`).
- Empty states: no opens that day; before 5 Oct 2026, "tracking started on 5 Oct 2026".
- DEV mock mode: a seeded `appOpens` mock domain.

## Privacy

- `docs/privacy/index.html`: the app-open record gains open count, app version and an install ID; guests' app opens are recorded with an install ID, platform, app version and open times.
- `FIREBASE.md` data model + rules notes.
- Account deletion is unchanged: it deletes `daily_activity/{day}/users/{uid}`. Guest docs are keyed by device, not account.

## Rollout (the user deploys)

1. Firestore rules (`firebase deploy --only firestore:rules`).
2. `workers/activity`: `wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`, `wrangler deploy`.
3. winklo-admin: admin-api Worker (lookup route) and console.
4. App release (rides the next release on this branch stack).

The console works after step 3 with existing data; versions, opens and guests fill in as players update.

## Testing

- App: `RecordAppOpen` (guest path, identity/day-aware throttle, skip when not written), `ActivityRepositoryImpl` (install ID stable, guest client call, prefs), `HttpGuestActivityClient`, `AppOpenLifecycle` first-auth ping.
- Rules: emulator tests for old and new shapes, `opens` monotonic, guests read/write.
- Worker: vitest for validation, window, rate limits, increment-then-create, failures.
- Admin: model tests (parsing, summary, guest matching), data tests, query tests, page and dashboard tests, plus the gates (`build`, `lint`, `check:ui`, `typecheck:tests`, `test`, `check:bundle`).
