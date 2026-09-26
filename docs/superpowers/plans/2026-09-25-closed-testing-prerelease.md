# Closed Testing Pre-Release (1.0.0+4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Google Play closed-testing build `1.0.0+4` with auth/leaderboard and related WIP, with privacy/Data Safety/native permissions, Firebase SHA/rules, Workers, force-update Remote Config, and a signed AAB upload.

**Architecture:** Sequential ops runbook (no new app architecture). Repo docs and Play CSV first → publish privacy Pages → Firebase + Workers → stabilize WIP + bump version → signed AAB → Play upload → Remote Config force → smoke. Product code changes are limited to stabilizing existing WIP and the version bump; compliance is mostly docs/CSV/manifest audit.

**Tech Stack:** Flutter release AAB, Fastlane (`android closed`), Firebase CLI, Cloudflare Wrangler, Play Android Publisher API (`play/upload_data_safety.py`), GitHub Pages (`master` /docs).

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-closed-testing-prerelease-design.md`
- Version for this drop: **`1.0.0+4`** exactly
- Package: `com.winklo.faseencm`; Firebase project: `brain-zip-app`
- Account deletion: contact-only via GitHub issues (documented in privacy); no in-app delete
- Play App access: any Google account; no dedicated reviewer credentials
- Force update only **after** `+4` is live on closed: `appVersion=1.0.0`, `minBuildNumber=4`, `forceUpdate=true`
- Do **not** add `READ_MEDIA_*` / storage / camera permissions
- Worker defaults already in app: avatar `https://winklo-avatar-upload.winklo.workers.dev`, nouns `https://winklo-path-words-nouns.winklo.workers.dev`
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)
- Never print or commit keystore passwords / service-account JSON contents

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `docs/privacy/index.html` | Public privacy policy (GitHub Pages) |
| `play/app_content_answers.txt` | Play Console App content crib sheet |
| `play/data_safety.csv` | Play Data Safety labels CSV |
| `play/upload_data_safety.py` | Upload CSV via Android Publisher API |
| `android/app/src/main/AndroidManifest.xml` | Permission audit (keep AD_ID removals) |
| `android/key.properties` + `android/upload-keystore.jks` | Release signing (gitignored / local) |
| `android/app/google-services.json` | Refresh if Firebase console requires after SHA |
| `firestore/firestore.rules` (+ indexes) | Deploy before closed auth traffic |
| `workers/avatar-upload/` | R2 avatar Worker deploy |
| `workers/path-words-nouns/` | Daily nouns Worker deploy |
| `pubspec.yaml` | Bump to `1.0.0+4` |
| `lib/core/config/avatar_upload_config.dart` | Default Worker URL (verify only) |
| `lib/core/config/path_words_nouns_config.dart` | Default Worker URL (verify only) |
| `FIREBASE.md` | Optional: note closed-testing SHA / force RC values |
| Fastlane `android closed` | Upload AAB to Play alpha (closed) |

---

### Task 1: Rewrite privacy policy

**Files:**
- Modify: `docs/privacy/index.html`

**Interfaces:**
- Consumes: Spec §1 (Auth, R2, notifications, contact-only deletion within 30 days)
- Produces: Live policy content ready for GitHub Pages at `/privacy/`

- [ ] **Step 1: Replace the policy body**

