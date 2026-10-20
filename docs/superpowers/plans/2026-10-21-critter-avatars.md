# Critter Avatars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the six blob presets with 12 bundled critter SVGs, and turn the avatar sheet into a header plus a big-tile grid where a tap saves (spec: `docs/superpowers/specs/2026-10-21-critter-avatars-design.md`).

**Architecture:** `AvatarCatalog` (domain, pure Dart) maps the existing `preset_XX` ids to an `AvatarCritter` enum and an asset path. `UserAvatar` draws a preset as a bundled SVG through `AppImage.asset`, so every avatar call site picks up the new art. The sheet keeps `ProfileCubit.selectPreset` and the photo flow as they are. The only new state is UI-local: which tile a save is pending for.

**Tech Stack:** Flutter, flutter_svg (already a dependency, via `AppImage`), flutter_bloc, mocktail, headless Chrome for exporting PNGs for old builds.

---

## File map

| File | Change |
|---|---|
| `assets/avatars/{fox,cat,owl,frog,panda,bunny,penguin,tiger,koala,bear,raccoon,chick}.svg` | new art (100×100, full-bleed square) |
| `pubspec.yaml` | `- assets/avatars/` |
| `lib/domain/avatars/avatar_catalog.dart` | enum, id→critter map, `assetFor`, `critterFor`; drop `imageUrlFor` |
| `lib/core/widgets/user_avatar.dart` | preset → bundled SVG |
| `lib/core/strings/app_text*.dart`, `app_strings.dart` | 12 critter names, `profileAvatarPhoto`, `profileAvatarHint`; drop `profilePresets` |
| `lib/core/strings/avatar_critter_name.dart` | `avatarCritterName(AvatarCritter)` |
| `lib/features/profile/view/widgets/avatar_edit_sheet.dart` | L2 layout (stateful for the pending tile) |
| `tools/static-assets/avatars/preset_XX.png` (×12) + `export_avatar_pngs.sh` + README | PNGs for old builds |
| tests | catalog, assets, user_avatar, sheet, app_text, screenshots |

Commands run from the worktree root `.worktrees/critter-avatars`. Format only the files you touched (`dart format <paths>`). Restore `pubspec.lock` before committing if `flutter pub get` changed it.

---

### Task 1: Critter art as bundled SVGs

**Files:**
- Create: `assets/avatars/*.svg` (12)
- Modify: `pubspec.yaml` (assets list)
- Create: `test/domain/avatars/avatar_art_test.dart`
- Delete: `test/domain/avatars/avatar_preset_assets_test.dart` (replaced in Task 5)

- [ ] **Step 1: Write the failing asset test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('every critter has a 100×100 SVG listed in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/avatars/'));
    for (final critter in AvatarCritter.values) {
      final file = File('assets/avatars/${critter.name}.svg');
      expect(file.existsSync(), isTrue, reason: file.path);
      final svg = file.readAsStringSync();
      expect(svg, contains('viewBox="0 0 100 100"'), reason: file.path);
      expect(svg, contains('xmlns="http://www.w3.org/2000/svg"'));
    }
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/domain/avatars/avatar_art_test.dart`. Expected: compile FAIL (`AvatarCritter` undefined). It goes green after Task 2.

- [ ] **Step 3: Draw the 12 SVGs.** Start from the approved mock symbols `b1`–`b12` in `.superpowers/brainstorm/34434-1792531277/content/sheet-layout.html` (fox=b1, cat=b2, owl=b3, frog=b4, panda=b5, bunny=b6, penguin=b7, tiger=b8, koala=b9, bear=b10, raccoon=b11, chick=b12). Each file is `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">`, first child `<rect width="100" height="100" fill="<bg>"/>`. Polish so they read as one set:
  - eyes are ink `#0F172A`, about r 4, with a white highlight r 1.3–2.2 up and to the right;
  - eye line at y 51–60;
  - strokes 2.2–3.4 with round caps and joins;
  - nothing important outside the inscribed circle (r 50).

  flutter_svg supports everything used: `rect`, `circle`, `ellipse`, `path`, `g`, `transform="rotate()"`, `fill-opacity`, `opacity`.

- [ ] **Step 4: Register the assets.** In `pubspec.yaml` under `assets:` after `- assets/branding/`, add:

```yaml
    # Preset avatars (critters), drawn by UserAvatar.
    - assets/avatars/
```

- [ ] **Step 5: Commit** (after Task 2 makes the test compile): `git add assets/avatars pubspec.yaml test/domain/avatars/avatar_art_test.dart`.

### Task 2: Catalog + UserAvatar draw the critters

