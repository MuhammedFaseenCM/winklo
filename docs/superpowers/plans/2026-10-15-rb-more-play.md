# Area F: more ways to play — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for every task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build section F of `docs/superpowers/specs/2026-10-15-roadmap-batch-design.md`: play modes (daily / archive / practice), the archive of past dailies, offline practice boards from the Dart generators, and Word Match and Category Race as polished bonus games.

**Architecture:** A pure-Dart `PlayMode` (`lib/domain/play_mode.dart`) travels with the route (`/zip?mode=archive&day=2026-10-09`, `/zip?mode=practice`; no `mode` means daily) and into each game bloc. Only the daily branch of a bloc touches the daily world (score repository mode keys, `RecordDailyClear`, `SubmitLeaderboardTime`, the daily hint quota, the cleared lock). Archive, practice and bonus runs write to a separate `PlayModeRecordRepository` that never fires `ProgressChangeSignal`, and spend hints from a per-mode quota (`HintQuotaForMode`). New screens live in `lib/features/more_play/`; hotspot files get small additive edits.

**Branch:** `feat/rb-more-play` (worktree `/Users/apple/Developments/personal/winklo-wt/rb-more-play`). Base: `feat/roadmap-batch` at `e3f7ca4` (waves 1 merged; about 1,550 tests pass).

---

## Ground rules

- TDD: write the test, watch it fail, implement, watch it pass.
- `dart format` only touched files. `pubspec.lock` untouched (no new packages). `pubspec.yaml` gains one asset line.
- Commit after each feature; last line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Hotspots (`home_screen.dart`, `app_router.dart`, `app_strings.dart`, `core/di/*`, game blocs and screens): additive edits. All new copy goes in one `AppStrings` block ("More ways to play"), English only (area G moves strings next).

## Isolation contract (what a non-daily run may touch)

| Thing | Daily | Archive | Practice | Bonus |
|---|---|---|---|---|
| Puzzle source | Firestore `daily_YYYYMMDD` (today) | Firestore `daily_YYYYMMDD` (the day, read by id, always `PlayPeriod.daily`) | `DailyPuzzleGenerator.practice`, `SudokuGenerator.practice`, `PathWordsGenerator.practice` (random seed) | CMS decks/categories |
| Run id (drafts, hints) | `20261015` | `archive_20261009` | `practice` | — |
| Draft key | `in_progress_zip_20261015` | `in_progress_zip_archive_20261009` | `in_progress_zip_practice` (stores the seed) | — |
| Best / meta key (`best_time_<modeKey>`) | `zip_daily_…`, `path_words_…`, `sudoku_…` via `SubmitScore` | `archive_zip_20261009`, `archive_path_words_…`, `archive_sudoku_…` via `PlayModeRecordRepository` | `practice_zip`, `practice_path_words`, `practice_sudoku` | `bonus_word_match_<deck>`, `bonus_category_race_<category>` |
| Hints | `HintQuotaRepository` (daily, synced) | 3 per run, `hints_used_<game>_archive_<day>` via the records store, reset when a fresh run starts | unlimited | none |
| `SubmitScore`, `IsNewPersonalBest`, `RecordDailyClear`, `SubmitLeaderboardTime`, cleared lock, `ClearedSummaryCard` | yes | **no** | **no** | **no** |
| `ProgressChangeSignal` | yes (score/hint/streak writes) | **no** | **no** | **no** |
| Midnight rollover on resume | yes | **no** (fixes "jumps to today") | **no** | — |

Mode keys put the mode first, so nothing starting with `zip_daily_`, `path_words_` or `sudoku_` is ever written by a non-daily run. Draft and hint keys keep the repositories' `<prefix>_<game>_<runId>` shape; nothing scans those prefixes except the per-user purge/stash, which must (and does) include them.

## File map

