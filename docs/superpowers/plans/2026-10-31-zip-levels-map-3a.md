# Zip Levels — Levels Tab and Map Implementation Plan (plan 3a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Levels tab (second in the nav dock) shows Zip's levels on a winding map through themed worlds (Ink on rice paper, Metro at night; locked worlds unprinted). Tapping a level opens a sheet with its stars, best time and goals, and Play. Locked levels can't be played, even from a link. Results' "Next level" and "Map" return to the map.

**Architecture:** A pure `LevelMap` (domain) turns the catalog and the player's progress into nodes (done / current / locked) and worlds (open, stars). A `LevelMapCubit` loads it and rebuilds on every progress change. A pure `LevelMapLayout` places nodes on a winding path and splits the height into world bands. The screen stacks two `CustomPainter`s (backdrops, path) under positioned node widgets, inside a reversed scroll view so Level 1 sits at the bottom. No animations in this plan: motion is plan 3b.

**Tech Stack:** Flutter, flutter_bloc, go_router (StatefulShellRoute), CustomPainter, mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-10-31-zip-levels-design.md` (sections "Map screen", "Playing a level and Results", "Errors"). Plan 1 (merged): `docs/superpowers/plans/2026-10-31-zip-levels-app-foundation.md`.

**Product rules (binding):** no emoji in UI (drawn icons from `AppIcons` via `AppIcon`, painters); no animations in this plan, and later motion must come from the line and the world's material, never stock effects.

**Conventions for every task**
- Work in `~/Developments/personal/winklo/.worktrees/zip-levels-map` (branch `feat/zip-levels-map`, from `master` at `2ac1e96`). `flutter pub get` is done.
- `pubspec.lock` has an unrelated local change: never stage it. Stage files by path; format only files you touch; no `git checkout/switch/reset/stash`.
- Commit after each task; end every message with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `flutter analyze`: 0 errors, 0 warnings, no new infos (currently 20).
- Copy through `AppStrings` → `AppText` (`AppTextEn`, `AppTextMl`); every new member also goes in `test/core/strings/app_text_test.dart`'s `_members` table (that test requires Malayalam script in every Malayalam string).

---

## File structure

**Create**
| File | Responsibility |
|---|---|
| `lib/domain/logic/level_map.dart` | `LevelMap`, `LevelMapWorld`, `LevelMapNode`, `LevelNodeState` |
| `lib/features/levels/cubit/level_map_cubit.dart` | `LevelMapCubit`, `LevelMapState`, `LevelMapStatus` |
| `lib/features/levels/logic/level_map_layout.dart` | `LevelMapLayout`, `LevelMapBand` (positions, bands) |
| `lib/features/levels/view/levels_screen.dart` | the tab: header, game chips, map / loading / unavailable / empty |
| `lib/features/levels/view/widgets/world_backdrop_painter.dart` | Ink, Metro, unprinted and plain backdrops |
| `lib/features/levels/view/widgets/level_path_painter.dart` | the line so far, and the dotted road ahead |
| `lib/features/levels/view/widgets/level_node.dart` | one tappable level: circle, number or padlock, star marks |
| `lib/features/levels/view/widgets/level_avatar_pin.dart` | the player's avatar on the current level |
| `lib/features/levels/view/widgets/level_sheet.dart` | the bottom sheet for a level |
| tests next to each (paths in tasks) | |

**Modify:** `lib/core/theme/app_icons.dart`, `lib/core/strings/{app_text,app_text_en,app_text_ml,app_strings}.dart`, `test/core/strings/app_text_test.dart`, `lib/features/zip/bloc/zip_bloc.dart`, `lib/features/zip/view/zip_screen.dart`, `lib/core/widgets/play_mode_strip.dart`, `lib/core/router/play_mode_route.dart`, `lib/core/router/app_router.dart`, `lib/features/dashboard/view/widgets/floating_nav_dock.dart`, `lib/features/results/results_args.dart`, `lib/features/results/view/level_results_view.dart`, and their tests.

---

### Task 1: Levels icon and map copy

**Files:**
- Modify: `lib/core/theme/app_icons.dart` (Navigation section; `_duotoneFills`)
- Modify: `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart` (end of the `// Levels` block, after `levelGoalMissed`)
- Modify: `test/core/strings/app_text_test.dart` (`_members`)
- Test: `test/core/strings/level_map_strings_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';

void main() {
  test('map copy in English', () {
    expect(AppStrings.levelsSoon, 'Soon');
    expect(AppStrings.levelsNeedConnection, 'Levels need a connection the first time.');
    expect(AppStrings.levelsComingSoon, 'Levels are coming soon.');
    expect(AppStrings.levelWorldTitle(2, 'metro'), 'World 2 · Metro');
    expect(AppStrings.levelWorldLocked(20), 'Clear Level 20 to open');
    expect(AppStrings.levelLocked(5), 'Clear Level 5 first');
    expect(AppStrings.levelLockedMessage, 'This level is still locked.');
    expect(AppStrings.levelPlay, 'Play');
    expect(AppStrings.levelBestTime('0:17'), 'Best 0:17');
    expect(AppStrings.levelBackToMap, 'Map');
    expect(AppStrings.levelNodeDone(4, 2, 3), 'Level 4, 2 of 3 stars');
    expect(AppStrings.levelNodeCurrent(5), 'Level 5, next to play');
    expect(AppStrings.levelNodeLocked(6), 'Level 6, locked');
    expect(AppStrings.levelNumber(4), 'Level 4');
  });

  test('the Levels tab icon has a fill layer', () {
    expect(AppIcons.duotoneFill(AppIcons.levels), isNotNull);
    expect(AppIcons.levelsSelected.codePoint, 0xe31a);
  });
}
```

