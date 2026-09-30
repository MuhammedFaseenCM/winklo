# Dashboard Bottom Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Dashboard shell with bottom nav (Home, Leaderboard, Profile), move auth chrome to Profile, and support editable display name plus preset/custom avatars persisted to Firestore/Storage.

**Architecture:** `go_router` `StatefulShellRoute.indexedStack` hosts the three tabs; games/results stay sibling full-screen routes. `AuthCubit` remains session-only. New `ProfileRepository` + usecases + `ProfileCubit` own profile edits. Shared avatar helper resolves `avatarId` → asset, else `photoUrl` → network, else initials. Leaderboard denormalization requires a Firestore rules change (today updates are improve-only).

**Tech Stack:** Flutter / Dart, `go_router` ^18, `flutter_bloc`, `freezed`, Firebase Auth / Firestore / Storage, `image_picker`, `bloc_test` / `mocktail`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-dashboard-bottom-nav-design.md`
- All user-facing copy via `AppStrings`
- Feature-first BLoC; `domain/` must not import Flutter UI
- UI reads deps via `context.read` / `RepositoryProvider` — never construct repos in widgets
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)
- Display name: trim, non-empty, max 24 chars
- Gallery only for custom photos (no camera)
- Bottom nav only on shell tabs

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/features/dashboard/view/dashboard_shell.dart` | Scaffold + `NavigationBar` around `StatefulNavigationShell` |
| `lib/core/router/app_router.dart` | Shell branches + sibling game/results routes |
| `lib/features/home/view/home_screen.dart` | Remove header leaderboard + auth avatar |
| `lib/features/results/view/mini_leaderboard_panel.dart` | `go` to `/leaderboard` (select tab) |
| `lib/features/profile/view/profile_screen.dart` | Signed-out CTA / signed-in edit UI |
| `lib/features/profile/view/widgets/avatar_edit_sheet.dart` | Preset grid + gallery pick |
| `lib/features/profile/cubit/profile_cubit.dart` | Edit/save/upload state |
| `lib/features/profile/cubit/profile_state.dart` | Freezed profile UI state |
| `lib/domain/entities/app_user.dart` | Add optional `avatarId` |
| `lib/domain/entities/leaderboard_entry.dart` | Add optional `avatarId` |
| `lib/domain/avatars/avatar_catalog.dart` | Preset ids + asset paths (pure Dart) |
| `lib/domain/repositories/profile_repository.dart` | Watch/update profile interface |
| `lib/domain/usecases/update_display_name.dart` | Name validation + repo call |
| `lib/domain/usecases/update_avatar.dart` | Preset or bytes → repo |
| `lib/data/repositories/profile_repository_impl.dart` | Firestore + Storage + denormalize |
| `lib/data/repositories/auth_repository_impl.dart` | Map user from Firestore profile when present |
| `lib/data/repositories/leaderboard_repository_impl.dart` | Read profile fields; parse `avatarId`; allow profile denormalize writes |
| `lib/core/widgets/user_avatar.dart` | Shared avatar rendering (2+ features) |
| `lib/features/leaderboard/view/widgets/leaderboard_row.dart` | Use `UserAvatar` |
| `lib/core/strings/app_strings.dart` | Nav + profile copy |
| `lib/core/di/app_repositories.dart` | Register profile repo + usecases |
| `assets/avatars/` | `preset_01.png` … `preset_06.png` (placeholders OK) |
| `pubspec.yaml` | `image_picker`, `firebase_storage`, `assets/avatars/` |
| `firestore/firestore.rules` | Allow `avatarId` on users + leaderboard; profile-field updates |
| `storage.rules` (new) | Own-uid avatar upload/read |
| `FIREBASE.md` | Storage + profile fields checklist |
| Tests under `test/domain/`, `test/features/profile/`, `test/core/widgets/` | As listed per task |

---

### Task 1: Strings + Dashboard shell + StatefulShellRoute

**Files:**
- Create: `lib/features/dashboard/view/dashboard_shell.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/strings/app_strings.dart`
- Create: `lib/features/profile/view/profile_screen.dart` (minimal stub: signed-out CTA + signed-in name/sign-out using `AuthCubit` only — editing comes in later tasks)
- Test: `test/features/dashboard/dashboard_shell_test.dart`