| File | Responsibility |
|---|---|
| `lib/domain/play_mode.dart` (new) | `PlayMode` (`daily` / `archive(day)` / `practice`), `runId`, `modeKey`, query parsing and `location()`, archive range (11 Oct 2026 → yesterday) |
| `lib/domain/repositories/play_mode_record_repository.dart` (new) | local bests (time, score) and archive hint counts, off the dailies |
| `lib/data/repositories/play_mode_record_repository_impl.dart` (new) | SharedPreferences impl; refuses daily-shaped keys; never notifies |
| `lib/domain/play_mode_hints.dart` (new) | `ArchiveHintQuota`, `UnlimitedHintQuota`, `HintQuotaForMode` |
| `lib/domain/archive_calendar.dart` (new) | months/days of the archive for one game, ✓ from daily or archive clears |
| `lib/features/zip/logic/daily_puzzle_generator.dart` (modify) | `practice(seed)`: 8×8, 6–7 checkpoints, 16–20 walls (the cron's hard rules) |
| `lib/domain/sudoku/sudoku_generator.dart` (modify) | `practice(seed)`: 6×6, 8–9 unique givens (cron hard band), never a full board |
| `lib/domain/path_words/path_words_generator.dart` (modify) | `practice(seed, words)`: 6×6, 5–6 letter words, 3–6 lone blanks, one route per word (port of the cron's hard board) |
| `assets/words/en_practice_words.txt` (new) | bundled 5–6 letter family-friendly words (the cron's fallback pool) |
| `lib/domain/repositories/word_list_repository.dart` + impl (modify) | `loadPracticeWords()` |
| `lib/features/zip/bloc/*`, `zip_screen.dart` (modify) | mode-aware start/finish/resume, `newBoard` event, clock fix |
| `lib/features/path_words/bloc/*`, screen (modify) | same |
| `lib/features/sudoku/bloc/*`, screen (modify) | same |
| `lib/core/widgets/play_mode_strip.dart` (new) | "Archive · 9 Oct" / "Practice · New board" strip under a game header |
| `lib/features/results/results_args.dart` (modify) | `local: LocalResultInfo?` |
| `lib/features/results/view/local_results_view.dart` (new) | Results variant: time (or score), label, local best, no board/streak/share |
| `lib/features/results/results_screen.dart` (modify) | one branch to the variant |
| `lib/features/more_play/view/more_play_screen.dart` (new) | hub: Archive, Practice, Bonus games |
| `lib/features/more_play/cubit/archive_cubit.dart` + view (new) | archive calendar per game |
| `lib/features/home/view/widgets/home_more_play_entry.dart` (new) | the one compact Home entry |
| `lib/core/router/app_router.dart` (modify) | parse `mode`/`day`; `/more`, `/more/archive` |
| `lib/core/di/app_repositories.dart` (modify) | register the records repo, `HintQuotaForMode`, `PracticeSeeds` |
| `lib/features/word_match/**`, `lib/features/category_race/**` (modify) | bonus-game polish |

## Tasks

### 1. Domain: `PlayMode` — commit `feat: play modes for daily, archive and practice runs`
- [ ] `test/domain/play_mode_test.dart`: `daily is the default when mode is missing`, `archive parses a past day`, `archive refuses today, the future and days before 11 Oct 2026`, `practice parses`, `runId is the period id, archive_<day> or practice`, `modeKey puts the mode first and never starts with a daily prefix`, `location round-trips through fromQuery`.
- [ ] Implement `lib/domain/play_mode.dart`.

### 2. Records store and mode hints — commit `feat: local records and hint quotas for runs off the dailies`
- [ ] `test/data/repositories/play_mode_record_repository_impl_test.dart`: `bests improve only`, `first clear is not a new best but is stored`, `score bests keep the highest`, `refuses daily mode keys`, `hint counts per run and reset`, `never writes a daily key`.
- [ ] `test/domain/play_mode_hints_test.dart`: `daily mode uses the daily quota`, `archive allows 3 per run without touching the daily quota`, `practice never runs out`.
- [ ] Implement, register in DI (`PlayModeRecordRepository`, `HintQuotaForMode`).
- [ ] `userProgressKeyPrefixes` already covers `best_`, `clear_meta_`, `hints_used_`, `in_progress_` → add a test that a purge removes archive keys.

### 3. Generators for practice — commit `feat: practice boards from the Dart generators`
- [ ] `test/features/zip/logic/daily_puzzle_generator_practice_test.dart`: `practice boards are 8x8 with 6-7 checkpoints and 16-20 walls`, `the solution visits every cell and respects walls`, `same seed same board`, `different seeds differ`.
- [ ] `test/domain/sudoku/sudoku_generator_practice_test.dart`: `practice boards are 6x6 with 8-9 givens`, `exactly one solution`, `never a solved board`, `100 seeds all valid`.
- [ ] `test/domain/path_words/path_words_generator_practice_test.dart`: `6x6, 5-6 letter words, 3-6 lone blanks`, `every letter belongs to a word`, `each word has one route`, `fromJson round-trip accepts it`, `100 seeds from the bundled list all build`.
- [ ] Bundle `assets/words/en_practice_words.txt`; `WordListRepository.loadPracticeWords()`.

### 4. Zip modes — commit `feat(zip): archive and practice runs`
- [ ] `test/features/zip/bloc/zip_bloc_modes_test.dart` (isolation first): `archive clear never submits a score, leaderboard time, streak or daily best`, `archive clear records the archive best`, `archive run never reads or writes today's draft or hints`, `archive ignores the daily lock`, `archive resume never jumps to today`, `practice clear never touches daily state`, `practice resumes its draft board from the stored seed`, `newBoard replaces the practice board`, `clock runs for an archive day` (date bug).
- [ ] Bloc + screen changes; `PlayModeStrip`.

### 5. Path Words modes — commit `feat(path-words): archive and practice runs`
- [ ] `test/features/path_words/bloc/path_words_bloc_modes_test.dart`: same list (leaderboard, streak, daily best, `daily_activity`/hints, draft, resume, practice words).

### 6. Sudoku modes — commit `feat(sudoku): archive and practice runs`
- [ ] `test/features/sudoku/bloc/sudoku_bloc_modes_test.dart`: same list.

### 7. Results variant — commit `feat(results): a local-best results page for archive, practice and bonus runs`
- [ ] `test/features/results/results_local_test.dart`: `shows time, Archive · 9 Oct and the archive best`, `no leaderboard, streak, share or achievements`, `practice offers New board`, `360x640 screenshot` (archive).

### 8. Router — commit `feat(router): game routes carry the play mode`
- [ ] `test/core/router/play_mode_routes_test.dart`: `/zip without mode is daily`, `/zip?mode=archive&day=… opens an archive run`, `invalid archive day goes to the archive page`, `/more and /more/archive open`.

### 9. Hub and archive — commit `feat: More ways to play hub and the archive calendar`
- [ ] `test/features/more_play/archive_cubit_test.dart`: `months from 11 Oct to yesterday`, `✓ for daily or archive clears`, `switching game reloads`.
- [ ] Widget tests + 360×640 screenshots: hub, archive calendar.

### 10. Home entry — commit `feat(home): one More ways to play entry`
- [ ] `test/features/home/view/home_more_play_entry_test.dart`: `opens the hub`, `Home at 360x640 has no overflow` (screenshot).

### 11. Bonus games — commit `feat: Word Match and Category Race as bonus games`
- [ ] Word Match: How to play on first run (`TutorialRepository`), sfx/haptics via one-shot game callbacks, local best time (`bonus_word_match_<deck>`), Results variant, themed header, AppStrings, no raw error text.
- [ ] Category Race: same, best = most words (`bonus_category_race_<category>`).
- [ ] Tests: bloc tests for bests and the no-daily-state rule; tutorial-once widget tests.

### 12. Docs and wrap-up — commit `docs: area F in the README`
- [ ] README: roadmap "More ways to play" entries marked done, Housekeeping generator note settled, deviations.
- [ ] `flutter analyze --no-fatal-infos` (20 infos baseline), full `flutter test`, format touched files, screenshots reviewed, code review for daily-state leaks.

## Deviations (recorded as they are made)

- Home gets one compact "More ways to play" entry that opens a hub (Archive, Practice, Bonus games) instead of three Home entries: Home must still fit 360×640.
- Mode keys are `archive_zip_<day>` / `practice_zip` (mode first) instead of the spec's `zip_archive_<day>` / `zip_practice`, so the stats' daily-prefix scans can never match them.
- Practice Path Words uses a new bundled list (`en_practice_words.txt`, the cron's fallback pool), because `en_nouns.txt` has no 6-letter words and the 79k ENABLE list is full of obscure words.
- The Dart generators were brought up to the cron's hard rules for practice (`practice(seed)` entry points); the old date-seeded `generate`/`forDate` stay for their tests.
- Archive and practice hints count in the local records store (`hints_used_<game>_archive_<day>`, reset when a fresh archive run starts) instead of `HintQuotaRepository`, because that repository's writes fire `ProgressChangeSignal`. Practice hints never run out (`UnlimitedHintQuota`).
- Draft and hint keys keep the repositories' `<prefix>_<game>_<runId>` shape (`in_progress_zip_archive_20261012`); only the score/meta keys (which the stats scan by prefix) put the mode first. Nothing scans in-progress or hint keys except the per-user purge and stash, which cover them.
- An archive link for today, a future day or a malformed day redirects to that game's archive calendar instead of opening the daily or an unranked copy of today's puzzle.
- Archive runs never lock: a day cleared in the daily (or the archive) can be replayed in the archive, and its ✓ stays.
- Bonus games: their bests moved from `SubmitScore` (`best_pts_match_<deck>`, `best_pts_race_<category>`, which fired the progress sync) to the local records store (`bonus_word_match_<deck>` best time, `bonus_category_race_<category>` most words). Old Word Match/Category Race points bests aren't migrated; the games were unreachable from the UI.
- Results for archive, practice and bonus runs is a separate local-best page (`LocalResultsView`); its second button is Back home.

