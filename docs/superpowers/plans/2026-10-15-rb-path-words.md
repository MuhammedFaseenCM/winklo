# Path Words content and weekends (area B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each Path Words daily a theme and word definitions (from the winklo-admin cron), harder weekend specials for all three games, and in the app: locked found words, bonus words, the theme reveal, definition sheets and a "Weekend special" badge.

**Architecture:** winklo-admin's Worker builds every daily: `dailyPuzzleParams(game, dateId)` picks weekday or weekend params, the generators take explicit overrides (Zip number/wall counts, Sudoku givens, Path Words word lengths and blanks), and the Path Words AI call returns a theme plus `{word, definition}` pairs that the board builder records. The app reads the new optional fields (`theme`, `definitions`, `special`) without changing board fingerprints; the Path Words bloc gains bonus-word detection behind `WordListRepository`, and new widgets carry the new UI so the hotspot files only get one-line hooks.

**Tech Stack:** Flutter + Flame, flutter_bloc/freezed, bloc_test + mocktail (app). TypeScript Cloudflare Worker + vitest, React SPA + vitest/testing-library (winklo-admin).

**Repos and branches:**
- App: `/Users/apple/Developments/personal/winklo-wt/rb-path-words` on `feat/rb-path-words` (base `feat/roadmap-batch`).
- winklo-admin: `/Users/apple/Developments/personal/winklo-admin-wt/themes` on `feat/themes-definitions-weekends` (base `origin/main`). Never merge to `main` (it deploys). No pushes from this work.

**Spec:** `docs/superpowers/specs/2026-10-15-roadmap-batch-design.md`, section B.

---

## Decisions (where the spec leaves room)

1. **Definition keys.** `definitions` is keyed by the target word as stored in `targets[].word` (lower case). The app lower-cases keys when it reads them, so an upper-case key written by hand in the CMS still works.
2. **Theme only when it is true.** The doc gets the AI's theme only when every target word is one of the AI's words. A board built from the fallback pool (or a mix) gets `theme: null`.
3. **Definitions are always there.** An AI word is kept only if it has a valid definition (8–90 characters, plain text, not containing the word) from the reply or from the fallback pool. Other words are dropped with a new reason, `noDefinition`. Every pool word has a definition (a test enforces it), so every target has one.
4. **Weekend day.** `isWeekendDateId('YYYYMMDD')` reads the calendar date in UTC (`Date.UTC(y, m-1, d).getUTCDay()` is 0 or 6). Weekday docs don't get a `special` field; weekend docs get `special: 'weekend'`.
5. **Weekend params.**
   - Zip 8×8: numbers 4–5 (weekday hard: 6–7), walls 22–26 (weekday hard: 16–20).
   - Sudoku 6×6: exactly 8 givens, difficulty `hard`, more attempts so a unique 8-given board is found.
   - Path Words 6×6: word lengths 6–6 and exactly 6 blanks, so five 6-letter words.
6. **CMS Generate on a weekend doc.** The SPA's Path Words Generate passes `special` to `/v1/content/path_words/ai-generate`; the route uses the weekend layout for `special: 'weekend'` on a 6×6 board and echoes `special` back, so a regenerated weekend doc stays honest.
7. **Undo.** Undo shortens the active stroke (the existing one-cell behaviour, covered by "undo shortens active path only") or removes the last *wrong* placed stroke. It never removes a found word. Reset still clears everything, bonus words included.
8. **Bonus words.** Checked on pointer-up for strokes of 4–8 letters that match no target; the set loads in the background when the puzzle loads, and a stroke released before it has loaded is treated as before (a wrong stroke). Stored lower case; shown upper case.
9. **Home badge.** Home reads only the Zip daily. The cron marks all three docs of a day by the same date rule, so Home shows "Weekend special" on all three tiles when the Zip level's `special == 'weekend'`. Each game header reads its own puzzle's `special`.
10. **Where the review card's theme goes.** Path Words review mode shows a "Today: …" line directly above the shared `ClearedSummaryCard`, in a Path Words widget, so the shared card (used by all three games) is unchanged.
11. **Results word list.** Results has no word list today, so a new `PathWordsResultsPanel` under the celebration shows the theme, the found words as chips (tappable when they have a definition) and "3 bonus words".

