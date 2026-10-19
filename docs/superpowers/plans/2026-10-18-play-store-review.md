# Play Store Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Profile “Rate on Play Store” row and an automatic in-app review ask after a personal best or 7-day streak on daily Results.

**Architecture:** New `AppReviewRepository` (domain + data) wraps `in_app_review` with Play Store URL fallback and SharedPreferences cooldown. Profile and Results both call it; daily Results reuse `args.improved` (already set from `IsNewPersonalBest`) and `args.currentStreak`.

**Tech Stack:** Flutter, `in_app_review`, `url_launcher`, SharedPreferences, Firebase Analytics, mocktail, bloc/widget tests.

Spec: `docs/superpowers/specs/2026-10-18-play-store-review-design.md`.

## Global Constraints

- All user-facing copy via `AppStrings` / `AppText` (EN + ML).
- Domain must not import Flutter UI.
- Profile tap: no cooldown. Auto: 30 days between attempts; stop after 3 auto attempts.
- Auto only on daily Results (`args.local == null`).
- PB = `args.improved` (already `IsNewPersonalBest` for dailies). Streak gate: `(currentStreak ?? 0) >= 7`.
- Do not open the store after a silent in-app “success” (Play quota).
- Format only files you touch (`dart format`). Do not hand-edit `pubspec.lock` layout; leave lock changes from `flutter pub get`.
- Commit after each task when the user asked for commits; otherwise leave working tree ready to commit.

## File map

| File | Role |
|------|------|
| `lib/domain/repositories/app_review_repository.dart` | Interface + `ReviewOutcome` |
| `lib/data/repositories/app_review_repository_impl.dart` | Prefs + in-app review + store launch |
| `lib/domain/repositories/analytics_repository.dart` | `logReviewPrompt` |
| `lib/data/repositories/firebase_analytics_repository_impl.dart` | Event `review_prompt` |
| `lib/core/di/app_repositories.dart` | Register review repo |
| `lib/features/profile/...` | Rate row + handler |
| `lib/features/results/results_screen.dart` | Auto prompt after 1 s |
| `lib/core/strings/app_text*.dart`, `app_strings.dart` | Copy |
| Tests under `test/data/`, `test/features/profile/`, `test/features/results/` | |

---

### Task 1: Strings

**Files:**
- Modify: `lib/core/strings/app_text.dart` (after `profileAboutGame`)
- Modify: `lib/core/strings/app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart`
- Modify: `test/core/strings/app_text_test.dart` `_members`

| Key | English | Malayalam |
|-----|---------|-----------|
| `profileRateOnPlayStore` | `Rate on Play Store` | `Play Store-ൽ റേറ്റ് ചെയ്യൂ` |
| `reviewOpenStoreFailed` | `Couldn't open the Play Store` | `Play Store തുറക്കാനായില്ല` |

- [ ] **Step 1:** Add getters to `AppText`, EN, ML, and `AppStrings` facades; add both keys to `_members`.
- [ ] **Step 2:** Run `flutter test test/core/strings/app_text_test.dart` — expect PASS.
- [ ] **Step 3:** Commit if requested: `feat: add Play Store review strings`

---

### Task 2: Domain interface + analytics stub

**Files:**
- Create: `lib/domain/repositories/app_review_repository.dart`
- Modify: `lib/domain/repositories/analytics_repository.dart`
- Modify: `lib/data/repositories/firebase_analytics_repository_impl.dart`
- Modify: `test/helpers/mock_analytics_repository.dart`

- [ ] **Step 1:** Create the domain file:

```dart
/// How a review request ended (for analytics and Profile snackbars).
enum ReviewOutcome { inApp, store, failed }

abstract class AppReviewRepository {
  /// Explicit ask (Profile): try in-app review, else open the store listing.
  Future<ReviewOutcome> requestReviewOrOpenStore();

  /// Auto prompt gate: PB or streak ≥ 7, and cooldown / attempt cap allow it.
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  });

  /// Call after every auto attempt (in-app, store, or failed).
  Future<void> recordAutoPromptAttempt();
}
```

- [ ] **Step 2:** Add to `AnalyticsRepository`:

```dart
  /// [source] is `profile`, `personal_best`, or `streak`.
  /// [outcome] is `in_app`, `store`, or `failed`.
  Future<void> logReviewPrompt({
    required String source,
    required String outcome,
  });
```

Implement in Firebase:

```dart
  @override
  Future<void> logReviewPrompt({
    required String source,
    required String outcome,
  }) {
    return _safe(
      (a) => a.logEvent(
        name: 'review_prompt',
        parameters: {'source': source, 'outcome': outcome},
      ),
    );
  }
```

Stub in `stubAnalytics`:

```dart
  when(
    () => analytics.logReviewPrompt(
      source: any(named: 'source'),
      outcome: any(named: 'outcome'),
    ),
  ).thenAnswer((_) async {});
```

- [ ] **Step 3:** Run `flutter test test/helpers/` and any analytics-using smoke tests that compile — expect PASS (mocks compile).
- [ ] **Step 4:** Commit if requested: `feat: add AppReviewRepository and review_prompt analytics`

---

### Task 3: Repository implementation + unit tests (TDD)

**Files:**
- Create: `lib/data/repositories/app_review_repository_impl.dart`
- Create: `test/data/repositories/app_review_repository_impl_test.dart`
- Modify: `pubspec.yaml` — add `in_app_review: ^2.0.10` (or latest compatible; run `flutter pub get`)
- Modify: `lib/core/di/app_repositories.dart` — register after `ShareRepository`

**Interfaces:**
- Consumes: `SharedPreferences`, injectable review + launch hooks, `DateTime Function() clock`, store URL string
- Produces: `AppReviewRepositoryImpl` satisfying Task 2 interface

Prefs keys:
- `review_auto_last_ms` (int, epoch ms)
- `review_auto_attempts` (int)

Constants: `_cooldown = Duration(days: 30)`, `_maxAttempts = 3`, streak threshold `7`.

