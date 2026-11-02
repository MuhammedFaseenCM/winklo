# Admin Levels 2a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app counts level starts, clears and hints per player, a signed-out Play on the level sheet asks for sign-in, the Ink world is dark, and winklo-admin gets a read-only Levels page (Worlds, Players, a player page, Stats) fed by two new admin-api routes.

**Architecture:** The app writes server-side increments to `users/{uid}/level_stats/{game}` through a fire-and-forget use case (`RecordLevelPlay`) called from `ZipBloc` level mode. winklo-admin's Worker reads `level_worlds`, and `level_progress` + `level_stats` by collection-group query, trims invalid values and returns compact rows; the browser does all counting in a pure module (`levelsModel.ts`).

**Tech Stack:** Flutter/Dart (BLoC, cloud_firestore, go_router, mocktail, bloc_test); Firestore rules (rules_test, vitest); winklo-admin: React 19, TanStack Query, react-router 7, Cloudflare Worker (TypeScript), vitest.

**Spec:** `docs/superpowers/specs/2026-11-02-admin-levels-design.md` (sections 1, 1b, 2 "Progress", 3 except the 2b items).

**Repos and branches**

- App: `~/Developments/personal/winklo/.worktrees/admin-levels` on `feat/admin-levels` (exists). Tasks 1–5.
- Admin: `~/Developments/personal/winklo-admin/.worktrees/admin-levels` on `feat/admin-levels`, created in Task 6 Step 1. Tasks 6–12.
- Never stage `pubspec.lock` or `package-lock.json` unless the task adds a dependency (none does).
- Every commit ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No emoji anywhere in UI or copy. Nothing is pushed or deployed by this plan.

---

## File map

**App (winklo)**

| File | Responsibility |
|---|---|
| `lib/features/levels/view/widgets/level_sheet.dart` (modify) | Play asks for sign-in first |
| `lib/features/levels/view/widgets/ink_palette.dart` (create) | The Ink world's colours, one place |
| `lib/features/levels/view/widgets/world_backdrop_painter.dart`, `level_path_painter.dart`, `level_node.dart` (modify) | Read `InkPalette` |
| `lib/domain/repositories/level_play_stats_repository.dart` (create) | `LevelPlayEvent`, `LevelPlayStatsRepository` |
| `lib/domain/usecases/record_level_play.dart` (create) | uid check, fire-and-forget write, rate-limited report |
| `lib/data/repositories/level_play_stats_repository_impl.dart` (create) | Firestore merge + increment |
| `lib/core/di/app_repositories.dart` (modify) | Provide `RecordLevelPlay` |
| `lib/features/zip/bloc/zip_bloc.dart`, `lib/features/zip/view/zip_screen.dart` (modify) | Count start, clear, hint in level mode |
| `firestore/firestore.rules`, `firestore/rules_test/levels.test.ts` (modify) | `level_stats` rules + tests |
| `workers/account-deletion/src/firestore_wipe.ts` + test (modify) | Wipe `level_stats` |

**Admin (winklo-admin)** — see the file map at the top of Task 6.

---

### Task 1: Play from the level sheet asks for sign-in

