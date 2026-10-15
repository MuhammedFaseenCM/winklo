# Area G: Malayalam — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build section G of `docs/superpowers/specs/2026-10-15-roadmap-batch-design.md`: the whole app UI in Malayalam as well as English, chosen in Settings (System, English, മലയാളം). Path Words boards stay English, and the game names Zip, Path Words and Sudoku stay English.

**Architecture:** `AppStrings` stays the one pure-Dart API for copy, because `domain/` (`submit_issue_report.dart`) and `data/` (notifications, the widget, issue reports, avatar uploads) read it without a `BuildContext`. Its members become static getters and methods that delegate to the current table: an `AppText` interface with `AppTextEn` (today's copy, moved verbatim) and `AppTextMl` (implements `AppText` in full, so the compiler forces every string). `AppStrings.use('ml')` switches the table; English is the default, so tests stay English. A `LocaleCubit` at the app root resolves System / English / മലയാളം (stored behind a `LanguageRepository`), switches `AppStrings` and the `MaterialApp` locale together, rebuilds the whole tree, and replans the reminders and the home-screen widget (their copy is baked in when written).

**Tech stack:** Flutter 3.44, `flutter_localizations` (SDK; Material, Cupertino and Widgets delegates, which format dates with intl's `ml` data), flutter_bloc (Cubit), shared_preferences, google_fonts (Noto Sans Malayalam bundled as a fallback), bloc_test + mocktail.

Branch: `feat/rb-malayalam` (worktree `/Users/apple/Developments/personal/winklo-wt/rb-malayalam`). Base: `feat/roadmap-batch` at `4120f32` (about 1,687 tests; `flutter analyze` shows 20 infos).

---

## Design change from the spec (decided before this plan)

The spec says to back `AppStrings` with gen-l10n's `AppLocalizations`. We don't: gen-l10n output imports Flutter (CLAUDE.md forbids that in `domain/`) and is looked up through a `BuildContext`, which the notification, widget and issue-report code doesn't have. The `AppText` tables above replace the ARB files; there is no `lib/l10n/`.

## Ground rules

- TDD for logic: the language repository and resolution, the cubit, `AppStrings.use`, replanning on a change, System following the phone.
- `pubspec.lock`: this machine's Flutter can rewrite SDK-pinned packages. Before each commit, check `git diff pubspec.lock` shows only `flutter_localizations` (and nothing else).
- `dart format` only the files a task touched (never `lib/` or `test/` as a whole).
- Const removals: drop only the `const` that has to go; don't reformat around it.
- Commit after each step below; the last line of every message is `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The generator for the tables lives outside the repo, in the session scratchpad (`l10n/gen_tables.py`). Its output is checked by hand.

## File map

| File | Responsibility |
|---|---|
| `lib/core/strings/app_text.dart` (new) | `abstract interface class AppText`: one getter or method per string, with the docs |
| `lib/core/strings/app_text_en.dart` (new) | `final class AppTextEn implements AppText`: today's English, verbatim |
| `lib/core/strings/app_text_ml.dart` (new) | `final class AppTextMl implements AppText`: Malayalam; deliberate English (game names, "Winklo", symbols) returned explicitly |
| `lib/core/strings/play_time_format.dart` (new) | `formatPlayTime` ("0:48"), shared by both tables |
| `lib/core/strings/app_strings.dart` (generated) | static getters/methods delegating to the current table; `use(code)`, `languageCode`, `supportedLanguageCodes` |
| `lib/core/strings/clean_run_chips.dart` | unchanged: it already reads `AppStrings` at call time |
| `lib/domain/entities/app_language.dart` (new) | `enum AppLanguage { system, english, malayalam }`, storage ids, `resolveLanguageCode(choice, deviceLanguageCodes)` |
| `lib/domain/repositories/language_repository.dart` (new) | interface: `language`, `setLanguage` |
| `lib/data/repositories/language_repository_impl.dart` (new) | shared_preferences key `app_language` |
| `lib/core/di/language_providers.dart` (new) | registers `LanguageRepository`; one spread line in `app_repositories.dart` |
| `lib/features/settings/cubit/locale_cubit.dart`, `locale_state.dart` (new) | choice + resolved code; `AppStrings.use`; replan callback |
| `lib/core/widgets/rebuild_descendants.dart` (new) | marks every element below a context dirty (state kept) |
| `lib/main.dart`, `lib/app.dart` (modify) | `LocaleCubit` above `WinkloApp`; `locale`, `supportedLocales`, delegates; rebuild on change; System follows `didChangeLocales` |
| `lib/features/settings/view/widgets/settings_language_slot.dart` (fill) | System / English / മലയാളം radio rows |
| `lib/core/theme/app_theme.dart` (modify) | Noto Sans Malayalam (google_fonts, bundled Regular and Bold) as `fontFamilyFallback` |
| `assets/google_fonts/NotoSansMalayalam-{Regular,Bold}.ttf`, `OFL.txt` (new) | bundled so Malayalam renders offline and in tests (google_fonts finds them in the asset manifest) |
| `android/app/src/main/res/values-ml/winklo_widget_strings.xml` (new) | widget picker and placeholder copy in Malayalam |
| `test/core/strings/app_text_test.dart` (new) | every member non-empty in both tables, Malayalam differs except an allowlist |
| `test/features/l10n/malayalam_screens_test.dart` (new) | 360×640 Malayalam screenshots, no overflow |

## Translation style

Natural, short, friendly Malayalam, the way a Kerala app talks to players; polite imperative (കളിക്കൂ, ശ്രമിക്കൂ). Gaming loanwords where players use them (സ്ട്രീക്ക്, ലീഡർബോർഡ്, റാങ്ക്, ലീഗ്, ബാഡ്ജ്, ഫ്രീസ്); native words where they read naturally (സൂചന for hint, പസിൽ, ഇന്ന്, സമയം, മികച്ചത്, കണക്കുകൾ for stats, ക്രമീകരണം for settings, പരിശീലനം for practice). Buttons stay short. Interpolations keep Malayalam word order ("ഒക്ടോ 9", "12 ദിവസത്തെ Zip സ്ട്രീക്ക്"). Western digits. Zip, Path Words, Sudoku and Winklo stay English. Player names, Path Words words and themes, and CMS content (Word Match decks, Category Race categories) are data and stay as they come.

---

## Tasks

### 1. Plan — commit `docs: plan for area G (Malayalam)`

- [ ] This file.

### 2. Infra — commit `feat(l10n): flutter_localizations and the language choice store`

**Files:** `pubspec.yaml`; `lib/domain/entities/app_language.dart`, `lib/domain/repositories/language_repository.dart`, `lib/data/repositories/language_repository_impl.dart`, `lib/core/di/language_providers.dart`, `lib/core/di/app_repositories.dart` (one line); tests `test/domain/app_language_test.dart`, `test/data/repositories/language_repository_impl_test.dart`.

- [ ] Add `flutter_localizations: sdk: flutter`. `flutter pub get`; the lock gains only that entry.
- [ ] Tests first (`app_language_test.dart`): English → `en`, Malayalam → `ml` whatever the phone says; System picks the first phone language the app has (`['ml','en']` → `ml`, `['hi','en']` → `en`, `['ta']` → `en`, `[]` → `en`); storage ids round-trip and an unknown id reads as System.
- [ ] `resolveLanguageCode`:

```dart
String resolveLanguageCode(AppLanguage choice, List<String> deviceLanguageCodes) =>
    switch (choice) {
      AppLanguage.english => 'en',
      AppLanguage.malayalam => 'ml',
      AppLanguage.system => deviceLanguageCodes.firstWhere(
        AppLanguage.supportedCodes.contains,
        orElse: () => 'en',
      ),
    };
```

- [ ] Repository tests (`SharedPreferences.setMockInitialValues`): defaults to System; stores and reads each choice; a bad stored value reads as System.
- [ ] Implement, register (`buildLanguageProviders()` spread in `buildRepositoryProviders`), run the tests green.

### 3. String moves — commit `refactor(strings): move inline copy and raw errors into AppStrings`

Still on today's `const` file, so the generator sees every string.

- [ ] Inline UI copy: "Your Rank" (`leaderboard_screen.dart`), "Next puzzle" (`results_screen.dart`), the "Play $game" semantics label (`leaderboard_screen.dart`), the "Results" fallback title (`app_router.dart`), the share text's "Winklo Zip · 9 Oct" headline and its month list (`result_share_text.dart`, now `AppStrings.shareHeadline` using `leaderboardShortDate`), the signed-out profile mock's "Player".
- [ ] The "Player" fallback: display-only fallbacks (leaderboard rows, league members) read `AppStrings.playerFallbackName`. Fallbacks that can be written to Firestore (`leaderboardDisplayName`, `mergeAuthWithProfile`, `_mapUser`, `mapUserProfile`, `resolveLeaderboardIdentity`) stay the stored English value, with a comment: other players read it.
- [ ] Raw error messages shown to players:
  - `UpdateDisplayName` uses `profileNameEmpty` / `profileNameTooLong` (it duplicated them); `UpdateAvatar` uses `profileSaveFailed`.
  - `profile_repository_impl`, `r2_avatar_upload_client`, `issue_report_repository_impl`: "Firebase is unavailable…" → `serviceUnavailable`, "Sign in required." → `signInRequiredShort`, "Could not update profile." → `profileSaveFailed` / `profileUploadFailed`, "Avatar upload is not configured." → `profileUploadFailed`.
  - `league_repository_impl`: the `_guard` messages, "League names are 1 to 30 characters.", "Sign in to use leagues.", "No league has that code.", "That league is full (30 players).", "Firebase is unavailable." → `AppStrings` (English unchanged, so tests still match).
  - The sign-in sheet shows `AppStrings.signInFailed` instead of the raw `state.error` (Google's or Firebase's English); the leaderboard and mini leaderboard show `leaderboardFailed` instead of a raw `state.error`.
  - Not moved: `DailyPuzzleUnavailable`, sync and submit messages (logged, never shown), `debugPrint`/assert text.
- [ ] Run the affected tests.

### 4. English table — commit `refactor(strings): AppStrings delegates to an AppText table`

- [ ] Generator (scratchpad `l10n/gen_tables.py`): parses `app_strings.dart` member by member (doc comments, section comments, `static const x = …;`, `static String x(…) => …;` and block bodies) and writes `app_text.dart` (interface), `app_text_en.dart` (`@override String get x => …;`, methods verbatim, `_shortMonths` kept private) and the new `app_strings.dart`:

```dart
abstract final class AppStrings {
  static const supportedLanguageCodes = ['en', 'ml'];
  static AppText _t = const AppTextEn();
  static String _languageCode = 'en';

  /// Switches every string to [languageCode] ('en' or 'ml'); anything else
  /// is English. English is the default, so tests read English.
  static void use(String languageCode) { … }
  static String get languageCode => _languageCode;

  static String formatPlayTime(int totalSeconds) => play_time.formatPlayTime(totalSeconds);
  static String get appTitle => _t.appTitle;
  static String zipHintWithCount(int n) => _t.zipHintWithCount(n);
  …
}
```

- [ ] `flutter analyze`; fix each const error with the smallest edit: drop the `const` that must go (`const Text(AppStrings.x)` → `Text(AppStrings.x)`, a `const` list or decoration holding a string), constructor defaults become nullable and resolve in `build` (`game_tutorial_overlay.dart`, `home_update_banner.dart`), `static const` channels become getters (`android_notification_display.dart`), `const Failure(AppStrings.x)` → `Failure(AppStrings.x)`. Same in `test/`.
- [ ] Look for strings cached outside `build` (`static final`, `late final`, fields set in `initState`) and read them at build time instead, so a language change shows up.
- [ ] Tests (`test/core/strings/app_strings_test.dart`): English by default; `use('ml')` switches a getter and a method; `use('xx')` falls back to English; `languageCode` follows.
- [ ] Full `flutter test` green (English is byte-for-byte the same).

### 5. Malayalam table — commit `feat(l10n): Malayalam strings`

- [ ] `app_text_ml.dart`: `final class AppTextMl implements AppText`, every member written by hand per the style above. Plurals and word order per string (e.g. `newPuzzleIn` → "പുതിയ പസിൽ 6 മ 12 മി-ൽ"; `leaderboardShortDate` → "ഒക്ടോ 9", CLDR's `ml` "MMM d"). Game titles, "Winklo", "✓", "–", "…", "×2", "ABC234", "0:48" stay as in English.
- [ ] `AppStrings.use('ml')` returns `const AppTextMl()`.
- [ ] Test (`test/core/strings/app_text_test.dart`): every `AppText` member, called with sample args through a table of closures, is non-empty in both tables; Malayalam differs from English except an explicit allowlist; the Malayalam values contain Malayalam script except the allowlist. A count check keeps the closure table in step with the interface (members parsed from `app_text.dart`).
- [ ] `android/app/src/main/res/values-ml/winklo_widget_strings.xml`; title and game names marked `translatable="false"` in `values/`.

### 6. Settings and the locale switch — commit `feat(settings): choose System, English or Malayalam`

**Files:** `lib/features/settings/cubit/locale_cubit.dart`, `locale_state.dart`, `lib/core/widgets/rebuild_descendants.dart`, `lib/main.dart`, `lib/app.dart`, `settings_language_slot.dart`, `settings_screen.dart`; tests `test/features/settings/cubit/locale_cubit_test.dart`, `test/features/settings/view/settings_language_slot_test.dart`, `test/app_locale_switch_test.dart`.

- [ ] Cubit tests first (bloc_test + mocktail): starts from the stored choice and applies it to `AppStrings`; `choose(malayalam)` stores, switches `AppStrings`, emits and replans once; choosing the same language does nothing; English → System on an English phone stores but doesn't replan; System follows `deviceLanguagesChanged()` (phone switches to `ml` → Malayalam, replans); with English chosen a phone change is ignored; a failing replan doesn't break the switch. `tearDown(() => AppStrings.use('en'))`.
- [ ] `LocaleCubit`:

```dart
class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit({required LanguageRepository languages, required List<String> Function() deviceLanguageCodes, Future<void> Function()? onLanguageChanged});
  Future<void> choose(AppLanguage choice);
  void deviceLanguagesChanged();
}
```

  It calls `AppStrings.use` before emitting, then the replan (`RefreshHabitSurfaces`, the same use case Home's lifecycle runs on app open), unawaited with errors swallowed (the next open replans).
- [ ] `main.dart`: `BlocProvider<LocaleCubit>(lazy: false, …)` above the `AuthCubit` provider, so `AppStrings` is set before anything reads it (notifications initialise after the first frame).
- [ ] `app.dart`: `locale: Locale(code)`, `supportedLocales`, `GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations`/`GlobalWidgetsLocalizations` delegates; a `BlocListener` calls `rebuildDescendants` on a change; `didChangeLocales` forwards to the cubit.
- [ ] Settings: `SettingsLanguageSlot` builds a `RadioGroup` with System (its hint names what it resolves to), English and മലയാളം (each language named in its own script); `visible` goes away and the section shows.
- [ ] Widget test: switching to മലയാളം in Settings changes the visible copy at once, including a stateful screen below it.

### 7. Fonts — commit `feat(theme): Noto Sans Malayalam fallback`

- [ ] Bundle `NotoSansMalayalam-Regular.ttf` and `-Bold.ttf` (the google_fonts files, sha256-checked) and `OFL.txt` under `assets/google_fonts/`; register the licence in `LicenseRegistry`.
- [ ] `buildAppTheme`: every Lexend text style gets `fontFamilyFallback: [Lexend, NotoSansMalayalam_regular]` (Bold for weights ≥ 600) through `GoogleFonts.notoSansMalayalam(...).fontFamily`; the direct `GoogleFonts.lexend(...)` styles too (they set their own fallback list).
- [ ] Test: the theme's text styles list the Malayalam fallback.

### 8. Screenshots — commit `test(l10n): Malayalam screens at 360×640`

- [ ] `test/features/l10n/malayalam_screens_test.dart`: Home (with the extras: recap, More ways to play), Zip, Sudoku, Results, Settings, Stats, the More ways to play hub and the Leaderboard, in Malayalam, with `loadScreenshotFonts()` and `await GoogleFonts.pendingFonts()`; `expect(tester.takeException(), isNull)`.
- [ ] Run with `WINKLO_SCREENSHOTS=1`, look at every PNG, shorten strings that overflow or wrap badly. PNGs stay in `build/` (ignored).

### 9. Docs — commit `docs: area G in the README`

- [ ] README "Other languages": done for Malayalam; the Malayalam copy needs a native speaker's review before release; how to add a language (a new `AppText` table + `supportedLanguageCodes`).

### 10. Wrap-up

- [ ] `git merge feat/roadmap-batch` (a Home layout fix lands there); translate any new Home strings.
- [ ] `flutter analyze --no-fatal-infos` (no new issues over the base's 20 infos), full `flutter test`, `dart format` on touched files only, `flutter build apk --debug` (build only).
- [ ] Code review of the diff against `feat/roadmap-batch`; fix real findings; re-run.

## Deviations (recorded as they are made)

- No gen-l10n and no ARB files (see "Design change" above).
