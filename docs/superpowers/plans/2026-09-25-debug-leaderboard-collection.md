# Debug Leaderboard Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route debug builds to a twin `leaderboards_debug` Firestore tree (watch, submit, profile patches, demo seed) while release/profile builds keep using `leaderboards`.

**Architecture:** One root-selector helper (`leaderboardRootCollection`) gated by `kDebugMode`. `LeaderboardRepositoryImpl` and `ProfileRepositoryImpl` build all board paths through it. Mirror security rules for the twin. Seed script writes/clears only `leaderboards_debug`, with `CLEAR=1` deleting without re-seed.

**Tech Stack:** Flutter/Dart (`foundation.kDebugMode`), Cloud Firestore, existing Firebase Auth rules helpers, Node seed script (`tools/seed_leaderboard_demo.mjs`).

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-debug-leaderboard-collection-design.md`
- Debug root: `leaderboards_debug`; prod root: `leaderboards`
- Switch: `kDebugMode` only (no DevFlag override)
- Debug builds write **only** to debug root; never dual-write
- Domain stays free of collection-root knowledge (helper lives in data/core)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/data/leaderboard_root.dart` | `leaderboardRootCollection({bool? isDebugMode})` → root name |
| `test/data/leaderboard_root_test.dart` | Unit tests for both roots |
| `lib/data/repositories/leaderboard_repository_impl.dart` | Watch + submit use helper |
| `lib/data/repositories/profile_repository_impl.dart` | Denormalize patches use helper |
| `firestore/firestore.rules` | Mirror match blocks for `leaderboards_debug` |
| `tools/seed_leaderboard_demo.mjs` | Seed/clear debug root only; CLEAR without re-seed |
| `FIREBASE.md` | Document both roots + seed behavior |

Existing collection-group indexes on `all_time` / `entries` already cover the twin (same leaf collection IDs). Do **not** change `firestore.indexes.json` unless a runtime index error appears.

---

### Task 1: Root selector helper

**Files:**
- Create: `lib/data/leaderboard_root.dart`
- Create: `test/data/leaderboard_root_test.dart`

**Interfaces:**
- Produces: `String leaderboardRootCollection({bool? isDebugMode})`
  - When `isDebugMode ?? kDebugMode` is true → `'leaderboards_debug'`
  - Else → `'leaderboards'`

- [ ] **Step 1: Write the failing test**

Create `test/data/leaderboard_root_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/leaderboard_root.dart';

void main() {
  group('leaderboardRootCollection', () {
    test('returns leaderboards_debug when isDebugMode is true', () {
      expect(
        leaderboardRootCollection(isDebugMode: true),
        'leaderboards_debug',
      );
    });

    test('returns leaderboards when isDebugMode is false', () {
      expect(
        leaderboardRootCollection(isDebugMode: false),
        'leaderboards',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/leaderboard_root_test.dart`

