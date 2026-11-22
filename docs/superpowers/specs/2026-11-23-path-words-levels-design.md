# Path Words Levels — design

Date: 2026-11-23
Repos: `winklo` (app, leaderboard Worker, rules) and `winklo-admin` (admin-api, Levels page, a publish script)
Builds on: [Zip Levels](2026-10-31-zip-levels-design.md), [Admin Levels](2026-11-02-admin-levels-design.md), [Levels leaderboard](2026-11-18-levels-leaderboard-design.md)

## Why

Zip Levels shipped in 1.2.0. Path Words only has the daily, the archive and practice. Practice boards are random and come and go, so there is nothing to work through, nothing to come back to and nothing to compare. Path Words Levels gives the second game the same long-term pull as Zip.

## What players get

All four of these are goals:

- **A steady difficulty ramp.** Levels get harder in a fixed order.
- **Themed word sets.** Every world is one word category, such as Animals or Food, and its words come from that category.
- **Progress to collect.** A map of numbered levels with up to three stars each, exactly like Zip.
- **Fixed, shareable boards.** Level 7 is the same board for everyone, so stars and times can be compared on a Path Words Levels board.

## Non-goals

- Sudoku Levels.
- New artwork per world. The backdrop stays plain or lightly tinted, and the category is the theme.
- Malayalam word sets. Path Words is English letters a–z only.
- Star-gated unlocks or rewards.
- Merging the Path Words and Zip boards into one.

## Anti-goals

- **A level board changing after it has been published.** That would break fixed boards and the stars already earned on them.
- **A clear counting without the Worker checking it.**
- **Words outside a world's category, or obscure words, on a themed board.**
  - The existing filters stay in force: common words, no plurals of common words, a definition for every word.
  - A word from the general pool may fill a gap, but only when the category list can't fill it.
- **Anything that changes how Zip Levels looks or behaves.**

## Decisions made with you

| Topic | Decision |
|---|---|
| Who makes boards | Both the admin's **Generate world** and a **script Claude runs** that writes straight into the backend |
| Script output | **Published straight away**, with no draft review step |
| World size | **Same as Zip**: 20 levels per world, 2 worlds at launch |
| Ramp | **The grid and the words both grow** within a world. Early levels are small grids with a few short words; later ones reach 6×6 with more and longer words |
| Theme | **One word category per world** |
| Leaderboard | **Its own Path Words Levels board**, chosen with the game switcher, with the same rules as Zip's |
| Scope | **Everything in one round**: the app, the Worker, admin-api, the admin page and the script |
| Generator home | **Approach A**: one TypeScript generator used by both the admin and the script |

## Approaches

- **A. One TypeScript generator in winklo-admin, used by both the admin and the script.** Chosen.
  - admin-api already builds dense Path Words boards on the server (`buildHardBoard`, its word pool and definitions, and `validatePathWordsLevel`) for the daily auto-puzzle. Levels reuse that code.
  - The admin's Generate world and Claude's script call the same functions, so their boards are the same kind.
- **B. Extend the app's Dart `PathWordsGenerator` and run it from a Dart command-line script.** Rejected. The browser admin can't run Dart, so admin would need a second, TypeScript generator, and the two would drift apart.
- **C. Claude lays out boards by hand, with no generator.** Rejected. Its boards wouldn't match admin's, and each one would still need its own checks.

## Data

### World doc: `level_worlds/path_words_{order}`

This is the same collection and the same rules as Zip: published worlds are public, admins see drafts, and the client never writes.

```jsonc
{
  "game": "path_words",
  "order": 1,
  "theme": "animals",        // the category id
  "title": "Animals",        // the category name the app shows
  "published": true,
  "levels": [
    {
      "id": "path_words_1_01",
      "size": 3,
      "letters": ["c","a","t", ...],              // size × size; "" marks a blank cell
      "targets": [{"id","word","start","path","colorIndex"}],
      "definitions": {"cat": "A small furry pet that purrs"},
      "targetSeconds": 25
    }
  ]
}
```

- A level's board uses **exactly the shape of the daily `path_words_levels` doc**. That way:
  - the app parses it with `PathWordsPuzzle.fromJson`;
  - the Worker parses it with `parsePathWordsPuzzle`.
- Level ids match `PlayMode.levelIdPattern`, for example `path_words_1_07`.

### Categories: `winklo-admin/workers/admin-api/src/path_words_categories.ts`

- This is a hand-curated list. Claude writes it.
- Each category has:
  - an id;
  - a name;
  - at least 60 common words of 3–6 letters, each with a short definition. The definition must not give the word away (`givesWordAway`).