## File map

### winklo-admin (`/Users/apple/Developments/personal/winklo-admin-wt/themes`)

| File | Change |
|---|---|
| `workers/admin-api/src/daily_puzzle_params.ts` | `dailyPuzzleParams(game, dateId?)`, `isWeekendDateId`, weekend overrides, `special` |
| `workers/admin-api/src/daily_puzzle_params.test.ts` | new: weekday/weekend params |
| `workers/admin-api/src/zip_difficulty.ts` / `generate_zip.ts` | optional `numberCount` / `wallCount` overrides |
| `workers/admin-api/src/generate_sudoku.ts` | optional `clues` band override and `attempts` |
| `workers/admin-api/src/path_words_hard_board.ts` | optional `lengths` / `blankCounts` overrides; returns `preferredWords` |
| `workers/admin-api/src/path_words_word_pool.ts` | `POOL_DEFINITIONS`, `poolDefinition(word)` |
| `workers/admin-api/src/path_words_definitions.ts` | new: `cleanDefinition`, `cleanTheme` |
| `workers/admin-api/src/path_words_ai_generate.ts` | themed prompt + schema, reads `{theme, words:[{word, definition}]}`, returns `theme`, `definitions` |
| `workers/admin-api/src/daily_puzzle_auto.ts` | passes `dateId` to params, writes `theme`, `definitions`, `special` |
| `workers/admin-api/src/content_cms.ts` | `validateCmsDocument` checks `theme`, `definitions`, `special` |
| `workers/admin-api/src/index.ts` | ai-generate route accepts `special` |
| tests next to each (`*.test.ts`) | weekend Saturday/Sunday guarantees, prompt, reply shapes, schema |
| `src/pages/content/types.ts` | `theme`, `definitions`, `special` on level types |
| `src/pages/content/validators/pathWords.ts` | theme and definition checks |
| `src/pages/content/editors/PathWordsEditor.tsx` | theme input, a definition input per target, weekend badge, Generate keeps `special` |
| `src/lib/adminApi.ts`, `src/queries/content.ts`, `src/mocks/content.ts` | new fields through the AI generate call |

### App (`/Users/apple/Developments/personal/winklo-wt/rb-path-words`)

| File | Change |
|---|---|
| `lib/domain/entities/path_words_puzzle.dart` | `theme`, `definitions`, `special`, `definitionFor(word)` |
| `lib/domain/entities/zip_level.dart`, `sudoku_puzzle.dart` | `special` |
| `lib/domain/entities/daily_special.dart` | new: `DailySpecial.weekend`, `isWeekendSpecial(String?)` |
| `lib/domain/entities/clear_meta.dart` | optional `bonusWords` |
| `lib/domain/repositories/score_repository.dart`, `lib/data/repositories/score_repository_impl.dart`, `lib/domain/usecases/submit_score.dart` | optional `bonusWords` into the clear meta |
| `lib/domain/repositories/word_list_repository.dart`, `lib/data/repositories/word_list_repository_impl.dart` | `loadBonusWords()` (lazy `Set`), asset swap |
| `assets/words/en_bonus_words.txt` | new (ENABLE 4–8 letters, blocklist applied); `en_words.txt` removed |
| `pubspec.yaml` | asset list |
| `lib/domain/path_words/path_words_rules.dart` | `spell`, `lastIncorrectIndex` |
| `lib/features/path_words/bloc/*` | undo locks found words; bonus words in state, draft and clear meta; results summary |
| `lib/domain/entities/path_words_clear_summary.dart` | new: what Results shows for a Path Words clear |
| `lib/features/results/results_args.dart` | optional `pathWords` summary |
| `lib/features/path_words/view/widgets/path_words_definition_sheet.dart` | new |
| `lib/features/path_words/view/widgets/path_words_theme_line.dart` | new |
| `lib/features/path_words/view/widgets/path_words_results_panel.dart` | new |
| `lib/features/path_words/view/widgets/path_words_word_list.dart` | tappable found words when definitions are on |
| `lib/core/widgets/weekend_special_badge.dart` | new: badge + `GameScreenTitle` |
| hotspots (one-line hooks) | `path_words_screen.dart`, `zip_screen.dart`, `sudoku_screen.dart`, `home_screen.dart`, `results_screen.dart`, `app_strings.dart`, `core/di/app_repositories.dart` (none expected) |

