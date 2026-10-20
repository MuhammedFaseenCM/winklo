# Leaderboard Podium and Phosphor Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every icon in the app to Phosphor duotone, and redesign the Leaderboard tab around a top-3 podium, worded gaps and an icon key.

**Architecture:**
- Icons: one `AppIcons` map (`lib/core/theme/app_icons.dart`) is the only file that names Phosphor glyphs. One `AppIcon` widget (`lib/core/widgets/app_icon.dart`) draws a duotone glyph as its two font layers. Every `Icons.*`/`Icon(` in the app moves to them.
- Leaderboard: the board body becomes a `CustomScrollView`. It holds a podium sliver (top 3 plus the badge key), then a `DecoratedSliver` table card with entries 4 and up. Pure layout maths (gaps, row offsets, badge kinds) lives in `features/leaderboard/logic/board_layout.dart`, so the screen's scroll-to-you and pinned-row logic can be unit-tested.

**Tech Stack:** Flutter 3.44, `phosphor_flutter` 2.1.0, `flutter_bloc`, `flutter_test` / `bloc_test` / `mocktail`.

**Spec:** `docs/superpowers/specs/2026-10-20-leaderboard-podium-phosphor-design.md`

> **Execution note (2026-10-20):** `phosphor_flutter` 2.1.0 doesn't compile on Flutter 3.44, because `IconData` is now `final`. Task 1 instead vendors the Phosphor 2.1 TTFs into `assets/fonts/phosphor/` and generates `AppIcons` as `const IconData(codepoint, fontFamily: 'PhosphorDuotone')` entries. It adds a const outline→fill table read through `AppIcons.duotoneFill(icon)`; `AppIcon` uses that instead of `PhosphorDuotoneIconData`. The screenshot helper loads the fonts from `assets/fonts/phosphor/`. Later tasks are unchanged.

**House rules for every task:**
- Run `dart format` on the files you touched only, never `lib`/`test` wholesale.
- Never run a filtered `build_runner`.
- `pubspec.lock` re-resolves on this machine (it downgrades `intl`/`meta`). Before each commit, run `git diff pubspec.lock`. The only lock change allowed on this branch is the `phosphor_flutter` entry; Task 1 Step 7 explains how to keep it.
- Strings come from `AppStrings`. Malayalam strings are first-pass and need native review.

---

## File map

| File | Responsibility |
|---|---|
| `lib/core/theme/app_icons.dart` (new) | Every glyph the app draws, by name |
| `lib/core/widgets/app_icon.dart` (new) | Draws an `AppIcons` glyph; stacks the two layers of a duotone glyph |
| `lib/core/theme/app_theme.dart` | `actionIconTheme` sets the Phosphor back and close icons |
| `lib/core/widgets/user_avatar.dart` | Optional `tintSeed` gives initials avatars one of 7 hues |
| `test/helpers/screenshot.dart` | Loads the Phosphor fonts for screenshot PNGs |
| `lib/features/leaderboard/logic/board_layout.dart` (new) | Podium size, gap rules, row offsets, badge kinds |
| `lib/features/leaderboard/view/widgets/medal_coin.dart` (new) | Drawn gold/silver/bronze coin and podium colours |
| `lib/features/leaderboard/view/widgets/leaderboard_badges.dart` (new) | Badge icons beside a name, and the key line |
| `lib/features/leaderboard/view/widgets/leaderboard_podium.dart` (new) | The top-3 podium |
| `lib/features/leaderboard/view/widgets/leaderboard_board_view.dart` (new) | Podium plus table card as one scroll view |
| `lib/features/leaderboard/view/widgets/leaderboard_table.dart` | Rows: no podium styling, gap under the time, tinted avatar, optional sub-line |
| `lib/features/leaderboard/view/widgets/leaderboard_shimmer.dart` | Podium plus row skeleton |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | Uses `LeaderboardBoardView`; scroll maths via `board_layout.dart`; pinned "behind #N" |
| `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart` | 4 new strings |
| 60+ files across `lib/` and 11 test files | `Icons.*` → `AppIcons.*`, `Icon(` → `AppIcon(` |

## Icon migration table (used by Tasks 2–5)

Material base name (any `_rounded`/`_outlined`/`_outline` suffix) → `AppIcons` name:

| Material | AppIcons | | Material | AppIcons |
|---|---|---|---|---|
| ac_unit | freeze | | info_outline | info |
| add | add | | insights | insights |
| all_inclusive | infinity | | leaderboard | ranking |
| arrow_back | back | | lightbulb, lightbulb_outline | hint (see note 1) |
| arrow_back_ios_new | chevronLeft | | local_fire_department | streak |
| auto_awesome | sparkle | | lock | lock |
| backspace | backspace | | logout | signOut |
| badge | nameBadge | | menu_book | book |
| block | prohibit | | military_tech | medal |
| bolt | lightning | | my_location | locate |
| calendar_month | calendar | | open_in_new | openExternal |
| campaign | announce | | pause_circle_filled | pause |
| casino | dice | | person (filled, selected tab) | userSelected |
| check | check | | person_outline | user |
| check_circle, check_circle_outline | checkCircle | | person_remove | userRemove |
| chevron_left | chevronLeft | | photo_library | photos |
| chevron_right | chevronRight | | play_arrow | play |
| circle_outlined | circle | | privacy_tip | privacy |
| close | close | | public | globe |
| cloud_off | offline | | refresh | refresh |
| compare_arrows, sync_alt | swap | | replay, restart_alt | replay |
| copy | copy | | route | path |
| date_range | week | | schedule | clock |
| delete_outline | delete | | send | send |
| download | download | | share | share |
| downloading | downloading | | shield | shield |
| edit, edit_outlined | edit | | star (filled) | star |
| edit_note | editNote | | star_outline | starOutline |
| emoji_events (filled, selected tab) | trophySelected | | style | cards |
| emoji_events_outlined/_rounded | trophy | | system_update | update |
| expand_more | expand | | text_fields | textAa |
| explore | compass | | timer | timer |
| flag | flag | | today | today |
| grid_on | grid | | tune | tune |
| group | group | | undo | undo |
| group_add | groupAdd | | verified | flawless |
| help_outline | help | | vibration | vibrate |
| home (filled, selected tab) | homeSelected | | volume_up | sound |
| home_outlined, home_rounded | home | | vpn_key | key |
| | | | wb_sunny | sun |

