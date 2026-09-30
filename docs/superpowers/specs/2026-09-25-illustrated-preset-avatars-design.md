# Illustrated preset avatars (mascot blobs)

**Date:** 2026-09-25  
**Status:** Approved  
**Approach:** Asset-only swap — replace solid-color PNGs with abstract mascot-blob illustrations

## Problem

The Edit avatar sheet’s “Presets” grid shows six blank color circles. Those are intentional bundled assets (`assets/avatars/preset_01.png` … `preset_06.png`), but each file is a flat solid color, so presets feel unfinished next to photo upload.

## Goals

- Replace the six preset PNGs with cute abstract mascot-blob illustrations.
- Keep existing `avatarId` values (`preset_01` … `preset_06`) so stored profiles and leaderboard denormalization keep working.
- Stay readable when cropped to a circle at ~56px (edit sheet) and smaller (leaderboard rows).

## Non-goals (v1)

- Dart / Flutter code changes (`AvatarCatalog`, `UserAvatar`, `AvatarEditSheet`).
- New preset IDs or expanding beyond six.
- Sheet layout / selection-ring polish.
- Changing photo-upload flow.
- Animations or SVG presets.

## Art direction

Style: **cute game creatures → abstract mascot blobs** (not animals, not human portraits).

Common rules:

- Flat shapes, bold dark-ink eyes/mouths.
- Each blob sits on a **dark slate disc** (`ZipColors.wall` / ink family) so it works on the dark app canvas.
- No text, logos, or fine detail that disappears at small sizes.
- Circle-safe: face/expression stays inside the circular crop.
- Opaque PNG, square canvas (~512×512).

| Asset | Color | Expression |
|---|---|---|
| `preset_01.png` | Ember (`#FF6B2C`) | Open smile |
| `preset_02.png` | Sky (`#38BDF8`) | Wink |
| `preset_03.png` | Lavender (`#A78BFA`) | Soft / shy |
| `preset_04.png` | Mint (`#2DD4BF`) | Cheeky (tiny ears OK) |
| `preset_05.png` | Gold (`#FBBF24`) | Sleepy eyes |
| `preset_06.png` | Rose (`#FB7185`) | Surprised O-mouth |

## Technical delivery

1. Generate six illustrations matching the table above.
2. Overwrite in place:
   - `assets/avatars/preset_01.png`
   - `assets/avatars/preset_02.png`
   - `assets/avatars/preset_03.png`
   - `assets/avatars/preset_04.png`
   - `assets/avatars/preset_05.png`
   - `assets/avatars/preset_06.png`
3. Do **not** change `pubspec.yaml` asset declarations if `assets/avatars/` is already included.
4. Do **not** change `AvatarCatalog.presetIds` or `assetPathFor`.

Existing path (unchanged):

```
avatarId (e.g. preset_01)
  → AvatarCatalog.assetPathFor → assets/avatars/preset_01.png
  → UserAvatar / AppImage.asset
  → Profile, Edit avatar sheet, Leaderboard
```

## Acceptance

- Edit avatar → Presets shows six distinct blob characters (not solid colors).
- Selecting a preset still persists `avatarId` and updates the profile avatar.
- Leaderboard / other `UserAvatar` call sites show the same art for that `avatarId`.
- Hot restart (or full restart) picks up the new asset bytes.

## Out of scope follow-ups

- Extra presets or seasonal sets.
- Vector (SVG) presets.
- Slight sheet polish (tile size, glow) if art alone isn’t enough.
