# Critter avatars: redesigned presets and picker

Date: 2026-10-21 · Branch: `feat/critter-avatars` (from `origin/master` `1deaba5`)

## Problem

The six preset avatars (Profile → Edit avatar) looked like placeholders:

- **Art.** Flat blobs with dot eyes, some circles and some ovals, with no shared style.
- **Floating.** The PNGs' background is `#1E293B`, the same as the sheet (`ZipColors.wall`). Each 56 dp avatar sat in a ~107 dp outlined ring, so you saw a small blob in empty space.
- **Sheet.** A plain "Presets" label, a 3×2 grid, and a loud orange "Choose from photos" button.
- **Count.** Six was too few, and many players shared a face on the leaderboard.

The user flagged all four in the visual companion.

## Decisions (made with the user)

- **Art direction: B "Critters".** Geometric, flat animal heads on deep tinted backgrounds that fill the circle. There are 12: fox, cat, owl, frog, panda, bunny, penguin, tiger, koala, bear, raccoon, chick.
- **Picker: L2 "Big tiles, tap to save".** A compact header shows your current avatar, your name, "Tap a critter to switch" and a Photo pill. Below it is a 3-column grid of 84 dp critters. A tap saves straight away, as before.
- **Shipping: bundled SVGs, existing ids kept.** Rejected: PNGs on R2 (network fetch, year-long cache) and readable ids like `critter_fox` (current players would lose their avatar without an alias table).

## Ids and art

`avatarId` stays an opaque string everywhere outside the app: Firestore rules, the leaderboard Worker, denormalised board rows, and the admin panel. Ids `preset_01`…`06` are redrawn as critters, matched by colour or shape to the old art. Ids `07`…`12` are new.

| id | was | critter | body / background |
|---|---|---|---|
| `preset_01` | orange face | Fox | ember on `#4A2617` |
| `preset_02` | sky face | Panda | white on `#1E5276` |
| `preset_03` | violet face | Cat | violet on `#2E2556` |
| `preset_04` | teal face with ears | Bear | `#C2763A` on `#163044` |
| `preset_05` | amber face | Owl | amber on `#4A3510` |
| `preset_06` | rose face | Bunny | rose on `#4C1D2B` |
| `preset_07` | — | Frog | lime on `#26330F` |
| `preset_08` | — | Penguin | ink and white on `#0369A1` |
| `preset_09` | — | Tiger | `#FB923C` on `#134E4A` |
| `preset_10` | — | Koala | `#CBD5E1` on `#1F3B2D` |
| `preset_11` | — | Raccoon | slate on `#4A3510` |
| `preset_12` | — | Chick | `#FDE047` on `#2E2556` |

Picker order (gives a varied grid): fox, cat, owl, frog, panda, bunny, penguin, tiger, koala, bear, raccoon, chick.

The art is twelve 100×100 SVGs in `assets/avatars/<critter>.svg`. Each draws a full-bleed square background, and the circle crop happens in Flutter. All of them share one system:

- **Head:** centred at x = 50, filling about 70% of the width.
- **Eyes:** ink (`#0F172A`) with a white highlight, at y ≈ 55.
- **Strokes:** 2.2–3.4 wide with round caps and joins.

Any detail outside the inscribed circle (r = 50) gets cropped, so nothing important goes there.

## Code

### `domain/avatars/avatar_catalog.dart` (pure Dart)

- `enum AvatarCritter { fox, cat, owl, frog, panda, bunny, penguin, tiger, koala, bear, raccoon, chick }`.
- `AvatarCatalog.presets`: an ordered `Map<String, AvatarCritter>` from id to critter, in picker order.
- `AvatarCatalog.presetIds`: its keys.
- `critterFor(String? id)` returns an `AvatarCritter?`.
- `isPresetId(String id)` is unchanged; `UpdateAvatar.preset` uses it.
- `assetFor(String? id)` returns `assets/avatars/<critter>.svg`, or null.
- `imageUrlFor` and the R2 dependency are removed. Nothing else in the app used them.