**Note 1:** where a lightbulb means "solved without hints", use `AppIcons.noHints` (the brain) instead of `hint`. That covers the hint-free achievement (`achievement_copy.dart` `hintFreeWeek`) and the Stats "Hint-free" tile (`stat_tiles.dart`). A plain hint (hint buttons, the hint penalty line, the rule tip banner, Sudoku's hint key) stays `AppIcons.hint`.

**Mechanical rules:**
1. Every `Icons.x` becomes `AppIcons.<mapped>`.
2. Every `Icon(` constructor call becomes `AppIcon(`, including `const Icon(` → `const AppIcon(`. Keep `size:`, `color:` and `semanticLabel:` as they are. No `Icon(` in `lib/` uses any other argument.
3. Fields and parameters typed `IconData` stay `IconData`.
4. Add the imports in the file's existing relative style, for example from `lib/features/home/view/widgets/`: `import '../../../../core/theme/app_icons.dart';` and `import '../../../../core/widgets/app_icon.dart';`. Add only the ones you use.
5. In tests, `find.byIcon(Icons.x)` becomes `find.byIcon(AppIcons.<mapped>)` with `import 'package:winklo/core/theme/app_icons.dart';`. `find.byIcon` still works, because the outline layer is an `Icon` whose `icon` is the `AppIcons` constant.

---

### Task 1: Phosphor foundation (`AppIcons`, `AppIcon`, theme, screenshot fonts)

**Files:**
- Modify: `pubspec.yaml` (dependency already added by `flutter pub add phosphor_flutter:^2.1.0`)
- Create: `lib/core/theme/app_icons.dart`
- Create: `lib/core/widgets/app_icon.dart`
- Modify: `lib/core/theme/app_theme.dart` (inside `ThemeData(` at line 129)
- Modify: `test/helpers/screenshot.dart`
- Test: `test/core/widgets/app_icon_test.dart`

- [ ] **Step 1: Write the failing test** `test/core/widgets/app_icon_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/widgets/app_icon.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

void main() {
  testWidgets('a duotone glyph draws its fill layer under the outline', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppIcon(AppIcons.streak, size: 20, color: Color(0xFFFFC27A)),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, hasLength(2));
    final duotone = AppIcons.streak as PhosphorDuotoneIconData;
    expect(icons.first.icon, duotone.secondary);
    expect(icons.first.color!.a, closeTo(appIconDuotoneOpacity, 0.01));
    expect(icons.last.icon, AppIcons.streak);
    expect(icons.last.color, const Color(0xFFFFC27A));
    expect(find.byIcon(AppIcons.streak), findsOneWidget);
  });

  testWidgets('a filled glyph is a single Icon', (tester) async {
    await _pump(tester, const AppIcon(AppIcons.star, size: 20));
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('a duotone glyph is announced once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const AppIcon(AppIcons.streak, semanticLabel: 'Streak'),
    );
    expect(find.bySemanticsLabel('Streak'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('without a colour, both layers take the IconTheme colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const IconTheme(
        data: IconThemeData(color: Color(0xFF38BDF8)),
        child: AppIcon(AppIcons.trophy),
      ),
    );
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.first.color!.withValues(alpha: 1), const Color(0xFF38BDF8));
    expect(icons.last.color, isNull);
  });
}
```

- [ ] **Step 2: Run it and check that it fails**

Run: `flutter test test/core/widgets/app_icon_test.dart`
Expected: FAIL to compile, because `app_icons.dart` / `app_icon.dart` don't exist.

- [ ] **Step 3: Create `lib/core/theme/app_icons.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Every icon the app draws: Phosphor duotone, with a few filled glyphs for
/// selected states. Screens name icons here, never `Icons.*` or Phosphor
/// directly, and draw them with `AppIcon` so both duotone layers show.
abstract final class AppIcons {
  // Navigation
  static const IconData home = PhosphorIconsDuotone.house;
  static const IconData homeSelected = PhosphorIconsFill.house;
  static const IconData trophy = PhosphorIconsDuotone.trophy;
  static const IconData trophySelected = PhosphorIconsFill.trophy;
  static const IconData user = PhosphorIconsDuotone.user;
  static const IconData userSelected = PhosphorIconsFill.user;
  static const IconData back = PhosphorIconsDuotone.arrowLeft;
  static const IconData chevronLeft = PhosphorIconsDuotone.caretLeft;
  static const IconData chevronRight = PhosphorIconsDuotone.caretRight;
  static const IconData expand = PhosphorIconsRegular.caretDown;
  static const IconData close = PhosphorIconsDuotone.x;
  static const IconData openExternal = PhosphorIconsDuotone.arrowSquareOut;

  // Games
  static const IconData lightning = PhosphorIconsDuotone.lightning;
  static const IconData path = PhosphorIconsDuotone.path;
  static const IconData grid = PhosphorIconsDuotone.gridFour;
  static const IconData textAa = PhosphorIconsDuotone.textAa;
  static const IconData swap = PhosphorIconsDuotone.arrowsLeftRight;
  static const IconData cards = PhosphorIconsDuotone.cards;
  static const IconData dice = PhosphorIconsDuotone.diceFive;
  static const IconData infinity = PhosphorIconsDuotone.infinity;
  static const IconData compass = PhosphorIconsDuotone.compass;
  static const IconData book = PhosphorIconsDuotone.bookOpen;
  static const IconData backspace = PhosphorIconsDuotone.backspace;
  static const IconData prohibit = PhosphorIconsDuotone.prohibit;
  static const IconData sparkle = PhosphorIconsDuotone.sparkle;

  // Play controls
  static const IconData play = PhosphorIconsDuotone.play;
  static const IconData pause = PhosphorIconsDuotone.pauseCircle;
  static const IconData refresh = PhosphorIconsDuotone.arrowClockwise;
  static const IconData replay = PhosphorIconsDuotone.arrowCounterClockwise;
  static const IconData undo = PhosphorIconsDuotone.arrowUUpLeft;
  static const IconData hint = PhosphorIconsDuotone.lightbulb;
  static const IconData help = PhosphorIconsDuotone.question;
  static const IconData timer = PhosphorIconsDuotone.timer;
  static const IconData clock = PhosphorIconsDuotone.clock;
  static const IconData send = PhosphorIconsDuotone.paperPlaneTilt;
  static const IconData editNote = PhosphorIconsDuotone.notePencil;

  // Progress and rewards
  static const IconData streak = PhosphorIconsDuotone.fire;
  static const IconData freeze = PhosphorIconsDuotone.snowflake;
  static const IconData noHints = PhosphorIconsDuotone.brain;
  static const IconData flawless = PhosphorIconsDuotone.sealCheck;
  static const IconData crown = PhosphorIconsDuotone.crownSimple;
  static const IconData medal = PhosphorIconsDuotone.medal;
  static const IconData ranking = PhosphorIconsDuotone.ranking;
  static const IconData insights = PhosphorIconsDuotone.chartLineUp;
  static const IconData star = PhosphorIconsFill.star;
  static const IconData starOutline = PhosphorIconsRegular.star;
  static const IconData check = PhosphorIconsDuotone.check;
  static const IconData checkCircle = PhosphorIconsDuotone.checkCircle;
  static const IconData circle = PhosphorIconsDuotone.circle;
  static const IconData lock = PhosphorIconsDuotone.lock;
  static const IconData sun = PhosphorIconsDuotone.sun;

  // Calendar
  static const IconData calendar = PhosphorIconsDuotone.calendarBlank;
  static const IconData today = PhosphorIconsDuotone.calendarDot;
  static const IconData week = PhosphorIconsDuotone.calendarDots;

  // People and leagues
  static const IconData globe = PhosphorIconsDuotone.globeHemisphereWest;
  static const IconData group = PhosphorIconsDuotone.usersThree;
  static const IconData groupAdd = PhosphorIconsDuotone.userPlus;
  static const IconData userRemove = PhosphorIconsDuotone.userMinus;
  static const IconData nameBadge = PhosphorIconsDuotone.identificationBadge;
  static const IconData key = PhosphorIconsDuotone.key;
  static const IconData locate = PhosphorIconsDuotone.crosshair;
  static const IconData share = PhosphorIconsDuotone.shareNetwork;
  static const IconData copy = PhosphorIconsDuotone.copy;
  static const IconData edit = PhosphorIconsDuotone.pencilSimple;
  static const IconData add = PhosphorIconsDuotone.plus;
  static const IconData delete = PhosphorIconsDuotone.trash;
  static const IconData signOut = PhosphorIconsDuotone.signOut;
  static const IconData photos = PhosphorIconsDuotone.images;

  // Settings and system
  static const IconData tune = PhosphorIconsDuotone.slidersHorizontal;
  static const IconData sound = PhosphorIconsDuotone.speakerHigh;
  static const IconData vibrate = PhosphorIconsDuotone.vibrate;
  static const IconData announce = PhosphorIconsDuotone.megaphone;
  static const IconData privacy = PhosphorIconsDuotone.shieldCheck;
  static const IconData shield = PhosphorIconsDuotone.shield;
  static const IconData info = PhosphorIconsDuotone.info;
  static const IconData flag = PhosphorIconsDuotone.flag;
  static const IconData download = PhosphorIconsDuotone.downloadSimple;
  static const IconData downloading = PhosphorIconsDuotone.cloudArrowDown;
  static const IconData update = PhosphorIconsDuotone.arrowCircleUp;
  static const IconData offline = PhosphorIconsDuotone.cloudSlash;
}
```

- [ ] **Step 4: Create `lib/core/widgets/app_icon.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// How strongly a duotone glyph's fill layer shows under its outline.
const double appIconDuotoneOpacity = 0.22;

/// Draws an `AppIcons` glyph. A Phosphor duotone glyph is two font layers,
/// a faint fill under the outline; a plain [Icon] would draw only the
/// outline. The fill is skipped by screen readers, so the icon is read once.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    final outline = Icon(
      glyph,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
    if (glyph is! PhosphorDuotoneIconData) return outline;

    final base =
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            glyph.secondary,
            size: size,
            color: base.withValues(alpha: base.a * appIconDuotoneOpacity),
          ),
        ),
        outline,
      ],
    );
  }
}
```

- [ ] **Step 5: Run the test and check that it passes**

Run: `flutter test test/core/widgets/app_icon_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Theme and screenshot fonts**

In `lib/core/theme/app_theme.dart`, add the imports `import '../widgets/app_icon.dart';` and `import 'app_icons.dart';`. Inside `ThemeData(` (line 129), after `scaffoldBackgroundColor: ZipColors.ink,`, add:

```dart
    // BackButton / CloseButton draw Phosphor like the rest of the app.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => const AppIcon(AppIcons.back),
      closeButtonIconBuilder: (context) => const AppIcon(AppIcons.close),
    ),
```

In `test/helpers/screenshot.dart`:
- Add `import 'dart:convert';`.
- Update the doc comment's list of loaded fonts to include "the Phosphor icons".
- After the two Malayalam `loadFiles` calls and before `final fonts = _materialFontsDir();`, add:

```dart
  // Phosphor ships its fonts in its package; IconData asks for them as
  // 'packages/phosphor_flutter/Phosphor<Style>'.
  final phosphor = _packageLibDir('phosphor_flutter');
  if (phosphor != null) {
    for (final (style, file) in [
      ('Duotone', 'Phosphor-Duotone.ttf'),
      ('Fill', 'Phosphor-Fill.ttf'),
      ('Regular', 'Phosphor.ttf'),
    ]) {
      await loadFiles('packages/phosphor_flutter/Phosphor$style', [
        '${phosphor.path}/fonts/$file',
      ]);
    }
  }
```

and below `_materialFontsDir()`:

```dart
/// [name]'s `lib/` folder, from the package config `flutter test` uses.
Directory? _packageLibDir(String name) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final package in (json['packages'] as List).cast<Map>()) {
    if (package['name'] != name) continue;
    var root = package['rootUri'] as String;
    if (!root.endsWith('/')) root = '$root/';
    final lib = config.absolute.uri
        .resolve(root)
        .resolve((package['packageUri'] as String?) ?? 'lib/');
    final dir = Directory.fromUri(lib);
    return dir.existsSync() ? dir : null;
  }
  return null;
}
```

- [ ] **Step 7: Keep the lockfile honest, then commit**

```bash
git show origin/master:pubspec.lock > /tmp/lock.master   # use the scratchpad dir
```

Write `pubspec.lock` as master's lock with only the `phosphor_flutter:` package block inserted in alphabetical order. Copy the block from the current re-resolved lock: name `phosphor_flutter`, version `2.1.0`, sha256 `8a14f238f28a0b54842c5a4dc20676598dd4811fcba284ed828bd5a262c11fde`. Then run `git diff pubspec.lock` and expect exactly that +8-line block.

```bash
dart format lib/core/theme/app_icons.dart lib/core/widgets/app_icon.dart lib/core/theme/app_theme.dart test/helpers/screenshot.dart test/core/widgets/app_icon_test.dart
git add pubspec.yaml pubspec.lock lib/core/theme/app_icons.dart lib/core/widgets/app_icon.dart lib/core/theme/app_theme.dart test/helpers/screenshot.dart test/core/widgets/app_icon_test.dart
git commit -m "feat(icons): add Phosphor duotone AppIcons and the AppIcon widget"
```

---

### Task 2: Migrate core widgets, dashboard and Home

**Files (lib):**
- `core/widgets/bonus_game_chrome.dart`
- `core/widgets/cleared_summary/cleared_summary_card.dart`
- `core/widgets/game_rule_tip_banner.dart`
- `core/widgets/paused_board_cover.dart`
- `core/widgets/play_mode_strip.dart`
- `core/widgets/weekend_special_badge.dart`
- `core/widgets/zip_ui.dart`: it builds `Icon(icon, …)` at lines 244 and ~315
- `features/dashboard/view/widgets/floating_nav_dock.dart`: selected tabs use the `*Selected` fill glyphs
- `features/home/view/home_screen.dart`
- `features/home/view/widgets/home_freeze_badge.dart`
- `features/home/view/widgets/home_habit_cards.dart`
- `features/home/view/widgets/home_more_play_entry.dart`
- `features/home/view/widgets/home_soft_update_section.dart`
- `features/home/view/widgets/home_today_summary.dart`
- `features/home/view/widgets/home_update_banner.dart`

**Files (test):**
- `test/core/widgets/weekend_special_badge_test.dart`
- `test/features/bonus_games_view_test.dart`
- `test/features/dashboard/floating_nav_dock_test.dart`
- `test/features/home/home_header_test.dart`
- `test/features/home/view/home_screen_test.dart`
- `test/features/home/view/widgets/home_freeze_badge_test.dart`

- [ ] **Step 1:** Apply the mechanical rules and the migration table to every file listed.
- [ ] **Step 2:** Verify none remain: `grep -nE "Icons\.|\bIcon\(" <the files>` prints nothing.
- [ ] **Step 3:** Run `dart analyze <the lib files>`. Expected: no errors.
- [ ] **Step 4:** Run `flutter test <the test files listed> test/features/dashboard test/features/home`. Expected: PASS.
- [ ] **Step 5:** Run `dart format <the files>`, then commit: `git commit -m "refactor(icons): Phosphor in core widgets, the nav dock and Home"`.

### Task 3: Migrate the games

**Files (lib):**
- `features/zip/view/zip_screen.dart`
- `features/zip/view/widgets/zip_tutorial.dart`
- `features/zip/view/widgets/zip_replay_button.dart`
- `features/zip/view/widgets/zip_how_to_play.dart`
- `features/path_words/view/path_words_screen.dart`
- `features/path_words/view/widgets/path_words_theme_line.dart`
- `features/path_words/view/widgets/path_words_tutorial.dart`
- `features/path_words/view/widgets/path_words_word_list.dart`
- `features/path_words/view/widgets/path_words_results_panel.dart`
- `features/path_words/view/widgets/path_words_how_to_play.dart`
- `features/sudoku/view/sudoku_screen.dart`: it builds `Icon(icon, size: 18)` at line ~647
- `features/sudoku/view/widgets/sudoku_how_to_play.dart`
- `features/word_match/view/word_match_select_screen.dart`: line ~190 `Icon(icon, …)`
- `features/category_race/view/category_race_screen.dart`
- `features/more_play/view/more_play_screen.dart`
- `features/more_play/view/more_play_widgets.dart`
- `features/more_play/view/archive_screen.dart`

**Files (test):** `test/features/more_play/more_play_screens_test.dart`

- [ ] Steps 1–5 as in Task 2. Test run: `flutter test test/features/zip test/features/path_words test/features/sudoku test/features/word_match test/features/category_race test/features/more_play test/features/bonus_games_view_test.dart`. Commit message: `refactor(icons): Phosphor in the games and More play`.

### Task 4: Migrate Profile, Settings, Stats, achievements, leagues and results

**Files (lib):**
- `features/profile/view/profile_screen.dart`
- `features/profile/view/widgets/avatar_edit_sheet.dart`
- `features/profile/view/widgets/name_edit_sheet.dart`
- `features/profile/view/widgets/about_game_dialog.dart`: line ~229 `Icon(icon, …)`
- `features/profile/view/widgets/confirm_action_dialog.dart`: lines ~70 and ~105
- `features/profile/view/widgets/delete_account_confirm_dialog.dart`
- `features/profile/view/widgets/profile_settings_entry.dart`
- `features/profile/view/widgets/profile_settings_list.dart`: line ~137 `leading: Icon(icon, …)`
- `features/profile/view/widgets/profile_stats_section.dart`
- `features/profile/view/widgets/sign_out_confirm_dialog.dart`
- `features/settings/view/settings_screen.dart`
- `features/settings/view/widgets/settings_section.dart`: line ~103 `secondary: Icon(icon, …)`
- `features/stats/view/stats_screen.dart`
- `features/stats/view/widgets/stat_tiles.dart`: the Hint-free tile uses `noHints` (note 1); line ~97 `Icon(icon, …)`
- `features/stats/view/widgets/clear_calendar_view.dart`
- `features/achievements/view/achievement_copy.dart`: `hintFreeWeek` uses `noHints` (note 1)
- `features/achievements/view/achievement_medal.dart`
- `features/achievements/view/badges_screen.dart`
- `features/achievements/view/badges_summary_card.dart`
- `features/leagues/view/leagues_screen.dart`
- `features/leagues/view/join_league_screen.dart`
- `features/leagues/view/league_detail_screen.dart`
- `features/leagues/view/widgets/leagues_page.dart`
- `features/results/results_screen.dart`
- `features/results/view/local_results_view.dart`
- `features/results/view/mini_leaderboard_panel.dart`
- `features/results/view/results_actions.dart`: line ~188 `icon: Icon(widget.icon)`
- `features/results/view/hint_penalty_line.dart`

**Files (test):**
- `test/features/achievements/view/achievement_copy_test.dart`: its lightbulb expectation becomes `AppIcons.noHints`
- `test/features/profile/view/profile_screen_test.dart`
- `test/features/settings/view/settings_screen_test.dart`

- [ ] Steps 1–5 as in Task 2. Test run: `flutter test test/features/profile test/features/settings test/features/stats test/features/achievements test/features/leagues test/features/results`. Commit message: `refactor(icons): Phosphor in Profile, Settings, Stats, badges, leagues and results`.

### Task 5: Migrate the leaderboard feature's icons (no layout changes yet)

**Files:**
- `features/leaderboard/view/leaderboard_screen.dart`: lines 398, 414, 463–467, 476–477, 572, 599 and 968. `my_location` → `locate`.
- `features/leaderboard/view/widgets/leaderboard_board_sheet.dart`
- `features/leaderboard/view/widgets/leaderboard_sheet_parts.dart`
- `features/leaderboard/view/widgets/leaderboard_filter_row.dart`: default `scopeIcon` → `AppIcons.globe`; line 95 `Icon(icon` → `AppIcon(icon`; `expand_more` → `expand`
- `features/leaderboard/view/widgets/leaderboard_scope_sheet.dart`
- `features/leaderboard/view/widgets/leaderboard_game_tabs.dart`: zip → `lightning`, pathWords → `path`, sudoku → `grid`; line 128 → `AppIcon`
- `features/leaderboard/view/widgets/player_card_sheet.dart`: line 124 → `AppIcons.streak`; line 197 → `AppIcon`
- `test/features/leaderboard/view/leaderboard_screen_test.dart` (2 refs)

`leaderboard_table.dart` is rewritten in Task 9; leave its icons until then.

- [ ] Steps 1–4 as in Task 2, with `flutter test test/features/leaderboard`.
- [ ] **Step 5: Whole-app check.** `grep -rnE "Icons\.|\bIcon\(" lib | grep -v "lib/core/widgets/app_icon.dart\|leaderboard_table.dart"` prints nothing. Then `flutter analyze`: no issues. Commit: `refactor(icons): Phosphor on the leaderboard's tabs, pickers and sheets`.

---

### Task 6: Strings

**Files:** `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart`

- [ ] **Step 1:** In `app_text.dart`, next to `String get leaderboardNoMistakesChip;` (line ~255), add:

```dart
  /// The badge key's name for the streak flame.
  String get leaderboardKeyStreak;

  /// Under the pinned row: how far you are behind the player at [rank].
  String leaderboardBehind(String gap, int rank);

  /// A podium place read aloud.
  String leaderboardPodiumSemantics(int rank, String name, String time);

  /// Days cleared this week, under a weekly podium time.
  String leaderboardDaysShort(int days);
```

- [ ] **Step 2:** In `app_text_en.dart`, after `leaderboardNoMistakesChip` (line 720):

```dart
  @override
  String get leaderboardKeyStreak => 'Day streak';

  @override
  String leaderboardBehind(String gap, int rank) => '$gap behind #$rank';

  @override
  String leaderboardPodiumSemantics(int rank, String name, String time) =>
      'Rank $rank, $name, $time';

  @override
  String leaderboardDaysShort(int days) => days == 1 ? '1 day' : '$days days';
```

- [ ] **Step 3:** In `app_text_ml.dart`, after `leaderboardNoMistakesChip` (line 760):

```dart
  @override
  String get leaderboardKeyStreak => 'ദിവസ സ്ട്രീക്ക്';

  @override
  String leaderboardBehind(String gap, int rank) =>
      '#$rank-നേക്കാൾ $gap പിന്നിൽ';

  @override
  String leaderboardPodiumSemantics(int rank, String name, String time) =>
      'റാങ്ക് $rank, $name, $time';

  @override
  String leaderboardDaysShort(int days) => '$days ദിവസം';
```

- [ ] **Step 4:** In `app_strings.dart`, after `leaderboardNoMistakesChip` (line 312):

```dart
  static String get leaderboardKeyStreak => _t.leaderboardKeyStreak;
  static String leaderboardBehind(String gap, int rank) =>
      _t.leaderboardBehind(gap, rank);
  static String leaderboardPodiumSemantics(
    int rank,
    String name,
    String time,
  ) => _t.leaderboardPodiumSemantics(rank, name, time);
  static String leaderboardDaysShort(int days) => _t.leaderboardDaysShort(days);
```

- [ ] **Step 5:** Run `flutter analyze lib/core/strings`. Expected: no issues. Commit: `feat(leaderboard): strings for the podium, key and behind line`.

### Task 7: Board layout logic

**Files:** Create `lib/features/leaderboard/logic/board_layout.dart`; Test `test/features/leaderboard/logic/board_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/logic/board_layout.dart';

LeaderboardEntry _e(
  int seconds, {
  bool? usedHints,
  bool? hadMistakes,
  int? streak,
}) => LeaderboardEntry(
  uid: 'u$seconds',
  displayName: 'P',
  timeSeconds: seconds,
  updatedAt: DateTime.utc(2026, 10, 20),
  rank: 1,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  currentStreak: streak,
);

void main() {
  group('leaderboardGapSeconds', () {
    test('seconds behind on the daily and all-time boards', () {
      for (final period in [
        LeaderboardPeriod.daily,
        LeaderboardPeriod.allTime,
      ]) {
        expect(
          leaderboardGapSeconds(entry: _e(57), ahead: _e(42), period: period),
          15,
        );
      }
    });

    test('none on the weekly board, where days rank first', () {
      expect(
        leaderboardGapSeconds(
          entry: _e(57),
          ahead: _e(42),
          period: LeaderboardPeriod.weekly,
        ),
        isNull,
      );
    });

    test('none for a tie', () {
      expect(
        leaderboardGapSeconds(
          entry: _e(42),
          ahead: _e(42),
          period: LeaderboardPeriod.daily,
        ),
        isNull,
      );
    });
  });

  group('leaderboardEntryTop', () {
    test('the podium is at the top', () {
      for (final i in [0, 1, 2]) {
        expect(
          leaderboardEntryTop(index: i, headExtent: 220, rowExtent: 52),
          0,
        );
      }
    });

    test('rows start after the head', () {
      expect(leaderboardEntryTop(index: 3, headExtent: 220, rowExtent: 52), 220);
      expect(
        leaderboardEntryTop(index: 13, headExtent: 220, rowExtent: 52),
        220 + 10 * 52,
      );
    });
  });

  group('leaderboardBadgesFor', () {
    test('daily: hint-free, Sudoku flawless and a 2+ day streak', () {
      expect(
        leaderboardBadgesFor(
          _e(60, usedHints: false, hadMistakes: false, streak: 2),
          period: LeaderboardPeriod.daily,
          gameId: GameIds.sudoku,
        ),
        [
          LeaderboardBadge.noHints,
          LeaderboardBadge.flawless,
          LeaderboardBadge.streak,
        ],
      );
    });

    test('flawless is Sudoku only; a 1-day streak and unknowns earn none', () {
      expect(
        leaderboardBadgesFor(
          _e(60, hadMistakes: false, streak: 1),
          period: LeaderboardPeriod.daily,
          gameId: GameIds.zip,
        ),
        isEmpty,
      );
    });

    test('only the daily board shows badges', () {
      expect(
        leaderboardBadgesFor(
          _e(60, usedHints: false, streak: 9),
          period: LeaderboardPeriod.weekly,
          gameId: GameIds.zip,
        ),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2:** Run `flutter test test/features/leaderboard/logic/board_layout_test.dart`. Expected: FAIL (file missing).

- [ ] **Step 3: Implement** `lib/features/leaderboard/logic/board_layout.dart`

```dart
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';

/// How many players stand on the podium; the table lists everyone else.
const int leaderboardPodiumSize = 3;

/// Seconds [entry] is behind [ahead], or null when there's nothing to show:
/// a tie, or the weekly board, which ranks by days cleared before time.
int? leaderboardGapSeconds({
  required LeaderboardEntry entry,
  required LeaderboardEntry ahead,
  required LeaderboardPeriod period,
}) {
  if (period == LeaderboardPeriod.weekly) return null;
  final gap = entry.timeSeconds - ahead.timeSeconds;
  return gap > 0 ? gap : null;
}

/// Where entry [index] starts in the board's scroll view: the podium places
/// sit at the top, and the rows start after [headExtent] (podium, badge key
/// and any column header).
double leaderboardEntryTop({
  required int index,
  required double headExtent,
  required double rowExtent,
}) {
  if (index < leaderboardPodiumSize) return 0;
  return headExtent + (index - leaderboardPodiumSize) * rowExtent;
}

/// A clean-run mark shown next to a name on the daily board.
enum LeaderboardBadge { noHints, flawless, streak }

/// The badges [entry] earns on [period]'s board for [gameId], in display
/// order. Unknown (null) fields earn nothing; only the daily board has any.
List<LeaderboardBadge> leaderboardBadgesFor(
  LeaderboardEntry entry, {
  required LeaderboardPeriod period,
  required String gameId,
}) {
  if (period != LeaderboardPeriod.daily) return const [];
  final streak = entry.currentStreak;
  return [
    if (entry.usedHints == false) LeaderboardBadge.noHints,
    if (gameId == GameIds.sudoku && entry.hadMistakes == false)
      LeaderboardBadge.flawless,
    if (streak != null && streak >= 2) LeaderboardBadge.streak,
  ];
}
```

- [ ] **Step 4:** Run the test. Expected: PASS. Commit: `feat(leaderboard): board layout maths for the podium`.

### Task 8: Tinted initials avatars

**Files:** Modify `lib/core/widgets/user_avatar.dart`; Test `test/core/widgets/user_avatar_tint_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/user_avatar.dart';

void main() {
  test('a seed always gets the same hue from the palette', () {
    expect(avatarTintFor('uid-123'), avatarTintFor('uid-123'));
    expect(avatarTintPalette, contains(avatarTintFor('uid-123')));
  });

  test('different players spread across the palette', () {
    final hues = {for (var i = 0; i < 40; i++) avatarTintFor('player$i')};
    expect(hues.length, greaterThanOrEqualTo(5));
  });

  testWidgets('initials take the tint; no seed keeps the grey', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            const UserAvatar(displayName: 'Ada', tintSeed: 'u1'),
            const UserAvatar(displayName: 'Bo'),
          ],
        ),
      ),
    );
    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();
    final tint = avatarTintFor('u1');
    expect(avatars[0].backgroundColor, tint.withValues(alpha: 0.18));
    expect(tester.widget<Text>(find.text('A')).style?.color, tint);
    expect(avatars[1].backgroundColor, ZipColors.mistDeep);
  });
}
```

- [ ] **Step 2:** Run it. Expected: FAIL (`avatarTintFor` undefined).

- [ ] **Step 3: Implement.** In `user_avatar.dart`, above `class UserAvatar`:

```dart
/// Hues for initials avatars, so a board of letters isn't all grey.
const avatarTintPalette = <Color>[
  ZipColors.ember,
  ZipColors.sky,
  ZipColors.success,
  ZipColors.number,
  Color(0xFFA78BFA), // violet
  Color(0xFFFBBF24), // amber
  Color(0xFFA3E635), // lime
];

