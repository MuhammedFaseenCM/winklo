# Zip Levels — App Foundation Implementation Plan (plan 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/zip?mode=level&level=zip_1_01` plays a level loaded from Firestore `level_worlds`, awards 1–3 stars, records progress locally, syncs it to `users/{uid}/level_progress/zip`, and shows a level Results page. Everything is covered by tests.

**Architecture:** Levels is a fourth `PlayMode` (`PlayModeKind.level`) that runs through ZipBloc's existing off-daily path. Pure domain types (`LevelWorld`, `LevelProgress`, `LevelCatalog`, `starsFor`) sit behind repository interfaces. The data layer reads worlds through a thin `LevelWorldsSource` (Firestore in the app, a fake in tests) and keeps progress in SharedPreferences keyed by uid, with a Firestore mirror. `SyncLevelProgress` runs after every `SyncProgress` run from `ProgressSyncLifecycle`.

**Tech Stack:** Flutter, Dart 3, flutter_bloc, mocktail, bloc_test, shared_preferences, cloud_firestore; Firestore rules tests with `@firebase/rules-unit-testing` + vitest; Cloudflare Worker tests with vitest.

**Spec:** `docs/superpowers/specs/2026-10-31-zip-levels-design.md`

**Later plans:** 2 = winklo-admin (`level_worlds` routes, Levels tab, Generate world, publish rules). 3 = Levels tab (nav, map, sheet, Ink/Metro motion; changes "Next level" to go through the map and the bad-link redirect to `/levels`). 4 = Embroidery/Neon/Sparkler.

**Conventions for every task**
- Work in the worktree: `cd ~/Developments/personal/winklo/.worktrees/zip-levels` (branch `feat/zip-levels`). Run `flutter pub get` once before Task 1.
- Commit after each task. End every commit message with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `flutter analyze` must report no warnings or errors (infos are tolerated, as in CI).
- Copy goes through `AppStrings` → `AppText` (`AppTextEn`, `AppTextMl`). Malayalam lines are flagged for native review like the rest.
- No emoji in UI. No new animations in this plan (motion is plan 3).

---

## File structure

**Create**
| File | Responsibility |
|---|---|
| `lib/domain/entities/level_world.dart` | `LevelWorld`, `LevelEntry` + JSON parsing |
| `lib/domain/entities/level_progress.dart` | `LevelRecord`, `LevelProgress` (merge, parse, withRun) |
| `lib/domain/logic/level_stars.dart` | `starsFor` (**written by the user**) |
| `lib/domain/logic/level_catalog.dart` | `LevelCatalog`, `LevelSlot` (numbering, next level, world boundaries) |
| `lib/domain/repositories/level_world_repository.dart` | `LevelWorldRepository`, `LevelsUnavailable` |
| `lib/domain/repositories/level_progress_repository.dart` | `LevelProgressRepository`, `LevelClearResult` |
| `lib/domain/repositories/level_progress_remote_repository.dart` | `LevelProgressRemoteRepository` (split out after the Task 8 review) |
| `lib/domain/usecases/record_level_clear.dart` | stars for a run → record → analytics |
| `lib/domain/usecases/sync_level_progress.dart` | pull/merge/push of level progress |
| `lib/data/clients/level_worlds_source.dart` | `LevelWorldsSource` + Firestore query |
| `lib/data/repositories/level_world_repository_impl.dart` | server→cache fallback, parse, memoize |
| `lib/data/repositories/level_progress_repository_impl.dart` | SharedPreferences store per uid |
| `lib/data/repositories/level_progress_remote_repository_impl.dart` | Firestore doc mirror |
| `lib/features/results/view/level_results_view.dart` | Results for a level |
| `firestore/rules_test/levels.test.ts` | rules for `level_worlds` and `level_progress` |
| `test/helpers/level_fixtures.dart` | boards and worlds for tests |
| tests next to each unit (paths in each task) | |

**Modify**: `lib/domain/play_mode.dart`, `lib/core/router/play_mode_route.dart`, `lib/domain/hint_penalty.dart`, `lib/domain/play_mode_hints.dart`, `lib/core/widgets/play_mode_strip.dart`, `lib/core/strings/{app_text,app_text_en,app_text_ml,app_strings}.dart`, `lib/domain/repositories/analytics_repository.dart`, `lib/data/repositories/firebase_analytics_repository_impl.dart`, `test/helpers/mock_analytics_repository.dart`, `lib/core/lifecycle/progress_sync_lifecycle.dart`, `lib/app.dart`, `lib/features/results/results_args.dart`, `lib/features/results/results_screen.dart`, `lib/features/zip/bloc/zip_bloc.dart`, `lib/features/zip/view/zip_screen.dart`, `lib/core/di/app_repositories.dart`, `firestore/firestore.rules`, `firestore/firestore.indexes.json`, `workers/account-deletion/src/firestore_wipe.ts`, `workers/account-deletion/src/firestore_wipe.test.ts`; dead-code removal in Task 20.

---

### Task 1: `PlayMode.level` and its route

**Files:**
- Modify: `lib/domain/play_mode.dart`
- Modify: `lib/core/router/play_mode_route.dart:28-35` (`playModeRedirect`)
- Test: `test/domain/play_mode_test.dart` (append a group), `test/core/router/play_mode_route_level_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/domain/play_mode_test.dart`:

```dart
  group('level', () {
    test('parses a level id', () {
      final mode = PlayMode.fromQuery(const {
        'mode': 'level',
        'level': 'zip_1_07',
      }, now: now);
      expect(mode, const PlayMode.level('zip_1_07'));
      expect(mode!.isLevel, isTrue);
      expect(mode.isDaily, isFalse);
      expect(mode.levelId, 'zip_1_07');
    });

    test('refuses a missing or malformed id', () {
      for (final query in const <Map<String, String>>[
        {'mode': 'level'},
        {'mode': 'level', 'level': ''},
        {'mode': 'level', 'level': 'zip'},
        {'mode': 'level', 'level': '../zip_1_01'},
        {'mode': 'level', 'level': 'Zip_1_07'},
      ]) {
        expect(PlayMode.fromQuery(query, now: now), isNull, reason: '$query');
      }
    });

    test('round-trips through its location', () {
      const mode = PlayMode.level('zip_2_13');
      final uri = Uri.parse(mode.location('/zip'));
      expect(uri.toString(), '/zip?mode=level&level=zip_2_13');
      expect(PlayMode.fromQuery(uri.queryParameters, now: now), mode);
    });

    test('keeps drafts under its own run id and has no record key', () {
      const mode = PlayMode.level('zip_1_07');
      expect(mode.runId(dailyPlayId: '20261015'), 'level_zip_1_07');
      expect(() => mode.recordKey('zip'), throwsStateError);
    });

    test('equality includes the level id', () {
      expect(
        const PlayMode.level('zip_1_01'),
        isNot(const PlayMode.level('zip_1_02')),
      );
      expect(
        const PlayMode.level('zip_1_01').hashCode,
        const PlayMode.level('zip_1_01').hashCode,
      );
      expect(const PlayMode.level('zip_1_01').toString(), 'PlayMode.level(zip_1_01)');
    });
  });
```

Create `test/core/router/play_mode_route_level_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a valid level link opens the level', () {
    final uri = Uri.parse('/zip?mode=level&level=zip_1_01');
    expect(playModeRedirect(uri, gameId: 'zip'), isNull);
    expect(playModeOf(uri), const PlayMode.level('zip_1_01'));
  });

  test('a malformed level link goes Home instead of opening the daily', () {
    final uri = Uri.parse('/zip?mode=level&level=nope');
    expect(playModeRedirect(uri, gameId: 'zip'), '/');
  });

  test('archive redirects are unchanged', () {
    final uri = Uri.parse('/zip?mode=archive&day=2020-01-01');
    expect(playModeRedirect(uri, gameId: 'zip'), '/more/archive?game=zip');
  });
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/domain/play_mode_test.dart test/core/router/play_mode_route_level_test.dart`
Expected: compile errors (`PlayMode.level` / `isLevel` / `levelId` not defined).

- [ ] **Step 3: Implement**

Replace `lib/domain/play_mode.dart` with:

```dart
import 'app_calendar.dart';
import 'play_period.dart';

enum PlayModeKind { daily, archive, practice, level }

/// How a game was opened: today's daily, a past daily from the archive, an
/// endless practice board, or one level of the game's Levels map.
///
/// Only [daily] runs touch the daily world (streaks, boards, the daily best,
/// the daily hint quota, the reminders and the widget). Archive, practice and
/// level runs keep their own drafts under keys that start with the mode
/// ([runId]), so nothing that reads the dailies' keys can mistake them for a
/// daily. Level bests live in the level progress repository, not here.
final class PlayMode {
  const PlayMode._(this.kind) : day = null, levelId = null;

  /// [day] is kept as a calendar day.
  PlayMode.archive(DateTime day)
    : kind = PlayModeKind.archive,
      day = DateTime(day.year, day.month, day.day),
      levelId = null;

  /// One level of the Levels map, by its stable id (`zip_1_07`).
  const PlayMode.level(String this.levelId)
    : kind = PlayModeKind.level,
      day = null;

  static const daily = PlayMode._(PlayModeKind.daily);
  static const practice = PlayMode._(PlayModeKind.practice);

  final PlayModeKind kind;

  /// The archive day; null for the other modes.
  final DateTime? day;

  /// The level's id; null for the other modes.
  final String? levelId;

  bool get isDaily => kind == PlayModeKind.daily;
  bool get isArchive => kind == PlayModeKind.archive;
  bool get isPractice => kind == PlayModeKind.practice;
  bool get isLevel => kind == PlayModeKind.level;

  /// The first hard daily, where the archive starts.
  static final archiveFirstDay = DateTime(2026, 10, 11);

  /// The archive's newest day: yesterday on the device's calendar. Today is
  /// never in it, so nobody can learn today's board before playing it.
  static DateTime archiveLastDay(DateTime now) {
    final today = AppCalendar.calendarDay(now);
    return DateTime(today.year, today.month, today.day - 1);
  }

  static bool isArchiveDay(DateTime day, {required DateTime now}) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(archiveFirstDay) && !d.isAfter(archiveLastDay(now));
  }

  static final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// A level id: game, world and level number (`zip_1_07`,
  /// `path_words_2_13`).
  static final levelIdPattern = RegExp(r'^[a-z][a-z_]*_[0-9]{1,3}_[0-9]{2,3}$');

  /// Reads `mode` (and `day` or `level`) from a game route's query. A missing
  /// or unknown mode is [daily], so App Links and the widget keep opening
  /// today's puzzle. Null for an archive day that is malformed or not in the
  /// archive, and for a malformed level id.
  static PlayMode? fromQuery(
    Map<String, String> query, {
    required DateTime now,
  }) {
    switch (query['mode']) {
      case 'practice':
        return practice;
      case 'level':
        final id = query['level'] ?? '';
        return levelIdPattern.hasMatch(id) ? PlayMode.level(id) : null;
      case 'archive':
        final match = _dayPattern.firstMatch(query['day'] ?? '');
        if (match == null) return null;
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        final day = DateTime(y, m, d);
        // DateTime rolls 2026-13-01 over into 2027; refuse it.
        if (day.year != y || day.month != m || day.day != d) return null;
        if (!isArchiveDay(day, now: now)) return null;
        return PlayMode.archive(day);
      default:
        return daily;
    }
  }

  /// [path] with this mode's query (`/zip?mode=archive&day=2026-10-09`,
  /// `/zip?mode=level&level=zip_1_07`).
  String location(String path) {
    switch (kind) {
      case PlayModeKind.daily:
        return path;
      case PlayModeKind.practice:
        return '$path?mode=practice';
      case PlayModeKind.archive:
        return '$path?mode=archive&day=${AppCalendar.dateIdDashed(day!)}';
      case PlayModeKind.level:
        return '$path?mode=level&level=$levelId';
    }
  }

  String get _dayId => PlayPeriod.id(day!, PlayPeriod.daily);

  /// Id of the run's period for drafts and hints: the daily's [dailyPlayId],
  /// `archive_<yyyyMMdd>`, `practice` or `level_<levelId>`.
  String runId({required String dailyPlayId}) {
    switch (kind) {
      case PlayModeKind.daily:
        return dailyPlayId;
      case PlayModeKind.archive:
        return 'archive_$_dayId';
      case PlayModeKind.practice:
        return 'practice';
      case PlayModeKind.level:
        return 'level_$levelId';
    }
  }

  /// Where an archive or practice run of [gameId] keeps its best:
  /// `archive_<game>_<yyyyMMdd>` or `practice_<game>`. Dailies keep theirs
  /// under `modeKeyFor`, through the score repository; levels in the level
  /// progress repository.
  String recordKey(String gameId) {
    switch (kind) {
      case PlayModeKind.daily:
        throw StateError('Daily bests live in the score repository');
      case PlayModeKind.level:
        throw StateError('Level bests live in LevelProgressRepository');
      case PlayModeKind.archive:
        return 'archive_${gameId}_$_dayId';
      case PlayModeKind.practice:
        return 'practice_$gameId';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlayMode &&
      other.kind == kind &&
      other.day == day &&
      other.levelId == levelId;

  @override
  int get hashCode => Object.hash(kind, day, levelId);

  @override
  String toString() => switch (kind) {
    PlayModeKind.archive =>
      'PlayMode.archive(${AppCalendar.dateIdDashed(day!)})',
    PlayModeKind.level => 'PlayMode.level($levelId)',
    _ => 'PlayMode.${kind.name}',
  };
}
```

In `lib/core/router/play_mode_route.dart`, replace `playModeRedirect` and its doc comment with:

```dart
/// Sends a game link whose archive day is malformed, today, in the future
/// or before the archive began to that game's archive calendar, and a
/// malformed level link Home, so neither opens today's puzzle unranked.
/// Null for everything else.
String? playModeRedirect(Uri uri, {required String gameId, DateTime? now}) {
  final kind = uri.queryParameters['mode'];
  if (kind != 'archive' && kind != 'level') return null;
  final mode = PlayMode.fromQuery(
    uri.queryParameters,
    now: now ?? DateTime.now(),
  );
  if (mode != null) return null;
  return kind == 'archive' ? archiveLocation(gameId) : '/';
}
```

- [ ] **Step 4: Fix exhaustive switches elsewhere**