**Files:**
- Modify: `lib/features/levels/view/widgets/level_sheet.dart` (the Play button's `onPressed`, ~line 139)
- Test: `test/features/levels/view/levels_tab_sheet_test.dart`

Why: the sheet pushes `/zip?mode=level…` directly; for a signed-out player `playAuthRedirect` (`lib/core/router/app_router.dart:47`) turns any play location into `/`, so they land on Home. Every other Play (Home, Archive, More play, Leaderboard) calls `ensureSignedInForPlay` first (`lib/features/auth/view/ensure_signed_in_for_play.dart`), which opens the sign-in sheet.

- [ ] **Step 1: Give the test an `AuthCubit` and a signed-in/out switch**

In `test/features/levels/view/levels_tab_sheet_test.dart`:

Add imports:

```dart
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
```

Add mocks next to `_MockAuth`:

```dart
class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}
```

Change `pumpShell` to take `{bool signedIn = true}` and stub the user from it:

```dart
  Future<void> pumpShell(WidgetTester tester, {bool signedIn = true}) async {
    ...
    final auth = _MockAuth();
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    when(() => auth.currentUser).thenReturn(signedIn ? user : null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream.value(signedIn ? user : null));
```

Wrap the `MaterialApp.router` in the `MultiRepositoryProvider` with the cubit:

```dart
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
```

- [ ] **Step 2: Write the failing tests**

Add after `'Play closes the sheet and opens the level'` (which keeps passing signed in):

```dart
  testWidgets('signed out, Play asks for sign-in and stays on the map', (
    tester,
  ) async {
    await pumpShell(tester, signedIn: false);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text('zip screen'), findsNothing);
    expect(find.text('home-body'), findsNothing);

    await tester.tap(find.text(AppStrings.signInCancel));
    await tester.pumpAndSettle();

    // Cancelled: the level sheet is still open over the map.
    expect(find.text(AppStrings.playSignInTitle), findsNothing);
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    expect(router.state.uri.path, '/levels');
  });
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/levels/view/levels_tab_sheet_test.dart`
Expected: the new test FAILS (`playSignInTitle` not found; the sheet pushed `/zip`). The two existing tests pass.

- [ ] **Step 4: Ask for sign-in in the sheet**

In `level_sheet.dart`, import the helper:

```dart
import '../../../auth/view/ensure_signed_in_for_play.dart';
```

Replace the Play button's `onPressed`:

```dart
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final navigator = Navigator.of(context);
                  // Signed out: the sign-in sheet opens over this one (both on
                  // the root navigator). Cancelled, this sheet stays open.
                  if (!await ensureSignedInForPlay(context)) return;
                  if (!context.mounted) return;
                  navigator.pop();
                  router.push(PlayMode.level(slot.entry.id).location('/zip'));
                },
```

Update the `showLevelSheet` doc comment's last sentence to: `Play asks a signed-out player to sign in first, like every other Play.`

- [ ] **Step 5: Run the sheet tests and the other levels tests**

Run: `flutter test test/features/levels/`
Expected: all PASS.

If `level_sheet_test.dart` pumps `LevelSheet` and taps Play without an `AuthCubit`, give it the same `BlocProvider<AuthCubit>` (signed in) as Step 1.

- [ ] **Step 6: Commit**

```bash
git add lib/features/levels/view/widgets/level_sheet.dart test/features/levels/view/
git commit -m "fix(levels): Play on the level sheet asks a signed-out player to sign in

It pushed the level straight away, and the router's sign-in redirect sent
the player Home.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: A dark Ink world (ink-stone)

**Files:**
- Create: `lib/features/levels/view/widgets/ink_palette.dart`
- Modify: `lib/features/levels/view/widgets/world_backdrop_painter.dart`, `level_path_painter.dart`, `level_node.dart`
- Test: `test/features/levels/view/level_node_test.dart`, `test/features/levels/view/map_painters_test.dart`

The Ink backdrop is light rice paper (`#EFE8D8`); the app (`ZipColors.ink` `#0F172A`) and Metro (`#13233A`) are dark. Ink becomes ink-stone: a warm near-black ground with the vermilion grid, and the line in rice-paper white.

| Element | Was | Becomes (`InkPalette.`) |
|---|---|---|
| Ground: backdrop, node discs, star-mark patch | `#EFE8D8` | `stone` `#1C1915` |
| Grid | `#C2410C` @ 0.28 | `vermilion` `#C2410C` @ 0.30 |
| Reached line, current ring, ensō, numbers | `#2B2724` / `#111111` | `rice` `#EFE8D8` |
| Unreached road dots, locked ring | `#A8A29E` | `pencil` `#78716C` |
| Locked number | `#A8A29E` | `pencilLight` `#A8A29E` |
| Star seals | `#B91C1C` | `seal` `#DC2626` |

- [ ] **Step 1: Write the failing test**

In `test/features/levels/view/level_node_test.dart`, change the expectation in `"a done level's marks sit on a patch of its world's paper"`:

```dart
    expect(decoration.color, const Color(0xFF1C1915));
```

Add a test (same file) for the number colour on Ink. Reuse the file's existing helper that pumps a `LevelNode` for an Ink done level (read the file; it builds `LevelMapNode`s from `level_fixtures`):

```dart
  testWidgets('on Ink the level number is rice-paper white on the stone', (
    tester,
  ) async {
    // Pump an Ink-world current-level node with the file's helper.
    ...
    final number = tester.widget<Text>(find.text('1'));
    expect(number.style?.color, const Color(0xFFEFE8D8));
  });
```

Fill the `...` with the same pump code the patch test above uses, but for the current level (state `LevelNodeState.current`). If the number is not drawn as a `Text` with an explicit `style.color`, assert on whichever widget carries `numberColor` in `level_node.dart`.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/levels/view/level_node_test.dart`
Expected: FAIL — `0xFFEFE8D8` vs `0xFF1C1915`, and `0xFF111111` vs `0xFFEFE8D8`.

- [ ] **Step 3: Create the palette**

`lib/features/levels/view/widgets/ink_palette.dart`:

```dart
import 'package:flutter/painting.dart';

/// The Ink world's colours: ink-stone, a warm near-black ground, with a
/// vermilion grid and the line in rice-paper white. Dark like the rest of
/// the app, and still distinct from Metro's navy. Every Ink painter reads
/// these, so the world can't drift apart.
abstract final class InkPalette {
  /// The ground: backdrop, node discs, the star-mark patch.
  static const stone = Color(0xFF1C1915);

  /// The grid (drawn at [gridAlpha]).
  static const vermilion = Color(0xFFC2410C);
  static const gridAlpha = 0.30;

  /// The reached line, the current ring, the ensō and level numbers.
  static const rice = Color(0xFFEFE8D8);

  /// The unreached road and a locked level's ring.
  static const pencil = Color(0xFF78716C);

  /// A locked level's number.
  static const pencilLight = Color(0xFFA8A29E);

  /// Earned and unearned star seals.
  static const seal = Color(0xFFDC2626);
}
```

- [ ] **Step 4: Use it in the painters**

`world_backdrop_painter.dart`:
- Import `ink_palette.dart`.
- Delete `static const paper` and `static const vermilion`. Keep `metroNight`.
- Update the class doc's first line to: `Each world's backdrop: ink-stone with a vermilion grid (Ink), a night`.
- `_ink`:

```dart
  void _ink(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = InkPalette.stone);
    final grid = Paint()
      ..color = InkPalette.vermilion.withValues(alpha: InkPalette.gridAlpha)
      ..strokeWidth = 0.8;
    ...unchanged loops...
  }
```

`level_path_painter.dart`:
- Import `ink_palette.dart`.
- Replace `static const ink = Color(0xFF2B2724);` and `static const pencil = Color(0xFFA8A29E);` with:

```dart
  static const ink = InkPalette.rice;
  static const pencil = InkPalette.pencil;
```

- In the class doc, change `(sumi ink on paper, a sky route on Metro)` to `(rice-paper white on ink-stone, a sky route on Metro)`.

`level_node.dart`:
- Import `ink_palette.dart`.
- `numberColor`:

```dart
      ('ink', LevelNodeState.locked) => InkPalette.pencilLight,
      ('ink', _) => InkPalette.rice,
```

- `_paper`: `'ink' => InkPalette.stone,`
- `_NodePainter`: delete `static const paper`; draw the disc with `InkPalette.stone`; the ensō `..color = InkPalette.rice`; the current ring `..color = InkPalette.rice`; the locked ring `..color = InkPalette.pencil`.
- `_StarMarksPainter`: `paint.color = InkPalette.seal;`
- Search the file for any remaining `0xFFEFE8D8`, `0xFF2B2724`, `0xFF111111`, `0xFFA8A29E`, `0xFFB91C1C` and replace with the palette entry from the table.

Then: `grep -rn "WorldBackdropPainter.paper\|WorldBackdropPainter.vermilion\|0xFFEFE8D8\|0xFF2B2724" lib test` must show nothing outside `ink_palette.dart` (fix any hit the same way; a test hit means the test expects the old colour and changes to the table's new one).

- [ ] **Step 5: Run the levels tests**

Run: `flutter test test/features/levels/`
Expected: all PASS. If `map_painters_test.dart` compares pixel colours of the Ink band against paper, update those to `InkPalette.stone` / `InkPalette.rice`.

- [ ] **Step 6: Render and look**

Write a temporary test `test/tmp_ink_render_test.dart` that pumps `LevelsScreen` at 360×780 with Ink World 1 (3 levels, Level 1 cleared) and Metro World 2, the same providers as `levels_screen_test.dart`, wraps it in a `RepaintBoundary` and saves `toImage(pixelRatio: 2)` to `/private/tmp/claude-501/-Users-apple-Desktop-winklo-playstore/1fa129fb-252f-48e0-98c0-3ba1206f25c7/scratchpad/levels_ink_dark.png` (use `tester.runAsync` for `toImage`/`toByteData` and `File.writeAsBytes`). Run it, open the PNG, and check: dark ground, readable white numbers, visible vermilion grid, white line up to the current level, dotted road beyond, star seals visible, world label legible. Then delete the temporary test file. Report the PNG path to the controller.

- [ ] **Step 7: Commit**

```bash
git add lib/features/levels/view/widgets/ test/features/levels/
git commit -m "feat(levels): the Ink world is ink-stone, dark like the rest of the app

The colours live in one InkPalette that the backdrop, path, node and star
painters share.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `RecordLevelPlay` (domain)

**Files:**
- Create: `lib/domain/repositories/level_play_stats_repository.dart`
- Create: `lib/domain/usecases/record_level_play.dart`
- Test: `test/domain/usecases/record_level_play_test.dart`

- [ ] **Step 1: Write the repository interface**

`lib/domain/repositories/level_play_stats_repository.dart`:

```dart
/// One counted moment of a level run.
enum LevelPlayEvent {
  /// A new run: the board loaded with no saved run to resume.
  start('starts'),

  /// A cleared run.
  clear('clears'),

  /// A hint spent.
  hint('hints');

  const LevelPlayEvent(this.field);

  /// The counter's field in `users/{uid}/level_stats/{game}.levels.{id}`.
  final String field;
}

/// Play counters for the admin's Levels views:
/// `users/{uid}/level_stats/{game}` = `{levels: {id: {starts, clears, hints,
/// lastPlayedAt}}, updatedAt}`. Written with server-side increments, so two
/// devices add up instead of overwriting. The app never reads it back.
abstract interface class LevelPlayStatsRepository {
  /// Adds 1 to [event]'s counter for [levelId] and stamps `lastPlayedAt`.
  Future<void> increment(
    String uid,
    String game,
    String levelId,
    LevelPlayEvent event,
  );
}
```

- [ ] **Step 2: Write the failing use-case tests**

`test/domain/usecases/record_level_play_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_play_stats_repository.dart';
import 'package:winklo/domain/usecases/record_level_play.dart';
import 'package:winklo/domain/usecases/report_client_error.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockStats extends Mock implements LevelPlayStatsRepository {}

class _MockReport extends Mock implements ReportClientError {}

void main() {
  late _MockAuth auth;
  late _MockStats stats;
  late _MockReport report;
  late DateTime now;
  var remoteReady = true;

  setUpAll(() {
    registerFallbackValue(LevelPlayEvent.start);
    registerFallbackValue(
      const ClientErrorReport(severity: 'error', source: 'handled', code: 'x', message: 'x'),
    );
  });

  setUp(() {
    auth = _MockAuth();
    stats = _MockStats();
    report = _MockReport();
    now = DateTime(2026, 11, 2, 9);
    remoteReady = true;
    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'Ada'),
    );
    when(() => stats.increment(any(), any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => report(any())).thenAnswer((_) async {});
  });

  RecordLevelPlay build() => RecordLevelPlay(
    auth: auth,
    stats: stats,
    reportClientError: report,
    isRemoteAvailable: () => remoteReady,
    now: () => now,
  );

  test('increments the event for the signed-in player', () async {
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verify(() => stats.increment('u1', 'zip', 'zip_1_01', LevelPlayEvent.start))
        .called(1);
  });

  test('records nothing when signed out', () async {
    when(() => auth.currentUser).thenReturn(null);
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.clear);
    verifyNever(() => stats.increment(any(), any(), any(), any()));
  });

  test('records nothing before Firebase is ready', () async {
    remoteReady = false;
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.hint);
    verifyNever(() => stats.increment(any(), any(), any(), any()));
  });

  test('a failed write is reported once per cooldown and never thrown', () async {
    when(() => stats.increment(any(), any(), any(), any()))
        .thenThrow(StateError('permission-denied'));
    final record = build();
    await record(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    await record(game: 'zip', levelId: 'zip_1_02', event: LevelPlayEvent.start);
    final reports = verify(() => report(captureAny())).captured;
    expect(reports, hasLength(1));
    final sent = reports.single as ClientErrorReport;
    expect(sent.code, 'level_stats_write_failed');
    expect(sent.uid, 'u1');

    now = now.add(const Duration(minutes: 11));
    await record(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verify(() => report(any())).called(1);
  });

  test('a timeout is not reported', () async {
    when(() => stats.increment(any(), any(), any(), any()))
        .thenThrow(TimeoutException('slow'));
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verifyNever(() => report(any()));
  });
}
```

- [ ] **Step 3: Run to see it fail**

Run: `flutter test test/domain/usecases/record_level_play_test.dart`
Expected: FAIL — `record_level_play.dart` does not exist.

- [ ] **Step 4: Write the use case**

`lib/domain/usecases/record_level_play.dart`:

```dart
import 'dart:async';

import '../entities/client_error_report.dart';
import '../failures.dart';
import '../repositories/auth_repository.dart';
import '../repositories/level_play_stats_repository.dart';
import 'report_client_error.dart';

/// Counts a level start, clear or hint for the admin's Levels views.
///
/// Never throws: play must not wait on or fail because of a counter. Signed
/// out, or before Firebase is ready, nothing is recorded. A failure is
/// reported at most once per [reportCooldown] for the same error; timeouts
/// (offline) are not reported, since Firestore keeps the write queued.
class RecordLevelPlay {
  RecordLevelPlay({
    required AuthRepository auth,
    required LevelPlayStatsRepository stats,
    ReportClientError? reportClientError,
    bool Function()? isRemoteAvailable,
    DateTime Function()? now,
    this.reportCooldown = const Duration(minutes: 10),
  }) : _auth = auth,
       _stats = stats,
       _reportClientError = reportClientError,
       _isRemoteAvailable = isRemoteAvailable ?? _always,
       _now = now ?? DateTime.now;

  static const failureCode = 'level_stats_write_failed';

  final AuthRepository _auth;
  final LevelPlayStatsRepository _stats;
  final ReportClientError? _reportClientError;
  final bool Function() _isRemoteAvailable;
  final DateTime Function() _now;
  final Duration reportCooldown;

  String? _lastReportKey;
  DateTime? _lastReportAt;

  static bool _always() => true;

  Future<void> call({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !_isRemoteAvailable()) return;
    try {
      await _stats.increment(uid, game, levelId, event);
    } catch (error, stack) {
      _report(uid, error, stack);
    }
  }

  void _report(String uid, Object error, StackTrace stack) {
    final report = _reportClientError;
    if (report == null || _auth.currentUser?.uid != uid) return;
    if (error is TimeoutException) return;
    if (error is Failure && !error.reportable) return;
    final at = _now();
    final key = '${error.runtimeType}|$error';
    final last = _lastReportAt;
    if (key == _lastReportKey &&
        last != null &&
        at.difference(last) < reportCooldown) {
      return;
    }
    _lastReportKey = key;
    _lastReportAt = at;
    unawaited(
      report(
        ClientErrorReport(
          severity: 'error',
          source: 'handled',
          code: failureCode,
          message: 'Level stats write failed: $error',
          cause: error.toString(),
          stack: stack.toString(),
          function: 'RecordLevelPlay',
          uid: uid,
        ),
      ).catchError((Object _) {}),
    );
  }
}
```

Note: the test's second failing write uses a different level but the same error, so the key matches and it is not reported again. That is intended (one report per error kind per cooldown).

- [ ] **Step 5: Run to see it pass**

Run: `flutter test test/domain/usecases/record_level_play_test.dart`
Expected: 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/level_play_stats_repository.dart lib/domain/usecases/record_level_play.dart test/domain/usecases/record_level_play_test.dart
git commit -m "feat(levels): RecordLevelPlay counts level starts, clears and hints

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore counters and ZipBloc counting

**Files:**
- Create: `lib/data/repositories/level_play_stats_repository_impl.dart`
- Modify: `lib/core/di/app_repositories.dart` (next to `RecordLevelClear`, ~line 499)
- Modify: `lib/features/zip/bloc/zip_bloc.dart` (constructor ~line 61; `_startOffDaily` after the ready emit ~line 600; `_onHint` after `_persistDraft` ~line 427; `_finishLevel` after `recordLevelClear!` ~line 705)
- Modify: `lib/features/zip/view/zip_screen.dart` (~line 156)
- Test: `test/features/zip/bloc/zip_bloc_level_test.dart`

- [ ] **Step 1: Write the failing bloc tests**

In `test/features/zip/bloc/zip_bloc_level_test.dart` add a recording fake at the top level:

```dart
class _Plays {
  final List<(String, LevelPlayEvent)> events = [];

  Future<void> call({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  }) async => events.add((levelId, event));
}
```

and the imports:

```dart
import 'package:winklo/domain/repositories/level_play_stats_repository.dart';
```

In `main()`, add `late _Plays plays;`, set `plays = _Plays();` in `setUp`, and pass `recordLevelPlay: plays.call,` in `build(...)`.

Add the tests:

```dart
  group('play counters', () {
    test('a fresh run counts a start; a clear counts a clear', () async {
      final bloc = build('zip_1_01');
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      expect(plays.events, [('zip_1_01', LevelPlayEvent.start)]);
      await finish(bloc);
      expect(plays.events, [
        ('zip_1_01', LevelPlayEvent.start),
        ('zip_1_01', LevelPlayEvent.clear),
      ]);
      await bloc.close();
    });

    test('resuming a saved run is not a start', () async {
      drafts.runs['zip_level_zip_1_01'] = InProgressRun(
        gameId: 'zip',
        playId: 'level_zip_1_01',
        elapsedMs: 1000,
        board: const {'path': []},
      );
      final bloc = build('zip_1_01');
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      expect(plays.events, isEmpty);
      await bloc.close();
    });

    test('each hint counts; Reset does not start a run', () async {
      final bloc = build('zip_1_01');
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      bloc.add(const ZipEvent.hint());
      await bloc.stream.firstWhere((s) => s.usedHintsThisRun);
      bloc.add(const ZipEvent.reset());
      await pumpEventQueue();
      expect(plays.events, [
        ('zip_1_01', LevelPlayEvent.start),
        ('zip_1_01', LevelPlayEvent.hint),
      ]);
      await bloc.close();
    });

    test('a Replay of a cleared level is a new start', () async {
      final first = build('zip_1_01');
      first.add(const ZipEvent.started());
      await ready(first);
      await finish(first);
      await first.close();

      final replay = build('zip_1_01');
      replay.add(const ZipEvent.started());
      await ready(replay);
      expect(
        plays.events.where((e) => e.$2 == LevelPlayEvent.start),
        hasLength(2),
      );
      await replay.close();
    });

    test('a level that fails to load counts nothing', () async {
      final bloc = build('zip_1_02', gated: true);
      bloc.add(const ZipEvent.started());
      expect((await ready(bloc)).status, ZipStatus.failed);
      expect(plays.events, isEmpty);
      await bloc.close();
    });
  });
```

A draft with no `boardFingerprint` matches any board (`InProgressRun.isForBoard`), so this draft is resumed.

Also add a test in `test/features/zip/bloc/zip_bloc_modes_test.dart` (or wherever daily/practice blocs are built) only if `recordLevelPlay` could be called there; it can't (Step 3 guards on `mode.isLevel`), so no test is needed.

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/zip/bloc/zip_bloc_level_test.dart`
Expected: compile error — `ZipBloc` has no `recordLevelPlay`.

- [ ] **Step 3: Count in ZipBloc**

In `zip_bloc.dart`:

Import:

```dart
import '../../../domain/repositories/level_play_stats_repository.dart';
```

Constructor parameter (after `this.levelProgress,`):

```dart
    this.recordLevelPlay,
```

Field (after `levelProgress`):

```dart
  /// Counts level starts, clears and hints for the admin (a
  /// `RecordLevelPlay`); null records nothing. Never awaited: a counter
  /// must not hold up play.
  final Future<void> Function({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  })?
  recordLevelPlay;

  void _countPlay(LevelPlayEvent event) {
    final slot = _levelSlot;
    final record = recordLevelPlay;
    if (!mode.isLevel || slot == null || record == null) return;
    unawaited(record(game: GameIds.zip, levelId: slot.entry.id, event: event));
  }
```

(`dart:async` is already imported, for `unawaited`.)

In `_startOffDaily`, right after the `emit(ZipState(... status: ZipStatus.ready ...))` and before the practice-seed `_persistDraft`:

```dart
    if (draft == null) _countPlay(LevelPlayEvent.start);
```

In `_onHint`, after `await _persistDraft();`:

```dart
    _countPlay(LevelPlayEvent.hint);
```

In `_finishLevel`, right after `final clear = await recordLevelClear!(...);`:

```dart
    _countPlay(LevelPlayEvent.clear);
```

- [ ] **Step 4: Run the bloc tests**

Run: `flutter test test/features/zip/bloc/`
Expected: all PASS.

- [ ] **Step 5: The Firestore implementation**

`lib/data/repositories/level_play_stats_repository_impl.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/level_play_stats_repository.dart';

/// `users/{uid}/level_stats/{game}`: one merge write per event, an increment
/// on the level's counter plus server timestamps. Increments add up across
/// devices; a write made offline waits in Firestore's queue, so this is not
/// given a timeout (the caller never awaits it on the UI path).
class LevelPlayStatsRepositoryImpl implements LevelPlayStatsRepository {
  LevelPlayStatsRepositoryImpl([this._firestore]);

  /// Null reads [FirebaseFirestore.instance] on first use.
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> increment(
    String uid,
    String game,
    String levelId,
    LevelPlayEvent event,
  ) => _db
      .collection('users')
      .doc(uid)
      .collection('level_stats')
      .doc(game)
      .set({
        'levels': {
          levelId: {
            event.field: FieldValue.increment(1),
            'lastPlayedAt': FieldValue.serverTimestamp(),
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
```

- [ ] **Step 6: Provide it and pass it to ZipBloc**

`app_repositories.dart`, after the `RecordLevelClear` provider:

```dart
    RepositoryProvider<RecordLevelPlay>(
      create: (context) => RecordLevelPlay(
        auth: context.read<AuthRepository>(),
        stats: LevelPlayStatsRepositoryImpl(),
        isRemoteAvailable: () => FirebaseBootstrap.isReady,
        reportClientError: clientErrorRepository == null
            ? null
            : ReportClientError(clientErrorRepository),
      ),
    ),
```

with imports for `RecordLevelPlay` and `LevelPlayStatsRepositoryImpl` (match the file's import style).

`zip_screen.dart`, after `levelProgress:`:

```dart
      recordLevelPlay: widget.mode.isLevel
          ? context.read<RecordLevelPlay>().call
          : null,
```

Find every test that pumps `ZipScreen` in level mode with explicit providers (`grep -rln "PlayMode.level" test/features/zip/view test/core`) and add `RepositoryProvider<RecordLevelPlay>.value(value: RecordLevelPlay(auth: <the test's auth mock>, stats: _NoStats()))`, where `_NoStats` is a local `LevelPlayStatsRepository` whose `increment` returns `Future.value()`. Tests that use `buildRepositoryProviders(...)` get it for free.

- [ ] **Step 7: Run the full suite and analyze**

Run: `flutter analyze && flutter test`
Expected: analyze shows only the 20 existing infos; all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/data/repositories/level_play_stats_repository_impl.dart lib/core/di/app_repositories.dart lib/features/zip/ test/
git commit -m "feat(levels): count level starts, clears and hints in level_stats

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Rules and account deletion

**Files:**
- Modify: `firestore/firestore.rules` (after `validLevelProgress`, ~line 174; after the `level_progress` match, ~line 331)
- Test: `firestore/rules_test/levels.test.ts`
- Modify: `workers/account-deletion/src/firestore_wipe.ts:5-11`, `workers/account-deletion/src/firestore_wipe.test.ts`

- [ ] **Step 1: Write the rules tests**

Append to `firestore/rules_test/levels.test.ts` (it already imports `setDoc`, `getDoc`, `deleteDoc`, `doc`, `serverTimestamp`, `assertSucceeds`, `assertFails`, `db`, `seed`):

```ts
describe('users/{uid}/level_stats', () => {
  const path = (uid: string, game = 'zip') => `users/${uid}/level_stats/${game}`;
  const valid = () => ({
    levels: { zip_1_01: { starts: increment(1), lastPlayedAt: serverTimestamp() } },
    updatedAt: serverTimestamp(),
  });

  it('the owner adds to their counters with merge writes', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path('u1')), valid(), { merge: true }));
    await assertSucceeds(setDoc(doc(db('u1'), path('u1')), valid(), { merge: true }));
  });

  it('nobody reads it from the app, not even the owner', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(getDoc(doc(db('u1'), path('u1'))));
    await assertFails(getDoc(doc(db('u2'), path('u1'))));
  });

  it('nobody else writes it', async () => {
    await assertFails(setDoc(doc(db('u2'), path('u1')), valid(), { merge: true }));
    await assertFails(setDoc(doc(db(null), path('u1')), valid(), { merge: true }));
  });

  it('refuses an unknown game, extra fields and a client clock', async () => {
    await assertFails(setDoc(doc(db('u1'), path('u1', 'chess')), valid(), { merge: true }));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { ...valid(), extra: 1 }, { merge: true }));
    await assertFails(
      setDoc(doc(db('u1'), path('u1')), { levels: {}, updatedAt: new Date(2020, 0, 1) }, { merge: true }),
    );
  });

  it('cannot be deleted', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(deleteDoc(doc(db('u1'), path('u1'))));
  });
});
```

Add `increment` to the file's `firebase/firestore` import.

- [ ] **Step 2: Add the rules**

In `firestore/firestore.rules`, after `validLevelProgress`:

```
    // users/{uid}/level_stats/{gameId}: {levels: map, updatedAt}. Play
    // counters for winklo-admin only; the app never reads them back. Entries
    // aren't checked one by one (rules can't walk a map with dynamic keys):
    // a hand-edited doc only skews its owner's numbers, and the admin drops
    // invalid values.
    function validLevelStats(gameId) {
      let data = request.resource.data;
      return validGame(gameId)
        && data.keys().hasOnly(['levels', 'updatedAt'])
        && data.levels is map
        && data.updatedAt == request.time;
    }
```

After the `level_progress` match:

```
    match /users/{uid}/level_stats/{gameId} {
      allow read: if false;
      allow create, update: if isOwner(uid) && validLevelStats(gameId);
      allow delete: if false;
    }
```

- [ ] **Step 3: Run the rules tests if the emulator can run**

Run: `cd firestore/rules_test && npx tsc --noEmit -p . 2>/dev/null; java -version`
If Java is present: `npm test -- levels` and expect PASS. If not (the known state on this Mac), report "rules tests written and type-checked, not run: no Java" and continue. Do not install Java.

- [ ] **Step 4: Account deletion wipes it**

`workers/account-deletion/src/firestore_wipe.ts`: add `'level_stats',` after `'level_progress',` in `USER_SUBCOLLECTIONS`.

`firestore_wipe.test.ts`, next to the `level_progress` test:

```ts
  it('wipes level play counters with the other user subcollections', () => {
    expect(USER_SUBCOLLECTIONS).toContain('level_stats');
  });
```

Run: `cd workers/account-deletion && npx vitest run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add firestore/firestore.rules firestore/rules_test/levels.test.ts workers/account-deletion/src/
git commit -m "feat(levels): rules for level_stats; account deletion wipes it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
## winklo-admin tasks (6–13)

All paths in Tasks 6–12 are relative to the admin worktree `~/Developments/personal/winklo-admin/.worktrees/admin-levels`.

**Gates** (CI runs all of them; every task ends green):

- SPA: `npm run lint` (oxlint, cap 26 warnings — never raise it), `npm run check:ui`, `npm run typecheck:tests`, `npm test`, `npm run build`, `npm run check:bundle`.
- Worker: `cd workers/admin-api && npm run typecheck && npm test` (the root `npm test` does not run Worker tests).

**Conventions found in this repo** (follow them):

- Worker errors: any thrown `Error` whose message does not start with `firestore_`, `token_`, `fcm_`, `rc_`, `auth_` or `ga4_` turns into **401 unauthorized** in the catch at the end of `index.ts`. Every new Firestore failure therefore throws `firestore_…`.
- Worker tests stub `fetch` with `vi.stubGlobal` and mock `./admin_auth` (see `src/platform_users_lookup.routes.test.ts:1-41`); `FIREBASE_ACCESS_TOKEN: 'test-token'` in `env` skips Google auth.
- SPA data goes through `fromSource(domain, real, mock)`; page tests run in mock mode (`localStorage winklo_mock_admin='true'`, `winklo_mock_latency='0'`, `resetMockStores()` after each).
- CSS: one stylesheet per page folder, classes prefixed by the page (`.lv-`), tokens only (no hex/rgb/hsl, only `var(--…)` names declared in `src/styles/tokens.css`), `--text-3` text at least 12px, never `color: var(--text-4)`.
- Stars are drawn with lucide `Star` icons, never emoji or the ★ character.

**Admin file map**

| File | Responsibility |
|---|---|
| `workers/admin-api/src/levels.ts` (create) | `LEVEL_GAMES`, trimming, `LevelsStore` (worlds list, collection-group progress, one player) |
| `workers/admin-api/src/index.ts` (modify) | Three GET routes |
| `src/lib/adminApi.ts` (modify) | Level types, `fetchLevelWorlds`, `fetchLevelProgress`, `fetchLevelPlayer` |
| `src/mocks/levels.ts` (create), `mockMode.ts`, `mockApi.ts` (modify) | Mock domain `levels` |
| `src/queries/keys.ts`, `src/queries/levels.ts` (create) | `qk.levels`, hooks, names lookup |
| `src/pages/levels/levelsModel.ts` (create) | All counting: map levels, player summaries, per-level and per-world stats, drop-off |
| `src/pages/levels/LevelsPage.tsx`, `WorldsTab.tsx`, `PlayersTab.tsx`, `StatsTab.tsx`, `PlayerLevelsPage.tsx`, `Stars.tsx`, `levels.css`, `levels-css.test.ts` (create) | The UI |
| `src/routes.tsx`, `src/layout/nav.ts`, `src/layout/nav.test.tsx` (modify) | Page registration and the sidebar item |
| `src/pages/platform/UsersTab.tsx`, `userModel.ts` (modify) | "View levels" |

---

### Task 6: admin-api reads worlds and progress (`levels.ts`)

**Files:**
- Create: `workers/admin-api/src/levels.ts`
- Test: `workers/admin-api/src/levels.test.ts`

- [ ] **Step 1: Create the admin worktree**

```bash
cd ~/Developments/personal/winklo-admin
git status --short   # expect only "?? docs/winklo.code-workspace"; leave it alone
grep -qx ".worktrees/" .gitignore || echo "STOP: .worktrees/ not ignored — tell the controller"
git worktree add -b feat/admin-levels .worktrees/admin-levels master
cd .worktrees/admin-levels && npm ci && (cd workers/admin-api && npm ci)
npm test 2>&1 | tail -3 && (cd workers/admin-api && npm test 2>&1 | tail -3)
```

Expected: both suites pass on the clean worktree. If `.worktrees/` is not ignored, stop and report (the controller decides; do not edit `.gitignore` on master).

- [ ] **Step 2: Write the failing tests**

`workers/admin-api/src/levels.test.ts`:

```ts
import { afterEach, describe, expect, it, vi } from 'vitest';
import { isLevelGame, LevelsStore, trimCounters, trimRecords, uidFromPath, worldFromDoc } from './levels';

const ROOT = 'projects/p/databases/(default)/documents';
const int = (n: number) => ({ integerValue: String(n) });
const str = (s: string) => ({ stringValue: s });
const ts = (s: string) => ({ timestampValue: s });
const map = (fields: Record<string, unknown>) => ({ mapValue: { fields } });

afterEach(() => vi.unstubAllGlobals());

describe('isLevelGame', () => {
  it('accepts zip only', () => {
    expect(isLevelGame('zip')).toBe(true);
    expect(isLevelGame('sudoku')).toBe(false);
    expect(isLevelGame('')).toBe(false);
  });
});

describe('uidFromPath', () => {
  it('reads the uid of users/{uid}/{collection}/{game}', () => {
    expect(uidFromPath(`${ROOT}/users/u1/level_progress/zip`, 'level_progress', 'zip')).toBe('u1');
    expect(uidFromPath(`${ROOT}/users/u1/level_progress/sudoku`, 'level_progress', 'zip')).toBeNull();
    expect(uidFromPath(`${ROOT}/teams/t1/level_progress/zip`, 'level_progress', 'zip')).toBeNull();
    expect(uidFromPath(`${ROOT}/users/u1/x/y/level_progress/zip`, 'level_progress', 'zip')).toBeNull();
  });
});

describe('trimRecords', () => {
  it('keeps valid records and drops the rest, like the app', () => {
    expect(
      trimRecords({
        zip_1_01: { stars: 3, bestSeconds: 14 },
        zip_1_02: { stars: 2.0, bestSeconds: 30.7 },
        zip_1_03: { stars: 4, bestSeconds: 10 },
        zip_1_04: { stars: 1, bestSeconds: 0 },
        zip_1_05: 'x',
      }),
    ).toEqual({ zip_1_01: { stars: 3, bestSeconds: 14 }, zip_1_02: { stars: 2, bestSeconds: 30 } });
    expect(trimRecords(null)).toEqual({});
  });
});

describe('trimCounters', () => {
  it('keeps whole counters >= 0, defaults missing ones to 0, keeps lastPlayedAt strings', () => {
    expect(
      trimCounters({
        zip_1_01: { starts: 3, clears: 1, lastPlayedAt: '2026-11-02T10:00:00Z' },
        zip_1_02: { starts: -1, clears: 1, hints: 2 },
        zip_1_03: { starts: 1.5 },
        zip_1_04: 7,
      }),
    ).toEqual({
      zip_1_01: { starts: 3, clears: 1, hints: 0, lastPlayedAt: '2026-11-02T10:00:00Z' },
      zip_1_02: { starts: 0, clears: 1, hints: 2, lastPlayedAt: null },
      zip_1_03: { starts: 0, clears: 0, hints: 0, lastPlayedAt: null },
    });
  });
});

describe('worldFromDoc', () => {
  it('summarises a world: no boards, levels as id/size/target', () => {
    const world = worldFromDoc(`${ROOT}/level_worlds/zip_1`, {
      game: str('zip'),
      order: int(1),
      theme: str('ink'),
      title: str('Ink'),
      published: { booleanValue: true },
      updatedAt: ts('2026-10-31T08:00:00Z'),
      levels: {
        arrayValue: {
          values: [
            map({ id: str('zip_1_01'), size: int(4), targetSeconds: int(20), solution: { arrayValue: { values: [str('0,0')] } } }),
            map({ id: str('zip_1_02'), size: int(4) }),
          ],
        },
      },
    });
    expect(world).toEqual({
      id: 'zip_1',
      game: 'zip',
      order: 1,
      theme: 'ink',
      title: 'Ink',
      published: true,
      updatedAt: '2026-10-31T08:00:00Z',
      levels: [
        { id: 'zip_1_01', size: 4, targetSeconds: 20 },
        { id: 'zip_1_02', size: 4, targetSeconds: null },
      ],
    });
  });

  it('is null without a game or an order', () => {
    expect(worldFromDoc(`${ROOT}/level_worlds/x`, { order: int(1) })).toBeNull();
    expect(worldFromDoc(`${ROOT}/level_worlds/x`, { game: str('zip') })).toBeNull();
  });
});

describe('LevelsStore', () => {
  const doc = (name: string, fields: Record<string, unknown>) => ({ document: { name: `${ROOT}/${name}`, fields } });

  it('joins progress and stats by uid across collection-group pages', async () => {
    const calls: Array<{ url: string; body: any }> = [];
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string, init: RequestInit) => {
        const body = JSON.parse(String(init.body));
        calls.push({ url, body });
        const from = body.structuredQuery.from[0].collectionId;
        if (from === 'level_progress') {
          return Response.json([
            doc('users/u1/level_progress/zip', {
              levels: map({ zip_1_01: map({ stars: int(3), bestSeconds: int(14) }) }),
              updatedAt: ts('2026-11-01T10:00:00Z'),
            }),
            doc('users/u1/level_progress/sudoku', { levels: map({}) }),
          ]);
        }
        return Response.json([
          doc('users/u1/level_stats/zip', {
            levels: map({ zip_1_01: map({ starts: int(2), clears: int(1), lastPlayedAt: ts('2026-11-02T10:00:00Z') }) }),
            updatedAt: ts('2026-11-02T10:00:00Z'),
          }),
          doc('users/u2/level_stats/zip', { levels: map({ zip_1_01: map({ starts: int(1) }) }), updatedAt: ts('2026-11-02T09:00:00Z') }),
        ]);
      }),
    );

    const result = await new LevelsStore('p', 'tok').progress('zip');

    expect(calls).toHaveLength(2);
    expect(calls[0].url).toBe(`https://firestore.googleapis.com/v1/${ROOT}:runQuery`);
    expect(calls[0].body.structuredQuery.from).toEqual([{ collectionId: 'level_progress', allDescendants: true }]);
    expect(result.truncated).toBe(false);
    expect(result.players).toEqual([
      {
        uid: 'u1',
        records: { zip_1_01: { stars: 3, bestSeconds: 14 } },
        counters: { zip_1_01: { starts: 2, clears: 1, hints: 0, lastPlayedAt: '2026-11-02T10:00:00Z' } },
        hasCounters: true,
        updatedAt: '2026-11-02T10:00:00Z',
      },
      {
        uid: 'u2',
        records: {},
        counters: { zip_1_01: { starts: 1, clears: 0, hints: 0, lastPlayedAt: null } },
        hasCounters: true,
        updatedAt: '2026-11-02T09:00:00Z',
      },
    ]);
  });

  it('pages with a __name__ cursor until a short page', async () => {
    const page = (from: number, n: number) =>
      Array.from({ length: n }, (_, i) =>
        doc(`users/u${from + i}/level_progress/zip`, { levels: map({}), updatedAt: ts('2026-11-01T00:00:00Z') }),
      );
    const bodies: any[] = [];
    vi.stubGlobal(
      'fetch',
      vi.fn(async (_url: string, init: RequestInit) => {
        const body = JSON.parse(String(init.body));
        bodies.push(body);
        if (body.structuredQuery.from[0].collectionId === 'level_stats') return Response.json([{ readTime: 'x' }]);
        return Response.json(body.structuredQuery.startAt ? page(500, 3) : page(0, 500));
      }),
    );

    const result = await new LevelsStore('p', 'tok').progress('zip');

    const progressBodies = bodies.filter((b) => b.structuredQuery.from[0].collectionId === 'level_progress');
    expect(progressBodies).toHaveLength(2);
    expect(progressBodies[1].structuredQuery.startAt).toEqual({
      values: [{ referenceValue: `${ROOT}/users/u499/level_progress/zip` }],
      before: false,
    });
    expect(result.players).toHaveLength(503);
    expect(result.players[0].hasCounters).toBe(false);
  });

  it('throws firestore_ errors so the route answers 502', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('nope', { status: 403 })));
    await expect(new LevelsStore('p', 'tok').progress('zip')).rejects.toThrow(/^firestore_levels_query_failed:403/);
  });

  it('reads one player from both docs; null when neither exists', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        if (url.endsWith('/users/u1/level_progress/zip')) {
          return Response.json({
            name: `${ROOT}/users/u1/level_progress/zip`,
            fields: { levels: map({ zip_1_01: map({ stars: int(2), bestSeconds: int(20) }) }), updatedAt: ts('2026-11-01T00:00:00Z') },
          });
        }
        return new Response('{}', { status: 404 });
      }),
    );
    const store = new LevelsStore('p', 'tok');
    expect(await store.player('zip', 'u1')).toEqual({
      uid: 'u1',
      records: { zip_1_01: { stars: 2, bestSeconds: 20 } },
      counters: {},
      hasCounters: false,
      updatedAt: '2026-11-01T00:00:00Z',
    });
    expect(await store.player('zip', 'nobody')).toBeNull();
  });

  it('lists the game\'s worlds by order', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        Response.json([
          doc('level_worlds/zip_2', { game: str('zip'), order: int(2), theme: str('metro'), title: str('Metro'), published: { booleanValue: false } }),
          doc('level_worlds/zip_1', { game: str('zip'), order: int(1), theme: str('ink'), title: str('Ink'), published: { booleanValue: true } }),
          doc('level_worlds/sudoku_1', { game: str('sudoku'), order: int(1) }),
        ]),
      ),
    );
    const worlds = await new LevelsStore('p', 'tok').worlds('zip');
    expect(worlds.map((w) => w.id)).toEqual(['zip_1', 'zip_2']);
    expect(worlds[1]).toMatchObject({ published: false, levels: [], updatedAt: null });
  });
});
```

- [ ] **Step 3: Run to see them fail**

Run: `cd workers/admin-api && npx vitest run src/levels.test.ts`
Expected: FAIL — `./levels` does not exist.

- [ ] **Step 4: Write `levels.ts`**

`workers/admin-api/src/levels.ts`:

```ts
import { firestoreValueToJs } from './content_cms';