/// [seed]'s hue from [avatarTintPalette]: the same seed always gets the same.
Color avatarTintFor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return avatarTintPalette[hash % avatarTintPalette.length];
}
```

Add the field `this.tintSeed,` to the constructor and `final String? tintSeed;` with the doc `/// When set, an initials avatar is tinted with [avatarTintFor] this seed.`. Replace `_initials` and the last `return CircleAvatar(...)` with:

```dart
  Color? get _tint => tintSeed == null ? null : avatarTintFor(tintSeed!);

  Widget get _initials => Text(
    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
    style: TextStyle(
      color: _tint ?? ZipColors.onInk,
      fontWeight: _tint == null ? null : FontWeight.w700,
    ),
  );
```

```dart
    return CircleAvatar(
      radius: radius,
      backgroundColor: _tint?.withValues(alpha: 0.18) ?? ZipColors.mistDeep,
      child: _initials,
    );
```

- [ ] **Step 4:** Run `flutter test test/core/widgets/user_avatar_tint_test.dart test/core/widgets`. Expected: PASS. Commit: `feat(avatar): optional tint for initials avatars`.

### Task 9: Medal coin, badge icons, key, and the row redesign

**Files:**
- Create: `lib/features/leaderboard/view/widgets/medal_coin.dart`
- Create: `lib/features/leaderboard/view/widgets/leaderboard_badges.dart`
- Modify: `lib/features/leaderboard/view/widgets/leaderboard_table.dart`
- Test: `test/features/leaderboard/view/widgets/leaderboard_badges_test.dart`, and update `test/features/leaderboard/view/widgets/leaderboard_table_test.dart`

