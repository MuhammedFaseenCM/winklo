# Path Words Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Path Words gets Levels like Zip:
- category-themed worlds of 20 fixed boards, ramping in difficulty;
- three stars per level;
- its own Levels leaderboard;
- worlds made by winklo-admin's Generate world and by a publish script.

**Architecture:**
- **admin-api** gains one TypeScript world generator, built on the existing `buildHardBoard`. Both the admin's new generate route and a Node script call it. The script publishes through the same `checkWorld`/`checkPublish` rules.
- **The leaderboard Worker** checks Path Words level clears with its existing `checkPathWordsProof`.
- **In the app**, `PathWordsBloc` gets a level mode that mirrors `ZipBloc`'s, and the Levels tab's game switcher becomes real.

**Tech Stack:**
- Flutter/Dart: BLoC, `bloc_test` + `mocktail`, go_router.
- Cloudflare Workers in TypeScript, tested with vitest.
- React SPA (winklo-admin).
- Firestore rules tests with `@firebase/rules-unit-testing`.

**Spec:** `docs/superpowers/specs/2026-11-23-path-words-levels-design.md`

## Global Constraints

- **Repos.**
  - Tasks 1–5 are in `/Users/muhammedfaseencm/winklo-admin`, on branch `feat/path-words-levels`.
  - Tasks 6–11 are in `/Users/muhammedfaseencm/winklo`, on branch `feat/path-words-levels`.
  - Never commit to `master` or `main` directly.
- **Level ids** are `path_words_{order}_{NN}`, with a two-digit index from 01. They come from `levelId(game, order, index)` in admin-api and must match the app's `PlayMode.levelIdPattern`.
- **The world doc** is `level_worlds/path_words_{order}`, with the fields `game`, `order`, `theme` (the category id), `title` (the category name), `published` and `levels`.
- **A Path Words level entry** has `{id, size, letters, targets, definitions, targetSeconds?}`.
  - `letters.length == size*size`, and `""` marks a blank cell.
  - Each target is `{id, word, start, path, colorIndex}`.
  - Cells are `[r, c]` in JS. Firestore stores them as `{row, col}` (`jsToFirestoreValue`), which the app's `Cell.fromJson` and the Worker's `parseCell` both read.
- **Sizes and word lengths.** Grids are 3–6. Words are lowercase a–z, 3–6 letters.
- **World size.** 20 levels per world by default, at most `MAX_WORLD_LEVELS` (40).
- **Seeds.** `worldLevelSeed(order, index, attempt) = order*1_000_000 + attempt*1_000 + index + 1`.
- **Category share.** At least 0.75 of each board's targets are category words. No word repeats within a world.
- **Every Path Words board passes** `validatePathWordsLevel` and `hardBoardIssues`. Every word has a definition: the category's, else `poolDefinition`.
- **The Path Words publish lock.** For a published world, a save may change only `targetSeconds`; letters, targets and definitions are frozen. Zip's save rules don't change.
- **Stars** are `starsFor(usedHints, seconds, targetSeconds)`, which already exists in both the app and the Worker. Don't change it.
- **Level runs never touch** the daily lock, streaks, the daily hint quota, the home widget, the daily or weekly boards, or `modeRecords`.
- **Copy.**
  - All user-facing copy goes through `AppStrings`, with entries in both `app_text_en.dart` and `app_text_ml.dart`.
  - A Path Words world's name is its doc `title`, shown as-is in every language.
- **Zip's behaviour and look don't change.** Every existing Zip test keeps passing unedited, except for mechanical renames that Task 7 names.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A published Path Words world edited in the admin.** Changing a letter or target must be refused (400 `schema_invalid`). Changing `targetSeconds` must save. *Task 3.*
2. **A category too small to fill a world** (for example 25 words for 20 levels with no repeats). The generator must throw a clear error naming the category and level, not loop forever or return off-theme boards. *Task 2.*
3. **A player opens a Path Words level link while offline, or before worlds load.** The level must fail with `levelFailed`, keep the draft, and not fall back to the daily. *Task 8.*
4. **Switching the Levels tab from Zip to Path Words and back.**
   - Each map shows its own stars.
   - The star link opens that game's Levels board.
   - A level sheet opened from Path Words plays `/path-words`, not `/zip`.
   - Results' Next level stays in the same game.

   *Tasks 8 and 9.*
5. **A Path Words clear whose stroke took a different valid route than the stored path.** The Worker must accept it, as it does for the daily (`checkPathWordsProof`). A stroke that reuses another word's cells must get 422 `bad_proof`. *Task 6.*

---

## Part A — winklo-admin

### Task 1: Word categories