/** Games with Levels. Path Words and Sudoku join this list when they get levels. */
export const LEVEL_GAMES = ['zip'] as const;
export type LevelGame = (typeof LEVEL_GAMES)[number];

export function isLevelGame(game: string): game is LevelGame {
  return (LEVEL_GAMES as readonly string[]).includes(game);
}

export type WorldLevelSummary = { id: string; size: number; targetSeconds: number | null };

export type WorldSummary = {
  id: string;
  game: string;
  order: number;
  theme: string;
  title: string;
  published: boolean;
  updatedAt: string | null;
  levels: WorldLevelSummary[];
};

export type LevelRecord = { stars: number; bestSeconds: number };
export type LevelCounters = { starts: number; clears: number; hints: number; lastPlayedAt: string | null };

export type PlayerLevels = {
  uid: string;
  records: Record<string, LevelRecord>;
  counters: Record<string, LevelCounters>;
  /** False when the player has no level_stats doc (no play since the app started counting). */
  hasCounters: boolean;
  /** The later of the two docs' updatedAt. */
  updatedAt: string | null;
};

export type ProgressResult = { players: PlayerLevels[]; truncated: boolean };

type FirestoreDoc = { name: string; fields?: Record<string, unknown> };

/** Each runQuery page; one Worker subrequest. */
export const PAGE_SIZE = 500;
/** Pages per collection group. CPU on the Workers Free plan (~10 ms) is the binding limit, not subrequests: see the Task 6 review note. */
export const MAX_PAGES = 2;

function isNumber(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v);
}

function fieldsToJs(fields: Record<string, unknown> | undefined): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(fields ?? {})) out[k] = firestoreValueToJs(v);
  return out;
}