**Files:**
- Modify: `lib/domain/avatars/avatar_catalog.dart`
- Modify: `lib/core/widgets/user_avatar.dart`
- Test: `test/domain/avatars/avatar_catalog_test.dart`, `test/core/widgets/user_avatar_test.dart`

- [ ] **Step 1: Write the failing catalog tests** (replace the file):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('12 presets, each critter exactly once', () {
    expect(AvatarCatalog.presetIds, hasLength(12));
    expect(AvatarCatalog.presetIds.toSet(), hasLength(12));
    expect(
      AvatarCatalog.presets.values.toSet(),
      AvatarCritter.values.toSet(),
    );
  });

  test('the original six ids keep working, as related critters', () {
    expect(AvatarCatalog.critterFor('preset_01'), AvatarCritter.fox);
    expect(AvatarCatalog.critterFor('preset_02'), AvatarCritter.panda);
    expect(AvatarCatalog.critterFor('preset_03'), AvatarCritter.cat);
    expect(AvatarCatalog.critterFor('preset_04'), AvatarCritter.bear);
    expect(AvatarCatalog.critterFor('preset_05'), AvatarCritter.owl);
    expect(AvatarCatalog.critterFor('preset_06'), AvatarCritter.bunny);
  });

  test('picker order starts fox, cat, owl', () {
    expect(AvatarCatalog.presetIds.take(3), [
      'preset_01',
      'preset_03',
      'preset_05',
    ]);
  });

  test('asset path for known ids, null otherwise', () {
    expect(AvatarCatalog.assetFor('preset_09'), 'assets/avatars/tiger.svg');
    expect(AvatarCatalog.assetFor('nope'), isNull);
    expect(AvatarCatalog.assetFor(null), isNull);
    expect(AvatarCatalog.critterFor('nope'), isNull);
    expect(AvatarCatalog.isPresetId('preset_12'), isTrue);
    expect(AvatarCatalog.isPresetId('preset_13'), isFalse);
  });
}
```

- [ ] **Step 2: Run them.** `flutter test test/domain/avatars/`. Expected: compile FAIL.

- [ ] **Step 3: Implement the catalog** (replace the file):

```dart
/// The critters a player can pick as their avatar.
enum AvatarCritter {
  fox,
  cat,
  owl,
  frog,
  panda,
  bunny,
  penguin,
  tiger,
  koala,
  bear,
  raccoon,
  chick,
}

abstract final class AvatarCatalog {
  /// Preset id → critter, in picker order. Ids 01–06 are the original
  /// presets, redrawn as the critter nearest the old art, so players who
  /// picked one keep a related face; ids are stored in profiles and
  /// leaderboard rows and never change.
  static const presets = <String, AvatarCritter>{
    'preset_01': AvatarCritter.fox,
    'preset_03': AvatarCritter.cat,
    'preset_05': AvatarCritter.owl,
    'preset_07': AvatarCritter.frog,
    'preset_02': AvatarCritter.panda,
    'preset_06': AvatarCritter.bunny,
    'preset_08': AvatarCritter.penguin,
    'preset_09': AvatarCritter.tiger,
    'preset_10': AvatarCritter.koala,
    'preset_04': AvatarCritter.bear,
    'preset_11': AvatarCritter.raccoon,
    'preset_12': AvatarCritter.chick,
  };

  static Iterable<String> get presetIds => presets.keys;

  static AvatarCritter? critterFor(String? avatarId) => presets[avatarId];

  /// Bundled SVG for a preset, or null if [avatarId] isn't one.
  static String? assetFor(String? avatarId) {
    final critter = critterFor(avatarId);
    return critter == null ? null : 'assets/avatars/${critter.name}.svg';
  }

  static bool isPresetId(String id) => presets.containsKey(id);
}
```

- [ ] **Step 4: Update the UserAvatar tests** (replace the second test, then add one):

```dart
  testWidgets('draws a preset as its bundled critter, over photoUrl', (
    tester,
  ) async {
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
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('an unknown preset id falls back to initials', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: UserAvatar(displayName: 'Ada', avatarId: 'gone', radius: 20),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });
```

(add imports `package:cached_network_image/cached_network_image.dart` and `package:flutter_svg/flutter_svg.dart`.)

- [ ] **Step 5: Implement it in UserAvatar.** Replace the `presetUrl` branch:

```dart
    final presetAsset = AvatarCatalog.assetFor(avatarId);
    if (presetAsset != null) {
      // Bundled, so no spinner; initials only if the asset can't be read.
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZipColors.mistDeep,
        child: ClipOval(
          child: AppImage.asset(
            presetAsset,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: Center(child: _initials),
          ),
        ),
      );
    }