**Files:**
- Create: `workers/admin-api/src/path_words_categories.ts`
- Test: `workers/admin-api/src/path_words_categories.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export type PathWordsCategory = { id: string; name: string; words: Record<string, string> /* word → definition */ };
  export const PATH_WORDS_CATEGORIES: readonly PathWordsCategory[];
  export function pathWordsCategory(id: string): PathWordsCategory | null;
  ```

- [ ] **Step 1: Write the failing tests** in `path_words_categories.test.ts`:
  - `has at least 6 categories, starting animals then food`: `PATH_WORDS_CATEGORIES.length >= 6`, `[0].id === 'animals'`, `[1].id === 'food'`.
  - `ids are unique lowercase slugs`: each id matches `/^[a-z]+(?:_[a-z]+)*$/`, and the names are 1–24 characters.
  - `every category has 60+ usable words`. For each category:
    - `Object.keys(words).length >= 60`;
    - each word matches `/^[a-z]{3,6}$/`, `isCommonWord(word)` is true and `isPluralOfCommon(word)` is false;
    - each definition passes `cleanDefinition(word, def) !== null`.
  - `each length 3–6 has words`: every category has at least 8 words of each length 3, 4 and 5, and at least 4 of length 6.
  - `pathWordsCategory('animals')?.name === 'Animals'`, and `pathWordsCategory('nope') === null`.
- [ ] **Step 2:** Run `cd workers/admin-api && npx vitest run src/path_words_categories.test.ts`. Expected: FAIL (module not found).
- [ ] **Step 3: Write `path_words_categories.ts`.**
  - The categories are Animals, Food, Sports, Nature, Home, Body, and more if you like.
  - Start from `/Users/muhammedfaseencm/winklo/assets/words/categories/{animals,food,sports}.json`.
  - Keep only words that pass the filters above.
  - Write a short, plain definition for each word, 8–90 characters, that doesn't contain the word (`givesWordAway`).
- [ ] **Step 4:** Run the tests. Expected: PASS. If a word fails `isCommonWord`, replace it; don't loosen the test.
- [ ] **Step 5:** Commit with `feat(levels): Path Words word categories`.

### Task 2: World generator

**Files:**
- Create: `workers/admin-api/src/path_words_world_generate.ts`
- Test: `workers/admin-api/src/path_words_world_generate.test.ts`

**Interfaces:**
- Consumes:
  - Task 1's `PathWordsCategory`;
  - the existing `buildHardBoard`, `hardBoardIssues`, `poolForLength`, `poolDefinition`, `validatePathWordsLevel`, `mulberry32`, `shuffleInPlace` and `levelId`.
- Produces:
  ```ts
  export type PathWordsWorldLevel = {
    id: string; size: number; letters: string[];
    targets: HardBoardTarget[]; definitions: Record<string, string>;
    targetSeconds: number; categoryShare: number;
  };
  export function worldLevelSeed(order: number, index: number, attempt: number): number;
  export function pathWordsRamp(index: number, count: number): { size: number; difficulty: PathWordsDifficulty };
  export function suggestedPathWordsTargetSeconds(size: number, wordCount: number): number;
  export const MIN_CATEGORY_SHARE = 0.75;
  export class CategoryTooSmallError extends Error { /* message names category id and level number */ }
  export function generatePathWordsWorld(order: number, category: PathWordsCategory, count?: number): PathWordsWorldLevel[];
  ```

- [ ] **Step 1: Write the failing tests:**
  - **`pathWordsRamp` never gets easier.** For `count` 20, 10 and 40, over `i`:
    - the size never falls;
    - difficulty, ranked easy < medium < hard, never falls;
    - `pathWordsRamp(0, 20)` is `{size: 3, difficulty: 'easy'}`;
    - `pathWordsRamp(19, 20).size === 6`.
  - **`worldLevelSeed(2, 4, 1) === 2_001_005`.**
  - **`suggestedPathWordsTargetSeconds`** is an integer of at least 10, and it rises with size at a fixed word count.
  - **The same world is generated every time.** `generatePathWordsWorld(1, animals)` deep-equals a second call.
  - **The world is 20 valid levels.** For each level:
    - the ids are `path_words_1_01` … `path_words_1_20`;
    - `validatePathWordsLevel(level).ok` is true;
    - `hardBoardIssues(level)` is empty;
    - `level.size === pathWordsRamp(i, 20).size`.
  - **The category dominates each board:** `categoryShare >= 0.75` for every level, and `categoryShare` equals the share of targets whose word is in `category.words`.
  - **No word repeats** across the world's targets.
  - **Every word has a definition:** each target word is a key of `definitions` with a non-empty value.
  - **A tiny category throws.** A category of 12 words throws `CategoryTooSmallError`, and the message includes the category id.
