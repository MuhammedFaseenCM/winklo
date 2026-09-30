# Debug leaderboard collection — Design

**Date:** 2026-09-25  
**Status:** Approved for planning  
**Related:** `FIREBASE.md` §7, `tools/seed_leaderboard_demo.mjs`, closed-testing prep

## Goal

Keep demo / local-debug leaderboard traffic off the production boards. Debug builds read and write a twin Firestore tree; release and profile builds keep using the current `leaderboards` collections.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Debug write destination | Debug collection only (never prod) |
| Collection shape | Top-level twin: `leaderboards_debug/{gameId}/…` mirroring prod |
| Switch | `kDebugMode` → debug root; release/profile → `leaderboards` |
| Implementation | Single root-selector helper shared by leaderboard + profile denormalize |
| Demo seed | Seeds / clears **only** `leaderboards_debug` |

## Out of scope

- Separate Firebase projects / environments
- Manual DevFlag override to force prod boards while debugging
- Migrating or deleting historical demo docs already removed from prod
- UI badge indicating “debug board”

---

## Data paths

**Production (unchanged):**

```
leaderboards/{gameId}/all_time/{uid}
leaderboards/{gameId}/daily/{yyyy-MM-dd}/entries/{uid}
```

**Debug (new twin):**

```
leaderboards_debug/{gameId}/all_time/{uid}
leaderboards_debug/{gameId}/daily/{yyyy-MM-dd}/entries/{uid}
```

Same fields, ranking, and `gameId` allow-list (`zip`, `path_words`) as prod. Doc IDs for seed fakes remain `demo_001` … under the **debug** tree only.

---

## App behavior

### Root selector

Add a small shared helper (e.g. in `lib/data/` or `lib/core/firebase/`) that returns:

- `'leaderboards_debug'` when `kDebugMode` is true
- `'leaderboards'` otherwise

All Firestore leaderboard path construction goes through this helper. No hardcoded `'leaderboards'` string left in write/watch/denormalize paths.

### Call sites

1. **`LeaderboardRepositoryImpl`**
   - `watchBoard` collection path
   - `submitBestTime` all-time + daily refs
2. **`ProfileRepositoryImpl._denormalizeLeaderboards`**
   - Identity patches (displayName / photoUrl / avatarId) only touch docs under the active root

Domain interfaces and UI stay unchanged; they do not know which root is active.

### Builds

| Build | Root |
|-------|------|
| `flutter run` / debug | `leaderboards_debug` |
| `flutter run --profile` | `leaderboards` |
| Release / Play AAB | `leaderboards` |

Closed-testing and production therefore never read demo seed data unless it was written into prod (which the seed script must not do).

---

## Firestore rules

Mirror the existing `leaderboards/{gameId}/…` match blocks for `leaderboards_debug/{gameId}/…` (same `validGame`, owner create/update, improve-only + profile-only update, public read). Deploy rules before relying on signed-in debug submits against the twin.

No change to `users/{uid}` or other collections.

---

## Seed tool

Update `tools/seed_leaderboard_demo.mjs`:

- Write all demo docs under `leaderboards_debug` only (REST and Admin paths)
- Default run seeds debug boards; `CLEAR=1` deletes `demo_*` under `leaderboards_debug` **without** re-seeding (works on both CLI-token and Admin paths)
- Docs in `FIREBASE.md` updated to state debug-only seeding

Running the seed while developing populates the board that debug builds already query.

---

## Testing

- Unit/repo tests: inject or override root (or assert helper returns expected values for documented modes); existing mapper/submit logic stays covered
- No requirement to hit live Firestore in CI
- Manual: debug run shows seeded `demo_*` rows; release/profile build (or console check of `leaderboards`) has no new demo writes from the updated seed

---

## Success criteria

- Debug build watch + submit + profile name/avatar patch use only `leaderboards_debug`
- Release/profile builds use only `leaderboards`
- Seed script cannot write `demo_*` into prod `leaderboards`
- Rules allow the same client behavior on the debug twin as on prod
- `FIREBASE.md` describes both roots and the `kDebugMode` switch

## Non-goals

- Showing prod leaderboard data inside a debug build
- Automating deletion of any leftover prod `demo_*` docs (already cleared separately if needed)