---

## Part 1: winklo-admin Worker

### Task 1: Weekend params

**Files:**
- Modify: `workers/admin-api/src/daily_puzzle_params.ts`
- Create: `workers/admin-api/src/daily_puzzle_params.test.ts`
- Modify: `workers/admin-api/src/daily_puzzle_auto.test.ts` (the existing `dailyPuzzleParams` test)

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from 'vitest';
import { dailyPuzzleParams, isWeekendDateId } from './daily_puzzle_params';

describe('isWeekendDateId', () => {
  it('reads the calendar date of the dateId', () => {
    expect(isWeekendDateId('20261017')).toBe(true); // Saturday
    expect(isWeekendDateId('20261018')).toBe(true); // Sunday
    expect(isWeekendDateId('20261016')).toBe(false); // Friday
    expect(isWeekendDateId('20261019')).toBe(false); // Monday
    expect(isWeekendDateId('bad')).toBe(false);
  });
});

describe('dailyPuzzleParams', () => {
  it('weekdays keep the hard tier with no special', () => {
    expect(dailyPuzzleParams('zip', '20261016')).toEqual({ size: 8, difficulty: 'hard', source: 'rules', special: null });
  });
  it('weekends return the weekend params', () => {
    expect(dailyPuzzleParams('zip', '20261017')).toMatchObject({
      size: 8, difficulty: 'hard', special: 'weekend',
      zip: { numberCount: { min: 4, max: 5 }, wallCount: { min: 22, max: 26 } },
    });
    expect(dailyPuzzleParams('sudoku', '20261018')).toMatchObject({ size: 6, special: 'weekend', sudoku: { givens: { min: 8, max: 8 } } });
    expect(dailyPuzzleParams('path_words', '20261017')).toMatchObject({
      size: 6, special: 'weekend', pathWords: { lengths: { min: 6, max: 6 }, blankCounts: [6] },
    });
  });
  it('without a date it is a weekday', () => {
    expect(dailyPuzzleParams('sudoku').special).toBeNull();
  });
});
```

- [ ] **Step 2: Run it** — `cd workers/admin-api && npx vitest run src/daily_puzzle_params.test.ts`; expected FAIL (`isWeekendDateId` is not exported).
- [ ] **Step 3: Implement**: add `DailySpecial = 'weekend'`, the optional `zip` / `sudoku` / `pathWords` override objects on `DailyPuzzleParams`, `isWeekendDateId` (UTC calendar date, `/^\d{8}$/`), and `dailyPuzzleParams(game, dateId?)` returning the weekday object plus `special: null`, or the weekend object with its overrides. Update the doc comment and the old `dailyPuzzleParams` expectation in `daily_puzzle_auto.test.ts` to include `special: null`.
- [ ] **Step 4: Run** the two test files; expected PASS.

### Task 2: Generators take the weekend overrides

**Files:** `generate_zip.ts`, `generate_sudoku.ts`, `path_words_hard_board.ts`; tests in `daily_puzzle_auto.test.ts` (new `describe('weekend specials')`) and `path_words_hard_board.test.ts`.

- [ ] **Step 1: Failing tests** for Saturday `20261017` and Sunday `20261018` (and a few more weekend dates):
  - Zip: `generateZip(8, { seed, difficulty: 'hard', numberCount: {4,5}, wallCount: {22,26} })` has a 64-cell Hamiltonian `solution`; numbers are 1..n in order along the solution, 1 at its start and n at its end; no wall crosses a solution step; 4–5 numbers and 22–26 walls; fewer numbers than the weekday board of the same seed allows (max 5 < 6) and more walls (min 22 > 20).
  - Sudoku: `generateSudoku({ size: 6, difficulty: 'hard', seed, dateId, clues: {8,8}, attempts: 400 })` has exactly 8 givens, `countSudokuSolutions(given, 6, 2, 3) === 1`, the solution is a valid grid matching the givens, `difficulty === 'hard'`.
  - Path Words: `buildHardBoard({ size: 6, difficulty: 'hard', rng, preferred: [], fallback: poolForLength, lengths: {6,6}, blankCounts: [6] })` gives 5 targets of 6 letters, 6 blanks, `hardBoardIssues(board) === []` (one route per word, words touch, blanks apart, every word turns).
- [ ] **Step 2: Run** — FAIL (unknown options).
- [ ] **Step 3: Implement**:
  - `generateZip` opts gain `numberCount?` / `wallCount?` that replace `zipBand(difficulty)`'s ranges.
  - `generateSudoku` opts gain `clues?: {min,max}` replacing `clueBand` and `attempts?` (default 12). With `clues` given the last resort keeps digging with new rngs until the band is met or attempts run out, then throws rather than returning a board outside the band (the weekend promise is exactly 8). Each attempt also retries the dig with a few orders before refilling.
  - `buildHardBoard` gains `lengths?` (replaces `hardWordLengths`) and `blankCounts?` (replaces `feasibleBlankCounts`), and returns `preferredWords: string[]` (the targets that came from `preferred`).
- [ ] **Step 4: Run** — PASS; check run time stays under a second or two per board.

### Task 3: Definitions for the fallback pool

**Files:** `path_words_word_pool.ts`, create `path_words_definitions.ts`, test `path_words_word_pool.test.ts`.

- [ ] **Step 1: Failing test**

```ts
import { describe, expect, it } from 'vitest';
import { cleanDefinition } from './path_words_definitions';
import { HARD_WORDS_5, HARD_WORDS_6, SHORT_WORDS, poolDefinition } from './path_words_word_pool';