function asMap(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

function asString(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

function later(a: string | null, b: string | null): string | null {
  if (!a) return b;
  if (!b) return a;
  return a > b ? a : b;
}

/** `…/documents/users/{uid}/{collection}/{game}` → uid; null for any other path. */
export function uidFromPath(name: string, collection: string, game: string): string | null {
  const at = name.indexOf('/documents/');
  if (at < 0) return null;
  const parts = name.slice(at + '/documents/'.length).split('/');
  if (parts.length !== 4 || parts[0] !== 'users' || parts[2] !== collection || parts[3] !== game) return null;
  return parts[1] || null;
}

/** The app's rules: stars 1–3, best time >= 1 s; whole-number doubles truncate. */
export function trimRecords(levels: unknown): Record<string, LevelRecord> {
  const out: Record<string, LevelRecord> = {};
  for (const [id, raw] of Object.entries(asMap(levels))) {
    const r = asMap(raw);
    if (!isNumber(r.stars) || !isNumber(r.bestSeconds)) continue;
    const stars = Math.trunc(r.stars);
    const bestSeconds = Math.trunc(r.bestSeconds);
    if (stars < 1 || stars > 3 || bestSeconds < 1) continue;
    out[id] = { stars, bestSeconds };
  }
  return out;
}

function counter(v: unknown): number {
  return isNumber(v) && Number.isInteger(v) && v >= 0 ? v : 0;
}

/** Counters must be whole numbers >= 0; anything else counts as 0. Non-map entries are dropped. */
export function trimCounters(levels: unknown): Record<string, LevelCounters> {
  const out: Record<string, LevelCounters> = {};
  for (const [id, raw] of Object.entries(asMap(levels))) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const c = raw as Record<string, unknown>;
    out[id] = {
      starts: counter(c.starts),
      clears: counter(c.clears),
      hints: counter(c.hints),
      lastPlayedAt: asString(c.lastPlayedAt),
    };
  }
  return out;
}

/** A `level_worlds` doc without its boards; null without a game or an order. */
export function worldFromDoc(name: string, fields: Record<string, unknown> | undefined): WorldSummary | null {
  const data = fieldsToJs(fields);
  const game = asString(data.game);
  if (!game || !isNumber(data.order)) return null;
  const levels = Array.isArray(data.levels) ? data.levels : [];
  return {
    id: name.split('/').pop() || name,
    game,
    order: Math.trunc(data.order),
    theme: asString(data.theme) ?? '',
    title: asString(data.title) ?? '',
    published: data.published === true,
    updatedAt: asString(data.updatedAt),
    levels: levels.flatMap((raw) => {
      const l = asMap(raw);
      const id = asString(l.id);
      if (!id) return [];
      const target = isNumber(l.targetSeconds) && l.targetSeconds >= 1 ? Math.trunc(l.targetSeconds) : null;
      return [{ id, size: isNumber(l.size) ? Math.trunc(l.size) : 0, targetSeconds: target }];
    }),
  };
}

export class LevelsStore {
  constructor(
    private readonly projectId: string,
    private readonly accessToken: string,
  ) {}

  private root(): string {
    return `projects/${this.projectId}/databases/(default)/documents`;
  }

  private async runQuery(structuredQuery: unknown): Promise<FirestoreDoc[]> {
    const res = await fetch(`https://firestore.googleapis.com/v1/${this.root()}:runQuery`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery }),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`firestore_levels_query_failed:${res.status}:${text.slice(0, 300)}`);
    const rows = JSON.parse(text) as Array<{ document?: FirestoreDoc }>;
    return rows.flatMap((r) => (r.document?.name ? [r.document] : []));
  }

  private async getDoc(path: string): Promise<FirestoreDoc | null> {
    const res = await fetch(`https://firestore.googleapis.com/v1/${this.root()}/${path}`, {
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });
    if (res.status === 404) return null;
    const text = await res.text();
    if (!res.ok) throw new Error(`firestore_levels_get_failed:${res.status}:${text.slice(0, 300)}`);
    return JSON.parse(text) as FirestoreDoc;
  }

  /** Every doc in a collection group, by name, PAGE_SIZE at a time; truncated after MAX_PAGES. */
  private async collectionGroup(collectionId: string): Promise<{ docs: FirestoreDoc[]; truncated: boolean }> {
    const docs: FirestoreDoc[] = [];
    let last: string | null = null;
    for (let page = 0; page < MAX_PAGES; page++) {
      const batch = await this.runQuery({
        from: [{ collectionId, allDescendants: true }],
        orderBy: [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
        limit: PAGE_SIZE,
        ...(last ? { startAt: { values: [{ referenceValue: last }], before: false } } : {}),
      });
      docs.push(...batch);
      if (batch.length < PAGE_SIZE) return { docs, truncated: false };
      last = batch[batch.length - 1].name;
    }
    return { docs, truncated: true };
  }

  async worlds(game: LevelGame): Promise<WorldSummary[]> {
    const docs = await this.runQuery({ from: [{ collectionId: 'level_worlds' }] });
    return docs
      .flatMap((d) => {
        const w = worldFromDoc(d.name, d.fields);
        return w && w.game === game ? [w] : [];
      })
      .sort((a, b) => a.order - b.order);
  }

  async progress(game: LevelGame): Promise<ProgressResult> {
    const [progress, stats] = await Promise.all([this.collectionGroup('level_progress'), this.collectionGroup('level_stats')]);
    const players = new Map<string, PlayerLevels>();
    const entry = (uid: string): PlayerLevels => {
      let p = players.get(uid);
      if (!p) {
        p = { uid, records: {}, counters: {}, hasCounters: false, updatedAt: null };
        players.set(uid, p);
      }
      return p;
    };
    for (const d of progress.docs) {
      const uid = uidFromPath(d.name, 'level_progress', game);
      if (!uid) continue;
      const data = fieldsToJs(d.fields);
      const p = entry(uid);
      p.records = trimRecords(data.levels);
      p.updatedAt = later(p.updatedAt, asString(data.updatedAt));
    }
    for (const d of stats.docs) {
      const uid = uidFromPath(d.name, 'level_stats', game);
      if (!uid) continue;
      const data = fieldsToJs(d.fields);
      const p = entry(uid);
      p.counters = trimCounters(data.levels);
      p.hasCounters = true;
      p.updatedAt = later(p.updatedAt, asString(data.updatedAt));
    }
    return {
      players: [...players.values()].sort((a, b) => (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0)),
      truncated: progress.truncated || stats.truncated,
    };
  }

  async player(game: LevelGame, uid: string): Promise<PlayerLevels | null> {
    const id = encodeURIComponent(uid);
    const [progress, stats] = await Promise.all([
      this.getDoc(`users/${id}/level_progress/${game}`),
      this.getDoc(`users/${id}/level_stats/${game}`),
    ]);
    if (!progress && !stats) return null;
    const p = fieldsToJs(progress?.fields);
    const s = fieldsToJs(stats?.fields);
    return {
      uid,
      records: trimRecords(p.levels),
      counters: trimCounters(s.levels),
      hasCounters: stats !== null,
      updatedAt: later(asString(p.updatedAt), asString(s.updatedAt)),
    };
  }
}
```

Note on `firestoreValueToJs`: it turns a map shaped exactly `{row, col}` into `[row, col]`. Records and counters never have that shape, so trimming is unaffected.

- [ ] **Step 5: Run to see them pass**

Run: `cd workers/admin-api && npx vitest run src/levels.test.ts && npm run typecheck`
Expected: all PASS, typecheck clean.

- [ ] **Step 6: Commit**

```bash
git add workers/admin-api/src/levels.ts workers/admin-api/src/levels.test.ts
git commit -m "feat(worker): read level worlds and players' level progress and play counters

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: admin-api routes

**Files:**
- Modify: `workers/admin-api/src/index.ts` (import near the other module imports; routes just before the final `return jsonResponse({ error: "not_found" }, 404, cors);`, ~line 1237)
- Test: `workers/admin-api/src/levels.routes.test.ts`

- [ ] **Step 1: Write the failing route tests**

`workers/admin-api/src/levels.routes.test.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./admin_auth', () => ({
  AdminAuthError: class AdminAuthError extends Error {
    constructor(
      readonly status: 401 | 403,
      message: string,
    ) {
      super(message);
    }
  },
  verifyAdmin: vi.fn(),
}));

import { AdminAuthError, verifyAdmin } from './admin_auth';
import worker, { type Env } from './index';

const env: Env = {
  FIREBASE_PROJECT_ID: 'brain-zip-app',
  ALLOWED_ORIGINS: 'http://localhost:5173',
  FIREBASE_ACCESS_TOKEN: 'test-token',
  AI: { run: vi.fn() } as unknown as Ai,
};
const ROOT = 'projects/brain-zip-app/databases/(default)/documents';
const get = (path: string) => worker.fetch(new Request(`https://api.example${path}`), env);

beforeEach(() => {
  vi.mocked(verifyAdmin).mockReset();
  vi.mocked(verifyAdmin).mockResolvedValue({ uid: 'ops', email: 'ops@winklo.game', admin: true } as never);
});
afterEach(() => vi.unstubAllGlobals());

describe('GET /v1/levels/:game/...', () => {
  it('refuses a game without levels before touching Firestore', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    for (const path of ['/v1/levels/chess/worlds', '/v1/levels/sudoku/progress', '/v1/levels/x/players/u1']) {
      const res = await get(path);
      expect(res.status, path).toBe(400);
      expect(await res.json()).toEqual({ error: 'invalid_game' });
    }
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('needs an admin', async () => {
    vi.mocked(verifyAdmin).mockRejectedValueOnce(new AdminAuthError(403, 'forbidden'));
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    expect((await get('/v1/levels/zip/progress')).status).toBe(403);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('lists worlds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        Response.json([
          { document: { name: `${ROOT}/level_worlds/zip_1`, fields: { game: { stringValue: 'zip' }, order: { integerValue: '1' } } } },
        ]),
      ),
    );
    const res = await get('/v1/levels/zip/worlds');
    expect(res.status).toBe(200);
    const body = (await res.json()) as { worlds: Array<{ id: string }> };
    expect(body.worlds.map((w) => w.id)).toEqual(['zip_1']);
  });

  it('returns progress rows and the truncated flag', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json([{ readTime: 'x' }])));
    const res = await get('/v1/levels/zip/progress');
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ players: [], truncated: false });
  });

  it('returns one player, 404 when they have no level docs', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 404 })));
    const res = await get('/v1/levels/zip/players/u1');
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: 'player_not_found' });
  });

  it('refuses a malformed uid', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    const res = await get(`/v1/levels/zip/players/${'x'.repeat(129)}`);
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: 'invalid_uid' });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('maps a Firestore failure to 502', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('boom', { status: 500 })));
    const res = await get('/v1/levels/zip/progress');
    expect(res.status).toBe(502);
  });

  it('answers 404 for other methods and paths under /v1/levels', async () => {
    vi.stubGlobal('fetch', vi.fn());
    const res = await worker.fetch(new Request('https://api.example/v1/levels/zip/progress', { method: 'POST' }), env);
    expect(res.status).toBe(404);
  });
});
```

(If `verifyAdmin`'s resolved type differs, copy the exact `mockResolvedValue` shape from `platform_users_lookup.routes.test.ts`.)

- [ ] **Step 2: Run to see them fail**

Run: `cd workers/admin-api && npx vitest run src/levels.routes.test.ts`
Expected: FAIL (404 `not_found` where 200/400 expected).

- [ ] **Step 3: Add the routes**

In `index.ts`, import:

```ts
import { isLevelGame, LevelsStore } from "./levels";
```

Just before the final `return jsonResponse({ error: "not_found" }, 404, cors);`:

```ts
      // Levels (read-only): worlds, every player's progress and play
      // counters, one player. The game is checked before admin auth, like
      // /v1/content/:collection.
      const levelsMatch = url.pathname.match(/^\/v1\/levels\/([a-z_]+)\/(worlds|progress)$/);
      const levelPlayerMatch = url.pathname.match(/^\/v1\/levels\/([a-z_]+)\/players\/([^/]+)$/);
      if (request.method === "GET" && (levelsMatch || levelPlayerMatch)) {
        const game = (levelsMatch ?? levelPlayerMatch)![1];
        if (!isLevelGame(game)) {
          return jsonResponse({ error: "invalid_game" }, 400, cors);
        }
        let uid: string | null = null;
        if (levelPlayerMatch) {
          uid = decodeURIComponent(levelPlayerMatch[2]);
          if (uid.length === 0 || uid.length > 128 || uid.includes("/")) {
            return jsonResponse({ error: "invalid_uid" }, 400, cors);
          }
        }
        const { token } = await requireAdmin(request, env);
        const store = new LevelsStore(env.FIREBASE_PROJECT_ID, token);
        if (uid !== null) {
          const player = await store.player(game, uid);
          if (!player) return jsonResponse({ error: "player_not_found" }, 404, cors);
          return jsonResponse({ player }, 200, cors);
        }
        if (levelsMatch![2] === "worlds") {
          return jsonResponse({ worlds: await store.worlds(game) }, 200, cors);
        }
        return jsonResponse(await store.progress(game), 200, cors);
      }
```

- [ ] **Step 4: Run the Worker suite**

Run: `cd workers/admin-api && npm run typecheck && npm test`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add workers/admin-api/src/index.ts workers/admin-api/src/levels.routes.test.ts
git commit -m "feat(worker): GET level worlds, level progress and one player's levels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Client API, mocks and queries

**Files:**
- Modify: `src/lib/adminApi.ts` (after `lookupPlatformUsers`, ~line 601)
- Create: `src/mocks/levels.ts`; Modify: `src/mocks/mockMode.ts` (add `'levels'` to `MockDomain`), `src/mocks/mockApi.ts` (add `levels: levelsMock`)
- Modify: `src/queries/keys.ts`; Create: `src/queries/levels.ts`
- Test: `src/queries/levels.test.tsx`, `src/mocks/levels.test.ts`

- [ ] **Step 1: Types and fetchers in `adminApi.ts`**

```ts
// --- Levels (read-only) ---------------------------------------------------

export type LevelWorldLevel = { id: string; size: number; targetSeconds: number | null };
export type LevelWorldSummary = {
  id: string;
  game: string;
  order: number;
  theme: string;
  title: string;
  published: boolean;
  updatedAt: string | null;
  levels: LevelWorldLevel[];
};
export type LevelRecord = { stars: number; bestSeconds: number };
export type LevelCounters = { starts: number; clears: number; hints: number; lastPlayedAt: string | null };
export type PlayerLevels = {
  uid: string;
  records: Record<string, LevelRecord>;
  counters: Record<string, LevelCounters>;
  hasCounters: boolean;
  updatedAt: string | null;
};
export type LevelProgressResponse = { players: PlayerLevels[]; truncated: boolean };

export async function fetchLevelWorlds(idToken: string, game: string): Promise<LevelWorldSummary[]> {
  const res = await adminFetch(idToken, `/v1/levels/${encodeURIComponent(game)}/worlds`);
  if (!res.ok) throw await ApiError.fromResponse(res, `level_worlds_failed_${res.status}`);
  return ((await res.json()) as { worlds: LevelWorldSummary[] }).worlds;
}

export async function fetchLevelProgress(idToken: string, game: string): Promise<LevelProgressResponse> {
  const res = await adminFetch(idToken, `/v1/levels/${encodeURIComponent(game)}/progress`);
  if (!res.ok) throw await ApiError.fromResponse(res, `level_progress_failed_${res.status}`);
  return (await res.json()) as LevelProgressResponse;
}

/** Null when the player has never played Levels (404). */
export async function fetchLevelPlayer(idToken: string, game: string, uid: string): Promise<PlayerLevels | null> {
  const res = await adminFetch(idToken, `/v1/levels/${encodeURIComponent(game)}/players/${encodeURIComponent(uid)}`);
  if (res.status === 404) return null;
  if (!res.ok) throw await ApiError.fromResponse(res, `level_player_failed_${res.status}`);
  return ((await res.json()) as { player: PlayerLevels }).player;
}
```

Careful: `fetchLevelPlayer` treats every 404 as "never played". The Worker answers 404 `player_not_found` for that, and 404 `not_found` only for unknown paths, which this client never builds.

- [ ] **Step 2: The mock**

`src/mocks/levels.ts` — deterministic, so page tests can assert numbers:

```ts
import type { LevelProgressResponse, LevelWorldSummary, PlayerLevels } from '../lib/adminApi';
import { shouldBeEmpty } from './mockMode';

const level = (world: number, n: number, size: number, targetSeconds: number | null = size * size + 4) => ({
  id: `zip_${world}_${String(n).padStart(2, '0')}`,
  size,
  targetSeconds,
});

/** Ink (published, 5 levels), Metro (published, 5), Embroidery (draft, 3). */
export const MOCK_WORLDS: LevelWorldSummary[] = [
  {
    id: 'zip_1', game: 'zip', order: 1, theme: 'ink', title: 'Ink', published: true,
    updatedAt: '2026-10-31T08:00:00Z', levels: [1, 2, 3, 4, 5].map((n) => level(1, n, 4)),
  },
  {
    id: 'zip_2', game: 'zip', order: 2, theme: 'metro', title: 'Metro', published: true,
    updatedAt: '2026-10-31T09:00:00Z', levels: [1, 2, 3, 4, 5].map((n) => level(2, n, 5, n === 5 ? null : 30)),
  },
  {
    id: 'zip_3', game: 'zip', order: 3, theme: 'embroidery', title: 'Embroidery', published: false,
    updatedAt: null, levels: [1, 2, 3].map((n) => level(3, n, 6)),
  },
];

const rec = (stars: number, bestSeconds: number) => ({ stars, bestSeconds });
const cnt = (starts: number, clears: number, hints = 0, lastPlayedAt: string | null = '2026-11-02T10:00:00Z') => ({
  starts, clears, hints, lastPlayedAt,
});

/**
 * u_ada: all of Ink, two of Metro; u_ben: stuck on Level 3 (many tries);
 * u_cy: everything cleared, counters; u_dee: one clear before counting began
 * (no counters); u_gone: an account that no longer exists in Auth.
 */