- Launch has at least 6 categories, enough for future worlds. World 1 is Animals and World 2 is Food.
- The app's `assets/words/categories/*.json` (Animals, Food, Sports) is the starting point. The lists need cleaning: only common words that pass `isCommonWord`.

## Generator (admin-api)

`generatePathWordsWorld(order, category, count = 20)` returns `count` boards.

- **Seed.** Each board's seed is `worldLevelSeed(order, index, attempt)`, the same formula Zip uses, so a re-run gives the same world. Move it, or copy it, into admin-api.
- **Ramp.** The ramp is `pathWordsRamp(index, count)` and runs across the whole world.

  | Levels (of 20) | Grid | Difficulty band |
  |---|---|---|
  | 1–4 | 3×3 | easy |
  | 5–9 | 4×4 | easy, then medium |
  | 10–15 | 5×5 | medium |
  | 16–20 | 6×6 | medium, then hard |

  The exact cut-offs are left to the builder, as long as the ramp only ever gets harder.
- **Word choice.** Boards come from `buildHardBoard`:
  - `preferred` is the category's words, shuffled by the seed;
  - `fallback` is `poolForLength`.

  A board uses as many category words as fit. Its share of category words (`preferredUsed / targets.length`) must be **at least 0.75**. A board under that is retried, and after the tries run out the generator throws. It never publishes a board that is off-theme.
- **No repeats within a world.** A word used in one level of a world isn't used again in that world.
- **Checks.** Every board must pass `validatePathWordsLevel` and `hardBoardIssues`.
- **Definitions.** Each word gets its category definition, or else `poolDefinition`.
- **Target time.** `suggestedPathWordsTargetSeconds(size, wordCount)` sets the third-star time. It grows with the number of cells, and the admin can edit it.

## admin-api changes

- `LEVEL_GAMES` becomes `['zip', 'path_words']`.
  - Every `/v1/levels/:game/...` route (worlds, progress, stats, save, publish, unpublish, delete) now accepts Path Words.
  - The existing rules still apply: worlds publish in order, and a world stays published while a later one is.
- `save` validates Path Words boards with `validatePathWordsLevel`. Zip keeps its own check.
- A new route, `POST /v1/levels/path_words/generate`, takes `{order, categoryId, count}` and returns boards for the admin editor. Generation runs on the server, the way the daily auto-puzzle does.
- A new route, `GET /v1/levels/path_words/categories`, lists category ids and names for the admin's picker.
- **The publish lock still applies.** A published world's boards can't be changed. Only `targetSeconds` stays editable, exactly as for Zip.

## Admin page (winklo-admin SPA)

- The Levels page gets a game switcher with Zip and Path Words. The routes are already keyed by game.
- For Path Words, the world editor shows:
  - a **category picker** instead of the visual-theme dropdown, which sets both `theme` and `title`;
  - a Path Words board preview for each level (letters grid and word list);
  - target time.
- **Generate world** calls the new generate route. It works only on drafts and asks before replacing levels, exactly as it does for Zip.
- The Players and Stats tabs work per game unchanged.

## Script: Claude's direct path

`winklo-admin/tools/publish-path-words-world.mjs --order N --category animals [--count 20]`

- It runs the **same `generatePathWordsWorld`**. It's a TypeScript import, run with `tsx`.
- It writes and publishes `level_worlds/path_words_N` through the **same LevelsStore logic** admin-api uses, so the rules hold:
  - worlds publish in order;
  - a published world is never overwritten;
  - every board is validated.
- **Credentials.** It reads `GOOGLE_APPLICATION_CREDENTIALS`, a Firebase service-account JSON, as `tools/set-admin-claim.mjs` does. Before the script can run, the user needs that JSON on disk; the earlier one was deleted.
- **It publishes straight away**, as decided.
- **It refuses** when world N already exists as published, or when world N−1 isn't published.
- It prints a summary for each level: size, words and category share.

## Leaderboard Worker (`winklo/workers/leaderboard`)

- `LEVEL_GAMES` becomes `['zip', 'path_words']`.
- **Clear check.** `handleLevelClear` picks the check by game:
  - `checkZipProof` for Zip;
  - `checkPathWordsProof` for Path Words, run on the level's board, parsed with `parsePathWordsPuzzle`.

  The proof is the same `{strokes: [{targetId, cells}]}` the daily sends.
- `MIN_SECONDS.path_words` already exists, and the same minimum applies.
- `findLevel` reads the board fields from a Path Words level entry.
- Stars, records, totals and the board row don't change. They are already per game.
- Account deletion already wipes `leaderboards/{game}/levels` and `level_records` for every game in `LEADERBOARD_GAMES`, which includes `path_words`. No change is needed.

## Firestore