Run: `flutter analyze`
For `lib/domain/play_mode_hints.dart` this is done in Task 3; ignore that error for now. For any **other** `non_exhaustive_switch` on `PlayModeKind`, add `case PlayModeKind.level:` to the same branch as `case PlayModeKind.practice:`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/domain/play_mode_test.dart test/core/router/play_mode_route_level_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/play_mode.dart lib/core/router/play_mode_route.dart test/domain/play_mode_test.dart test/core/router/play_mode_route_level_test.dart
git commit -m "feat(levels): add PlayMode.level and its route"
```

---

### Task 2: Level copy in `AppStrings`

**Files:**
- Modify: `lib/core/strings/app_text.dart` (next to `archiveRunLabel`, ~line 501)
- Modify: `lib/core/strings/app_text_en.dart` (next to `archiveRunLabel`, ~line 1363)
- Modify: `lib/core/strings/app_text_ml.dart` (next to `archiveRunLabel`, ~line 1423)
- Modify: `lib/core/strings/app_strings.dart` (next to `archiveRunLabel`, ~line 562)
- Test: `test/core/strings/level_strings_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';

void main() {
  test('level copy in English', () {
    expect(AppStrings.levelsTitle, 'Levels');
    expect(AppStrings.levelWorldName('ink'), 'Ink');
    expect(AppStrings.levelWorldName('sparkler'), 'Sparkler');
    expect(AppStrings.levelWorldName('unknown'), 'Levels');
    expect(AppStrings.levelRunLabel(27, 'metro'), 'Level 27 · Metro');
    expect(AppStrings.levelClearedTitle(7), 'Level 7 cleared');
    expect(AppStrings.levelHintCostsStar, 'Hint · costs a star');
    expect(AppStrings.levelTarget('0:30'), 'Target 0:30');
    expect(AppStrings.levelGoalUnder('0:30'), '0:30 or less');
    expect(AppStrings.levelNewBestStars(2, 3), 'New best · 2 → 3 stars');
    expect(AppStrings.levelOpenWorld('metro'), 'Open Metro');
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/core/strings/level_strings_test.dart`
Expected: compile errors (`levelsTitle` not defined).

- [ ] **Step 3: Implement**

`app_text.dart`, add after `String archiveRunLabel(DateTime day);`:

```dart
  // Levels
  String get levelsTitle;

  /// A world's name from its theme (`ink`, `metro`, …); [levelsTitle] for
  /// an unknown theme.
  String levelWorldName(String theme);
  String levelRunLabel(int number, String worldName);
  String levelClearedTitle(int number);
  String get levelFailed;
  String get levelHintCostsStar;
  String levelTarget(String time);
  String get levelGoalClear;
  String get levelGoalNoHints;
  String levelGoalUnder(String time);
  String get levelGoalNoHintsHow;
  String levelGoalUnderHow(String time);
  String levelNewBestStars(int from, int to);
  String get levelNewBestTime;
  String get levelNext;
  String levelOpenWorld(String worldName);
  String get levelReplay;
  String get levelAllDone;
```

`app_text_en.dart`, add after the `archiveRunLabel` override:

```dart
  @override
  String get levelsTitle => 'Levels';
  @override
  String levelWorldName(String theme) => switch (theme) {
    'ink' => 'Ink',
    'metro' => 'Metro',
    'embroidery' => 'Embroidery',
    'neon' => 'Neon',
    'sparkler' => 'Sparkler',
    _ => levelsTitle,
  };
  @override
  String levelRunLabel(int number, String worldName) =>
      'Level $number · $worldName';
  @override
  String levelClearedTitle(int number) => 'Level $number cleared';
  @override
  String get levelFailed => 'Could not load this level.';
  @override
  String get levelHintCostsStar => 'Hint · costs a star';
  @override
  String levelTarget(String time) => 'Target $time';
  @override
  String get levelGoalClear => 'Clear the board';
  @override
  String get levelGoalNoHints => 'No hints';
  @override
  String levelGoalUnder(String time) => '$time or less';
  @override
  String get levelGoalNoHintsHow => 'Replay without hints for this star';
  @override
  String levelGoalUnderHow(String time) =>
      'Replay in $time or less for this star';
  @override
  String levelNewBestStars(int from, int to) => 'New best · $from → $to stars';
  @override
  String get levelNewBestTime => 'New best time';
  @override
  String get levelNext => 'Next level';
  @override
  String levelOpenWorld(String worldName) => 'Open $worldName';
  @override
  String get levelReplay => 'Replay';
  @override
  String get levelAllDone => 'More worlds coming soon';
```

`app_text_ml.dart`, add after the `archiveRunLabel` override (native review pending, like the rest):

```dart
  @override
  String get levelsTitle => 'ലെവലുകൾ';
  @override
  String levelWorldName(String theme) => switch (theme) {
    'ink' => 'മഷി',
    'metro' => 'മെട്രോ',
    'embroidery' => 'ചിത്രത്തുന്നൽ',
    'neon' => 'നിയോൺ',
    'sparkler' => 'കമ്പിത്തിരി',
    _ => levelsTitle,
  };
  @override
  String levelRunLabel(int number, String worldName) =>
      'ലെവൽ $number · $worldName';
  @override
  String levelClearedTitle(int number) => 'ലെവൽ $number പൂർത്തിയായി';
  @override
  String get levelFailed => 'ഈ ലെവൽ ലോഡ് ചെയ്യാനായില്ല.';
  @override
  String get levelHintCostsStar => 'സൂചന · ഒരു നക്ഷത്രം കുറയും';
  @override
  String levelTarget(String time) => 'ലക്ഷ്യം $time';
  @override
  String get levelGoalClear => 'ബോർഡ് പൂർത്തിയാക്കുക';
  @override
  String get levelGoalNoHints => 'സൂചനയില്ലാതെ';
  @override
  String levelGoalUnder(String time) => '$time-നുള്ളിൽ';
  @override
  String get levelGoalNoHintsHow =>
      'ഈ നക്ഷത്രത്തിന് സൂചനയില്ലാതെ വീണ്ടും കളിക്കുക';
  @override
  String levelGoalUnderHow(String time) =>
      'ഈ നക്ഷത്രത്തിന് $time-നുള്ളിൽ വീണ്ടും കളിക്കുക';
  @override
  String levelNewBestStars(int from, int to) =>
      'പുതിയ മികച്ചത് · $from → $to നക്ഷത്രങ്ങൾ';
  @override
  String get levelNewBestTime => 'പുതിയ മികച്ച സമയം';
  @override
  String get levelNext => 'അടുത്ത ലെവൽ';
  @override
  String levelOpenWorld(String worldName) => '$worldName തുറക്കുക';
  @override
  String get levelReplay => 'വീണ്ടും കളിക്കുക';
  @override
  String get levelAllDone => 'കൂടുതൽ ലോകങ്ങൾ ഉടൻ വരുന്നു';
```

`app_strings.dart`, add after `static String archiveRunLabel(...)`:

```dart
  static String get levelsTitle => _t.levelsTitle;
  static String levelWorldName(String theme) => _t.levelWorldName(theme);

  /// "Level 27 · Metro", from the world's [theme].
  static String levelRunLabel(int number, String theme) =>
      _t.levelRunLabel(number, _t.levelWorldName(theme));
  static String levelClearedTitle(int number) => _t.levelClearedTitle(number);
  static String get levelFailed => _t.levelFailed;
  static String get levelHintCostsStar => _t.levelHintCostsStar;
  static String levelTarget(String time) => _t.levelTarget(time);
  static String get levelGoalClear => _t.levelGoalClear;
  static String get levelGoalNoHints => _t.levelGoalNoHints;
  static String levelGoalUnder(String time) => _t.levelGoalUnder(time);
  static String get levelGoalNoHintsHow => _t.levelGoalNoHintsHow;
  static String levelGoalUnderHow(String time) => _t.levelGoalUnderHow(time);
  static String levelNewBestStars(int from, int to) =>
      _t.levelNewBestStars(from, to);
  static String get levelNewBestTime => _t.levelNewBestTime;
  static String get levelNext => _t.levelNext;
  /// "Open Metro", from the next world's [theme].
  static String levelOpenWorld(String theme) =>
      _t.levelOpenWorld(_t.levelWorldName(theme));
  static String get levelReplay => _t.levelReplay;
  static String get levelAllDone => _t.levelAllDone;
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/strings/level_strings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings test/core/strings/level_strings_test.dart
git commit -m "feat(levels): add level copy in English and Malayalam"
```

---

### Task 3: Hints in level runs are free of time and count in memory

**Files:**
- Modify: `lib/domain/hint_penalty.dart` (`appliesTo` and its doc)
- Modify: `lib/domain/play_mode_hints.dart`
- Modify: `lib/core/widgets/play_mode_strip.dart` (`hintLabelFor`)
- Modify: `lib/core/di/app_repositories.dart` (the `HintQuotaForMode` provider, ~line 296)
- Test: `test/domain/hint_penalty_test.dart` (append), `test/core/widgets/hint_label_level_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/domain/hint_penalty_test.dart` (add `import 'package:winklo/domain/play_mode.dart';` if it isn't imported yet):

```dart
  test('level hints cost no time; they cost a star instead', () {
    const mode = PlayMode.level('zip_1_01');
    expect(HintPenalty.appliesTo(mode), isFalse);
    expect(HintPenalty.nextSeconds(mode, hintsUsed: 2), 0);
    expect(HintPenalty.chargedSeconds(mode, hintsUsed: 3), 0);
  });
```

Create `test/core/widgets/hint_label_level_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/play_mode_strip.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a level hint says it costs a star until one is used', () {
    const mode = PlayMode.level('zip_1_01');
    expect(hintLabelFor(mode, hintsUsed: 0), 'Hint · costs a star');
    expect(hintLabelFor(mode, hintsUsed: 1), 'Hint');
  });
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/domain/hint_penalty_test.dart test/core/widgets/hint_label_level_test.dart`
Expected: FAIL (`appliesTo` is true for levels; the label is "Hint +10s").

- [ ] **Step 3: Implement**

`hint_penalty.dart`: replace

```dart
  /// Whether hints in [mode] cost time.
  static bool appliesTo(PlayMode mode) => !mode.isPractice;
```

with

```dart
  /// Whether hints in [mode] cost time. Practice hints are free; a level
  /// hint costs that level's no-hints star instead.
  static bool appliesTo(PlayMode mode) => !mode.isPractice && !mode.isLevel;
```

and change the class doc line `/// Dailies and the archive pay it; practice hints are free.` to `/// Dailies and the archive pay it; practice and level hints are free.`

`play_mode_hints.dart`: replace the class body with:

```dart
class HintQuotaForMode {
  const HintQuotaForMode({
    required this.daily,
    required this.archive,
    required this.practice,
    required this.level,
  });

  final HintQuotaRepository daily;
  final HintQuotaRepository archive;
  final HintQuotaRepository practice;

  /// Level runs count hints in memory: a hint costs a star, not time, and a
  /// draft keeps `usedHintsThisRun` itself.
  final HintQuotaRepository level;

  HintQuotaRepository call(PlayMode mode) {
    switch (mode.kind) {
      case PlayModeKind.daily:
        return daily;
      case PlayModeKind.archive:
        return archive;
      case PlayModeKind.practice:
        return practice;
      case PlayModeKind.level:
        return level;
    }
  }
}
```

`play_mode_strip.dart`: replace `hintLabelFor` with:

```dart
/// The hint button's label: what the next hint costs ("Hint +20s"), plain
/// "Hint" in practice, where hints are free, and in a level "Hint · costs a
/// star" until the first hint of the run.
String hintLabelFor(PlayMode mode, {required int hintsUsed}) {
  if (mode.isLevel) {
    return hintsUsed == 0
        ? AppStrings.levelHintCostsStar
        : AppStrings.hintUnlimited;
  }
  final cost = HintPenalty.nextSeconds(mode, hintsUsed: hintsUsed);
  return cost > 0 ? AppStrings.hintWithCost(cost) : AppStrings.hintUnlimited;
}
```

`app_repositories.dart`, in the `HintQuotaForMode` provider add `level: UnlimitedHintQuotaRepositoryImpl(),` after `practice: UnlimitedHintQuotaRepositoryImpl(),`.

Then run `grep -rn "HintQuotaForMode(" test lib` and add `level: UnlimitedHintQuotaRepositoryImpl(),` to every other constructor call it lists (import `package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart` in tests that lack it).

- [ ] **Step 4: Run the tests and analyze**

Run: `flutter test test/domain/hint_penalty_test.dart test/core/widgets/hint_label_level_test.dart && flutter analyze`
Expected: tests PASS; analyze has no warnings or errors.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/hint_penalty.dart lib/domain/play_mode_hints.dart lib/core/widgets/play_mode_strip.dart lib/core/di/app_repositories.dart test
git commit -m "feat(levels): level hints cost a star, not time"
```

---

### Task 4: `LevelWorld` and `LevelEntry`

**Files:**
- Create: `lib/domain/entities/level_world.dart`
- Create: `test/helpers/level_fixtures.dart`
- Test: `test/domain/entities/level_world_test.dart`

- [ ] **Step 1: Create the fixtures**

`test/helpers/level_fixtures.dart`:

```dart
import 'package:winklo/domain/entities/level_world.dart';

/// A 3×3 Zip board with a serpentine solution; numbers 1 and 2 at its ends.
Map<String, dynamic> levelBoardJson(String id, {int? targetSeconds}) => {
  'id': id,
  'size': 3,
  'numbers': {'0,0': 1, '2,2': 2},
  'walls': <Object>[],
  'solution': [
    [0, 0], [0, 1], [0, 2],
    [1, 2], [1, 1], [1, 0],
    [2, 0], [2, 1], [2, 2],
  ],
  'targetSeconds': ?targetSeconds,
};

String levelId(int world, int n) => 'zip_${world}_${n.toString().padLeft(2, '0')}';

Map<String, dynamic> levelWorldJson(
  int order,
  int count, {
  String theme = 'ink',
  int targetSeconds = 30,
}) => {
  'game': 'zip',
  'order': order,
  'published': true,
  'theme': theme,
  'levels': [
    for (var n = 1; n <= count; n++)
      levelBoardJson(levelId(order, n), targetSeconds: targetSeconds),
  ],
};

LevelWorld levelWorld(
  int order,
  int count, {
  String theme = 'ink',
  int targetSeconds = 30,
}) => LevelWorld.fromJson(
  'zip_$order',
  levelWorldJson(order, count, theme: theme, targetSeconds: targetSeconds),
);
```

- [ ] **Step 2: Write the failing test**

`test/domain/entities/level_world_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_world.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  test('parses a world and its levels in order', () {
    final world = LevelWorld.fromJson('zip_1', levelWorldJson(1, 3));
    expect(world.id, 'zip_1');
    expect(world.game, 'zip');
    expect(world.order, 1);
    expect(world.theme, 'ink');
    expect(world.levels.map((l) => l.id), ['zip_1_01', 'zip_1_02', 'zip_1_03']);
    expect(world.levels.first.targetSeconds, 30);
  });

  test('a level builds its Zip board under its own id', () {
    final entry = LevelEntry.fromJson(levelBoardJson('zip_1_01'));
    final board = entry.zipLevel;
    expect(board.id, 'zip_1_01');
    expect(board.size, 3);
    expect(board.solution.length, 9);
  });

  test('a missing, zero or negative target means no time goal', () {
    expect(LevelEntry.fromJson(levelBoardJson('a_1_01')).targetSeconds, isNull);
    expect(
      LevelEntry.fromJson(levelBoardJson('a_1_01', targetSeconds: 0)).targetSeconds,
      isNull,
    );
    expect(
      LevelEntry.fromJson(levelBoardJson('a_1_01', targetSeconds: -5)).targetSeconds,
      isNull,
    );
  });

  test('refuses a level without an id and a world without levels', () {
    expect(
      () => LevelEntry.fromJson(<String, dynamic>{'size': 3}),
      throwsFormatException,
    );
    expect(() => LevelEntry.fromJson('not a map'), throwsFormatException);
    expect(
      () => LevelWorld.fromJson('zip_1', {'game': 'zip', 'order': 1}),
      throwsFormatException,
    );
    expect(
      () => LevelWorld.fromJson('zip_1', {'game': 'zip', 'levels': []}),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 3: Run it and see it fail**

Run: `flutter test test/domain/entities/level_world_test.dart`
Expected: compile error (`level_world.dart` not found).

- [ ] **Step 4: Implement**

`lib/domain/entities/level_world.dart`:

```dart
import 'zip_level.dart';

/// One world of a game's Levels (`level_worlds/{game}_{order}`): its look
/// and its levels in play order.
class LevelWorld {
  const LevelWorld({
    required this.id,
    required this.game,
    required this.order,
    required this.theme,
    required this.levels,
  });

  /// The doc id, `zip_1`.
  final String id;
  final String game;

  /// The world's place on the map, from 1.
  final int order;

  /// `ink`, `metro`, `embroidery`, `neon` or `sparkler`; the map draws a
  /// plain backdrop for anything else.
  final String theme;
  final List<LevelEntry> levels;

  /// Throws [FormatException] when the doc isn't a world.
  factory LevelWorld.fromJson(String id, Map<String, dynamic> json) {
    final order = json['order'];
    final rawLevels = json['levels'];
    if (order is! num || rawLevels is! List) {
      throw FormatException('World $id needs an order and a levels list');
    }
    return LevelWorld(
      id: id,
      game: _string(json['game']),
      order: order.toInt(),
      theme: _string(json['theme']),
      levels: [for (final raw in rawLevels) LevelEntry.fromJson(raw)],
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}

/// One level: a Zip board in `ZipLevel.toJson` shape, its stable id and the
/// time that earns its third star.
class LevelEntry {
  const LevelEntry({
    required this.id,
    required this.board,
    this.targetSeconds,
  });

  /// Stable id, `zip_1_07`; progress is keyed by it.
  final String id;
  final Map<String, dynamic> board;

  /// Null when the CMS left it out or set it to 0 or less: the level then
  /// has no time goal.
  final int? targetSeconds;

  ZipLevel get zipLevel => ZipLevel.fromJson(board, id: id);

  /// Throws [FormatException] when [raw] isn't a level with an id.
  factory LevelEntry.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('A level must be a map');
    final board = Map<String, dynamic>.from(raw);
    final id = board['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('A level needs an id');
    }
    final target = board['targetSeconds'];
    final seconds = target is num ? target.toInt() : null;
    return LevelEntry(
      id: id,
      board: board,
      targetSeconds: seconds != null && seconds > 0 ? seconds : null,
    );
  }
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/domain/entities/level_world_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/level_world.dart test/helpers/level_fixtures.dart test/domain/entities/level_world_test.dart
git commit -m "feat(levels): add LevelWorld and LevelEntry"
```

---

### Task 5: `starsFor` — written by the user

This is the learning-mode contribution: the tests and an empty function are set up, and **the user writes the body**. An agent running this plan must stop at Step 3 and ask the user to write it.

**Files:**
- Create: `lib/domain/logic/level_stars.dart`
- Test: `test/domain/logic/level_stars_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_stars.dart';

void main() {
  int stars({bool hints = false, int seconds = 20, int? target = 30}) =>
      starsFor(usedHints: hints, seconds: seconds, targetSeconds: target);

  test('a clean run under the target earns all three', () {
    expect(stars(), 3);
  });

  test('exactly the target counts as beating it', () {
    expect(stars(seconds: 30), 3);
  });

  test('each missed goal costs one star', () {
    expect(stars(seconds: 31), 2);
    expect(stars(hints: true), 2);
    expect(stars(hints: true, seconds: 31), 1);
  });

  test('without a target there is no time star', () {
    expect(stars(target: null), 2);
    expect(stars(target: 0), 2);
    expect(stars(hints: true, target: null), 1);
  });

  test('a clear is never below one star, even with a broken clock', () {
    expect(stars(hints: true, seconds: 0), 1);
    expect(stars(seconds: 0), 2);
    expect(stars(seconds: -4), 2);
  });
}
```

- [ ] **Step 2: Create the file with the signature only**

`lib/domain/logic/level_stars.dart`:

```dart
/// Stars a cleared level run earns, 1 to 3: one for clearing, one for using
/// no hints, one for a time at or under [targetSeconds].
///
/// [targetSeconds] null or 0 or less means the level has no time goal. A
/// run's [seconds] below 1 comes from a broken clock and can't earn the
/// time star.
int starsFor({
  required bool usedHints,
  required int seconds,
  required int? targetSeconds,
}) {
  // Written by the user: see test/domain/logic/level_stars_test.dart.
  throw UnimplementedError('starsFor');
}
```

Run: `flutter test test/domain/logic/level_stars_test.dart`
Expected: FAIL with `UnimplementedError: starsFor`.

- [ ] **Step 3: STOP — the user writes the body (5–10 lines)**

Ask the user to replace the `throw` in `starsFor` so the five tests pass. The design choices the tests already pin down: equal to the target counts; no target means no time star; a time below 1 can't earn the time star; a clear is at least 1★.

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/logic/level_stars_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit** (author: the user)

```bash
git add lib/domain/logic/level_stars.dart test/domain/logic/level_stars_test.dart
git commit -m "feat(levels): stars for a level run"
```

---

### Task 6: `LevelRecord` and `LevelProgress`

**Files:**
- Create: `lib/domain/entities/level_progress.dart`
- Test: `test/domain/entities/level_progress_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';

void main() {
  const a = LevelProgress({
    'zip_1_01': LevelRecord(stars: 2, bestSeconds: 20),
    'zip_1_02': LevelRecord(stars: 1, bestSeconds: 50),
  });
  const b = LevelProgress({
    'zip_1_01': LevelRecord(stars: 3, bestSeconds: 25),
    'zip_1_03': LevelRecord(stars: 3, bestSeconds: 12),
  });

  test('merge keeps the most stars and the fastest time per level', () {
    final merged = a.merge(b);
    expect(merged['zip_1_01'], const LevelRecord(stars: 3, bestSeconds: 20));
    expect(merged['zip_1_02'], const LevelRecord(stars: 1, bestSeconds: 50));
    expect(merged['zip_1_03'], const LevelRecord(stars: 3, bestSeconds: 12));
  });

  test('merge is commutative and never makes a record worse', () {
    expect(a.merge(b).sameAs(b.merge(a)), isTrue);
    expect(a.merge(b).merge(a).sameAs(a.merge(b)), isTrue);
  });

  test('a run only ever improves its level', () {
    final slower = a.withRun('zip_1_01', stars: 1, seconds: 40);
    expect(slower['zip_1_01'], const LevelRecord(stars: 2, bestSeconds: 20));
    final better = a.withRun('zip_1_01', stars: 3, seconds: 18);
    expect(better['zip_1_01'], const LevelRecord(stars: 3, bestSeconds: 18));
    final first = a.withRun('zip_1_04', stars: 2, seconds: 0);
    expect(first['zip_1_04'], const LevelRecord(stars: 2, bestSeconds: 1));
  });

  test('stars add up and cleared levels are known', () {
    expect(a.totalStars, 3);
    expect(a.isCleared('zip_1_02'), isTrue);
    expect(a.isCleared('zip_1_03'), isFalse);
    expect(LevelProgress.empty.totalStars, 0);
  });

  test('parse drops invalid entries and counts them', () {
    final parsed = LevelProgress.parse({
      'zip_1_01': {'stars': 3, 'bestSeconds': 14},
      'zip_1_02': {'stars': 4, 'bestSeconds': 14},
      'zip_1_03': {'stars': 2, 'bestSeconds': 0},
      'zip_1_04': 'junk',
    });
    expect(parsed.dropped, 3);
    expect(parsed.progress.records.keys, ['zip_1_01']);
    expect(LevelProgress.parse(null).progress.sameAs(LevelProgress.empty), isTrue);
    expect(LevelProgress.parse(null).dropped, 0);
  });

  test('toJson round-trips through parse', () {
    final again = LevelProgress.parse(a.toJson()).progress;
    expect(again.sameAs(a), isTrue);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/entities/level_progress_test.dart`
Expected: compile error (file not found).

- [ ] **Step 3: Implement**

`lib/domain/entities/level_progress.dart`:

```dart
import 'dart:math';

/// A level's best: the most stars one run earned, and the fastest clear.
class LevelRecord {
  const LevelRecord({required this.stars, required this.bestSeconds});

  final int stars;
  final int bestSeconds;

  bool get isValid => stars >= 1 && stars <= 3 && bestSeconds >= 1;

  /// The better of both records, field by field.
  LevelRecord merge(LevelRecord other) => LevelRecord(
    stars: max(stars, other.stars),
    bestSeconds: min(bestSeconds, other.bestSeconds),
  );

  Map<String, Object> toJson() => {'stars': stars, 'bestSeconds': bestSeconds};

  /// Null for anything that isn't a valid record.
  static LevelRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    final stars = json['stars'];
    final seconds = json['bestSeconds'];
    if (stars is! num || seconds is! num) return null;
    final record = LevelRecord(
      stars: stars.toInt(),
      bestSeconds: seconds.toInt(),
    );
    return record.isValid ? record : null;
  }

  @override
  bool operator ==(Object other) =>
      other is LevelRecord &&
      other.stars == stars &&
      other.bestSeconds == bestSeconds;

  @override
  int get hashCode => Object.hash(stars, bestSeconds);

  @override
  String toString() => 'LevelRecord($stars★, ${bestSeconds}s)';
}

/// One player's records in a game's Levels, by level id.
///
/// Records only ever improve, so [merge] is commutative: a phone and the
/// server can be merged in either order and agree.
class LevelProgress {
  const LevelProgress(this.records);

  static const empty = LevelProgress(<String, LevelRecord>{});

  final Map<String, LevelRecord> records;

  LevelRecord? operator [](String levelId) => records[levelId];

  bool isCleared(String levelId) => records.containsKey(levelId);

  int get totalStars => records.values.fold(0, (sum, r) => sum + r.stars);

  /// This progress after a cleared run of [levelId]. A time below 1 s (a
  /// broken clock) is kept as 1 s so the record stays valid.
  LevelProgress withRun(
    String levelId, {
    required int stars,
    required int seconds,
  }) {
    final run = LevelRecord(stars: stars, bestSeconds: max(1, seconds));
    final old = records[levelId];
    return LevelProgress({
      ...records,
      levelId: old == null ? run : old.merge(run),
    });
  }

  LevelProgress merge(LevelProgress other) {
    final merged = Map<String, LevelRecord>.of(records);
    other.records.forEach((id, record) {
      final mine = merged[id];
      merged[id] = mine == null ? record : mine.merge(record);
    });
    return LevelProgress(merged);
  }

  bool sameAs(LevelProgress other) {
    if (records.length != other.records.length) return false;
    for (final entry in records.entries) {
      if (other.records[entry.key] != entry.value) return false;
    }
    return true;
  }

  Map<String, Object> toJson() => {
    for (final entry in records.entries) entry.key: entry.value.toJson(),
  };

  /// Reads a `levels` map, dropping (and counting) entries that aren't valid
  /// records. Anything that isn't a map is empty progress.
  static ({LevelProgress progress, int dropped}) parse(Object? json) {
    if (json is! Map) return (progress: empty, dropped: 0);
    final records = <String, LevelRecord>{};
    var dropped = 0;
    json.forEach((key, value) {
      final record = LevelRecord.tryParse(value);
      if (key is String && record != null) {
        records[key] = record;
      } else {
        dropped++;
      }
    });
    return (progress: LevelProgress(records), dropped: dropped);
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/entities/level_progress_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/level_progress.dart test/domain/entities/level_progress_test.dart
git commit -m "feat(levels): add LevelProgress with a monotonic merge"
```

---

### Task 7: `LevelCatalog`

**Files:**
- Create: `lib/domain/logic/level_catalog.dart`
- Test: `test/domain/logic/level_catalog_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_catalog.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  final ink = levelWorld(1, 3);
  final metro = levelWorld(2, 2, theme: 'metro');

  test('numbers levels across worlds, in world order', () {
    final catalog = LevelCatalog([metro, ink]);
    expect(catalog.worlds.map((w) => w.order), [1, 2]);
    expect(catalog.levelCount, 5);
    expect(catalog.slot('zip_1_01')!.number, 1);
    expect(catalog.slot('zip_1_03')!.number, 3);
    expect(catalog.slot('zip_2_01')!.number, 4);
    expect(catalog.slot('zip_2_01')!.indexInWorld, 0);
  });

  test('knows the next level and when it starts a new world', () {
    final catalog = LevelCatalog([ink, metro]);
    final second = catalog.slot('zip_1_02')!;
    expect(second.nextId, 'zip_1_03');
    expect(second.opensNewWorld, isFalse);
    final lastInk = catalog.slot('zip_1_03')!;
    expect(lastInk.nextId, 'zip_2_01');
    expect(lastInk.opensNewWorld, isTrue);
    expect(lastInk.nextWorld!.theme, 'metro');
    final last = catalog.slot('zip_2_02')!;
    expect(last.nextId, isNull);
    expect(last.opensNewWorld, isFalse);
  });

  test('an unknown id and an empty catalog', () {
    expect(LevelCatalog([ink]).slot('zip_9_01'), isNull);
    expect(LevelCatalog(const []).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/logic/level_catalog_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/domain/logic/level_catalog.dart`:

```dart
import '../entities/level_world.dart';

/// Where one level sits on the map.
class LevelSlot {
  const LevelSlot({
    required this.world,
    required this.entry,
    required this.number,
    required this.indexInWorld,
    this.nextId,
    this.nextWorld,
  });

  final LevelWorld world;
  final LevelEntry entry;

  /// "Level 27": counted across every world before this one, from 1.
  final int number;
  final int indexInWorld;

  /// The level after this one; null on the last published level.
  final String? nextId;

  /// The world [nextId] starts, when it starts a new one; null otherwise.
  final LevelWorld? nextWorld;

  bool get opensNewWorld => nextWorld != null;
}

/// A game's published worlds in order, with every level numbered and found
/// by id. Numbers are worked out here, never stored.
class LevelCatalog {
  LevelCatalog(List<LevelWorld> worlds)
    : worlds = List.unmodifiable(
        [...worlds]..sort((a, b) => a.order.compareTo(b.order)),
      ) {
    final flat = <(LevelWorld, LevelEntry, int)>[
      for (final world in this.worlds)
        for (var i = 0; i < world.levels.length; i++)
          (world, world.levels[i], i),
    ];
    for (var n = 0; n < flat.length; n++) {
      final (world, entry, index) = flat[n];
      final next = n + 1 < flat.length ? flat[n + 1] : null;
      _slots[entry.id] = LevelSlot(
        world: world,
        entry: entry,
        number: n + 1,
        indexInWorld: index,
        nextId: next?.$2.id,
        nextWorld: next != null && !identical(next.$1, world) ? next.$1 : null,
      );
    }
  }

  final List<LevelWorld> worlds;
  final Map<String, LevelSlot> _slots = {};

  bool get isEmpty => _slots.isEmpty;
  int get levelCount => _slots.length;

  LevelSlot? slot(String levelId) => _slots[levelId];
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/logic/level_catalog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/level_catalog.dart test/domain/logic/level_catalog_test.dart
git commit -m "feat(levels): number levels across worlds in LevelCatalog"
```

---

### Task 8: Repository interfaces

**Files:**
- Create: `lib/domain/repositories/level_world_repository.dart`
- Create: `lib/domain/repositories/level_progress_repository.dart`
- Test: `test/domain/repositories/level_clear_result_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';

void main() {
  test('a first clear is not an improvement', () {
    const result = LevelClearResult(
      runStars: 2,
      current: LevelRecord(stars: 2, bestSeconds: 30),
    );
    expect(result.firstClear, isTrue);
    expect(result.improved, isFalse);
  });

  test('more stars or a faster time improve the record', () {
    const stars = LevelClearResult(
      runStars: 3,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 3, bestSeconds: 30),
    );
    expect(stars.moreStars, isTrue);
    expect(stars.improved, isTrue);
    const time = LevelClearResult(
      runStars: 2,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 2, bestSeconds: 25),
    );
    expect(time.fasterTime, isTrue);
    expect(time.moreStars, isFalse);
    const same = LevelClearResult(
      runStars: 1,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 2, bestSeconds: 30),
    );
    expect(same.improved, isFalse);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/repositories/level_clear_result_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/domain/repositories/level_world_repository.dart`:

```dart
import '../logic/level_catalog.dart';

/// Levels could not be loaded from the server or from the cache.
class LevelsUnavailable implements Exception {
  const LevelsUnavailable(this.message);

  final String message;

  @override
  String toString() => 'LevelsUnavailable: $message';
}

/// The published worlds of a game's Levels.
abstract class LevelWorldRepository {
  /// Published worlds of [game] in order, from the server, else from the
  /// cache. Kept for the session; [refresh] reads again. Throws
  /// [LevelsUnavailable] when neither the server nor the cache has them.
  Future<LevelCatalog> catalog(String game, {bool refresh = false});
}
```

`lib/domain/repositories/level_progress_repository.dart`:

```dart
import '../entities/level_progress.dart';

/// What a cleared level run did to the level's record.
class LevelClearResult {
  const LevelClearResult({
    required this.runStars,
    required this.current,
    this.previous,
  });

  /// Stars this run earned on its own.
  final int runStars;

  /// The record before this run; null on a first clear.
  final LevelRecord? previous;

  /// The record after this run.
  final LevelRecord current;

  bool get firstClear => previous == null;
  bool get moreStars => previous != null && current.stars > previous!.stars;
  bool get fasterTime =>
      previous != null && current.bestSeconds < previous!.bestSeconds;

  /// A replay beat the record (a first clear has nothing to beat).
  bool get improved => moreStars || fasterTime;
}

/// The signed-in player's level progress on this device.
///
/// Read synchronously by the UI. Kept per account, so signing into another
/// account shows that account's map.
abstract class LevelProgressRepository {
  /// Fires after any write, including [restore].
  Stream<void> get changes;

  LevelProgress progress(String game);

  /// Keeps a cleared run of [levelId]; the record only ever improves.
  Future<LevelClearResult> record(
    String game,
    String levelId, {
    required int stars,
    required int seconds,
  });

  /// Replaces the progress with [merged] after a sync, without asking for
  /// another sync.
  Future<void> restore(String game, LevelProgress merged);

  /// Whether the progress differs from what was last pushed.
  bool needsPush(String game);

  Future<void> markPushed(String game, LevelProgress pushed);
}

/// The account's copy, `users/{uid}/level_progress/{game}`.
abstract class LevelProgressRemoteRepository {
  /// The doc's raw `levels` map, or null when there is no doc.
  Future<Object?> fetch(String uid, String game);

  Future<void> save(String uid, String game, LevelProgress progress);
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/repositories/level_clear_result_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/level_world_repository.dart lib/domain/repositories/level_progress_repository.dart test/domain/repositories/level_clear_result_test.dart
git commit -m "feat(levels): add level repository interfaces"
```

---

### Task 9: `LevelWorldRepositoryImpl` and its Firestore source

**Files:**
- Create: `lib/data/clients/level_worlds_source.dart`
- Create: `lib/data/repositories/level_world_repository_impl.dart`
- Test: `test/data/repositories/level_world_repository_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/clients/level_worlds_source.dart';
import 'package:winklo/data/repositories/level_world_repository_impl.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';

import '../../helpers/level_fixtures.dart';

class _FakeSource implements LevelWorldsSource {
  List<LevelWorldDoc>? server;
  List<LevelWorldDoc>? cache;
  final calls = <bool>[];

  @override
  Future<List<LevelWorldDoc>> published(
    String game, {
    required bool fromCache,
  }) async {
    calls.add(fromCache);
    final docs = fromCache ? cache : server;
    if (docs == null) throw StateError(fromCache ? 'no cache' : 'offline');
    return docs;
  }
}

LevelWorldDoc doc(int order, int count) =>
    (id: 'zip_$order', data: levelWorldJson(order, count));

void main() {
  late _FakeSource source;

  setUp(() => source = _FakeSource());

  test('reads the server first', () async {
    source.server = [doc(1, 3), doc(2, 2)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.levelCount, 5);
    expect(source.calls, [false]);
  });

  test('falls back to the cache when the server fails', () async {
    source.cache = [doc(1, 3)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.levelCount, 3);
    expect(source.calls, [false, true]);
  });

  test('is unavailable when neither has levels', () async {
    final repo = LevelWorldRepositoryImpl(source);
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    source.cache = [];
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    await expectLater(
      LevelWorldRepositoryImpl(null).catalog('zip'),
      throwsA(isA<LevelsUnavailable>()),
    );
  });

  test('no published worlds on the server is an empty catalog', () async {
    source.server = [];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.isEmpty, isTrue);
  });

  test('stops at the first world that does not parse', () async {
    source.server = [
      doc(1, 2),
      (id: 'zip_2', data: <String, dynamic>{'order': 2}),
      doc(3, 2),
    ];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.worlds.map((w) => w.id), ['zip_1']);
  });

  test('stops at a world that repeats an earlier level id', () async {
    final repeat = levelWorldJson(2, 1)
      ..['levels'] = [levelBoardJson('zip_1_02')];
    source.server = [doc(1, 2), (id: 'zip_2', data: repeat), doc(3, 2)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.worlds.map((w) => w.id), ['zip_1']);
  });

  test('keeps the catalog for the session; refresh reads again', () async {
    source.server = [doc(1, 2)];
    final repo = LevelWorldRepositoryImpl(source);
    await repo.catalog('zip');
    await repo.catalog('zip');
    expect(source.calls, [false]);
    await repo.catalog('zip', refresh: true);
    expect(source.calls, [false, false]);
  });

  test('a failure is not kept: the next call tries again', () async {
    final repo = LevelWorldRepositoryImpl(source);
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    source.server = [doc(1, 2)];
    final catalog = await repo.catalog('zip');
    expect(catalog.levelCount, 2);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/data/repositories/level_world_repository_impl_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/data/clients/level_worlds_source.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

typedef LevelWorldDoc = ({String id, Map<String, dynamic> data});

/// Reads published `level_worlds` docs: Firestore in the app, a fake in
/// tests.
abstract class LevelWorldsSource {
  Future<List<LevelWorldDoc>> published(String game, {required bool fromCache});
}

class FirestoreLevelWorldsSource implements LevelWorldsSource {
  FirestoreLevelWorldsSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// The rules let players list only published worlds, so the query must
  /// filter on `published`. Needs the (game, published, order) index.
  @override
  Future<List<LevelWorldDoc>> published(
    String game, {
    required bool fromCache,
  }) async {
    final snap = await _firestore
        .collection('level_worlds')
        .where('game', isEqualTo: game)
        .where('published', isEqualTo: true)
        .orderBy('order')
        .get(GetOptions(source: fromCache ? Source.cache : Source.server));
    return [for (final d in snap.docs) (id: d.id, data: d.data())];
  }
}
```

`lib/data/repositories/level_world_repository_impl.dart`:

```dart
import '../../domain/entities/level_world.dart';
import '../../domain/logic/level_catalog.dart';
import '../../domain/repositories/level_world_repository.dart';
import '../clients/level_worlds_source.dart';

class LevelWorldRepositoryImpl implements LevelWorldRepository {
  /// [source] is null while Firebase isn't ready.
  LevelWorldRepositoryImpl(this._source);

  final LevelWorldsSource? _source;
  final Map<String, Future<LevelCatalog>> _loaded = {};

  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) {
    if (refresh) _loaded.remove(game);
    final kept = _loaded[game];
    if (kept != null) return kept;
    final future = _load(game);
    _loaded[game] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_loaded[game], future)) _loaded.remove(game);
      },
    );
    return future;
  }

  Future<LevelCatalog> _load(String game) async {
    final source = _source;
    if (source == null) throw const LevelsUnavailable('Firebase is not ready');
    List<LevelWorldDoc> docs;
    try {
      docs = await source.published(game, fromCache: false);
    } catch (_) {
      try {
        docs = await source.published(game, fromCache: true);
      } catch (e) {
        throw LevelsUnavailable('Not on the server or in the cache: $e');
      }
      if (docs.isEmpty) throw const LevelsUnavailable('Nothing cached yet');
    }
    return LevelCatalog(_parse(docs));
  }

  /// Worlds in order, stopping at the first one that doesn't parse or that
  /// repeats a level id of an earlier world, so a bad world can't shift the
  /// numbers of the levels after it or share progress with another board.
  static List<LevelWorld> _parse(List<LevelWorldDoc> docs) {
    final worlds = <LevelWorld>[];
    final seen = <String>{};
    for (final doc in docs) {
      final LevelWorld world;
      try {
        world = LevelWorld.fromJson(doc.id, doc.data);
      } on FormatException {
        break;
      }
      if (!world.levels.every((level) => seen.add(level.id))) break;
      worlds.add(world);
    }
    return worlds;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/repositories/level_world_repository_impl_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/clients/level_worlds_source.dart lib/data/repositories/level_world_repository_impl.dart test/data/repositories/level_world_repository_impl_test.dart
git commit -m "feat(levels): load published worlds, server then cache"
```

---

### Task 10: Level progress store and its Firestore mirror

**Files:**
- Create: `lib/data/repositories/level_progress_repository_impl.dart`
- Create: `lib/data/repositories/level_progress_remote_repository_impl.dart`
- Test: `test/data/repositories/level_progress_repository_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/level_progress.dart';

void main() {
  late SharedPreferences prefs;
  late String? uid;
  late int syncAsks;
  late LevelProgressRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    uid = 'u1';
    syncAsks = 0;
    repo = LevelProgressRepositoryImpl(
      prefs,
      currentUid: () => uid,
      onChanged: () => syncAsks++,
    );
  });

  tearDown(() => repo.dispose());

  test('a first clear is recorded and asks for a sync', () async {
    final result = await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    expect(result.firstClear, isTrue);
    expect(result.runStars, 2);
    expect(repo.progress('zip')['zip_1_01'], const LevelRecord(stars: 2, bestSeconds: 30));
    expect(syncAsks, 1);
  });

  test('a replay keeps the best of both', () async {
    await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    final worse = await repo.record('zip', 'zip_1_01', stars: 1, seconds: 45);
    expect(worse.improved, isFalse);
    expect(worse.current, const LevelRecord(stars: 2, bestSeconds: 30));
    final better = await repo.record('zip', 'zip_1_01', stars: 3, seconds: 20);
    expect(better.moreStars, isTrue);
    expect(better.previous, const LevelRecord(stars: 2, bestSeconds: 30));
  });

  test('each account has its own map', () async {
    await repo.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    uid = 'u2';
    expect(repo.progress('zip').records, isEmpty);
    uid = 'u1';
    expect(repo.progress('zip').totalStars, 3);
  });

  test('restore fires changes but does not ask for a sync', () async {
    final changes = <void>[];
    final sub = repo.changes.listen(changes.add);
    await repo.restore(
      'zip',
      const LevelProgress({'zip_1_02': LevelRecord(stars: 1, bestSeconds: 9)}),
    );
    await pumpEventQueue();
    expect(changes, hasLength(1));
    expect(syncAsks, 0);
    expect(repo.progress('zip').isCleared('zip_1_02'), isTrue);
    await sub.cancel();
  });

  test('needsPush until what is stored has been pushed', () async {
    expect(repo.needsPush('zip'), isFalse);
    await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    expect(repo.needsPush('zip'), isTrue);
    await repo.markPushed('zip', repo.progress('zip'));
    expect(repo.needsPush('zip'), isFalse);
  });

  test('a corrupt stored value reads as empty progress', () async {
    await prefs.setString('level_progress_u1_zip', '{not json');
    expect(repo.progress('zip').records, isEmpty);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/data/repositories/level_progress_repository_impl_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/data/repositories/level_progress_repository_impl.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/repositories/level_progress_repository.dart';

/// SharedPreferences store for [LevelProgressRepository], one JSON value per
/// account and game (`level_progress_<uid>_<game>`), plus what was last
/// pushed (`level_progress_pushed_<uid>_<game>`).
class LevelProgressRepositoryImpl implements LevelProgressRepository {
  LevelProgressRepositoryImpl(
    this._prefs, {
    required String? Function() currentUid,
    void Function()? onChanged,
  }) : _currentUid = currentUid,
       _onChanged = onChanged;

  final SharedPreferences _prefs;
  final String? Function() _currentUid;

  /// Asks for a push-only progress sync (`ProgressChangeSignal.notify`).
  final void Function()? _onChanged;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();

  String get _owner => _currentUid() ?? 'signed_out';
  String _key(String game) => 'level_progress_${_owner}_$game';
  String _pushedKey(String game) => 'level_progress_pushed_${_owner}_$game';

  LevelProgress _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return LevelProgress.empty;
    try {
      return LevelProgress.parse(jsonDecode(raw)).progress;
    } on FormatException {
      return LevelProgress.empty;
    }
  }

  Future<void> _write(String key, LevelProgress progress) =>
      _prefs.setString(key, jsonEncode(progress.toJson()));

  @override
  LevelProgress progress(String game) => _read(_key(game));

  @override
  Future<LevelClearResult> record(
    String game,
    String levelId, {
    required int stars,
    required int seconds,
  }) async {
    final before = progress(game);
    final after = before.withRun(levelId, stars: stars, seconds: seconds);
    await _write(_key(game), after);
    _fire(askSync: true);
    return LevelClearResult(
      runStars: stars,
      previous: before[levelId],
      current: after[levelId]!,
    );
  }

  @override
  Future<void> restore(String game, LevelProgress merged) async {
    await _write(_key(game), merged);
    _fire(askSync: false);
  }

  @override
  bool needsPush(String game) =>
      !progress(game).sameAs(_read(_pushedKey(game)));

  @override
  Future<void> markPushed(String game, LevelProgress pushed) =>
      _write(_pushedKey(game), pushed);

  void _fire({required bool askSync}) {
    if (!_changes.isClosed) _changes.add(null);
    if (askSync) _onChanged?.call();
  }
}
```

`lib/data/repositories/level_progress_remote_repository_impl.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/repositories/level_progress_remote_repository.dart';

/// `users/{uid}/level_progress/{game}`: `{levels, updatedAt}`. The rules
/// accept only those two fields, with `updatedAt` the server's time.
class LevelProgressRemoteRepositoryImpl
    implements LevelProgressRemoteRepository {
  LevelProgressRemoteRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String game) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('level_progress')
          .doc(game);

  @override
  Future<Object?> fetch(String uid, String game) async {
    final snap = await _doc(uid, game).get(
      const GetOptions(source: Source.server),
    );
    return snap.data()?['levels'];
  }

  @override
  Future<void> save(String uid, String game, LevelProgress progress) =>
      _doc(uid, game).set({
        'levels': progress.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/repositories/level_progress_repository_impl_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/level_progress_repository_impl.dart lib/data/repositories/level_progress_remote_repository_impl.dart test/data/repositories/level_progress_repository_impl_test.dart
git commit -m "feat(levels): store level progress per account"
```

---

### Task 11: `level_cleared` analytics event

**Files:**
- Modify: `lib/domain/repositories/analytics_repository.dart` (after `logGameCompleted`)
- Modify: `lib/data/repositories/firebase_analytics_repository_impl.dart` (after `logGameCompleted`)
- Modify: `test/helpers/mock_analytics_repository.dart` (`stubAnalytics`)

- [ ] **Step 1: Add to the interface**

After the `logGameCompleted` declaration:

```dart
  /// A level of the Levels map cleared: which one, the stars this run
  /// earned, whether it was the level's first clear, and whether a replay
  /// improved the level's record.
  Future<void> logLevelCleared({
    required String gameId,
    required String levelId,
    required int world,
    required int number,
    required int stars,
    required bool firstClear,
    required bool improved,
  });
```

- [ ] **Step 2: Implement it**

In `FirebaseAnalyticsRepositoryImpl`, after `logGameCompleted`:

```dart
  @override
  Future<void> logLevelCleared({
    required String gameId,
    required String levelId,
    required int world,
    required int number,
    required int stars,
    required bool firstClear,
    required bool improved,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'level_cleared',
        parameters: <String, Object>{
          'game_id': gameId,
          'level_id': levelId,
          'world': world,
          'level_number': number,
          'stars': stars,
          'first_clear': _flag(firstClear),
          'improved': _flag(improved),
        },
      ),
    );
  }
```

- [ ] **Step 3: Stub it for tests**

In `stubAnalytics`, after the `logGameCompleted` stub:

```dart
  when(
    () => analytics.logLevelCleared(
      gameId: any(named: 'gameId'),
      levelId: any(named: 'levelId'),
      world: any(named: 'world'),
      number: any(named: 'number'),
      stars: any(named: 'stars'),
      firstClear: any(named: 'firstClear'),
      improved: any(named: 'improved'),
    ),
  ).thenAnswer((_) async {});
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze`
Expected: no warnings or errors (every other `AnalyticsRepository` in tests is a mocktail `Mock`).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/analytics_repository.dart lib/data/repositories/firebase_analytics_repository_impl.dart test/helpers/mock_analytics_repository.dart
git commit -m "feat(levels): log level_cleared"
```

---

### Task 12: `RecordLevelClear`

**Files:**
- Create: `lib/domain/usecases/record_level_clear.dart`
- Test: `test/domain/usecases/record_level_clear_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';

import '../../helpers/level_fixtures.dart';
import '../../helpers/mock_analytics_repository.dart';

void main() {
  late LevelProgressRepositoryImpl progress;
  late MockAnalyticsRepository analytics;
  late RecordLevelClear record;
  final catalog = LevelCatalog([levelWorld(1, 3), levelWorld(2, 2)]);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    record = RecordLevelClear(progress, analytics);
  });

  test('scores the run, keeps it and logs it', () async {
    final slot = catalog.slot('zip_2_01')!;
    final result = await record(
      game: 'zip',
      slot: slot,
      usedHints: false,
      seconds: 25,
    );
    expect(result.runStars, 3);
    expect(progress.progress('zip')['zip_2_01']!.stars, 3);
    verify(
      () => analytics.logLevelCleared(
        gameId: 'zip',
        levelId: 'zip_2_01',
        world: 2,
        number: 4,
        stars: 3,
        firstClear: true,
        improved: false,
      ),
    ).called(1);
  });

  test('a hinted, slow run earns one star', () async {
    final result = await record(
      game: 'zip',
      slot: catalog.slot('zip_1_01')!,
      usedHints: true,
      seconds: 90,
    );
    expect(result.runStars, 1);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/usecases/record_level_clear_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/domain/usecases/record_level_clear.dart`:

```dart
import '../logic/level_catalog.dart';
import '../logic/level_stars.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/level_progress_repository.dart';

/// Scores a cleared level run, keeps it in the player's progress and logs
/// `level_cleared`.
class RecordLevelClear {
  RecordLevelClear(this._progress, this._analytics);

  final LevelProgressRepository _progress;
  final AnalyticsRepository _analytics;

  Future<LevelClearResult> call({
    required String game,
    required LevelSlot slot,
    required bool usedHints,
    required int seconds,
  }) async {
    final stars = starsFor(
      usedHints: usedHints,
      seconds: seconds,
      targetSeconds: slot.entry.targetSeconds,
    );
    final result = await _progress.record(
      game,
      slot.entry.id,
      stars: stars,
      seconds: seconds,
    );
    await _analytics.logLevelCleared(
      gameId: game,
      levelId: slot.entry.id,
      world: slot.world.order,
      number: slot.number,
      stars: stars,
      firstClear: result.firstClear,
      improved: result.improved,
    );
    return result;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/domain/usecases/record_level_clear_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/record_level_clear.dart test/domain/usecases/record_level_clear_test.dart
git commit -m "feat(levels): record a level clear"
```

---

### Task 13: `SyncLevelProgress` and the lifecycle hook

**Files:**
- Create: `lib/domain/usecases/sync_level_progress.dart`
- Modify: `lib/core/lifecycle/progress_sync_lifecycle.dart`
- Modify: `lib/app.dart` (`_ensureProgressSyncLifecycle`)
- Test: `test/domain/usecases/sync_level_progress_test.dart`, `test/core/lifecycle/progress_sync_lifecycle_test.dart` (append)

- [ ] **Step 1: Write the failing use-case test**

`test/domain/usecases/sync_level_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_remote_repository.dart';
import 'package:winklo/domain/usecases/sync_level_progress.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MemoryRemote implements LevelProgressRemoteRepository {
  final docs = <String, Object?>{};
  int fetches = 0;
  int saves = 0;
  void Function()? onFetch;

  @override
  Future<Object?> fetch(String uid, String game) async {
    fetches++;
    onFetch?.call();
    return docs['$uid/$game'];
  }

  @override
  Future<void> save(String uid, String game, LevelProgress progress) async {
    saves++;
    docs['$uid/$game'] = progress.toJson();
  }
}

void main() {
  late _MockAuth auth;
  late AppUser? user;
  late _MemoryRemote remote;
  late LevelProgressRepositoryImpl local;
  late SyncLevelProgress sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = _MockAuth();
    user = const AppUser(uid: 'u1', displayName: 'A');
    when(() => auth.currentUser).thenAnswer((_) => user);
    remote = _MemoryRemote();
    local = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => user?.uid,
    );
    sync = SyncLevelProgress(auth: auth, local: local, remote: remote);
  });

  test('a pull merges both copies and writes the result to both', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 3, 'bestSeconds': 40},
      'zip_1_02': {'stars': 1, 'bestSeconds': 60},
    };
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: true);
    expect(
      local.progress('zip')['zip_1_01'],
      const LevelRecord(stars: 3, bestSeconds: 20),
    );
    expect(local.progress('zip').isCleared('zip_1_02'), isTrue);
    expect(
      LevelProgress.parse(remote.docs['u1/zip']).progress.sameAs(local.progress('zip')),
      isTrue,
    );
    expect(local.needsPush('zip'), isFalse);
  });

  test('a push-only run does nothing when nothing changed', () async {
    await sync(pull: false);
    expect(remote.fetches, 0);
  });

  test('a push-only run pushes a new clear', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: false);
    expect(remote.saves, 1);
    expect(local.needsPush('zip'), isFalse);
  });

  test('an identical remote copy is not written again', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 2, 'bestSeconds': 20},
    };
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await sync(pull: true);
    expect(remote.saves, 0);
  });

  test('invalid remote entries are dropped and the doc rewritten', () async {
    remote.docs['u1/zip'] = {
      'zip_1_01': {'stars': 9, 'bestSeconds': 20},
    };
    await sync(pull: true);
    expect(remote.saves, 1);
    expect(local.progress('zip').records, isEmpty);
  });

  test('signed out: nothing happens', () async {
    user = null;
    await sync(pull: true);
    expect(remote.fetches, 0);
  });

  test('an account switch mid-sync leaves both copies alone', () async {
    await local.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    remote.onFetch = () => user = const AppUser(uid: 'u2', displayName: 'B');
    await sync(pull: true);
    expect(remote.saves, 0);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/usecases/sync_level_progress_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement the use case**

`lib/domain/usecases/sync_level_progress.dart`:

```dart
import '../entities/level_progress.dart';
import '../game_ids.dart';
import '../repositories/auth_repository.dart';
import '../repositories/level_progress_remote_repository.dart';
import '../repositories/level_progress_repository.dart';

/// Reconciles this device's level progress with the account's copy.
///
/// Per game: read the remote doc, merge (most stars, fastest time), keep the
/// result locally, and write it back only when the remote copy differs. A
/// push-only run ([pull] false) skips games with nothing new to push. The
/// merge can't conflict, so the order of devices never matters.
class SyncLevelProgress {
  SyncLevelProgress({
    required AuthRepository auth,
    required LevelProgressRepository local,
    required LevelProgressRemoteRepository remote,
    bool Function()? isRemoteAvailable,
  }) : _auth = auth,
       _local = local,
       _remote = remote,
       _isRemoteAvailable = isRemoteAvailable ?? _always;

  /// Games with Levels.
  static const gameIds = [GameIds.zip];

  final AuthRepository _auth;
  final LevelProgressRepository _local;
  final LevelProgressRemoteRepository _remote;
  final bool Function() _isRemoteAvailable;

  static bool _always() => true;

  Future<void> call({required bool pull}) async {
    if (!_isRemoteAvailable()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    for (final game in gameIds) {
      if (!pull && !_local.needsPush(game)) continue;
      final remote = LevelProgress.parse(await _remote.fetch(uid, game));
      // Another account signed in while we read: leave both copies alone.
      if (_auth.currentUser?.uid != uid) return;
      final local = _local.progress(game);
      final merged = local.merge(remote.progress);
      if (!merged.sameAs(local)) await _local.restore(game, merged);
      if (!merged.sameAs(remote.progress) || remote.dropped > 0) {
        await _remote.save(uid, game, merged);
      }
      // The local store is keyed by whoever is signed in now.
      if (_auth.currentUser?.uid != uid) return;
      await _local.markPushed(game, merged);
    }
  }
}
```

- [ ] **Step 4: Run the use-case test**

Run: `flutter test test/domain/usecases/sync_level_progress_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Write the failing lifecycle test**

Append inside `main()` of `test/core/lifecycle/progress_sync_lifecycle_test.dart`:

```dart
  group('level progress', () {
    ProgressSyncLifecycle withLevels(
      Future<void> Function({required bool pull}) syncLevels,
    ) => ProgressSyncLifecycle(
      syncProgress: sync,
      authRepository: auth,
      localChanges: signal.changes,
      now: () => now,
      createTimer: (duration, callback) {
        final timer = _FakeTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
      syncLevels: syncLevels,
    );

    test('syncs after every progress sync, full or push-only', () async {
      final levelPulls = <bool>[];
      final lifecycle = withLevels(
        ({required bool pull}) async => levelPulls.add(pull),
      );
      lifecycle.start();
      await pumpEventQueue();
      expect(pulls, [true]);
      expect(levelPulls, [true]);
      signal.notify();
      await pumpEventQueue();
      timers.last.fire();
      await pumpEventQueue();
      expect(levelPulls, [true, false]);
      lifecycle.dispose();
    });

    test('a failing level sync never breaks the lifecycle', () async {
      final lifecycle = withLevels(
        ({required bool pull}) async => throw StateError('offline'),
      );
      lifecycle.start();
      await pumpEventQueue();
      expect(pulls, [true]);
      lifecycle.dispose();
    });
  });
```

Run: `flutter test test/core/lifecycle/progress_sync_lifecycle_test.dart`
Expected: compile error (`syncLevels` isn't a parameter).

- [ ] **Step 6: Implement the hook**

In `ProgressSyncLifecycle`'s constructor, add `this._syncLevels,` after `required this._localChanges,`. Add the field after `final Stream<void> _localChanges;`:

```dart
  /// Level progress sync, run after each progress sync with the same `pull`.
  final Future<void> Function({required bool pull})? _syncLevels;
```

Replace `_run` with:

```dart
  Future<void> _run({required bool pull}) async {
    try {
      final result = await _syncProgress(pull: pull);
      if (result.localChanged && _started && !_restored.isClosed) {
        _restored.add(null);
      }
    } catch (e) {
      // SyncProgress reports its own failures; never crash the app here.
      debugPrint('Progress sync failed: $e');
    }
    final syncLevels = _syncLevels;
    if (syncLevels == null) return;
    try {
      await syncLevels(pull: pull);
    } catch (e) {
      // Retried on the next run; the local copy is the source until then.
      debugPrint('Level progress sync failed: $e');
    }
  }
```

In `lib/app.dart`, `_ensureProgressSyncLifecycle`, add to the constructor call:

```dart
      syncLevels: context.read<SyncLevelProgress>().call,
```

and import `domain/usecases/sync_level_progress.dart` (relative to `lib/app.dart`: `'domain/usecases/sync_level_progress.dart'`). The provider is added in Task 16.

- [ ] **Step 7: Run the lifecycle tests**

Run: `flutter test test/core/lifecycle/progress_sync_lifecycle_test.dart`
Expected: PASS, including the existing tests.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/usecases/sync_level_progress.dart lib/core/lifecycle/progress_sync_lifecycle.dart lib/app.dart test/domain/usecases/sync_level_progress_test.dart test/core/lifecycle/progress_sync_lifecycle_test.dart
git commit -m "feat(levels): sync level progress after each progress sync"
```

---

### Task 14: Results arguments for a level

**Files:**
- Modify: `lib/features/results/results_args.dart` (`LocalResultKind`, `LocalResultInfo`)
- Test: `test/features/results/level_result_info_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_stars.dart';
import 'package:winklo/features/results/results_args.dart';

void main() {
  test('the goal ticks agree with starsFor in every case', () {
    for (final hints in [false, true]) {
      for (final target in <int?>[null, 0, 30]) {
        for (final seconds in [0, 20, 30, 31]) {
          final stars = starsFor(
            usedHints: hints,
            seconds: seconds,
            targetSeconds: target,
          );
          final info = LevelResultInfo(
            runStars: stars,
            bestStars: stars,
            usedHints: hints,
            targetSeconds: target != null && target > 0 ? target : null,
          );
          final expected =
              target != null && target > 0 && seconds >= 1 && seconds <= target;
          expect(
            info.timeEarned,
            expected,
            reason: 'hints $hints, target $target, seconds $seconds',
          );
          expect(info.noHintsEarned, !hints);
        }
      }
    }
  });

  test('which goals the run earned, from its stars', () {
    const clean = LevelResultInfo(runStars: 3, bestStars: 3, usedHints: false, targetSeconds: 30);
    expect(clean.noHintsEarned, isTrue);
    expect(clean.timeEarned, isTrue);
    const slowClean = LevelResultInfo(runStars: 2, bestStars: 2, usedHints: false, targetSeconds: 30);
    expect(slowClean.timeEarned, isFalse);
    const fastHinted = LevelResultInfo(runStars: 2, bestStars: 2, usedHints: true, targetSeconds: 30);
    expect(fastHinted.noHintsEarned, isFalse);
    expect(fastHinted.timeEarned, isTrue);
    const noTarget = LevelResultInfo(runStars: 2, bestStars: 2, usedHints: false);
    expect(noTarget.timeEarned, isFalse);
  });

  test('more stars than before, and a new world next', () {
    const info = LevelResultInfo(
      runStars: 3,
      bestStars: 3,
      previousStars: 2,
      usedHints: false,
      nextLocation: '/zip?mode=level&level=zip_2_01',
      nextWorldTheme: 'metro',
    );
    expect(info.moreStars, isTrue);
    expect(info.opensNewWorld, isTrue);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/results/level_result_info_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

In `results_args.dart`, change the enum to:

```dart
enum LocalResultKind { archive, practice, bonus, level }
```

In `LocalResultInfo`, add the constructor parameter `this.level,` after `this.againLocation,` and the field after `againLocation`:

```dart
  /// Set for a level run: its stars and what comes next.
  final LevelResultInfo? level;
```

Append to the file:

```dart
/// What Results shows for a cleared level.
class LevelResultInfo {
  const LevelResultInfo({
    required this.runStars,
    required this.bestStars,
    required this.usedHints,
    this.previousStars,
    this.targetSeconds,
    this.nextLocation,
    this.nextWorldTheme,
  });

  /// Stars this run earned.
  final int runStars;

  /// The level's stars after this run.
  final int bestStars;

  /// The level's stars before this run; null on a first clear.
  final int? previousStars;
  final bool usedHints;

  /// Null when the level has no time goal.
  final int? targetSeconds;

  /// The next level's route; null on the last published level.
  final String? nextLocation;

  /// The next world's theme when the next level starts a new world.
  final String? nextWorldTheme;

  bool get noHintsEarned => !usedHints;

  /// The run's stars are 1 + no hints + time, so the time star is whatever
  /// the hints don't explain.
  bool get timeEarned =>
      targetSeconds != null && runStars == (usedHints ? 2 : 3);

  bool get moreStars => previousStars != null && bestStars > previousStars!;
  bool get opensNewWorld => nextWorldTheme != null;
}
```

- [ ] **Step 4: Run the test and analyze**

Run: `flutter test test/features/results/level_result_info_test.dart && flutter analyze`
Expected: PASS. If analyze reports a `non_exhaustive_switch` on `LocalResultKind`, add `case LocalResultKind.level:` to the `practice` branch.

- [ ] **Step 5: Commit**

```bash
git add lib/features/results/results_args.dart test/features/results/level_result_info_test.dart
git commit -m "feat(levels): Results arguments for a level"
```

---

### Task 15: ZipBloc level mode

**Files:**
- Modify: `lib/features/zip/bloc/zip_bloc.dart`
- Test: `test/features/zip/bloc/zip_bloc_level_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_board.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';

import '../../../helpers/level_fixtures.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockGetClearBoard extends Mock implements GetClearBoard {}

class _Worlds implements LevelWorldRepository {
  _Worlds(this.value);
  final LevelCatalog value;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      value;
}

class _OfflineWorlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      throw const LevelsUnavailable('offline');
}

class _MemoryInProgressRuns implements InProgressRunRepository {
  final Map<String, InProgressRun> runs = {};
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async => runs['${gameId}_$playId'];
  @override
  Future<void> save(InProgressRun run) async =>
      runs['${run.gameId}_${run.playId}'] = run;
  @override
  Future<void> clear({required String gameId, required String playId}) async =>
      runs.remove('${gameId}_$playId');
}

void main() {
  final catalog = LevelCatalog([levelWorld(1, 2), levelWorld(2, 1, theme: 'metro')]);
  late MockAnalyticsRepository analytics;
  late _MockRecordDailyClear recordDailyClear;
  late _MockSubmitScore submitScore;
  late LevelProgressRepositoryImpl progress;
  late _MemoryInProgressRuns drafts;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    recordDailyClear = _MockRecordDailyClear();
    submitScore = _MockSubmitScore();
    progress = LevelProgressRepositoryImpl(prefs, currentUid: () => 'u1');
    drafts = _MemoryInProgressRuns();
    now = DateTime(2026, 10, 31, 9);
  });

  ZipBloc build(String levelId) => ZipBloc(
    mode: PlayMode.level(levelId),
    levelWorlds: _Worlds(catalog),
    recordLevelClear: RecordLevelClear(progress, analytics),
    inProgressRuns: drafts,
    submitScore: submitScore,
    submitLeaderboardTime: _MockSubmitLeaderboardTime(),
    recordDailyClear: recordDailyClear,
    getBestPoints: _MockGetBestPoints(),
    getBestTimeSeconds: _MockGetBestTimeSeconds(),
    isNewPersonalBest: _MockIsNewPersonalBest(),
    getClearBoard: _MockGetClearBoard(),
    analytics: analytics,
    hintQuota: UnlimitedHintQuotaRepositoryImpl(),
    clockNow: () => now,
    wait: (_) async {},
    fetchDailyLevel: (date, {period = const Duration(days: 1)}) =>
        throw StateError('a level run never reads a daily'),
  );

  Future<ZipState> ready(ZipBloc bloc) => bloc.stream.firstWhere(
    (s) => s.status == ZipStatus.ready || s.status == ZipStatus.failed,
  );

  Future<ZipState> finish(ZipBloc bloc) async {
    bloc.add(ZipEvent.pathChanged(path: bloc.state.level.solution));
    bloc.add(const ZipEvent.completed());
    return bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);
  }

  test('loads the board from the catalog', () async {
    final bloc = build('zip_1_02');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.ready);
    expect(state.level.id, 'zip_1_02');
    expect(bloc.levelSlot!.number, 2);
    expect(bloc.playId, 'level_zip_1_02');
    await bloc.close();
  });

  test('a clean, fast clear earns three stars and offers the next level', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    final args = done.resultsExtra!;
    expect(args.title, 'Level 1 cleared');
    expect(args.local!.kind, LocalResultKind.level);
    expect(args.local!.label, 'Level 1 · Ink');
    expect(args.local!.againLocation, '/zip?mode=level&level=zip_1_01');
    expect(args.local!.level!.runStars, 3);
    expect(args.local!.level!.nextLocation, '/zip?mode=level&level=zip_1_02');
    expect(args.local!.level!.opensNewWorld, isFalse);
    expect(progress.progress('zip')['zip_1_01']!.stars, 3);
    verifyNever(
      () => recordDailyClear(
        gameId: any(named: 'gameId'),
        dateId: any(named: 'dateId'),
      ),
    );
    verifyZeroInteractions(submitScore);
    await bloc.close();
  });

  test('a hint adds no time and costs the no-hints star', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    bloc.add(const ZipEvent.hint());
    await bloc.stream.firstWhere((s) => s.hintsUsed == 1);
    now = now.add(const Duration(seconds: 10));
    final done = await finish(bloc);
    expect(done.timeSeconds, 10);
    expect(done.resultsExtra!.hintPenaltySeconds, 0);
    expect(done.resultsExtra!.local!.level!.runStars, 2);
    expect(done.resultsExtra!.local!.level!.usedHints, isTrue);
    await bloc.close();
  });

  test("a world's last level opens the next world", () async {
    final bloc = build('zip_1_02');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    final level = done.resultsExtra!.local!.level!;
    expect(level.nextLocation, '/zip?mode=level&level=zip_2_01');
    expect(level.nextWorldTheme, 'metro');
    await bloc.close();
  });

  test('the last published level has no next level', () async {
    final bloc = build('zip_2_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    expect(done.resultsExtra!.local!.level!.nextLocation, isNull);
    await bloc.close();
  });

  test('an unknown level fails and drops its draft', () async {
    drafts.runs['zip_level_zip_9_01'] = InProgressRun(
      gameId: 'zip',
      playId: 'level_zip_9_01',
      elapsedMs: 1000,
      board: const {'path': []},
    );
    final bloc = build('zip_9_01');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.failed);
    expect(state.errorMessage, 'Could not load this level.');
    expect(drafts.runs, isEmpty);
    await bloc.close();
  });

  test('levels being unavailable keeps the draft', () async {
    drafts.runs['zip_level_zip_1_01'] = InProgressRun(
      gameId: 'zip',
      playId: 'level_zip_1_01',
      elapsedMs: 1000,
      board: const {'path': []},
    );
    final bloc = ZipBloc(
      mode: const PlayMode.level('zip_1_01'),
      levelWorlds: _OfflineWorlds(),
      recordLevelClear: RecordLevelClear(progress, analytics),
      inProgressRuns: drafts,
      submitScore: submitScore,
      submitLeaderboardTime: _MockSubmitLeaderboardTime(),
      recordDailyClear: recordDailyClear,
      getBestPoints: _MockGetBestPoints(),
      getBestTimeSeconds: _MockGetBestTimeSeconds(),
      isNewPersonalBest: _MockIsNewPersonalBest(),
      getClearBoard: _MockGetClearBoard(),
      analytics: analytics,
      hintQuota: UnlimitedHintQuotaRepositoryImpl(),
      clockNow: () => now,
      wait: (_) async {},
      fetchDailyLevel: (date, {period = const Duration(days: 1)}) =>
          throw StateError('a level run never reads a daily'),
    );
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.failed);
    expect(drafts.runs['zip_level_zip_1_01'], isNotNull);
    await bloc.close();
  });

  test('a run left halfway resumes from its draft', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 3)));
    await bloc.stream.firstWhere((s) => s.path.length == 3);
    expect(drafts.runs['zip_level_zip_1_01'], isNotNull);
    await bloc.close();

    final again = build('zip_1_01');
    again.add(const ZipEvent.started());
    final resumed = await ready(again);
    expect(resumed.path.length, 3);
    await again.close();
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/zip/bloc/zip_bloc_level_test.dart`
Expected: compile errors (`levelWorlds`, `recordLevelClear`, `levelSlot` unknown).

- [ ] **Step 3: Implement**

In `zip_bloc.dart`:

(a) Imports, next to the other domain imports:

```dart
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../../../domain/usecases/record_level_clear.dart';
```

(b) Constructor parameters, after `this.modeRecords,`:

```dart
    this.levelWorlds,
    this.recordLevelClear,