- [ ] **Step 1: Write failing tests** `leaderboard_badges_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/leaderboard/logic/board_layout.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_badges.dart';
import 'package:winklo/features/leaderboard/view/widgets/medal_coin.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('the key names only the badges on the board, in order', (
    tester,
  ) async {
    await _pump(
      tester,
      const LeaderboardBadgeKey(
        badges: {LeaderboardBadge.streak, LeaderboardBadge.noHints},
      ),
    );
    expect(find.text(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(find.text(AppStrings.leaderboardKeyStreak), findsOneWidget);
    expect(find.text(AppStrings.leaderboardNoMistakesChip), findsNothing);
    expect(
      tester.getCenter(find.text(AppStrings.leaderboardNoHintChip)).dx,
      lessThan(tester.getCenter(find.text(AppStrings.leaderboardKeyStreak)).dx),
    );
    expect(find.byIcon(AppIcons.noHints), findsOneWidget);
    expect(find.byIcon(AppIcons.streak), findsOneWidget);
  });

  testWidgets('no badges, no key', (tester) async {
    await _pump(tester, const LeaderboardBadgeKey(badges: {}));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a medal coin shows its rank', (tester) async {
    await _pump(tester, const MedalCoin(rank: 2));
    expect(find.text('2'), findsOneWidget);
    expect(podiumColor(1), leaderboardGold);
    expect(podiumColor(4), isNull);
  });
}
```

