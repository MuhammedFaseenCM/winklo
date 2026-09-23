# Post-game mini leaderboard — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

After **Zip** or **Path Words** completes, replace the current “Puzzle cleared!” results card with a **mini leaderboard** centered on the player’s rank, plus medals for top 3 and a path to the full board. Word Match and other games keep the existing results screen.

## Product decisions

| Topic | Choice |
|-------|--------|
| Games | Zip + Path Words only |
| Post-game UI | Mini board only — **no** time / points / streak card |
| Full board entry | “See full leaderboard” → `/leaderboard?game=…` |
| Home exit | “Back home” → `/` |
| Default period (mini) | Daily |
| Windowing | Always top 3; if user outside top 3 → gap + 2 above + you + 2 below |
| Top-3 leading | Gold / silver / bronze medal **images** (AI-generated assets) |
| Shared row | Same row widget on full leaderboard and mini board |
| Word Match | Unchanged results screen |

## Approach

**Reuse `/results` as a post-game shell** (chosen over a new `/post-game` route and over always opening full `/leaderboard`):

- Zip / Path Words still `pushReplacement('/results', extra: ResultsArgs)` after finish.
- When `gameId` is Zip or Path Words, `ResultsScreen` renders the mini leaderboard + CTAs instead of the score card.
- Other `gameId`s (or null) keep the existing results card.

## Architecture

```
Zip / Path Words finish
  → submit score / leaderboard time (unchanged)
  → pushReplacement /results (ResultsArgs + gameId)
        │
        ├─ Zip / Path Words → MiniLeaderboardView
        │     LeaderboardCubit (WatchLeaderboard, Daily, gameId)
        │     sliceLeaderboardForMini(entries, currentUid)
        │     shared LeaderboardRow (+ medals for rank 1–3)
        │     [See full leaderboard] [Back home]
        │
        └─ other games → existing ResultsScreen score card
```

Full `/leaderboard` continues to use the same shared row (with medals).

## Mini windowing rules

Pure helper: `sliceLeaderboardForMini({ required List<LeaderboardEntry> entries, required String? currentUid, int above = 2, int below = 2 })`.

Returns an ordered list of display items: either an entry row or a gap marker (`…`).

1. Include ranks **1–3** when present (no duplicates).
2. Find the current user’s entry by `uid`.
3. If user is **missing** from the board: show top 3 only (or empty/loading handling upstream).
4. If user is **in top 3**: show top 3, then up to `below` additional ranks immediately after 3 (if available). No gap.
5. If user is **outside top 3**:
   - Show top 3.
   - Insert a **gap** if there is a rank hole between 3 and the neighborhood.
   - Show neighborhood: ranks in `[userRank - above, userRank + below]` clamped to available entries, excluding any already shown in top 3.
6. Clamp at ends (e.g. rank 1 has no “above”; last place has fewer “below”).

Example: user at 25 → ranks `1, 2, 3, …, 23, 24, 25, 26, 27`.

## Shared row + medals

Promote / extract a shared leaderboard row used by:

- `features/leaderboard/view/leaderboard_screen.dart`
- Post-game mini board on `ResultsScreen`

**Leading slot:**

| Rank | Leading |
|------|---------|
| 1 | `assets/medals/medal_gold.png` |
| 2 | `assets/medals/medal_silver.png` |
| 3 | `assets/medals/medal_bronze.png` |
| 4+ | Numeric rank text (current behavior) |

Assets: AI-generated, flat game-UI style, transparent background, readable at ~28–32 logical px. Registered in `pubspec.yaml`.

Row layout unchanged otherwise: leading → avatar → name (+ “You”) → formatted time. Current-user highlight styling preserved.

## Data & state

- Mini board: `BlocProvider` + `LeaderboardCubit` with `initialGameId` from `ResultsArgs.gameId`, period **Daily** (no game/period tabs on the mini view).
- Uses existing `WatchLeaderboard` / auth wiring; signed-out → same sign-in hint as full board (defensive; play is already gated).
- Loading / empty / failure → spinner / `AppStrings.leaderboardEmpty` / retry with `AppStrings.leaderboardFailed`.

## Navigation & copy

| Control | Behavior |
|---------|----------|
| See full leaderboard | `context.push('/leaderboard?game=$gameId')` |
| Back home | Existing home navigation from results |

New `AppStrings` for the full-board CTA (and any mini-specific empty/title copy if needed). Prefer reuse of `leaderboardTitle`, `backHome`, `youLabel`.

## Testing

- Unit tests for `sliceLeaderboardForMini`: top-only, in-top-3, mid-board (e.g. 25), near end, missing user, small boards (< 3 / < 7 entries).
- Widget/smoke: Zip/Path Words results path shows mini board + CTAs; Word Match still shows score card.
- Leaderboard row: ranks 1–3 show medal widgets (asset present); rank 4+ shows number.
- Existing leaderboard cubit tests remain valid.

## Out of scope

- Changing Firestore ranking / submit rules.
- Showing time / points / streak on the post-game screen.
- Mini board All-time toggle.
- Word Match / Category Race post-game changes.
- Redesigning full leaderboard tabs / layout beyond shared row medals.

## Error handling

| Case | Behavior |
|------|----------|
| Stream loading | Centered progress indicator |
| Stream failure | Message + retry |
| Empty board | Empty copy (user may still be syncing; live stream should update) |
| User not yet on board | Top 3 (or empty); stream updates when submit lands |
| Missing medal asset | Fallback to numeric rank (defensive) |