### `core/widgets/user_avatar.dart`

A preset id renders `AppImage.asset(svg)`, clipped to a circle at `radius * 2`. Its `errorWidget` is the initials and it has no spinner placeholder, because the asset is bundled. The photo and initials branches are unchanged.

### Critter names

The domain mustn't import strings, so names live in a helper, `core/strings/avatar_critter_name.dart`. `avatarCritterName(AvatarCritter)` switches over the enum to return the `AppStrings.avatarCritter*` getters.

### `features/profile/view/widgets/avatar_edit_sheet.dart` (L2)

- **Grab handle,** as before.
- **Header row:**
  - your current avatar at 52 dp (`UserAvatar` with the profile's photo, avatarId and name), with a 2 dp ember ring;
  - your name in bold, ellipsised, with "Tap a critter to switch" below it;
  - a **Photo** pill on the right (outlined, Phosphor `images` icon). It runs the existing `_pickPhoto` flow, with the same resizing and the same permission snackbar.
- **Grid:** 3 columns of 84 dp critters, with 12 dp between columns and 16 dp between rows. Each tile:
  - full-bleed critter (no outline ring, so nothing floats);
  - **selected:** a 3 dp ember ring outside a 3 dp wall gap, an ember glow, and a check badge at bottom-right;
  - **saving:** the tile being saved shows a 2 dp spinner ring in place of the check, and every tile is disabled;
  - `Semantics(button: true, selected:, label: critter name)`;
  - tap → `ProfileCubit.selectPreset(id)` (unchanged). The sheet stays open, and the header updates when the save lands.
- **Avatar error:** the text shows under the grid.
- **Narrow screens:** the grid keeps 3 columns and the tiles shrink (`LayoutBuilder`, at most 84 dp). The sheet still scrolls on short screens.
- The old `profilePresets` label and the full-width button go. `profileChoosePhoto` stays as the Photo pill's tooltip and semantics label.

The cubit and repository are unchanged, so tap-to-save behaves exactly as before.

### Strings (en + ml)

- `avatarCritterFox` … `avatarCritterChick` (12).
- `profileAvatarPhoto` ("Photo").
- `profileAvatarHint` ("Tap a critter to switch").
- Remove `profilePresets`.

The new Malayalam strings need a native speaker's review.

### Old app versions (R2)

Old builds render a preset from `static/avatars/<id>.png` and only know ids 01–06. Critter PNGs (512 px) for all 12 ids are exported into `tools/static-assets/avatars/` under the same keys. After the user re-uploads them, old builds show critters for 01–06 once their image cache expires. They show initials for 07–12, which is acceptable. The upload is manual, as before (README in that folder).

## Testing

- **Catalog:** 12 unique ids; every critter is used exactly once; `assetFor` and `critterFor` work for known ids and return null for unknown ones; `isPresetId`.
- **Asset test** (replaces `avatar_preset_assets_test`): every critter SVG exists, is listed under `assets/avatars/` in pubspec, and has a 100×100 viewBox. Every id has a 512×512 PNG in `tools/static-assets/avatars/`.
- **`UserAvatar`:** a preset renders an `SvgPicture` and no network image, and it beats `photoUrl`. An unknown id falls back to the photo, then initials.
- **Sheet:**
  - one tile per preset;
  - the selected tile is marked in semantics;
  - a tap calls `selectPreset`;
  - while saving, the tiles are disabled and a spinner shows;
  - the Photo pill opens the picker with the same resize arguments;
  - no overflow at 320×568, 360×640 and 390×844, or in Malayalam.
- **Strings:** the `app_text_test` sample table covers the new members.
- **Screenshots** (`WINKLO_SCREENSHOTS=1`): the sheet at 360 and 392 dp, Malayalam at 360 dp, and a leaderboard table with critters.

## Out of scope

- Google account photos as an option.
- Unlockable critters.
- Animated avatars.
- Changing how photos upload.