In `leaderboard_table_test.dart`:
- Delete the old `'a daily row: …'` height assertion's literal reliance on 56. It compares with `leaderboardTableRowHeight`, which becomes 52; keep it.
- Add:

```dart
  testWidgets('a daily row shows its gap to the leader under the time', (
    tester,
  ) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
        gapSeconds: 15,
      ),
    );
    expect(find.text('+0:15'), findsOneWidget);
  });

  testWidgets('the pinned row can carry a sub-line', (tester) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: true,
        subtitle: AppStrings.leaderboardBehind('0:05', 13),
      ),
    );
    expect(find.text(AppStrings.leaderboardBehind('0:05', 13)), findsOneWidget);
  });

  testWidgets('a row tints an initials avatar by uid', (tester) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).tintSeed, 'u4');
  });
```

with `import 'package:winklo/core/widgets/user_avatar.dart';`.

- [ ] **Step 2:** Run both test files. Expected: FAIL (missing files and params).

- [ ] **Step 3: Create `medal_coin.dart`**

```dart
import 'package:flutter/material.dart';

const leaderboardGold = Color(0xFFFFD700);
const leaderboardSilver = Color(0xFFD4DFEB);
const leaderboardBronze = Color(0xFFE28B52);

/// Gold, silver or bronze for podium place [place]; null below the podium.
Color? podiumColor(int place) => switch (place) {
  1 => leaderboardGold,
  2 => leaderboardSilver,
  3 => leaderboardBronze,
  _ => null,
};

/// A drawn medal with [rank] stamped on it: no network image, so it shows
/// offline and in tests.
class MedalCoin extends StatelessWidget {
  const MedalCoin({super.key, required this.rank, this.size = 22});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = podiumColor(rank) ?? leaderboardSilver;
    final light = Color.lerp(base, Colors.white, 0.55)!;
    final dark = Color.lerp(base, Colors.black, 0.3)!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [light, base, dark],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: dark),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$rank',
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: size * 0.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `leaderboard_badges.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../logic/board_layout.dart';