Expected: FAIL — `leaderboard_root.dart` missing / function undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/leaderboard_root.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Top-level Firestore collection for Zip / Path Words leaderboards.
///
/// Debug builds use [leaderboards_debug] so demo seeds and local submits
/// never touch production [leaderboards].
String leaderboardRootCollection({bool? isDebugMode}) {
  final debug = isDebugMode ?? kDebugMode;
  return debug ? 'leaderboards_debug' : 'leaderboards';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/leaderboard_root_test.dart`

Expected: PASS (2 tests).

- [ ] **Step 5: Format + analyze**

Run:

```bash
dart format lib/data/leaderboard_root.dart test/data/leaderboard_root_test.dart
dart analyze lib/data/leaderboard_root.dart test/data/leaderboard_root_test.dart
```

Expected: no issues.

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/data/leaderboard_root.dart test/data/leaderboard_root_test.dart
git commit -m "$(cat <<'EOF'
Add leaderboard root selector for debug vs prod boards.

EOF
)"
```

---

### Task 2: Wire repositories to the root helper

**Files:**
- Modify: `lib/data/repositories/leaderboard_repository_impl.dart`
- Modify: `lib/data/repositories/profile_repository_impl.dart`
- Test: `test/data/repositories/leaderboard_repository_impl_test.dart` (existing pure-mapper tests still pass; no Firestore fake required)

**Interfaces:**
- Consumes: `leaderboardRootCollection()` from Task 1
- Produces: all watch/submit/denormalize paths under the active root

- [ ] **Step 1: Update `LeaderboardRepositoryImpl`**

Add import:

```dart
import '../leaderboard_root.dart';
```

In `_boardCollection`, replace:

```dart
final gameRef = db.collection('leaderboards').doc(gameId);
```

with:

```dart
final gameRef = db.collection(leaderboardRootCollection()).doc(gameId);
```

In `submitBestTime`, replace both hardcoded roots:

```dart
final root = leaderboardRootCollection();
final allTimeRef = db
    .collection(root)
    .doc(gameId)
    .collection('all_time')
    .doc(user.uid);
final dailyRef = db
    .collection(root)
    .doc(gameId)
    .collection('daily')
    .doc(dayId)
    .collection('entries')
    .doc(user.uid);
```

Confirm there are **no** remaining `'leaderboards'` string literals in this file.

- [ ] **Step 2: Update `ProfileRepositoryImpl._denormalizeLeaderboards`**

Add import:

```dart
import '../leaderboard_root.dart';
```

Replace the game ref construction:

```dart
final root = leaderboardRootCollection();
for (final gameId in [GameIds.zip, GameIds.pathWords]) {
  final game = db.collection(root).doc(gameId);
  refs.add(game.collection('all_time').doc(user.uid));
  refs.add(
    game
        .collection('daily')
        .doc(dayId)
        .collection('entries')
        .doc(user.uid),
  );
}
```

Confirm no remaining `'leaderboards'` literals in this file.

- [ ] **Step 3: Grep for leftover hardcoded roots in `lib/`**

Run: `rg -n "collection\\('leaderboards'\\)|'leaderboards'" lib/`

Expected: no matches in repository path construction (helper file may mention the string as return values only).

- [ ] **Step 4: Run existing leaderboard + profile repo tests**

Run:

```bash
flutter test test/data/repositories/leaderboard_repository_impl_test.dart test/data/repositories/profile_repository_impl_test.dart test/data/leaderboard_root_test.dart
```

Expected: PASS.

- [ ] **Step 5: Format + analyze changed files**

Run:

```bash
dart format lib/data/repositories/leaderboard_repository_impl.dart lib/data/repositories/profile_repository_impl.dart
dart analyze lib/data/repositories/leaderboard_repository_impl.dart lib/data/repositories/profile_repository_impl.dart
```

Expected: no issues.

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add lib/data/repositories/leaderboard_repository_impl.dart lib/data/repositories/profile_repository_impl.dart
git commit -m "$(cat <<'EOF'
Route leaderboard watch, submit, and profile patches through root helper.

EOF
)"
```

---

### Task 3: Mirror Firestore rules for `leaderboards_debug`

**Files:**
- Modify: `firestore/firestore.rules`

**Interfaces:**
- Produces: identical allow rules under `leaderboards_debug/{gameId}/…` as under `leaderboards/{gameId}/…`

- [ ] **Step 1: Duplicate the two match blocks**

After the existing `leaderboards/{gameId}/daily/...` block (before `issue_reports`), add:

```
    match /leaderboards_debug/{gameId}/all_time/{uid} {
      allow read: if validGame(gameId);
      allow create: if isOwner(uid)
        && validGame(gameId)
        && validTimeSeconds()
        && validLeaderboardKeys();
      allow update: if isOwner(uid)
        && validGame(gameId)
        && (
          (improvingTime() && validLeaderboardKeys())
          || profileOnlyLeaderboardUpdate()
        );
      allow delete: if false;
    }

    match /leaderboards_debug/{gameId}/daily/{dayId}/entries/{uid} {
      allow read: if validGame(gameId);
      allow create: if isOwner(uid)
        && validGame(gameId)
        && validTimeSeconds()
        && validLeaderboardKeys();
      allow update: if isOwner(uid)
        && validGame(gameId)
        && (
          (improvingTime() && validLeaderboardKeys())
          || profileOnlyLeaderboardUpdate()
        );
      allow delete: if false;
    }
```

Keep the original `leaderboards` blocks unchanged.

- [ ] **Step 2: Sanity-check rules locally (optional but preferred)**

If the Firebase emulator / `firebase deploy --only firestore:rules --dry-run` is available:

```bash
firebase deploy --only firestore:rules --dry-run
```

Otherwise skip and note that deploy happens with the closed-testing / ops checklist. Do **not** deploy from this task unless the user asks.

- [ ] **Step 3: Commit** (only if user asked)

```bash
git add firestore/firestore.rules
git commit -m "$(cat <<'EOF'
Mirror leaderboard security rules for leaderboards_debug.