**Interfaces:**
- Produces: `DashboardShell({ required StatefulNavigationShell navigationShell })`
- Routes: `/`, `/leaderboard`, `/profile` inside shell; existing game/results routes remain **siblings** of the shell (not nested under it)

- [ ] **Step 1: Add AppStrings**

Append to `lib/core/strings/app_strings.dart`:

```dart
  // Dashboard nav
  static const navHome = 'Home';
  static const navLeaderboard = 'Leaderboard';
  static const navProfile = 'Profile';

  // Profile
  static const profileTitle = 'Profile';
  static const profileSignedOutTitle = 'Your profile';
  static const profileSignedOutBody =
      'Sign in to set your name and avatar for the leaderboard.';
  static const profileEditName = 'Display name';
  static const profileNameHint = 'Enter a display name';
  static const profileNameEmpty = 'Name can’t be empty.';
  static const profileNameTooLong = 'Name must be 24 characters or fewer.';
  static const profileSave = 'Save';
  static const profileEditAvatar = 'Edit avatar';
  static const profileChoosePhoto = 'Choose from photos';
  static const profilePresets = 'Presets';
  static const profileSaveFailed = 'Could not save profile. Try again.';
  static const profileUploadFailed = 'Could not upload photo. Try again.';
  static const profilePermissionDenied =
      'Photo access was denied. Enable it in Settings to upload an avatar.';
```

- [ ] **Step 2: Write failing shell test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/features/dashboard/view/dashboard_shell.dart';

