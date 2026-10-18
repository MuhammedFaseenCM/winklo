# Play Store review & rating in-app — design

Date: 2026-10-18
Status: approved (user: "go ahead", 2026-10-18)
Repos: winklo (Flutter app)
Roadmap: quick win 7 in README (“Ask for a review at a good moment”)

## Goal

Players can rate Winklo from inside the app: a Profile row they can tap any time, and an automatic ask after a personal best or a 7-day streak, using Play’s in-app review when possible and the Play Store listing as fallback.

## What exists today

- Play Store URL lives in Remote Config (`RemoteConfigClient.playStoreUrl`), default `https://play.google.com/store/apps/details?id=com.winklo.faseencm`. App update already opens it via `AppUpdateRepository.openStore`.
- Profile list: Settings, Privacy, About, Report issue, Sign out, Delete account — no rate/review row.
- `IsNewPersonalBest` already decides whether a daily clear beats every earlier daily of that game.
- Daily Results already receive `currentStreak` and know whether the run is a daily (`local == null`).
- No `in_app_review` dependency yet. `url_launcher` is already used.

## Decisions

| Topic | Choice |
|-------|--------|
| Placement | Profile row **and** automatic prompt after a milestone |
| Action | Try Play in-app review first; if unavailable or fails, open the Play Store listing |
| Soft “Enjoying Winklo?” dialog | Not in v1 |
| Auto trigger | Personal best **or** streak ≥ 7, on daily Results only |
| Auto frequency | At most once every 30 days; stop auto-asking after 3 attempts |
| Profile tap | Always allowed; no cooldown |
| PB definition | Daily Results already set `ResultsArgs.improved` from `IsNewPersonalBest` — reuse that; no new field |
| Store URL | Same Remote Config URL as updates; hard-coded default if empty |

## Architecture

### `AppReviewRepository` (domain)

```dart
abstract class AppReviewRepository {
  /// Profile / explicit ask: in-app review, else store listing.
  /// Returns how it ended for analytics / snackbars.
  Future<ReviewOutcome> requestReviewOrOpenStore();

  /// Whether an auto prompt is allowed right now for this milestone.
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  });

  /// Call after an auto prompt is attempted (dialog, store, or failed).
  Future<void> recordAutoPromptAttempt();
}

enum ReviewOutcome { inApp, store, failed }
```

- `shouldPromptAfterMilestone`: true only if `(isPersonalBest || (streak ?? 0) >= 7)` **and** auto-ask is not disabled **and** last auto attempt was ≥ 30 days ago (or never).
- Prefs (SharedPreferences): `review_auto_last_ms`, `review_auto_attempts` (int). When attempts reach 3, further auto prompts are refused forever; Profile still works.
- Implementation uses `in_app_review`: if `isAvailable`, call `requestReview` and treat that as `ReviewOutcome.inApp` (Play does not report whether a dialog actually appeared). If not available or `requestReview` throws, open the store URL with `LaunchMode.externalApplication` (same pattern as `AppUpdateRepositoryImpl.openStore`) → `store` or `failed`.
- Known platform limit: Play may silently no-op even when `requestReview` “succeeds” (quota / already reviewed). We do **not** open the store afterward in that case (would stack two UIs). Profile still helps most users; auto-prompt accepts the same limit.
- Do not pile review launch logic into `AppUpdateRepository`; keep update and review separate even though both may open the same URL.

### DI

Register `AppReviewRepositoryImpl` in `core/di` via `RepositoryProvider`, next to the other app repositories.

## UI & triggers

### Profile

- New `_SettingsRow` on `ProfileSettingsList` (signed-in and signed-out mock), **after About, before Report issue**.
- Label: `AppStrings.profileRateOnPlayStore` (EN + ML). Icon: star outline.
- Tap → `requestReviewOrOpenStore()`. On `failed`, show a SnackBar (`AppStrings.reviewOpenStoreFailed`).

### Automatic prompt on Results

- Only when `args.local == null` (daily clear).
- Use `args.improved` as the personal-best flag (already set from `IsNewPersonalBest` on daily clears). Do not add a second field.
- After Results has settled (**1.0 s** after first frame, after celebration chips), if `shouldPromptAfterMilestone(isPersonalBest: args.improved, streak: args.currentStreak)` → `requestReviewOrOpenStore()` then `recordAutoPromptAttempt()`.
- No custom dialog; no SnackBar on auto `failed` (still record the attempt so a broken store link does not retry every clear).

## Analytics

Extend `AnalyticsRepository` with:

```dart
Future<void> logReviewPrompt({
  required String source, // profile | personal_best | streak
  required String outcome, // in_app | store | failed
});
```

- Profile: `source = profile`.
- Auto: `personal_best` if PB (even if streak also ≥ 7); else `streak`.

## Errors

| Case | Behaviour |
|------|-----------|
| In-app review unavailable / silent no-op / throws | Open store URL |
| Store URL empty | Use Remote Config default package URL |
| Store launch fails | Profile: SnackBar. Auto: quiet + still count attempt |
| Desktop / tests | Repository fake; widgets never call the real plugin |

## Testing

- Unit: milestone gating, 30-day cooldown, attempt cap at 3, Profile path ignores prefs.
- Unit/bloc or widget with mock repo: Profile row invokes repository; Results auto-prompt only for daily + milestone + allowed.
- No integration test against the real Play dialog (Play does not guarantee it appears).

## Out of scope

- iOS App Store review (Android / Play-first for now; `in_app_review` can open the right store later if needed).
- Custom pre-prompt dialog.
- Asking after “Perfect day” alone (unless it also hits PB or streak ≥ 7).
- Changing Play Console listing copy.

## Files likely touched

- `pubspec.yaml` — `in_app_review`
- `lib/domain/repositories/app_review_repository.dart`
- `lib/domain/repositories/analytics_repository.dart` + Firebase impl — `logReviewPrompt`
- `lib/data/repositories/app_review_repository_impl.dart`
- `lib/core/di/…` registration
- `lib/features/profile/view/widgets/profile_settings_list.dart` + profile screen wiring
- `lib/features/results/results_screen.dart` — auto-prompt trigger (reuse `args.improved`)
- `lib/core/strings/app_text*.dart`, `app_strings.dart`
- Tests under `test/domain/`, `test/features/profile/`, `test/features/results/`