- `leaderboards/path_words/levels/{uid}` and `level_records/{uid}` are already covered by the `{gameId}` matches.
  - `validGame` already accepts `path_words`.
  - The composite index on `levels` is scoped to the collection, so it also covers Path Words. Deploy it anyway.
- No rule changes are expected beyond the game list. Rules tests add Path Words cases for the levels board.

## App (`winklo`)

- **`levelGameIds`** becomes `{zip, pathWords}`. Everything gated on it opens up for Path Words:
  - routing;
  - the Levels period on the Board tab;
  - the sheet;
  - the notes.
- **`LevelEntry`.** The fields are currently Zip-only (`zipLevel`, `zipLevelSize`).
  - Add `pathWordsPuzzle`.
  - Make the size game-neutral: `boardSize` reads `size` for both games.

  The sheet's size chip works for both.
- **The Levels tab game switcher.** The Path Words chip becomes real.
  - Choosing it swaps the map to `LevelMapCubit(game: pathWords)`.
  - The chosen game is remembered as a per-device preference.
  - The star total and its link open **that game's** Levels board.
  - The Sudoku chip stays as "Soon".
- **World titles.** For Path Words, the map shows the world's `title`, the category name, through `levelWorldTitle`.
  - The theme id has no artwork, so the backdrop painter's plain fallback applies, plus an optional category tint.
  - Zip themes don't change.
- **The sheet.** Path Words shows the grid size and best time, and the same three goals: clear, no hints, and under the target time.
  - Play goes to `PlayMode.level(id).location('/path-words')`.
  - The "not on the board yet" line works per game.
- **`PathWordsBloc` level mode.** This mirrors `ZipBloc` level mode:
  - the board comes from the world catalog;
  - drafts are kept per level under the mode's run id;
  - the best clear goes to `LevelProgressRepository`;
  - `RecordLevelPlay` counts starts, clears and hints;
  - every clear goes to `SubmitLevelClear` with the stroke proof;
  - the results screen shows stars, the goals bar, Next level and Back to map.

  Level runs never touch the daily lock, streaks, the daily hint quota, the widget or the daily boards. That's the same rule as Zip.
- **The Board tab.** With Path Words selected, the Levels period reads `leaderboards/path_words/levels`. The player card shows Path Words Levels stats.
- **Strings.** Any new copy goes through `AppStrings`, in en and ml. Category names come from the world doc's `title` and stay in English.

## Testing

- **admin-api (vitest).**
  - The same seed gives the same world.
  - The ramp only gets harder.
  - Every board passes validation.
  - The category share is at least 0.75, and the generator throws when it can't be met.
  - No word repeats within a world.
  - The routes accept `path_words`.
  - Saving a Path Words board that fails validation is refused.
  - The publish order and the lock hold for Path Words.
- **The script.** Run against the mock store and the Firestore emulator. It refuses when the previous world is missing, and refuses when the world is already published.
- **Leaderboard Worker.**
  - A Path Words level clear is accepted with a valid proof and refused with a bad one (422 `bad_proof`).
  - `not_live` when the level is missing.
  - Stars come from the board's `targetSeconds`.
- **Rules tests.** The Path Words levels row: public read, profile-only update, no create or delete.
- **App (`bloc_test` and `mocktail`).**
  - `PathWordsBloc` level mode:
    - start, resume and replay;
    - a clear records progress and stats, and submits;
    - no effect on the daily.
  - `LevelMapCubit` with `game: pathWords`.
  - Widget tests: the game switcher, a Path Words world title, the sheet's Play route, and the Levels board for the chosen game.
- **In the emulator.** Generate and publish World 1 (Animals) with the script. Play a level, clear it, then check:
  - its stars on the map;
  - the row on the Path Words Levels board;
  - that the Zip map and board are unchanged.

## Rollout

1. Deploy the Worker, then the rules and indexes. Unknown games keep being refused until then.
2. Deploy admin-api.
3. Run the script for World 1 (Animals) and World 2 (Food).
4. Release the app. Older apps ignore Path Words worlds, because they only load `zip`.

## Left to the builder

- The exact ramp cut-offs and difficulty bands.
- The formula for the target time.
- The category tint colours.
- How the switcher stores the chosen game.
- The admin preview's styling.
- The other four launch categories, beyond Animals and Food.

## Claude's calls (check while reading)

- **A category share of at least 0.75 per board, with pool words filling the rest.** Strictly category-only boards rarely fit a dense grid.
- **Category names stay in English in Malayalam too.** The words are English.
- **Remembering the chosen game per device**, not per account.
- **Generation for Path Words runs on the server**, because the builder already lives in admin-api. Zip's still runs in the browser.
- **The script needs a service-account JSON again.**
