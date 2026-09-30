# Profile Shimmer + AppImage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix cold-start Profile flash (show shimmer instead of sign-in), add avatar edit badge, reusable shimmer primitives, pull-to-refresh shimmer, and a shared `AppImage` (raster + SVG) used by `UserAvatar`.

**Architecture:** Auth `unknown` and Profile `refreshing` render `ProfileShimmer` built from shared `AppShimmer*` widgets (`package:shimmer`). Media goes through `AppImage` (`cached_network_image` + `flutter_svg`). Profile avatar uses a `Stack` edit badge; signed-in body uses `RefreshIndicator` → `ProfileCubit.refresh()`.

**Tech Stack:** Flutter, `shimmer`, `cached_network_image`, `flutter_svg`, existing `AuthCubit` / `ProfileCubit` / `UserAvatar`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-profile-shimmer-app-image-design.md`
- Never show signed-out mock while `AuthStatus.unknown`
- `ProfileStatus.saving` must **not** swap the whole body to shimmer
- Domain stays pure Dart (no Flutter imports in `domain/`)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `pubspec.yaml` | Add `shimmer`, `cached_network_image`, `flutter_svg` |
| `lib/core/widgets/app_shimmer.dart` | `AppShimmer`, `AppShimmerBox`, `AppShimmerCircle` |
| `lib/core/widgets/app_image.dart` | Network/asset/file/memory + SVG routing |
| `lib/core/widgets/user_avatar.dart` | Use `AppImage` inside `ClipOval` |
| `lib/features/profile/view/widgets/profile_shimmer.dart` | Profile-shaped skeleton |
| `lib/features/profile/cubit/profile_state.dart` | Add `ProfileStatus.refreshing` |
| `lib/features/profile/cubit/profile_cubit.dart` | Add `refresh()` via `getProfile` |
| `lib/features/profile/view/profile_screen.dart` | Auth branch, edit badge, RefreshIndicator |
| `test/core/widgets/app_shimmer_test.dart` | Smoke widget tests |
| `test/core/widgets/app_image_test.dart` | SVG vs raster routing |
| `test/features/profile/view/widgets/profile_shimmer_test.dart` | Layout smoke |
| `test/features/profile/cubit/profile_cubit_test.dart` | `refresh()` states |
| `test/features/profile/view/profile_screen_test.dart` | unknown → shimmer; signedOut → CTA; edit icon |

---

### Task 1: Dependencies + AppShimmer primitives

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/widgets/app_shimmer.dart`
- Test: `test/core/widgets/app_shimmer_test.dart`

**Interfaces:**
- Produces:

```dart
// lib/core/widgets/app_shimmer.dart
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;
}

class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });
  final double? width;
  final double height;
  final double borderRadius;
}

class AppShimmerCircle extends StatelessWidget {
  const AppShimmerCircle({super.key, required this.radius});
  final double radius;
}
```

- Colors: base `ZipColors.wall`, highlight `ZipColors.mistDeep` (or slightly lighter wall).

- [ ] **Step 1: Add packages**

Run:

```bash
cd /Users/muhammedfaseencm/winklo && flutter pub add shimmer cached_network_image flutter_svg
```

Expected: `pubspec.yaml` lists all three; `flutter pub get` succeeds.

- [ ] **Step 2: Write failing shimmer smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';