- [ ] **Step 1:** Write failing tests first (`test/data/repositories/app_review_repository_impl_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/app_review_repository_impl.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late bool available;
  late bool reviewThrows;
  late bool launchOk;
  late int reviewCalls;
  late int launchCalls;
  late AppReviewRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 10, 18);
    available = true;
    reviewThrows = false;
    launchOk = true;
    reviewCalls = 0;
    launchCalls = 0;
    repo = AppReviewRepositoryImpl(
      prefs: prefs,
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
      clock: () => now,
      isReviewAvailable: () async => available,
      requestReview: () async {
        reviewCalls++;
        if (reviewThrows) throw StateError('no');
      },
      openStoreUrl: (url) async {
        launchCalls++;
        return launchOk;
      },
    );
  });

  group('shouldPromptAfterMilestone', () {
    test('false when neither PB nor streak >= 7', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: false, streak: 6),
        isFalse,
      );
    });

    test('true for PB when never asked', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 0),
        isTrue,
      );
    });

    test('true for streak 7', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: false, streak: 7),
        isTrue,
      );
    });

    test('false within 30 days after an attempt', () async {
      await repo.recordAutoPromptAttempt();
      now = now.add(const Duration(days: 29));
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 7),
        isFalse,
      );
    });

    test('true again after 30 days', () async {
      await repo.recordAutoPromptAttempt();
      now = now.add(const Duration(days: 30));
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: null),
        isTrue,
      );
    });

    test('false forever after 3 attempts', () async {
      for (var i = 0; i < 3; i++) {
        await repo.recordAutoPromptAttempt();
        now = now.add(const Duration(days: 31));
      }
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 99),
        isFalse,
      );
    });
  });

  group('requestReviewOrOpenStore', () {
    test('inApp when available', () async {
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.inApp);
      expect(reviewCalls, 1);
      expect(launchCalls, 0);
    });

    test('store when unavailable', () async {
      available = false;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.store);
      expect(launchCalls, 1);
    });

    test('store when requestReview throws', () async {
      reviewThrows = true;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.store);
    });

    test('failed when store launch fails', () async {
      available = false;
      launchOk = false;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.failed);
    });

    test('empty store URL uses default package URL', () async {
      available = false;
      final emptyUrlRepo = AppReviewRepositoryImpl(
        prefs: prefs,
        playStoreUrl: '  ',
        clock: () => now,
        isReviewAvailable: () async => false,
        requestReview: () async {},
        openStoreUrl: (url) async {
          expect(
            url,
            'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
          );
          return true;
        },
      );
      expect(await emptyUrlRepo.requestReviewOrOpenStore(), ReviewOutcome.store);
    });
  });
}
```

- [ ] **Step 2:** Run `flutter test test/data/repositories/app_review_repository_impl_test.dart` — expect FAIL (missing impl / package).

- [ ] **Step 3:** Add dependency and implement:

```yaml
  in_app_review: ^2.0.10
```

```dart
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/app_review_repository.dart';
import '../clients/remote_config_client.dart';

class AppReviewRepositoryImpl implements AppReviewRepository {
  AppReviewRepositoryImpl({
    required SharedPreferences prefs,
    required String playStoreUrl,
    DateTime Function()? clock,
    Future<bool> Function()? isReviewAvailable,
    Future<void> Function()? requestReview,
    Future<bool> Function(String url)? openStoreUrl,
  }) : _prefs = prefs,
       _playStoreUrl = playStoreUrl,
       _clock = clock ?? DateTime.now,
       _isReviewAvailable =
           isReviewAvailable ?? () => InAppReview.instance.isAvailable(),
       _requestReview =
           requestReview ?? () => InAppReview.instance.requestReview(),
       _openStoreUrl = openStoreUrl ?? _launchStore;

  static const lastMsKey = 'review_auto_last_ms';
  static const attemptsKey = 'review_auto_attempts';
  static const cooldown = Duration(days: 30);
  static const maxAttempts = 3;
  static const streakThreshold = 7;

  final SharedPreferences _prefs;
  final String _playStoreUrl;
  final DateTime Function() _clock;
  final Future<bool> Function() _isReviewAvailable;
  final Future<void> Function() _requestReview;
  final Future<bool> Function(String url) _openStoreUrl;

  static Future<bool> _launchStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) return false;
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String get _resolvedStoreUrl {
    final trimmed = _playStoreUrl.trim();
    return trimmed.isEmpty
        ? RemoteConfigClient.defaultPlayStoreUrl
        : trimmed;
  }

  @override
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  }) {
    final milestone =
        isPersonalBest || (streak ?? 0) >= streakThreshold;
    if (!milestone) return false;
    final attempts = _prefs.getInt(attemptsKey) ?? 0;
    if (attempts >= maxAttempts) return false;
    final lastMs = _prefs.getInt(lastMsKey);
    if (lastMs == null) return true;
    final elapsed = _clock().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true),
    );
    return elapsed >= cooldown;
  }

  @override
  Future<void> recordAutoPromptAttempt() async {
    final attempts = (_prefs.getInt(attemptsKey) ?? 0) + 1;
    await _prefs.setInt(attemptsKey, attempts);
    await _prefs.setInt(
      lastMsKey,
      _clock().toUtc().millisecondsSinceEpoch,
    );
  }

  @override
  Future<ReviewOutcome> requestReviewOrOpenStore() async {
    try {
      if (await _isReviewAvailable()) {
        await _requestReview();
        return ReviewOutcome.inApp;
      }
    } catch (_) {
      // Fall through to store.
    }
    final opened = await _openStoreUrl(_resolvedStoreUrl);
    return opened ? ReviewOutcome.store : ReviewOutcome.failed;
  }
}
```

DI (in `buildRepositoryProviders`, after `ShareRepository`):

```dart
    RepositoryProvider<AppReviewRepository>(
      create: (context) => AppReviewRepositoryImpl(
        prefs: context.read<SharedPreferences>(),
        playStoreUrl: RemoteConfigClient.instance.playStoreUrl,
      ),
    ),
```

Import the domain + data + remote config types at the top of `app_repositories.dart`.

- [ ] **Step 4:** Run `flutter test test/data/repositories/app_review_repository_impl_test.dart` — expect PASS.
- [ ] **Step 5:** Commit if requested: `feat: implement AppReviewRepository with cooldown`

---

### Task 4: Profile row

**Files:**
- Modify: `lib/features/profile/view/widgets/profile_settings_list.dart`
- Modify: `lib/features/profile/view/profile_screen.dart`
- Modify: `lib/features/profile/view/widgets/profile_signed_out_mock.dart` (pass `onRate` noop or optional)
- Create or modify: `test/features/profile/view/profile_settings_list_test.dart` (create if missing; else extend)

**Interfaces:**
- Consumes: `AppReviewRepository`, `AnalyticsRepository`, new `onRate` callback
- Produces: Profile row after About, before Report

- [ ] **Step 1:** Extend `ProfileSettingsList`:

```dart
  const ProfileSettingsList({
    // ...existing...
    required this.onRate,
  });

  final VoidCallback onRate;
```

Insert after the About row (before Report):

```dart
            _SettingsRow(
              icon: Icons.star_outline_rounded,
              label: AppStrings.profileRateOnPlayStore,
              iconColor: const Color(0xFFFBBF24),
              onTap: enabled ? onRate : null,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
```

Wire signed-out mock: `onRate: _noop`.

- [ ] **Step 2:** In `profile_screen.dart`:

```dart
  Future<void> _rateOnPlayStore(BuildContext context) async {
    final review = context.read<AppReviewRepository>();
    final analytics = context.read<AnalyticsRepository>();
    final outcome = await review.requestReviewOrOpenStore();
    await analytics.logReviewPrompt(
      source: 'profile',
      outcome: switch (outcome) {
        ReviewOutcome.inApp => 'in_app',
        ReviewOutcome.store => 'store',
        ReviewOutcome.failed => 'failed',
      },
    );
    if (!context.mounted) return;
    if (outcome == ReviewOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.reviewOpenStoreFailed)),
      );
    }
  }
```

Pass `onRate: () => unawaited(_rateOnPlayStore(context))` into `ProfileSettingsList`.

- [ ] **Step 3:** Widget test: pump `ProfileSettingsList` with callbacks; tap the rate label; expect `onRate` called once. Optionally pump Profile with a mock repo and assert `requestReviewOrOpenStore` + analytics.

- [ ] **Step 4:** Run relevant profile tests — expect PASS.
- [ ] **Step 5:** Commit if requested: `feat: add Rate on Play Store to Profile`

---

### Task 5: Results auto prompt

**Files:**
- Modify: `lib/features/results/results_screen.dart`
- Modify: `test/features/results/results_screen_test.dart` (and/or new `review_prompt_test.dart`)

**Interfaces:**
- Consumes: `AppReviewRepository.shouldPromptAfterMilestone` / `requestReviewOrOpenStore` / `recordAutoPromptAttempt`; `args.improved`, `args.currentStreak`; `AnalyticsRepository.logReviewPrompt`
- Produces: one-shot delayed prompt on `_CelebrateAndClaimResults` only

- [ ] **Step 1:** Convert `_CelebrateAndClaimResults` to a `StatefulWidget` (or wrap its `build` scaffold with a tiny `StatefulWidget` child `_ReviewPromptHost`) that in `initState`:

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAsk());
    });