void main() {
  testWidgets('shows three nav destinations', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return DashboardShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const Text('home-body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/leaderboard',
                  builder: (_, _) => const Text('lb-body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, _) => const Text('profile-body'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);
    expect(find.text('home-body'), findsOneWidget);

    await tester.tap(find.text(AppStrings.navProfile));
    await tester.pumpAndSettle();
    expect(find.text('profile-body'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test — expect FAIL** (missing `DashboardShell`)

Run: `flutter test test/features/dashboard/dashboard_shell_test.dart`  
Expected: FAIL compiling / missing library

- [ ] **Step 4: Implement `DashboardShell`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: ZipColors.wall,
        indicatorColor: ZipColors.emberSoft,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: AppStrings.navLeaderboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire `app_router.dart`**

Replace the flat `/` and `/leaderboard` routes with a shell; keep game/results as top-level siblings:

```dart
import '../../features/dashboard/view/dashboard_shell.dart';
import '../../features/profile/view/profile_screen.dart';
// ...existing imports...

GoRouter buildRouter({required AnalyticsRepository analytics}) {
  return GoRouter(
    initialLocation: '/',
    observers: [AnalyticsRouteObserver(analytics)],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                name: 'leaderboard',
                builder: (context, state) {
                  final game = state.uri.queryParameters['game'];
                  return LeaderboardScreen(
                    initialGameId: game == GameIds.pathWords
                        ? GameIds.pathWords
                        : GameIds.zip,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/zip',
        name: 'zip',
        builder: (context, state) => const ZipScreen(),
      ),
      // ... path-words, word-match, category-race, results unchanged ...
    ],
  );
}
```

- [ ] **Step 6: Minimal `ProfileScreen` stub**

Signed-out: title/body + button calling `showSignInSheet`.  
Signed-in: show `user.displayName` + Sign out via `AuthCubit`.  
No avatar edit yet.

- [ ] **Step 7: Re-run shell test + analyze**

Run:

```bash
flutter test test/features/dashboard/dashboard_shell_test.dart
dart analyze lib/features/dashboard/view/dashboard_shell.dart lib/core/router/app_router.dart lib/features/profile/view/profile_screen.dart
```

Expected: PASS / no issues

- [ ] **Step 8: Commit** (only if user asked)

```bash
git add lib/features/dashboard lib/features/profile/view/profile_screen.dart lib/core/router/app_router.dart lib/core/strings/app_strings.dart test/features/dashboard
git commit -m "feat: add dashboard shell with Home, Leaderboard, Profile tabs"
```

---

### Task 2: Home header cleanup + leaderboard tab navigation

**Files:**
- Modify: `lib/features/home/view/home_screen.dart` (remove `_AuthAvatarButton`, leaderboard `IconButton`, related imports if unused)
- Modify: `lib/features/results/view/mini_leaderboard_panel.dart` — change `context.push('/leaderboard?game=$gameId')` → `context.go('/leaderboard?game=$gameId')`
- Test: extend or add `test/features/home/home_header_test.dart` **or** update an existing home widget test if present; otherwise a focused test that pumps `_HomeHeader` equivalents via `HomeScreen` with mocked cubits is optional — minimum: manual verify + `dart analyze` on touched files. Prefer a small widget test that `HomeScreen` header text exists and `Icons.login` / trophies are absent when Auth is mocked signed-out.

**Interfaces:**
- Consumes: shell routes from Task 1
- Produces: Home without auth/leaderboard chrome; “See full leaderboard” selects shell tab

- [ ] **Step 1: Remove header chrome from `_HomeHeader`**

Keep brand mark + title + tagline only. Delete `_AuthAvatarButton` class entirely. Remove unused auth imports from `home_screen.dart` if nothing else needs them (Play gate may still use `AuthCubit` / `showSignInSheet` — keep those).

- [ ] **Step 2: Change mini panel navigation**

```dart
onPressed: () => context.go('/leaderboard?game=$gameId'),
```

- [ ] **Step 3: Analyze + smoke test**

```bash
dart analyze lib/features/home/view/home_screen.dart lib/features/results/view/mini_leaderboard_panel.dart
flutter test test/features/results/results_screen_test.dart
```

Expected: no issues; existing results tests still pass

- [ ] **Step 4: Commit** (only if user asked)

```bash
git commit -m "refactor: move auth and leaderboard entry points to dashboard tabs"
```

---

### Task 3: Domain — `avatarId`, catalog, profile repository + usecases

**Files:**
- Modify: `lib/domain/entities/app_user.dart`
- Modify: `lib/domain/entities/leaderboard_entry.dart`
- Create: `lib/domain/avatars/avatar_catalog.dart`
- Create: `lib/domain/repositories/profile_repository.dart`
- Create: `lib/domain/usecases/update_display_name.dart`
- Create: `lib/domain/usecases/update_avatar.dart`
- Test: `test/domain/usecases/profile_usecases_test.dart`
- Test: `test/domain/avatars/avatar_catalog_test.dart`
- Update any tests constructing `AppUser` / `LeaderboardEntry` if constructors break (optional named param — should not break)

**Interfaces:**
- Produces:

```dart
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
  });
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
}

class LeaderboardEntry {
  // ...existing fields...
  final String? avatarId;
}

abstract final class AvatarCatalog {
  static const presetIds = [
    'preset_01', 'preset_02', 'preset_03',
    'preset_04', 'preset_05', 'preset_06',
  ];
  static String? assetPathFor(String? avatarId);
  static bool isPresetId(String id);
}

abstract class ProfileRepository {
  Stream<AppUser?> watchProfile(String uid);
  Future<AppUser?> getProfile(String uid);
  Future<AppUser> updateDisplayName(String displayName);
  Future<AppUser> updateAvatarPreset(String avatarId);
  Future<AppUser> updateAvatarPhoto(List<int> bytes, {String contentType = 'image/jpeg'});
}

class UpdateDisplayName {
  const UpdateDisplayName(this._repo);
  final ProfileRepository _repo;
  /// Throws [Failure] on validation or repo errors.
  Future<AppUser> call(String rawName);
}

class UpdateAvatar {
  const UpdateAvatar(this._repo);
  final ProfileRepository _repo;
  Future<AppUser> preset(String avatarId);
  Future<AppUser> photo(List<int> bytes, {String contentType = 'image/jpeg'});
}
```

- [ ] **Step 1: Failing catalog + usecase tests**

```dart
// test/domain/avatars/avatar_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('maps known preset to asset path', () {
    expect(
      AvatarCatalog.assetPathFor('preset_01'),
      'assets/avatars/preset_01.png',
    );
  });

  test('unknown id returns null', () {
    expect(AvatarCatalog.assetPathFor('nope'), isNull);
  });
}
```

```dart
// test/domain/usecases/profile_usecases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_01');
  late _MockProfileRepository repo;

  setUp(() {
    repo = _MockProfileRepository();
  });

  group('UpdateDisplayName', () {
    test('trims and forwards', () async {
      when(() => repo.updateDisplayName('Ada')).thenAnswer((_) async => user);
      expect(await UpdateDisplayName(repo)('  Ada  '), user);
    });

    test('empty throws Failure', () async {
      expect(
        () => UpdateDisplayName(repo)('   '),
        throwsA(isA<Failure>()),
      );
      verifyNever(() => repo.updateDisplayName(any()));
    });

    test('too long throws Failure', () async {
      expect(
        () => UpdateDisplayName(repo)('a' * 25),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('UpdateAvatar', () {
    test('preset forwards', () async {
      when(() => repo.updateAvatarPreset('preset_02'))
          .thenAnswer((_) async => user);
      expect(await UpdateAvatar(repo).preset('preset_02'), user);
    });

    test('invalid preset throws before repo', () async {
      expect(
        () => UpdateAvatar(repo).preset('nope'),
        throwsA(isA<Failure>()),
      );
      verifyNever(() => repo.updateAvatarPreset(any()));
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `flutter test test/domain/avatars/avatar_catalog_test.dart test/domain/usecases/profile_usecases_test.dart`

- [ ] **Step 3: Implement domain types + usecases**

`UpdateDisplayName` validation:

```dart
final trimmed = rawName.trim();
if (trimmed.isEmpty) throw const Failure('Name can’t be empty.');
if (trimmed.length > 24) {
  throw const Failure('Name must be 24 characters or fewer.');
}
return _repo.updateDisplayName(trimmed);
```

`UpdateAvatar.preset`: if `!AvatarCatalog.isPresetId(avatarId)` throw `Failure('Invalid avatar.')`.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit** (only if user asked)

---

### Task 4: Profile repository impl + DI + Firestore/Storage rules

**Files:**
- Create: `lib/data/repositories/profile_repository_impl.dart`
- Modify: `lib/core/di/app_repositories.dart`
- Modify: `lib/data/repositories/auth_repository_impl.dart` — after auth, prefer Firestore `users/{uid}` fields (`displayName`, `photoUrl`, `avatarId`) when mapping for `authStateChanges` / `currentUser` (switchMap / async map). On first sign-in upsert, do not wipe an existing `avatarId`.
- Modify: `lib/data/repositories/leaderboard_repository_impl.dart` — parse `avatarId`; on submit, read profile from `users/{uid}` for `displayName` / `photoUrl` / `avatarId`; write those fields on leaderboard docs
- Modify: `firestore/firestore.rules` — allow `avatarId` on user + leaderboard docs; allow **profile-only** leaderboard updates (same `timeSeconds`, only identity fields change)
- Create: `storage.rules`
- Modify: `FIREBASE.md` — Storage enable + rules deploy + profile fields
- Modify: `pubspec.yaml` — add `firebase_storage`, `image_picker`
- Create placeholder PNGs under `assets/avatars/` and register folder in `pubspec.yaml`
- Test: `test/data/repositories/profile_repository_impl_test.dart` if feasible with fakes; otherwise cover via usecase mocks + manual Firebase checklist. Prefer unit-testing pure mapping helpers extracted from the impl if Firebase fakes are heavy.

**Interfaces:**
- Consumes: `ProfileRepository` from Task 3
- Produces: working `ProfileRepositoryImpl` registered in DI

**Firestore rules (leaderboard profile patch):** extend `validLeaderboardKeys` to include `avatarId`. Add:

```
function profileOnlyLeaderboardUpdate() {
  return request.resource.data.timeSeconds == resource.data.timeSeconds
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['displayName', 'photoUrl', 'avatarId', 'updatedAt']);
}
```

Allow `update` if `improvingTime() && validLeaderboardKeys()` **OR** `isOwner(uid) && validGame(gameId) && profileOnlyLeaderboardUpdate()`.

**Users doc:** allow `avatarId` string|null (no need to enumerate keys strictly unless already constrained).

**Storage rules:**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /avatars/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == uid
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

(Adjust path if impl uses `avatars/{uid}.jpg` — match the exact object path used in code.)

- [ ] **Step 1: Add packages + assets**

```bash
flutter pub add firebase_storage image_picker
```

Add `assets/avatars/` with six placeholder PNGs (`preset_01.png` … `preset_06.png`). Register `- assets/avatars/` in `pubspec.yaml`.

Android: ensure gallery permission notes for `image_picker` (READ_MEDIA_IMAGES / photos permission as required by current plugin docs). Document in `FIREBASE.md` or Android README snippet inside the same FIREBASE update.

- [ ] **Step 2: Implement `ProfileRepositoryImpl`**

Behavior:

1. `watchProfile` / `getProfile` — `users/{uid}` snapshots → `AppUser`
2. `updateDisplayName` — require signed-in; write Firestore; `user.updateDisplayName`; denormalize leaderboard docs for `zip` + `path_words` (all_time + today’s daily entry if present) with merge update of identity fields only
3. `updateAvatarPreset` — set `avatarId`, set `photoUrl` null in Firestore; clear Auth photoURL if API allows; denormalize
4. `updateAvatarPhoto` — upload bytes to Storage `avatars/{uid}`; set `photoUrl` download URL, `avatarId` null; update Auth photoURL; denormalize
5. Fail soft when `FirebaseBootstrap.isReady == false` → throw `Failure('Firebase is unavailable. Try again later.')`

- [ ] **Step 3: Register DI**

```dart
RepositoryProvider<ProfileRepository>(
  create: (_) => ProfileRepositoryImpl(),
),
RepositoryProvider<UpdateDisplayName>(
  create: (context) => UpdateDisplayName(context.read<ProfileRepository>()),
),
RepositoryProvider<UpdateAvatar>(
  create: (context) => UpdateAvatar(context.read<ProfileRepository>()),
),
```

- [ ] **Step 4: Update rules + FIREBASE.md**

Deploy instructions:

```bash
firebase deploy --only firestore:rules,storage
```

- [ ] **Step 5: Analyze touched files**

```bash
dart analyze lib/data/repositories/profile_repository_impl.dart lib/core/di/app_repositories.dart lib/data/repositories/auth_repository_impl.dart lib/data/repositories/leaderboard_repository_impl.dart
```

- [ ] **Step 6: Commit** (only if user asked)

---

### Task 5: Shared `UserAvatar` + LeaderboardRow

**Files:**
- Create: `lib/core/widgets/user_avatar.dart`
- Modify: `lib/features/leaderboard/view/widgets/leaderboard_row.dart`
- Modify: Profile screen (Task 6 will use it; wire row now)
- Test: `test/core/widgets/user_avatar_test.dart`

**Interfaces:**
- Produces:

```dart
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
    this.radius = 18,
  });
}
```

Resolution order: `AvatarCatalog.assetPathFor(avatarId)` → `Image.asset`; else non-empty `photoUrl` → `NetworkImage`; else initial letter.

- [ ] **Step 1: Widget test**

```dart
testWidgets('prefers preset asset over photoUrl', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: UserAvatar(
          displayName: 'Ada',
          avatarId: 'preset_01',
          photoUrl: 'https://example.com/x.png',
          radius: 20,
        ),
      ),
    ),
  );
  expect(find.byType(Image), findsOneWidget);
});
```

- [ ] **Step 2: Implement + switch `LeaderboardRow` CircleAvatar to `UserAvatar`**

- [ ] **Step 3: Run tests + analyze**

```bash
flutter test test/core/widgets/user_avatar_test.dart test/features/leaderboard/view/leaderboard_row_test.dart
```

- [ ] **Step 4: Commit** (only if user asked)

---

### Task 6: ProfileCubit + full Profile UI (edit name + avatar sheet)

**Files:**
- Create: `lib/features/profile/cubit/profile_state.dart` (+ freezed part)
- Create: `lib/features/profile/cubit/profile_cubit.dart`
- Modify: `lib/features/profile/view/profile_screen.dart`
- Create: `lib/features/profile/view/widgets/avatar_edit_sheet.dart`
- Test: `test/features/profile/cubit/profile_cubit_test.dart`

**Interfaces:**
- Consumes: `UpdateDisplayName`, `UpdateAvatar`, `AuthCubit`, `ProfileRepository.watchProfile`
- Produces:

```dart
enum ProfileStatus { idle, saving, failure }