describe('fallback pool definitions', () => {
  for (const word of [...HARD_WORDS_6, ...HARD_WORDS_5, ...SHORT_WORDS]) {
    it(`"${word}" has a plain one-line definition`, () => {
      const def = poolDefinition(word);
      expect(def).toBeTypeOf('string');
      expect(cleanDefinition(word, def)).toBe(def);
    });
  }
});
```

plus unit tests of `cleanDefinition` (trims and collapses spaces, capitalises, rejects < 8 or > 90 characters, markup `<>{}[]*_#|~` or a URL, and any text containing the word case-insensitively) and `cleanTheme` (2–24 characters of letters, spaces and `' & , -`, capitalised; null otherwise).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** `cleanDefinition`, `cleanTheme`, and `POOL_DEFINITIONS: Record<string, string>` with one definition for every pool word (≈410), plus `poolDefinition(word)`.
- [ ] **Step 4: Run** — PASS.

### Task 4: Themed AI prompt and reply

**Files:** `path_words_ai_generate.ts` and its two test files.

- [ ] **Step 1: Failing tests**
  - `buildWordsPrompt(6, [5, 6])` asks for a theme of 2–24 characters, `{"theme": ..., "words": [{"word": ..., "definition": ...}]}`, definitions of 8–90 characters without the word, and no longer says "no theme".
  - The JSON schema sent is `{ theme: string, words: [{ word, definition }] }` with both required.
  - `readAiWords` reads `{theme, words: [{word, definition}]}` (as a string, parsed, in `choices`, cut off at `max_tokens`), keeps the theme, and keeps definitions; old string lists still read.
  - A word with no usable definition that isn't in the pool is dropped as `noDefinition`; a pool word without one gets the pool definition.
  - `aiGeneratePathWordsLevel` returns `theme` (cleaned) and `definitions` for exactly the target words; with no AI (or a throwing one) `theme` is null and `definitions` are the pool's; a mixed board has `theme: null`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**: candidates become `{ word, definition? }`; `readAiWords` returns `theme`, `definitions` (a `Map` of kept words), and `dropped.noDefinition`; `aiGeneratePathWordsLevel` takes `opts.layout?: { lengths, blankCounts }` and `opts.special?`, builds with `preferred` = kept words, and returns `theme` only when `board.preferredWords.length === board.targets.length`, `definitions` from the AI map or the pool, and `special` when given.