Run: `flutter test test/core/strings/level_map_strings_test.dart`
Expected: compile errors (members don't exist).

- [ ] **Step 2: Implement**

`app_icons.dart`, after `userSelected` in the Navigation section:

```dart
  /// Phosphor `map-trifold`, duotone: the Levels tab.
  static const levels = IconData(0xe31b, fontFamily: _duotone);

  /// Phosphor `map-trifold`, fill.
  static const levelsSelected = IconData(0xe31a, fontFamily: _fill);
```

and in `_duotoneFills`, next to the `// house` entry:

```dart
    0xe31b: IconData(0xe31a, fontFamily: _duotone), // map-trifold
```

`app_text.dart`, after `String levelGoalMissed(String goal);`:

```dart
  String get levelsSoon;
  String get levelsNeedConnection;
  String get levelsComingSoon;
  String levelWorldTitle(int order, String worldName);
  String levelWorldLocked(int lastLevel);
  String levelLocked(int number);
  String get levelLockedMessage;
  String get levelPlay;
  String levelBestTime(String time);
  String get levelBackToMap;
  String levelNodeDone(int number, int stars, int maxStars);
  String levelNodeCurrent(int number);
  String levelNodeLocked(int number);
  String levelNumber(int number);
```

`app_text_en.dart`, after the `levelGoalMissed` override (blank line before each `@override`, like the rest of the file):

```dart
  @override
  String get levelsSoon => 'Soon';

  @override
  String get levelsNeedConnection => 'Levels need a connection the first time.';

  @override
  String get levelsComingSoon => 'Levels are coming soon.';

  @override
  String levelWorldTitle(int order, String worldName) =>
      'World $order · $worldName';

  @override
  String levelWorldLocked(int lastLevel) => 'Clear Level $lastLevel to open';

  @override
  String levelLocked(int number) => 'Clear Level $number first';

  @override
  String get levelLockedMessage => 'This level is still locked.';

  @override
  String get levelPlay => 'Play';

  @override
  String levelBestTime(String time) => 'Best $time';

  @override
  String get levelBackToMap => 'Map';

  @override
  String levelNodeDone(int number, int stars, int maxStars) =>
      'Level $number, $stars of $maxStars stars';

  @override
  String levelNodeCurrent(int number) => 'Level $number, next to play';

  @override
  String levelNodeLocked(int number) => 'Level $number, locked';

  @override
  String levelNumber(int number) => 'Level $number';
```

`app_text_ml.dart`, after the `levelGoalMissed` override (native review pending, like the rest):

```dart
  @override
  String get levelsSoon => 'ഉടൻ';

  @override
  String get levelsNeedConnection =>
      'ആദ്യമായി ലെവലുകൾ തുറക്കാൻ ഇന്റർനെറ്റ് വേണം.';

  @override
  String get levelsComingSoon => 'ലെവലുകൾ ഉടൻ വരുന്നു.';

  @override
  String levelWorldTitle(int order, String worldName) =>
      'ലോകം $order · $worldName';

  @override
  String levelWorldLocked(int lastLevel) =>
      'തുറക്കാൻ ലെവൽ $lastLevel പൂർത്തിയാക്കുക';

  @override
  String levelLocked(int number) => 'ആദ്യം ലെവൽ $number പൂർത്തിയാക്കുക';

  @override
  String get levelLockedMessage => 'ഈ ലെവൽ ഇനിയും തുറന്നിട്ടില്ല.';

  @override
  String get levelPlay => 'കളിക്കുക';

  @override
  String levelBestTime(String time) => 'മികച്ചത് $time';

  @override
  String get levelBackToMap => 'മാപ്പ്';

  @override
  String levelNodeDone(int number, int stars, int maxStars) =>
      'ലെവൽ $number, $maxStars-ൽ $stars നക്ഷത്രം';

  @override
  String levelNodeCurrent(int number) => 'ലെവൽ $number, അടുത്തത്';

  @override
  String levelNodeLocked(int number) => 'ലെവൽ $number, പൂട്ടിയത്';

  @override
  String levelNumber(int number) => 'ലെവൽ $number';
```

`app_strings.dart`, after `levelGoalMissed`:

```dart
  static String get levelsSoon => _t.levelsSoon;
  static String get levelsNeedConnection => _t.levelsNeedConnection;
  static String get levelsComingSoon => _t.levelsComingSoon;

  /// "World 2 · Metro", from the world's [theme].
  static String levelWorldTitle(int order, String theme) =>
      _t.levelWorldTitle(order, _t.levelWorldName(theme));
  static String levelWorldLocked(int lastLevel) =>
      _t.levelWorldLocked(lastLevel);
  static String levelLocked(int number) => _t.levelLocked(number);
  static String get levelLockedMessage => _t.levelLockedMessage;
  static String get levelPlay => _t.levelPlay;
  static String levelBestTime(String time) => _t.levelBestTime(time);
  static String get levelBackToMap => _t.levelBackToMap;
  static String levelNodeDone(int number, int stars, int maxStars) =>
      _t.levelNodeDone(number, stars, maxStars);
  static String levelNodeCurrent(int number) => _t.levelNodeCurrent(number);
  static String levelNodeLocked(int number) => _t.levelNodeLocked(number);
  static String levelNumber(int number) => _t.levelNumber(number);
```

`test/core/strings/app_text_test.dart`, at the end of `_members` (after `levelGoalMissed`):

```dart
  'levelsSoon': (t) => t.levelsSoon,
  'levelsNeedConnection': (t) => t.levelsNeedConnection,
  'levelsComingSoon': (t) => t.levelsComingSoon,
  'levelWorldTitle': (t) => t.levelWorldTitle(2, 'Metro'),
  'levelWorldLocked': (t) => t.levelWorldLocked(20),
  'levelLocked': (t) => t.levelLocked(5),
  'levelLockedMessage': (t) => t.levelLockedMessage,
  'levelPlay': (t) => t.levelPlay,
  'levelBestTime': (t) => t.levelBestTime('0:17'),
  'levelBackToMap': (t) => t.levelBackToMap,
  'levelNodeDone': (t) => t.levelNodeDone(4, 2, 3),
  'levelNodeCurrent': (t) => t.levelNodeCurrent(5),
  'levelNodeLocked': (t) => t.levelNodeLocked(6),
  'levelNumber': (t) => t.levelNumber(4),
```

- [ ] **Step 3: Run the tests**

Run: `flutter test test/core/strings test/core/theme`
Expected: PASS (the new test and `app_text_test`).

- [ ] **Step 4: Commit**

```bash
git add lib/core/theme/app_icons.dart lib/core/strings test/core/strings
git commit -m "feat(levels): map copy and the Levels tab icon"
```

---

### Task 2: `LevelMap`

**Files:**
- Create: `lib/domain/logic/level_map.dart`
- Test: `test/domain/logic/level_map_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  final catalog = LevelCatalog([levelWorld(1, 3), levelWorld(2, 2, theme: 'metro')]);

  LevelMap map(Map<String, LevelRecord> records) =>
      LevelMap.build(catalog, LevelProgress(records));

  test('a new player: Level 1 is current, everything else locked', () {
    final m = map(const {});
    expect(m.currentId, 'zip_1_01');
    expect(m.node('zip_1_01')!.state, LevelNodeState.current);
    expect(m.node('zip_1_02')!.state, LevelNodeState.locked);
    expect(m.isPlayable('zip_1_01'), isTrue);
    expect(m.isPlayable('zip_1_02'), isFalse);
    expect(m.worlds[0].open, isTrue);
    expect(m.worlds[1].open, isFalse);
    expect(m.stars, 0);
    expect(m.maxStars, 15);
  });

  test('cleared levels are done; the first uncleared one is current', () {
    final m = map(const {
      'zip_1_01': LevelRecord(stars: 3, bestSeconds: 10),
      'zip_1_02': LevelRecord(stars: 2, bestSeconds: 40),
    });
    expect(m.node('zip_1_01')!.state, LevelNodeState.done);
    expect(m.node('zip_1_02')!.stars, 2);
    expect(m.currentId, 'zip_1_03');
    expect(m.worlds[0].stars, 5);
    expect(m.worlds[0].maxStars, 9);
    expect(m.worlds[0].lastNumber, 3);
  });

  test('clearing a world opens the next one', () {
    final m = map(const {
      'zip_1_01': LevelRecord(stars: 1, bestSeconds: 9),
      'zip_1_02': LevelRecord(stars: 1, bestSeconds: 9),
      'zip_1_03': LevelRecord(stars: 1, bestSeconds: 9),
    });
    expect(m.currentId, 'zip_2_01');
    expect(m.worlds[1].open, isTrue);
  });

  test('everything cleared: no current level', () {
    final all = {
      for (final id in ['zip_1_01', 'zip_1_02', 'zip_1_03', 'zip_2_01', 'zip_2_02'])
        id: const LevelRecord(stars: 3, bestSeconds: 5),
    };
    final m = map(all);
    expect(m.currentId, isNull);
    expect(m.allCleared, isTrue);
    expect(m.isPlayable('zip_2_02'), isTrue);
  });

  test('a level without a time goal is worth two stars', () {
    final m = LevelMap.build(
      LevelCatalog([levelWorld(1, 2, targetSeconds: null)]),
      LevelProgress.empty,
    );
    expect(m.maxStars, 4);
  });

  test('an unknown id is not playable; an empty catalog is empty', () {
    expect(map(const {}).isPlayable('zip_9_01'), isFalse);
    final empty = LevelMap.build(LevelCatalog(const []), LevelProgress.empty);
    expect(empty.isEmpty, isTrue);
    expect(empty.allCleared, isFalse);
  });
}
```

Run: `flutter test test/domain/logic/level_map_test.dart` → compile error.

- [ ] **Step 2: Implement**

`lib/domain/logic/level_map.dart`:

```dart
import '../entities/level_progress.dart';
import '../entities/level_world.dart';
import 'level_catalog.dart';

enum LevelNodeState { done, current, locked }

/// One level on the map.
class LevelMapNode {
  const LevelMapNode({required this.slot, required this.state, this.record});

  final LevelSlot slot;
  final LevelNodeState state;

  /// The level's best; null until it is cleared.
  final LevelRecord? record;

  bool get playable => state != LevelNodeState.locked;
  int get stars => record?.stars ?? 0;

  /// Stars the level can give: 3, or 2 without a time goal.
  int get maxStars => slot.entry.targetSeconds == null ? 2 : 3;
}

/// One world on the map and its levels.
class LevelMapWorld {
  const LevelMapWorld({required this.world, required this.nodes});

  final LevelWorld world;
  final List<LevelMapNode> nodes;

  /// Levels open one by one, so a world is open once its first level is.
  bool get open => nodes.isNotEmpty && nodes.first.playable;
  int get stars => nodes.fold(0, (sum, n) => sum + n.stars);
  int get maxStars => nodes.fold(0, (sum, n) => sum + n.maxStars);

  /// The number of the world's last level; null for an empty world.
  int? get lastNumber => nodes.isEmpty ? null : nodes.last.slot.number;
}

/// The player's map: every published level, done, current or locked.
///
/// Levels open one by one: the current level is the first one, in map
/// order, that isn't cleared; a cleared level stays playable for replays.
class LevelMap {
  LevelMap._(this.worlds, this.currentId, this._nodes);

  factory LevelMap.build(LevelCatalog catalog, LevelProgress progress) {
    final worlds = <LevelMapWorld>[];
    final byId = <String, LevelMapNode>{};
    String? currentId;
    for (final world in catalog.worlds) {
      final nodes = <LevelMapNode>[];
      for (final entry in world.levels) {
        final slot = catalog.slot(entry.id)!;
        final record = progress[entry.id];
        final LevelNodeState state;
        if (record != null) {
          state = LevelNodeState.done;
        } else if (currentId == null) {
          state = LevelNodeState.current;
          currentId = entry.id;
        } else {
          state = LevelNodeState.locked;
        }
        final node = LevelMapNode(slot: slot, state: state, record: record);
        nodes.add(node);
        byId[entry.id] = node;
      }
      worlds.add(LevelMapWorld(world: world, nodes: List.unmodifiable(nodes)));
    }
    return LevelMap._(List.unmodifiable(worlds), currentId, byId);
  }

  final List<LevelMapWorld> worlds;

  /// The next level to play; null when every level is cleared.
  final String? currentId;
  final Map<String, LevelMapNode> _nodes;

  LevelMapNode? node(String levelId) => _nodes[levelId];
  bool isPlayable(String levelId) => _nodes[levelId]?.playable ?? false;
  bool get isEmpty => _nodes.isEmpty;
  bool get allCleared => !isEmpty && currentId == null;
  int get stars => worlds.fold(0, (sum, w) => sum + w.stars);
  int get maxStars => worlds.fold(0, (sum, w) => sum + w.maxStars);
}
```

- [ ] **Step 3: Run the test**

Run: `flutter test test/domain/logic/level_map_test.dart` → PASS (6 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/domain/logic/level_map.dart test/domain/logic/level_map_test.dart
git commit -m "feat(levels): work out the map from catalog and progress"
```

---

### Task 3: Locked levels can't be played

**Files:**
- Modify: `lib/features/zip/bloc/zip_bloc.dart` (constructor, fields, the level branch of `_startOffDaily` and its catch)
- Modify: `lib/features/zip/view/zip_screen.dart` (ZipBloc construction)
- Modify: `test/features/zip/bloc/zip_bloc_level_test.dart`, `test/features/zip/view/zip_screen_level_test.dart`

- [ ] **Step 1: Write the failing test**

In `zip_bloc_level_test.dart`, give the file's `build(...)` helper an extra named parameter `bool gated = false` and pass `levelProgress: gated ? progress : null` to `ZipBloc(`. Then add:

```dart
  test('a locked level fails with the locked message and keeps its draft', () async {
    drafts.runs['zip_level_zip_1_02'] = InProgressRun(
      gameId: 'zip',
      playId: 'level_zip_1_02',
      elapsedMs: 1000,
      board: const {'path': []},
    );
    final bloc = build('zip_1_02', gated: true);
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.failed);
    expect(state.errorMessage, 'This level is still locked.');
    expect(drafts.runs['zip_level_zip_1_02'], isNotNull);
    await bloc.close();
  });

  test('the current level and cleared levels play when gated', () async {
    final first = build('zip_1_01', gated: true);
    first.add(const ZipEvent.started());
    expect((await ready(first)).status, ZipStatus.ready);
    await first.close();

    await progress.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    for (final id in ['zip_1_01', 'zip_1_02']) {
      final bloc = build(id, gated: true);
      bloc.add(const ZipEvent.started());
      expect((await ready(bloc)).status, ZipStatus.ready, reason: id);
      await bloc.close();
    }
  });
```

Run: `flutter test test/features/zip/bloc/zip_bloc_level_test.dart` → compile error (`levelProgress`).

- [ ] **Step 2: Implement**

In `zip_bloc.dart`:
- import `'../../../domain/logic/level_map.dart'` and `'../../../domain/repositories/level_progress_repository.dart'`;
- constructor parameter `this.levelProgress,` after `this.recordLevelClear,`;
- field after `recordLevelClear`:

```dart
  /// The player's level progress, so a locked level can't be played (a
  /// link can name any published level). Null skips the check.
  final LevelProgressRepository? levelProgress;
```

- in `_startOffDaily`, declare `var lockedLevel = false;` just before the board-loading `try`, and in the level branch, right after the `if (slot == null) { … }` block:

```dart
        final progress = levelProgress;
        if (progress != null &&
            !LevelMap.build(
              catalog,
              progress.progress(GameIds.zip),
            ).isPlayable(slot.entry.id)) {
          lockedLevel = true;
          throw StateError('Level ${mode.levelId} is locked');
        }
```

- in the `catch (_)` of that `try`, change the message to:

```dart
          errorMessage: lockedLevel
              ? AppStrings.levelLockedMessage
              : mode.isLevel
              ? AppStrings.levelFailed
              : AppStrings.zipFailed,
```

In `zip_screen.dart`, add to the `ZipBloc(` call after `recordLevelClear: …`:

```dart
      levelProgress: widget.mode.isLevel
          ? context.read<LevelProgressRepository>()
          : null,
```

(import `../../../domain/repositories/level_progress_repository.dart`). `test/features/zip/view/zip_screen_level_test.dart` pumps ZipScreen under its own providers: add a `RepositoryProvider<LevelProgressRepository>` there (a `LevelProgressRepositoryImpl` on mock SharedPreferences with `currentUid: () => 'u1'` is enough).

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/zip` → PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/zip test/features/zip
git commit -m "feat(levels): a locked level can't be played"
```

---

### Task 4: `LevelMapCubit`

**Files:**
- Create: `lib/features/levels/cubit/level_map_cubit.dart`
- Test: `test/features/levels/cubit/level_map_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/features/levels/cubit/level_map_cubit.dart';

import '../../../helpers/level_fixtures.dart';

class _Worlds implements LevelWorldRepository {
  LevelCatalog? value;
  int calls = 0;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async {
    calls++;
    final v = value;
    if (v == null) throw const LevelsUnavailable('offline');
    return v;
  }
}

void main() {
  late _Worlds worlds;
  late LevelProgressRepositoryImpl progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    worlds = _Worlds();
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
  });

  LevelMapCubit build() => LevelMapCubit(worlds: worlds, progress: progress);

  test('loads the map', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.ready);
    expect(cubit.state.map!.currentId, 'zip_1_01');
    await cubit.close();
  });

  test('offline with nothing cached is unavailable; retry recovers', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.unavailable);
    worlds.value = LevelCatalog([levelWorld(1, 1)]);
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.ready);
    await cubit.close();
  });

  test('no published worlds is empty', () async {
    worlds.value = LevelCatalog(const []);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.empty);
    await cubit.close();
  });

  test('a new clear rebuilds the map without reloading worlds', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pumpEventQueue();
    expect(cubit.state.map!.currentId, 'zip_1_02');
    expect(cubit.state.map!.stars, 3);
    expect(worlds.calls, 1);
    await cubit.close();
  });
}
```

Run: `flutter test test/features/levels/cubit/level_map_cubit_test.dart` → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/cubit/level_map_cubit.dart`:

```dart
import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/game_ids.dart';
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';

enum LevelMapStatus { loading, ready, empty, unavailable }

class LevelMapState {
  const LevelMapState({this.status = LevelMapStatus.loading, this.map});

  final LevelMapStatus status;

  /// Set when [status] is ready.
  final LevelMap? map;
}

/// The Levels tab's map: loads the published worlds once and rebuilds the
/// map whenever the player's level progress changes (a clear, a sync).
class LevelMapCubit extends Cubit<LevelMapState> {
  LevelMapCubit({
    required LevelWorldRepository worlds,
    required LevelProgressRepository progress,
    this.game = GameIds.zip,
  }) : _worlds = worlds,
       _progress = progress,
       super(const LevelMapState()) {
    _changes = _progress.changes.listen((_) => _rebuild());
  }

  final LevelWorldRepository _worlds;
  final LevelProgressRepository _progress;
  final String game;
  StreamSubscription<void>? _changes;
  LevelCatalog? _catalog;

  /// Loads the worlds (also the Retry action).
  Future<void> load() async {
    if (_catalog == null && state.status != LevelMapStatus.loading) {
      emit(const LevelMapState());
    }
    try {
      final catalog = await _worlds.catalog(game);
      if (isClosed) return;
      _catalog = catalog;
      _rebuild();
    } on LevelsUnavailable {
      if (isClosed || _catalog != null) return;
      emit(const LevelMapState(status: LevelMapStatus.unavailable));
    }
  }

  void _rebuild() {
    final catalog = _catalog;
    if (catalog == null || isClosed) return;
    if (catalog.isEmpty) {
      emit(const LevelMapState(status: LevelMapStatus.empty));
      return;
    }
    emit(
      LevelMapState(
        status: LevelMapStatus.ready,
        map: LevelMap.build(catalog, _progress.progress(game)),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 3: Run the test** → PASS (4 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/cubit test/features/levels/cubit
git commit -m "feat(levels): LevelMapCubit"
```