- [ ] **Step 2:** Run `npx vitest run src/path_words_world_generate.test.ts`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - The ramp:
    - size cut-offs at fractions of `count`: 3 below 0.2, 4 below 0.45, 5 below 0.75, else 6;
    - within the 4×4 band, easy for its first half;
    - hard only in the last 0.1;
    - medium otherwise.
  - Per level, for each attempt in 0..40:
    - seed `mulberry32(worldLevelSeed(...))`;
    - `preferred` is the unused category words, shuffled;
    - call `buildHardBoard({size, difficulty, rng, preferred, fallback: (len) => poolForLength(len).filter(w => !used.has(w) && !(w in category.words))})`;
    - accept the board when `preferredUsed/targets.length >= MIN_CATEGORY_SHARE`.

    When every attempt fails, throw `CategoryTooSmallError`.
  - Add the accepted words to `used`.
  - The target time is a per-cell seconds factor plus a per-word allowance. Pick constants that give about 25s at 3×3 and about 120s at 6×6.
- [ ] **Step 4:** Run the tests. Expected: PASS. Also run `npx vitest run src/path_words_hard_board.test.ts`; it must stay green.
- [ ] **Step 5:** Commit with `feat(levels): Path Words world generator with a category ramp`.

### Task 3: Path Words worlds in admin-api (save, publish lock, generate, categories)

**Files:**
- Modify: `workers/admin-api/src/levels.ts:5` (`LEVEL_GAMES`)
- Modify: `workers/admin-api/src/level_worlds_write.ts`:
  - `checkWorld` branches by game;
  - add Path Words board to/from stored;
  - `StoredWorldFacts` carries the stored boards.
- Modify: `workers/admin-api/src/level_worlds_routes.ts` (PUT passes the stored boards; the per-game store mapping)
- Modify: `workers/admin-api/src/levels.ts` (`world()` returns Path Words boards in the editor shape)
- Modify: `workers/admin-api/src/index.ts` (two new routes before `worldMatch`)
- Test: `workers/admin-api/src/level_worlds_write.test.ts`, `workers/admin-api/src/levels_write.routes.test.ts`, `workers/admin-api/src/levels.routes.test.ts`

**Interfaces:**
- Consumes: Task 1's `PATH_WORDS_CATEGORIES`/`pathWordsCategory`, and Task 2's `generatePathWordsWorld`/`CategoryTooSmallError`.
- Produces:
  - `LEVEL_GAMES = ['zip', 'path_words']`.
  - `type StoredWorldFacts = { published: boolean; levelIds: string[]; boards?: Record<string, unknown>[] } | null`.
  - `export function pathWordsBoardToStored(b: PathWordsWorldBoard): Record<string, unknown>` and `export function pathWordsBoardFromStored(raw): PathWordsWorldBoard`, where `PathWordsWorldBoard = {id, size, letters, targets, definitions, targetSeconds?: number | null}`.
  - `GET /v1/levels/path_words/categories` returns `{categories: [{id, name, wordCount}]}`.
  - `POST /v1/levels/path_words/generate` with body `{order, categoryId, count?}`:
    - success: `{levels: PathWordsWorldLevel[]}`;
    - `400 invalid_body` / `unknown_category`;
    - `422 {error: 'category_too_small', message}`.

    Both routes run behind `requireAdmin`.

- [ ] **Step 1: Write failing `checkWorld` tests** for `game = 'path_words'`:
  - **A world from `generatePathWordsWorld(1, animals)` is valid:** saved with `theme: 'animals'`, `title: 'Animals'` and `stored: null`, it gives no issues.
  - **The theme must be a category:** `theme: 'ink'` gives an issue at `theme`.
  - **A broken board is refused:** removing one letter gives an issue at `levels.0.letters`, and a size of 7 gives an issue at `levels.0.size`.
  - **Mixed sizes are allowed for Path Words.** This is the opposite of Zip's same-size rule.
  - **Published: the target time may change.** With `stored = {published: true, levelIds, boards: <same boards>}` and `targetSeconds` changed, there are no issues.
  - **Published: letters are frozen.** With the same `stored` and one letter changed, there's an issue at `levels.0`. The message includes "published".
  - **Zip is unchanged.** The existing Zip tests pass untouched.
- [ ] **Step 2: Write failing route tests:**
  - **`GET /v1/levels/path_words/worlds`** returns 200. The existing test pattern covers it.
  - **`POST .../path_words/generate`** with `{order: 1, categoryId: 'animals'}` returns 200 and 20 levels. With `categoryId: 'nope'` it returns 400 `unknown_category`.
  - **`GET .../path_words/categories`** lists `animals` first.
  - **`POST .../zip/generate`** returns 404.
  - **The PUT round trip.** PUT a generated Path Words world, then GET it: the boards are equal, and the cells come back as `[r, c]`.
  - **Publishing in order holds for `path_words`:** publishing world 2 before world 1 returns 409 `publish_order`.
