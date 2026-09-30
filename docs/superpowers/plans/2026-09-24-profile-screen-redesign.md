# Profile Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign signed-in Profile into an identity hero + settings list, move name editing to a sheet, and add Privacy (WebView), About (dialog), Report an issue (Firestore + user metadata), Log out — with analytics and tests.

**Architecture:** Keep `ProfileCubit` for avatar/name. Add `IssueReportRepository` + `SubmitIssueReport` + `ReportIssueCubit` for the report form. New child routes under the profile shell branch for privacy WebView and report screen. Analytics via existing `AnalyticsRepository`. All user-facing copy via `AppStrings`.

**Tech Stack:** Flutter / Dart, `flutter_bloc` / `freezed`, `go_router`, `cloud_firestore`, `webview_flutter`, `package_info_plus`, `bloc_test` / `mocktail`, existing `ZipColors` / Lexend theme.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-profile-screen-redesign-design.md`
- All user-facing copy via `AppStrings` (no inline UI strings)
- Domain stays Flutter-free (`domain/` must not import `package:flutter/*`)
- Privacy URL: `https://muhammedfaseencm.github.io/winklo/privacy/`
- Report label: **Report an issue**; fields title (max 80) + description (max 2000)
- Signed-out Profile unchanged aside from mock visual match (no settings list)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/core/strings/app_strings.dart` | Profile / about / report / privacy copy |
| `lib/core/constants/app_urls.dart` | Privacy policy URL constant |
| `lib/domain/repositories/analytics_repository.dart` | Profile analytics method signatures |
| `lib/data/repositories/firebase_analytics_repository_impl.dart` | Firebase event impl |
| `test/helpers/mock_analytics_repository.dart` | Stub new analytics methods |
| `lib/domain/repositories/issue_report_repository.dart` | Submit interface |
| `lib/domain/usecases/submit_issue_report.dart` | Validate + submit |
| `lib/data/repositories/issue_report_repository_impl.dart` | Firestore write + PackageInfo/platform |
| `lib/core/di/app_repositories.dart` | Register repo + usecase |
| `firestore/firestore.rules` | `issue_reports` create-only rules |
| `FIREBASE.md` | Document collection |
| `lib/features/profile/cubit/report_issue_cubit.dart` | Form state machine |
| `lib/features/profile/cubit/report_issue_state.dart` | Freezed state |
| `lib/features/profile/view/widgets/name_edit_sheet.dart` | Name field + Save sheet |
| `lib/features/profile/view/widgets/profile_settings_list.dart` | Grouped list tiles |
| `lib/features/profile/view/widgets/about_game_dialog.dart` | About dialog |
| `lib/features/profile/view/privacy_webview_screen.dart` | In-app WebView |
| `lib/features/profile/view/report_issue_screen.dart` | Report form screen |
| `lib/features/profile/view/profile_screen.dart` | Hero + list layout |
| `lib/features/profile/view/widgets/profile_signed_out_mock.dart` | Match new layout visually |
| `lib/core/router/app_router.dart` | `/profile/privacy`, `/profile/report` children |
| Tests under `test/features/profile/`, `test/domain/usecases/` | Cubit, usecase, widgets |

---

### Task 1: App strings, privacy URL, profile analytics

**Files:**
- Create: `lib/core/constants/app_urls.dart`
- Modify: `lib/core/strings/app_strings.dart`
- Modify: `lib/domain/repositories/analytics_repository.dart`
- Modify: `lib/data/repositories/firebase_analytics_repository_impl.dart`
- Modify: `test/helpers/mock_analytics_repository.dart`
- Modify: `test/data/repositories/firebase_analytics_repository_impl_test.dart`

**Interfaces:**
- Produces:

```dart
// lib/core/constants/app_urls.dart
abstract final class AppUrls {
  static const privacyPolicy =
      'https://muhammedfaseencm.github.io/winklo/privacy/';
}

// AnalyticsRepository additions:
Future<void> logProfilePrivacyOpened();
Future<void> logProfileAboutOpened();
Future<void> logProfileReportOpened();
Future<void> logProfileReportSubmitted();
Future<void> logProfileSignOut();
```

- Event names (exact): `profile_privacy_opened`, `profile_about_opened`, `profile_report_opened`, `profile_report_submitted`, `profile_sign_out`
- No parameters on these events

- [ ] **Step 1: Add AppUrls + AppStrings**

Add to `AppStrings` (Profile section):

```dart
static const profileEditDisplayName = 'Edit display name';
static const profilePrivacyPolicy = 'Privacy policy';
static const profileAboutGame = 'About the game';
static const profileReportIssue = 'Report an issue';
static const profileAboutBody =
    'Winklo is a daily puzzle app with solo mini-games like Zip and Path Words. '
    'Clear today’s puzzles, climb the leaderboard, and keep your streak going.';
static String profileAboutVersion(String version) => 'Version $version';
static const profileReportTitleLabel = 'Title';
static const profileReportTitleHint = 'Short summary';
static const profileReportDescriptionLabel = 'Description';
static const profileReportDescriptionHint = 'What went wrong or what you’d like to see?';
static const profileReportTitleEmpty = 'Title can’t be empty.';
static const profileReportTitleTooLong = 'Title must be 80 characters or fewer.';
static const profileReportDescriptionEmpty = 'Description can’t be empty.';
static const profileReportDescriptionTooLong =
    'Description must be 2000 characters or fewer.';
static const profileReportSend = 'Send';
static const profileReportSent = 'Thanks — your report was sent.';
static const profileReportFailed = 'Could not send report. Try again.';
static const profilePrivacyFailed = 'Could not load the privacy policy.';
static const profilePrivacyRetry = 'Retry';
```

Reuse existing `AppStrings.signOut`, `profileEditName`, `profileSave`, `profileNameHint`, etc. Keep `tutorialGotIt` / add `profileAboutGotIt = 'Got it'` if you want a dedicated key — prefer reusing `tutorialGotIt` only if wording matches; otherwise add `profileAboutGotIt = 'Got it'`.

Create `lib/core/constants/app_urls.dart` with `AppUrls.privacyPolicy` as above.

- [ ] **Step 2: Extend AnalyticsRepository + impl + stubs**

Add the five methods to the interface. Implement in `FirebaseAnalyticsRepositoryImpl` with `_safe` + `logEvent(name: '...')` and no parameters.

Update `stubAnalytics` in `test/helpers/mock_analytics_repository.dart` to stub all five as `thenAnswer((_) async {})`.

Update `firebase_analytics_repository_impl_test.dart` to call the new methods (same no-op-when-Firebase-not-ready test style).

- [ ] **Step 3: Format, analyze, test**

```bash
dart format lib/core/constants/app_urls.dart lib/core/strings/app_strings.dart \
  lib/domain/repositories/analytics_repository.dart \
  lib/data/repositories/firebase_analytics_repository_impl.dart \
  test/helpers/mock_analytics_repository.dart \
  test/data/repositories/firebase_analytics_repository_impl_test.dart
dart analyze lib/core/constants/app_urls.dart lib/core/strings/app_strings.dart \
  lib/domain/repositories/analytics_repository.dart \
  lib/data/repositories/firebase_analytics_repository_impl.dart
flutter test test/data/repositories/firebase_analytics_repository_impl_test.dart
```

Expected: analyze clean; tests PASS.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add lib/core/constants/app_urls.dart lib/core/strings/app_strings.dart \
  lib/domain/repositories/analytics_repository.dart \
  lib/data/repositories/firebase_analytics_repository_impl.dart \
  test/helpers/mock_analytics_repository.dart \
  test/data/repositories/firebase_analytics_repository_impl_test.dart
git commit -m "feat: add profile strings and analytics events"
```

---

### Task 2: `SubmitIssueReport` domain usecase

**Files:**
- Create: `lib/domain/repositories/issue_report_repository.dart`
- Create: `lib/domain/usecases/submit_issue_report.dart`
- Create: `test/domain/usecases/submit_issue_report_test.dart`

**Interfaces:**
- Consumes: `AppUser`, `Failure`, `AppStrings` validation copy
- Produces:

```dart
abstract class IssueReportRepository {
  /// Persists a report. Throws [Failure] on infra errors.
  Future<void> submit({
    required String title,
    required String description,
    required AppUser user,
  });
}

class SubmitIssueReport {
  const SubmitIssueReport(this._repo);
  final IssueReportRepository _repo;

  /// Validates then submits. Throws [Failure] on validation or repo errors.
  Future<void> call({
    required String title,
    required String description,
    required AppUser user,
  });
}
```

- Validation (trim first):
  - title empty → `Failure(AppStrings.profileReportTitleEmpty)`
  - title length > 80 → `Failure(AppStrings.profileReportTitleTooLong)`
  - description empty → `Failure(AppStrings.profileReportDescriptionEmpty)`
  - description length > 2000 → `Failure(AppStrings.profileReportDescriptionTooLong)`
- Pass **trimmed** title/description to the repo

- [ ] **Step 1: Write the failing usecase test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';

class _MockRepo extends Mock implements IssueReportRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada');
  late _MockRepo repo;
  late SubmitIssueReport submit;

  setUp(() {
    repo = _MockRepo();
    submit = SubmitIssueReport(repo);
    when(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(user);
  });

  test('trims and submits valid report', () async {
    await submit(
      title: '  Bug  ',
      description: '  Details here  ',
      user: user,
    );
    verify(
      () => repo.submit(
        title: 'Bug',
        description: 'Details here',
        user: user,
      ),
    ).called(1);
  });

  test('empty title throws and skips repo', () async {
    expect(
      () => submit(title: '  ', description: 'x', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportTitleEmpty,
        ),
      ),
    );
    verifyNever(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    );
  });

  test('title over 80 throws', () async {
    expect(
      () => submit(title: 'a' * 81, description: 'x', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportTitleTooLong,
        ),
      ),
    );
  });

  test('empty description throws', () async {
    expect(
      () => submit(title: 't', description: ' \n ', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportDescriptionEmpty,
        ),
      ),
    );
  });

  test('description over 2000 throws', () async {
    expect(
      () => submit(title: 't', description: 'd' * 2001, user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportDescriptionTooLong,
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/domain/usecases/submit_issue_report_test.dart
```

Expected: FAIL (missing library / class).

- [ ] **Step 3: Implement repository interface + usecase**

```dart
// issue_report_repository.dart
import '../entities/app_user.dart';

abstract class IssueReportRepository {
  Future<void> submit({
    required String title,
    required String description,
    required AppUser user,
  });
}
```

```dart
// submit_issue_report.dart
import '../../core/strings/app_strings.dart';
import '../entities/app_user.dart';
import '../failures.dart';
import '../repositories/issue_report_repository.dart';

class SubmitIssueReport {
  const SubmitIssueReport(this._repo);
  final IssueReportRepository _repo;

  Future<void> call({
    required String title,
    required String description,
    required AppUser user,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    if (trimmedTitle.isEmpty) {
      throw const Failure(AppStrings.profileReportTitleEmpty);
    }
    if (trimmedTitle.length > 80) {
      throw const Failure(AppStrings.profileReportTitleTooLong);
    }
    if (trimmedDescription.isEmpty) {
      throw const Failure(AppStrings.profileReportDescriptionEmpty);
    }
    if (trimmedDescription.length > 2000) {
      throw const Failure(AppStrings.profileReportDescriptionTooLong);
    }
    return _repo.submit(
      title: trimmedTitle,
      description: trimmedDescription,
      user: user,
    );
  }
}
```

Note: `AppStrings` lives under `lib/core/` and is pure Dart (no Flutter imports) — confirm before importing from domain. If `app_strings.dart` ever imports Flutter, duplicate the four validation string literals in the usecase instead (keep messages identical to `AppStrings`).

- [ ] **Step 4: Run tests**

```bash
flutter test test/domain/usecases/submit_issue_report_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/domain/repositories/issue_report_repository.dart \
  lib/domain/usecases/submit_issue_report.dart \
  test/domain/usecases/submit_issue_report_test.dart
git commit -m "feat: add SubmitIssueReport usecase"
```

---

### Task 3: Firestore `IssueReportRepositoryImpl` + DI + rules

**Files:**
- Create: `lib/data/repositories/issue_report_repository_impl.dart`
- Modify: `lib/core/di/app_repositories.dart`
- Modify: `firestore/firestore.rules`
- Modify: `FIREBASE.md`
- Create: `test/data/repositories/issue_report_repository_impl_test.dart` (optional light test: unavailable when Firebase not ready throws `Failure`)

**Interfaces:**
- Consumes: `IssueReportRepository`, `AppUser`, `FirebaseBootstrap`, `PackageInfo`
- Produces: Firestore docs in `issue_reports` with keys exactly:

```
title, description, uid, displayName, photoUrl, avatarId,
appVersion, buildNumber, platform, createdAt
```

- `createdAt`: `FieldValue.serverTimestamp()`
- `platform`: `defaultTargetPlatform.name` (Flutter foundation) — OK in data layer
- `appVersion` / `buildNumber`: from `PackageInfo.fromPlatform()`
- When Firebase not ready: throw `Failure` with a clear message (reuse profile-style “Firebase is unavailable…” or `AppStrings.profileReportFailed`)

**Firestore rules** (append):

```
match /issue_reports/{reportId} {
  allow create: if isSignedIn()
    && request.auth.uid == request.resource.data.uid
    && request.resource.data.keys().hasOnly([
      'title', 'description', 'uid', 'displayName', 'photoUrl',
      'avatarId', 'appVersion', 'buildNumber', 'platform', 'createdAt'
    ])
    && request.resource.data.title is string
    && request.resource.data.title.size() > 0
    && request.resource.data.title.size() <= 80
    && request.resource.data.description is string
    && request.resource.data.description.size() > 0
    && request.resource.data.description.size() <= 2000
    && request.resource.data.uid is string
    && request.resource.data.displayName is string
    && (request.resource.data.photoUrl == null
        || request.resource.data.photoUrl is string)
    && (request.resource.data.avatarId == null
        || request.resource.data.avatarId is string)
    && request.resource.data.appVersion is string
    && request.resource.data.buildNumber is string
    && request.resource.data.platform is string
    && request.resource.data.createdAt == request.time;
  allow read, update, delete: if false;
}
```

Note: `createdAt == request.time` is the standard pattern when the client writes `serverTimestamp()` on create. If deploy rejects this equality, switch to `request.resource.data.createdAt is timestamp` only.

- [ ] **Step 1: Implement repository**

Follow `ProfileRepositoryImpl` patterns (`FirebaseBootstrap.isReady`, injectable `FirebaseFirestore?` for tests).

```dart
class IssueReportRepositoryImpl implements IssueReportRepository {
  IssueReportRepositoryImpl({FirebaseFirestore? firestore});

  @override
  Future<void> submit({
    required String title,
    required String description,
    required AppUser user,
  }) async {
    // require db; PackageInfo.fromPlatform(); write collection('issue_reports').add({...})
  }
}
```

Map `photoUrl` / `avatarId` as nullable fields (write `null` when absent so keys are present for rules `hasOnly`).

- [ ] **Step 2: Register DI**

In `buildRepositoryProviders`:

```dart
RepositoryProvider<IssueReportRepository>(
  create: (_) => IssueReportRepositoryImpl(),
),
RepositoryProvider<SubmitIssueReport>(
  create: (context) =>
      SubmitIssueReport(context.read<IssueReportRepository>()),
),
```

- [ ] **Step 3: Update FIREBASE.md**

Add a short subsection under Firestore collections describing `issue_reports` (create-only, fields list, no client read).

- [ ] **Step 4: Format, analyze**

```bash
dart format lib/data/repositories/issue_report_repository_impl.dart \
  lib/core/di/app_repositories.dart
dart analyze lib/data/repositories/issue_report_repository_impl.dart \
  lib/core/di/app_repositories.dart
```

Expected: clean.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/data/repositories/issue_report_repository_impl.dart \
  lib/core/di/app_repositories.dart firestore/firestore.rules FIREBASE.md
git commit -m "feat: persist issue reports to Firestore"
```

Remind in PR notes: deploy rules with `firebase deploy --only firestore:rules` before relying on production writes.

---

### Task 4: `ReportIssueCubit`

**Files:**
- Create: `lib/features/profile/cubit/report_issue_state.dart`
- Create: `lib/features/profile/cubit/report_issue_cubit.dart`
- Create: `test/features/profile/cubit/report_issue_cubit_test.dart`
- Run build_runner for freezed

**Interfaces:**
- Consumes: `SubmitIssueReport`, `AnalyticsRepository`, `AppUser`
- Produces:

```dart
enum ReportIssueStatus { idle, submitting, success, failure }

@freezed
sealed class ReportIssueState with _$ReportIssueState {
  const factory ReportIssueState({
    @Default(ReportIssueStatus.idle) ReportIssueStatus status,
    @Default('') String titleDraft,
    @Default('') String descriptionDraft,
    String? error,
  }) = _ReportIssueState;
}

class ReportIssueCubit extends Cubit<ReportIssueState> {
  ReportIssueCubit({
    required SubmitIssueReport submitIssueReport,
    required AnalyticsRepository analytics,
    required AppUser user,
  });

  void setTitle(String value);
  void setDescription(String value);
  Future<void> submit();
}
```

- `submit()`: call usecase; on validation `Failure` emit failure with message (stay failure, not submitting if sync throw before await — mirror `ProfileCubit.saveName`); on success emit success + `analytics.logProfileReportSubmitted()`; on other errors use `AppStrings.profileReportFailed`

- [ ] **Step 1: Write failing cubit tests**

```dart
blocTest<ReportIssueCubit, ReportIssueState>(
  'submit success',
  build: () => ReportIssueCubit(
    submitIssueReport: SubmitIssueReport(repo),
    analytics: analytics,
    user: user,
  ),
  seed: () => const ReportIssueState(
    titleDraft: 'Bug',
    descriptionDraft: 'Broken button',
  ),
  setUp: () {
    when(() => repo.submit(
      title: any(named: 'title'),
      description: any(named: 'description'),
      user: any(named: 'user'),
    )).thenAnswer((_) async {});
  },
  act: (c) => c.submit(),
  expect: () => [
    const ReportIssueState(
      status: ReportIssueStatus.submitting,
      titleDraft: 'Bug',
      descriptionDraft: 'Broken button',
    ),
    const ReportIssueState(
      status: ReportIssueStatus.success,
      titleDraft: 'Bug',
      descriptionDraft: 'Broken button',
    ),
  ],
  verify: (_) {
    verify(() => analytics.logProfileReportSubmitted()).called(1);
  },
);

blocTest<ReportIssueCubit, ReportIssueState>(
  'empty title fails without repo',
  // seed empty title; expect failure with AppStrings.profileReportTitleEmpty
  // verifyNever repo; verifyNever analytics submit
);
```

Stub analytics via `stubAnalytics`.

- [ ] **Step 2: Implement state + cubit + freezed**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Only for the new freezed file (or project-wide if that’s the repo norm).

- [ ] **Step 3: Run cubit tests**

```bash
flutter test test/features/profile/cubit/report_issue_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add lib/features/profile/cubit/report_issue_state.dart \
  lib/features/profile/cubit/report_issue_state.freezed.dart \
  lib/features/profile/cubit/report_issue_cubit.dart \
  test/features/profile/cubit/report_issue_cubit_test.dart
git commit -m "feat: add ReportIssueCubit"
```

---

### Task 5: Profile hero UI + name edit sheet + settings list

**Files:**
- Create: `lib/features/profile/view/widgets/name_edit_sheet.dart`
- Create: `lib/features/profile/view/widgets/profile_settings_list.dart`
- Modify: `lib/features/profile/view/profile_screen.dart`
- Modify: `lib/features/profile/view/widgets/profile_signed_out_mock.dart`
- Create: `test/features/profile/view/profile_screen_test.dart`

**Interfaces:**
- Produces:

```dart
class NameEditSheet extends StatelessWidget {
  const NameEditSheet({super.key});
  // Expects ProfileCubit in context (BlocProvider.value from parent)
}

class ProfileSettingsList extends StatelessWidget {
  const ProfileSettingsList({
    super.key,
    required this.onPrivacy,
    required this.onAbout,
    required this.onReport,
    required this.onSignOut,
  });
}
```

- Profile signed-in body layout:
  1. Tappable `UserAvatar` (existing sheet)
  2. Display name text + “Edit display name” affordance → `showModalBottomSheet` with `NameEditSheet`
  3. `ProfileSettingsList` rows: Privacy, About, Report, divider, Log out
- Remove inline `TextField` / Save / OutlinedButton from main body
- Name sheet: `TextField` bound to cubit draft + Save `FilledButton`; pop on successful save (listen for idle after saving with no name error — or pop from Save after `await saveName()` when status idle)
- Wire callbacks later for privacy/report routes in Task 6–7; for this task, About can call a temporary no-op **or** open About dialog if Task 6 dialog is extracted early — prefer wiring About dialog here if small, else placeholder `onAbout` that tests can supply
- On Log out: `analytics.logProfileSignOut()` then `AuthCubit.signOut()`
- Update `ProfileSignedOutMock` to show inert hero + inert list (disabled tiles), no real actions

**Visual:**
- Grouped list in `ZipColors.wall` rounded container (radius ~20)
- Icons: `Icons.privacy_tip_outlined`, `Icons.info_outline`, `Icons.flag_outlined`, `Icons.logout`
- Log out row uses quieter / error-tint foreground (`ColorScheme.error` or soft red), no chevron
- Other rows show trailing chevron / `Icons.chevron_right`

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('signed-in profile shows hero and settings rows', (tester) async {
  // Pump ProfileScreen with mocked AuthCubit signed-in user,
  // ProfileRepository watch emitting user, analytics stubbed.
  expect(find.text(AppStrings.profilePrivacyPolicy), findsOneWidget);
  expect(find.text(AppStrings.profileAboutGame), findsOneWidget);
  expect(find.text(AppStrings.profileReportIssue), findsOneWidget);
  expect(find.text(AppStrings.signOut), findsOneWidget);
  expect(find.byType(TextField), findsNothing); // no inline name field
});

testWidgets('tapping edit display name opens sheet with field', (tester) async {
  // tap AppStrings.profileEditDisplayName; expect TextField + Save in sheet
});
```

Follow patterns from `test/features/auth/view/sign_in_sheet_test.dart` / dashboard tests for `RepositoryProvider` + `BlocProvider` setup.

- [ ] **Step 2: Implement widgets + rewrite `_SignedInBody`**

Keep existing avatar sheet + `ProfileCubit` provider wiring.

- [ ] **Step 3: Update signed-out mock**

Decorative only; keep under `IgnorePointer` via `BlurredMockEmptyBody`.

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/profile/view/profile_screen_test.dart \
  test/features/profile/cubit/profile_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/features/profile/view/ \
  test/features/profile/view/profile_screen_test.dart
git commit -m "feat: redesign profile hero and settings list"
```

---

### Task 6: About dialog + Privacy WebView + routes

**Files:**
- Create: `lib/features/profile/view/widgets/about_game_dialog.dart`
- Create: `lib/features/profile/view/privacy_webview_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/profile/view/profile_screen.dart` (wire About + Privacy)
- Modify: `pubspec.yaml` — add `webview_flutter`
- Create: `test/features/profile/view/about_game_dialog_test.dart`
- Optional: `test/features/profile/view/privacy_webview_screen_test.dart` (pump screen with a fake controller if practical; otherwise smoke-test AppBar title only with a test `WebViewController` seam)

**Interfaces:**
- Produces:

```dart
Future<void> showAboutGameDialog(BuildContext context);

class PrivacyWebViewScreen extends StatefulWidget {
  const PrivacyWebViewScreen({super.key, this.initialUrl = AppUrls.privacyPolicy});
}
```

- About: load `PackageInfo.fromPlatform()`, show `AppStrings.profileAboutBody` + `profileAboutVersion(info.version)`, Got it button; call `analytics.logProfileAboutOpened()` when dialog is shown
- Privacy: Scaffold + AppBar (`profilePrivacyPolicy`) + `WebViewWidget`; loading indicator until `onPageFinished`; on failure show message + Retry
- Router: under profile branch:

```dart
GoRoute(
  path: '/profile',
  name: 'profile',
  builder: ...,
  routes: [
    GoRoute(
      path: 'privacy',
      name: 'profile_privacy',
      builder: (context, state) => const PrivacyWebViewScreen(),
    ),
    // report route added in Task 7
  ],
),
```

- Profile Privacy row: `context.push('/profile/privacy')` + `analytics.logProfilePrivacyOpened()`
- Add dependency:

```bash
flutter pub add webview_flutter
```

- [ ] **Step 1: Add package + About dialog test**

```dart
testWidgets('about dialog shows body and version', (tester) async {
  PackageInfo.setMockInitialValues(
    appName: 'Winklo',
    packageName: 'com.example.winklo',
    version: '1.0.0',
    buildNumber: '3',
  );
  await tester.pumpWidget(/* MaterialApp + button that calls showAboutGameDialog */);
  // open dialog
  expect(find.text(AppStrings.profileAboutBody), findsOneWidget);
  expect(find.text(AppStrings.profileAboutVersion('1.0.0')), findsOneWidget);
});
```

- [ ] **Step 2: Implement About + Privacy + route**

Wire profile list `onAbout` / `onPrivacy`.

- [ ] **Step 3: Format, analyze, test**

```bash
dart format lib/features/profile/view/widgets/about_game_dialog.dart \
  lib/features/profile/view/privacy_webview_screen.dart \
  lib/core/router/app_router.dart lib/features/profile/view/profile_screen.dart