---

### Task 5: `LevelMapLayout`

**Files:**
- Create: `lib/features/levels/logic/level_map_layout.dart`
- Test: `test/features/levels/logic/level_map_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/logic/level_map_layout.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 3), levelWorld(2, 2, theme: 'metro')]),
    LevelProgress.empty,
  );
  const width = 390.0;
  final layout = LevelMapLayout.of(map, width);
  double y(String id) => layout.centers[id]!.dy;

  test('height fits every level and the gap between worlds', () {
    expect(
      layout.size.height,
      LevelMapLayout.topPad +
          LevelMapLayout.bottomPad +
          4 * LevelMapLayout.step +
          (LevelMapLayout.gateGap - LevelMapLayout.step),
    );
    expect(layout.size.width, width);
  });

  test('Level 1 is at the bottom and the path climbs', () {
    expect(y('zip_1_01'), layout.size.height - LevelMapLayout.bottomPad);
    final ids = ['zip_1_01', 'zip_1_02', 'zip_1_03', 'zip_2_01', 'zip_2_02'];
    for (var i = 1; i < ids.length; i++) {
      expect(y(ids[i]), lessThan(y(ids[i - 1])));
    }
    expect(y('zip_1_03') - y('zip_2_01'), LevelMapLayout.gateGap);
  });

  test('levels wind around the middle', () {
    final amp = width * LevelMapLayout.amplitudeFraction;
    for (final c in layout.centers.values) {
      expect(c.dx, inInclusiveRange(width / 2 - amp - 0.01, width / 2 + amp + 0.01));
    }
    expect(layout.centers['zip_1_01']!.dx, closeTo(width / 2, 0.01));
    expect(layout.centers['zip_1_02']!.dx, closeTo(width / 2 + amp, 0.01));
  });

  test('world bands cover the map, top to bottom, with the gate between', () {
    expect(layout.bands.length, 2);
    expect(layout.bands[0].rect.bottom, layout.size.height);
    expect(layout.bands[1].rect.top, 0);
    expect(layout.bands[0].rect.top, layout.bands[1].rect.bottom);
    expect(layout.bands[1].gateY, (y('zip_1_03') + y('zip_2_01')) / 2);
    expect(layout.nodes.map((n) => n.slot.entry.id).first, 'zip_1_01');
  });

  test('an empty world takes no space', () {
    final withEmpty = LevelMap.build(
      LevelCatalog([levelWorld(1, 1), levelWorld(2, 0), levelWorld(3, 1)]),
      LevelProgress.empty,
    );
    expect(LevelMapLayout.of(withEmpty, width).bands.length, 2);
  });
}
```

Run: `flutter test test/features/levels/logic/level_map_layout_test.dart` → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/logic/level_map_layout.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/logic/level_map.dart';

/// One world's stretch of the map.
class LevelMapBand {
  const LevelMapBand({required this.world, required this.rect});

  final LevelMapWorld world;
  final Rect rect;

  /// Where this world meets the one below it (the gate).
  double get gateY => rect.bottom;
}

/// Where each level sits on the map: Level 1 at the bottom, the path
/// climbing and winding left and right, a wider gap where worlds meet.
class LevelMapLayout {
  LevelMapLayout._({
    required this.size,
    required this.nodes,
    required this.centers,
    required this.bands,
  });

  static const step = 76.0;
  static const gateGap = 92.0;
  static const topPad = 96.0;
  static const bottomPad = 120.0;
  static const amplitudeFraction = 0.24;

  factory LevelMapLayout.of(LevelMap map, double width) {
    final worlds = [
      for (final w in map.worlds)
        if (w.nodes.isNotEmpty) w,
    ];
    final count = worlds.fold<int>(0, (sum, w) => sum + w.nodes.length);
    final height =
        topPad +
        bottomPad +
        math.max(0, count - 1) * step +
        math.max(0, worlds.length - 1) * (gateGap - step);
    final cx = width / 2;
    final amp = width * amplitudeFraction;
    final nodes = <LevelMapNode>[];
    final centers = <String, Offset>{};
    final spans = <(double, double)>[];
    var y = height - bottomPad;
    var index = 0;
    for (var w = 0; w < worlds.length; w++) {
      if (w > 0) y -= gateGap - step;
      final firstY = y;
      for (final node in worlds[w].nodes) {
        nodes.add(node);
        centers[node.slot.entry.id] = Offset(
          cx + amp * math.sin(index * math.pi / 2),
          y,
        );
        index++;
        y -= step;
      }
      spans.add((firstY, y + step));
    }
    final bands = <LevelMapBand>[
      for (var w = 0; w < worlds.length; w++)
        LevelMapBand(
          world: worlds[w],
          rect: Rect.fromLTRB(
            0,
            w == worlds.length - 1 ? 0 : (spans[w].$2 + spans[w + 1].$1) / 2,
            width,
            w == 0 ? height : (spans[w].$1 + spans[w - 1].$2) / 2,
          ),
        ),
    ];
    return LevelMapLayout._(
      size: Size(width, height),
      nodes: List.unmodifiable(nodes),
      centers: Map.unmodifiable(centers),
      bands: List.unmodifiable(bands),
    );
  }

  final Size size;

  /// Every level, Level 1 first.
  final List<LevelMapNode> nodes;

  /// Each level's centre, by id.
  final Map<String, Offset> centers;

  /// The worlds that have levels, bottom world first.
  final List<LevelMapBand> bands;
}
```

- [ ] **Step 3: Run the test** → PASS (5 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/logic test/features/levels/logic
git commit -m "feat(levels): lay the map out"
```

---

### Task 6: Backdrop and path painters

**Files:**
- Create: `lib/features/levels/view/widgets/world_backdrop_painter.dart`
- Create: `lib/features/levels/view/widgets/level_path_painter.dart`
- Test: `test/features/levels/view/map_painters_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/logic/level_map_layout.dart';
import 'package:winklo/features/levels/view/widgets/level_path_painter.dart';
import 'package:winklo/features/levels/view/widgets/world_backdrop_painter.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  LevelMapLayout layoutWith(Map<String, LevelRecord> records) => LevelMapLayout.of(
    LevelMap.build(
      LevelCatalog([
        levelWorld(1, 3),
        levelWorld(2, 2, theme: 'metro'),
        levelWorld(3, 1, theme: 'mystery'),
      ]),
      LevelProgress(records),
    ),
    390,
  );

  testWidgets('both painters draw every kind of world without errors', (tester) async {
    final layout = layoutWith(const {
      'zip_1_01': LevelRecord(stars: 3, bestSeconds: 9),
      'zip_1_02': LevelRecord(stars: 3, bestSeconds: 9),
      'zip_1_03': LevelRecord(stars: 3, bestSeconds: 9),
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: WorldBackdropPainter(layout.bands))),
                Positioned.fill(child: CustomPaint(painter: LevelPathPainter(layout))),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('painters repaint only for a new layout', () {
    final a = layoutWith(const {});
    final b = layoutWith(const {});
    expect(WorldBackdropPainter(a.bands).shouldRepaint(WorldBackdropPainter(a.bands)), isFalse);
    expect(WorldBackdropPainter(a.bands).shouldRepaint(WorldBackdropPainter(b.bands)), isTrue);
    expect(LevelPathPainter(a).shouldRepaint(LevelPathPainter(a)), isFalse);
    expect(LevelPathPainter(a).shouldRepaint(LevelPathPainter(b)), isTrue);
  });
}
```