- [ ] **Step 3:** Run `npx vitest run src/level_worlds_write.test.ts src/levels_write.routes.test.ts src/levels.routes.test.ts`. Expected: the new tests FAIL.
- [ ] **Step 4: Implement.**
  - `checkWorld` keeps today's Zip code under `if (game === 'zip')`. The Path Words branch checks:
    - the theme is a category id;
    - the title is 1–40 characters;
    - the levels list is 1–`MAX_WORLD_LEVELS` long;
    - each id is `levelId(...)`;
    - each board passes `validatePathWordsLevel` and has a definition for every target;
    - the target time is the same as Zip's;
    - the publish lock: compare each level's `{size, letters, targets, definitions}` with `stored.boards[i]` after normalising both through `pathWordsBoardFromStored`.
  - The PUT handler passes `boards: existing.levels`.
  - `LevelsStore.world()` uses `pathWordsBoardFromStored` when the game is `path_words`.
  - Saving maps the levels with the per-game `…ToStored`.
- [ ] **Step 5:** Run the whole admin-api suite with `npx vitest run`. Expected: PASS.
- [ ] **Step 6:** Commit with `feat(levels): admin-api saves, locks and generates Path Words worlds`.

### Task 4: Publish script (Claude's direct path)

**Files:**
- Create: `workers/admin-api/src/publish_path_words_world.ts`, the testable core.
- Create: `tools/publish-path-words-world.mjs`, the command-line wrapper.
- Test: `workers/admin-api/src/publish_path_words_world.test.ts`
- Modify: `tools/package.json`, adding the `tsx` dev dependency if it's missing.

**Interfaces:**
- Consumes:
  - Task 2's `generatePathWordsWorld`;
  - Task 3's `checkWorld` and `pathWordsBoardToStored`;
  - the existing `checkPublish` and `LevelsStore`.
- Produces:
  ```ts
  export type PublishStore = Pick<LevelsStore, 'worlds' | 'world' | 'saveWorld' | 'setPublished'>;
  export async function publishPathWordsWorld(
    store: PublishStore,
    opts: { order: number; categoryId: string; count?: number; actor: { uid: string; email: string | null } },
  ): Promise<{ levels: { id: string; size: number; words: string[]; categoryShare: number }[] }>;
  // Throws Error with message 'world_published' | 'publish_order:<n>' | 'unknown_category' | 'schema_invalid:<json>'
  ```
- The command line is `node --import tsx tools/publish-path-words-world.mjs --order N --category <id> [--count 20]`.
  - It needs `GOOGLE_APPLICATION_CREDENTIALS`.
  - It gets an access token with `google-auth-library` for scope `https://www.googleapis.com/auth/datastore`, then builds `new LevelsStore('brain-zip-app', token)`.
  - It prints one line per level and exits non-zero on any error.

- [ ] **Step 1: Write failing tests** with an in-memory fake `PublishStore`:
  - **It saves, then publishes, world 1.** The fake has `published: true`, the theme is the category id, the title is the category name, and 20 levels are stored.
  - **It refuses when world 1 isn't published:** `order: 2` with no world 1 throws `publish_order:1`.
  - **It refuses a world that's already published** with `world_published`, and writes nothing.
  - **It replaces an unpublished draft:** a draft at the same order is overwritten using its `updateTime`, then published.
  - **It refuses an unknown category** with `unknown_category`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement the core and the wrapper.**
  - The order of operations is: generate → `checkWorld` → `checkPublish` → `saveWorld` → `setPublished`.
  - The wrapper reads its arguments as `tools/set-admin-claim.mjs` does.
- [ ] **Step 4:** Run the tests. Expected: PASS. Then run `node --import tsx tools/publish-path-words-world.mjs --help`, which prints usage and exits 0.
- [ ] **Step 5:** Commit with `feat(levels): script that generates and publishes a Path Words world`.

### Task 5: Admin Levels page — the game switcher and the Path Words editor

**Files:**
- Modify: `src/pages/levels/LevelsPage.tsx` (the `LEVELS_GAME` constant becomes a `game` state; a Zip / Path Words switcher; the URL query `?game=path_words` holds it)
- Modify: `src/pages/levels/WorldEditorPage.tsx`, `worldDraft.ts`, `LevelEditModal.tsx` and `GenerateWorldModal.tsx`, each branching on game
- Create: `src/pages/levels/PathWordsBoardPreview.tsx`
- Modify: the levels API client and mocks (`src/queries/*levels*`, `src/mocks/*`): add `pathWordsCategories()` and `generatePathWordsWorld(order, categoryId, count)`
- Test: `LevelsPage.test.tsx`, `WorldEditorPage.test.tsx`, `GenerateWorldModal.test.tsx` and `worldDraft.test.ts`, plus a new `PathWordsBoardPreview.test.tsx`