```

- [ ] **Step 6: Run the tests.** `flutter test test/domain/avatars test/core/widgets/user_avatar_test.dart`. Expected: PASS. The old `avatar_preset_assets_test.dart` references `imageUrlFor`, so delete it now (Task 5 replaces it).

- [ ] **Step 7: Commit** Tasks 1 and 2 together: `feat(avatars): 12 bundled critter presets drawn by UserAvatar`.

### Task 3: Strings + critter names

**Files:**
- Modify: `lib/core/strings/app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`, `app_strings.dart`
- Create: `lib/core/strings/avatar_critter_name.dart`
- Test: `test/core/strings/app_text_test.dart` (`_members` table), new `test/core/strings/avatar_critter_name_test.dart`

- [ ] **Step 1: Failing test for names**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/avatar_critter_name.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('every critter has a distinct, non-empty name', () {
    final names = AvatarCritter.values.map(avatarCritterName).toList();
    expect(names.every((n) => n.isNotEmpty), isTrue);
    expect(names.toSet(), hasLength(AvatarCritter.values.length));
    expect(avatarCritterName(AvatarCritter.fox), 'Fox');
  });
}
```

- [ ] **Step 2: Add the members.** In `app_text.dart`, replace `String get profilePresets;` with:

```dart
  String get profileAvatarHint;
  String get profileAvatarPhoto;
  String get avatarCritterFox;
  String get avatarCritterCat;
  String get avatarCritterOwl;
  String get avatarCritterFrog;
  String get avatarCritterPanda;
  String get avatarCritterBunny;
  String get avatarCritterPenguin;
  String get avatarCritterTiger;
  String get avatarCritterKoala;
  String get avatarCritterBear;
  String get avatarCritterRaccoon;
  String get avatarCritterChick;
```

English: 'Tap a critter to switch', 'Photo', Fox, Cat, Owl, Frog, Panda, Bunny, Penguin, Tiger, Koala, Bear, Raccoon, Chick.

Malayalam: 'മാറ്റാൻ ഒന്നിൽ തൊടൂ', 'ഫോട്ടോ', കുറുക്കൻ, പൂച്ച, മൂങ്ങ, തവള, പാണ്ട, മുയൽ, പെൻഗ്വിൻ, കടുവ, കോവാല, കരടി, റാക്കൂൺ, കോഴിക്കുഞ്ഞ്.

`app_strings.dart` gets matching `static String get … => _t.…;` lines. `app_text_test.dart`'s `_members` gets each new key, and `'profilePresets'` is removed.

- [ ] **Step 3: Name helper**

```dart
import '../../domain/avatars/avatar_catalog.dart';
import 'app_strings.dart';

/// [critter]'s name in the current language, e.g. for a screen reader.
String avatarCritterName(AvatarCritter critter) => switch (critter) {
  AvatarCritter.fox => AppStrings.avatarCritterFox,
  AvatarCritter.cat => AppStrings.avatarCritterCat,
  AvatarCritter.owl => AppStrings.avatarCritterOwl,
  AvatarCritter.frog => AppStrings.avatarCritterFrog,
  AvatarCritter.panda => AppStrings.avatarCritterPanda,
  AvatarCritter.bunny => AppStrings.avatarCritterBunny,
  AvatarCritter.penguin => AppStrings.avatarCritterPenguin,
  AvatarCritter.tiger => AppStrings.avatarCritterTiger,
  AvatarCritter.koala => AppStrings.avatarCritterKoala,
  AvatarCritter.bear => AppStrings.avatarCritterBear,
  AvatarCritter.raccoon => AppStrings.avatarCritterRaccoon,
  AvatarCritter.chick => AppStrings.avatarCritterChick,
};
```

- [ ] **Step 4: Run.** `flutter test test/core/strings`. Expected: PASS. (The sheet still uses `profilePresets` until Task 4, so do Tasks 3 and 4 before running `flutter analyze`.)

### Task 4: The L2 sheet

**Files:**
- Modify: `lib/features/profile/view/widgets/avatar_edit_sheet.dart`
- Test: `test/features/profile/view/widgets/avatar_edit_sheet_test.dart`

Layout (spec § sheet):
- `Semantics(namesRoute, scopesRoute, label: profileEditAvatar)` wrapping a `Column`:
  - grab handle;
  - `_SheetHeader`: a 52 dp current avatar with an ember ring, name over the hint, and the Photo pill;
  - `_CritterGrid`, using a `LayoutBuilder`: 3 columns, 12 dp column gap, 16 dp row gap, tile = min(84, cell − 12);
  - error text.