Overwrite `docs/privacy/index.html` keeping the existing `<style>` / layout, but replace copy so it matches Auth. Full replacement content:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Winklo Privacy Policy</title>
    <style>
      :root {
        color-scheme: dark;
        --ink: #0f172a;
        --on-ink: #f8fafc;
        --muted: #94a3b8;
        --ember: #ff6b2c;
        --wall: #1e293b;
      }
      body {
        margin: 0;
        background: var(--ink);
        color: var(--on-ink);
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif;
        line-height: 1.6;
      }
      main {
        max-width: 42rem;
        margin: 0 auto;
        padding: 2.5rem 1.25rem 4rem;
      }
      h1 {
        font-size: 2rem;
        letter-spacing: -0.03em;
        margin-bottom: 0.25rem;
      }
      h2 {
        font-size: 1.15rem;
        margin-top: 2rem;
      }
      p,
      li {
        color: var(--on-ink);
      }
      .muted {
        color: var(--muted);
      }
      a {
        color: var(--ember);
      }
      .card {
        background: var(--wall);
        border-radius: 1rem;
        padding: 1rem 1.15rem;
        margin: 1.25rem 0;
      }
    </style>
  </head>
  <body>
    <main>
      <p class="muted">Winklo · com.winklo.faseencm</p>
      <h1>Privacy Policy</h1>
      <p class="muted">Last updated: 25 September 2026</p>

      <p>
        Winklo is a set of quick solo mini-games (Zip, Path Words, Word Match,
        and Category Race). You sign in with Google to play Zip and Path Words
        and to use the live leaderboard and cloud profile. This policy explains
        what is stored on your device and what is processed in the cloud.
      </p>

      <div class="card">
        <strong>Short version:</strong> We do not run ads and we do not sell
        data. Google Sign-In is required for Zip, Path Words, leaderboard, and
        profile. We use Google Firebase (Auth, Firestore, Analytics,
        Crashlytics, Remote Config, Cloud Messaging) and Cloudflare (avatar
        upload Worker + R2) to run those features.
      </div>

      <h2>Information stored on your device</h2>
      <p>
        Local preferences may include tutorial flags, notification schedules,
        and cached puzzle data. Uninstalling Winklo or clearing app storage
        removes local data. Cloud profile and leaderboard scores are separate
        (see below).
      </p>

      <h2>Account and profile</h2>
      <p>
        When you sign in with Google, Firebase Authentication creates an
        account tied to your Google identity. We store a Firebase user id
        (uid), display name, optional profile photo URL, and optional preset
        avatar id on <code>users/{uid}</code>. Display name and photo/avatar
        may also appear on Zip and Path Words leaderboards visible to other
        signed-in players in the app.
      </p>
      <p>
        You may choose a gallery photo. The app uses the system photo picker
        (no broad photo-library permission). The image is uploaded as JPEG to
        our Cloudflare Worker and stored on Cloudflare R2 at a public URL
        (for example on <code>r2.dev</code>). Preset avatars are bundled in
        the app and do not upload a photo.
      </p>
      <p>
        An FCM device token may be stored on your user document so we can send
        topic messages (for example announcements and app updates). The app
        may also schedule local notifications on the device.
      </p>

      <h2>Gameplay scores</h2>
      <p>
        Personal-best times for Zip and Path Words sync to Firestore
        leaderboards (daily and all-time). Other players can see your display
        name, avatar/photo, and time on those boards.
      </p>

      <h2>Other network processing</h2>
      <ul>
        <li>
          <strong>Cloud Firestore</strong> — puzzle catalogs and the user /
          leaderboard data described above.
        </li>
        <li>
          <strong>Firebase Analytics</strong> — product events (screens,
          games started/completed, hints, tutorials, and similar). Events may
          include gameplay metadata and device/installation identifiers from
          Google’s SDKs.
        </li>
        <li>
          <strong>Firebase Crashlytics</strong> — crash logs from release
          builds (stack traces, device/OS info). Not enabled for typical debug
          builds.
        </li>
        <li>
          <strong>Firebase Remote Config</strong> — operator settings such as
          minimum app version / build for update prompts.
        </li>
        <li>
          <strong>Path Words noun pool</strong> — the app may fetch a shared
          daily word list from our Cloudflare Worker.
        </li>
      </ul>
      <p>
        Google may process technical data such as IP address and Firebase
        installation identifiers. See
        <a href="https://firebase.google.com/support/privacy"
          >Firebase’s privacy information</a
        >
        and
        <a href="https://policies.google.com/privacy">Google’s privacy policy</a
        >. Cloudflare’s processing for Workers/R2 is described in
        <a href="https://www.cloudflare.com/privacypolicy/"
          >Cloudflare’s privacy policy</a
        >.
      </p>
      <p>
        The app may load the Lexend font from Google Fonts; Google may see your
        IP address for that request.
      </p>

      <h2>What we do not collect</h2>
      <ul>
        <li>No advertising identifiers used for ads (the app has no ads)</li>
        <li>No precise location, contacts, or microphone</li>
        <li>No payment or health information</li>
        <li>No sale of personal information</li>
      </ul>

      <h2>Children</h2>
      <p>
        Winklo is not directed at children under 13. We do not knowingly collect
        personal information from children.
      </p>

      <h2>Your choices and account deletion</h2>
      <p>
        You can sign out in Profile. You can stop using network features by
        staying signed out (Zip and Path Words require sign-in). Analytics and
        Crashlytics collection is required for the app’s current design (no
        in-app opt-out toggle).
      </p>
      <p>
        There is no in-app “delete account” button yet. To request deletion of
        your account and associated cloud data (profile, leaderboard entries,
        and custom R2 avatar if any),
        <a href="https://github.com/MuhammedFaseenCM/winklo/issues"
          >open a GitHub issue</a
        >
        and include the Google account email you used to sign in and your
        Firebase uid if you know it. We will delete that data within 30 days of
        a verified request.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this policy:
        <a href="https://github.com/MuhammedFaseenCM/winklo/issues"
          >open an issue on GitHub</a
        >.
      </p>
    </main>
  </body>
