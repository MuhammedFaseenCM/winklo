# Firebase setup (Winklo)

The daily games need Firebase: Zip, Path Words and Sudoku load each day's puzzle from Firestore (written by winklo-admin), and playing requires Google sign-in. Without a working Firebase config the app still starts, but the games show "Could not load today's puzzle", and Analytics / Crashlytics do nothing.

## 1. Create project

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Create a project (Spark / free plan is fine)
3. Add an **Android** app with package name: `com.winklo.faseencm`
4. Enable **Google Analytics** for the project (recommended; also powers Crashlytics breadcrumbs)
5. In Build → **Crashlytics**, click through to enable Crashlytics for the Android app

## 2. Wire the Android app

```bash
# from project root
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID --platforms=android
```

Or manually:

1. Download `google-services.json` into `android/app/`
2. In `android/settings.gradle.kts` plugins block, add:
   `id("com.google.gms.google-services") version "4.4.4" apply false`
   `id("com.google.firebase.crashlytics") version "3.0.8" apply false`
3. In `android/app/build.gradle.kts` plugins block, add:
   `id("com.google.gms.google-services")`
   `id("com.google.firebase.crashlytics")`

## 3. Firestore

1. Create a Firestore database
2. Deploy rules and indexes (see Auth / leaderboard section below for write paths):

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Rules files: `firestore/firestore.rules`, `storage.rules`  
Indexes file: `firestore/firestore.indexes.json`

Content collections remain **public read / no client writes**. Leaderboard and user profile paths require Auth (see §7).

3. Seed content collections (same shape as assets):

### `zip_levels/{id}` (e.g. `daily_YYYYMMDD` for daily puzzle overrides)

Doc ids use the **player’s local calendar** date (`YYYYMMDD`). Publish today and the next 1–2 days ahead so other timezones pick up the curated board at their midnight.
```json
{
  "size": 6,
  "order": 1,
  "numbers": { "5,5": 1, "4,3": 2, "2,2": 3, "0,5": 4, "0,0": 5, "5,0": 6 },
  "walls": [
    { "a": [5, 0], "b": [5, 1] },
    { "a": [1, 4], "b": [1, 5] }
  ]
}
```

### `path_words_levels/{id}` (e.g. `daily_YYYYMMDD`)
```json
{
  "size": 5,
  "day": "2026-09-29T00:00:00.000Z",
  "letters": ["a", "p", "p", "l", "e", "t", "r", "e", "e", "s", "g", "r", "a", "p", "e", "m", "e", "l", "o", "n", "b", "e", "r", "r", "y"],
  "targets": [
    {
      "id": "target_1",
      "word": "APPLE",
      "start": [0, 0],
      "path": [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
      "colorIndex": 0
    }
  ]
}
```

### `sudoku_levels/{id}` (e.g. `daily_YYYYMMDD`)
```json
{
  "dateId": "20260929",
  "size": 6,
  "boxRows": 2,
  "boxCols": 3,
  "difficulty": "easy",
  "given": [1, 0, 0, 0, 0, 6, 0, 2, 0, 0, 5, 0, 0, 0, 3, 4, 0, 0, 0, 0, 5, 6, 0, 0, 0, 4, 0, 0, 1, 0, 6, 0, 0, 0, 0, 2],
  "solution": [1, 5, 4, 2, 3, 6, 3, 2, 6, 1, 5, 4, 2, 6, 3, 4, 1, 5, 4, 1, 5, 6, 2, 3, 5, 4, 2, 3, 1, 6, 6, 3, 1, 5, 4, 2]
}
```

### `word_match_decks/{id}`
```json
{
  "title": "Opposites",
  "seconds": 60,
  "order": 1,
  "pairs": [{ "a": "hot", "b": "cold" }]
}
```

### `categories/{id}`
```json
{
  "name": "Animals",
  "order": 1,
  "words": ["ant", "bear", "cat"]
}
```

The bundled samples are legacy and not read by the daily games:

- `assets/zip/levels/`: the old level-based Zip
- `assets/word_match/decks/`, `assets/words/categories/`: the hidden Word Match and Category Race games

### `issue_reports/{reportId}`

Create-only while signed in. The client cannot read, update, or delete. `uid` must match `request.auth.uid`. `photoUrl` and `avatarId` are written as null when absent so every key is present.

```
title, description, uid, displayName, photoUrl, avatarId,
appVersion, buildNumber, platform, createdAt
```

Deploy rules before relying on production writes:

```bash
firebase deploy --only firestore:rules
```