Run → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/view/widgets/world_backdrop_painter.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../logic/level_map_layout.dart';

/// Each world's backdrop: rice paper with a vermilion grid (Ink), a night
/// transit map (Metro), or, for a world not yet open, its outlines only
/// ("unprinted"). An unknown theme gets the plain app background.
class WorldBackdropPainter extends CustomPainter {
  WorldBackdropPainter(this.bands);

  final List<LevelMapBand> bands;

  static const paper = Color(0xFFEFE8D8);
  static const vermilion = Color(0xFFC2410C);
  static const metroNight = Color(0xFF13233A);

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      final rect = band.rect;
      if (!band.world.open) {
        _unprinted(canvas, rect);
        continue;
      }
      switch (band.world.world.theme) {
        case 'ink':
          _ink(canvas, rect);
        case 'metro':
          _metro(canvas, rect);
        default:
          canvas.drawRect(rect, Paint()..color = ZipColors.ink);
      }
    }
  }

  void _ink(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = paper);
    final grid = Paint()
      ..color = vermilion.withValues(alpha: 0.28)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 4; i++) {
      final x = r.left + r.width * i / 4;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
    }
    for (var y = r.bottom - 70; y > r.top; y -= 70) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
    }
  }

  void _metro(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = metroNight);
    for (final (path, color) in _metroLines(r)) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.35),
      );
    }
  }

  void _unprinted(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = ZipColors.ink);
    final dash = Paint()
      ..color = ZipColors.outlineQuiet
      ..strokeWidth = 1;
    for (final (path, _) in _metroLines(r)) {
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 7) {
          canvas.drawPath(metric.extractPath(d, math.min(d + 3, metric.length)), dash..style = PaintingStyle.stroke);
        }
      }
    }
  }

  /// Three transit lines across [r]: the Metro look, and the outline of
  /// any world before it's printed.
  static List<(Path, Color)> _metroLines(Rect r) {
    final w = r.width;
    final h = r.height;
    return [
      (
        Path()
          ..moveTo(r.left + w * 0.12, r.bottom)
          ..lineTo(r.left + w * 0.12, r.top),
        const Color(0xFFF472B6),
      ),
      (
        Path()
          ..moveTo(r.left, r.top + h * 0.4)
          ..lineTo(r.left + w * 0.3, r.top + h * 0.4)
          ..lineTo(r.left + w * 0.38, r.top + h * 0.4 - w * 0.08)
          ..lineTo(r.right, r.top + h * 0.4 - w * 0.08),
        const Color(0xFFA3E635),
      ),
      (
        Path()
          ..moveTo(r.left + w * 0.86, r.top)
          ..lineTo(r.left + w * 0.86, r.top + h * 0.3)
          ..lineTo(r.left + w * 0.94, r.top + h * 0.3 + w * 0.08)
          ..lineTo(r.left + w * 0.94, r.bottom),
        const Color(0xFFFBBF24),
      ),
    ];
  }

  @override
  bool shouldRepaint(WorldBackdropPainter oldDelegate) =>
      !identical(oldDelegate.bands, bands);
}
```

`lib/features/levels/view/widgets/level_path_painter.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/logic/level_map.dart';
import '../../logic/level_map_layout.dart';

/// The line through the levels: drawn in the world's material up to the
/// current level (sumi ink on paper, a sky route on Metro), and a dotted
/// pencil road beyond it.
class LevelPathPainter extends CustomPainter {
  LevelPathPainter(this.layout);

  final LevelMapLayout layout;