</html>
```

- [ ] **Step 2: Verify locally**

Open the file in a browser or `python3 -m http.server` from `docs/` and load `/privacy/`. Confirm “Last updated: 25 September 2026”, Sign-In / deletion / R2 language present, and no “you do not create an account” text.

- [ ] **Step 3: Commit** (only if user asked)

```bash
git add docs/privacy/index.html
git commit -m "$(cat <<'EOF'
docs: update privacy policy for Google Sign-In and cloud profile

EOF
)"
```

---

### Task 2: Update Play App content crib sheet

**Files:**
- Modify: `play/app_content_answers.txt`

**Interfaces:**
- Consumes: Privacy URL + App access decision (any Google account)
- Produces: Operator notes matching Console answers

- [ ] **Step 1: Replace file contents**

```text
Winklo Play Console App content answers
Privacy policy URL:
https://muhammedfaseencm.github.io/winklo/privacy/

Sign in / App access:
All features available with any Google account. Zip and Path Words require
Google Sign-In. Reviewers and closed testers should use their own Google
account. No special login credentials are required.

Ads:
No, the app does not contain ads.

Content rating:
Puzzle / word games. No violence, sex, drugs, location sharing, or chat.
Leaderboard shows display name and avatar/photo among players.
Expected: Everyone / PEGI 3. Confirm the IARC email Google sends.

Target audience:
13-15, 16-17, and 18+. Not designed for children. Appeal to kids: No.

Data safety: upload via Play API (play/data_safety.csv + upload_data_safety.py)
- Google Sign-In (OAuth)
- Name, user IDs, optional photos; name/photo may appear on in-app leaderboard
- Device IDs / approximate location (IP) / crash / diagnostics / app interactions
  for Firebase
- Encrypted in transit: Yes
- Account deletion: request via GitHub issues (see privacy policy); no in-app delete yet

Government apps: No
Financial features: No
Health: No
News: No
COVID-19: No
```

- [ ] **Step 2: Mirror in Play Console**

In Play Console → App content, update **App access** and any stale “no account” answers to match the crib sheet. (Manual Console clicks; no API for all fields.)

- [ ] **Step 3: Commit** (only if user asked)

```bash
git add play/app_content_answers.txt
git commit -m "$(cat <<'EOF'
docs: refresh Play App content answers for Auth