EOF
)"
```

---

### Task 4: Point the demo seed at `leaderboards_debug` + fix CLEAR

**Files:**
- Modify: `tools/seed_leaderboard_demo.mjs`
- Modify: `FIREBASE.md` (Demo seed subsection under §7)

**Interfaces:**
- Constant `ROOT = 'leaderboards_debug'`
- Default run: seed debug boards only
- `CLEAR=1`: delete `demo_*` under debug root for both games (all_time + today’s daily), **then exit without seeding**
- Works for CLI-token REST path and Admin path

- [ ] **Step 1: Add root constant and update header comments**

Near the top of `tools/seed_leaderboard_demo.mjs` (after `games`):

```js
/** Debug twin only — never write demo_* into production `leaderboards`. */
const ROOT = 'leaderboards_debug';
```

Update the file header comment to say:

- Seeds `leaderboards_debug` (debug app builds)
- `CLEAR=1` deletes demo docs under that root and does **not** re-seed
- Production `leaderboards` is never touched

- [ ] **Step 2: Implement REST clear + gate seed on CLEAR**

Replace `seedViaRest` path strings to use `` `${ROOT}/${gameId}/...` ``.

Add `clearViaRest(accessToken, dayId)` that builds `delete` writes for `demo_001`…`demo_NNN` (use `count`) under:

- `${ROOT}/${gameId}/all_time/${uid}`
- `${ROOT}/${gameId}/daily/${dayId}/entries/${uid}`

for each `gameId` in `games`, then commits in chunks of 400 (same commit helper as seed).

Change `main` to:

```js
async function main() {
  const dayId = utcDayId();
  const players = demoPlayers(count);
  const clearOnly = process.env.CLEAR === '1';

  console.log(`Root: ${ROOT}`);
  console.log(`Day (UTC): ${dayId}`);
  if (clearOnly) {
    console.log(`CLEAR=1 — deleting demo_001…demo_${String(count).padStart(3, '0')} (no re-seed)`);
  } else {
    console.log(
      `Players: ${players.length} (uids demo_001…demo_${String(count).padStart(3, '0')})`,
    );
  }

  const cliToken = readCliAccessToken();
  if (cliToken) {
    console.log('Auth: Firebase CLI access token');
    if (clearOnly) {
      await clearViaRest(cliToken, dayId);
    } else {
      await seedViaRest(cliToken, players, dayId);
    }
  } else {
    console.log('Auth: service account (Admin SDK)');
    await seedViaAdmin(players, dayId, { clearOnly });
  }

  if (clearOnly) {
    console.log('Done — demo_* removed from leaderboards_debug.');
  } else {
    console.log('Done. Open Leaderboard (Daily / All-time) for Zip and Path Words in a debug build.');
    console.log(
      'Your real account joins after you clear a puzzle (or improve your time).',
    );
  }
}
```

- [ ] **Step 3: Update Admin path**

In `seedViaAdmin(players, dayId, { clearOnly = false } = {})`:

- Use `ROOT` instead of `'leaderboards'` for collection refs
- If `clearOnly`: clear all_time + daily for each game, log counts, **return** (do not call `writePlayers`)
- Else: write players as today (no clear-then-write unless you keep an optional clear-before-seed; default seed should not clear)

- [ ] **Step 4: Update `FIREBASE.md` Demo seed section**

Replace the Demo seed subsection so it states:

- Debug builds read/write `leaderboards_debug`; release uses `leaderboards`
- Seed command populates **only** `leaderboards_debug`
- `CLEAR=1 node tools/seed_leaderboard_demo.mjs` deletes demo docs there without re-seeding

Example:

```markdown
### Demo seed (debug boards only)

Debug / `flutter run` builds use Firestore root `leaderboards_debug` (same shape as `leaderboards`). Release and profile builds use `leaderboards`.

Seed 28 fake players (`demo_001` …) into **debug** Zip + Path Words boards (Daily today UTC + All-time):

```bash
# requires `firebase login` (project brain-zip-app)
node tools/seed_leaderboard_demo.mjs
```

Clear demo docs without re-seeding:

```bash
CLEAR=1 node tools/seed_leaderboard_demo.mjs
```

Never writes to production `leaderboards`.
```

Also add a short note under Data paths listing both roots and the `kDebugMode` switch.

- [ ] **Step 5: Dry-run sanity (optional live)**

If the user wants live verification:

```bash
node tools/seed_leaderboard_demo.mjs
# then in a debug app: open Leaderboard — demo rows appear
CLEAR=1 node tools/seed_leaderboard_demo.mjs
# demo rows gone; prod leaderboards unchanged in Console
```

Skip if offline / no token; do not seed prod.

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add tools/seed_leaderboard_demo.mjs FIREBASE.md
git commit -m "$(cat <<'EOF'
Seed and clear demo leaderboard rows only under leaderboards_debug.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Twin root `leaderboards_debug` | 1, 2, 3, 4 |
| `kDebugMode` switch | 1 |
| Watch + submit use helper | 2 |
| Profile denormalize uses helper | 2 |
| Rules mirrored | 3 |
| Seed only debug + CLEAR without re-seed | 4 |
| `FIREBASE.md` updated | 4 |
| Indexes | Covered by existing collection-group indexes — no task |

## Placeholder / consistency self-review

- Helper name is consistently `leaderboardRootCollection` / optional `isDebugMode`
- Root string values are exactly `leaderboards` and `leaderboards_debug`
- No “TBD” / “similar to Task N” left in steps
- Commit steps are optional per repo commit policy