```

(c) Replace the second assert:

```dart
       assert(
         mode == PlayMode.daily || modeRecords != null,
         'Archive and practice runs keep their bests in modeRecords',
       ),
```

with:

```dart
       assert(
         mode.isDaily || mode.isLevel || modeRecords != null,
         'Archive and practice runs keep their bests in modeRecords',
       ),
       assert(
         !mode.isLevel || (levelWorlds != null && recordLevelClear != null),
         'Level runs need levelWorlds and recordLevelClear',
       ),
```

(d) Fields, after `final PlayModeRecordRepository? modeRecords;`:

```dart
  /// Where level runs find their board; required for level runs.
  final LevelWorldRepository? levelWorlds;

  /// Keeps a level clear's stars; required for level runs.
  final RecordLevelClear? recordLevelClear;

  /// The level on screen and where it sits on the map; null outside level
  /// runs and until the board has loaded.
  LevelSlot? get levelSlot => _levelSlot;
  LevelSlot? _levelSlot;
```

(e) In `_startOffDaily`, change the placeholder id

```dart
          id: mode.isArchive ? 'daily_$runId' : 'practice',
```

to

```dart
          id: mode.isArchive
              ? 'daily_$runId'
              : mode.isLevel
              ? mode.levelId!
              : 'practice',