- [ ] **Step 4: Run** — PASS (update the `dropped` expectations to include `noDefinition: 0`).

### Task 5: Cron writes the new fields; CMS validation

**Files:** `daily_puzzle_auto.ts`, `content_cms.ts`, `index.ts`, tests in `daily_puzzle_auto.test.ts`, `content_cms.test.ts`, `index.test.ts`.

- [ ] **Step 1: Failing tests**
  - `fillMissingDailyPuzzles` on `now = 2026-10-16` (Fri) creates Saturday 17th docs with `special: 'weekend'` for all three games and Friday docs without `special`; the Path Words doc has `theme` (string or null) and a `definitions` map whose keys are exactly the target words.
  - `validateCmsDocument('path_words_levels', …)` accepts `theme: null`, `theme: 'Kitchen tools'`, `definitions: { cedar: 'A tall evergreen tree' }`, `special: 'weekend'`; rejects `theme: 'x'`, `theme: 7`, a 25+ character theme, `definitions: []`, a non-string or 91+ character definition, and `special: 'holiday'` on all three daily collections.
  - The ai-generate route passes `special: 'weekend'` through for size 6.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** in `buildPuzzleDoc`: `dailyPuzzleParams(slot.game, slot.dateId)`, overrides into each generator, `...(params.special ? { special: params.special } : {})`, `theme`, `definitions`, and `special` in `generatorMeta`. Add the checks to `validateCmsDocument`.
- [ ] **Step 4: Run** the Worker suite and `npm run typecheck` — PASS.
- [ ] **Step 5: Commit** (winklo-admin): `feat(admin-api): themed Path Words with definitions, and weekend specials`.

## Part 2: winklo-admin SPA

### Task 6: Types, validator and the editor

**Files:** `src/pages/content/types.ts`, `validators/pathWords.ts` (+ test), `editors/PathWordsEditor.tsx` (+ test), `src/lib/adminApi.ts`, `src/queries/content.ts`, `src/mocks/content.ts`.

- [ ] **Step 1: Failing tests**
  - `validatePathWords` flags `theme` outside 2–24 characters and a definition outside 8–90 characters or containing its word (path `definitions.<word>`), and accepts a good theme/definitions and none at all.
  - `PathWordsEditor`: typing in "Theme" calls `onChange` with `theme`; clearing it sets `theme: null`; each target row has a "Definition of CEDAR" input that writes `definitions.cedar`; renaming a target moves nothing but drops no other definitions; a doc with `special: 'weekend'` shows a "Weekend special" badge; Generate passes `special` and applies the returned `theme` and `definitions`.
- [ ] **Step 2: Run** `npx vitest run src/pages/content` — FAIL.
- [ ] **Step 3: Implement**; prune definition keys that no longer match a target when saving (in `apply` and on word change, keep only target words).
- [ ] **Step 4: Run** lint, `typecheck:tests`, tests, build, `check:ui`, `check:bundle` — PASS.
- [ ] **Step 5: Commit** (winklo-admin): `feat(cms): edit the Path Words theme and definitions`.

