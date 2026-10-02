# Daily leaderboard clean-run chips — design

Date: 2026-10-02  
Status: approved for implementation

## Goal

Highlight daily leaderboard entries that finished **without hints** and (for Sudoku) **without unit-error mistakes**, using separate chips beside the player name.

## Product decisions

| Topic | Choice |
|-------|--------|
| Boards | Daily only (full board + post-game mini board) |
| Games | Zip, Path Words, Sudoku |
| No hint chip | Shown when `usedHints == false` |
| Perfect chip | Shown when `hadMistakes == false` and game is Sudoku |
| Mistake definition | Sudoku session ever had non-empty `errorIndices` (filled unit wrong) |
| Improve overwrite | Faster time replaces entry; chips reflect that run only |
| Legacy docs | Missing fields → no chips |
| All-time UI | No chips (fields may still be written for schema consistency) |

## Data model

Leaderboard entry docs gain:

- `usedHints: bool`
- `hadMistakes: bool` (Zip / Path Words always `false` on write)

Client entity uses nullable `bool?`; chips render only when the value is explicitly `false`.

## Submit path

Session tracks sticky `usedHintsThisRun` / `hadMistakesThisRun` (session-local, not period quota remaining). On improve, `SubmitLeaderboardTime` writes both flags with `timeSeconds` to all-time and today’s daily entry.

Guest soft-claim after sign-in carries the same flags via `ResultsArgs`; if unknown, submit `true`/`true` so chips are not shown falsely.

## UI

`LeaderboardRow` shows small chips (same pattern as “You”):

- **No hint** — teal-style chip when `usedHints == false`
- **Perfect** — blue-style chip when Sudoku and `hadMistakes == false`

Admin daily table shows the same badges.

## Out of scope

- Ranking / scoring changes
- Historical backfill
- Server-side verification of flags