EOF
)"
```

---

### Task 3: Update Data Safety CSV for Auth

**Files:**
- Modify: `play/data_safety.csv`

**Interfaces:**
- Consumes: Spec Data Safety rules (OAuth, deletion URL = privacy page, Name / User IDs / Photos)
- Produces: CSV accepted by `play/upload_data_safety.py`

Google’s CSV template only has `PSL_DATA_USAGE_ONLY_COLLECTED` and `PSL_DATA_USAGE_ONLY_SHARED` for the collected/shared question. For Name and Photos (shown on leaderboard), declare **shared** (`ONLY_SHARED`) and set both collection and sharing purposes where the row exists. For User IDs (Firebase uid stored and readable on leaderboard docs), same pattern. Photos are optional for the user → `DATA_USAGE_USER_CONTROL_OPTIONAL`. Name/User IDs required for signed-in play → `DATA_USAGE_USER_CONTROL_REQUIRED`.

- [ ] **Step 1: Account creation + deletion**

In `play/data_safety.csv`, change these response-value cells (column 3):

| Question ID | Response ID | New Response value |
|-------------|-------------|--------------------|
| `PSL_SUPPORTED_ACCOUNT_CREATION_METHODS` | `PSL_ACM_OAUTH` | `true` |
| `PSL_SUPPORTED_ACCOUNT_CREATION_METHODS` | `PSL_ACM_NONE` | _(empty)_ |
| `PSL_ACCOUNT_DELETION_URL` | _(empty response id)_ | `https://muhammedfaseencm.github.io/winklo/privacy/` |
| `PSL_SUPPORT_DATA_DELETION_BY_USER` | `DATA_DELETION_YES` | `true` |
| `PSL_SUPPORT_DATA_DELETION_BY_USER` | `DATA_DELETION_NO` | _(empty)_ |

Exact line edits (search-replace):

```csv
PSL_SUPPORTED_ACCOUNT_CREATION_METHODS,PSL_ACM_OAUTH,true,MULTIPLE_CHOICE,Which of the following methods of account creation does your app support? Select all that apply/OAuth
PSL_SUPPORTED_ACCOUNT_CREATION_METHODS,PSL_ACM_NONE,,MULTIPLE_CHOICE,Which of the following methods of account creation does your app support? Select all that apply/My app does not allow users to create an account
PSL_ACCOUNT_DELETION_URL,,https://muhammedfaseencm.github.io/winklo/privacy/,MAYBE_REQUIRED,Add a link that users can use to request that their account and associated data be deleted
PSL_SUPPORT_DATA_DELETION_BY_USER,DATA_DELETION_YES,true,SINGLE_CHOICE,Do you provide a way for users to request that their data is deleted?/Yes
PSL_SUPPORT_DATA_DELETION_BY_USER,DATA_DELETION_NO,,SINGLE_CHOICE,Do you provide a way for users to request that their data is deleted?/No
```

- [ ] **Step 2: Declare Name, User IDs, Photos**

```csv
PSL_DATA_TYPES_PERSONAL,PSL_NAME,true,MULTIPLE_CHOICE,Personal info/Name
PSL_DATA_TYPES_PERSONAL,PSL_USER_ACCOUNT,true,MULTIPLE_CHOICE,Personal info/User IDs
PSL_DATA_TYPES_PHOTOS_AND_VIDEOS,PSL_PHOTOS,true,MULTIPLE_CHOICE,Photos and videos/Photos
```

- [ ] **Step 3: Name usage rows**

Set (leave other Name purpose rows empty):

```csv
PSL_DATA_USAGE_RESPONSES:PSL_NAME:PSL_DATA_USAGE_COLLECTION_AND_SHARING,PSL_DATA_USAGE_ONLY_SHARED,true,MULTIPLE_CHOICE,"Data usage and handling (Name)/Is this data collected, shared or both?/Shared"
PSL_DATA_USAGE_RESPONSES:PSL_NAME:DATA_USAGE_USER_CONTROL,PSL_DATA_USAGE_USER_CONTROL_REQUIRED,true,SINGLE_CHOICE,"Data usage and handling (Name)/Is this data required for your app, or can users choose whether it's collected?/Data collection is required (users can't turn off this data collection)"
PSL_DATA_USAGE_RESPONSES:PSL_NAME:DATA_USAGE_COLLECTION_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (Name)/Why is this user data collected? Select all that apply./App functionality
PSL_DATA_USAGE_RESPONSES:PSL_NAME:DATA_USAGE_COLLECTION_PURPOSE,PSL_ACCOUNT_MANAGEMENT,true,MULTIPLE_CHOICE,Data usage and handling (Name)/Why is this user data collected? Select all that apply./Account management
PSL_DATA_USAGE_RESPONSES:PSL_NAME:DATA_USAGE_SHARING_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (Name)/Why is this user data shared? Select all that apply./App functionality
```