IconData _icon(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => AppIcons.noHints,
  LeaderboardBadge.flawless => AppIcons.flawless,
  LeaderboardBadge.streak => AppIcons.streak,
};

Color _color(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => const Color(0xFF7EE0C3),
  LeaderboardBadge.flawless => const Color(0xFF9EC0FF),
  LeaderboardBadge.streak => const Color(0xFFFFC27A),
};

String _keyLabel(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => AppStrings.leaderboardNoHintChip,
  LeaderboardBadge.flawless => AppStrings.leaderboardNoMistakesChip,
  LeaderboardBadge.streak => AppStrings.leaderboardKeyStreak,
};

/// What [badge] means for [entry], read aloud.
String leaderboardBadgeSemantics(
  LeaderboardBadge badge,
  LeaderboardEntry entry,
) => badge == LeaderboardBadge.streak
    ? AppStrings.streakLabel(entry.currentStreak ?? 0)
    : _keyLabel(badge);

/// [entry]'s [badges] as small icons after a name; the flame shows the
/// streak's day count when [showStreakCount].
class LeaderboardBadgeIcons extends StatelessWidget {
  const LeaderboardBadgeIcons({
    super.key,
    required this.entry,
    required this.badges,
    this.size = 15,
    this.showStreakCount = true,
  });

  final LeaderboardEntry entry;
  final List<LeaderboardBadge> badges;
  final double size;
  final bool showStreakCount;

