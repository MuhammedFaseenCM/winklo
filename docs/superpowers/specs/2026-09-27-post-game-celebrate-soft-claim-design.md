# Post-game celebrate + soft claim — design

Date: 2026-09-27  
Status: approved for implementation

## Goal

After Zip or Path Words, make finish feel like a win first. Sign-in is an optional “claim this run” moment — never a blocker to play or leave. Guests keep full local play, streaks, and scores.

## Problem

Guest play removed the Home auth gate, but Zip / Path Words still land on a **mini leaderboard with a signed-out sign-in wall** (“Sign in to view rankings”). That:

- Skips celebration (time / PB / streak already in `ResultsArgs` but unused on this path)
- Frames sign-in as unlocking rankings, not saving the run they just earned
- Feels like a post-game blocker even with “Not now”

## Product decisions

| Topic | Choice |
|-------|--------|
| Play gate | Unchanged — still no sign-in required to play |
| Post-game primary UI | **Celebration card** (time, optional PB / streak) — not mini board alone |
| Sign-in prompt | Soft secondary CTA: claim / save this run’s time |
| Rank teaser | Soft copy only for guests (no public board without auth in this pass) |
| Signed-in post-game | Celebration + mini leaderboard below (same slice rules as today) |
| Leave / home | Always available, one tap — never behind sign-in |
| Leaderboard tab signed-out | Unchanged (blurred mock + sign-in) |
| Profile signed-out | Unchanged |
| Remote write | Still requires Firebase auth; submit on successful sign-in from results |
| Word Match / other games | Unchanged |

**Supersedes (results path only):**

- [Post-game mini leaderboard](2026-09-24-post-game-mini-leaderboard-design.md) — “mini board only, no time/points/streak card”
- [Guest play sign-in](2026-09-26-guest-play-leaderboard-signin-design.md) — “post-game = soft sign-in hint as primary body”

Guest play + remote-write-requires-auth remain in force.

## Approach

**Celebrate first → soft claim second.**

1. Zip / Path Words keep pushing `/results` with full `ResultsArgs` (already includes time, improved, streak, `gameId`).
2. `ResultsScreen` for Zip / Path Words renders the **shared celebration layout** (same emotional core as the generic results card), not `MiniLeaderboardPanel` alone.
3. Guest extras under the card:
   - Soft line: save this time to today’s board (optional rank-teaser wording if we can phrase without a live query)
   - Secondary button → existing `showSignInSheet` → on success `SubmitLeaderboardTime(gameId, timeSeconds)` then reveal mini board
4. Signed-in: celebration + existing mini board + “See full leaderboard” / “Back home”.
5. Rewrite sign-in sheet copy when opened from results toward **claim/save**, not “view rankings”. Global sheet used from Leaderboard/Profile may keep board-focused copy via a small context param or dedicated results CTA strings.

## User flows

### Guest finishes Zip / Path Words

```
Finish puzzle
  → local score + streak (unchanged)
  → /results celebration
        hero: time (+ PB / streak if present)
        primary: Back home (daily) / same home exit as today
        secondary: “Save {time} to today’s board” → Google sheet
        dismiss: always free (Back home / Not now on sheet)
```

### Guest signs in from results

```
Secondary CTA → showSignInSheet (claim copy)
  → success → SubmitLeaderboardTime(gameId, timeSeconds) best-effort
  → same screen updates: celebration stays; mini board appears live
```

### Signed-in finishes

```
Finish → celebration + MiniLeaderboardPanel (live)
  → See full leaderboard / Back home
```

## UI layout (Zip / Path Words results)

```
┌─────────────────────────────┐
│         ZipMark / title     │
│         m:ss  (hero)        │
│    [New personal best?]     │
│    [Streak pill?]           │
├─────────────────────────────┤
│ Guest only: soft claim CTA  │
│ Signed-in: mini board       │
├─────────────────────────────┤
│ [See full leaderboard]*     │
│ [Back home]                 │
└─────────────────────────────┘
* Signed-in: primary path to full board.
  Guest: optional; may open Leaderboard tab (existing signed-out tease)
  or be omitted to reduce noise — prefer omit for guests.
```

## Copy direction

All via `AppStrings`.

| Context | Direction |
|---------|-----------|
| Results soft CTA | Claim/save this run’s time to today’s board |
| Sign-in sheet from results | Title/body about saving the run, not “view rankings” |
| Sign-in sheet from Leaderboard tab | Keep board-focused (existing) |
| Cancel | Keep “Not now” |
| After claim success | No extra modal; mini board appears |

Example (final wording in implementation):

- CTA: `Save 1:12 to today’s board`
- Sheet title: `Save your time`
- Sheet body: `Sign in with Google to put this run on the live daily leaderboard.`

## Architecture

```
ResultsScreen(args)
  gameId ∈ {zip, path_words}
    → CelebrationHeader(args)          // time / PB / streak
    → if signed in: MiniLeaderboardPanel(gameId, timeSeconds)
    → if guest: SoftClaimCta(timeSeconds) → showSignInSheet → submit
    → nav: See full (signed-in) / Back home
  else
    → existing generic results card (unchanged)
```

Reuse existing pieces:

- `ResultsArgs` fields already populated by Zip / Path Words blocs
- `showSignInSheet` + `SubmitLeaderboardTime` sync path from `MiniLeaderboardPanel`
- Mini windowing / medals unchanged for signed-in users

Prefer extracting celebration into a small shared widget used by Zip/Path Words results and optionally the generic card later — only if it reduces duplication cleanly; otherwise duplicate lightly inside `ResultsScreen` for this pass.

## Out of scope

- Anonymous Firebase auth / public leaderboard reads without sign-in
- Computing exact “you would be #N” without a board query (nice-to-have later)
- Backfilling all local bests on any sign-in
- Changing Firestore rules or ranking
- Word Match post-game
- Force sign-in anywhere in play
- Redesigning Leaderboard tab / Profile signed-out states

## Testing

- Guest Zip/Path Words results: celebration shows time (and streak/PB when present); no locked “sign in to view rankings” as the only body.
- Guest can reach Home without signing in.
- Soft CTA → sign-in → `SubmitLeaderboardTime` with results time; mini board appears.
- Signed-in results: celebration + mini board + full board CTA.
- Word Match / null `gameId` path unchanged.
- Copy assertions for results claim strings; Leaderboard-tab sheet can keep existing board copy if parameterized.

## Error handling

| Case | Behavior |
|------|----------|
| Sign-in cancel / Not now | Stay on celebration; no error |
| Submit after sign-in fails | Stay signed in; celebration remains; mini board may load without this run until retry elsewhere |
| `timeSeconds <= 0` | Skip submit (same as today) |
| Firebase not ready | Soft fail; local celebration still works |