  static const ink = Color(0xFF2B2724);
  static const pencil = Color(0xFFA8A29E);

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = layout.nodes;
    for (var i = 0; i + 1 < nodes.length; i++) {
      final a = layout.centers[nodes[i].slot.entry.id]!;
      final b = layout.centers[nodes[i + 1].slot.entry.id]!;
      final midY = (a.dy + b.dy) / 2;
      final segment = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final next = nodes[i + 1];
      final theme = next.slot.world.theme;
      if (next.state != LevelNodeState.locked) {
        canvas.drawPath(
          segment,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = theme == 'ink' ? 8 : 7
            ..color = switch (theme) {
              'ink' => ink,
              'metro' => ZipColors.sky,
              _ => ZipColors.onInk.withValues(alpha: 0.6),
            },
        );
      } else {
        final dot = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6
          ..color = theme == 'ink' ? pencil : ZipColors.outline;
        for (final metric in segment.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 7) {
            canvas.drawPath(metric.extractPath(d, math.min(d + 2.2, metric.length)), dot);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(LevelPathPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
```

If `ZipColors.outlineQuiet` or `ZipColors.outline` don't exist in `lib/core/theme/app_theme.dart`, use the closest existing outline colours and say so in the report.

- [ ] **Step 3: Run the test** → PASS (2 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/view/widgets/world_backdrop_painter.dart lib/features/levels/view/widgets/level_path_painter.dart test/features/levels/view/map_painters_test.dart
git commit -m "feat(levels): paint world backdrops and the line"
```

---

### Task 7: Level node and avatar pin

**Files:**
- Create: `lib/features/levels/view/widgets/level_node.dart`
- Create: `lib/features/levels/view/widgets/level_avatar_pin.dart`
- Test: `test/features/levels/view/level_node_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/view/widgets/level_avatar_pin.dart';
import 'package:winklo/features/levels/view/widgets/level_node.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 3), levelWorld(2, 1, theme: 'metro')]),
    const LevelProgress({'zip_1_01': LevelRecord(stars: 2, bestSeconds: 20)}),
  );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  testWidgets('a done level reads its stars and taps', (tester) async {
    var taps = 0;
    await pump(tester, LevelNode(node: map.node('zip_1_01')!, onTap: () => taps++));
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 1, 2 of 3 stars'), findsOneWidget);
    await tester.tap(find.byType(LevelNode));
    expect(taps, 1);
  });

  testWidgets('the current and a locked level', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          LevelNode(node: map.node('zip_1_02')!, onTap: () {}),
          LevelNode(node: map.node('zip_2_01')!, onTap: () {}),
        ],
      ),
    );
    expect(find.bySemanticsLabel('Level 2, next to play'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 4, locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the avatar pin draws with or without a player', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          LevelAvatarPin(user: AppUser(uid: 'u1', displayName: 'Asha')),
          LevelAvatarPin(user: null),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

Run → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/view/widgets/level_node.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/logic/level_map.dart';

/// One level on the map, drawn in its world's material: a brushed ensō on
/// Ink, a station on Metro. Cleared levels show their stars as marks
/// (vermilion seals on Ink, dots elsewhere); locked ones a padlock.
class LevelNode extends StatelessWidget {
  const LevelNode({super.key, required this.node, required this.onTap});

  final LevelMapNode node;
  final VoidCallback onTap;

  static const diameter = 40.0;
  static const width = 64.0;

  String get _label {
    final number = node.slot.number;
    return switch (node.state) {
      LevelNodeState.done => AppStrings.levelNodeDone(number, node.stars, node.maxStars),
      LevelNodeState.current => AppStrings.levelNodeCurrent(number),
      LevelNodeState.locked => AppStrings.levelNodeLocked(number),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = node.slot.world.theme;
    final locked = node.state == LevelNodeState.locked;
    final numberColor = switch ((theme, node.state)) {
      ('ink', LevelNodeState.locked) => const Color(0xFFA8A29E),
      ('ink', _) => const Color(0xFF111111),
      (_, LevelNodeState.locked) => ZipColors.inkSoft,
      _ => ZipColors.ink,
    };
    return Semantics(
      button: true,
      label: _label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: diameter,
                child: CustomPaint(
                  painter: _NodePainter(theme: theme, state: node.state),
                  child: Center(
                    child: locked
                        ? AppIcon(AppIcons.lock, size: 15, color: numberColor)
                        : Text(
                            '${node.slot.number}',
                            style: TextStyle(
                              color: numberColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (node.state == LevelNodeState.done)
                CustomPaint(
                  size: Size(node.maxStars * 10.0, 8),
                  painter: _StarMarksPainter(
                    theme: theme,
                    earned: node.stars,
                    total: node.maxStars,
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  _NodePainter({required this.theme, required this.state});

  final String theme;
  final LevelNodeState state;

  static const paper = Color(0xFFEFE8D8);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    if (theme == 'ink') {
      canvas.drawCircle(c, r, Paint()..color = paper);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      switch (state) {
        case LevelNodeState.done:
          // A brushed ensō: almost closed, the gap where the brush lifted.
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -math.pi / 2 - 0.6,
            math.pi * 2 * 0.9,
            false,
            stroke
              ..strokeWidth = 3.4
              ..color = const Color(0xFF2B2724),
          );
        case LevelNodeState.current:
          canvas.drawCircle(c, r, stroke..strokeWidth = 3.4..color = const Color(0xFF111111));
        case LevelNodeState.locked:
          canvas.drawCircle(c, r, stroke..strokeWidth = 1.2..color = const Color(0xFFA8A29E));
      }
      return;
    }
    final fill = switch (state) {
      LevelNodeState.done => ZipColors.sky,
      LevelNodeState.current => ZipColors.onInk,
      LevelNodeState.locked => ZipColors.paper,
    };
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = state == LevelNodeState.current ? 3 : 1.5
        ..color = state == LevelNodeState.locked ? ZipColors.outline : ZipColors.sky,
    );
  }

  @override
  bool shouldRepaint(_NodePainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.state != state;
}

/// A level's stars in its world's material: vermilion seals on Ink, dots
/// elsewhere; filled when earned, outlined when not.
class _StarMarksPainter extends CustomPainter {
  _StarMarksPainter({required this.theme, required this.earned, required this.total});

  final String theme;
  final int earned;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < total; i++) {
      final cx = 5.0 + i * 10;
      final on = i < earned;
      final paint = Paint()
        ..style = on ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1;
      if (theme == 'ink') {
        paint.color = const Color(0xFFB91C1C);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, 4), width: 7, height: 7),
            const Radius.circular(1.2),
          ),
          paint,
        );
      } else {
        paint.color = ZipColors.sky;
        canvas.drawCircle(Offset(cx, 4), 2.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarMarksPainter oldDelegate) =>
      oldDelegate.earned != earned || oldDelegate.total != total || oldDelegate.theme != theme;
}
```

`lib/features/levels/view/widgets/level_avatar_pin.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/app_user.dart';

/// The player's avatar on a pin, standing on the current level.
class LevelAvatarPin extends StatelessWidget {
  const LevelAvatarPin({super.key, required this.user});

  final AppUser? user;

  static const width = 40.0;
  static const height = 46.0;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _PinPainter(),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: UserAvatar(
                displayName: user?.displayName ?? '',
                photoUrl: user?.photoUrl,
                avatarId: user?.avatarId,
                radius: 15,
                tintSeed: user?.uid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ZipColors.onInk;
    canvas.drawCircle(Offset(size.width / 2, 18), 18, paint);
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 6, 33)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width / 2 + 6, 33)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}
```

If `AppUser`'s constructor needs more required fields than `uid` and `displayName`, adapt the test's `AppUser(...)` call.

- [ ] **Step 3: Run the test** → PASS (3 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/view/widgets/level_node.dart lib/features/levels/view/widgets/level_avatar_pin.dart test/features/levels/view/level_node_test.dart
git commit -m "feat(levels): level nodes and the avatar pin"
```

---

### Task 8: The level sheet

**Files:**
- Create: `lib/features/levels/view/widgets/level_sheet.dart`
- Test: `test/features/levels/view/level_sheet_test.dart`

The best run's individual goals aren't stored (progress keeps the best stars and best time), so the sheet shows the stars as marks, the best time, and the goals as a plain list.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/view/widgets/level_sheet.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 2)]),
    const LevelProgress({'zip_1_01': LevelRecord(stars: 2, bestSeconds: 17)}),
  );

  Future<List<String>> openSheet(WidgetTester tester, String id) async {
    final visited = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLevelSheet(context, map.node(id)!),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/zip',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('a cleared level: world, number, best time, goals, Replay', (tester) async {
    final visited = await openSheet(tester, 'zip_1_01');
    expect(find.text('World 1 · Ink'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('3 × 3 · Best 0:17'), findsOneWidget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();
    expect(visited, ['/zip?mode=level&level=zip_1_01']);
  });

  testWidgets('the current level says Play', (tester) async {
    await openSheet(tester, 'zip_1_02');
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('3 × 3'), findsOneWidget);
  });
}
```

Run → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/view/widgets/level_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/zip_ui.dart';
import '../../../../domain/logic/level_map.dart';
import '../../../../domain/play_mode.dart';

/// Opens the sheet for a playable [node]: its world, number, best, goals,
/// and Play (or Replay).
Future<void> showLevelSheet(BuildContext context, LevelMapNode node) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: ZipColors.paper,
    builder: (_) => LevelSheet(node: node),
  );
}

class LevelSheet extends StatelessWidget {
  const LevelSheet({super.key, required this.node});

  final LevelMapNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = node.slot;
    final size = slot.entry.zipLevelSize;
    final best = node.record?.bestSeconds;
    final meta = best == null
        ? '$size × $size'
        : '$size × $size · ${AppStrings.levelBestTime(AppStrings.formatPlayTime(best))}';
    final target = slot.entry.targetSeconds;
    final cleared = node.state == LevelNodeState.done;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.levelWorldTitle(slot.world.order, slot.world.theme),
              style: theme.textTheme.labelLarge?.copyWith(color: ZipColors.inkSoft),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.levelNumber(slot.number),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(meta, style: theme.textTheme.labelLarge?.copyWith(color: ZipColors.inkSoft)),
              ],
            ),
            if (cleared) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < node.maxStars; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AppIcon(
                        i < node.stars ? AppIcons.star : AppIcons.starOutline,
                        size: 20,
                        color: i < node.stars ? ZipColors.star : ZipColors.outline,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            for (final goal in [
              AppStrings.levelGoalClear,
              AppStrings.levelGoalNoHints,
              if (target != null) AppStrings.levelGoalUnder(AppStrings.formatPlayTime(target)),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.starOutline, size: 18, color: ZipColors.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(child: Text(goal, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ZipPrimaryButton(
              label: cleared ? AppStrings.levelReplay : AppStrings.levelPlay,
              icon: AppIcons.play,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(PlayMode.level(slot.entry.id).location('/zip'));
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

This needs one small addition, made in this task: in `LevelEntry` (`lib/domain/entities/level_world.dart`) add

```dart
  /// The board's size from its JSON, without parsing the whole board.
  int get zipLevelSize => (board['size'] as num?)?.toInt() ?? 0;
```

(`AppStrings.levelNumber` comes from Task 1.)

`context.push` after `pop` uses the sheet's context; if the analyzer flags `use_build_context_synchronously` or the push fails because the sheet's context is gone, capture `final router = GoRouter.of(context);` before `pop()` and call `router.push(...)`.

- [ ] **Step 3: Run the test** → PASS (2 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/view/widgets/level_sheet.dart lib/domain/entities/level_world.dart test/features/levels/view/level_sheet_test.dart
git commit -m "feat(levels): the level sheet"
```

---

### Task 9: The Levels screen

**Files:**
- Create: `lib/features/levels/view/levels_screen.dart`
- Test: `test/features/levels/view/levels_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';

import '../../../helpers/level_fixtures.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _Worlds implements LevelWorldRepository {
  _Worlds(this.value);
  final LevelCatalog? value;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async {
    final v = value;
    if (v == null) throw const LevelsUnavailable('offline');
    return v;
  }
}

void main() {
  late LevelProgressRepositoryImpl progress;
  late _MockAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester, LevelCatalog? catalog, {String? open}) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => LevelsScreen(openLevelId: open)),
        GoRoute(path: '/zip', builder: (_, _) => const Text('zip screen')),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelWorldRepository>.value(value: _Worlds(catalog)),
          RepositoryProvider<LevelProgressRepository>.value(value: progress),
          RepositoryProvider<AuthRepository>.value(value: auth),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the map with the current level and stars total', (tester) async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(tester, LevelCatalog([levelWorld(1, 3), levelWorld(2, 2, theme: 'metro')]));
    expect(find.text('Levels'), findsWidgets);
    expect(find.text('3 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 2, next to play'), findsOneWidget);
    expect(find.text('World 2 · Metro'), findsOneWidget);
    expect(find.text('Clear Level 3 to open'), findsOneWidget);
  });

  testWidgets('tapping a locked level says what to clear first', (tester) async {
    await pump(tester, LevelCatalog([levelWorld(1, 3)]));
    await tester.tap(find.bySemanticsLabel('Level 3, locked'));
    await tester.pump();
    expect(find.text('Clear Level 1 first'), findsOneWidget);
  });

  testWidgets('tapping the current level opens its sheet', (tester) async {
    await pump(tester, LevelCatalog([levelWorld(1, 2)]));
    await tester.tap(find.bySemanticsLabel('Level 1, next to play'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets("open= opens that level's sheet once the map loads", (tester) async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(tester, LevelCatalog([levelWorld(1, 2)]), open: 'zip_1_02');
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('offline first time: message and Retry', (tester) async {
    await pump(tester, null);
    expect(find.text('Levels need a connection the first time.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('no worlds yet', (tester) async {
    await pump(tester, LevelCatalog(const []));
    expect(find.text('Levels are coming soon.'), findsOneWidget);
  });
}
```

Run → compile error.

- [ ] **Step 2: Implement**

`lib/features/levels/view/levels_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../cubit/level_map_cubit.dart';
import '../logic/level_map_layout.dart';
import 'widgets/level_avatar_pin.dart';
import 'widgets/level_node.dart';
import 'widgets/level_path_painter.dart';
import 'widgets/level_sheet.dart';
import 'widgets/world_backdrop_painter.dart';

/// The Levels tab: Zip's levels on a winding map. [openLevelId] (from
/// `/levels?open=…`, e.g. Results' Next level) opens that level's sheet
/// once the map is loaded.
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key, this.openLevelId});

  final String? openLevelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LevelMapCubit(
        worlds: context.read<LevelWorldRepository>(),
        progress: context.read<LevelProgressRepository>(),
      )..load(),
      child: _LevelsView(openLevelId: openLevelId),
    );
  }
}

class _LevelsView extends StatefulWidget {
  const _LevelsView({this.openLevelId});

  final String? openLevelId;

  @override
  State<_LevelsView> createState() => _LevelsViewState();
}

class _LevelsViewState extends State<_LevelsView> {
  final _scroll = ScrollController();
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Once, after the map first lays out: scroll to the level to show
  /// ([openLevelId] or the current one) and open its sheet if asked.
  void _place(LevelMap map, LevelMapLayout layout, double viewport) {
    if (_placed) return;
    _placed = true;
    final focusId = widget.openLevelId ?? map.currentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = focusId == null ? null : layout.centers[focusId];
      if (center != null && _scroll.hasClients) {
        final offset = layout.size.height - center.dy - viewport / 2;
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
      final open = widget.openLevelId == null ? null : map.node(widget.openLevelId!);
      if (open != null && open.playable) showLevelSheet(context, open);
    });
  }

  void _onTap(LevelMap map, LevelMapNode node) {
    if (node.playable) {
      showLevelSheet(context, node);
      return;
    }
    final current = map.currentId == null ? null : map.node(map.currentId!);
    if (current == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppStrings.levelLocked(current.slot.number))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: BlocBuilder<LevelMapCubit, LevelMapState>(
            builder: (context, state) {
              final map = state.map;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(stars: map?.stars, maxStars: map?.maxStars),
                  Expanded(
                    child: switch (state.status) {
                      LevelMapStatus.loading => const Center(child: CircularProgressIndicator()),
                      LevelMapStatus.unavailable => _Message(
                        text: AppStrings.levelsNeedConnection,
                        onRetry: () => context.read<LevelMapCubit>().load(),
                      ),
                      LevelMapStatus.empty => _Message(text: AppStrings.levelsComingSoon),
                      LevelMapStatus.ready => _map(context, map!),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _map(BuildContext context, LevelMap map) {
    final user = context.read<AuthRepository>().currentUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = LevelMapLayout.of(map, constraints.maxWidth);
        _place(map, layout, constraints.maxHeight);
        final current = map.currentId == null ? null : layout.centers[map.currentId];
        return SingleChildScrollView(
          controller: _scroll,
          reverse: true,
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                // Its own layer, so scrolling doesn't repaint the whole map.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            isComplex: true,
                            painter: WorldBackdropPainter(layout.bands),
                          ),
                        ),
                        Positioned.fill(child: CustomPaint(painter: LevelPathPainter(layout))),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < layout.bands.length; i++)
                  Positioned(
                    left: 14,
                    top: layout.bands[i].gateY - 40,
                    child: _WorldLabel(
                      band: layout.bands[i],
                      previousLast: i == 0 ? null : layout.bands[i - 1].world.lastNumber,
                    ),
                  ),
                for (final node in layout.nodes)
                  Positioned(
                    left: layout.centers[node.slot.entry.id]!.dx - LevelNode.width / 2,
                    top: layout.centers[node.slot.entry.id]!.dy - LevelNode.diameter / 2,
                    child: LevelNode(node: node, onTap: () => _onTap(map, node)),
                  ),
                if (current != null)
                  Positioned(
                    left: current.dx - LevelAvatarPin.width / 2,
                    top: current.dy - LevelNode.diameter / 2 - LevelAvatarPin.height,
                    child: LevelAvatarPin(user: user),
                  ),
                if (map.allCleared)
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: Center(child: _Chip(text: AppStrings.levelAllDone)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.stars, this.maxStars});

  final int? stars;
  final int? maxStars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.levelsTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (stars != null && maxStars != null)
                _Chip(
                  icon: AppIcons.star,
                  text: '$stars / $maxStars',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(text: AppStrings.zipTitle, selected: true),
              _Chip(text: '${AppStrings.pathWordsTab} · ${AppStrings.levelsSoon}'),
              _Chip(text: '${AppStrings.sudokuTitle} · ${AppStrings.levelsSoon}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon, this.selected = false});

  final String text;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? ZipColors.ember : ZipColors.paper,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 14, color: ZipColors.star),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? ZipColors.onInk : (icon != null ? ZipColors.star : ZipColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldLabel extends StatelessWidget {
  const _WorldLabel({required this.band, this.previousLast});

  final LevelMapBand band;

  /// The last level of the world below, which opens this one.
  final int? previousLast;

  @override
  Widget build(BuildContext context) {
    final world = band.world;
    final title = AppStrings.levelWorldTitle(world.world.order, world.world.theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ZipColors.ink.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!world.open) ...[
                const AppIcon(AppIcons.lock, size: 13, color: ZipColors.inkSoft),
                const SizedBox(width: 5),
              ],
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZipColors.onInk),
              ),
              if (world.open) ...[
                const SizedBox(width: 8),
                const AppIcon(AppIcons.star, size: 11, color: ZipColors.star),
                const SizedBox(width: 3),
                Text(
                  '${world.stars}/${world.maxStars}',
                  style: const TextStyle(fontSize: 11, color: ZipColors.star),
                ),
              ],
            ],
          ),
          if (!world.open && previousLast != null)
            Text(
              AppStrings.levelWorldLocked(previousLast!),
              style: const TextStyle(fontSize: 10, color: ZipColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ZipColors.onInk),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const AppIcon(AppIcons.refresh),
                label: Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Notes for the implementer:
- `ZipAtmosphere` is in `lib/core/widgets/zip_ui.dart`. `AppStrings.zipTitle`, `pathWordsTab`, `sudokuTitle`, `levelsTitle`, `levelAllDone`, `retry` exist.
- The world label for World 1 sits at the bottom of the map (its band's bottom is the map's bottom); that's intended.
- The bottom dock overlaps the map's bottom; `bottomPad` (120) keeps Level 1 above it. If the dashboard already pads the body (see how `LeaderboardScreen` handles the dock), keep it as is.

- [ ] **Step 3: Run the test** → PASS (6 tests). If the open= test's sheet doesn't appear, check that `_place` runs after the first ready build (post-frame) and that `showLevelSheet` uses a context under the `MaterialApp`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/levels/view/levels_screen.dart test/features/levels/view/levels_screen_test.dart
git commit -m "feat(levels): the Levels screen"
```

---

### Task 10: The tab, the route and links

**Files:**
- Modify: `lib/core/router/play_mode_route.dart` (`levelsLocation`, `levelsOpenLocation`, redirect target)
- Modify: `lib/core/router/app_router.dart` (new shell branch, second)
- Modify: `lib/features/dashboard/view/widgets/floating_nav_dock.dart` (`_destinations`)
- Modify: `test/core/router/play_mode_route_level_test.dart`; any dashboard/dock tests that assume three tabs
- Test: `test/features/dashboard/levels_tab_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

In `test/core/router/play_mode_route_level_test.dart`, change every expected redirect of a level link from `'/'` to `'/levels'`, and add:

```dart
  test('levels locations', () {
    expect(levelsLocation, '/levels');
    expect(levelsOpenLocation('zip_1_02'), '/levels?open=zip_1_02');
  });
```

Create `test/features/dashboard/levels_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';

void main() {
  testWidgets('the dock has Home, Levels, Board and Profile, in order', (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingNavDock(selectedIndex: 0, onDestinationSelected: (i) => picked = i),
        ),
      ),
    );
    expect(find.text('Levels'), findsOneWidget);
    await tester.tap(find.text('Levels'));
    expect(picked, 1);
  });
}
```

Run: `flutter test test/core/router/play_mode_route_level_test.dart test/features/dashboard/levels_tab_test.dart` → FAIL.

- [ ] **Step 2: Implement**

`play_mode_route.dart`:

```dart
/// The Levels tab.
const levelsLocation = '/levels';

/// The Levels tab with [levelId]'s sheet open (Results' Next level).
String levelsOpenLocation(String levelId) => '$levelsLocation?open=$levelId';
```

and in `playModeRedirect`, return `levelsLocation` instead of `'/'` for a malformed level link and for a level link on the wrong game; update its doc comment ("… sends it to the Levels tab").

`app_router.dart`: insert a new `StatefulShellBranch` between the Home branch and the Leaderboard branch:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: levelsLocation,
                name: 'levels',
                builder: (context, state) {
                  final open = state.uri.queryParameters['open'];
                  // A new open= (Next level) builds a fresh map that opens it.
                  return LevelsScreen(key: ValueKey(open), openLevelId: open);
                },
              ),
            ],
          ),
```

(import `../../features/levels/view/levels_screen.dart`; `levelsLocation` comes from `play_mode_route.dart`, already imported there).

`floating_nav_dock.dart`, in `_destinations` after Home:

```dart
    _DockDestination(
      label: AppStrings.levelsTitle,
      icon: AppIcons.levels,
      selectedIcon: AppIcons.levelsSelected,
    ),
```

Then run `grep -rn "goBranch(\|selectedIndex: [0-9]\|currentIndex" lib test` and fix anything that assumed Leaderboard was branch 1 or Profile branch 2 (the dashboard's back-to-Home `goBranch(0)` stays). Also check `playAuthRedirect` in `app_router.dart`'s helpers: the Levels tab shows without sign-in (playing still requires it), so it needs no change unless it whitelists tab paths — if it does, add `levelsLocation` beside `/leaderboard`.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/core/router test/features/dashboard` then the full `flutter test`.
Expected: PASS. Fix any test that counted three dock items.

- [ ] **Step 4: Commit**

```bash
git add lib/core/router lib/features/dashboard test/core/router test/features/dashboard
git commit -m "feat(levels): Levels is the second tab"
```

---

### Task 11: Back to the map from Results and a failed level; the strip icon

**Files:**
- Modify: `lib/features/results/results_args.dart` (`LevelResultInfo.nextLocation` → `nextLevelId`)
- Modify: `lib/features/zip/bloc/zip_bloc.dart` (`_finishLevel`)
- Modify: `lib/features/results/view/level_results_view.dart`
- Modify: `lib/features/zip/view/zip_screen.dart` (failed view)
- Modify: `lib/core/widgets/play_mode_strip.dart` (icon)
- Modify: `test/features/results/level_result_info_test.dart`, `test/features/results/level_results_view_test.dart`, `test/features/zip/bloc/zip_bloc_level_test.dart`, `test/features/zip/view/zip_screen_level_test.dart`

- [ ] **Step 1: Change the tests first**

- Everywhere a test builds or checks `LevelResultInfo(nextLocation: '/zip?mode=level&level=X')` or `level.nextLocation`, use `nextLevelId: 'X'` / `level.nextLevelId` instead (e.g. `expect(level.nextLevelId, 'zip_1_02')`; the last level: `isNull`).
- In `level_results_view_test.dart`, the action that read "Back home" now reads "Map" (expect `find.text('Map')`); add a test that tapping Next level goes to `/levels?open=zip_1_08` (use the file's GoRouter setup with a `/levels` route that records `state.uri`) and that Map goes to `/levels`.
- In `zip_screen_level_test.dart`, expect a "Map" button under Retry on the failed level screen.

Run: `flutter test test/features/results test/features/zip` → FAIL.

- [ ] **Step 2: Implement**

- `results_args.dart`: replace `nextLocation` with

```dart
  /// The next level; null on the last published level. Next level opens it
  /// on the map.
  final String? nextLevelId;
```

(constructor parameter `this.nextLevelId`).
- `zip_bloc.dart` `_finishLevel`: `nextLevelId: nextId,` in place of the `nextLocation:` expression.
- `level_results_view.dart`: Next level → `context.go(levelsOpenLocation(level.nextLevelId!))` (keep the `_log` call before it); the "Back home" button becomes `AppStrings.levelBackToMap` → `context.go(levelsLocation)` logging `'map'`; `next != null` checks use `level.nextLevelId`. Import `../../../core/router/play_mode_route.dart`.
- `zip_screen.dart` failed view: in level mode, add under the Retry button:

```dart
                                  if (widget.mode.isLevel) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => context.go(levelsLocation),
                                      icon: const AppIcon(AppIcons.levels),
                                      label: Text(AppStrings.levelBackToMap),
                                    ),
                                  ],
```

(import `../../../core/router/play_mode_route.dart` and go_router if not yet).
- `play_mode_strip.dart`: the strip's icon is `mode.isArchive ? AppIcons.calendar : AppIcons.infinity`; make it `mode.isArchive ? AppIcons.calendar : mode.isLevel ? AppIcons.levels : AppIcons.infinity`.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/results test/features/zip test/core/widgets` then the full `flutter test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/results lib/features/zip lib/core/widgets test/features/results test/features/zip
git commit -m "feat(levels): Results and failed levels lead back to the map"
```

---

### Task 12: Verification

- [ ] `flutter analyze` → 0 errors, 0 warnings, 20 infos (none in touched files).
- [ ] Full `flutter test` → all pass.
- [ ] On a device (World 1 is seeded in `brain-zip-app`): open the Levels tab → the map scrolls to Level 1 (or the next level) with the avatar pin; Level 2+ shows padlocks; tapping a locked level says "Clear Level N first"; tapping the current level opens the sheet → Play → the board; clear it → Results → Next level → back on the map with Level 2's sheet open; Map returns to the map; a link to a locked level shows "This level is still locked." with a Map button.
- [ ] Hand off with superpowers:finishing-a-development-branch. Plan 3b (motion: the line drawn in each world's material, the world crossing, reduced motion) is next.

---

## Spec coverage (self-review)

| Spec item | Task |
|---|---|
| Levels as the second tab, Phosphor map icon | 1, 10 |
| Game switcher (Zip; Path Words and Sudoku "soon") | 9 |
| Total stars in the header | 9 |
| Done / current / locked nodes in each world's material; stars as seals or dots | 2, 7 |
| Avatar pin on the current level | 7, 9 |
| Ink and Metro backdrops; locked worlds unprinted; unknown theme plain | 6 |
| Line drawn so far; dotted road ahead | 6 |
| World label with star total; locked world says what opens it | 9 |
| Map scrolls to the current level | 9 |
| Sheet: world, level, size, best, goals, Play / Replay; locked tap message | 8, 9 |
| Unlocking one by one, enforced (links too) | 2, 3 |
| Unavailable / empty / all cleared states | 4, 9 |
| Rebuild on progress change | 4 |
| Next level and Map go through the map; bad links go to /levels | 10, 11 |

**Deferred to plan 3b:** all motion (the line drawn in the world's material on return to the map, stars pressed, the world crossing and printing), reduced motion, pending-animation state in the cubit. **Changed from the spec:** the sheet lists the goals without per-goal ticks (progress stores best stars and best time, not which goals the best run met).
