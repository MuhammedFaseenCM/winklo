# Guest play — sign-in only for leaderboard — design

Date: 2026-09-26  
Status: approved for implementation

## Goal

Let anyone play Zip and Path Words without signing in. Restrict Google sign-in to **viewing** the live leaderboard (full tab and post-game mini board). Soft-prompt only — no extra finish dialog.

## Product decisions

| Topic | Choice |
|-------|--------|
| Play gate on Home | Removed |
| Leaderboard tab signed-out | Keep blurred mock + sign-in CTA |
| Post-game mini board | Keep soft sign-in hint (choice A) |
| Profile signed-out | Unchanged (name/avatar still require sign-in) |
| Local scores / streaks | SharedPreferences — already auth-free |
| Remote leaderboard write | Still requires Firebase auth |
| After sign-in from results | Best-effort submit that run’s `timeSeconds` |
| Sync all local bests on any sign-in | Out of scope |

## Approach

**Minimal gate removal + results-time sync on sign-in.**

1. Home opens Zip / Path Words without `ensureSignedInForPlay`.
2. Mini board / Leaderboard keep existing signed-out CTAs.
3. When the user signs in from the post-game mini board, call `SubmitLeaderboardTime` once with `ResultsArgs.gameId` + `timeSeconds` (if valid), then show live rankings.
4. Update sign-in / sign-out copy so it no longer says “sign in to play.”

## Architecture

```
Home (signed out or in)
  → Zip / Path Words play (no auth gate)
  → local submitScore + optional submitLeaderboardTime (no-op if signed out)
  → /results MiniLeaderboardPanel(gameId, timeSeconds)
        │
        ├─ signed out → leaderboardSignInHint + Google CTA
        │                 → showSignInSheet
        │                 → on success: SubmitLeaderboardTime(gameId, timeSeconds)
        │                 → live mini board
        │
        └─ signed in → live mini board (unchanged)

Leaderboard tab / Profile → signed-out tease unchanged
```

## Copy

| Key | Direction |
|-----|-----------|
| `signInTitle` / `signInRequired` | Leaderboard-focused |
| `signInBody` | Play without account; sign in for live leaderboard |
| `signOutConfirmBody` | Drop “to play”; keep leaderboard |

`leaderboardSignInHint` and profile signed-out strings stay as-is.

## Out of scope

- Anonymous Firebase auth
- Offline / public leaderboard reads without sign-in
- Backfilling historical local bests when signing in from the Leaderboard tab only
- Firestore rule changes
- Removing Profile signed-out gate

## Testing

- Home: signed-out user reaches Zip / Path Words without the sign-in sheet.
- Mini board: signed-out → sign-in → `SubmitLeaderboardTime` with results time; panel leaves signed-out empty state.
- Sign-in sheet assertions match updated copy.