## Part 3: App

### Task 7: Entities read the new fields

**Files:** `lib/domain/entities/path_words_puzzle.dart`, `zip_level.dart`, `sudoku_puzzle.dart`, new `daily_special.dart`; tests `test/domain/entities/path_words_puzzle_test.dart` (create or extend), `zip_level_test.dart`, `sudoku_puzzle_test.dart`.

- [ ] **Step 1: Failing tests**

```dart
test('reads theme, definitions and special without changing the fingerprint', () {
  final base = {'size': 2, 'letters': ['a', 'b', 'c', 'd'], 'targets': [ /* ab */ ]};
  final plain = PathWordsPuzzle.fromJson(base, id: 'daily_20261017');
  final themed = PathWordsPuzzle.fromJson({
    ...base,
    'theme': 'Kitchen tools',
    'definitions': {'AB': 'Two letters in a row', 'x': 5},
    'special': 'weekend',
    'unknown': true,
  }, id: 'daily_20261017');
  expect(themed.theme, 'Kitchen tools');
  expect(themed.definitionFor('ab'), 'Two letters in a row');
  expect(themed.definitions.containsKey('x'), isFalse);
  expect(themed.special, 'weekend');
  expect(plain.theme, isNull);
  expect(plain.definitions, isEmpty);
  expect(themed.fingerprint, plain.fingerprint);
});
```

and the same `special` + fingerprint checks for `ZipLevel.fromJson` and `SudokuPuzzle.fromJson`; a blank theme reads as null.
- [ ] **Step 2: Run** `flutter test test/domain/entities` — FAIL.
- [ ] **Step 3: Implement** (optional constructor params, `toJson` writes them when set).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit**: `feat(path-words): read the daily theme, definitions and weekend special`.

### Task 8: Lock found words

**Files:** `lib/domain/path_words/path_words_rules.dart`, `lib/features/path_words/bloc/path_words_bloc.dart`, `test/features/path_words/bloc/path_words_bloc_test.dart`, `test/domain/path_words/path_words_rules_test.dart`.

- [ ] **Step 1: Failing tests**: replace "undo of a found word unlocks that word" with "undo never unlocks a found word" (the found word stays, nothing is emitted); "undo removes the last wrong stroke, not a later found word" (wrong, found → undo leaves the found word); change "a word traced along another route counts, saves and undoes" so undo keeps it.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** `_onUndo`: shorten the active stroke if there is one; else remove the last placed stroke with `targetId == null`; else do nothing. The screen's Undo button is enabled only when there is an active stroke or a wrong stroke.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit**: `feat(path-words): undo never takes back a found word`.

### Task 9: Bonus word list

**Files:** `assets/words/en_bonus_words.txt` (new), delete `assets/words/en_words.txt`, `pubspec.yaml`, `word_list_repository.dart`, `word_list_repository_impl.dart`, `test/data/repositories/word_list_repository_impl_test.dart`.

- [ ] **Step 1: Failing test**: `loadBonusWords()` returns a `Set` with `stare`, every entry 4–8 lowercase letters, no blocked word (`fuck`, `shit`), the same instance on a second call, and only one asset read.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; `loadEnglishWords` reads the new asset (the old file is gone; only the generator test used it).
- [ ] **Step 4: Run** the repository and generator tests — PASS.
- [ ] **Step 5: Commit**: `feat(path-words): bundle the ENABLE bonus word list`.

### Task 10: Bonus words in the bloc, draft and clear meta

**Files:** `path_words_state.dart` (+ regenerated freezed), `path_words_bloc.dart`, `clear_meta.dart`, `score_repository.dart`, `score_repository_impl.dart`, `submit_score.dart`, `path_words_screen.dart` (pass `wordList`), tests for each.

