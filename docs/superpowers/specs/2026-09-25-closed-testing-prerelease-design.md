# Closed testing pre-release (1.0.0+4) — Design

**Date:** 2026-09-25  
**Status:** Approved for planning  
**Track:** Google Play closed testing (alpha)  
**Package:** `com.winklo.faseencm`

## Goal

Ship closed-testing build **`1.0.0+4`** with the full current app experience after auth and leaderboard (plus profile, avatars, notifications, Path Words noun pool, UI polish), and complete Play / Firebase / Worker prep so testers are not blocked.

Previous closed builds are **`1.0.0+1` … `1.0.0+3`**. This drop is the first closed release that includes Google Sign-In and realtime leaderboards.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope of work | Full checklist: backend/ops + Play compliance + native permissions + privacy + bump/build/upload |
| Product slice | Ship everything currently intended for closed testing (stabilize WIP, then release) |
| Account deletion | Contact-only for this drop (GitHub issues); no in-app delete |
| Play App access | Any Google account works; no dedicated reviewer credentials |
| Old installs (+1…+3) | Hard force update via Remote Config after +4 is live |
| Execution style | Single sequential runbook (compliance → backend → build → upload → force RC → smoke) |
| Platforms | Android only |

## Out of scope

- In-app account deletion
- iOS / App Store
- Open testing or production rollout
- New product features beyond stabilizing current WIP for this build

## Approach

One ordered runbook. Do not upload the AAB before Firebase SHA, rules, and Workers are ready. Publish privacy Pages before testers open the in-app Privacy screen. Publish Remote Config force-update **only after** `1.0.0+4` is available on the closed track.

---

## 1. Compliance & privacy

### Privacy policy (`docs/privacy/index.html` → GitHub Pages)

URL (unchanged): `https://muhammedfaseencm.github.io/winklo/privacy/`

Rewrite so the policy matches the shipping product:

- Google Sign-In is required for Zip and Path Words, and for leaderboard / profile cloud features.
- Cloud data may include: Firebase uid, display name, photo URL or preset avatar id, personal-best times (leaderboards), FCM token.
- Custom gallery photos upload through the Cloudflare Worker to R2 and are served as public `r2.dev` URLs. Gallery pick is optional and uses the system Photo Picker (no broad media/storage permission).
- Local notifications and FCM topic messages (`announcements`, `app_updates`).
- Firebase Analytics, Crashlytics (release), Remote Config, Firestore content catalogs — same intent as today.
- No ads. Advertising ID is not used for advertising (manifest removes AD_ID; Analytics ADID collection disabled).
- **Deletion (contact-only):** Users request deletion by opening a GitHub issue on the Winklo repo, including the Google account email used to sign in and Firebase uid if known. Operators manually delete profile, leaderboard entries, and R2 avatar object within **30 days**. State clearly that there is no in-app delete yet.
- Remove outdated claims such as “you do not create an account,” “we do not require sign-in,” and “scores stay only on your phone” where cloud sync now applies.
- Update “Last updated” date.

### Play Console docs in repo

**`play/app_content_answers.txt`**

- Privacy policy URL unchanged.
- App access: not restricted beyond Google Sign-In; reviewers/testers use **any** Google account.
- Ads: no.
- Replace “Account creation: none” / “cannot request cloud deletion” with OAuth (Google) and contact-only deletion via GitHub issues (link privacy or issues URL).

**`play/data_safety.csv`**

Align with Auth + profile + leaderboard + photos:

- Account creation: **OAuth** (not “none”).
- User deletion support: **Yes**, with deletion request URL set to the privacy policy page (which instructs users to open a GitHub issue).
- Declare personal data types as collected where accurate: **Name**, **User IDs**, **Photos** (optional gallery / Google photo URL). Mark **shared** where leaderboard display shares name/photo/avatar with other users in-app.
- Keep existing Analytics/Crashlytics/device ID / approximate location (IP) disclosures unless a field is no longer true.
- Re-upload via `play/upload_data_safety.py` (or Console) before or with the closed release.

### Native Android permissions

Audit `android/app/src/main/AndroidManifest.xml`:

| Permission / entry | Action |
|--------------------|--------|
| `INTERNET` | Keep |
| `POST_NOTIFICATIONS` | Keep |
| `RECEIVE_BOOT_COMPLETED` | Keep |
| `VIBRATE` | Keep |
| `AD_ID` / `ACCESS_ADSERVICES_AD_ID` with `tools:node="remove"` | Keep |
| `google_analytics_adid_collection_enabled=false` | Keep |
| `READ_MEDIA_*` / `READ_EXTERNAL_STORAGE` / camera | **Do not add** (`image_picker` stays Photo Picker–only) |

No permission expansion for this release unless a dependency forces a documented, justified addition (prefer avoiding).

---

## 2. Backend & ops

### Firebase

1. Deploy current Firestore rules (and indexes / storage rules if changed):  
   `firebase deploy --only firestore:rules,firestore:indexes` (add `storage` only if still used).
2. Confirm Authentication → Google provider is enabled.
3. Register **upload keystore** SHA-1 and SHA-256 on the Android app `com.winklo.faseencm` (Project settings). Debug fingerprints alone are insufficient for Play/closed release builds.
4. Download updated `google-services.json` into `android/app/` if the console requires it after SHA registration.

### Cloudflare Workers

1. Deploy `workers/avatar-upload` (`winklo-avatar-upload`) — R2 bucket public URL and `FIREBASE_PROJECT_ID` already in wrangler where configured.
2. Deploy `workers/path-words-nouns` (`winklo-path-words-nouns`) — KV + Workers AI as configured.
3. Release AAB must call production Worker base URLs (app defaults in config classes, or `--dart-define` overrides if defaults are wrong).
4. Smoke: `GET /v1/health` on both Workers; optional signed-in gallery upload once +4 is installed.

### Remote Config (after +4 is live on closed)

| Key | Value |
|-----|-------|
| `appVersion` | `1.0.0` |
| `minBuildNumber` | `4` |
| `forceUpdate` | `true` |
| `playStoreUrl` | `https://play.google.com/store/apps/details?id=com.winklo.faseencm` |

Installs below `1.0.0+4` see the blocking Home force-update overlay until they update from the closed track.

Do **not** publish these values before `+4` is available to testers (or old builds brick with no update target).

---

## 3. Build, upload & verification

### Build

1. Stabilize and include all WIP intended for closed (auth, leaderboard, profile, R2 avatars, Path Words nouns, notifications, UI polish). Critical tests green.
2. Bump `pubspec.yaml` version to **`1.0.0+4`**.
3. `flutter build appbundle --release` with release signing (`android/key.properties` + upload keystore). Pass Worker `--dart-define`s only if defaults are incorrect.
4. Confirm the AAB is release-signed (not falling back to debug when keystore is missing).

### Upload

1. Upload updated Data Safety (and listing text/graphics if changed) via `play/` scripts / `fastlane android listing`.
2. Upload AAB with `fastlane android closed` (or `testing` if internal + closed assignment is desired).

Privacy Pages publish happens earlier in the execution order (right after the HTML rewrite), not after the AAB upload.

### Smoke checklist (closed track)

- Cold start on a release/closed install
- Google Sign-In succeeds (release SHA registered)
- Zip and Path Words play; scores appear on leaderboard
- Profile: name, preset avatar, optional gallery upload
- Notification permission path behaves as designed
- Install on old `+3`: force-update overlay → open Play → update → overlay clears on resume/Home

### Execution order

1. Compliance docs (privacy, `app_content_answers`, `data_safety.csv`)
2. Publish privacy HTML to GitHub Pages (so the live URL matches Auth before any tester opens it)
3. Firebase SHA + rules/indexes deploy
4. Workers deploy + health checks
5. Version bump + signed AAB
6. Play Data Safety / listing upload as needed
7. Fastlane closed upload
8. Remote Config force-update publish
9. Smoke on closed track (+ force-update on old build)

---

## Success criteria

- Closed track shows version **`1.0.0 (4)`** (or equivalent Play labeling for build 4).
- New testers can sign in with any Google account and use Zip, Path Words, leaderboard, and profile.
- Privacy policy and Data Safety no longer claim “no account.”
- Old closed installs below build 4 are force-prompted to update.
- Gallery avatar works when Worker URL is configured; Path Words daily nouns resolve from the Worker (or documented fallback).

## Non-goals for operators during this drop

- Automating account deletion
- Changing `applicationId`
- Shipping to production / open testing