  @override
  Widget build(BuildContext context) {
    final countStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: _color(LeaderboardBadge.streak),
      fontWeight: FontWeight.w800,
      fontSize: size * 0.75,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, badge) in badges.indexed) ...[
          if (i > 0) const SizedBox(width: 3),
          Semantics(
            label: leaderboardBadgeSemantics(badge, entry),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(_icon(badge), size: size, color: _color(badge)),
                if (badge == LeaderboardBadge.streak && showStreakCount)
                  Text('${entry.currentStreak}', style: countStyle),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One line saying what the badge icons mean: only the kinds in [badges],
/// always in the same order. Nothing when the board has none.
class LeaderboardBadgeKey extends StatelessWidget {
  const LeaderboardBadgeKey({super.key, required this.badges});

  final Set<LeaderboardBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final badge in LeaderboardBadge.values)
            if (badges.contains(badge))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(_icon(badge), size: 14, color: _color(badge)),
                  const SizedBox(width: 4),
                  Text(_keyLabel(badge), style: style),
                ],
              ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite the row parts of `leaderboard_table.dart`**
- `leaderboardTableRowHeight` becomes `52`, and add `const double leaderboardTableHeaderHeight = 30;`. `LeaderboardTableHeader` uses it instead of `height: 30`.
- Delete `_noHintColor`, `_flawlessColor`, `_streakColor`, `_gold`, `_silver`, `_bronze`, `_podiumWash`, `_podiumAccent`, `_NoHintIcon` and `_SlashPainter`. Also delete the `static_assets_config.dart` and `app_image.dart` imports once they're unused, and `LeaderboardTableCard`, which only the old screen used (check with grep).
- Add imports: `../../logic/board_layout.dart` and `leaderboard_badges.dart`.
- Rename `_YouPill` to public `LeaderboardYouPill`; the podium uses it too.
- `LeaderboardTableRow` gets `this.gapSeconds` and `this.subtitle`, documented as "Seconds behind #1, shown under the time" and "A line under the name (the pinned row's 'behind #N')".
- `build`: the wash is `isYou ? ZipColors.ember.withValues(alpha: 0.14) : Colors.transparent`, and the You bar shows when `isYou`. The container is always the plain divider/left-bar decoration (the old non-podium branch). The avatar passes `tintSeed: entry.uid`. The time cell becomes:

```dart
        SizedBox(
          width: _timeWidth,
          child: _FitCell(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppStrings.formatPlayTime(entry.timeSeconds),
                  maxLines: 1,
                  style: numberStyle?.copyWith(
                    color: isYou
                        ? ZipColors.ember
                        : ZipColors.onInk.withValues(alpha: 0.95),
                  ),
                ),
                if (gapSeconds != null)
                  Text(
                    '+${AppStrings.formatPlayTime(gapSeconds!)}',
                    maxLines: 1,
                    style: textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
```

- `_rank`: always the plain number, without the grey circle:

```dart
  Widget _rank(BuildContext context) => Text(
    '${entry.rank}',
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: isYou ? ZipColors.ember : ZipColors.inkSoft,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
```

- `_name`: the name `Flexible` and the `LeaderboardYouPill`, then:

```dart
        if (badges.isNotEmpty) ...[
          const SizedBox(width: 6),
          LeaderboardBadgeIcons(entry: entry, badges: badges),
        ],
```

where `final badges = leaderboardBadgesFor(entry, period: period, gameId: gameId);`. When `subtitle != null`, `_name` returns:

```dart
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameRow,
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFFFFB18A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    )
```

- [ ] **Step 6:** Run `flutter test test/features/leaderboard/view/widgets`. Expected: PASS. Existing table tests keep passing, because the semantics labels are unchanged (`leaderboardNoHintChip`, `leaderboardNoMistakesChip`, `streakLabel(n)`). Commit: `feat(leaderboard): drawn medals, worded key, rows with gaps`.

### Task 10: The podium

**Files:** Create `lib/features/leaderboard/view/widgets/leaderboard_podium.dart`; Test `test/features/leaderboard/view/widgets/leaderboard_podium_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_podium.dart';
import 'package:winklo/features/leaderboard/view/widgets/medal_coin.dart';

LeaderboardEntry _e(int rank, {int? days}) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Player $rank',
  timeSeconds: 40 + rank * 5,
  updatedAt: DateTime.utc(2026, 10, 20),
  rank: rank,
  daysCleared: days,
  usedHints: rank == 1 ? false : null,
);

Future<List<LeaderboardEntry>> _pump(
  WidgetTester tester,
  List<LeaderboardEntry> entries, {
  LeaderboardPeriod period = LeaderboardPeriod.daily,
  String? currentUid,
  Key? youKey,
}) async {
  final tapped = <LeaderboardEntry>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: LeaderboardPodium(
            entries: entries,
            period: period,
            gameId: GameIds.zip,
            currentUid: currentUid,
            youKey: youKey,
            onTap: tapped.add,
          ),
        ),
      ),
    ),
  );
  return tapped;
}

void main() {
  testWidgets('first in the middle, second left, third right', (
    tester,
  ) async {
    await _pump(tester, [_e(1), _e(2), _e(3)]);
    final x1 = tester.getCenter(find.text('Player 1')).dx;
    expect(tester.getCenter(find.text('Player 2')).dx, lessThan(x1));
    expect(tester.getCenter(find.text('Player 3')).dx, greaterThan(x1));
    expect(find.byType(MedalCoin), findsNWidgets(3));
    expect(find.byIcon(AppIcons.crown), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
  });

  testWidgets('one player stays in the middle', (tester) async {
    await _pump(tester, [_e(1)]);
    expect(tester.getCenter(find.text('Player 1')).dx, closeTo(180, 12));
    expect(find.byType(MedalCoin), findsOneWidget);
  });

  testWidgets('the weekly podium shows days cleared', (tester) async {
    await _pump(tester, [
      _e(1, days: 7),
      _e(2, days: 6),
    ], period: LeaderboardPeriod.weekly);
    expect(find.text(AppStrings.leaderboardDaysShort(7)), findsOneWidget);
    expect(find.text(AppStrings.leaderboardDaysShort(6)), findsOneWidget);
  });

  testWidgets('your place says You and carries your key', (tester) async {
    final key = GlobalKey();
    await _pump(tester, [_e(1), _e(2)], currentUid: 'u2', youKey: key);
    expect(find.text(AppStrings.youLabel), findsOneWidget);
    expect(key.currentContext, isNotNull);
  });

  testWidgets('tapping a place reports its entry', (tester) async {
    final tapped = await _pump(tester, [_e(1), _e(2), _e(3)]);
    await tester.tap(find.text('Player 3'));
    expect(tapped.single.uid, 'u3');
  });

  testWidgets('each place is read as one button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_e(1)]);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^${RegExp.escape(AppStrings.leaderboardPodiumSemantics(1, 'Player 1', '0:45'))}',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
```

- [ ] **Step 2:** Run it. Expected: FAIL (file missing).

- [ ] **Step 3: Implement `leaderboard_podium.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_layout.dart';
import 'leaderboard_badges.dart';
import 'leaderboard_table.dart';
import 'medal_coin.dart';

/// The top of the board on a podium: second, first and third from the left.
/// A missing place keeps its column, so first always stands in the middle.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.entries,
    required this.period,
    required this.gameId,
    required this.currentUid,
    required this.onTap,
    this.youKey,
  });

  /// The board's first entries; only the first [leaderboardPodiumSize] show.
  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final String gameId;
  final String? currentUid;
  final ValueChanged<LeaderboardEntry> onTap;

  /// Put on your place, so the screen can tell when it's on screen.
  final Key? youKey;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    Widget place(int index, int flex) {
      final entry = index < entries.length ? entries[index] : null;
      if (entry == null) return Expanded(flex: flex, child: const SizedBox());
      final isYou = entry.uid == currentUid;
      final child = _PodiumPlace(
        entry: entry,
        place: index + 1,
        period: period,
        gameId: gameId,
        isYou: isYou,
        onTap: () => onTap(entry),
      );
      return Expanded(
        flex: flex,
        child: isYou && youKey != null
            ? KeyedSubtree(key: youKey, child: child)
            : child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [
            leaderboardGold.withValues(alpha: 0.13),
            leaderboardGold.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, layout.space(6), 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            place(1, 10),
            const SizedBox(width: 8),
            place(0, 11),
            const SizedBox(width: 8),
            place(2, 10),
          ],
        ),
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.place,
    required this.period,
    required this.gameId,
    required this.isYou,
    required this.onTap,
  });

  final LeaderboardEntry entry;

  /// 1, 2 or 3: sets the medal colour and step height.
  final int place;
  final LeaderboardPeriod period;
  final String gameId;
  final bool isYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final textTheme = Theme.of(context).textTheme;
    final first = place == 1;
    final medal = podiumColor(place)!;
    final badges = leaderboardBadgesFor(entry, period: period, gameId: gameId);
    final time = AppStrings.formatPlayTime(entry.timeSeconds);
    final days = period == LeaderboardPeriod.weekly
        ? AppStrings.leaderboardDaysShort(entry.daysCleared ?? 0)
        : null;
    final label = [
      AppStrings.leaderboardPodiumSemantics(entry.rank, entry.displayName, time),
      ?days,
      if (isYou) AppStrings.youLabel,
      for (final badge in badges) leaderboardBadgeSemantics(badge, entry),
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (first)
              AppIcon(
                AppIcons.crown,
                size: layout.space(20),
                color: leaderboardGold,
              ),
            SizedBox(height: layout.space(3)),
            Container(
              padding: EdgeInsets.all(first ? 2.5 : 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medal,
                boxShadow: first
                    ? [
                        BoxShadow(
                          color: leaderboardGold.withValues(alpha: 0.35),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: UserAvatar(
                displayName: entry.displayName,
                photoUrl: entry.photoUrl,
                avatarId: entry.avatarId,
                radius: layout.space(first ? 26 : 21),
                tintSeed: entry.uid,
              ),
            ),
            SizedBox(height: layout.space(6)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: isYou ? ZipColors.ember : ZipColors.onInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  LeaderboardBadgeIcons(
                    entry: entry,
                    badges: badges,
                    size: 13,
                    showStreakCount: first,
                  ),
                ],
              ],
            ),
            if (isYou)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: LeaderboardYouPill(),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                maxLines: 1,
                style: textTheme.titleSmall?.copyWith(
                  color: first
                      ? leaderboardGold
                      : ZipColors.onInk.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: first ? 16 : 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (days != null)
              Text(
                days,
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
            SizedBox(height: layout.space(6)),
            Container(
              height: layout.space(switch (place) {
                1 => 60,
                2 => 44,
                _ => 32,
              }),
              width: double.infinity,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: layout.space(first ? 8 : 6)),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    medal.withValues(alpha: first ? 0.28 : 0.2),
                    ZipColors.wall.withValues(alpha: 0.92),
                  ],
                ),
              ),
              child: MedalCoin(rank: entry.rank, size: layout.space(22)),
            ),
          ],
        ),
      ),
    );
  }
}
```

The `?days` null-aware element needs Dart ≥ 3.8. Check `pubspec.yaml`'s `sdk:` constraint. If it's lower, use `if (days != null) days` instead.

- [ ] **Step 4:** Run `flutter test test/features/leaderboard/view/widgets/leaderboard_podium_test.dart`. Expected: PASS. Commit: `feat(leaderboard): podium for the top three`.

### Task 11: Board view, screen wiring, scroll maths, pinned "behind"

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_board_view.dart`
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart`
- Modify tests: `test/features/leaderboard/view/leaderboard_screen_area_c_test.dart` (lines 203–219, 241–256), `test/features/leaderboard/view/leaderboard_screen_test.dart`

- [ ] **Step 1: Write and update the failing screen tests**

In `leaderboard_screen_area_c_test.dart`, rename `'a 390×800 phone shows at least nine rows'` to `'a 390×800 phone shows the podium and the first rows'`, and assert:

```dart
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    // Above the 88px nav dock.
    expect(tester.getRect(find.text('Player 7')).bottom, lessThan(800 - 88));
```

In `'This week shows days and total columns'`, add three entries ahead of `_bo` so it lands in the table (rank 4). Before `board.add([_bo])`, define:

```dart
    LeaderboardEntry top(int rank) => LeaderboardEntry(
      uid: 't$rank',
      displayName: 'Top $rank',
      timeSeconds: 100 + rank,
      updatedAt: DateTime.utc(2026, 10, 15),
      rank: rank,
      daysCleared: 7,
    );
```

Then call `board.add([top(1), top(2), top(3), _bo]);`. Keep the column, `'5'` and `'6:12'` expectations. Add `expect(find.text(AppStrings.leaderboardDaysShort(7)), findsNWidgets(3));`.

In `leaderboard_screen_test.dart`, add after `'user at rank 20 shows pinned user tile at bottom'`:

```dart
  testWidgets('the pinned row says how far you are behind the next rank', (
    tester,
  ) async {
    // Same setup as 'user at rank 20 shows pinned user tile at bottom'.
    …
    expect(
      find.text(AppStrings.leaderboardBehind(<gap>, 19)),
      findsOneWidget,
    );
  });
```

Fill in the setup by copying the rank-20 test's pump code (lines 291–344) verbatim. Compute `<gap>` with `AppStrings.formatPlayTime(entries[19].timeSeconds - entries[18].timeSeconds)` from that test's entry list. If the gap is 0 there, give the user entry a time 5s slower.

- [ ] **Step 2:** Run both files. Expected: the new and changed tests FAIL.

- [ ] **Step 3: Create `leaderboard_board_view.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_layout.dart';
import 'leaderboard_badges.dart';
import 'leaderboard_podium.dart';
import 'leaderboard_table.dart';

/// The board: the podium and its badge key, then everyone else in the table
/// card, all in one scroll. The screen pins your row over it.
class LeaderboardBoardView extends StatelessWidget {
  const LeaderboardBoardView({
    super.key,
    required this.entries,
    required this.period,
    required this.gameId,
    required this.currentUid,
    required this.controller,
    required this.listKey,
    required this.headKey,
    required this.userKey,
    required this.bottomPadding,
    required this.onTapEntry,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final String gameId;
  final String? currentUid;
  final ScrollController controller;

  /// On the scroll view; the screen measures your row against it.
  final Key listKey;

  /// On the podium and key; its height is where the rows start.
  final GlobalKey headKey;

  /// On your podium place or row.
  final GlobalKey userKey;

  /// Room under the last row for the pinned row and the sign-in button.
  final double bottomPadding;
  final ValueChanged<LeaderboardEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final rest = entries.skip(leaderboardPodiumSize).toList();
    final leader = entries.first;
    final badges = {
      for (final entry in entries)
        ...leaderboardBadgesFor(entry, period: period, gameId: gameId),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: CustomScrollView(
          key: listKey,
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: headKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LeaderboardPodium(
                      entries: entries,
                      period: period,
                      gameId: gameId,
                      currentUid: currentUid,
                      youKey: userKey,
                      onTap: onTapEntry,
                    ),
                    if (badges.isEmpty)
                      const SizedBox(height: 10)
                    else
                      LeaderboardBadgeKey(badges: badges),
                  ],
                ),
              ),
            ),
            if (rest.isNotEmpty)
              DecoratedSliver(
                decoration: leaderboardTableDecoration(),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (period == LeaderboardPeriod.weekly)
                      SliverToBoxAdapter(
                        child: LeaderboardTableHeader(period: period),
                      ),
                    SliverFixedExtentList(
                      itemExtent: leaderboardTableRowHeight,
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final entry = rest[i];
                          final isYou = entry.uid == currentUid;
                          return LeaderboardTableRow(
                            key: isYou ? userKey : null,
                            entry: entry,
                            period: period,
                            gameId: gameId,
                            isYou: isYou,
                            showDivider: i < rest.length - 1,
                            gapSeconds: leaderboardGapSeconds(
                              entry: entry,
                              ahead: leader,
                              period: period,
                            ),
                            onTap: () => onTapEntry(entry),
                          );
                        },
                        childCount: rest.length,
                      ),
                    ),
                  ],
                ),
              ),
            SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the screen** (`leaderboard_screen.dart`)

Add the imports `../logic/board_layout.dart` and `widgets/leaderboard_board_view.dart`, and the field `final GlobalKey _boardHeadKey = GlobalKey();` after `_listKey`.

Add this method above `_isUserReached`:

```dart
  /// Where your row starts in the board's scroll view.
  double _userTop(int userIndex) {
    final head = _boardHeadKey.currentContext?.findRenderObject();
    final headHeight = head is RenderBox && head.hasSize
        ? head.size.height
        : 0.0;
    final weekly =
        context.read<LeaderboardCubit>().state.period ==
        LeaderboardPeriod.weekly;
    return leaderboardEntryTop(
      index: userIndex,
      headExtent: headHeight + (weekly ? leaderboardTableHeaderHeight : 0),
      rowExtent: leaderboardTableRowHeight,
    );
  }
```

In `_isUserReached`, set `final userItemTop = _userTop(userIndex);`. In `_scrollToUser`, set `final targetOffset = (_userTop(userIndex) - 100.0).clamp(`.

Replace the whole `Padding(… child: LeaderboardTableCard(…))` child of the `Stack` (lines 645–714) with:

```dart
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      bottomGap,
                                    ),
                                    child:
                                        NotificationListener<
                                          ScrollNotification
                                        >(
                                          onNotification: (_) {
                                            _onBoardScrolled(layout, userIndex);
                                            return false;
                                          },
                                          child: LeaderboardBoardView(
                                            listKey: _listKey,
                                            headKey: _boardHeadKey,
                                            userKey: _userRowKey,
                                            controller: _scrollController,
                                            entries: state.entries,
                                            period: state.period,
                                            gameId: state.gameId,
                                            currentUid: state.currentUid,
                                            // Kept while the pin can show, so
                                            // hiding it doesn't move the rows.
                                            bottomPadding:
                                                (userEntry != null &&
                                                        !inInitialList
                                                    ? 64.0
                                                    : 0.0) +
                                                (showSignInFab ? 80.0 : 0.0),
                                            onTapEntry: (entry) =>
                                                showPlayerCardSheet(
                                                  context,
                                                  entry: entry,
                                                  gameId: state.gameId,
                                                  period: state.period,
                                                  isYou:
                                                      entry.uid ==
                                                      state.currentUid,
                                                ),
                                          ),
                                        ),
                                  ),