dart analyze lib/features/profile/view/widgets/about_game_dialog.dart \
  lib/features/profile/view/privacy_webview_screen.dart \
  lib/core/router/app_router.dart
flutter test test/features/profile/view/about_game_dialog_test.dart \
  test/features/profile/view/profile_screen_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/profile/view/widgets/about_game_dialog.dart \
  lib/features/profile/view/privacy_webview_screen.dart \
  lib/core/router/app_router.dart \
  lib/features/profile/view/profile_screen.dart \
  test/features/profile/view/about_game_dialog_test.dart
git commit -m "feat: add about dialog and privacy webview"
```

---

### Task 7: Report issue screen + route + end-to-end wiring

**Files:**
- Create: `lib/features/profile/view/report_issue_screen.dart`
- Modify: `lib/core/router/app_router.dart` — add `report` child
- Modify: `lib/features/profile/view/profile_screen.dart` — navigate + analytics
- Create: `test/features/profile/view/report_issue_screen_test.dart`
- Update profile widget test to verify Report navigates / opens (if using GoRouter in test)

**Interfaces:**
- Produces:

```dart
class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key});
  // Provides ReportIssueCubit using context.read<SubmitIssueReport>(),
  // AnalyticsRepository, and AuthCubit/user (or ProfileCubit profile)
}
```

- On open (init / first frame): `analytics.logProfileReportOpened()`
- Form: title + description fields, Send button disabled when `submitting`
- `BlocListener` on `success` → snackbar `profileReportSent` → `context.pop()`
- On `failure` → snackbar or inline `error`
- Profile row: `context.push('/profile/report')`

Router child:

```dart
GoRoute(
  path: 'report',
  name: 'profile_report',
  builder: (context, state) => const ReportIssueScreen(),
),
```

- [ ] **Step 1: Write failing report screen test**

```dart
testWidgets('can edit fields and tap send', (tester) async {
  // Mock SubmitIssueReport / IssueReportRepository success
  // Pump ReportIssueScreen with providers
  await tester.enterText(find.byType(TextField).first, 'Crash');
  await tester.enterText(find.byType(TextField).last, 'App closes on save');
  await tester.tap(find.text(AppStrings.profileReportSend));
  await tester.pumpAndSettle();
  verify(() => repo.submit(
    title: 'Crash',
    description: 'App closes on save',
    user: any(named: 'user'),
  )).called(1);
});
```

- [ ] **Step 2: Implement screen + wire navigation**

User for cubit: `context.read<AuthCubit>().state.user` — if null, pop immediately (shouldn’t happen from signed-in profile). Prefer profile display fields from `ProfileCubit.state.profile ?? auth user` so avatarId/photoUrl are current.

- [ ] **Step 3: Run full profile-related tests**

```bash
flutter test test/features/profile/ \
  test/domain/usecases/submit_issue_report_test.dart \
  test/data/repositories/firebase_analytics_repository_impl_test.dart