void main() {
  testWidgets('AppShimmerBox and AppShimmerCircle build under AppShimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: AppShimmer(
            child: Column(
              children: [
                AppShimmerCircle(radius: 24),
                AppShimmerBox(width: 120, height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppShimmerCircle), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test — expect FAIL (library missing)**

```bash
flutter test test/core/widgets/app_shimmer_test.dart
```

Expected: FAIL — `app_shimmer.dart` not found.

- [ ] **Step 4: Implement `app_shimmer.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ZipColors.wall,
      highlightColor: ZipColors.mistDeep,
      child: child,
    );
  }
}

class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class AppShimmerCircle extends StatelessWidget {
  const AppShimmerCircle({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        color: ZipColors.wall,
        shape: BoxShape.circle,
      ),
    );
  }
}
```

- [ ] **Step 5: Run test — expect PASS**

```bash
flutter test test/core/widgets/app_shimmer_test.dart
```

Expected: PASS

- [ ] **Step 6: Format + analyze**

```bash
dart format lib/core/widgets/app_shimmer.dart test/core/widgets/app_shimmer_test.dart
dart analyze lib/core/widgets/app_shimmer.dart test/core/widgets/app_shimmer_test.dart
```

- [ ] **Step 7: Commit** (skip unless user asked)

```bash
git add pubspec.yaml pubspec.lock lib/core/widgets/app_shimmer.dart test/core/widgets/app_shimmer_test.dart
git commit -m "feat: add shared AppShimmer primitives"
```

---

### Task 2: AppImage (raster + SVG, all sources)

**Files:**
- Create: `lib/core/widgets/app_image.dart`
- Test: `test/core/widgets/app_image_test.dart`

**Interfaces:**
- Produces:

```dart
enum AppImageKind { network, asset, file, memory }

class AppImage extends StatelessWidget {
  const AppImage.network(String url, {Key? key, …});
  const AppImage.asset(String path, {Key? key, …});
  const AppImage.file(String path, {Key? key, …});
  const AppImage.memory(Uint8List bytes, {Key? key, …});

  /// True when [pathOrUrl] looks like SVG (case-insensitive `.svg`, ignoring query).
  static bool looksLikeSvg(String pathOrUrl);
}
```

Common fields: `BoxFit fit`, `double? width`, `double? height`, `Widget? placeholder`, `Widget? errorWidget`, `BorderRadius? borderRadius`.

Empty network/asset/file string → build `errorWidget` or zero-size `SizedBox.shrink()` — never throw.

- [ ] **Step 1: Write failing unit + widget tests**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/app_image.dart';

void main() {
  group('AppImage.looksLikeSvg', () {
    test('detects .svg ignoring case and query', () {
      expect(AppImage.looksLikeSvg('icons/Logo.SVG'), isTrue);
      expect(AppImage.looksLikeSvg('https://cdn.ex/a.svg?x=1'), isTrue);
      expect(AppImage.looksLikeSvg('photo.jpg'), isFalse);
    });
  });

  testWidgets('asset svg uses SvgPicture', (tester) async {
    // Use a tiny inline SVG via memory constructor instead of asset bundle.
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImage.memory(
            Uint8List.fromList(svg.codeUnits),
            width: 10,
            height: 10,
            // Force SVG path: looksLikeSvg on empty name won't work for memory —
            // memory SVG: AppImage must accept optional forceSvg OR detect XML.
            // Spec: memory SVG via SvgPicture.memory when bytes look like SVG
            // OR named ctor AppImage.memory(..., isSvg: true).
            // Plan: if bytes start with '<' / contain '<svg', treat as SVG;
            // else Image.memory. For this test use isSvg: true param.
            isSvg: true,
          ),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('empty network url shows errorWidget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImage.network(
            '',
            errorWidget: const Text('bad'),
          ),
        ),
      ),
    );
    expect(find.text('bad'), findsOneWidget);
  });
}
```

**API clarification (lock in implementation):** add optional `bool? isSvg` on constructors; when null, infer via `looksLikeSvg` for string sources, and for memory sniff UTF-8 prefix for `<svg`.

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/core/widgets/app_image_test.dart
```

Expected: FAIL — missing library.

- [ ] **Step 3: Implement `app_image.dart`**

Implement named constructors storing `AppImageKind`, source string or bytes, and shared display params. In `build`:

1. If empty string source → `errorWidget ?? SizedBox.shrink()`.
2. Resolve `useSvg` from `isSvg ?? looksLikeSvg(source)` (memory: sniff).
3. Build child:
   - SVG network → `SvgPicture.network`
   - SVG asset → `SvgPicture.asset`
   - SVG file → `SvgPicture.file(File(path))`
   - SVG memory → `SvgPicture.memory`
   - Raster network → `CachedNetworkImage` with `placeholder` / `errorWidget`
   - Raster asset/file/memory → `Image.asset` / `Image.file` / `Image.memory` with `errorBuilder`
4. If `borderRadius != null`, wrap in `ClipRRect`.

`looksLikeSvg`:

```dart
static bool looksLikeSvg(String pathOrUrl) {
  final noQuery = pathOrUrl.split('?').first;
  return noQuery.toLowerCase().endsWith('.svg');
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/core/widgets/app_image_test.dart
```

- [ ] **Step 5: Format + analyze**

```bash
dart format lib/core/widgets/app_image.dart test/core/widgets/app_image_test.dart
dart analyze lib/core/widgets/app_image.dart test/core/widgets/app_image_test.dart
```

- [ ] **Step 6: Commit** (skip unless user asked)

```bash
git add lib/core/widgets/app_image.dart test/core/widgets/app_image_test.dart
git commit -m "feat: add AppImage for raster and SVG sources"
```

---

### Task 3: Wire UserAvatar through AppImage

**Files:**
- Modify: `lib/core/widgets/user_avatar.dart`
- Test: extend or add `test/core/widgets/user_avatar_test.dart` (create if missing)

**Interfaces:**
- Consumes: `AppImage.asset`, `AppImage.network`
- Produces: same public `UserAvatar` API (`displayName`, `photoUrl`, `avatarId`, `radius`)

- [ ] **Step 1: Write/adjust test — initials still show when no photo/avatar**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/user_avatar.dart';

void main() {
  testWidgets('shows initials when no photo or avatarId', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: UserAvatar(displayName: 'Ada', radius: 20),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test (may PASS already)**

```bash
flutter test test/core/widgets/user_avatar_test.dart
```

- [ ] **Step 3: Replace image loads with AppImage**

In `user_avatar.dart`, for asset path:

```dart
return CircleAvatar(
  radius: radius,
  backgroundColor: ZipColors.mistDeep,
  child: ClipOval(
    child: AppImage.asset(
      assetPath,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorWidget: Center(child: _initials),
    ),
  ),
);
```

For network URL:

```dart
return CircleAvatar(
  radius: radius,
  backgroundColor: ZipColors.mistDeep,
  child: ClipOval(
    child: AppImage.network(
      url,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorWidget: Center(child: _initials),
      placeholder: Center(
        child: SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
  ),
);
```

Remove `backgroundImage: NetworkImage(url)`.

- [ ] **Step 4: Run user_avatar + existing profile/leaderboard avatar tests**

```bash
flutter test test/core/widgets/user_avatar_test.dart test/features/profile/view/profile_screen_test.dart
```

Expected: PASS (network tests may need `HttpOverrides` only if they hit real network — existing tests use display names / no photo).

- [ ] **Step 5: Format + analyze touched files**

- [ ] **Step 6: Commit** (skip unless user asked)

```bash
git commit -m "feat: route UserAvatar images through AppImage"
```

---

### Task 4: ProfileShimmer + Auth unknown branch

**Files:**
- Create: `lib/features/profile/view/widgets/profile_shimmer.dart`
- Modify: `lib/features/profile/view/profile_screen.dart` (auth branching only in this task)
- Test: `test/features/profile/view/widgets/profile_shimmer_test.dart`
- Modify: `test/features/profile/view/profile_screen_test.dart`

**Interfaces:**
- Consumes: `AppShimmer`, `AppShimmerBox`, `AppShimmerCircle`, `AppLayout`
- Produces: `class ProfileShimmer extends StatelessWidget { const ProfileShimmer({super.key}); }`

- [ ] **Step 1: Write ProfileShimmer smoke test**

```dart
testWidgets('ProfileShimmer exposes circle and boxes', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: ProfileShimmer()),
    ),
  );
  expect(find.byType(AppShimmerCircle), findsOneWidget);
  expect(find.byType(AppShimmerBox), findsWidgets);
});
```

- [ ] **Step 2: Implement `ProfileShimmer`**

Layout (match signed-in spacing):

```dart
AppShimmer(
  child: SingleChildScrollView(
    padding: AppLayout.of(context).pagePadding,
    child: Column(
      children: [
        const Center(child: AppShimmerCircle(radius: 56)),
        SizedBox(height: layout.space(16)),
        const Center(child: AppShimmerBox(width: 140, height: 22)),
        SizedBox(height: layout.space(8)),
        const Center(child: AppShimmerBox(width: 120, height: 14)),
        SizedBox(height: layout.space(12)),
        AppShimmerBox(height: 180, borderRadius: 16, width: double.infinity),
      ],
    ),
  ),
);
```

(If `width: double.infinity` is awkward inside unbounded width, use `SizedBox(width: double.infinity, child: AppShimmerBox(height: 180, borderRadius: 16))`.)

- [ ] **Step 3: Change ProfileScreen auth branch**

Replace:

```dart
final user = state.user;
if (user == null) {
  return const _SignedOutBody();
}
```

With:

```dart
switch (state.status) {
  case AuthStatus.unknown:
    return const ProfileShimmer();
  case AuthStatus.signedOut:
  case AuthStatus.signingIn:
  case AuthStatus.failure:
    if (state.user == null) return const _SignedOutBody();
    // fall through if user somehow present
    break;
  case AuthStatus.signedIn:
    break;
}
final user = state.user;
if (user == null) return const _SignedOutBody();
// existing BlocProvider + _SignedInBody
```

Simpler equivalent:

```dart
if (state.status == AuthStatus.unknown) {
  return const ProfileShimmer();
}
final user = state.user;
if (user == null) {
  return const _SignedOutBody();
}
```

- [ ] **Step 4: Add profile_screen tests**

```dart
testWidgets('auth unknown shows ProfileShimmer not sign-in CTA', (tester) async {
  final controller = StreamController<AppUser?>();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.authStateChanges()).thenAnswer((_) => controller.stream);

  await tester.pumpWidget(/* same MultiRepositoryProvider + AuthCubit + ProfileScreen */);
  await tester.pump();

  expect(find.byType(ProfileShimmer), findsOneWidget);
  expect(find.text(AppStrings.signInWithGoogle), findsNothing);

  await controller.close();
});

testWidgets('auth signedOut still shows sign-in CTA', (tester) async {
  await pumpProfile(tester, signedIn: null);
  expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
  expect(find.byType(ProfileShimmer), findsNothing);
});
```

Note: `pumpProfile(..., signedIn: null)` currently emits `Stream.value(null)` → `signedOut`. Keep that for signed-out test. Unknown test must use a **non-emitting** stream so cubit stays on default `unknown`.

- [ ] **Step 5: Run tests**

```bash
flutter test test/features/profile/view/widgets/profile_shimmer_test.dart test/features/profile/view/profile_screen_test.dart
```

Expected: PASS

- [ ] **Step 6: Format + analyze**

- [ ] **Step 7: Commit** (skip unless user asked)

```bash
git commit -m "feat: show ProfileShimmer while auth is unknown"
```

---

### Task 5: ProfileCubit.refresh + RefreshIndicator + edit badge

**Files:**
- Modify: `lib/features/profile/cubit/profile_state.dart`
- Modify: `lib/features/profile/cubit/profile_state.freezed.dart` (via build_runner if needed — enum change only may not require regen)
- Modify: `lib/features/profile/cubit/profile_cubit.dart`
- Modify: `lib/features/profile/view/profile_screen.dart`
- Modify: `test/features/profile/cubit/profile_cubit_test.dart`
- Modify: `test/features/profile/view/profile_screen_test.dart`

**Interfaces:**
- Produces:

```dart
enum ProfileStatus { idle, saving, failure, refreshing }

// ProfileCubit
Future<void> refresh(); // uses _profileRepository.getProfile(uid)
```

`refresh()` behavior:

1. If `_uid` null / closed → return.
2. Emit `status: refreshing` (clear error / failureKind none).
3. `final user = await _profileRepository.getProfile(uid);`
4. On success: emit `idle` with `profile: user` (and nameDraft seed rules same as `_onProfile`).
5. On `Failure`: emit `failure` with `failureKind: watchProfile` (reuse) and message.
6. Live `watchProfile` subscription remains active; a later stream event must not leave status stuck on `refreshing` — `_onProfile` should set `status: idle` when applying profile if current status is `refreshing` **or** `refresh()` always completes to idle/failure before return.

Preferred: `_onProfile` only updates `profile` / `nameDraft` (as today); `refresh()` owns status transitions end-to-end.

- [ ] **Step 1: Write failing cubit test**

```dart
blocTest<ProfileCubit, ProfileState>(
  'refresh emits refreshing then idle with profile',
  build: buildCubit,
  seed: () => const ProfileState(profile: original),
  setUp: () {
    when(() => repo.getProfile('u1')).thenAnswer((_) async => updated);
  },
  act: (cubit) => cubit.refresh(),
  expect: () => [
    const ProfileState(status: ProfileStatus.refreshing, profile: original),
    const ProfileState(
      status: ProfileStatus.idle,
      profile: updated,
      nameDraft: 'Grace', // if nameDraftTouched false and seedName applies
    ),
  ],
);
```

Adjust `nameDraft` expectation to match `_onProfile` / refresh seeding: if refresh copies `_onProfile` seeding logic when `!nameDraftTouched`, expect `nameDraft: updated.displayName`.

Also:

```dart
blocTest<ProfileCubit, ProfileState>(
  'refresh failure emits failure and keeps prior profile',
  build: buildCubit,
  seed: () => const ProfileState(profile: original),
  setUp: () {
    when(() => repo.getProfile('u1')).thenThrow(const Failure('offline'));
  },
  act: (cubit) => cubit.refresh(),
  expect: () => [
    const ProfileState(status: ProfileStatus.refreshing, profile: original),
    const ProfileState(
      status: ProfileStatus.failure,
      profile: original,
      error: 'offline',
      failureKind: ProfileFailureKind.watchProfile,
    ),
  ],
);
```

- [ ] **Step 2: Run cubit test — expect FAIL**

```bash
flutter test test/features/profile/cubit/profile_cubit_test.dart --name refresh
```

- [ ] **Step 3: Add `refreshing` + implement `refresh()`**

Store `uid` on the cubit as `final String? _uid` from constructor (today uid is only used in ctor — assign to field).

```dart
Future<void> refresh() async {
  final uid = _uid;
  if (uid == null || isClosed) return;
  emit(
    state.copyWith(
      status: ProfileStatus.refreshing,
      error: null,
      failureKind: ProfileFailureKind.none,
    ),
  );
  try {
    final user = await _profileRepository.getProfile(uid);
    if (isClosed) return;
    final seedName = !state.nameDraftTouched && user != null;
    emit(
      state.copyWith(
        status: ProfileStatus.idle,
        profile: user,
        nameDraft: seedName ? user.displayName : state.nameDraft,
        error: null,
        failureKind: ProfileFailureKind.none,
      ),
    );
  } on Failure catch (error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileStatus.failure,
        error: error.message,
        failureKind: ProfileFailureKind.watchProfile,
      ),
    );
  } catch (_) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileStatus.failure,
        error: AppStrings.profileSaveFailed,
        failureKind: ProfileFailureKind.watchProfile,
      ),
    );
  }
}
```

- [ ] **Step 4: Profile UI — RefreshIndicator + shimmer while refreshing + edit badge**

In `_SignedInBody.build`, when `state.status == ProfileStatus.refreshing`, return `const ProfileShimmer()` (still under listener).

Otherwise wrap scroll view:

```dart
return RefreshIndicator(
  color: ZipColors.ember,
  backgroundColor: ZipColors.wall,
  onRefresh: () => context.read<ProfileCubit>().refresh(),
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: layout.pagePadding,
    child: Column(
      children: [
        Center(
          child: Semantics(
            button: true,
            label: AppStrings.profileEditAvatar,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => unawaited(_openAvatarSheet(context)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    displayName: profile.displayName,
                    photoUrl: profile.photoUrl,
                    avatarId: profile.avatarId,
                    radius: 56,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: ZipColors.ember,
                      shape: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: ZipColors.onInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // … existing name + settings …
      ],
    ),
  ),
);
```

Ensure `BlocListener` still ignores name/avatar failures as today; watchProfile refresh failures still snackbar.

- [ ] **Step 5: Widget test — edit icon present when signed in**

```dart
testWidgets('signed-in avatar shows edit icon', (tester) async {
  await pumpProfile(tester, signedIn: user);
  expect(find.byIcon(Icons.edit), findsOneWidget);
});
```

- [ ] **Step 6: Run all related tests**

```bash
flutter test \
  test/features/profile/cubit/profile_cubit_test.dart \
  test/features/profile/view/profile_screen_test.dart \
  test/core/widgets/app_shimmer_test.dart \
  test/core/widgets/app_image_test.dart \
  test/core/widgets/user_avatar_test.dart
```

Expected: all PASS

- [ ] **Step 7: Format + analyze all touched Dart files**

- [ ] **Step 8: Commit** (skip unless user asked)

```bash
git commit -m "feat: profile refresh shimmer and avatar edit badge"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Auth unknown → ProfileShimmer | Task 4 |
| signedOut → existing mock | Task 4 |
| Edit badge Stack | Task 5 |
| AppShimmer primitives | Task 1 |
| ProfileShimmer layout | Task 4 |
| refreshing + RefreshIndicator | Task 5 |
| AppImage network/asset/file/memory + SVG | Task 2 |
| UserAvatar via AppImage | Task 3 |
| saving ≠ full-body shimmer | Task 5 (only `refreshing`) |
| Tests listed in spec | Tasks 2–5 |

## Self-review notes

- No TBD placeholders left; `isSvg` / memory sniff locked in Task 2.
- `ProfileStatus.refreshing` naming consistent across cubit, screen, tests.
- Commit steps optional per Global Constraints / user commit rule.