```

Pass a `subtitle` to `_PinnedUserRow`. Before `return Stack(`, compute:

```dart
                              final ahead = userIndex > 0
                                  ? state.entries[userIndex - 1]
                                  : null;
                              final behindSeconds = ahead == null
                                  ? null
                                  : leaderboardGapSeconds(
                                      entry: userEntry!,
                                      ahead: ahead,
                                      period: state.period,
                                    );
```

Then call `_PinnedUserRow(…, subtitle: behindSeconds == null ? null : AppStrings.leaderboardBehind(AppStrings.formatPlayTime(behindSeconds), ahead!.rank), …)`. Add `final String? subtitle;` to `_PinnedUserRow` and forward it to its `LeaderboardTableRow(subtitle: subtitle)`. `userEntry!` is safe here: `ahead` is only non-null when `userIndex > 0`, which means the entry was found.

Delete `LeaderboardTableCard` from `leaderboard_table.dart` if nothing else references it (`grep -rn LeaderboardTableCard lib test`).

- [ ] **Step 5:** Run `flutter test test/features/leaderboard`. Expected: PASS. If `'user at rank 20 …'` or `'scrolling down to user rank 20 hides pinned tile'` fail, the row-offset maths is wrong: check `_userTop` against the podium's measured height. Don't loosen the tests.
- [ ] **Step 6:** Commit: `feat(leaderboard): podium board with gaps and a behind line on your row`.

### Task 12: Shimmer

**Files:** Modify `lib/features/leaderboard/view/widgets/leaderboard_shimmer.dart`; Test `test/features/leaderboard/view/widgets/leaderboard_shimmer_test.dart`

- [ ] **Step 1:** In the test, change the expectation to `expect(find.byType(AppShimmerCircle), findsNWidgets(3 + 3));`, i.e. three podium places plus three rows. Run it. Expected: FAIL (3 found).

- [ ] **Step 2: Implement.** Replace the `build` body of `LeaderboardShimmer`:

```dart
  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    Widget place(int flex, double radius, double step) => Expanded(
      flex: flex,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppShimmerCircle(radius: layout.space(radius)),
          const SizedBox(height: 8),
          const AppShimmerBox(width: 56, height: 10, borderRadius: 4),
          const SizedBox(height: 6),
          const AppShimmerBox(width: 36, height: 12, borderRadius: 4),
          const SizedBox(height: 8),
          AppShimmerBox(
            width: double.infinity,
            height: layout.space(step),
            borderRadius: 10,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppShimmer(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, layout.space(6) + 23, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        place(10, 23, 44),
                        const SizedBox(width: 8),
                        place(11, 28.5, 60),
                        const SizedBox(width: 8),
                        place(10, 23, 32),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: leaderboardTableDecoration(),
                  child: AppShimmer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < rowCount; i++)
                          const _LeaderboardRowShimmer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- Default `rowCount` becomes 6.
- Update the class doc to "Skeleton of the board: a three-step podium over [rowCount] rows shaped like [LeaderboardTableRow]".
- Update `_LeaderboardRowShimmer`'s comment to "52px".
- Add the import `../../../../core/theme/app_layout.dart`.

- [ ] **Step 3:** Run `flutter test test/features/leaderboard/view/widgets/leaderboard_shimmer_test.dart test/features/leaderboard/view/leaderboard_screen_test.dart`. Expected: PASS. Commit: `feat(leaderboard): podium-shaped loading skeleton`.

### Task 13: Verify, screenshots, docs, push

- [ ] **Step 1:** `flutter analyze`. Expected: `No issues found!`
- [ ] **Step 2:** `flutter test`. Expected: all pass. Record the count.
- [ ] **Step 3:** `WINKLO_SCREENSHOTS=1 flutter test test/features/leaderboard/view/leaderboard_screenshots_test.dart`, then look at every PNG in `build/screenshots/leaderboard_*`. Check:
  - real Phosphor glyphs, not boxes
  - podium centred
  - no overflow stripes at 360×640
  - the key shows on daily and not on weekly
  - the "behind" line on the pinned row
- [ ] **Step 4:** Also render Profile and badges: `WINKLO_SCREENSHOTS=1 flutter test test/features/profile/view/profile_screenshots_test.dart` (or whichever screenshot tests exist: `ls test/**/*screenshots_test.dart`). Look at them for broken glyphs.
- [ ] **Step 5:** README. In the leaderboard section of the feature list, describe:
  - the podium, gaps and key
  - Phosphor duotone icons across the app via `AppIcons`/`AppIcon`
  - "Malayalam: 4 new leaderboard strings need native review"

  Commit `docs: README for the leaderboard podium and Phosphor icons`.
- [ ] **Step 6:** Check `git status` for stray format or lock changes, then `git push -u origin feat/leaderboard-podium`.