```

```dart
  Future<void> _maybeAsk() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    // Only dailies reach this widget; local runs use LocalResultsView.
    final review = context.read<AppReviewRepository>();
    final args = widget.args;
    if (!review.shouldPromptAfterMilestone(
      isPersonalBest: args.improved,
      streak: args.currentStreak,
    )) {
      return;
    }
    final outcome = await review.requestReviewOrOpenStore();
    await review.recordAutoPromptAttempt();
    final source = args.improved ? 'personal_best' : 'streak';
    await context.read<AnalyticsRepository>().logReviewPrompt(
      source: source,
      outcome: switch (outcome) {
        ReviewOutcome.inApp => 'in_app',
        ReviewOutcome.store => 'store',
        ReviewOutcome.failed => 'failed',
      },
    );
  }
```

Import `dart:async` for `unawaited` if not already present.

Do **not** show a SnackBar on auto `failed`.

- [ ] **Step 2:** Tests with fake `AppReviewRepository` (mocktail) and `pump` + `pump(Duration(seconds: 1))`:
  - daily + improved true + shouldPrompt true → `requestReviewOrOpenStore` + `recordAutoPromptAttempt` once
  - streak 7, not improved → source `streak` (verify analytics)
  - `shouldPrompt` false → no request
  - `LocalResultsView` path → never calls review
  - dispose before 1 s → no call (optional)

Provide `AppReviewRepository` in the test’s `MultiRepositoryProvider` (existing results tests already wrap analytics).

- [ ] **Step 3:** Run `flutter test test/features/results/` — expect PASS.
- [ ] **Step 4:** Commit if requested: `feat: ask for Play review after PB or 7-day streak`

---

### Task 6: Verify

- [ ] **Step 1:** `dart format` on touched files.
- [ ] **Step 2:** `flutter analyze` on touched paths only (do not hang on whole-project forever):

```bash
flutter analyze lib/domain/repositories/app_review_repository.dart \
  lib/data/repositories/app_review_repository_impl.dart \
  lib/features/profile/view/widgets/profile_settings_list.dart \
  lib/features/profile/view/profile_screen.dart \
  lib/features/results/results_screen.dart \
  lib/core/strings/app_text.dart lib/core/strings/app_text_en.dart \
  lib/core/strings/app_text_ml.dart lib/core/strings/app_strings.dart
```

Expect no new errors.

- [ ] **Step 3:** `flutter test test/data/repositories/app_review_repository_impl_test.dart test/core/strings/app_text_test.dart test/features/results/ test/features/profile/` — expect PASS.
- [ ] **Step 4:** Optionally tick README quick win 7 as done when this ships.
- [ ] **Step 5:** Mark spec status remains approved; note plan executed in PR description when opening one.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Profile row | 4 |
| In-app then store fallback | 3 |
| Auto PB or streak ≥ 7 | 5 |
| 30-day cooldown, 3-attempt cap | 3 |
| Profile no cooldown | 3 + 4 |
| Use `IsNewPersonalBest` via `args.improved` | 5 |
| Analytics `review_prompt` | 2, 4, 5 |
| SnackBar only on Profile failed | 4 |
| Quiet auto failure + still record | 5 |
| Strings EN+ML | 1 |
| Unit tests for gating | 3 |
| Widget/results tests | 4, 5 |
| No custom Enjoying dialog | — (omitted) |
| DI registration | 3 |