export const MOCK_PLAYERS: PlayerLevels[] = [
  {
    uid: 'u_ada',
    records: {
      zip_1_01: rec(3, 12), zip_1_02: rec(3, 15), zip_1_03: rec(2, 25), zip_1_04: rec(3, 18), zip_1_05: rec(1, 40),
      zip_2_01: rec(2, 35), zip_2_02: rec(3, 28),
    },
    counters: {
      zip_1_01: cnt(1, 1), zip_1_02: cnt(1, 1), zip_1_03: cnt(2, 1, 1), zip_1_04: cnt(1, 1), zip_1_05: cnt(3, 1, 2),
      zip_2_01: cnt(1, 1), zip_2_02: cnt(1, 1), zip_2_03: cnt(2, 0, 0, '2026-11-02T11:00:00Z'),
    },
    hasCounters: true,
    updatedAt: '2026-11-02T11:00:00Z',
  },
  {
    uid: 'u_ben',
    records: { zip_1_01: rec(2, 22), zip_1_02: rec(1, 50) },
    counters: { zip_1_01: cnt(2, 1), zip_1_02: cnt(1, 1, 1), zip_1_03: cnt(6, 0, 3, '2026-11-01T20:00:00Z') },
    hasCounters: true,
    updatedAt: '2026-11-01T20:00:00Z',
  },
  {
    uid: 'u_cy',
    records: Object.fromEntries(
      MOCK_WORLDS.filter((w) => w.published).flatMap((w) => w.levels.map((l) => [l.id, rec(3, 10)])),
    ),
    counters: Object.fromEntries(
      MOCK_WORLDS.filter((w) => w.published).flatMap((w) => w.levels.map((l) => [l.id, cnt(1, 1, 0, '2026-10-30T10:00:00Z')])),
    ),
    hasCounters: true,
    updatedAt: '2026-10-30T10:00:00Z',
  },
  {
    uid: 'u_dee',
    records: { zip_1_01: rec(1, 60) },
    counters: {},
    hasCounters: false,
    updatedAt: '2026-10-29T10:00:00Z',
  },
  {
    uid: 'u_gone',
    records: { zip_1_01: rec(2, 30) },
    counters: { zip_1_01: cnt(1, 1, 0, '2026-10-28T10:00:00Z') },
    hasCounters: true,
    updatedAt: '2026-10-28T10:00:00Z',
  },
];

/** Names the mock "Auth lookup" knows; u_gone has no account. */
export const MOCK_LEVEL_NAMES: Record<string, { displayName: string | null; email: string | null }> = {
  u_ada: { displayName: 'Ada Lovelace', email: 'ada@example.com' },
  u_ben: { displayName: 'Ben Okafor', email: 'ben@example.com' },
  u_cy: { displayName: null, email: 'cy@example.com' },
  u_dee: { displayName: 'Dee', email: null },
};

export const levelsMock = {
  worlds(game: string): LevelWorldSummary[] {
    if (shouldBeEmpty('levels') || game !== 'zip') return [];
    return MOCK_WORLDS;
  },
  progress(game: string): LevelProgressResponse {
    if (shouldBeEmpty('levels') || game !== 'zip') return { players: [], truncated: false };
    return { players: MOCK_PLAYERS, truncated: false };
  },
  player(game: string, uid: string): PlayerLevels | null {
    if (shouldBeEmpty('levels') || game !== 'zip') return null;
    return MOCK_PLAYERS.find((p) => p.uid === uid) ?? null;
  },
  names(uids: string[]): Record<string, { displayName: string | null; email: string | null }> {
    return Object.fromEntries(uids.filter((u) => u in MOCK_LEVEL_NAMES).map((u) => [u, MOCK_LEVEL_NAMES[u]]));
  },
};
```

Add `'levels'` to `MockDomain` in `mockMode.ts`, and `levels: levelsMock,` to `mockApi` in `mockApi.ts` (it keeps no state, so `resetMockStores` needs nothing). If `mockMode.test.ts` lists every domain, add `'levels'` there too.

- [ ] **Step 3: Keys**

In `src/queries/keys.ts` add to `qk`:

```ts
  levels: {
    all: () => ['levels'] as const,
    worlds: (game: string) => ['levels', 'worlds', game] as const,
    progress: (game: string) => ['levels', 'progress', game] as const,
    player: (game: string, uid: string) => ['levels', 'player', game, uid] as const,
    names: (uids: readonly string[]) => ['levels', 'names', ...uids] as const,
  },
```

- [ ] **Step 4: Write the failing query test**

`src/queries/levels.test.tsx`:

```tsx
// @vitest-environment jsdom
import { renderHook, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetMockStores } from '../mocks/mockApi';
import { createWrapper } from '../test/render';
import { useLevelNames, useLevelProgress, useLevelWorlds } from './levels';

vi.mock('../lib/firebase', () => ({ db: {}, auth: {} }));

beforeEach(() => {
  localStorage.setItem('winklo_mock_admin', 'true');
  localStorage.setItem('winklo_mock_latency', '0');
});
afterEach(() => {
  resetMockStores();
  localStorage.clear();
});

describe('levels queries', () => {
  it('loads worlds and progress from the mock', async () => {
    const wrapper = createWrapper();
    const worlds = renderHook(() => useLevelWorlds('zip'), { wrapper });
    const progress = renderHook(() => useLevelProgress('zip'), { wrapper });
    await waitFor(() => expect(worlds.result.current.data).toHaveLength(3));
    await waitFor(() => expect(progress.result.current.data?.players).toHaveLength(5));
  });

  it('looks up names; an account with no Auth record has none', async () => {
    const { result } = renderHook(() => useLevelNames(['u_ada', 'u_gone']), { wrapper: createWrapper() });
    await waitFor(() => expect(result.current.data).toBeDefined());
    expect(result.current.data).toEqual({ u_ada: { displayName: 'Ada Lovelace', email: 'ada@example.com' } });
  });
});
```

Find how existing query tests wrap hooks (`grep -rn "renderHook" src/queries | head -3`) and use that wrapper instead of `createWrapper` if it is named differently (the test needs an auth context that yields an idToken in mock mode, plus a QueryClient).

- [ ] **Step 5: Run to see it fail**

Run: `npx vitest run src/queries/levels.test.tsx`
Expected: FAIL — `./levels` does not exist.

- [ ] **Step 6: Write the queries**

`src/queries/levels.ts`:

```ts
import { keepPreviousData } from '@tanstack/react-query';
import { fetchLevelPlayer, fetchLevelProgress, fetchLevelWorlds, lookupPlatformUsers } from '../lib/adminApi';
import { qk } from './keys';
import { fromSource } from './source';
import { useAuthedQuery } from './useAuthedQuery';

/** Level data changes slowly and a load reads every player's docs: cache for 5 minutes. */
const LEVELS_STALE_MS = 5 * 60_000;
const LOOKUP_BATCH = 100;

export type LevelName = { displayName: string | null; email: string | null };

export function useLevelWorlds(game: string) {
  return useAuthedQuery({
    queryKey: qk.levels.worlds(game),
    queryFn: ({ idToken }) =>
      fromSource('levels', () => fetchLevelWorlds(idToken, game), (api) => api.levels.worlds(game)),
    staleTime: LEVELS_STALE_MS,
  });
}

export function useLevelProgress(game: string) {
  return useAuthedQuery({
    queryKey: qk.levels.progress(game),
    queryFn: ({ idToken }) =>
      fromSource('levels', () => fetchLevelProgress(idToken, game), (api) => api.levels.progress(game)),
    staleTime: LEVELS_STALE_MS,
  });
}

export function useLevelPlayer(game: string, uid: string) {
  return useAuthedQuery({
    queryKey: qk.levels.player(game, uid),
    queryFn: ({ idToken }) =>
      fromSource('levels', () => fetchLevelPlayer(idToken, game, uid), (api) => api.levels.player(game, uid)),
    staleTime: LEVELS_STALE_MS,
  });
}

