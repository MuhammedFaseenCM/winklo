# Compulsory Play Sign-In + Public Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require Google sign-in before entering any playable game; show live Leaderboard rankings to guests with a floating bottom sign-in CTA.

**Architecture:** Home tile taps call shared `ensureSignedInForPlay` (play-copy `showSignInSheet`). GoRouter `redirect` + auth `refreshListenable` bounce unsigned users off playable routes to `/`. Leaderboard tab drops the blurred sign-in wall, always streams live entries, and overlays a floating sign-in button when signed out.

**Tech Stack:** Flutter, go_router, AuthCubit, existing `showSignInSheet`, `AppStrings`, widget tests (flutter_test / mocktail).

**Spec:** `docs/superpowers/specs/2026-09-27-compulsory-play-signin-design.md`

## Global Constraints

- All user-facing copy via `AppStrings` (no inline UI strings).
- Domain stays Flutter-free; UI helpers live under `lib/features/auth/` or `lib/core/`.
- Soft-claim / Profile signed-out tease: do not rewrite in this plan.
- Firestore rules: no change (leaderboard read already public).
- Keep `LeaderboardSignedOutMock` — still used by results board tease.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/core/strings/app_strings.dart` | Play-gate + updated auth/leaderboard copy |
| `lib/features/auth/view/ensure_signed_in_for_play.dart` | Shared `ensureSignedInForPlay(context)` |
| `lib/features/home/view/home_screen.dart` | Gate `openZip` / `openPathWords` / `openSudoku` |
| `lib/core/router/auth_router_refresh.dart` | `ChangeNotifier` bridging `AuthCubit.stream` → GoRouter |
| `lib/core/router/app_router.dart` | Playable-path redirect when signed out |
| `lib/app.dart` | Pass `AuthCubit` into `buildRouter` |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | Live board for guests + floating CTA |
| `test/features/home/view/home_screen_test.dart` | Invert guest-play expectations |
| `test/core/router/app_router_auth_redirect_test.dart` | Redirect coverage |
| `test/features/leaderboard/view/leaderboard_screen_test.dart` | Guest live board + FAB |

---

### Task 1: AppStrings — play gate + guest-play copy reversal

**Files:**
- Modify: `lib/core/strings/app_strings.dart`
- Test: covered by later widget tests asserting these strings

**Interfaces:**
- Produces: `AppStrings.playSignInTitle`, `AppStrings.playSignInBody`; updated `signInBody`, `signOutConfirmBody`; keep `signInWithGoogle` for floating CTA

- [ ] **Step 1: Update auth / play copy**

In `lib/core/strings/app_strings.dart`, replace the Auth / leaderboard block strings as follows (keep other keys):

```dart
  // Auth / leaderboard
  static const playSignInTitle = 'Sign in to play';
  static const playSignInBody =
      'Sign in with Google to play today’s puzzles and save your time on the board.';
  static const signInTitle = 'Sign in to join the board';
  static const signInBody =
      'Browse live rankings anytime. Sign in with Google to play and save your scores.';
  static const signInWithGoogle = 'Continue with Google';
  static const signInCancel = 'Not now';
  static const signInRequired = 'Sign in to join the board';
  static const signOut = 'Sign out';
  static const signOutConfirmTitle = 'Sign out?';
  static const signOutConfirmBody =
      'You’ll need to sign in again to play. You can still view the live leaderboard signed out.';
  static const signOutConfirmCancel = 'Cancel';
  // ... keep leaderboardTitle, periods, empty, failed, etc.
  // Remove leaderboardSignInHint only after Task 4 confirms nothing still references it
  // on the Leaderboard tab. Keep the key until mini-board / results stop using it
  // (out of scope to rewrite soft-claim); leave `leaderboardSignInHint` unchanged.
```

Exact values to add/change:

| Key | Value |
|-----|--------|
| `playSignInTitle` | `Sign in to play` |
| `playSignInBody` | `Sign in with Google to play today’s puzzles and save your time on the board.` |
| `signInTitle` | `Sign in to join the board` |
| `signInBody` | `Browse live rankings anytime. Sign in with Google to play and save your scores.` |
| `signInRequired` | `Sign in to join the board` |
| `signOutConfirmBody` | `You’ll need to sign in again to play. You can still view the live leaderboard signed out.` |

Do **not** delete `leaderboardSignInHint` in this task (still used by mini leaderboard / soft claim).

- [ ] **Step 2: Format**

Run: `dart format lib/core/strings/app_strings.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/core/strings/app_strings.dart
git commit -m "$(cat <<'EOF'
feat: add play sign-in copy and revise guest auth strings