```

(f) In `_startOffDaily`, replace the board-loading `try`/`catch`:

```dart
    try {
      if (mode.isArchive) {
        // Past days are always live and read by id, like the dailies.
        level = await fetchDailyLevel(day, period: PlayPeriod.daily);
      } else {
        final saved = draft?.board['seed'];
        final seed = saved is num ? saved.toInt() : _newPracticeSeed();
        _practiceSeed = seed;
        level = practiceLevel(seed);
      }
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: ZipStatus.failed,
          errorMessage: AppStrings.zipFailed,
        ),
      );
      return;
    }
```

with:

```dart
    try {
      if (mode.isArchive) {
        // Past days are always live and read by id, like the dailies.
        level = await fetchDailyLevel(day, period: PlayPeriod.daily);
      } else if (mode.isLevel) {
        final catalog = await levelWorlds!.catalog(GameIds.zip);
        final slot = catalog.slot(mode.levelId!);
        if (slot == null) {
          // A level that no longer exists can't be resumed either. Being
          // offline (LevelsUnavailable) keeps the draft for later.
          await inProgressRuns.clear(gameId: GameIds.zip, playId: runId);
          throw StateError('No level ${mode.levelId}');
        }
        level = slot.entry.zipLevel;
        _levelSlot = slot;
      } else {
        final saved = draft?.board['seed'];
        final seed = saved is num ? saved.toInt() : _newPracticeSeed();
        _practiceSeed = seed;
        level = practiceLevel(seed);
      }
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: ZipStatus.failed,
          errorMessage: mode.isLevel
              ? AppStrings.levelFailed
              : AppStrings.zipFailed,
        ),
      );
      return;
    }