- [ ] **Step 4: User IDs usage rows**

```csv
PSL_DATA_USAGE_RESPONSES:PSL_USER_ACCOUNT:PSL_DATA_USAGE_COLLECTION_AND_SHARING,PSL_DATA_USAGE_ONLY_SHARED,true,MULTIPLE_CHOICE,"Data usage and handling (User IDs)/Is this data collected, shared or both?/Shared"
PSL_DATA_USAGE_RESPONSES:PSL_USER_ACCOUNT:DATA_USAGE_USER_CONTROL,PSL_DATA_USAGE_USER_CONTROL_REQUIRED,true,SINGLE_CHOICE,"Data usage and handling (User IDs)/Is this data required for your app, or can users choose whether it's collected?/Data collection is required (users can't turn off this data collection)"
PSL_DATA_USAGE_RESPONSES:PSL_USER_ACCOUNT:DATA_USAGE_COLLECTION_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (User IDs)/Why is this user data collected? Select all that apply./App functionality
PSL_DATA_USAGE_RESPONSES:PSL_USER_ACCOUNT:DATA_USAGE_COLLECTION_PURPOSE,PSL_ACCOUNT_MANAGEMENT,true,MULTIPLE_CHOICE,Data usage and handling (User IDs)/Why is this user data collected? Select all that apply./Account management
PSL_DATA_USAGE_RESPONSES:PSL_USER_ACCOUNT:DATA_USAGE_SHARING_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (User IDs)/Why is this user data shared? Select all that apply./App functionality
```

- [ ] **Step 5: Photos usage rows**

```csv
PSL_DATA_USAGE_RESPONSES:PSL_PHOTOS:PSL_DATA_USAGE_COLLECTION_AND_SHARING,PSL_DATA_USAGE_ONLY_SHARED,true,MULTIPLE_CHOICE,"Data usage and handling (Photos)/Is this data collected, shared or both?/Shared"
PSL_DATA_USAGE_RESPONSES:PSL_PHOTOS:DATA_USAGE_USER_CONTROL,PSL_DATA_USAGE_USER_CONTROL_OPTIONAL,true,SINGLE_CHOICE,"Data usage and handling (Photos)/Is this data required for your app, or can users choose whether it's collected?/Users can choose whether this data is collected"
PSL_DATA_USAGE_RESPONSES:PSL_PHOTOS:DATA_USAGE_COLLECTION_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (Photos)/Why is this user data collected? Select all that apply./App functionality
PSL_DATA_USAGE_RESPONSES:PSL_PHOTOS:DATA_USAGE_COLLECTION_PURPOSE,PSL_ACCOUNT_MANAGEMENT,true,MULTIPLE_CHOICE,Data usage and handling (Photos)/Why is this user data collected? Select all that apply./Account management
PSL_DATA_USAGE_RESPONSES:PSL_PHOTOS:DATA_USAGE_SHARING_PURPOSE,PSL_APP_FUNCTIONALITY,true,MULTIPLE_CHOICE,Data usage and handling (Photos)/Why is this user data shared? Select all that apply./App functionality
```

Keep existing `true` rows for approximate location, crash logs, diagnostics, app interactions, and device IDs unchanged.

- [ ] **Step 6: Upload Data Safety**

```bash
python3 play/upload_data_safety.py
```

Expected: `Uploaded Data safety labels for com.winklo.faseencm`

If the API returns a validation error about collected vs shared, open Play Console → App content → Data safety and set Name / User IDs / Photos to **Collected and shared** manually, then re-export or leave Console as source of truth and fix the CSV to match.