- The sheet becomes a `StatefulWidget` holding `_pendingId`. It's set on a tile tap and cleared when a photo pick starts.
- The tile ring goes to `isSaving && _pendingId != null ? _pendingId : selectedId`. The badge is a spinner on the pending tile and a check otherwise.
- Tiles carry `ValueKey('avatar-preset-$id')` and `Semantics(button, selected, enabled, label: avatarCritterName)`. The InkWell sits on top of the art in a `Stack` so the splash shows.

- [ ] **Step 1: Update the tests first.**
  - `'shows a tile for each preset id'`: look for `find.byKey(ValueKey('avatar-preset-$id'))` for each id.
  - The overflow test: look for `AppStrings.profileAvatarHint` and `AppStrings.profileAvatarPhoto`. Run it at 320×568, 360×640 and 390×844 (loop).
  - The photo test: tap `find.text(AppStrings.profileAvatarPhoto)`.
  - Add `'tapping a critter saves it'`: tap the tiger key, then `verify(() => profile.updateAvatarPreset('preset_09')).called(1)` (stub returns `user.copyWith(avatarId: 'preset_09')` via a Completer so the saving state can be checked first).
  - Add `'while saving, tiles are disabled and the tapped one spins'`: there's a `CircularProgressIndicator` inside the tiger tile, and a second tap on fox doesn't call the repository.
  - Add `'selected critter is marked for screen readers'`: `tester.getSemantics(find.byKey(ValueKey('avatar-preset-preset_01')))` has the selected flag (`SemanticsFlag.isSelected`).

- [ ] **Step 2: Run them.** Expected: FAIL (keys and strings not found).

- [ ] **Step 3: Implement** (see the final file in the commit). The behaviour is fixed by the tests above. `_pickPhoto` and `_isPermissionDenied` move into the State unchanged.

- [ ] **Step 4: Run.** `flutter test test/features/profile`. Expected: PASS. Then `flutter analyze lib test`. Expected: no new issues (11 info hints already exist).

- [ ] **Step 5: Commit** Tasks 3 and 4: `feat(profile): avatar sheet as a big critter grid with a photo pill`.

### Task 5: PNGs for old builds

**Files:**
- Create: `tools/static-assets/export_avatar_pngs.sh`
- Modify: `tools/static-assets/avatars/preset_01..06.png`, create `preset_07..12.png`
- Modify: `tools/static-assets/README.md`
- Create: `test/domain/avatars/avatar_png_export_test.dart`

- [ ] **Step 1: Failing test.** For every id in `AvatarCatalog.presetIds`, `tools/static-assets/avatars/$id.png` exists. Its PNG IHDR (bytes 16–23) gives 512×512. It's larger than 4 KiB, since critters aren't flat blobs.

- [ ] **Step 2: Script.** It takes each id → critter from a fixed list (kept in sync by the test), wraps the SVG in `<html><body style="margin:0"><img src="…svg" width=512 height=512>`, and runs headless Chrome with `--screenshot --window-size=512,512` and a 40 s watchdog. Chrome 155 can hang, so the script kills it by its profile dir.

- [ ] **Step 3: Run it** (outside the command sandbox), then the test. Expected: PASS.

- [ ] **Step 4: README.** Explain that the PNGs exist only for app builds older than critter avatars, that `export_avatar_pngs.sh` regenerates them, and that they're uploaded with the existing loop.

- [ ] **Step 5: Commit:** `chore(avatars): critter PNGs on the old R2 keys for older builds`.

### Task 6: Screenshots and visual check

**Files:**
- Create: `test/features/profile/view/avatar_sheet_screenshots_test.dart`

- [ ] **Step 1:** Pump the sheet in a `RepaintBoundary` at 360×740 and 392×850, plus Malayalam at 360. Use the same font setup as `profile_screenshots_test.dart` (`loadScreenshotFonts`, `GoogleFonts.config.allowRuntimeFetching = false`). Let the SVGs decode with `await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)))` and then `pump`. Assert there's no overflow, then call `saveScreenshot`.
- [ ] **Step 2:** Add a leaderboard table case: a `LeaderboardTable` with 6 entries using presets, at 360 wide. Save the screenshot.
- [ ] **Step 3:** Run with `WINKLO_SCREENSHOTS=1` and look at the PNGs. Fix spacing and art issues. Re-run.
- [ ] **Step 4: Commit:** `test(profile): screenshots of the critter picker`.

### Task 7: Wrap-up

- [ ] Run `dart format` on the touched files only, `flutter analyze` (no new issues), and the full `flutter test`. Compare failures against the 11 known on master.
- [ ] README: add the branch entry to "Ready to merge", listing 14 new Malayalam strings for native review and the R2 upload step.
- [ ] Restore `pubspec.lock` if it changed, then `git push -u origin feat/critter-avatars`.