- [ ] **Step 1: Failing tests**
  - A released stroke spelling `cab` … (4+ letters) that matches no target and is in the set: `bonusWords == ['stare']`, `placedPaths` unchanged, `activePath` empty, no rule tip, haptic `HapticKind.light`; the same word again is an ordinary wrong stroke.
  - A stroke spelling a non-word stays a wrong stroke.
  - `bonusWords` saved in the draft (`board['bonusWords']`) and restored.
  - Reset clears them; undo doesn't.
  - The clear passes `bonusWords` to `submitScore`, and they don't change `usedHints`, `hadMistakes`, points, time or the leaderboard call.
  - `ClearMeta` round-trips `bonusWords` and treats a missing list as empty; `ScoreRepositoryImpl.submitScore(bonusWords: …)` stores them in the meta.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** (`wordList` optional in the bloc; loading starts in `_onStarted` and errors are ignored).
- [ ] **Step 4: Run** `dart run build_runner build --delete-conflicting-outputs` for the state, then the tests — PASS.
- [ ] **Step 5: Commit**: `feat(path-words): count real words that aren't targets as bonus words`.

### Task 11: Theme reveal, definitions, Results summary

**Files:** new `path_words_clear_summary.dart`, `results_args.dart`, new widgets `path_words_definition_sheet.dart`, `path_words_theme_line.dart`, `path_words_results_panel.dart`, `path_words_word_list.dart`, `path_words_screen.dart`, `results_screen.dart`, `app_strings.dart`; widget tests.

- [ ] **Step 1: Failing tests**
  - `PathWordsResultsPanel` shows "Today: Kitchen tools", chips of the found words, "3 bonus words" (and "1 bonus word"); tapping a word with a definition opens a sheet with the word and its definition; a word without one has no tap target.
  - Path Words review mode shows "Today: Kitchen tools" and tapping a found word opens the sheet; while playing there is no theme and tapping does nothing.
  - The bloc's `resultsExtra.pathWords` carries theme, words in list order, definitions and bonus words.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; hooks: one widget in Results' `_celebrationHeader`, the theme line above `ClearedSummaryCard`, `definitionsEnabled: isReview` on the word list.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit**: `feat(path-words): reveal the theme and definitions after a clear`.

### Task 12: Weekend badge

**Files:** new `lib/core/widgets/weekend_special_badge.dart`, `home_screen.dart`, `path_words_screen.dart`, `zip_screen.dart`, `sudoku_screen.dart`, `app_strings.dart`; tests.

- [ ] **Step 1: Failing tests**: `GameScreenTitle(title, special: 'weekend')` shows the title and "Weekend special"; `special: null` shows only the title; the Home tiles show "Weekend special" instead of "Today" when the Zip level is a weekend special; the Path Words screen header shows the badge for a weekend puzzle.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** (replace the three header `Text(title)` with `GameScreenTitle`, add `weekendSpecial:` to the three Home tiles).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit**: `feat: show a Weekend special badge on Home and in the game header`.

### Task 13: Verify and review

- [ ] `flutter analyze --no-fatal-infos` (no new issues), full `flutter test` green, `dart format` on the touched files only, `git checkout pubspec.lock` if `pub get` touched it.
- [ ] winklo-admin: `npm run lint`, `npm run check:ui`, `npm run typecheck:tests`, `npm test`, `npm run build`, `npm run check:bundle`; `cd workers/admin-api && npm run typecheck && npm test`.
- [ ] Code review of both diffs (app vs `feat/roadmap-batch`, admin vs `origin/main`); fix real findings; re-run.

## Manual follow-ups (after merge, not part of this work)

- Deploy winklo-admin (merge to `main`) per the spec's deploy steps; check the next Path Words day has `theme`/`definitions` and a Saturday has `special: 'weekend'`.
- Docs already in Firestore (generated before the deploy) have no theme, definitions or special; the app hides those parts until then.