### `deletion_requests/{id}`

Worker-only audit trail for account deletion (written by the account-deletion Worker via Admin SDK). Firestore rules deny all client read and write; only server-side Admin access applies.

## 4. Analytics + Crashlytics

Packages: `firebase_analytics`, `firebase_crashlytics`.

- Collection is always on when Firebase initializes successfully
- Crashlytics upload is **release-only** (`!kDebugMode`)
- Product events go through `AnalyticsRepository` (domain) → `FirebaseAnalyticsRepositoryImpl`
- Screen views are logged via `AnalyticsRouteObserver` on GoRouter

### Verify Analytics (debug)

1. Enable Analytics DebugView for your device (see [DebugView](https://firebase.google.com/docs/analytics/debugview))
2. Open games from home, use hint/reset, finish a puzzle
3. Confirm events such as `home_game_opened`, `game_started`, `game_completed`, `hint_used`, `screen_view` in the Firebase console

### Verify Crashlytics

1. Ship a release build (or temporarily enable collection in debug)
2. Force a test crash once, relaunch the app so the report uploads
3. Check Crashlytics → Issues in the Firebase console (can take a few minutes)

## 5. Behavior

- On launch, the app tries `Firebase.initializeApp()`
- If that fails (no config yet), the daily games can't load a puzzle and show an error with Retry; there is no asset fallback
- Daily puzzle reads wait up to 8 seconds for the server, then use the copy Firestore cached on the device (offline persistence is on)
- Analytics / Crashlytics no-op safely when Firebase is not ready

## 6. Remote Config (force update)

Winklo reads **Firebase Remote Config** on Home to soft-prompt or block players when their install is below a minimum **version** and/or **build number**. Checks run on Home load and again when the app resumes (so updating from the Play Store and returning can clear a forced overlay without restart).

### Enable in the console

1. In [Firebase Console](https://console.firebase.google.com/) → your project → **Remote Config**, create parameters if they do not exist yet.
2. Publish values when you are ready for clients to fetch them (app initializes Remote Config after a successful `Firebase.initializeApp()`).

**Fetch interval (client cache):** `FirebaseBootstrap` sets Remote Config `minimumFetchInterval` to **`Duration.zero` in debug** (immediate fetch while developing) and **15 minutes in release**. Publishing new parameters in the console is **not instant** for installs that are already running: the app re-checks on Home load and when the app **resumes**, but the SDK may still serve **cached** values until the minimum fetch interval has elapsed since the last successful fetch.

Package: `firebase_remote_config` (see `lib/data/clients/remote_config_client.dart` for key names and in-app defaults).

### Keys, types, and in-app defaults

| Key | Type | Default (in app) | Purpose |
|-----|------|------------------|---------|
| `appVersion` | String | `0.0.0` | Minimum required marketing version (e.g. `1.0.0`) |
| `minBuildNumber` | Number | `0` | Minimum build when installed version **equals** `appVersion` |
| `forceUpdate` | Boolean | `false` | `true` → Home-only blocking overlay; `false` → non-dismissible soft banner |
| `playStoreUrl` | String | `https://play.google.com/store/apps/details?id=com.winklo.faseencm` | Android store link opened by **Update** |
| `appStoreUrl` | String | `''` (empty) | Reserved for iOS later; not used for update decisions on Android today |

**Comparison (summary):**

- `appVersion` empty or `0.0.0` → treat as **not configured** → no update prompt.
- `playStoreUrl` empty → **no update prompt** (fail open; Android uses Play URL only for now).
- If installed version **&lt;** required → update needed; if **==** required and build **&lt;** `minBuildNumber` → update needed; if installed version **&gt;** required → no update.
- If update is needed and `forceUpdate` is `true` → **forced** overlay on Home; otherwise **soft** banner (games still playable).

### Operator procedures

**Soft prompt (recommended first):**

1. Set `appVersion` and/or `minBuildNumber` above what most installed clients report (version from `pubspec`, build from CI/`versionCode`).
2. Leave `forceUpdate` **false**.
3. Set `playStoreUrl` to the live listing (default matches package `com.winklo.faseencm`).
4. Publish Remote Config.

Users see a non-dismissible banner on Home until their install is no longer behind; **Update** opens the Play Store.

**Force update (escalation):**

1. Same minimum `appVersion` / `minBuildNumber` as soft.
2. Set `forceUpdate` **true**.
3. Confirm `playStoreUrl` is valid and published.

Home shows a blocking overlay (no skip); only **Update Now** and returning after install clears it via resume re-check.

**Roll back / disable:**

- Set `appVersion` to `0.0.0` and `minBuildNumber` to `0`, or lower mins below current installs, and publish — prompts stop for clients that fetch the new config.

### Fail-open behavior

The app **must not brick** if Remote Config or Firebase is unavailable:

- If Firebase does not initialize, Remote Config is not initialized and every update check returns **no prompt**.
- Fetch/refresh errors are logged; clients fall back to in-app defaults (no forced update unless you publish stricter values and fetch succeeds).
- Empty `playStoreUrl` or unconfigured `appVersion` (`0.0.0`) → **no prompt**, even if other keys are set.

Always keep a valid `playStoreUrl` when you intentionally prompt or force updates.

### Data Safety / privacy

Remote Config uses the same Firebase project as Analytics and Crashlytics. Parameters are **operator-defined minimums and store URLs** — the app does not send user PII to Remote Config for this feature. **No new personal data collection** beyond existing Firebase SDK disclosures.

Before each store release, confirm [Google Play Data Safety](https://play.google.com/console) still matches `play/data_safety.csv` and project docs; update the CSV or console only if Google requires an explicit Remote Config disclosure beyond your current Firebase entries.

## 7. Authentication + realtime leaderboard

Packages: `firebase_auth`, `google_sign_in`.

Players must **sign in with Google** before playing Zip, Path Words or Sudoku. Personal-best times sync to Firestore; the leaderboard screen listens with live snapshots. Per-user progress (daily clears, hint usage, streaks) also syncs to private owner-only docs under `users/{uid}` (see **Private progress sync** below).

### Enable Google Sign-In

1. Firebase Console → **Authentication** → Sign-in method → enable **Google**.
2. Android: add your debug/release **SHA-1** (and SHA-256) fingerprints under Project settings → Your apps → Android app `com.winklo.faseencm`.
3. Download an updated `google-services.json` if the console asks you to.
4. Optional but recommended for reliable ID tokens: use the Web client ID from the Firebase Google provider as `serverClientId` when initializing Google Sign-In if sign-in fails to return an ID token on device.

### Data paths

```
users/{uid}
  displayName, photoUrl, avatarId, updatedAt, fcmToken, fcmUpdatedAt

leaderboards/{gameId}/all_time/{uid}          # release / profile builds
leaderboards/{gameId}/daily/{yyyy-MM-dd}/entries/{uid}

leaderboards_debug/{gameId}/all_time/{uid}    # debug builds (`kDebugMode`)
leaderboards_debug/{gameId}/daily/{yyyy-MM-dd}/entries/{uid}

daily_activity/{yyyy-MM-dd}/users/{uid}
  uid, firstOpenAt, lastOpenAt, platform

users/{uid}/game_days/{gameId}_{playId}       # private progress (owner-only)
  gameId, playId, timeSeconds?, points?, usedHints?, hadMistakes?,
  flagsKnown?, hintsUsed, clearedAt?, board?, updatedAt
users/{uid}/game_streaks/{gameId}
  current, longest, lastClearedDateId, freezeAvailable, updatedAt

users/{uid}/game_days_debug/{gameId}_{playId} # debug builds (`kDebugMode`)
users/{uid}/game_streaks_debug/{gameId}
```

Signed-in clients create/update their own daily open doc (throttled in app); admins read for dashboard counts. Timestamps use `FieldValue.serverTimestamp()` (rules validate as `request.time`).

`gameId` is `zip`, `path_words` or `sudoku`. Leaderboard docs hold `timeSeconds`, `updatedAt`, `displayName`, `photoUrl`, `avatarId`, `usedHints`, `hadMistakes` (clean-run flags) and optional `currentStreak` (int ≥ 0, written by 1.0.0+14 and later). Daily day keys are **device-local** `yyyy-MM-dd` (the player's phone calendar). Ranking: ascending `timeSeconds`, then ascending `updatedAt` (earlier submit wins ties). Client shows top 50. Debug builds (`flutter run`) read and write **only** `leaderboards_debug`; release and profile builds use `leaderboards`.

`avatarId` is an optional preset id (`preset_01` … `preset_06`) or null when the player uses a photo. `photoUrl` is the Google photo or a public R2 URL (`*.r2.dev`) after gallery upload. Display priority: preset asset, then `photoUrl`, then the first letter of `displayName`.

Profile edits patch the signed-in user’s Zip, Path Words and Sudoku **all-time** docs and **today’s** daily entry under the **active** root (when those docs already exist) with `displayName`, `photoUrl`, and `avatarId` only. That update must keep `timeSeconds` unchanged.

### Demo seed (debug boards only)

Debug / `flutter run` builds use Firestore root `leaderboards_debug` (same shape as `leaderboards`). Release and profile builds use `leaderboards`.

Seed 28 fake players (`demo_001` …) into **debug** Zip + Path Words boards (Daily today local + All-time):

```bash
# requires `firebase login` (project brain-zip-app)
node tools/seed_leaderboard_demo.mjs
```

Clear demo docs without re-seeding:

```bash
CLEAR=1 node tools/seed_leaderboard_demo.mjs
```

Uses your Firebase CLI access token (Cloud IAM; bypasses client rules). Never writes to production `leaderboards`. Your real Google user only appears after you clear a puzzle.

### Private progress sync

SharedPreferences stays the source the UI reads; `SyncProgress` reconciles it with the owner-only docs above (pull + merge, push when changed, leaderboard backfill for the current and previous play period). Writes use `set(..., SetOptions(merge: true))` (not transactions) so they queue offline.

- `playId` is `YYYYMMDD` (release) or `YYYYMMDDHHmm` (debug minute period); the doc id must be `{gameId}_{playId}`.
- `timeSeconds` / `points` / `usedHints` / `hadMistakes` are present only for cleared days. `flagsKnown: false` marks flags derived for clears made before progress sync existed (`usedHints` = any hint used that day; `hadMistakes` = false for Zip / Path Words, true for Sudoku).
- `hintsUsed` is the hint quota consumed that day (0..50). `clearedAt` is when the clear was first pushed.
- `board` is the game-specific board of the best-time run (Zip: the drawn path as `row,col` cells joined by `;`), so the review of a cleared puzzle shows the player's own solution on any device. Any valid Zip path wins, so it often differs from the level's generated `solution`.
- Debug builds read and write only the `_debug` twins.
- **Every key the client writes must be in the rules whitelist** (lesson from the `currentStreak` incident). The whitelists equal `gameDayFirestoreKeys` / `streakFirestoreKeys` in `lib/data/repositories/progress_remote_repository_impl.dart`, and a unit test pins the client payload to those sets. Change all three together, and **deploy rules before shipping** the build that writes a new key. `test/firestore/rules_key_whitelist_test.dart` reads `firestore/firestore.rules` and fails when a rules whitelist (game days, streaks, leaderboard) drifts from the client key set.

### Rules checklist (manual)

After deploy:

1. Anyone can **read** Zip / Path Words / Sudoku leaderboard docs; signed-out clients still cannot write.
2. Signed-in user can create/update **only** their own score docs; worsening a time is rejected. A profile-only update (same `timeSeconds`, only `displayName` / `photoUrl` / `avatarId` / `updatedAt` / `currentStreak`) is allowed. A submit with `usedHints` / `hadMistakes` (bool) and `currentStreak` (int ≥ 0) is accepted. `updatedAt` (the tie-breaker) must be the write's server time or unchanged; `displayName` is a non-empty string of at most 120 chars; `photoUrl` is null or an `https` URL on `*.googleusercontent.com` or the avatar bucket's `r2.dev` host under `/avatars/`; `avatarId` is null or at most 64 chars. The client trims names to 40 chars and drops other photo URLs (`lib/data/leaderboard_identity.dart`).
3. Content collections (`zip_levels`, etc.) still refuse client writes.
4. `users/{uid}` is owner read / owner write (admins can read too): it holds the device's `fcmToken`, so other players can't read it. `avatarId` must be a string or null when present.
5. Custom gallery photos: Worker accepts `PUT /v1/avatar` only with a valid Firebase ID token for that uid; object key `avatars/{uid}.jpg` on R2; JPEG, max 2 MiB. Public read via R2 `r2.dev` (no Firebase Storage rules).
6. `daily_activity/{yyyy-MM-dd}/users/{uid}`: owner create/update and read of their own doc; admin read (counts). **Deploy** `firestore/firestore.rules` before relying on production open tracking (`firebase deploy --only firestore:rules`).
7. `users/{uid}/game_days/{dayKey}` and `users/{uid}/game_streaks/{gameId}` (and the `_debug` twins): **only the owner** can read, create or update; other signed-in users and signed-out clients are rejected; delete is always rejected.
8. Game day writes: keys only from the whitelist; `gameId` in `zip` / `path_words` / `sudoku`; `playId` matches `^[0-9]{8}([0-9]{4})?$`; doc id equals `gameId + '_' + playId`; `hintsUsed` int 0..50; `timeSeconds` / `points` int ≥ 0 when present; `usedHints` / `hadMistakes` / `flagsKnown` bool when present; `clearedAt` timestamp when present; `board` non-empty string of at most 1024 chars, only alongside `timeSeconds`; `updatedAt == request.time`. Merge writes are validated against the **merged** doc. Updates may only improve: `timeSeconds` never rises, `points` / `hintsUsed` never drop, `clearedAt` never moves later or disappears, `board` only changes with a strictly better `timeSeconds` (a stale merge write from a cached read is rejected and re-merged on the next sync).
9. Streak writes: path `gameId` is a valid game; keys only `current`, `longest`, `lastClearedDateId`, `freezeAvailable`, `updatedAt`; `current` / `longest` int ≥ 0; `lastClearedDateId` null or an 8-digit string; `freezeAvailable` bool; `updatedAt == request.time`. Updates never lower `longest` and never move `lastClearedDateId` earlier or back to null (`current` may reset to 0).
10. Compile check before deploy: `firebase deploy --only firestore:rules --dry-run --project brain-zip-app`. Rules must be live **before** a build that writes new paths or keys ships.

### Admin custom claims (panel foundation)

Operators of the admin SPA use the same Firebase Auth project with a custom claim `{ admin: true }`. Firestore rules define `isAdmin()` (`request.auth.token.admin == true`). Admin reads are enabled for `client_errors` and `daily_activity/{yyyy-MM-dd}/users/{uid}` (the owner may also read their own daily activity doc). User-submitted `issue_reports` still have no client reads (inbox is phase 2).

Admin console code lives in a **separate repo**: [MuhammedFaseenCM/winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin) (SPA + `workers/admin-api` + claim script).

Grant or revoke (from that repo):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node tools/set-admin-claim.mjs --email you@example.com --admin true
```

FCM announcements can be sent from the [winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin) **Announcements** module (Worker → FCM HTTP v1 + `announcement_sends` history). Console campaigns still work as a fallback.

### Data Safety / privacy (Auth)

Leaderboards (Zip, Path Words, Sudoku) store **uid, displayName, photoUrl, avatarId, timeSeconds, updatedAt, usedHints, hadMistakes, currentStreak**; these are publicly readable. Private progress docs (owner-only) store per-day **best time, points, usedHints, hadMistakes, flagsKnown, hintsUsed, clearedAt, board (Zip drawn path)** and per-game **streak counters** (`current`, `longest`, `lastClearedDateId`, `freezeAvailable`). `daily_activity` stores uid, first/last open time and platform; `issue_reports` store the submitted text plus uid, displayName, photoUrl, avatarId, app version/build and platform. Custom photos live on **Cloudflare R2** (public `r2.dev` URLs). Play Data Safety declares this gameplay data under **App interactions** (`PSL_USER_INTERACTION`) for **App functionality** and **Analytics**, collected not shared (`play/data_safety.csv`). Confirm Play Data Safety covers Google account sign-in and that profile/name/photo sharing on a public-within-app leaderboard is disclosed if required.

## 8. Profile photos (Cloudflare R2 + Worker)

Custom gallery avatars do **not** use Firebase Storage. You can stay on the **Spark** plan for Auth/Firestore; no Blaze upgrade is required for profile photos.

Packages: `image_picker` (gallery). Uploads go through the **`winklo-avatar-upload`** Worker in `workers/avatar-upload/`.

### One-time ops (R2 + Worker)

1. **R2 bucket** `winklo-avatars` — create and bind in Wrangler (see `workers/avatar-upload/README.md`):

   ```bash
   cd workers/avatar-upload
   npm install
   npx wrangler r2 bucket create winklo-avatars
   ```

2. **Public access** — Cloudflare dashboard → R2 → `winklo-avatars` → enable public access / `r2.dev` subdomain. Set `PUBLIC_BASE_URL` in `workers/avatar-upload/wrangler.toml` (e.g. `https://pub-xxxxx.r2.dev`).

3. **Deploy Worker**:

   ```bash
   cd workers/avatar-upload
   npm run deploy
   ```

   Note the Worker URL (e.g. `https://winklo-avatar-upload.<account>.workers.dev`). `FIREBASE_PROJECT_ID` in `wrangler.toml` must match your Firebase project for ID token verification.

### Flutter run / release

Pass the Worker **base URL** (no trailing slash):

```bash
flutter run --dart-define=AVATAR_UPLOAD_BASE_URL=https://winklo-avatar-upload.<account>.workers.dev
```

Use the same `--dart-define` for release builds (CI / Gradle / Xcode as applicable). If `AVATAR_UPLOAD_BASE_URL` is empty, gallery upload is unavailable; presets and Google sign-in photo still work.

Upload flow: signed-in client `PUT`s JPEG to `/v1/avatar` with `Authorization: Bearer <Firebase ID token>`. Worker writes **`avatars/{uid}.jpg`** (overwrite) to R2 and returns JSON `{ "photoUrl": "..." }`. The app stores that URL on `users/{uid}.photoUrl` and sets `avatarId` to null. Choosing a preset sets `avatarId` and clears `photoUrl` (no R2 upload); preset art is loaded from public R2 `static/avatars/` (see below).

### Static UI images (public R2)

Game tiles, leaderboard medals, and preset avatars are **not** bundled in the APK. Sources live in `tools/static-assets/` and are served from the same public bucket:

| R2 key | App usage |
|--------|-----------|
| `static/games/zip_tile.png` | Home Zip tile |
| `static/games/path_words_tile.png` | Home Path Words tile |
| `static/medals/medal_{gold,silver,bronze}.png` | Leaderboard top-3 |
| `static/avatars/preset_0N.png` | `UserAvatar` presets |

Flutter builds URLs via `StaticAssetsConfig` (`lib/core/config/static_assets_config.dart`). Default base is `PUBLIC_BASE_URL` from Wrangler. Override with:

```bash
flutter run --dart-define=STATIC_ASSETS_BASE_URL=https://pub-xxxxx.r2.dev
```

Upload / refresh objects (from repo root, Wrangler authenticated):

```bash
for f in tools/static-assets/games/*.png tools/static-assets/medals/*.png tools/static-assets/avatars/*.png; do
  rel="${f#tools/static-assets/}"
  npx --prefix workers/avatar-upload wrangler r2 object put \
    "winklo-avatars/static/$rel" \
    --file="$f" \
    --content-type="image/png" \
    --cache-control="public, max-age=31536000" \
    --remote
done
```

See `tools/static-assets/README.md`. Branding (`assets/branding/`) stays in the APK for launcher icon + native splash.

### Gallery pick (Android)

`image_picker` 1.2.x needs **no extra Android permission**. On Android 13+ it uses the system Photo Picker; on older versions the photo picker backport is optional and `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` are not required. Do not add those permissions (Play photo/video policy). This app’s gallery flow is picker-only (no camera).

iOS is not a shipping target. If you add it later, `Info.plist` needs `NSPhotoLibraryUsageDescription` even when `requestFullMetadata` is false.

### Manual checklist

1. Signed-in user can update `users/{uid}` `displayName` and `avatarId`.
2. Preset select clears `photoUrl` and does not upload; preset image loads from `static/avatars/` on R2.
3. Gallery upload (with `AVATAR_UPLOAD_BASE_URL` set) returns a public `photoUrl`; Profile and Zip / Path Words **Leaderboard** show the image; `avatarId` is null.
4. Worker rejects missing/invalid token, wrong content type, or body over 2 MiB.
5. Zip and Path Words leaderboard rows for that user show the new name and avatar without a new best time.
6. Sign-in again does not erase an existing `avatarId`.
7. Home game tiles and medals load from `static/games/` and `static/medals/` (public GET).

## 9. Push + local notifications

Packages: `firebase_messaging`, `flutter_local_notifications`, `timezone`, `flutter_timezone`.

### Local schedules (device local calendar)

| Type | Time | Condition |
|------|------|-----------|
| `daily_ready` | 08:00 | Every day |
| `streak_at_risk` | 20:00 | Scheduled while Zip **or** Path Words still uncleared today; cancelled when both are cleared |

Rescheduled on Home load / resume (and after returning from a game).

### FCM topics (until admin panel)

| Topic | `data.type` |
|-------|-------------|
| `announcements` | `announcement` |
| `app_updates` | `app_update` |

Signed-in devices subscribe after permission. Token is stored on `users/{uid}.fcmToken`.

**Console test:** Messaging → New campaign → Topic → `announcements` with custom data `type=announcement`. Optional `route=/`.

**Enable Cloud Messaging** in the Firebase project if not already. Android uses the existing `google-services.json`.

Android: `POST_NOTIFICATIONS`, status-bar icon `ic_stat_winklo`, and **core library desugaring** (`desugar_jdk_libs`) required by `flutter_local_notifications`.