@freezed
sealed class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(ProfileStatus.idle) ProfileStatus status,
    AppUser? profile,
    String? error,
    @Default('') String nameDraft,
  }) = _ProfileState;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required ProfileRepository profileRepository,
    required UpdateDisplayName updateDisplayName,
    required UpdateAvatar updateAvatar,
    required String? uid,
  });
  void setNameDraft(String value);
  Future<void> saveName();
  Future<void> selectPreset(String avatarId);
  Future<void> uploadPhoto(List<int> bytes, {String contentType});
}
```

When `uid == null`, state stays empty (UI shows signed-out from `AuthCubit`). When `uid != null`, subscribe to `watchProfile(uid)`.

- [ ] **Step 1: Write failing `bloc_test`s**

Cases:

1. `saveName` success → status idle, profile updated  
2. `saveName` empty draft → failure with validation message, repo not called  
3. `selectPreset` failure from repo → status failure  

Use `mocktail` + `bloc_test`.

- [ ] **Step 2: Run — expect FAIL** then implement cubit + `build_runner` for freezed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Profile UI**

- Provide `ProfileCubit` when signed in (`BlocProvider` in `ProfileScreen`)
- Signed-out: existing CTA
- Signed-in: large `UserAvatar`, name field/draft + Save, Sign out, tap avatar → `showModalBottomSheet` with `AvatarEditSheet`
- `AvatarEditSheet`: preset grid (`AvatarCatalog.presetIds`) + “Choose from photos” using `ImagePicker().pickImage(source: ImageSource.gallery)`; read bytes; call cubit; handle permission errors with `AppStrings.profilePermissionDenied`

- [ ] **Step 4: Tests + analyze**

```bash
flutter test test/features/profile/cubit/profile_cubit_test.dart
dart analyze lib/features/profile
```

- [ ] **Step 5: Commit** (only if user asked)

---

### Task 7: End-to-end verification checklist

**Files:** none required beyond fixes found

- [ ] **Step 1: Automated**

```bash
flutter test test/features/dashboard test/domain/avatars test/domain/usecases/profile_usecases_test.dart test/features/profile test/core/widgets/user_avatar_test.dart test/features/leaderboard test/features/results
dart analyze lib/features/dashboard lib/features/profile lib/core/router/app_router.dart lib/core/widgets/user_avatar.dart lib/domain/avatars lib/domain/repositories/profile_repository.dart lib/data/repositories/profile_repository_impl.dart
```

Expected: all PASS / no analyzer issues

- [ ] **Step 2: Manual (device/emulator)**

1. Bottom nav on Home / Leaderboard / Profile; absent on Zip / Path Words / Results  
2. Home header has no login avatar / trophy button  
3. Signed-out Profile → sign-in sheet → signed-in Profile  
4. Edit name → appears on Profile + Leaderboard after refresh/stream  
5. Pick preset → avatar updates on Profile + Leaderboard  
6. Upload gallery photo → avatar updates  
7. “See full leaderboard” from results lands on Leaderboard **tab** (nav selected)  
8. Sign out from Profile  

- [ ] **Step 3: Commit** (only if user asked) any leftover fixes

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| StatefulShellRoute + 3 tabs | 1 |
| Games/results outside shell (no bottom nav) | 1 |
| Home games list unchanged | 1–2 |
| Remove Home auth + leaderboard chrome | 2 |
| Leaderboard tab reuses existing screen | 1 |
| Profile signed-out CTA only | 1, 6 |
| Editable name + presets + gallery photo | 3–6 |
| `avatarId` + shared avatar helper | 3, 5 |
| ProfileRepository / usecases / DI | 3–4 |
| Storage upload + rules | 4 |
| Denormalize leaderboard identity fields | 4 (incl. rules fix) |
| `AppStrings` only | 1, 6 |
| Tests (cubit / usecase / shell) | 1, 3, 5, 6, 7 |
| FIREBASE.md | 4 |
| Out of scope (camera, guest profiles, stats) | not implemented |

**Rules note:** Existing improve-only leaderboard `update` would block denormalization — Task 4’s `profileOnlyLeaderboardUpdate` is required for the spec to work.

**Type consistency:** `avatarId` optional on `AppUser` + `LeaderboardEntry`; `AvatarCatalog.presetIds` / `assetPathFor`; `UpdateAvatar.preset` / `photo`; `UserAvatar` resolution order matches spec.