dart analyze lib/features/profile/ lib/domain/usecases/submit_issue_report.dart \
  lib/data/repositories/issue_report_repository_impl.dart \
  lib/core/router/app_router.dart
```

Expected: all PASS; analyze clean.

- [ ] **Step 4: Manual QA checklist** (developer)

1. Signed-in: avatar, name sheet save, list rows look correct
2. Privacy opens WebView at Pages URL
3. About shows blurb + version
4. Report writes Firestore doc with user + app fields (Firebase console)
5. DebugView: five profile analytics events
6. Signed-out: blur tease only, no settings list
7. Deploy `firestore.rules` before production submit

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/features/profile/view/report_issue_screen.dart \
  lib/core/router/app_router.dart \
  lib/features/profile/view/profile_screen.dart \
  test/features/profile/view/report_issue_screen_test.dart
git commit -m "feat: add report an issue screen"
```

---

## Spec coverage self-check

| Spec item | Task |
|-----------|------|
| Identity hero + settings list | 5 |
| Name edit bottom sheet | 5 |
| Avatar sheet unchanged | 5 |
| Signed-out unchanged (+ mock visual) | 5 |
| Privacy WebView + URL | 1, 6 |
| About dialog + version | 6 |
| Report screen title/description | 7 |
| Firestore + user/app metadata | 2, 3 |
| Firestore create-only rules | 3 |
| Analytics events | 1, 4, 5, 6, 7 |
| Tests (usecase, cubit, widgets) | 2, 4, 5, 6, 7 |
| AppStrings | 1 |
| Log out | 5 |

## Placeholder / consistency notes

- Max lengths fixed at 80 / 2000 in usecase, rules, and copy.
- Analytics method names and event string names aligned across Tasks 1, 4, 5, 6, 7.
- Domain may import `AppStrings` only if that file stays Flutter-free (current state); otherwise inline matching literals.
