# Illustrated Preset Avatars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the six solid-color preset PNGs with cute abstract mascot-blob illustrations so Edit avatar presets look like real characters.

**Architecture:** Asset-only swap. A small Python (Pillow) generator script draws six flat mascot blobs to exact colors/expressions from the spec, writing square opaque PNGs over `assets/avatars/preset_0{1–6}.png`. No Dart catalog/UI changes — `AvatarCatalog` + `UserAvatar` already resolve those paths.

**Tech Stack:** Python 3 + Pillow; existing Flutter asset path `assets/avatars/`; Flutter widget tests for smoke check.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-illustrated-preset-avatars-design.md`
- **Do not** modify Dart UI/catalog (`AvatarCatalog`, `UserAvatar`, `AvatarEditSheet`) unless a bug blocks display
- Keep IDs `preset_01` … `preset_06` and filenames unchanged
- Opaque square PNG ≈ **512×512**; circle-safe; dark slate disc behind each blob
- Style: flat abstract mascot blobs (not animals, not human portraits)
- `assets/avatars/` is already declared in `pubspec.yaml` — do not add duplicate entries
- Commits only when the user asks (skip commit steps unless explicitly requested)
- Analyze with timed `dart analyze` / `flutter test` on touched paths only — never MCP `analyze_files`

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `assets/avatars/preset_01.png` … `preset_06.png` | Bundled preset art (overwrite in place) |
| `tool/generate_preset_avatars.py` | Deterministic Pillow generator for the six blobs |
| `test/domain/avatars/avatar_preset_assets_test.dart` | Assert each preset PNG exists and is large enough to be real art |
| `lib/domain/avatars/avatar_catalog.dart` | Unchanged — reference only |
| `test/core/widgets/user_avatar_test.dart` | Unchanged smoke — still finds `Image` for `preset_01` |

---

### Task 1: Failing asset integrity test

**Files:**
- Create: `test/domain/avatars/avatar_preset_assets_test.dart`
- Reference: `lib/domain/avatars/avatar_catalog.dart`

**Interfaces:**
- Consumes: `AvatarCatalog.presetIds`, `AvatarCatalog.assetPathFor`
- Produces: test that fails while presets are tiny solid-color PNGs (~300 bytes)

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';

void main() {
  test('each preset asset exists and is illustrated (not a tiny solid fill)', () {
    for (final id in AvatarCatalog.presetIds) {
      final relative = AvatarCatalog.assetPathFor(id);
      expect(relative, isNotNull, reason: id);
      final file = File(relative!);
      expect(file.existsSync(), isTrue, reason: relative);

      final bytes = file.readAsBytesSync();
      // Solid-color placeholders are ~70–300 bytes. Illustrated 512² PNGs are much larger.
      expect(
        bytes.length,
        greaterThan(8 * 1024),
        reason: '$relative looks like a placeholder (${bytes.length} bytes)',
      );

      // PNG magic
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x4E); // N
      expect(bytes[3], 0x47); // G
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/domain/avatars/avatar_preset_assets_test.dart
```

Expected: FAIL with reason containing `looks like a placeholder` (file size ≤ 8 KiB).

- [ ] **Step 3: Commit** (only if user asked)

```bash
git add test/domain/avatars/avatar_preset_assets_test.dart
git commit -m "test: require illustrated preset avatar PNGs"
```

---

### Task 2: Generator script + overwrite preset PNGs

**Files:**
- Create: `tool/generate_preset_avatars.py`
- Modify: `assets/avatars/preset_01.png`
- Modify: `assets/avatars/preset_02.png`
- Modify: `assets/avatars/preset_03.png`
- Modify: `assets/avatars/preset_04.png`
- Modify: `assets/avatars/preset_05.png`
- Modify: `assets/avatars/preset_06.png`

**Interfaces:**
- Consumes: spec color/expression table
- Produces: six 512×512 opaque PNGs at the paths above

- [ ] **Step 1: Ensure Pillow is available**

Run:

```bash
python3 -c "from PIL import Image, ImageDraw; print('ok')"
```

If that fails:

```bash
python3 -m pip install --user Pillow
```

Expected: prints `ok`.

- [ ] **Step 2: Add `tool/generate_preset_avatars.py`**

Create the file with this full script (exact content):