EOF
)"
```

---

### Task 2: `ensureSignedInForPlay` + Home tile gate

**Files:**
- Create: `lib/features/auth/view/ensure_signed_in_for_play.dart`
- Modify: `lib/features/home/view/home_screen.dart` (around `openZip` / `openPathWords` / `openSudoku`)
- Modify: `test/features/home/view/home_screen_test.dart`

**Interfaces:**
- Consumes: `AuthCubit.isSignedIn`, `showSignInSheet`, `AppStrings.playSignInTitle` / `playSignInBody`
- Produces: `Future<bool> ensureSignedInForPlay(BuildContext context)`

- [ ] **Step 1: Write failing Home tests (invert guest play)**

In `test/features/home/view/home_screen_test.dart`, replace the two guest-play tests with:

```dart
  testWidgets('signed-out user sees play sign-in sheet and stays on Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router, authUser: null);

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
    expect(find.text('zip-screen'), findsNothing);

    await tester.tap(find.text(AppStrings.signInCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    expect(find.text('zip-screen'), findsNothing);
  });

  testWidgets('signed-out Path Words tap shows play sign-in sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router, authUser: null);

    await tester.tap(find.text(AppStrings.playTodaysPathWords));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text('path-words'), findsNothing);
  });

  testWidgets('signed-in user opens Zip without sign-in sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/zip',
          builder: (_, _) => const Scaffold(body: Text('zip-screen')),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Scaffold(body: Text('path-words')),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('leaderboard')),
        ),
      ],
    );

    await pumpHome(tester, prefs: prefs, router: router); // default signed-in user

    await tester.tap(find.text(AppStrings.playTodaysZip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.playSignInTitle), findsNothing);
    expect(find.text('zip-screen'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests — expect FAIL**

Run:

```bash
flutter test test/features/home/view/home_screen_test.dart
```

Expected: FAIL — signed-out still navigates to zip / path-words; `playSignInTitle` not found.

- [ ] **Step 3: Add helper**

Create `lib/features/auth/view/ensure_signed_in_for_play.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../cubit/auth_cubit.dart';
import 'sign_in_sheet.dart';

/// Returns true if the user is (or becomes) signed in and may open a game.
Future<bool> ensureSignedInForPlay(BuildContext context) async {
  final auth = context.read<AuthCubit>();
  if (auth.isSignedIn) return true;
  return showSignInSheet(
    context,
    title: AppStrings.playSignInTitle,
    body: AppStrings.playSignInBody,
  );
}
```

- [ ] **Step 4: Gate Home openers**

In `lib/features/home/view/home_screen.dart`, import the helper and wrap each opener:

```dart
        Future<void> openZip() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.zip);
          if (!context.mounted) return;
          await context.push('/zip');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openPathWords() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.pathWords);
          if (!context.mounted) return;
          await context.push('/path-words');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openSudoku() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.sudoku);
          if (!context.mounted) return;
          await context.push('/sudoku');
          if (!cubit.isClosed) await cubit.load();
        }
```

- [ ] **Step 5: Run tests — expect PASS**

Run:

```bash
flutter test test/features/home/view/home_screen_test.dart
```

Expected: PASS

- [ ] **Step 6: Format + commit**

```bash
dart format lib/features/auth/view/ensure_signed_in_for_play.dart \
  lib/features/home/view/home_screen.dart \
  test/features/home/view/home_screen_test.dart
git add lib/features/auth/view/ensure_signed_in_for_play.dart \
  lib/features/home/view/home_screen.dart \
  test/features/home/view/home_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: require sign-in before opening games from Home

EOF
)"
```

---

### Task 3: GoRouter playable-path redirect

**Files:**
- Create: `lib/core/router/auth_router_refresh.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/app.dart`
- Create: `test/core/router/app_router_auth_redirect_test.dart`

**Interfaces:**
- Consumes: `AuthCubit` (`state.status`, `isSignedIn`, `stream`)
- Produces: `buildRouter({required AnalyticsRepository analytics, required AuthCubit authCubit})`; redirect to `/` when signed out on playable paths

Playable paths (exact or prefix):

- `/zip`, `/path-words`, `/sudoku`, `/word-match`, `/category-race`
- any path starting with `/word-match/`

Non-playable (never redirect for auth): `/`, `/leaderboard`, `/profile`, `/results`, profile sub-routes.

Auth cold start: if `authCubit.state.status == AuthStatus.unknown`, return `null` (no redirect).

- [ ] **Step 1: Write failing redirect test**

Create `test/core/router/app_router_auth_redirect_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository authRepo;
  late StreamController<AppUser?> authController;
  late AuthCubit authCubit;
  late GoRouter router;

  setUp(() {
    authRepo = _MockAuthRepository();
    authController = StreamController<AppUser?>.broadcast();
    when(() => authRepo.currentUser).thenReturn(null);
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => authController.stream);

    authCubit = AuthCubit(
      authRepository: authRepo,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );

    final analytics = _MockAnalytics();
    when(
      () => analytics.logScreenView(screenName: any(named: 'screenName')),
    ).thenAnswer((_) async {});

    router = buildRouter(analytics: analytics, authCubit: authCubit);
  });

  tearDown(() async {
    await authCubit.close();
    await authController.close();
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('signed-out deep link to /zip redirects to /', (tester) async {
    await pumpApp(tester);
    authController.add(null);
    await tester.pump();

    router.go('/zip');
    await tester.pump();
    await tester.pump();

    expect(router.state.uri.path, '/');
  });

  testWidgets('auth unknown does not redirect away from /zip yet', (
    tester,
  ) async {
    // Cubit starts unknown when currentUser is null and stream has not emitted.
    await pumpApp(tester);

    router.go('/zip');
    await tester.pump();

    expect(router.state.uri.path, '/zip');
  });

  testWidgets('signed-in can open /zip', (tester) async {
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    when(() => authRepo.currentUser).thenReturn(user);
    await authCubit.close();
    authCubit = AuthCubit(
      authRepository: authRepo,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));

    final analytics = _MockAnalytics();
    when(
      () => analytics.logScreenView(screenName: any(named: 'screenName')),
    ).thenAnswer((_) async {});
    router.dispose();
    router = buildRouter(analytics: analytics, authCubit: authCubit);

    await pumpApp(tester);
    await tester.pump();

    router.go('/zip');
    await tester.pump();
    await tester.pump();

    expect(router.state.uri.path, '/zip');
  });

  testWidgets('signed-out /leaderboard is allowed', (tester) async {
    await pumpApp(tester);
    authController.add(null);
    await tester.pump();

    router.go('/leaderboard');
    await tester.pump();
    await tester.pump();

    expect(router.state.uri.path, '/leaderboard');
  });
}
```

Adjust analytics stubs if `AnalyticsRouteObserver` / `ClientErrorRouteObserver` require more `when(...)` — match whatever existing router tests or observer constructors need. If `buildRouter` currently lacks `authCubit`, the file will not compile until Step 3 — that is expected.

- [ ] **Step 2: Run test — expect FAIL / compile error**

Run:

```bash
flutter test test/core/router/app_router_auth_redirect_test.dart
```

Expected: FAIL or compile error (`authCubit` named param missing).

- [ ] **Step 3: Add `AuthRouterRefresh`**

Create `lib/core/router/auth_router_refresh.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/cubit/auth_cubit.dart';

/// Bridges [AuthCubit] emissions to GoRouter's [refreshListenable].
final class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(AuthCubit authCubit) {
    _subscription = authCubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
```

- [ ] **Step 4: Wire redirect in `buildRouter`**

Update `lib/core/router/app_router.dart`:

```dart
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/auth_state.dart';
import 'auth_router_refresh.dart';

bool isPlayableLocation(String path) {
  if (path == '/zip' ||
      path == '/path-words' ||
      path == '/sudoku' ||
      path == '/word-match' ||
      path == '/category-race') {
    return true;
  }
  return path.startsWith('/word-match/');
}

GoRouter buildRouter({
  required AnalyticsRepository analytics,
  required AuthCubit authCubit,
}) {
  final refresh = AuthRouterRefresh(authCubit);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!isPlayableLocation(state.matchedLocation)) return null;
      final status = authCubit.state.status;
      if (status == AuthStatus.unknown) return null;
      if (authCubit.isSignedIn) return null;
      return '/';
    },
    observers: [AnalyticsRouteObserver(analytics), ClientErrorRouteObserver()],
    routes: [
      // ... existing routes unchanged ...
    ],
  );
}
```

Keep the existing `routes:` tree exactly as today; only add the parameters, `refreshListenable`, and `redirect`.

Note: `AuthRouterRefresh` is owned by the router lifetime. Do not dispose it separately unless you add a custom dispose path — leaking one subscription for app lifetime is acceptable. If you prefer, store refresh on `_WinkloAppState` and dispose in `dispose()`.

- [ ] **Step 5: Pass `AuthCubit` from `WinkloApp`**

Update `lib/app.dart`:

```dart
import 'features/auth/cubit/auth_cubit.dart';

// in build:
    _router ??= buildRouter(
      analytics: context.read<AnalyticsRepository>(),
      authCubit: context.read<AuthCubit>(),
    );
```

- [ ] **Step 6: Fix any other `buildRouter(` call sites**

Search the repo for `buildRouter(` and pass a real or test `AuthCubit`. Update tests that construct the full app router.

- [ ] **Step 7: Run redirect tests — expect PASS**

```bash
flutter test test/core/router/app_router_auth_redirect_test.dart
```

Expected: PASS. If the “unknown” case fails because `ZipScreen` / observers throw without DI, swap playable builders in the test router — prefer testing via the real `buildRouter` with enough repository stubs, or extract `isPlayableLocation` + redirect closure into a pure function tested without full screens. Prefer keeping `buildRouter` integration if feasible; if DI blows up, create a thin `String? playAuthRedirect({required AuthStatus status, required bool isSignedIn, required String matchedLocation})` in `app_router.dart` and unit-test that instead, still wiring the same logic into `GoRouter.redirect`.

Minimal pure helper (use if widget integration is too heavy):

```dart
String? playAuthRedirect({
  required AuthStatus status,
  required bool isSignedIn,
  required String matchedLocation,
}) {
  if (!isPlayableLocation(matchedLocation)) return null;
  if (status == AuthStatus.unknown) return null;
  if (isSignedIn) return null;
  return '/';
}
```

Then unit-test `playAuthRedirect` / `isPlayableLocation` without pumping full game screens, and still wire it inside `buildRouter`’s `redirect`.

- [ ] **Step 8: Format + commit**

```bash
dart format lib/core/router/ lib/app.dart test/core/router/
git add lib/core/router/ lib/app.dart test/core/router/
git commit -m "$(cat <<'EOF'
feat: redirect unsigned users away from playable routes

EOF
)"
```

---

### Task 4: Leaderboard — live for guests + floating sign-in CTA

**Files:**
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart`
- Modify: `test/features/leaderboard/view/leaderboard_screen_test.dart`

**Interfaces:**
- Consumes: `AuthCubit`, `showSignInSheet`, `AppStrings.signInWithGoogle`
- Produces: signed-out users see the same ready/loading/failure/empty board as signed-in; floating bottom CTA when `auth.user == null` and status is not `unknown`

- [ ] **Step 1: Write failing leaderboard tests**

Add to `test/features/leaderboard/view/leaderboard_screen_test.dart`:

```dart
  testWidgets('signed-out shows live entries and floating sign-in CTA', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    boardController.add([
      LeaderboardEntry(
        uid: 'a',
        displayName: 'Alex',
        timeSeconds: 42,
        updatedAt: DateTime.utc(2026, 9, 27),
        rank: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text(AppStrings.leaderboardSignInHint), findsNothing);
    expect(
      find.byKey(const Key('leaderboard_sign_in_fab')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
  });

  testWidgets('signed-in does not show floating sign-in CTA', (tester) async {
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    boardController.add([
      LeaderboardEntry(
        uid: 'u1',
        displayName: 'Ada',
        timeSeconds: 40,
        updatedAt: DateTime.utc(2026, 9, 27),
        rank: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leaderboard_sign_in_fab')), findsNothing);
  });
```

Match `LeaderboardEntry` constructor fields to the real entity (add `photoUrl` / `avatarId` / `updatedAt` if required by the type).

Update the existing `auth unknown shows LeaderboardShimmer not sign-in CTA` test so it still expects shimmer and **no** floating FAB while unknown.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/leaderboard/view/leaderboard_screen_test.dart
```

Expected: FAIL — signed-out still hits `BlurredMockEmptyBody` / hint; no live `Alex` row.

- [ ] **Step 3: Remove signed-out wall; add floating CTA**

In `lib/features/leaderboard/view/leaderboard_screen.dart` inside `_LeaderboardView`’s body builder:

1. Keep `AuthStatus.unknown` → `LeaderboardShimmer`.
2. **Delete** the `if (auth.user == null) { return BlurredMockEmptyBody(...); }` branch.
3. Always switch on `LeaderboardCubit` status for the list (loading / failure / ready).
4. Wrap the main column / scaffold body in a `Stack` so when `auth.user == null` (and status ≠ unknown), overlay:

```dart
Positioned(
  left: 16,
  right: 16,
  bottom: 16,
  child: SafeArea(
    child: FilledButton(
      key: const Key('leaderboard_sign_in_fab'),
      onPressed: () => showSignInSheet(context),
      child: Text(AppStrings.signInWithGoogle),
    ),
  ),
),
```

5. Add bottom padding to the scrollable list when the FAB is visible (e.g. extra `80` logical pixels) so the last rows are not hidden under the button.
6. Empty-state “Play {game}” button: before `context.push(gameRoute)`, call `ensureSignedInForPlay(context)` and return if false — otherwise router redirect alone would bounce guests to Home without a sheet.

Remove unused imports (`BlurredMockEmptyBody`, `LeaderboardSignedOutMock`) from this file only. Do **not** delete `leaderboard_signed_out_mock.dart`.

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/features/leaderboard/view/leaderboard_screen_test.dart
```

Expected: PASS

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/leaderboard/view/leaderboard_screen.dart \
  test/features/leaderboard/view/leaderboard_screen_test.dart
git add lib/features/leaderboard/view/leaderboard_screen.dart \
  test/features/leaderboard/view/leaderboard_screen_test.dart
git commit -m "$(cat <<'EOF'
feat: show live leaderboard to guests with floating sign-in

EOF
)"
```

---

### Task 5: Smoke + string references

**Files:**
- Possibly touch tests that assert old `signInTitle` / `signInBody` / `signOutConfirmBody` copy

- [ ] **Step 1: Grep for stale expectations**

```bash
rg "Play Zip and Path Words anytime|Sign in to view rankings|view the live leaderboard" test lib
```

Update any test assertions to the new `AppStrings` values from Task 1.

- [ ] **Step 2: Run focused suite**

```bash
flutter test \
  test/features/home/view/home_screen_test.dart \
  test/features/leaderboard/view/leaderboard_screen_test.dart \
  test/core/router/app_router_auth_redirect_test.dart \
  test/features/auth/view/sign_in_sheet_test.dart \
  test/features/profile/view/profile_screen_test.dart
```

Expected: all PASS

- [ ] **Step 3: Commit any test copy fixes**

```bash
git add -u test/
git commit -m "$(cat <<'EOF'
test: align auth copy assertions with play-required sign-in

EOF
)"
```

Skip empty commit if nothing changed.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Home tile → play sheet; Not now stays Home | Task 2 |
| Play-focused sheet copy | Tasks 1–2 |
| Deep link / any playable path → `/` when signed out | Task 3 |
| Auth `unknown` does not false-redirect | Task 3 |
| Live leaderboard for guests | Task 4 |
| Floating bottom sign-in CTA | Task 4 |
| Signed-in leaderboard unchanged (no FAB) | Task 4 |
| Soft-claim / Profile unchanged | Explicit non-goals |
| Firestore unchanged | Explicit non-goal |
| `signOutConfirmBody` mentions play | Task 1 |

## Out of scope (do not implement)

- Soft-claim guest celebration cleanup
- Profile signed-out gate changes
- Auto-showing play sheet after deep-link bounce
- Deleting `leaderboardSignInHint` / `LeaderboardSignedOutMock`