function chunks<T>(list: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** Auth names for [uids], in batches of 100; a uid with no account is absent from the result. */
export function useLevelNames(uids: string[]) {
  const sorted = [...new Set(uids)].sort();
  return useAuthedQuery({
    queryKey: qk.levels.names(sorted),
    enabled: sorted.length > 0,
    queryFn: ({ idToken }) =>
      fromSource(
        'levels',
        async () => {
          const batches = await Promise.all(chunks(sorted, LOOKUP_BATCH).map((b) => lookupPlatformUsers(idToken, b)));
          return Object.fromEntries(
            batches.flat().map((u): [string, LevelName] => [u.uid, { displayName: u.displayName, email: u.email }]),
          );
        },
        (api) => api.levels.names(sorted),
      ),
    staleTime: LEVELS_STALE_MS,
    placeholderData: keepPreviousData,
  });
}
```

- [ ] **Step 7: Run, then the SPA gates**

Run: `npx vitest run src/queries/levels.test.tsx src/mocks && npm run typecheck:tests && npm run lint`
Expected: PASS, lint at or under 26 warnings.

- [ ] **Step 8: Commit**

```bash
git add src/lib/adminApi.ts src/mocks/ src/queries/
git commit -m "feat(levels): client API, mock data and queries for level worlds and progress

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `levelsModel.ts` — all the counting

**Files:**
- Create: `src/pages/levels/levelsModel.ts`
- Test: `src/pages/levels/levelsModel.test.ts`

Definitions (from the spec):

- **Map levels**: published worlds by `order`, their levels in order; `number` runs on across worlds (World 2's first level after five Ink levels is Level 6). Unpublished worlds are not on the map.
- **Current level**: the first map level the player hasn't cleared; none when all are cleared.
- **Reached** (per player, per level): the first level, or the level before it is cleared, or the level itself is cleared.
- **Counter sums** cover map levels only, and are null for a player without counters.
- **Unfinished** = Σ `max(0, starts − clears)`.
- **Last played** = latest `lastPlayedAt` over the player's counters, else `updatedAt`.

- [ ] **Step 1: Write the failing tests**

`src/pages/levels/levelsModel.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { MOCK_PLAYERS, MOCK_WORLDS } from '../../mocks/levels';
import {
  countersCoverage,
  dropOff,
  levelStats,
  mapLevels,
  median,
  playerLevelRows,
  summarizePlayer,
  worldStats,
} from './levelsModel';

const levels = mapLevels(MOCK_WORLDS);
const player = (uid: string) => MOCK_PLAYERS.find((p) => p.uid === uid)!;

describe('mapLevels', () => {
  it('numbers published levels across worlds and leaves drafts off', () => {
    expect(levels).toHaveLength(10);
    expect(levels[0]).toMatchObject({ id: 'zip_1_01', number: 1, worldOrder: 1, theme: 'ink', size: 4 });
    expect(levels[5]).toMatchObject({ id: 'zip_2_01', number: 6, worldOrder: 2, theme: 'metro' });
    expect(levels.some((l) => l.id.startsWith('zip_3_'))).toBe(false);
  });

  it('sorts worlds by order whatever order they arrive in', () => {
    expect(mapLevels([...MOCK_WORLDS].reverse())[0].id).toBe('zip_1_01');
  });
});

describe('median', () => {
  it('is the middle value, the mean of the two middles, or null', () => {
    expect(median([5, 1, 3])).toBe(3);
    expect(median([4, 1, 3, 2])).toBe(2.5);
    expect(median([])).toBeNull();
  });
});

describe('summarizePlayer', () => {
  it('counts clears, stars and counters over map levels', () => {
    const s = summarizePlayer(levels, player('u_ada'));
    expect(s.current?.id).toBe('zip_2_03');
    expect(s.allCleared).toBe(false);
    expect(s.cleared).toBe(7);
    expect(s.total).toBe(10);
    expect(s.stars).toBe(17);
    expect(s.maxStars).toBe(30);
    expect(s.starts).toBe(12);
    expect(s.unfinished).toBe(5); // 1_03: 1, 1_05: 2, 2_03: 2
    expect(s.hints).toBe(3);
    expect(s.lastPlayed).toBe('2026-11-02T11:00:00Z');
  });

  it('marks all cleared', () => {
    const s = summarizePlayer(levels, player('u_cy'));
    expect(s.current).toBeNull();
    expect(s.allCleared).toBe(true);
    expect(s.cleared).toBe(10);
  });

  it('has null counters without a stats doc, and falls back to updatedAt', () => {
    const s = summarizePlayer(levels, player('u_dee'));
    expect(s.starts).toBeNull();
    expect(s.unfinished).toBeNull();
    expect(s.hints).toBeNull();
    expect(s.lastPlayed).toBe('2026-10-29T10:00:00Z');
  });

  it('ignores records for levels not on the map', () => {
    const s = summarizePlayer(levels, { ...player('u_dee'), records: { zip_3_01: { stars: 3, bestSeconds: 9 } } });
    expect(s.cleared).toBe(0);
    expect(s.current?.id).toBe('zip_1_01');
  });
});

describe('playerLevelRows', () => {
  it('marks reached levels: the first, after a clear, or cleared', () => {
    const rows = playerLevelRows(levels, player('u_ben'));
    expect(rows.map((r) => r.reached)).toEqual([true, true, true, false, false, false, false, false, false, false]);
    expect(rows[2]).toMatchObject({ record: null, counters: { starts: 6, clears: 0, hints: 3 } });
  });
});

describe('levelStats', () => {
  const stats = levelStats(levels, MOCK_PLAYERS);
  const at = (id: string) => stats.find((s) => s.level.id === id)!;

  it('Level 1: everyone reached and cleared it', () => {
    expect(at('zip_1_01')).toMatchObject({ reached: 5, cleared: 5, clearRate: 1 });
    expect(at('zip_1_01').avgStars).toBeCloseTo((3 + 2 + 3 + 1 + 2) / 5);
    expect(at('zip_1_01').threeStarShare).toBeCloseTo(2 / 5);
    expect(at('zip_1_01').medianBest).toBe(22);
  });

  it('Level 3: Ben is stuck — reached by three, cleared by two, many tries', () => {
    const s = at('zip_1_03');
    expect(s).toMatchObject({ reached: 3, cleared: 2 });
    expect(s.clearRate).toBeCloseTo(2 / 3);
    // starts: ada 2, ben 6, cy 1 = 9; clears: 1 + 0 + 1 = 2
    expect(s.triesPerClear).toBeCloseTo(9 / 2);
    expect(s.unfinished).toBe(1 + 6);
  });

  it('a level nobody cleared has null rates', () => {
    const s = at('zip_2_05');
    expect(s.cleared).toBe(1);
    const none = levelStats(levels, [player('u_dee')]).find((x) => x.level.id === 'zip_2_05')!;
    expect(none).toMatchObject({ reached: 0, cleared: 0, clearRate: null, avgStars: null, medianBest: null, triesPerClear: null, unfinished: null });
  });
});

describe('worldStats', () => {
  it('reached, cleared all, stars of the possible', () => {
    const [ink, metro] = worldStats(levels, MOCK_PLAYERS);
    expect(ink).toMatchObject({ order: 1, theme: 'ink', levelCount: 5, reached: 5, clearedAll: 2 });
    expect(metro).toMatchObject({ order: 2, reached: 2, clearedAll: 1 });
    expect(metro.maxStars).toBe(2 * 5 * 3);
  });
});

describe('dropOff', () => {
  it('counts players by the furthest level cleared', () => {
    const bars = dropOff(levels, MOCK_PLAYERS);
    expect(bars).toHaveLength(10);
    const by = Object.fromEntries(bars.map((b) => [b.level.id, b.players]));
    expect(by.zip_1_01).toBe(2); // dee, gone
    expect(by.zip_1_02).toBe(1); // ben
    expect(by.zip_2_02).toBe(1); // ada
    expect(by.zip_2_05).toBe(1); // cy
  });
});

describe('countersCoverage', () => {
  it('says how many players have counters', () => {
    expect(countersCoverage(MOCK_PLAYERS)).toEqual({ withCounters: 4, total: 5 });
  });
});
```

- [ ] **Step 2: Run to see them fail**

Run: `npx vitest run src/pages/levels/levelsModel.test.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Write the model**

`src/pages/levels/levelsModel.ts`:

```ts
import type { LevelCounters, LevelRecord, LevelWorldSummary, PlayerLevels } from '../../lib/adminApi';

export type MapLevel = {
  id: string;
  /** Level N as players see it: counted across published worlds. */
  number: number;
  worldOrder: number;
  theme: string;
  size: number;
  targetSeconds: number | null;
};

export type PlayerSummary = {
  current: MapLevel | null;
  allCleared: boolean;
  cleared: number;
  total: number;
  stars: number;
  maxStars: number;
  starts: number | null;
  unfinished: number | null;
  hints: number | null;
  lastPlayed: string | null;
};

export type PlayerLevelRow = {
  level: MapLevel;
  record: LevelRecord | null;
  counters: LevelCounters | null;
  reached: boolean;
};

export type LevelStat = {
  level: MapLevel;
  reached: number;
  cleared: number;
  clearRate: number | null;
  avgStars: number | null;
  threeStarShare: number | null;
  medianBest: number | null;
  triesPerClear: number | null;
  unfinished: number | null;
};

export type WorldStat = {
  order: number;
  theme: string;
  title: string;
  levelCount: number;
  reached: number;
  clearedAll: number;
  stars: number;
  maxStars: number;
};

export type DropOffBar = { level: MapLevel; players: number };

/** The levels players see, in map order: published worlds only. */
export function mapLevels(worlds: LevelWorldSummary[]): MapLevel[] {
  const out: MapLevel[] = [];
  for (const world of [...worlds].filter((w) => w.published).sort((a, b) => a.order - b.order)) {
    for (const l of world.levels) {
      out.push({
        id: l.id,
        number: out.length + 1,
        worldOrder: world.order,
        theme: world.theme,
        size: l.size,
        targetSeconds: l.targetSeconds,
      });
    }
  }
  return out;
}

export function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function sumCounters(levels: MapLevel[], p: PlayerLevels, pick: (c: LevelCounters) => number): number | null {
  if (!p.hasCounters) return null;
  let total = 0;
  for (const l of levels) {
    const c = p.counters[l.id];
    if (c) total += pick(c);
  }
  return total;
}

const unfinishedOf = (c: LevelCounters) => Math.max(0, c.starts - c.clears);

export function summarizePlayer(levels: MapLevel[], p: PlayerLevels): PlayerSummary {
  let cleared = 0;
  let stars = 0;
  let current: MapLevel | null = null;
  for (const l of levels) {
    const r = p.records[l.id];
    if (r) {
      cleared++;
      stars += r.stars;
    } else if (!current) {
      current = l;
    }
  }
  let lastPlayed: string | null = null;
  for (const c of Object.values(p.counters)) {
    if (c.lastPlayedAt && (!lastPlayed || c.lastPlayedAt > lastPlayed)) lastPlayed = c.lastPlayedAt;
  }
  return {
    current,
    allCleared: levels.length > 0 && current === null,
    cleared,
    total: levels.length,
    stars,
    maxStars: levels.length * 3,
    starts: sumCounters(levels, p, (c) => c.starts),
    unfinished: sumCounters(levels, p, unfinishedOf),
    hints: sumCounters(levels, p, (c) => c.hints),
    lastPlayed: lastPlayed ?? p.updatedAt,
  };
}

function isReached(levels: MapLevel[], i: number, p: PlayerLevels): boolean {
  return i === 0 || levels[i].id in p.records || levels[i - 1].id in p.records;
}

export function playerLevelRows(levels: MapLevel[], p: PlayerLevels): PlayerLevelRow[] {
  return levels.map((level, i) => ({
    level,
    record: p.records[level.id] ?? null,
    counters: p.counters[level.id] ?? null,
    reached: isReached(levels, i, p),
  }));
}

export function levelStats(levels: MapLevel[], players: PlayerLevels[]): LevelStat[] {
  return levels.map((level, i) => {
    let reached = 0;
    const clearedRecords: LevelRecord[] = [];
    let starts = 0;
    let clears = 0;
    let unfinished = 0;
    let withCounters = 0;
    for (const p of players) {
      if (isReached(levels, i, p)) reached++;
      const r = p.records[level.id];
      if (r) clearedRecords.push(r);
      if (p.hasCounters && isReached(levels, i, p)) {
        withCounters++;
        const c = p.counters[level.id];
        if (c) {
          starts += c.starts;
          clears += c.clears;
          unfinished += unfinishedOf(c);
        }
      }
    }
    const cleared = clearedRecords.length;
    return {
      level,
      reached,
      cleared,
      clearRate: reached > 0 ? cleared / reached : null,
      avgStars: cleared > 0 ? clearedRecords.reduce((s, r) => s + r.stars, 0) / cleared : null,
      threeStarShare: cleared > 0 ? clearedRecords.filter((r) => r.stars === 3).length / cleared : null,
      medianBest: median(clearedRecords.map((r) => r.bestSeconds)),
      triesPerClear: clears > 0 ? starts / clears : null,
      unfinished: withCounters > 0 ? unfinished : null,
    };
  });
}

export function worldStats(levels: MapLevel[], players: PlayerLevels[], worlds?: LevelWorldSummary[]): WorldStat[] {
  const orders = [...new Set(levels.map((l) => l.worldOrder))];
  return orders.map((order) => {
    const inWorld = levels.filter((l) => l.worldOrder === order);
    const firstIndex = levels.indexOf(inWorld[0]);
    let reached = 0;
    let clearedAll = 0;
    let stars = 0;
    for (const p of players) {
      if (!isReached(levels, firstIndex, p)) continue;
      reached++;
      if (inWorld.every((l) => l.id in p.records)) clearedAll++;
      for (const l of inWorld) stars += p.records[l.id]?.stars ?? 0;
    }
    return {
      order,
      theme: inWorld[0].theme,
      title: worlds?.find((w) => w.order === order)?.title ?? '',
      levelCount: inWorld.length,
      reached,
      clearedAll,
      stars,
      maxStars: reached * inWorld.length * 3,
    };
  });
}

/** Players by the furthest map level they've cleared; players with no clear are left out. */
export function dropOff(levels: MapLevel[], players: PlayerLevels[]): DropOffBar[] {
  const counts = new Array<number>(levels.length).fill(0);
  for (const p of players) {
    for (let i = levels.length - 1; i >= 0; i--) {
      if (levels[i].id in p.records) {
        counts[i]++;
        break;
      }
    }
  }
  return levels.map((level, i) => ({ level, players: counts[i] }));
}

export function countersCoverage(players: PlayerLevels[]): { withCounters: number; total: number } {
  return { withCounters: players.filter((p) => p.hasCounters).length, total: players.length };
}

/** "Level 7 · Metro" — the world's theme, capitalised. */
export function levelLabel(level: MapLevel): string {
  return `Level ${level.number} · ${level.theme.charAt(0).toUpperCase()}${level.theme.slice(1)}`;
}

/** 75 → "1:15", 9 → "0:09". */
export function formatSeconds(total: number): string {
  const s = Math.round(total);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
```

Check the test numbers against the model by hand once (the expected values in Step 1 were worked out from `MOCK_PLAYERS`); if one disagrees, re-derive it from the definitions above and fix whichever side is wrong — say which in the report.

- [ ] **Step 4: Run to see them pass**

Run: `npx vitest run src/pages/levels/levelsModel.test.ts`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/pages/levels/levelsModel.ts src/pages/levels/levelsModel.test.ts
git commit -m "feat(levels): levelsModel works out map levels, player summaries, level and world stats

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The Levels page: shell, Worlds tab, sidebar

**Files:**
- Create: `src/pages/levels/LevelsPage.tsx`, `src/pages/levels/WorldsTab.tsx`, `src/pages/levels/Stars.tsx`, `src/pages/levels/levels.css`, `src/pages/levels/levels-css.test.ts`
- Modify: `src/routes.tsx`, `src/layout/nav.ts`, `src/layout/nav.test.tsx`, `src/queries/registerPrefetch.ts`
- Test: `src/pages/levels/LevelsPage.test.tsx`

- [ ] **Step 1: Write the failing page test**

`src/pages/levels/LevelsPage.test.tsx`:

```tsx
// @vitest-environment jsdom
import { act, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetMockStores } from '../../mocks/mockApi';
import { renderRoute } from '../../test/renderRoute';
import { toastStore } from '../../ui/toast/store';
import { LevelsPage } from './LevelsPage';

vi.mock('../../lib/firebase', () => ({ db: {}, auth: {} }));

function renderLevels(entry = '/levels') {
  return renderRoute(
    [
      { path: '/levels', element: <LevelsPage /> },
      { path: '/levels/:game/players/:uid', element: <p>player page</p> },
    ],
    entry,
  );
}

beforeEach(() => {
  localStorage.setItem('winklo_mock_admin', 'true');
  localStorage.setItem('winklo_mock_latency', '0');
});
afterEach(() => {
  resetMockStores();
  localStorage.clear();
  act(() => toastStore.clear());
});

describe('LevelsPage', () => {
  it('opens on Worlds: a card per world with its badge and level count', async () => {
    renderLevels();
    expect(await screen.findByRole('heading', { level: 1, name: 'Levels' })).toBeInTheDocument();
    const ink = await screen.findByRole('article', { name: 'World 1 · Ink' });
    expect(within(ink).getByText('Published')).toBeInTheDocument();
    expect(within(ink).getByText('5 levels · 4 × 4')).toBeInTheDocument();
    const draft = screen.getByRole('article', { name: 'World 3 · Embroidery' });
    expect(within(draft).getByText('Draft')).toBeInTheDocument();
  });

  it('keeps the tab in ?tab=', async () => {
    const { router } = renderLevels();
    await userEvent.click(await screen.findByRole('tab', { name: /Players/ }));
    expect(router.state.location.search).toBe('?tab=players');
    await userEvent.click(screen.getByRole('tab', { name: /Worlds/ }));
    expect(router.state.location.search).toBe('');
  });

  it('says so when there are no worlds', async () => {
    localStorage.setItem('winklo_mock_empty', 'levels');
    renderLevels();
    expect(await screen.findByText('No worlds yet')).toBeInTheDocument();
  });
});
```

Check `mockMode.ts` for the exact format `winklo_mock_empty` expects (a comma list of domains, or JSON) and match it.

- [ ] **Step 2: Run to see it fail**

Run: `npx vitest run src/pages/levels/LevelsPage.test.tsx`
Expected: FAIL — module missing.

- [ ] **Step 3: `Stars.tsx`** (used by Players and the player page)

```tsx
import { Star } from 'lucide-react';

/** Earned stars filled, the rest outlined; drawn icons, never emoji. */
export function Stars({ earned, total = 3, label }: { earned: number; total?: number; label?: string }) {
  return (
    <span className="lv-stars" role="img" aria-label={label ?? `${earned} of ${total} stars`}>
      {Array.from({ length: total }, (_, i) => (
        <Star key={i} aria-hidden="true" className={i < earned ? 'lv-star lv-star--on' : 'lv-star'} />
      ))}
    </span>
  );
}
```

- [ ] **Step 4: `WorldsTab.tsx`**

```tsx
import { Layers } from 'lucide-react';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';
import { EmptyState } from '../../ui/EmptyState';
import { ErrorState } from '../../ui/ErrorState';
import { SkeletonCardGrid } from '../../ui/Skeleton';
import { formatDateTime } from '../../lib/format';
import { useLevelWorlds } from '../../queries/levels';

const capitalise = (s: string) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : 'Plain');

/** Read-only in plan 2a: editing, Generate world and publishing arrive with plan 2b. */
export function WorldsTab({ game }: { game: string }) {
  const query = useLevelWorlds(game);
  if (query.isPending) return <SkeletonCardGrid />;
  if (query.error) return <ErrorState error={query.error} onRetry={() => void query.refetch()} retrying={query.isFetching} />;
  if (query.data.length === 0) {
    return <EmptyState icon={<Layers />} title="No worlds yet" description="Worlds appear here once they are added to level_worlds." />;
  }
  return (
    <ul role="list" className="lv-worlds">
      {query.data.map((w) => {
        const name = `World ${w.order} · ${capitalise(w.theme)}`;
        const size = w.levels[0]?.size;
        return (
          <li key={w.id}>
            <Card padding="lg" className="lv-world">
              <article aria-label={name}>
                <header className="lv-world__head">
                  <h2 className="lv-world__title">{name}</h2>
                  <Badge tone={w.published ? 'success' : 'neutral'} label={w.published ? 'Published' : 'Draft'} />
                </header>
                <p className="lv-world__meta">
                  {w.levels.length} levels{size ? ` · ${size} × ${size}` : ''}
                </p>
                <p className="lv-world__updated">{w.updatedAt ? `Updated ${formatDateTime(w.updatedAt)}` : 'Never saved'}</p>
              </article>
            </Card>
          </li>
        );
      })}
    </ul>
  );
}
```

Check before using: `SkeletonCardGrid`'s module path and props, `Card`'s `padding` values, `Badge`'s `label` prop, and a date formatter in `src/lib/format.ts` (`grep -n "^export function" src/lib/format.ts`). Use whatever date formatter exists (it may be named differently); do not add a new one if one fits.

- [ ] **Step 5: `LevelsPage.tsx`**

```tsx
import { ChartColumn, Layers, MapIcon, Users } from 'lucide-react';
import { useTabParam } from '../../hooks/useTabParam';
import { Badge } from '../../ui/Badge';
import { PageHeader } from '../../ui/PageHeader';
import { TabPanel, Tabs } from '../../ui/Tabs';
import { PlayersTab } from './PlayersTab';
import { StatsTab } from './StatsTab';
import { WorldsTab } from './WorldsTab';
import './levels.css';

const LEVEL_TABS = ['worlds', 'players', 'stats'] as const;
/** The only game with Levels so far; the page, routes and data are keyed by game for the others. */
const GAME = 'zip';

export function LevelsPage() {
  const [tab, setTab] = useTabParam('tab', LEVEL_TABS, 'worlds');
  return (
    <div className="lv">
      <PageHeader
        kicker={<><MapIcon aria-hidden="true" /> Game</>}
        title="Levels"
        description="Worlds, each player's progress and play counts, and where players stop."
        status={<Badge game="zip" label="Zip" />}
      />
      <Tabs
        label="Levels sections"
        idPrefix="lv-tabs"
        value={tab}
        onChange={setTab}
        items={[
          { id: 'worlds', label: 'Worlds', icon: <Layers /> },
          { id: 'players', label: 'Players', icon: <Users /> },
          { id: 'stats', label: 'Stats', icon: <ChartColumn /> },
        ]}
      />
      <TabPanel tabsId="lv-tabs" id={tab}>
        {tab === 'worlds' ? <WorldsTab game={GAME} /> : null}
        {tab === 'players' ? <PlayersTab game={GAME} /> : null}
        {tab === 'stats' ? <StatsTab game={GAME} /> : null}
      </TabPanel>
    </div>
  );
}
```

`PlayersTab` and `StatsTab` come in Tasks 11–12. For this task create both as one-line placeholders so the page compiles, each returning `null`:

```tsx
export function PlayersTab(_props: { game: string }) {
  return null;
}
```

(Tasks 11 and 12 replace them. These and the `PlayerLevelsPage` stub below are the plan's only stubs, and this task's tests don't look inside them.)

Check `lucide-react` exports `MapIcon` and `ChartColumn` (`node -e "const l=require('lucide-react');console.log(!!l.MapIcon,!!l.ChartColumn)"`); if `ChartColumn` is missing use `BarChart3`.

- [ ] **Step 6: `levels.css` and its contract test**

`src/pages/levels/levels.css` (tokens only):

```css
.lv { display: grid; gap: var(--s-6); }

.lv-worlds { display: grid; gap: var(--s-4); grid-template-columns: repeat(auto-fill, minmax(min(100%, 260px), 1fr)); margin: 0; padding: 0; list-style: none; }
.lv-world__head { display: flex; align-items: center; justify-content: space-between; gap: var(--s-3); }
.lv-world__title { margin: 0; font-size: var(--fs-lg); color: var(--text-1); }
.lv-world__meta { margin: var(--s-2) 0 0; color: var(--text-2); font-size: var(--fs-sm); }
.lv-world__updated { margin: var(--s-1) 0 0; color: var(--text-3); font-size: var(--fs-sm); }

.lv-stars { display: inline-flex; gap: 2px; vertical-align: middle; }
.lv-star { width: 14px; height: 14px; color: var(--border-strong); }
.lv-star--on { color: var(--medal-gold); fill: var(--medal-gold); }

.lv-muted { color: var(--text-3); font-size: var(--fs-sm); }
.lv-num { font-variant-numeric: tabular-nums; }
.lv-row--unreached { opacity: 0.55; }

.lv-summary { display: grid; gap: var(--s-4); grid-template-columns: repeat(auto-fill, minmax(min(100%, 160px), 1fr)); }

.lv-dropoff { display: grid; gap: var(--s-2); }
```

Check `--fs-sm` resolves to at least 12px in `tokens.css` (the `--text-3` rule); if it is smaller, use `--fs-md` for `.lv-world__updated` and `.lv-muted`.

`src/pages/levels/levels-css.test.ts`: copy the first three `it` blocks of `src/pages/platform/platform-css.test.ts` (tokens only; declared custom properties; no `--text-4` text and `--text-3` text >= 12px), importing `./levels.css?raw` instead.

- [ ] **Step 7: Register the page and the sidebar item**

`src/routes.tsx`:
- `pageLoaders`: `levels: () => import('./pages/levels/LevelsPage'),` and `levelPlayer: () => import('./pages/levels/PlayerLevelsPage'),`
- `pageExports`: `levels: 'LevelsPage',` and `levelPlayer: 'PlayerLevelsPage',`
- In the `AdminShell` children, after `page('content', 'content'),`: `page('levels', 'levels'),` and `page('levels/:game/players/:uid', 'levelPlayer'),`

`PlayerLevelsPage.tsx` is built in Task 11; for this task create it as:

```tsx
export function PlayerLevelsPage() {
  return null;
}
```

`src/layout/nav.ts`, in the `Game` group after `content`:

```ts
        { key: 'levels', to: '/levels', label: 'Levels', icon: MapIcon },
```

(import `MapIcon` from `lucide-react`).

`src/layout/nav.test.tsx`: add `'levels'` after `'content'` in the keys list (line ~18) and `'/levels'` after `'/content'` in the Game group (line ~46). Run `npx vitest run src/layout` to find any other list that counts nav items and update it.

`src/queries/registerPrefetch.ts`: register `levels` like `platform`:

```ts
registerDataPrefetch('levels', (queryClient, idToken) => {
  void import('./levels')
    .then((m) => m.prefetchLevels(queryClient, idToken))
    .catch(() => undefined); // a failed chunk load must not become an unhandled rejection
});
```

and add to `src/queries/levels.ts`:

```ts
export function prefetchLevels(queryClient: QueryClient, idToken: string): void {
  void queryClient.prefetchQuery({
    queryKey: qk.levels.worlds('zip'),
    queryFn: () => fromSource('levels', () => fetchLevelWorlds(idToken, 'zip'), (api) => api.levels.worlds('zip')),
    staleTime: LEVELS_STALE_MS,
  });
}
```

(import `type QueryClient` from `@tanstack/react-query`).

- [ ] **Step 8: Run the page test and all gates**

Run: `npx vitest run src/pages/levels src/layout src/app && npm run lint && npm run check:ui && npm run typecheck:tests && npm run build && npm run check:bundle`
Expected: all PASS; `check:bundle` lists `LevelsPage-*.js` and `PlayerLevelsPage-*.js` as lazy chunks.

- [ ] **Step 9: Commit**

```bash
git add src/pages/levels/ src/routes.tsx src/layout/ src/queries/
git commit -m "feat(levels): Levels page with the read-only Worlds tab and a sidebar item

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Players tab and the player page

**Files:**
- Modify: `src/pages/levels/PlayersTab.tsx`, `src/pages/levels/PlayerLevelsPage.tsx` (replace the Task 10 stubs)
- Test: `src/pages/levels/PlayersTab.test.tsx`, `src/pages/levels/PlayerLevelsPage.test.tsx`

- [ ] **Step 1: Write the failing tests**

`src/pages/levels/PlayersTab.test.tsx` (same setup block as `LevelsPage.test.tsx`):

```tsx
// @vitest-environment jsdom
import { act, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetMockStores } from '../../mocks/mockApi';
import { renderRoute } from '../../test/renderRoute';
import { toastStore } from '../../ui/toast/store';
import { LevelsPage } from './LevelsPage';

vi.mock('../../lib/firebase', () => ({ db: {}, auth: {} }));

const renderPlayers = () =>
  renderRoute(
    [
      { path: '/levels', element: <LevelsPage /> },
      { path: '/levels/:game/players/:uid', element: <p>player page</p> },
    ],
    '/levels?tab=players',
  );

beforeEach(() => {
  localStorage.setItem('winklo_mock_admin', 'true');
  localStorage.setItem('winklo_mock_latency', '0');
});
afterEach(() => {
  resetMockStores();
  localStorage.clear();
  act(() => toastStore.clear());
});

describe('PlayersTab', () => {
  it('lists every player, newest play first', async () => {
    renderPlayers();
    const table = await screen.findByRole('table', { name: 'Level players' });
    await within(table).findByText('Ada Lovelace');
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows.map((r) => within(r).getAllByRole('cell')[0].textContent)).toEqual([
      expect.stringContaining('Ada Lovelace'),
      expect.stringContaining('Ben Okafor'),
      expect.stringContaining('cy@example.com'),
      expect.stringContaining('Dee'),
      expect.stringContaining('Deleted account'),
    ]);
  });

  it("shows a player's current level, clears, stars and counters", async () => {
    renderPlayers();
    const row = (await screen.findByText('Ada Lovelace')).closest('tr')!;
    expect(within(row).getByText('Level 8 · Metro')).toBeInTheDocument();
    expect(within(row).getByText('7 / 10')).toBeInTheDocument();
    expect(within(row).getByText('17 / 30')).toBeInTheDocument();
    expect(within(row).getByText('12')).toBeInTheDocument(); // starts
    expect(within(row).getByText('5')).toBeInTheDocument(); // unfinished
  });

  it('shows a dash for players without counters, and All cleared', async () => {
    renderPlayers();
    const dee = (await screen.findByText('Dee')).closest('tr')!;
    expect(within(dee).getAllByText('—').length).toBeGreaterThanOrEqual(3);
    const cy = screen.getByText('cy@example.com').closest('tr')!;
    expect(within(cy).getByText('All cleared')).toBeInTheDocument();
  });

  it('says how many players have play counts', async () => {
    renderPlayers();
    expect(await screen.findByText('Play counts cover 4 of 5 players')).toBeInTheDocument();
  });

  it('filters by name, email or uid', async () => {
    renderPlayers();
    await screen.findByText('Ada Lovelace');
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search players' }), 'ben@');
    expect(await screen.findByText('Ben Okafor')).toBeInTheDocument();
    expect(screen.queryByText('Ada Lovelace')).not.toBeInTheDocument();
  });

  it('Refresh reads the players again', async () => {
    renderPlayers();
    await screen.findByText('Ada Lovelace');
    const refresh = screen.getByRole('button', { name: 'Refresh' });
    await userEvent.click(refresh);
    expect(await screen.findByText('Ada Lovelace')).toBeInTheDocument();
  });

  it('opens the player page from a row', async () => {
    const { router } = renderPlayers();
    await userEvent.click(await screen.findByText('Ben Okafor'));
    expect(router.state.location.pathname).toBe('/levels/zip/players/u_ben');
  });

  it('says so when nobody has played', async () => {
    localStorage.setItem('winklo_mock_empty', 'levels');
    renderPlayers();
    expect(await screen.findByText('No one has played Levels yet')).toBeInTheDocument();
  });
});
```

`src/pages/levels/PlayerLevelsPage.test.tsx`:

```tsx
// @vitest-environment jsdom
import { act, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetMockStores } from '../../mocks/mockApi';
import { renderRoute } from '../../test/renderRoute';
import { toastStore } from '../../ui/toast/store';
import { PlayerLevelsPage } from './PlayerLevelsPage';

vi.mock('../../lib/firebase', () => ({ db: {}, auth: {} }));

const renderPlayer = (uid: string) =>
  renderRoute([{ path: '/levels/:game/players/:uid', element: <PlayerLevelsPage /> }], `/levels/zip/players/${uid}`);

beforeEach(() => {
  localStorage.setItem('winklo_mock_admin', 'true');
  localStorage.setItem('winklo_mock_latency', '0');
});
afterEach(() => {
  resetMockStores();
  localStorage.clear();
  act(() => toastStore.clear());
});

describe('PlayerLevelsPage', () => {
  it('shows the summary and a row per map level', async () => {
    renderPlayer('u_ben');
    expect(await screen.findByRole('heading', { level: 1, name: 'Ben Okafor' })).toBeInTheDocument();
    // The current level shows in the summary and as its own row.
    expect(screen.getAllByText('Level 3 · Ink')).toHaveLength(2);
    const table = screen.getByRole('table', { name: 'Levels for Ben Okafor' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows).toHaveLength(10);
    expect(within(rows[2]).getByText('6')).toBeInTheDocument(); // starts on Level 3
    expect(rows[3]).toHaveClass('lv-row--unreached');
  });

  it('draws stars, never characters', async () => {
    renderPlayer('u_ada');
    await screen.findByRole('heading', { level: 1, name: 'Ada Lovelace' });
    expect(screen.getAllByRole('img', { name: '3 of 3 stars' }).length).toBeGreaterThan(0);
    expect(document.body.textContent).not.toMatch(/[★☆⭐]/);
  });

  it('names a deleted account and a player who never played', async () => {
    renderPlayer('u_gone');
    expect(await screen.findByRole('heading', { level: 1, name: 'Deleted account' })).toBeInTheDocument();
  });

  it('says when the player has no Levels progress', async () => {
    renderPlayer('nobody');
    expect(await screen.findByText('This player has not played Levels')).toBeInTheDocument();
  });
});
```

If `DataTable` doesn't render a `<table>` with `aria-label` from its `label` prop, or rows as `role="row"`, adjust the queries to what `DataTable` renders (read `src/ui/DataTable.tsx`); keep the assertions' meaning.

- [ ] **Step 2: Run to see them fail**

Run: `npx vitest run src/pages/levels/PlayersTab.test.tsx src/pages/levels/PlayerLevelsPage.test.tsx`
Expected: FAIL (stubs render nothing).

- [ ] **Step 3: `PlayersTab.tsx`**

```tsx
import { RefreshCw, Users } from 'lucide-react';
import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useStringParam } from '../../hooks/useStringParam';
import type { PlayerLevels } from '../../lib/adminApi';
import { formatDateTime } from '../../lib/format';
import { useLevelNames, useLevelProgress, useLevelWorlds, type LevelName } from '../../queries/levels';
import { Callout } from '../../ui/Callout';
import { DataTable, type Column } from '../../ui/DataTable';
import { EmptyState } from '../../ui/EmptyState';
import { FilterBar } from '../../ui/FilterBar';
import { IconButton } from '../../ui/IconButton';
import { NoResults } from '../../ui/NoResults';
import { SearchInput } from '../../ui/SearchInput';
import { countersCoverage, levelLabel, mapLevels, summarizePlayer, type PlayerSummary } from './levelsModel';
import { playerHref, playerName } from './playerName';

/** namesDone: the Auth lookup finished, so a missing name means a deleted account (not "still loading"). */
type Row = { player: PlayerLevels; summary: PlayerSummary; name: LevelName | null; namesDone: boolean };

const dash = (n: number | null) => (n === null ? '—' : String(n));

const COLUMNS: Column<Row>[] = [
  {
    id: 'player',
    header: 'Player',
    sortable: true,
    sortValue: (r) => playerName(r.name, r.player.uid, r.namesDone).toLowerCase(),
    cell: (r) => (
      <span className="lv-player">
        <span>{playerName(r.name, r.player.uid, r.namesDone)}</span>
        <span className="lv-muted mono">{r.player.uid}</span>
      </span>
    ),
  },
  {
    id: 'current',
    header: 'Current level',
    sortable: true,
    sortValue: (r) => r.summary.current?.number ?? Number.MAX_SAFE_INTEGER,
    cell: (r) => (r.summary.allCleared ? 'All cleared' : r.summary.current ? levelLabel(r.summary.current) : '—'),
  },
  { id: 'cleared', header: 'Cleared', align: 'end', sortable: true, sortValue: (r) => r.summary.cleared, cell: (r) => <span className="lv-num">{`${r.summary.cleared} / ${r.summary.total}`}</span> },
  { id: 'stars', header: 'Stars', align: 'end', sortable: true, sortValue: (r) => r.summary.stars, cell: (r) => <span className="lv-num">{`${r.summary.stars} / ${r.summary.maxStars}`}</span> },
  { id: 'starts', header: 'Starts', align: 'end', hideBelow: 'md', sortable: true, sortValue: (r) => r.summary.starts, cell: (r) => <span className="lv-num">{dash(r.summary.starts)}</span> },
  { id: 'unfinished', header: 'Unfinished', align: 'end', hideBelow: 'md', sortable: true, sortValue: (r) => r.summary.unfinished, cell: (r) => <span className="lv-num">{dash(r.summary.unfinished)}</span> },
  { id: 'hints', header: 'Hints', align: 'end', hideBelow: 'lg', sortable: true, sortValue: (r) => r.summary.hints, cell: (r) => <span className="lv-num">{dash(r.summary.hints)}</span> },
  {
    id: 'last',
    header: 'Last played',
    sortable: true,
    sortValue: (r) => r.summary.lastPlayed ?? '',
    cell: (r) => (r.summary.lastPlayed ? formatDateTime(r.summary.lastPlayed) : '—'),
  },
];

function matches(row: Row, q: string): boolean {
  const needle = q.trim().toLowerCase();
  if (!needle) return true;
  return [row.player.uid, row.name?.displayName, row.name?.email].some((v) => v?.toLowerCase().includes(needle));
}

export function PlayersTab({ game }: { game: string }) {
  const navigate = useNavigate();
  const [q, setQ] = useStringParam('q');
  const worlds = useLevelWorlds(game);
  const progress = useLevelProgress(game);
  const players = progress.data?.players ?? [];
  const names = useLevelNames(players.map((p) => p.uid));

  const rows = useMemo<Row[] | undefined>(() => {
    if (!worlds.data || !progress.data) return undefined;
    const levels = mapLevels(worlds.data);
    return progress.data.players.map((player) => ({
      player,
      summary: summarizePlayer(levels, player),
      name: names.data?.[player.uid] ?? null,
      namesDone: names.isSuccess,
    }));
  }, [worlds.data, progress.data, names.data, names.isSuccess]);

  const visible = rows?.filter((r) => matches(r, q));
  const coverage = countersCoverage(players);
  const error = worlds.error ?? progress.error;

  return (
    <div className="lv-tab">
      {progress.data?.truncated ? (
        <Callout tone="warning" title="Showing part of the players">
          More players have played Levels than one load reads (about 1,000). Counts below cover the players shown.
        </Callout>
      ) : null}
      {names.error ? (
        <Callout tone="info" title="Names are missing">
          The account lookup failed, so players show by uid.
        </Callout>
      ) : null}
      <FilterBar>
        <SearchInput label="Search players" placeholder="Search by name, email or UID…" value={q} onChange={setQ} />
        {/* Results are cached 5 minutes; this reads every player's docs again. */}
        <IconButton
          label="Refresh"
          icon={<RefreshCw />}
          disabled={progress.isFetching}
          onClick={() => {
            void worlds.refetch();
            void progress.refetch();
          }}
        />
      </FilterBar>
      {rows && coverage.total > 0 ? (
        <p className="lv-muted">{`Play counts cover ${coverage.withCounters} of ${coverage.total} players`}</p>
      ) : null}
      <DataTable
        label="Level players"
        columns={COLUMNS}
        rows={visible}
        rowKey={(r) => r.player.uid}
        loading={worlds.isPending || progress.isPending}
        error={error}
        onRetry={() => {
          void worlds.refetch();
          void progress.refetch();
        }}
        retrying={worlds.isFetching || progress.isFetching}
        initialSort={{ id: 'last', dir: 'desc' }}
        isFiltered={q.trim().length > 0}
        onRowClick={(r) => navigate(playerHref(game, r.player.uid))}
        rowLabel={(r) => `Open ${playerName(r.name, r.player.uid, r.namesDone)}`}
        empty={<EmptyState icon={<Users />} title="No one has played Levels yet" />}
        noResults={<NoResults onClear={() => setQ('')} />}
      />
    </div>
  );
}
```

`src/pages/levels/playerName.ts` (shared by both views and the Users tab link):

```ts
import type { LevelName } from '../../queries/levels';

/** Display name, else email, else "Deleted account" when the lookup knows no account, else the uid while loading. */
export function playerName(name: LevelName | null | undefined, uid: string, lookupDone = true): string {
  if (name?.displayName) return name.displayName;
  if (name?.email) return name.email;
  return lookupDone ? 'Deleted account' : uid;
}

export function playerHref(game: string, uid: string): string {
  return `/levels/${encodeURIComponent(game)}/players/${encodeURIComponent(uid)}`;
}
```

`namesDone` is `names.isSuccess`: while the lookup loads, or if it failed (the Callout says so), rows show uids instead of "Deleted account".

Before writing, check the real props: `DataTable` (`onRowClick`, `rowLabel`, `initialSort`, `isFiltered`), `FilterBar` children, `Callout` (`tone`, `title`, children), `NoResults` (`onClear`), and `formatDateTime`'s real name in `src/lib/format.ts`. Use them as they are; do not change shared UI components.

- [ ] **Step 4: `PlayerLevelsPage.tsx`**

```tsx
import { ArrowLeft, Users } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { useBreadcrumbLeaf } from '../../layout/breadcrumbs';
import { formatDateTime } from '../../lib/format';
import { useLevelNames, useLevelPlayer, useLevelWorlds } from '../../queries/levels';
import { DataTable, type Column } from '../../ui/DataTable';
import { EmptyState } from '../../ui/EmptyState';
import { ErrorState } from '../../ui/ErrorState';
import { PageHeader } from '../../ui/PageHeader';
import { StatCard } from '../../ui/StatCard';
import { formatSeconds, levelLabel, mapLevels, playerLevelRows, summarizePlayer, type PlayerLevelRow } from './levelsModel';
import { playerName } from './playerName';
import { Stars } from './Stars';
import './levels.css';

const dash = (n: number | null | undefined) => (n === null || n === undefined ? '—' : String(n));

const COLUMNS: Column<PlayerLevelRow>[] = [
  { id: 'level', header: 'Level', cell: (r) => levelLabel(r.level) },
  { id: 'stars', header: 'Stars', cell: (r) => (r.record ? <Stars earned={r.record.stars} /> : <span className="lv-muted">—</span>) },
  {
    id: 'best',
    header: 'Best · target',
    align: 'end',
    cell: (r) => (
      <span className="lv-num">
        {r.record ? formatSeconds(r.record.bestSeconds) : '—'}
        {r.level.targetSeconds ? <span className="lv-muted">{` · ${formatSeconds(r.level.targetSeconds)}`}</span> : null}
      </span>
    ),
  },
  { id: 'starts', header: 'Starts', align: 'end', cell: (r) => <span className="lv-num">{dash(r.counters?.starts)}</span> },
  { id: 'clears', header: 'Clears', align: 'end', hideBelow: 'md', cell: (r) => <span className="lv-num">{dash(r.counters?.clears)}</span> },
  { id: 'hints', header: 'Hints', align: 'end', hideBelow: 'md', cell: (r) => <span className="lv-num">{dash(r.counters?.hints)}</span> },
  { id: 'last', header: 'Last played', hideBelow: 'lg', cell: (r) => (r.counters?.lastPlayedAt ? formatDateTime(r.counters.lastPlayedAt) : '—') },
];

export function PlayerLevelsPage() {
  const { game = 'zip', uid = '' } = useParams();
  const worlds = useLevelWorlds(game);
  const player = useLevelPlayer(game, uid);
  const names = useLevelNames([uid]);
  const name = playerName(names.data?.[uid], uid, names.isSuccess);
  useBreadcrumbLeaf(name);

  const back = (
    <Link to="/levels?tab=players" className="lv-back">
      <ArrowLeft aria-hidden="true" /> All players
    </Link>
  );

  if (worlds.error || player.error) {
    return (
      <div className="lv">
        {back}
        <ErrorState error={worlds.error ?? player.error} onRetry={() => { void worlds.refetch(); void player.refetch(); }} />
      </div>
    );
  }
  if (worlds.isPending || player.isPending) {
    return <div className="lv">{back}<DataTable label="Loading levels" columns={COLUMNS} rows={undefined} rowKey={(r) => r.level.id} loading /></div>;
  }
  if (player.data === null) {
    return (
      <div className="lv">
        {back}
        <PageHeader title={name} />
        <EmptyState icon={<Users />} title="This player has not played Levels" />
      </div>
    );
  }

  const levels = mapLevels(worlds.data);
  const summary = summarizePlayer(levels, player.data);
  const rows = playerLevelRows(levels, player.data);

  return (
    <div className="lv">
      {back}
      <PageHeader title={name} description={uid} />
      <div className="lv-summary">
        <StatCard label="Current level" value={summary.allCleared ? 'All cleared' : summary.current ? levelLabel(summary.current) : '—'} />
        <StatCard label="Cleared" value={`${summary.cleared} / ${summary.total}`} />
        <StatCard label="Stars" value={`${summary.stars} / ${summary.maxStars}`} />
        <StatCard label="Starts" value={dash(summary.starts)} />
        <StatCard label="Unfinished" value={dash(summary.unfinished)} />
        <StatCard label="Hints" value={dash(summary.hints)} />
      </div>
      {!player.data.hasCounters ? (
        <p className="lv-muted">No play counts yet: this player hasn't played since the app started counting.</p>
      ) : null}
      <DataTable
        label={`Levels for ${name}`}
        columns={COLUMNS}
        rows={rows}
        rowKey={(r) => r.level.id}
        rowTone={(r) => (r.reached ? undefined : 'muted')}
      />
    </div>
  );
}
```

`rowTone` must end up putting the class `lv-row--unreached` on unreached rows (the test checks it). Read how `DataTable` applies `rowTone` (it may map a tone to its own class); if it can't carry a page class, add a `rowClassName?: (row) => string | undefined` prop only if DataTable has nothing usable — and in that case report it as a shared-component change. Prefer an existing prop.

Also add `.lv-back` and `.lv-player` to `levels.css`:

```css
.lv-back { display: inline-flex; align-items: center; gap: var(--s-1); color: var(--text-2); font-size: var(--fs-sm); text-decoration: none; }
.lv-back:hover { color: var(--text-1); }
.lv-back svg { width: 16px; height: 16px; }
.lv-player { display: grid; gap: 2px; }
.lv-tab { display: grid; gap: var(--s-4); }
```

- [ ] **Step 5: Run the tests and gates**

Run: `npx vitest run src/pages/levels && npm run lint && npm run check:ui && npm run typecheck:tests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/pages/levels/
git commit -m "feat(levels): Players tab and a per-player levels page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Stats tab, and "View levels" in the Users tab

**Files:**
- Modify: `src/pages/levels/StatsTab.tsx` (replace the stub)
- Modify: `src/pages/platform/UsersTab.tsx` (`menuItems`, ~line 256)
- Test: `src/pages/levels/StatsTab.test.tsx`, `src/pages/platform/UsersTab.test.tsx`

- [ ] **Step 1: Write the failing tests**

`src/pages/levels/StatsTab.test.tsx` (setup as in `PlayersTab.test.tsx`, entry `/levels?tab=stats`):

```tsx
describe('StatsTab', () => {
  it('summarises each world', async () => {
    renderStats();
    const ink = await screen.findByRole('article', { name: 'World 1 · Ink' });
    expect(within(ink).getByText('5 reached')).toBeInTheDocument();
    expect(within(ink).getByText('2 cleared it all')).toBeInTheDocument();
  });

  it('shows per-level reach, clears and tries', async () => {
    renderStats();
    const table = await screen.findByRole('table', { name: 'Level stats' });
    const row = within(table).getByText('Level 3 · Ink').closest('tr')!;
    expect(within(row).getByText('3')).toBeInTheDocument(); // reached
    expect(within(row).getByText('2 · 67%')).toBeInTheDocument(); // cleared · rate
    expect(within(row).getByText('4.5')).toBeInTheDocument(); // tries per clear
    expect(within(row).getByText('7')).toBeInTheDocument(); // unfinished
  });

  it('draws the drop-off as a bar per level', async () => {
    renderStats();
    const bars = await screen.findByRole('list', { name: 'Players by furthest level cleared' });
    expect(within(bars).getAllByRole('listitem')).toHaveLength(10);
  });

  it('says how many players have play counts', async () => {
    renderStats();
    expect(await screen.findByText('Play counts cover 4 of 5 players')).toBeInTheDocument();
  });
});
```

(`renderStats` and the setup are the same as `renderPlayers` in Task 11 with `'/levels?tab=stats'`; write them out in full in the file.)

In `src/pages/platform/UsersTab.test.tsx`, next to the 'Send notification' test (~line 304):

```tsx
  it('links each user to their levels', async () => {
    const { router } = renderUsers();  // use the file's existing render helper
    await userEvent.click(await screen.findByRole('button', { name: 'Actions for ops@winklo.game' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'View levels' }));
    expect(router.state.location.pathname).toMatch(/^\/levels\/zip\/players\/.+/);
  });
```

(Use the same render call and user email as the neighbouring tests.)

- [ ] **Step 2: Run to see them fail**

Run: `npx vitest run src/pages/levels/StatsTab.test.tsx src/pages/platform/UsersTab.test.tsx`
Expected: the new tests FAIL.

- [ ] **Step 3: `StatsTab.tsx`**

```tsx
import { ChartColumn } from 'lucide-react';
import { useMemo } from 'react';
import { useLevelProgress, useLevelWorlds } from '../../queries/levels';
import { Card } from '../../ui/Card';
import { DataTable, type Column } from '../../ui/DataTable';
import { EmptyState } from '../../ui/EmptyState';
import { ErrorState } from '../../ui/ErrorState';
import { RankedBars } from '../../ui/RankedBars';
import { countersCoverage, dropOff, formatSeconds, levelLabel, levelStats, mapLevels, worldStats, type LevelStat } from './levelsModel';

const pct = (x: number | null) => (x === null ? '—' : `${Math.round(x * 100)}%`);
const one = (x: number | null) => (x === null ? '—' : String(Math.round(x * 10) / 10));
const capitalise = (s: string) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : 'Plain');

const COLUMNS: Column<LevelStat>[] = [
  { id: 'level', header: 'Level', sortable: true, sortValue: (s) => s.level.number, cell: (s) => levelLabel(s.level) },
  { id: 'reached', header: 'Reached', align: 'end', sortable: true, sortValue: (s) => s.reached, cell: (s) => <span className="lv-num">{s.reached}</span> },
  {
    id: 'cleared',
    header: 'Cleared · rate',
    align: 'end',
    sortable: true,
    sortValue: (s) => s.clearRate,
    cell: (s) => <span className="lv-num">{`${s.cleared} · ${pct(s.clearRate)}`}</span>,
  },
  { id: 'stars', header: 'Avg stars · 3 stars', align: 'end', hideBelow: 'md', sortable: true, sortValue: (s) => s.avgStars, cell: (s) => <span className="lv-num">{`${one(s.avgStars)} · ${pct(s.threeStarShare)}`}</span> },
  {
    id: 'best',
    header: 'Median best · target',
    align: 'end',
    hideBelow: 'md',
    cell: (s) => (
      <span className="lv-num">
        {s.medianBest === null ? '—' : formatSeconds(s.medianBest)}
        {s.level.targetSeconds ? <span className="lv-muted">{` · ${formatSeconds(s.level.targetSeconds)}`}</span> : null}
      </span>
    ),
  },
  { id: 'tries', header: 'Tries per clear', align: 'end', sortable: true, sortValue: (s) => s.triesPerClear, cell: (s) => <span className="lv-num">{one(s.triesPerClear)}</span> },
  { id: 'unfinished', header: 'Unfinished', align: 'end', sortable: true, sortValue: (s) => s.unfinished, cell: (s) => <span className="lv-num">{s.unfinished ?? '—'}</span> },
];

export function StatsTab({ game }: { game: string }) {
  const worlds = useLevelWorlds(game);
  const progress = useLevelProgress(game);
  const data = useMemo(() => {
    if (!worlds.data || !progress.data) return null;
    const levels = mapLevels(worlds.data);
    const players = progress.data.players;
    return {
      levels,
      worlds: worldStats(levels, players, worlds.data),
      stats: levelStats(levels, players),
      drop: dropOff(levels, players),
      coverage: countersCoverage(players),
    };
  }, [worlds.data, progress.data]);

  const error = worlds.error ?? progress.error;
  if (error) return <ErrorState error={error} onRetry={() => { void worlds.refetch(); void progress.refetch(); }} />;
  if (!data) return <DataTable label="Level stats" columns={COLUMNS} rows={undefined} rowKey={(s) => s.level.id} loading />;
  if (data.coverage.total === 0) return <EmptyState icon={<ChartColumn />} title="No one has played Levels yet" />;

  return (
    <div className="lv-tab">
      <p className="lv-muted">{`Play counts cover ${data.coverage.withCounters} of ${data.coverage.total} players`}</p>
      <ul role="list" className="lv-worlds">
        {data.worlds.map((w) => {
          const name = `World ${w.order} · ${capitalise(w.theme)}`;
          return (
            <li key={w.order}>
              <Card padding="lg" className="lv-world">
                <article aria-label={name}>
                  <h2 className="lv-world__title">{name}</h2>
                  <p className="lv-world__meta">{`${w.reached} reached`}</p>
                  <p className="lv-world__meta">{`${w.clearedAll} cleared it all`}</p>
                  <p className="lv-world__meta">{`${w.stars} / ${w.maxStars} stars`}</p>
                </article>
              </Card>
            </li>
          );
        })}
      </ul>
      <Card padding="lg" className="lv-dropoff">
        <h2 className="lv-world__title">Where players stop</h2>
        <p className="lv-muted">Players by the furthest level they have cleared. A big bar followed by small ones marks a level that stops people.</p>
        <RankedBars
          label="Players by furthest level cleared"
          tone="accent"
          items={data.drop.map((b) => ({ key: b.level.id, label: levelLabel(b.level), value: b.players }))}
        />
      </Card>
      <DataTable label="Level stats" columns={COLUMNS} rows={data.stats} rowKey={(s) => s.level.id} initialSort={{ id: 'level', dir: 'asc' }} />
    </div>
  );
}
```

Notes:
- `RankedBars` keeps the items in the order given (map order). If it sorts by value, read it: if there is no way to keep the order, render the bars in map order with the same markup classes it uses (`ul`/`li` with an `aria-label`) instead — the test only needs a list of 10 items named "Players by furthest level cleared".
- `sortValue` may return `null`; `Column.sortValue` allows `null | undefined`.

- [ ] **Step 4: "View levels" in the Users tab**

`src/pages/platform/UsersTab.tsx`: import `MapIcon` from `lucide-react` and `playerHref` from `../levels/playerName`; in `menuItems`, after the `notify` item:

```tsx
      { id: 'levels', label: 'View levels', icon: <MapIcon />, onSelect: () => navigate(playerHref('zip', user.uid)) },
```

- [ ] **Step 5: Run the tests and every SPA gate**

Run: `npm run lint && npm run check:ui && npm run typecheck:tests && npm test && npm run build && npm run check:bundle`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add src/pages/levels/ src/pages/platform/UsersTab.tsx src/pages/platform/UsersTab.test.tsx
git commit -m "feat(levels): Stats tab with drop-off; View levels from the Users tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Verification and hand-off

- [ ] **App** (`~/Developments/personal/winklo/.worktrees/admin-levels`): `flutter analyze` → only the 20 existing infos; `flutter test` → all pass. The Ink render from Task 2 Step 6 has been looked at.
- [ ] **Rules**: written; run only if Java is present (it isn't on this Mac — say so).
- [ ] **Deletion Worker**: `cd workers/account-deletion && npx vitest run` → pass.
- [ ] **Admin SPA** (`~/Developments/personal/winklo-admin/.worktrees/admin-levels`): `npm run lint`, `npm run check:ui`, `npm run typecheck:tests`, `npm test`, `npm run build`, `npm run check:bundle` → all pass.
- [ ] **admin-api**: `cd workers/admin-api && npm run typecheck && npm test` → pass.
- [ ] **Mock-mode look**: run `npm run dev` in the admin worktree with mock mode on (`localStorage.winklo_mock_admin = 'true'`), open `/levels`, each tab, a player page, and the Users tab "View levels"; take a 390 px wide and a 1280 px wide screenshot of Players and Stats into the scratchpad; check no horizontal page scroll at 390 px. Stop the dev server.
- [ ] **Real data** (needs the user): deploy the rules (`firebase deploy --only firestore:rules`), the admin-api Worker, and a build of the app; then the Players tab shows real players once someone plays a level on the new build. Listed for the user, not run.
- [ ] Hand off with superpowers:finishing-a-development-branch for **both** repos (branch `feat/admin-levels` in each). Nothing is pushed or deployed without the user.