- [ ] **Step 7: Commit** (only if user asked)

```bash
git add play/data_safety.csv
git commit -m "$(cat <<'EOF'
chore: update Play Data Safety for Google Sign-In

EOF
)"
```

---

### Task 4: Native Android permission audit

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (only if a forbidden permission slipped in)

**Interfaces:**
- Consumes: Spec permission table
- Produces: Manifest with INTERNET / POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED / VIBRATE; AD_ID removed; no media/storage

- [ ] **Step 1: Audit merged permissions**

```bash
rg -n "uses-permission|AD_ID|READ_MEDIA|READ_EXTERNAL|CAMERA|RECORD_AUDIO" android/app/src/main/AndroidManifest.xml
```

Expected present: `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, and AD_ID/`ACCESS_ADSERVICES_AD_ID` with `tools:node="remove"`. Expected absent: `READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`, `CAMERA`.

- [ ] **Step 2: Confirm release merge does not re-add AD_ID**

```bash
# After a local release assemble if available; otherwise skip if assemble is slow
./gradlew :app:processReleaseManifest --quiet 2>/dev/null || true
# Inspect merged manifest if generated:
rg -n "AD_ID|READ_MEDIA|READ_EXTERNAL" android/app/build/intermediates/merged_manifests/release/ 2>/dev/null || echo "merged manifest not present yet; re-check after Task 8 build"
```

- [ ] **Step 3: Commit only if you changed the manifest** (and user asked)

No code change is the happy path.

---

### Task 5: Publish privacy to GitHub Pages

**Files:**
- Already modified: `docs/privacy/index.html` (Task 1)

**Interfaces:**
- Consumes: Updated HTML on a branch that can reach `master`
- Produces: `https://muhammedfaseencm.github.io/winklo/privacy/` serving the new text

GitHub Pages source: **`master` branch, `/docs` path**.

- [ ] **Step 1: Land privacy on `master`**

Merge or cherry-pick the privacy commit onto `master` and push (requires network + user approval for push):

```bash
git push origin HEAD   # if releasing from feature branch workflow that merges to master
# Or after PR merge to master:
git checkout master && git pull && git push origin master
```

Exact branching is operator choice; success criterion is `master` containing the new `docs/privacy/index.html`.

- [ ] **Step 2: Verify Pages**

```bash
curl -sL "https://muhammedfaseencm.github.io/winklo/privacy/" | rg -n "Last updated: 25 September 2026|Google Sign-In|account deletion"
```

Expected: matches. If stale, wait for Pages build (`gh api repos/MuhammedFaseenCM/winklo/pages`) and retry.

---

### Task 6: Firebase SHA, rules, and Auth check

**Files:**
- Possibly update: `android/app/google-services.json` (download from console if prompted)
- Deploy: `firestore/firestore.rules`, `firestore/firestore.indexes.json`

**Interfaces:**
- Consumes: Upload keystore at `android/upload-keystore.jks`, alias `upload`
- Produces: Release SHA registered; rules live; Google provider enabled

- [ ] **Step 1: Print release fingerprints** (do not log keystore passwords)

```bash
# Reads storePassword from android/key.properties locally; do not paste passwords into chat/logs
keytool -list -v -keystore android/upload-keystore.jks -alias upload \
  -storepass "$(python3 -c "import pathlib; print(dict(l.strip().split('=',1) for l in pathlib.Path('android/key.properties').read_text().splitlines() if '=' in l)['storePassword'])")" \
  | rg "SHA1:|SHA256:"
```

Expected (current upload key):

```
SHA1: 1F:85:8B:9D:9D:1A:A4:32:89:7D:10:62:76:DC:B5:BC:49:F0:AD:B8
SHA256: 1E:9F:CE:70:26:F1:ED:CA:7D:AC:F2:8D:45:F9:18:43:5B:92:4B:C1:ED:2C:78:E9:D8:DD:04:06:D9:CC:98:7E
```