**Interfaces:**
- Consumes: Task 3's routes and response shapes.
- Produces: no new interfaces used later.

- [ ] **Step 1: Write failing tests:**
  - **The switcher.** Picking Path Words shows the Path Words worlds list from the mock API, the URL carries `game=path_words`, and Players and Stats get `game="path_words"`.
  - **The Path Words editor.**
    - It shows a category `<select>` filled from `pathWordsCategories()`, with no theme dropdown.
    - Choosing "Food" sets both the theme and the title.
  - **Generate world on a Path Words draft** calls `generatePathWordsWorld(order, categoryId, 20)` and fills 20 levels.
    - With levels already there, it asks "Replace all N levels?" first, as Zip does.
    - On a 422 `category_too_small`, a toast shows the server's message.
  - **A published Path Words world.** In its level modal only the target time is editable, and the board preview is read-only.
  - **`PathWordsBoardPreview`** renders `size*size` cells, shows each target word in a list, and gives each blank cell `aria-label="blank"`.
  - **Zip unchanged.** The existing Zip editor tests pass untouched.
- [ ] **Step 2:** Run `npx vitest run src/pages/levels`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.** Reuse `levels.css`. The preview is a CSS grid of letters with target colours from `colorIndex`.
- [ ] **Step 4:** Run `npx vitest run` and `npm run build`. Expected: PASS, and the build succeeds.
- [ ] **Step 5:** Commit with `feat(levels): admin Levels page edits and generates Path Words worlds`.

## Part B — winklo

### Task 6: Leaderboard Worker accepts Path Words level clears, plus rules tests

**Files:**
- Modify: `workers/leaderboard/src/limits.ts:65` (`LEVEL_GAMES = ['zip', 'path_words']`)
- Modify: `workers/leaderboard/src/level_board.ts:60-76` (`findLevel` becomes per game)
- Modify: `workers/leaderboard/src/level_submit.ts:89-90` (the proof check per game; the header comment)
- Test: `workers/leaderboard/src/level_board.test.ts`, `level_submit.test.ts` and `limits.test.ts`
- Test: `firestore/rules_test/leaderboards.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export type LevelPuzzle = { game: 'zip'; puzzle: ZipPuzzle } | { game: 'path_words'; puzzle: PathWordsPuzzle };
  export function findLevel(worldDoc, levelId: string, game: LevelGameId): { level: LevelPuzzle; targetSeconds: number | null } | null;
  ```

- [ ] **Step 1: Write failing tests.** Use a fixture world `path_words_1` with one published 3×3 level: two targets plus a blank cell.
  - **`findLevel` parses Path Words.** With game `'path_words'` it returns a `path_words` puzzle. It returns null for an unpublished doc, and null for a Zip-shaped level under `path_words`.
  - **The clear is accepted with stored paths.** A proof `{strokes: [{targetId, cells: stored path}]}` gives 200 `{accepted: true, improved: true}`. The board row is written at `leaderboards/path_words/levels/{uid}`, and the stars come from the level's `targetSeconds`.
  - **The clear is accepted on an alternate route.** A stroke that spells the word along a different adjacent route that stays off the other words' cells gives 200.
  - **A bad proof is refused.** A stroke reusing another target's cell gives 422 `bad_proof`.
  - **A missing level** gives 422 `not_live`.
  - **The Zip clear tests** pass unchanged.
  - **Rules (`leaderboards.test.ts`).**
    - `leaderboards/path_words/levels/{uid}` can be read signed out.
    - The owner's profile-only update succeeds, and a `stars` change fails.
    - Create and delete fail.
    - `level_records` can be read by the owner only.
- [ ] **Step 2:** Run `cd workers/leaderboard && npx vitest run`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
  - `findLevel` switches on the game: `parseZipPuzzle` or `parsePathWordsPuzzle`.
  - `handleLevelClear` calls `checkZipProof` or `checkPathWordsProof` to match.
- [ ] **Step 4:** Run `npx vitest run`. Expected: PASS. Then run the rules tests with `cd firestore/rules_test && JAVA_HOME=/opt/homebrew/opt/openjdk@21 npx firebase emulators:exec --only firestore "npx vitest run"`, using the project's existing command. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(leaderboard): Path Words level clears`.