```

(g) In `_completeOffDaily`, replace

```dart
    emit(state.copyWith(status: ZipStatus.submitting));

    final records = modeRecords!;
```

with

```dart
    emit(state.copyWith(status: ZipStatus.submitting));

    if (mode.isLevel) {
      await _finishLevel(emit, elapsed: elapsed, points: points, runId: runId);
      return;
    }

    final records = modeRecords!;
```

(h) Add this method after `_completeOffDaily`:

```dart
  /// A level clear: stars into the level progress, then Results with the
  /// goals and the next level. No score, streak, leaderboard or local best.
  Future<void> _finishLevel(
    Emitter<ZipState> emit, {
    required int elapsed,
    required int points,
    required String runId,
  }) async {
    final slot = _levelSlot!;
    final usedHints = state.usedHintsThisRun;
    final clear = await recordLevelClear!(
      game: GameIds.zip,
      slot: slot,
      usedHints: usedHints,
      seconds: elapsed,
    );
    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: points,
      timeSeconds: elapsed,
      dayId: runId,
      usedHints: usedHints,
    );
    if (emit.isDone) return;

    final nextId = slot.nextId;
    emit(
      state.copyWith(
        improved: clear.improved,
        status: ZipStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.levelClearedTitle(slot.number),
          subtitle: '',
          timeSeconds: elapsed,
          improved: clear.improved,
          points: points,
          gameId: GameIds.zip,
          usedHints: usedHints,
          hadMistakes: false,
          hintPenaltySeconds: 0,
          local: LocalResultInfo(
            kind: LocalResultKind.level,
            label: AppStrings.levelRunLabel(slot.number, slot.world.theme),
            bestSeconds: clear.current.bestSeconds,
            againLocation: mode.location('/zip'),
            level: LevelResultInfo(
              runStars: clear.runStars,
              bestStars: clear.current.stars,
              previousStars: clear.previous?.stars,
              usedHints: usedHints,
              targetSeconds: slot.entry.targetSeconds,
              nextLocation: nextId == null
                  ? null
                  : PlayMode.level(nextId).location('/zip'),
              nextWorldTheme: slot.nextWorld?.theme,
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the new and existing ZipBloc tests**

Run: `flutter test test/features/zip/bloc/`
Expected: all PASS (the new 8 and the existing daily, archive and practice tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/zip/bloc/zip_bloc.dart test/features/zip/bloc/zip_bloc_level_test.dart
git commit -m "feat(levels): play a Zip level in ZipBloc"
```

---

### Task 16: Wire it up: DI, ZipScreen and the strip

**Files:**
- Modify: `lib/core/di/app_repositories.dart` (append providers; remove nothing yet)
- Modify: `lib/features/zip/view/zip_screen.dart` (~line 130 bloc creation, ~line 261 strip)
- Modify: `lib/core/widgets/play_mode_strip.dart` (`PlayModeStrip`)
- Test: `test/core/widgets/play_mode_strip_level_test.dart` (create)

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/play_mode_strip.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  testWidgets('a level run shows its level label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayModeStrip(
            mode: PlayMode.level('zip_1_07'),
            levelLabel: 'Level 7 · Ink · Target 0:30',
          ),
        ),
      ),
    );
    expect(find.text('Level 7 · Ink · Target 0:30'), findsOneWidget);
  });

  testWidgets('before the board loads it says Levels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlayModeStrip(mode: PlayMode.level('zip_1_07'))),
      ),
    );
    expect(find.text('Levels'), findsOneWidget);
  });
}
```

Run: `flutter test test/core/widgets/play_mode_strip_level_test.dart`
Expected: compile error (`levelLabel` isn't a parameter).

- [ ] **Step 2: Implement the strip**

In `PlayModeStrip`, change the constructor and add the field:

```dart
  const PlayModeStrip({
    super.key,
    required this.mode,
    this.onNewBoard,
    this.levelLabel,
  });

  final PlayMode mode;

  /// Practice only; null hides the button (or disables it mid-celebration).
  final VoidCallback? onNewBoard;

  /// A level run's "Level 7 · Ink · Target 0:30"; "Levels" until it loads.
  final String? levelLabel;
```

and in `build` replace

```dart
    final label = mode.isArchive
        ? AppStrings.archiveRunLabel(mode.day!)
        : AppStrings.practiceRunLabel;
```

with

```dart
    final label = mode.isArchive
        ? AppStrings.archiveRunLabel(mode.day!)
        : mode.isLevel
        ? (levelLabel ?? AppStrings.levelsTitle)
        : AppStrings.practiceRunLabel;
```

Check that the New board button in `PlayModeStrip.build` is shown only when `mode.isPractice`. If it is gated only on `onNewBoard != null`, change that condition to `mode.isPractice && onNewBoard != null`.

Run: `flutter test test/core/widgets/play_mode_strip_level_test.dart`
Expected: PASS.

- [ ] **Step 3: Pass the level dependencies and label in `ZipScreen`**

In `zip_screen.dart`, in the `ZipBloc(...)` call add after `modeRecords: context.modeRecordsFor(widget.mode),`:

```dart
      levelWorlds: widget.mode.isLevel
          ? context.read<LevelWorldRepository>()
          : null,
      recordLevelClear: widget.mode.isLevel
          ? context.read<RecordLevelClear>()
          : null,
```

Add this method to the screen's `State` class:

```dart
  /// "Level 7 · Ink · Target 0:30" once a level's board has loaded.
  String? _levelLabel() {
    final slot = _bloc.levelSlot;
    if (slot == null) return null;
    final base = AppStrings.levelRunLabel(slot.number, slot.world.theme);
    final target = slot.entry.targetSeconds;
    if (target == null) return base;
    return '$base · ${AppStrings.levelTarget(AppStrings.formatPlayTime(target))}';
  }
```

and pass `levelLabel: _levelLabel(),` to the `PlayModeStrip(` call (~line 261). Add the imports `../../../domain/repositories/level_world_repository.dart` and `../../../domain/usecases/record_level_clear.dart`.

- [ ] **Step 4: Register the providers**

In `app_repositories.dart`, append these providers **at the end** of the providers list (after the last existing `RepositoryProvider`), so `AuthRepository`, `AnalyticsRepository`, `ProgressChangeSignal` and `SharedPreferences` are all above them:

```dart
    // Levels: worlds from Firestore, progress per account (synced).
    RepositoryProvider<LevelWorldRepository>(
      create: (_) => LevelWorldRepositoryImpl(
        FirebaseBootstrap.isReady
            ? FirestoreLevelWorldsSource(FirebaseFirestore.instance)
            : null,
      ),
    ),
    RepositoryProvider<LevelProgressRepository>(
      create: (context) => LevelProgressRepositoryImpl(
        context.read<SharedPreferences>(),
        currentUid: () => context.read<AuthRepository>().currentUser?.uid,
        onChanged: context.read<ProgressChangeSignal>().notify,
      ),
      dispose: (repo) {
        if (repo is LevelProgressRepositoryImpl) repo.dispose();
      },
    ),
    RepositoryProvider<RecordLevelClear>(
      create: (context) => RecordLevelClear(
        context.read<LevelProgressRepository>(),
        context.read<AnalyticsRepository>(),
      ),
    ),
    RepositoryProvider<SyncLevelProgress>(
      create: (context) => SyncLevelProgress(
        auth: context.read<AuthRepository>(),
        local: context.read<LevelProgressRepository>(),
        remote: LevelProgressRemoteRepositoryImpl(FirebaseFirestore.instance),
        isRemoteAvailable: () => FirebaseBootstrap.isReady,
      ),
    ),
```

`LevelProgressRemoteRepositoryImpl(FirebaseFirestore.instance)` is created lazily (on the first sync), and `isRemoteAvailable` stops a sync before it touches Firestore while Firebase isn't ready. If `FirebaseFirestore.instance` throws when Firebase isn't initialised in your setup, change `remote:` to read `FirebaseFirestore.instance` inside the repository's methods instead.

Add imports for `cloud_firestore`, `FirebaseBootstrap` (`../firebase/firebase_bootstrap.dart`), the four new data classes and the domain types, if the file lacks them.

- [ ] **Step 5: Analyze and run the whole suite**

Run: `flutter analyze && flutter test`
Expected: no warnings or errors; all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/di/app_repositories.dart lib/features/zip/view/zip_screen.dart lib/core/widgets/play_mode_strip.dart test/core/widgets/play_mode_strip_level_test.dart
git commit -m "feat(levels): wire level runs into ZipScreen and DI"
```

---

### Task 17: Results for a level

**Files:**
- Create: `lib/features/results/view/level_results_view.dart`
- Modify: `lib/features/results/results_screen.dart:53`
- Test: `test/features/results/level_results_view_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/view/level_results_view.dart';

ResultsArgs args({
  required LevelResultInfo level,
  int seconds = 24,
  bool improved = false,
}) => ResultsArgs(
  title: 'Level 7 cleared',
  subtitle: '',
  timeSeconds: seconds,
  improved: improved,
  points: 0,
  gameId: 'zip',
  usedHints: level.usedHints,
  hadMistakes: false,
  hintPenaltySeconds: 0,
  local: LocalResultInfo(
    kind: LocalResultKind.level,
    label: 'Level 7 · Ink',
    bestSeconds: seconds,
    againLocation: '/zip?mode=level&level=zip_1_07',
    level: level,
  ),
);

Future<void> pump(WidgetTester tester, ResultsArgs value) =>
    tester.pumpWidget(MaterialApp(home: LevelResultsView(args: value)));

void main() {
  testWidgets('shows the time, the target and every goal', (tester) async {
    await pump(
      tester,
      args(
        level: const LevelResultInfo(
          runStars: 3,
          bestStars: 3,
          usedHints: false,
          targetSeconds: 30,
          nextLocation: '/zip?mode=level&level=zip_1_08',
        ),
      ),
    );
    expect(find.text('Level 7 cleared'), findsOneWidget);
    expect(find.text('Level 7 · Ink'), findsOneWidget);
    expect(find.text('0:24 · Target 0:30'), findsOneWidget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    expect(find.text('Next level'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
  });

  testWidgets('a missed goal says how to earn it', (tester) async {
    await pump(
      tester,
      args(
        level: const LevelResultInfo(
          runStars: 2,
          bestStars: 2,
          usedHints: true,
          targetSeconds: 30,
        ),
      ),
    );
    expect(find.text('Replay without hints for this star'), findsOneWidget);
    expect(find.text('More worlds coming soon'), findsOneWidget);
  });

  testWidgets('says what improved, and names the next world', (tester) async {
    await pump(
      tester,
      args(
        improved: true,
        level: const LevelResultInfo(
          runStars: 3,
          bestStars: 3,
          previousStars: 2,
          usedHints: false,
          targetSeconds: 30,
          nextLocation: '/zip?mode=level&level=zip_2_01',
          nextWorldTheme: 'metro',
        ),
      ),
    );
    expect(find.text('New best · 2 → 3 stars'), findsOneWidget);
    expect(find.text('Open Metro'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/results/level_results_view_test.dart`
Expected: compile error.

- [ ] **Step 2: Implement**

`lib/features/results/view/level_results_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../results_args.dart';

/// Results of a cleared level: the time against the target, the three goals
/// (earned, or how to earn them), what improved, and the next level.
///
/// Deliberately still: the level's reward is the line drawn on the map
/// (Levels plan 3), not an effect here.
class LevelResultsView extends StatelessWidget {
  const LevelResultsView({super.key, required this.args});

  final ResultsArgs args;

  static const _starGold = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final info = args.local!;
    final level = info.level!;
    final theme = Theme.of(context);
    final time = AppStrings.formatPlayTime(args.timeSeconds);
    final target = level.targetSeconds;
    final targetText = target == null
        ? null
        : AppStrings.formatPlayTime(target);
    final next = level.nextLocation;
    final again = info.againLocation;
    final newBest = level.moreStars
        ? AppStrings.levelNewBestStars(level.previousStars!, level.bestStars)
        : args.improved
        ? AppStrings.levelNewBestTime
        : null;

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Text(
                args.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                info.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                targetText == null
                    ? time
                    : '$time · ${AppStrings.levelTarget(targetText)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ZipColors.ember,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (newBest != null) ...[
                const SizedBox(height: 6),
                Text(
                  newBest,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ZipColors.success,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _Goal(earned: true, label: AppStrings.levelGoalClear),
              _Goal(
                earned: level.noHintsEarned,
                label: AppStrings.levelGoalNoHints,
                how: AppStrings.levelGoalNoHintsHow,
              ),
              if (targetText != null)
                _Goal(
                  earned: level.timeEarned,
                  label: AppStrings.levelGoalUnder(targetText),
                  how: AppStrings.levelGoalUnderHow(targetText),
                ),
              const SizedBox(height: 24),
              if (next != null)
                ZipPrimaryButton(
                  label: level.opensNewWorld
                      ? AppStrings.levelOpenWorld(level.nextWorldTheme!)
                      : AppStrings.levelNext,
                  icon: AppIcons.play,
                  onPressed: () => context.pushReplacement(next),
                )
              else
                Text(
                  AppStrings.levelAllDone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              const SizedBox(height: 6),
              if (again != null)
                TextButton(
                  onPressed: () => context.pushReplacement(again),
                  child: Text(AppStrings.levelReplay),
                ),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(AppStrings.backHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.earned, required this.label, this.how});

  final bool earned;
  final String label;

  /// Shown under a missed goal.
  final String? how;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            earned ? AppIcons.star : AppIcons.starOutline,
            size: 22,
            color: earned
                ? LevelResultsView._starGold
                : ZipColors.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (!earned && how != null)
                  Text(
                    how!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ZipColors.ember,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

In `results_screen.dart`, replace

```dart
    if (args.local != null) return LocalResultsView(args: args);
```

with

```dart
    if (args.local?.kind == LocalResultKind.level) {
      return LevelResultsView(args: args);
    }
    if (args.local != null) return LocalResultsView(args: args);
```

and import `view/level_results_view.dart` (and `results_args.dart` if it isn't already imported).

- [ ] **Step 3: Run the test and analyze**

Run: `flutter test test/features/results/level_results_view_test.dart && flutter analyze`
Expected: PASS; no warnings or errors. If `ZipColors.inkSoft`, `ZipColors.success` or `ZipColors.outline` are not the names in `app_theme.dart` (they were at `master` 34954de), use the matching names there.

- [ ] **Step 4: Commit**

```bash
git add lib/features/results test/features/results/level_results_view_test.dart
git commit -m "feat(levels): Results for a cleared level"
```

---

### Task 18: Firestore rules, index and rules tests

**Files:**
- Modify: `firestore/firestore.rules`
- Modify: `firestore/firestore.indexes.json`
- Create: `firestore/rules_test/levels.test.ts`

- [ ] **Step 1: Write the failing rules test**

`firestore/rules_test/levels.test.ts`:

```ts
import { assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-levels');
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function db(uid: string | null, admin = false): Firestore {
  if (!uid) return env.unauthenticatedContext().firestore() as unknown as Firestore;
  return env.authenticatedContext(uid, admin ? { admin: true } : {}).firestore() as unknown as Firestore;
}

async function seed(path: string, data: Record<string, unknown>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore() as unknown as Firestore, path), data);
  });
}

describe('level_worlds', () => {
  beforeEach(async () => {
    await seed('level_worlds/zip_1', { game: 'zip', order: 1, published: true, levels: [] });
    await seed('level_worlds/zip_2', { game: 'zip', order: 2, published: false, levels: [] });
  });

  it('anyone can read a published world', async () => {
    await assertSucceeds(getDoc(doc(db(null), 'level_worlds/zip_1')));
  });

  it('players cannot read an unpublished world; admins can', async () => {
    await assertFails(getDoc(doc(db('u1'), 'level_worlds/zip_2')));
    await assertSucceeds(getDoc(doc(db('a1', true), 'level_worlds/zip_2')));
  });

  it('players can list published worlds', async () => {
    const q = query(
      collection(db('u1'), 'level_worlds'),
      where('game', '==', 'zip'),
      where('published', '==', true),
      orderBy('order'),
    );
    await assertSucceeds(getDocs(q));
  });

  it('players cannot list without the published filter', async () => {
    await assertFails(getDocs(query(collection(db('u1'), 'level_worlds'), where('game', '==', 'zip'))));
  });

  it('nobody writes a world from a client', async () => {
    await assertFails(setDoc(doc(db('a1', true), 'level_worlds/zip_3'), { game: 'zip' }));
  });
});

describe('users/{uid}/level_progress', () => {
  const path = (uid: string, game = 'zip') => `users/${uid}/level_progress/${game}`;
  const valid = () => ({
    levels: { zip_1_01: { stars: 3, bestSeconds: 14 } },
    updatedAt: serverTimestamp(),
  });

  it('the owner writes and reads their progress', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path('u1')), valid()));
    await assertSucceeds(getDoc(doc(db('u1'), path('u1'))));
  });

  it('nobody else reads or writes it', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(getDoc(doc(db('u2'), path('u1'))));
    await assertFails(setDoc(doc(db('u2'), path('u1')), valid()));
    await assertFails(getDoc(doc(db(null), path('u1'))));
  });

  it('refuses an unknown game, extra fields, a non-map and a client clock', async () => {
    await assertFails(setDoc(doc(db('u1'), path('u1', 'chess')), valid()));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { ...valid(), extra: 1 }));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { levels: [], updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { levels: {}, updatedAt: new Date(2020, 0, 1) }));
  });

  it('cannot be deleted', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(deleteDoc(doc(db('u1'), path('u1'))));
  });
});
```

- [ ] **Step 2: Run it and see it fail**

Run (needs the Firebase CLI and Java):
`cd firestore/rules_test && npm ci && npx firebase emulators:exec --only firestore --project demo-winklo --config ../../firebase.json "npx vitest run levels.test.ts"`
Expected: FAIL (reads of published worlds and owner writes are denied: no rules yet).

- [ ] **Step 3: Implement the rules**

In `firestore/firestore.rules`, add this function right after `function validUserAvatarId() { … }`:

```
    // users/{uid}/level_progress/{gameId}: {levels: map, updatedAt}. Each
    // entry is checked by the app's merge; level progress never reaches a
    // leaderboard, so a hand-edited doc only changes its owner's map.
    function validLevelProgress(gameId) {
      let data = request.resource.data;
      return gameId in ['zip', 'path_words', 'sudoku']
        && data.keys().hasOnly(['levels', 'updatedAt'])
        && data.levels is map
        && data.updatedAt == request.time;
    }
```

and these two matches right after the `match /users/{uid}/game_streaks/{gameId} { … }` block:

```
    // Levels content, edited in winklo-admin through admin-api. Players read
    // published worlds only; their queries must filter on published == true.
    match /level_worlds/{id} {
      allow get, list: if resource.data.published == true || isAdmin();
      allow write: if false;
    }

    match /users/{uid}/level_progress/{gameId} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid) && validLevelProgress(gameId);
      allow delete: if false;
    }
```

In `firestore/firestore.indexes.json`, add to the `indexes` array:

```json
    {
      "collectionGroup": "level_worlds",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "game", "order": "ASCENDING" },
        { "fieldPath": "published", "order": "ASCENDING" },
        { "fieldPath": "order", "order": "ASCENDING" }
      ]
    }
```

- [ ] **Step 4: Run all rules tests**

Run: `cd firestore/rules_test && npm run test:emulator`
Expected: all files PASS (the new ones and the existing ones).

- [ ] **Step 5: Commit**

```bash
git add firestore/firestore.rules firestore/firestore.indexes.json firestore/rules_test/levels.test.ts
git commit -m "feat(levels): rules and index for level_worlds and level_progress"
```

Deploying (`firebase deploy --only firestore:rules,firestore:indexes`) is a release step for the user, not part of this task.

---

### Task 19: Account deletion wipes level progress

**Files:**
- Modify: `workers/account-deletion/src/firestore_wipe.ts:5-10`
- Modify: `workers/account-deletion/src/firestore_wipe.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `firestore_wipe.test.ts` (add `USER_SUBCOLLECTIONS` to the existing import from `./firestore_wipe`, and `expect`/`it` from vitest if they aren't imported):

```ts
it('wipes level progress with the other user subcollections', () => {
  expect(USER_SUBCOLLECTIONS).toContain('level_progress');
});
```

Run: `cd workers/account-deletion && npx vitest run src/firestore_wipe.test.ts`
Expected: FAIL (`USER_SUBCOLLECTIONS` isn't exported).

- [ ] **Step 2: Implement**

In `firestore_wipe.ts`, replace

```ts
const USER_SUBCOLLECTIONS = [
  'game_days',
  'game_days_debug',
  'game_streaks',
  'game_streaks_debug',
] as const;
```

with

```ts
export const USER_SUBCOLLECTIONS = [
  'game_days',
  'game_days_debug',
  'game_streaks',
  'game_streaks_debug',
  'level_progress',
] as const;
```

- [ ] **Step 3: Run the worker's tests**

Run: `cd workers/account-deletion && npx vitest run`
Expected: all PASS. If an existing test lists every subcollection path it expects to be read, add `/users/u1/level_progress` to it the same way `game_days` is listed.

- [ ] **Step 4: Commit**

```bash
git add workers/account-deletion/src/firestore_wipe.ts workers/account-deletion/src/firestore_wipe.test.ts
git commit -m "feat(levels): delete level progress with the account"
```

Deploying the Worker (`npx wrangler deploy` in `workers/account-deletion`) is a release step for the user.

---

### Task 20: Remove the dead `fetchLevels` path

**Files:**
- Modify: `lib/domain/repositories/zip_level_repository.dart` (remove `fetchLevels`)
- Modify: `lib/data/repositories/zip_level_repository_impl.dart` (remove `fetchLevels`, `_loadAssets`, `_assetFiles`, the `assetBundle` parameter and field, and imports that become unused)
- Delete: `lib/domain/usecases/fetch_zip_levels.dart`, `assets/zip/levels/`
- Modify: `lib/core/di/app_repositories.dart:445-447` (remove the `FetchZipLevels` provider and its import)
- Modify: `pubspec.yaml:120` (remove `- assets/zip/levels/`)
- Modify: `test/features/home/view/home_weekend_badge_test.dart:45`, `test/features/home/view/home_screen_busy_day_test.dart:74`, `test/features/l10n/malayalam_screens_test.dart:64` (remove the `fetchLevels` override and its `@override` line)
- Modify: `test/data/repositories/zip_level_repository_impl_test.dart` (remove the `fetchLevels falls back to assets…` test, and any `assetBundle:` argument)

- [ ] **Step 1: Make the removals listed above**

Then: `git rm -r assets/zip/levels lib/domain/usecases/fetch_zip_levels.dart`

- [ ] **Step 2: Check nothing still refers to them**

Run: `grep -rn "fetchLevels\|FetchZipLevels\|zip/levels\|assetBundle" lib test pubspec.yaml`
Expected: no matches, apart from unrelated `assetBundle` uses outside the Zip level repository (leave those).

- [ ] **Step 3: Analyze and test**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: no warnings or errors; all PASS.

- [ ] **Step 4: Commit**

```bash
git add -A lib test pubspec.yaml assets
git commit -m "chore(zip): remove the unreachable fetchLevels path"
```

---

### Task 21: Full verification

- [ ] **Step 1: Everything the CI runs**

```bash
flutter analyze
flutter test
(cd firestore/rules_test && npm run test:emulator)
(cd workers/account-deletion && npx vitest run)
```

Expected: analyze has no warnings or errors; every suite passes. Copy the summary lines into the PR description.

- [ ] **Step 2: Optional manual check (writes to Firestore — ask the user first)**

There is no Firebase project for staging, so this writes to production. Only with the user's go-ahead: deploy the rules and index, create `level_worlds/zip_1` in the console with `published: true` and two levels shaped like `test/helpers/level_fixtures.dart`, then open the level on a device:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://winklo.pages.dev/zip?mode=level&level=zip_1_01" com.winklo.faseencm
```

Expected: the board loads with "Level 1 · Ink · Target 0:30"; clearing it shows level Results with the goals and "Next level"; Profile has no new entry (the Levels tab is plan 3). Then set `published: false` again.

- [ ] **Step 3: Hand off**

Use superpowers:finishing-a-development-branch. Plan 2 (winklo-admin) is next.

---

## Spec coverage (self-review)

| Spec item | Task |
|---|---|
| `PlayMode.level`, route, run id, not daily | 1 |
| Strings in English and Malayalam | 2 |
| Hints free of time, "costs a star" label | 3 |
| `level_worlds` doc shape, target ≤ 0 → no time goal | 4 |
| `starsFor` written by the user | 5 |
| Per-run stars, monotonic commutative merge, invalid entries dropped | 6 |
| Level numbers worked out across worlds; next level; world boundary | 7 |
| Repository interfaces, `LevelsUnavailable`, `LevelClearResult` | 8 |
| Server → cache, stop at a bad world, memoize | 9 |
| Local-first progress per account; Firestore mirror | 10 |
| `level_cleared` analytics | 11 |
| Record a clear | 12 |
| Sync after each `SyncProgress` run; account switch safe | 13 |
| Results arguments; Results page with goals and next | 14, 17 |
| ZipBloc level mode, drafts, unknown level | 15 |
| Strip label, DI | 16 |
| Rules, validator, index | 18 |
| Account-deletion wipe | 19 |
| Remove dead `fetchLevels` | 20 |

**Deferred on purpose (later plans):** the Levels tab, map, sheet and motion (plan 3: "Next level" will go through the map; the bad-link redirect will go to `/levels`; the strip gains drawn goal marks); the admin side and the publish-order rule (plan 2). **Changed from the spec:** invalid remote entries are dropped and the doc is rewritten, but not sent as a client-error report (the reporter's payload type is outside this plan's reading; add it if wanted).