If fingerprints differ, use the values printed by your keystore.

- [ ] **Step 2: Register SHA in Firebase Console**

Firebase Console → Project settings → Your apps → Android `com.winklo.faseencm` → Add fingerprint → paste SHA-1 and SHA-256 → Save. Download `google-services.json` into `android/app/` if the console prompts.

- [ ] **Step 3: Confirm Google Sign-In provider**

Authentication → Sign-in method → Google → Enabled.

- [ ] **Step 4: Deploy Firestore rules and indexes**

```bash
firebase deploy --only firestore:rules,firestore:indexes --project brain-zip-app
```

Expected: deploy success. (Skip `storage` unless you still use Firebase Storage for something; avatars are on R2.)

- [ ] **Step 5: Commit google-services.json only if it changed** (and user asked)

---

### Task 7: Deploy Cloudflare Workers

**Files:**
- Deploy from: `workers/avatar-upload/`, `workers/path-words-nouns/`
- Verify defaults in: `lib/core/config/avatar_upload_config.dart`, `lib/core/config/path_words_nouns_config.dart`

**Interfaces:**
- Produces: Healthy production Workers matching app default base URLs

- [ ] **Step 1: Deploy avatar upload Worker**

```bash
cd workers/avatar-upload
npm install
npm test
npm run deploy
cd ../..
```

Expected: deploy URL for `winklo-avatar-upload` (default app expects `https://winklo-avatar-upload.winklo.workers.dev`).

- [ ] **Step 2: Deploy path-words nouns Worker**

```bash
cd workers/path-words-nouns
npm install
npm test
npm run deploy
cd ../..
```

Expected: deploy URL for `winklo-path-words-nouns` (default `https://winklo-path-words-nouns.winklo.workers.dev`).

- [ ] **Step 3: Health checks**

```bash
curl -sS "https://winklo-avatar-upload.winklo.workers.dev/v1/health"
curl -sS "https://winklo-path-words-nouns.winklo.workers.dev/v1/health"
```

Expected each: `{"ok":true}` (or equivalent ok JSON).

- [ ] **Step 4: Confirm Flutter defaults**

```bash
rg -n "defaultValue:" lib/core/config/avatar_upload_config.dart lib/core/config/path_words_nouns_config.dart
```

If deployed hostnames differ from defaults, either update the `defaultValue` strings in those two files **or** pass matching `--dart-define`s in Task 8. Prefer updating defaults so Play builds do not require hidden defines.

---

### Task 8: Stabilize WIP, bump version, build signed AAB

**Files:**
- Modify: `pubspec.yaml` (`version: 1.0.0+4`)
- Product WIP as already in the working tree (auth, leaderboard, profile, avatars, nouns, notifications, UI)

**Interfaces:**
- Consumes: Release keystore present (`android/key.properties` + `upload-keystore.jks`)
- Produces: `build/app/outputs/bundle/release/app-release.aab` with versionCode 4

- [ ] **Step 1: Gate on tests**

```bash
flutter test
```

Expected: all tests pass. Fix failures before continuing (this is the “ship everything” gate).

- [ ] **Step 2: Bump version**

In `pubspec.yaml` set:

```yaml
version: 1.0.0+4
```

- [ ] **Step 3: Build release AAB**

```bash
flutter build appbundle --release
```

Only add dart-defines if Task 7 defaults are wrong:

```bash
flutter build appbundle --release \
  --dart-define=AVATAR_UPLOAD_BASE_URL=https://winklo-avatar-upload.winklo.workers.dev \
  --dart-define=PATH_WORDS_NOUNS_BASE_URL=https://winklo-path-words-nouns.winklo.workers.dev
```

Expected output path: `build/app/outputs/bundle/release/app-release.aab`.

- [ ] **Step 4: Confirm release signing (not debug)**

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab 2>&1 | rg -i "signed|CN=|jar verified" | head -20
```

Expected: jar verified; signer is the upload key (not Android Debug). If debug-signed, stop — `android/key.properties` / keystore missing from the build machine.

- [ ] **Step 5: Commit version bump** (only if user asked)

```bash
git add pubspec.yaml
git commit -m "$(cat <<'EOF'
chore: bump version to 1.0.0+4 for closed testing