### Task 7: App domain — Path Words level entries and world names

**Files:**
- Modify: `lib/domain/game_ids.dart` (`levelGameIds = {GameIds.zip, GameIds.pathWords}`; update the doc comment)
- Modify: `lib/domain/entities/level_world.dart`:
  - `LevelWorld.title`;
  - `LevelEntry.boardSize`;
  - `LevelEntry.pathWordsPuzzle`;
  - keep `zipLevelSize` as a deprecated forward to `boardSize`, or rename it at every call site.
- Modify: `lib/core/strings/app_strings.dart`, `app_text.dart`, `app_text_en.dart` and `app_text_ml.dart` (the world-name helpers)
- Modify: the call sites of `levelWorldTitle`, `levelRunLabel` and `levelOpenWorld`:
  - `lib/features/levels/view/**`;
  - `lib/features/zip/bloc/zip_bloc.dart:767`;
  - `lib/features/results/**`.
- Modify: `lib/features/results/results_args.dart` (`nextWorldTheme` becomes `nextWorldName`, a display name; it adds `game`)
- Test: `test/domain/entities/level_world_test.dart`, `test/core/strings/*` (where they exist), and the existing Zip and results tests updated for the rename

**Interfaces:**
- Produces:
  - `LevelWorld({..., String title = ''})` and `LevelWorld.fromJson`, which reads `title` (or `''` when it isn't a string).
  - `int get LevelEntry.boardSize`, read from `board['size']`, or 0.
  - `PathWordsPuzzle get LevelEntry.pathWordsPuzzle`, which is `PathWordsPuzzle.fromJson(board, id: id)` and throws on a malformed board.
  - `static String AppStrings.levelWorldDisplayName(LevelWorld world)`. It returns `world.title` for Path Words when that's not empty, and otherwise `levelWorldName(world.theme)`.
  - `levelWorldTitle(int order, String worldName)`, `levelRunLabel(int number, String worldName)` and `levelOpenWorld(String worldName)` now take the **display name**. Callers pass `levelWorldDisplayName(world)`.
  - `LevelResultInfo.nextWorldName` (`String?`).
  - `LevelResultInfo.game` (`String`, default `GameIds.zip`), used by Task 8.

- [ ] **Step 1: Write failing tests:**
  - **`LevelWorld.fromJson`** reads `title`. A missing title is `''`.
  - **`LevelEntry.boardSize`** is 4 for `{size: 4}` and 0 when the size is missing.
  - **`LevelEntry.pathWordsPuzzle`.** For a Path Words level map with `{row, col}` cells it parses:
    - the letters;
    - the targets, with `start` and `path` as `Cell`s;
    - the definitions.

    A level without `letters` throws.
  - **`levelWorldDisplayName`:**
    - a Path Words world titled "Animals" gives `'Animals'` in both en and ml;
    - a Zip world with theme `ink` gives today's ink name;
    - a Path Words world with an empty title falls back to `levelWorldName(theme)`.
- [ ] **Step 2:** Run `flutter test test/domain/entities/level_world_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Update every caller (find them with `grep -rn "levelWorldTitle\|levelRunLabel\|levelOpenWorld\|nextWorldTheme\|zipLevelSize" lib test`). The Zip output text doesn't change.
- [ ] **Step 4:** Run `flutter analyze` and `flutter test`. Expected: no issues, all tests pass.
- [ ] **Step 5:** Commit with `feat(levels): Path Words level entries and world display names`.

### Task 8: `PathWordsBloc` level mode, the screen wiring and results

**Files:**
- Modify: `lib/features/path_words/bloc/path_words_bloc.dart`:
  - constructor: `levelWorlds`, `recordLevelClear`, `submitLevelClear`, `levelProgress`, `recordLevelPlay`, as in `ZipBloc`;
  - `_startOffDaily`: a level branch;
  - `_finishOffDaily`: becomes `_finishLevel` when `mode.isLevel`;
  - the hint and start counters.
- Modify: `lib/features/path_words/view/path_words_screen.dart` (pass the level dependencies when `widget.mode.isLevel`, as `zip_screen.dart:153-167` does; show the level goals bar as `zip_screen.dart:366` does)
- Modify: `lib/features/results/view/level_results_view.dart:128` (Next level goes to `gameRoute(level.game)`, not `'/zip'`)
- Test: `test/features/path_words/bloc/path_words_bloc_level_test.dart` (new), `test/features/results/view/level_results_view_test.dart`

**Interfaces:**
- Consumes:
  - Task 7's `LevelEntry.pathWordsPuzzle`, `LevelResultInfo.game` and `levelWorldDisplayName`;
  - the existing `LevelWorldRepository.catalog(game)`, `LevelMap.build(...).isPlayable`, `RecordLevelClear`, `SubmitLevelClear`, `RecordLevelPlay`/`LevelPlayEvent`, and `PathWordsLeaderboardProof.fromRun(...)`. Read its factory at `lib/domain/entities/leaderboard_proof.dart:114` for its parameters.
- Produces: `PathWordsBloc(mode: PlayMode.level(id), levelWorlds:, recordLevelClear:, submitLevelClear:, levelProgress:, recordLevelPlay:)`. The assert matches ZipBloc's: `!mode.isLevel || (levelWorlds != null && recordLevelClear != null)`.

- [ ] **Step 1: Write failing `bloc_test`s,** with mocktail mocks for every repository and use case:
  - **The level loads from the catalog.** The board equals `slot.entry.pathWordsPuzzle`, the status is playing, and `recordLevelPlay` gets `LevelPlayEvent.start` with `game: 'path_words'`.
  - **A locked level fails** with `AppStrings.levelLockedMessage`.
  - **An unknown level** fails with `levelFailed` and clears the draft.
  - **`LevelsUnavailable`** fails with `levelFailed` and keeps the draft.
  - **A resumed draft** restores the found words and records no start.
  - **A clear records and submits.**
    - `recordLevelClear(game: 'path_words', ...)` is called once.
    - `submitLevelClear(game: 'path_words', levelId:, proof: isA<PathWordsLeaderboardProof>())` is called once.
    - The results have `local.kind == LocalResultKind.level`, `level.game == 'path_words'` and `nextLevelId` set.
  - **No daily side effects.** In a level clear, the streak, the daily lock, the daily hint quota, the widget, `modeRecords` and the daily leaderboard submit are never called. Verify these with `verifyNever`.
  - **A hint in a level** gives `LevelPlayEvent.hint`, doesn't use the daily hint quota, and the clear's `usedHints` is true.
  - **`level_results_view`:** Next level for `game: 'path_words'` pushes `PlayMode.level(next).location('/path-words')`, and for Zip it still pushes `/zip`.
- [ ] **Step 2:** Run `flutter test test/features/path_words test/features/results`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement,** mirroring `ZipBloc` at `zip_bloc.dart:512-600` and `:715-790`. Use `GameIds.pathWords`, and `PathWordsLeaderboardProof.fromRun` built from the run's correct strokes. A level's hint cost comes from the existing off-daily hint path, minus any `modeRecords` writes.
- [ ] **Step 4:** Run `flutter analyze` and `flutter test`. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(path-words): level mode — play, stars, submit and results`.

### Task 9: Levels tab game switcher

**Files:**
- Modify: `lib/features/levels/view/levels_screen.dart`:
  - lines 300-330: the chips become a switcher;
  - one `LevelMapCubit` per game;
  - `_StarsLink` goes to the chosen game's board.
- Modify: `lib/features/levels/view/widgets/level_sheet.dart:194` (the Play route is `gameRoute(slot.world.game)`; the size uses `boardSize`)
- Modify: `lib/core/router/play_mode_route.dart:10-13` (`levelsBoardLocation` becomes `levelsBoardLocationFor(String gameId)`; keep a `levelsBoardLocation` const for Zip, or replace its callers)
- Create: `lib/domain/repositories/levels_game_preference_repository.dart` and `lib/data/repositories/levels_game_preference_repository_impl.dart` (SharedPreferences key `levels_selected_game`), registered in `lib/core/di/app_repositories.dart`
- Modify: `lib/features/levels/view/widgets/world_backdrop_painter.dart`, `level_path_painter.dart` and `level_node.dart` (an unknown theme keeps the plain fallback; the optional category tint is the builder's choice)
- Modify: the strings for the switcher's accessibility labels, if any are new (en and ml)
- Test: `test/features/levels/view/levels_screen_test.dart`, `test/features/levels/view/widgets/level_sheet_test.dart`, `test/data/repositories/levels_game_preference_repository_impl_test.dart`, `test/core/router/play_mode_route_test.dart`

**Interfaces:**
- Consumes: Task 7's `boardSize` and `levelWorldDisplayName`, and `LevelMapCubit(game:)`, which already exists.
- Produces:
  - `abstract class LevelsGamePreferenceRepository { String read(); Future<void> write(String gameId); }`. `read` returns `GameIds.zip` when the stored value is unset or not in `levelGameIds`.
  - `String levelsBoardLocationFor(String gameId) => '/leaderboard?game=$gameId&board=levels';`

- [ ] **Step 1: Write failing tests:**
  - **The switcher shows the Path Words map.** Tapping the Path Words chip shows its worlds (title "Animals") and calls `write('path_words')`. The Sudoku chip still reads "Sudoku · Soon" and does nothing.
  - **The chosen game is remembered.** With `read()` returning `path_words`, the tab opens on Path Words.
  - **The star link follows the game.** On Path Words it goes to `levelsBoardLocationFor('path_words')` with a `levelsVisitToken` extra.
  - **Each game has its own stars.** The Zip and Path Words totals come from their own `LevelProgressRepository.progress(game)`.
  - **The sheet plays Path Words.** Play on a Path Words node pushes `/path-words?mode=level&level=path_words_1_01`. The size chip reads "3 × 3".
  - **`playModeRedirect`** lets `/path-words?mode=level&level=path_words_1_01` through (null), and still redirects `/path-words?mode=level&level=zip_1_01` to `/levels`.
  - **The preference repository** round-trips, and an unknown stored value reads as `zip`.
- [ ] **Step 2:** Run `flutter test test/features/levels test/core/router test/data/repositories/levels_game_preference_repository_impl_test.dart`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.** Keep the `?open=` deep link working. An `open=path_words_…` id selects Path Words before opening the sheet.
- [ ] **Step 4:** Run `flutter analyze` and `flutter test`. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(levels): game switcher — Path Words map, sheet and board link`.

### Task 10: Path Words on the Levels leaderboard

**Files:**
- Modify: anything under `lib/features/leaderboard/` that is still Zip-only after `levelGameIds` grows:
  - `leaderboard_screen.dart` (`_RouteGameSync` for `game=path_words&board=levels`);
  - `leaderboard_levels_note.dart`;
  - `player_card_sheet.dart` (Levels stats for the selected game);
  - `leaderboard_board_sheet.dart`.
- Modify: `lib/data/repositories/leaderboard_repository_impl.dart` (`myBoardLevelIds(game)` and the Levels period queries already take a game; check that nothing hard-codes `zip`)
- Test: `test/features/leaderboard/**`, `test/data/repositories/leaderboard_repository_impl_test.dart`

**Interfaces:**
- Consumes: `levelGameIds`, now including Path Words, from Task 7, and `levelsBoardLocationFor` from Task 9.

- [ ] **Step 1: Write failing tests:**
  - **The Levels period exists for Path Words.** On the Board tab with Path Words selected, Levels is offered, and the cubit reads `leaderboards/path_words/levels`, using the fake Firestore from the existing tests.
  - **The route opens it.** `/leaderboard?game=path_words&board=levels` opens Path Words on Levels.
  - **The player card shows Path Words Levels stats** from that game's row.
  - **The empty-board note** names replaying a Path Words level. It reuses the existing note copy, with the game in the context.
  - **Sudoku** still has no Levels period.
  - **Profile changes reach the row.** `leaderboardIdentityDocPaths` includes `leaderboards/path_words/levels/{uid}`.
- [ ] **Step 2:** Run `flutter test test/features/leaderboard test/data`. Expected: the new tests FAIL, or pass already where `levelGameIds` was enough. Keep those as regression tests.
- [ ] **Step 3: Implement** whatever is still Zip-only (`grep -rn "GameIds.zip\|'zip'" lib/features/leaderboard`).
- [ ] **Step 4:** Run `flutter analyze` and `flutter test`. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(leaderboard): Path Words Levels board`.

### Task 11: End-to-end check in the emulator, and rollout notes

These steps are **outward actions**. Ask the user before each deploy or publish; the plan doesn't authorise them.

**Files:**
- Modify: `README.md` (winklo: the rollout checklist for Path Words Levels) and `README.md` (winklo-admin: the script usage)

- [ ] **Step 1:** Run both repos' full suites:
  - `flutter analyze && flutter test` in winklo;
  - `npx vitest run` in `workers/leaderboard`;
  - in winklo-admin, `npx vitest run` and `npm run build`, then `npx vitest run` in `workers/admin-api`.

  Expected: all green.
- [ ] **Step 2:** Add the rollout checklist (spec § Rollout) and the script usage, including the `GOOGLE_APPLICATION_CREDENTIALS` requirement, to the READMEs. Commit with `docs(levels): Path Words Levels rollout and script usage`.
- [ ] **Step 3: With the user's go-ahead,** deploy:
  - the leaderboard Worker;
  - the rules and indexes;
  - admin-api.

  Then run the script for `--order 1 --category animals` and `--order 2 --category food`.
- [ ] **Step 4: Check in the emulator.** Open Levels and switch to Path Words, then check:
  - World 1 "Animals" shows;
  - playing and clearing level 1 shows stars on the map;
  - the star link opens the Path Words Levels board with the row;
  - after switching back to Zip, its map and board are unchanged.