```python
#!/usr/bin/env python3
"""Generate Winklo preset avatar mascot-blob PNGs (512x512)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 512
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "avatars"

SLATE = (30, 41, 59, 255)  # ZipColors.wall-ish
INK = (15, 23, 42, 255)  # ZipColors.ink

PRESETS = [
    ("preset_01", (255, 107, 44), "smile"),  # ember
    ("preset_02", (56, 189, 248), "wink"),  # sky
    ("preset_03", (167, 139, 250), "shy"),  # lavender
    ("preset_04", (45, 212, 191), "cheeky"),  # mint
    ("preset_05", (251, 191, 36), "sleepy"),  # gold
    ("preset_06", (251, 113, 133), "surprise"),  # rose
]


def disc(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def eye(draw: ImageDraw.ImageDraw, x: int, y: int, r: int = 18) -> None:
    disc(draw, x, y, r, INK)


def closed_eye(draw: ImageDraw.ImageDraw, x: int, y: int, w: int = 36) -> None:
    draw.rounded_rectangle((x - w // 2, y - 4, x + w // 2, y + 4), radius=4, fill=INK)


def smile_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    box = (cx - 55, cy - 20, cx + 55, cy + 55)
    draw.arc(box, start=20, end=160, fill=INK, width=10)


def shy_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    box = (cx - 40, cy - 35, cx + 40, cy + 15)
    draw.arc(box, start=200, end=340, fill=INK, width=8)


def flat_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    draw.rounded_rectangle((cx - 40, cy - 5, cx + 40, cy + 5), radius=4, fill=INK)


def draw_face(
    draw: ImageDraw.ImageDraw,
    kind: str,
    cx: int,
    cy: int,
    blob_r: int,
    fill: tuple[int, int, int, int],
) -> None:
    eye_y = cy - int(blob_r * 0.12)
    left_x = cx - int(blob_r * 0.28)
    right_x = cx + int(blob_r * 0.28)
    mouth_y = cy + int(blob_r * 0.28)

    if kind == "smile":
        eye(draw, left_x, eye_y)
        eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y)
    elif kind == "wink":
        eye(draw, left_x, eye_y)
        closed_eye(draw, right_x, eye_y)
        flat_mouth(draw, cx, mouth_y)
    elif kind == "shy":
        eye(draw, left_x, eye_y, r=14)
        eye(draw, right_x, eye_y, r=14)
        shy_mouth(draw, cx, mouth_y)
    elif kind == "cheeky":
        eye(draw, left_x, eye_y)
        eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y + 5)
    elif kind == "sleepy":
        closed_eye(draw, left_x, eye_y)
        closed_eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y)
    elif kind == "surprise":
        eye(draw, left_x, eye_y, r=20)
        eye(draw, right_x, eye_y, r=20)
        disc(draw, cx, mouth_y, 26, INK)
        disc(draw, cx, mouth_y, 12, fill)
    else:
        raise ValueError(kind)


def render(_preset_id: str, rgb: tuple[int, int, int], kind: str) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), SLATE)
    draw = ImageDraw.Draw(img)
    cx = cy = SIZE // 2
    fill = (*rgb, 255)
    blob_r = 170
    body_cy = cy + 8

    # Mint cheeky: ears peek from behind the body
    if kind == "cheeky":
        disc(draw, cx - 120, cy - 130, 48, fill)
        disc(draw, cx + 120, cy - 130, 48, fill)

    if kind in ("shy", "sleepy"):
        draw.ellipse(
            (
                cx - blob_r - 10,
                body_cy - blob_r + 25,
                cx + blob_r + 10,
                body_cy + blob_r - 10,
            ),
            fill=fill,
        )
    elif kind == "wink":
        draw.ellipse(
            (
                cx - blob_r + 5,
                body_cy - blob_r + 5,
                cx + blob_r - 5,
                body_cy + blob_r - 5,
            ),
            fill=fill,
        )
    else:
        disc(draw, cx, body_cy, blob_r, fill)

    draw_face(draw, kind, cx, body_cy, blob_r, fill)
    return img.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for preset_id, rgb, kind in PRESETS:
        path = OUT_DIR / f"{preset_id}.png"
        render(preset_id, rgb, kind).save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run the generator**
```bash
python3 tool/generate_preset_avatars.py
```

Expected: six lines like `wrote .../assets/avatars/preset_0N.png (NNNNN bytes)` with sizes **> 8 KiB** each.

- [ ] **Step 4: Spot-check one file**

```bash
python3 - <<'PY'
from PIL import Image
from pathlib import Path
root = Path('assets/avatars')
for p in sorted(root.glob('preset_0*.png')):
    im = Image.open(p)
    print(p.name, im.size, im.mode, p.stat().st_size)
PY
```

Expected: each `512x512`, mode `RGB`, size > 8192 bytes.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add tool/generate_preset_avatars.py assets/avatars/preset_0*.png
git commit -m "feat: replace solid preset avatars with mascot blobs"
```

---

### Task 3: Verify tests + visual acceptance

**Files:**
- Test: `test/domain/avatars/avatar_preset_assets_test.dart`
- Test: `test/core/widgets/user_avatar_test.dart`
- Manual: Edit avatar sheet in the running app

**Interfaces:**
- Consumes: generated PNGs from Task 2

- [ ] **Step 1: Run asset integrity test (must pass)**

```bash
flutter test test/domain/avatars/avatar_preset_assets_test.dart
```

Expected: PASS (all presets > 8 KiB, PNG magic OK).

- [ ] **Step 2: Run UserAvatar smoke test**

```bash
flutter test test/core/widgets/user_avatar_test.dart
```

Expected: PASS — `prefers preset asset over photoUrl` still finds an `Image`.

- [ ] **Step 3: Manual visual check**

1. Full restart the app (hot restart may cache old asset bytes).
2. Open Profile → Edit avatar.
3. Confirm Presets shows six distinct colored blobs (ember smile, sky wink, lavender shy, mint cheeky, gold sleepy, rose surprise) — **not** flat color circles.
4. Tap one preset; profile header avatar updates to that blob.
5. Optional: open Leaderboard and confirm the same `avatarId` shows the blob in a row.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add test/domain/avatars/avatar_preset_assets_test.dart tool/generate_preset_avatars.py assets/avatars/preset_0*.png
git commit -m "feat: add illustrated mascot preset avatars"
```

(If Tasks 1–2 already committed pieces, only stage remaining files.)

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Replace six solid-color PNGs with blob art | Task 2 |
| Keep `preset_01`…`06` IDs / paths | Task 2 (overwrite in place) |
| Flat abstract mascots; expressions table | Task 2 script `PRESETS` |
| Dark slate disc; ~512² opaque PNG | Task 2 `SIZE` / `SLATE` |
| No Dart catalog/UI changes | Global Constraints + no Dart modify tasks |
| Acceptance: sheet / profile / leaderboard | Task 3 |
| Asset not placeholder | Task 1 + Task 3 tests |

## Plan self-review

1. **Spec coverage:** All v1 goals mapped; non-goals (UI polish, new IDs, SVG) intentionally omitted.
2. **Placeholders:** None — generator script is complete and runnable as written.
3. **Consistency:** Filenames and IDs match `AvatarCatalog.presetIds` and the design table.