EOF
)"
```

---

### Task 9: Upload AAB to Play closed testing

**Files:**
- Uses: `fastlane/Fastfile` lane `closed`, `play/play-service-account.json`

**Interfaces:**
- Consumes: AAB at `build/app/outputs/bundle/release/app-release.aab`
- Produces: Version code 4 on Play track `alpha` (closed)

- [ ] **Step 1: Upload**

From repo root (with Fastlane installed):

```bash
bundle exec fastlane android closed
# or, if bundler not used:
fastlane android closed
```

Expected: upload success for track `alpha`. If you also want internal: `fastlane android testing`.

- [ ] **Step 2: Confirm in Play Console**

Closed testing → Releases → version **1.0.0** version code **4** available / rolling out to the closed testers list.

---

### Task 10: Publish Remote Config force-update

**Files:**
- None in repo (Firebase Console / optional note in `FIREBASE.md`)

**Interfaces:**
- Consumes: Spec RC table; **requires** Task 9 complete so testers can install +4
- Produces: Old +1…+3 installs see forced Home overlay

- [ ] **Step 1: Publish parameters**

Firebase Console → Remote Config → set and **Publish**:

| Key | Value |
|-----|-------|
| `appVersion` | `1.0.0` |
| `minBuildNumber` | `4` |
| `forceUpdate` | `true` |
| `playStoreUrl` | `https://play.google.com/store/apps/details?id=com.winklo.faseencm` |

- [ ] **Step 2: Optional doc note**

Append a short “Closed testing +4” operator note to `FIREBASE.md` §6 with these values (optional; skip if user prefers Console-only).

---

### Task 11: Closed-track smoke checklist

**Files:**
- None (manual QA)

**Interfaces:**
- Consumes: Tasks 5–10 complete
- Produces: Pass/fail notes; fix blockers before inviting more testers

- [ ] **Step 1: Fresh closed install (+4)**

- Cold start
- Google Sign-In succeeds on the **Play/closed** build (proves release SHA)
- Open Zip → finish → score on leaderboard
- Open Path Words → finish → score on leaderboard
- Profile: edit name; pick preset; optional gallery upload shows on Profile + leaderboard
- Accept/deny notifications path does not crash
- Profile → Privacy policy WebView loads updated Pages content

- [ ] **Step 2: Old build force-update**

On a device still on `1.0.0+3` (or lower): open Home → blocking force-update → Update → install +4 from closed track → resume/Home → overlay gone.

- [ ] **Step 3: Worker spot-checks**

```bash
curl -sS "https://winklo-avatar-upload.winklo.workers.dev/v1/health"
curl -sS "https://winklo-path-words-nouns.winklo.workers.dev/v1/health"
# Optional nouns for today UTC yyyyMMdd:
date -u +%Y%m%d
curl -sS "https://winklo-path-words-nouns.winklo.workers.dev/v1/path-words/nouns?dateId=$(date -u +%Y%m%d)" | head -c 200
```

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| Privacy rewrite + contact-only deletion | 1, 5 |
| `app_content_answers` | 2 |
| `data_safety.csv` + upload | 3 |
| Native permission audit / no media perms | 4 |
| GitHub Pages privacy publish | 5 |
| Firebase SHA + rules + Google provider | 6 |
| Workers deploy + health | 7 |
| Ship full WIP + `1.0.0+4` signed AAB | 8 |
| Fastlane closed upload | 9 |
| Force RC after +4 live | 10 |
| Smoke (+ old build force) | 11 |
| No in-app delete / no iOS / no production | Out of scope (not tasked) |

## Placeholder / consistency scan

- Version `1.0.0+4` used consistently
- Privacy deletion URL = Pages privacy URL (matches Data Safety)
- Worker default hosts match health-check URLs
- Upload keystore SHA values documented; re-print if keystore rotated
