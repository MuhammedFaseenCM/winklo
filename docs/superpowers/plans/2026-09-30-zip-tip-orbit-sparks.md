# Zip Tip Orbit Sparks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Soft ember flecks orbit the Zip live stroke tip while the user is drawing, and clear immediately on release.

**Architecture:** Pure helper `ZipTipSparks` owns particle spawn/update/clear/draw. `ZipGame` calls it from `update`/`render` while `_drawing` and a live tip exist; clears when drawing ends. No Bloc changes.

**Tech Stack:** Flutter Canvas, Flame `ZipGame`, `ZipPathRibbon` / `ZipColors`, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-30-zip-tip-orbit-sparks-design.md`

## Global Constraints

- Visual-only; no puzzle rule / Bloc / win-flow changes
- No new packages
- Sparks only while `_drawing` + live tip; clear immediately on release (no post-lift fade)
- Soft ember / ribbon colors — not white glitter
- Prefer `dart format`; no drive-by refactors
- All user-facing copy via `AppStrings` (N/A — no new copy)

## File map

| File | Responsibility |
| --- | --- |
| `lib/features/zip/game/zip_tip_sparks.dart` | Particle model, spawn, tick, clear, paint |
| `lib/features/zip/game/zip_game.dart` | Wire sparks to drawing lifecycle + tip position |
| `test/features/zip/game/zip_tip_sparks_test.dart` | Unit tests for spawn / tick / clear / inactive |

---

### Task 1: `ZipTipSparks` helper (TDD)

**Files:**
- Create: `test/features/zip/game/zip_tip_sparks_test.dart`
- Create: `lib/features/zip/game/zip_tip_sparks.dart`

**Interfaces:**
- Produces:
  - `class ZipTipSparks` with:
    - `bool get isActive`
    - `int get count`
    - `void ensureActive({required int seed})` — spawn ~8 flecks if empty
    - `void clear()`
    - `void update(double dt)` — advance orbit angles when active
    - `void paint(Canvas canvas, {required Offset tip, required double tipRadius})`

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/zip/game/zip_tip_sparks.dart';

void main() {
  test('starts inactive with zero flecks', () {
    final sparks = ZipTipSparks();
    expect(sparks.isActive, isFalse);
    expect(sparks.count, 0);
  });

  test('ensureActive spawns a fixed fleck set', () {
    final sparks = ZipTipSparks();
    sparks.ensureActive(seed: 7);
    expect(sparks.isActive, isTrue);
    expect(sparks.count, ZipTipSparks.fleckCount);
    sparks.ensureActive(seed: 99);
    expect(sparks.count, ZipTipSparks.fleckCount);
  });

  test('clear empties flecks immediately', () {
    final sparks = ZipTipSparks()..ensureActive(seed: 1);
    sparks.clear();
    expect(sparks.isActive, isFalse);
    expect(sparks.count, 0);
  });

  test('update advances angles without changing count', () {
    final sparks = ZipTipSparks()..ensureActive(seed: 3);
    final before = sparks.debugAngles();
    sparks.update(1 / 60);
    final after = sparks.debugAngles();
    expect(sparks.count, ZipTipSparks.fleckCount);
    expect(after, isNot(before));
  });

  test('paint is a no-op when inactive', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    ZipTipSparks().paint(
      canvas,
      tip: Offset.zero,
      tipRadius: 10,
    );
    expect(recorder.endRecording().approximateBytesUsed, lessThan(64));
  });
}
```

- [ ] **Step 2: Run tests — confirm RED**

```bash
flutter test test/features/zip/game/zip_tip_sparks_test.dart
```

Expected: FAIL — `zip_tip_sparks.dart` missing / `ZipTipSparks` undefined.

- [ ] **Step 3: Implement `ZipTipSparks`**

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'zip_path_ribbon.dart';

/// Soft ember flecks that orbit the live Zip stroke tip while drawing.
class ZipTipSparks {
  static const fleckCount = 8;

  final List<_Fleck> _flecks = [];

  bool get isActive => _flecks.isNotEmpty;
  int get count => _flecks.length;

  /// Test-only angle snapshot.
  List<double> debugAngles() => [for (final f in _flecks) f.angle];

  void ensureActive({required int seed}) {
    if (_flecks.isNotEmpty) return;
    final random = math.Random(seed);
    for (var i = 0; i < fleckCount; i++) {
      final t = i / fleckCount;
      _flecks.add(
        _Fleck(
          angle: t * math.pi * 2 + random.nextDouble() * 0.4,
          speed: 1.2 + random.nextDouble() * 1.6,
          radiusFactor: 1.1 + random.nextDouble() * 0.5,
          size: 1.5 + random.nextDouble() * 2.0,
          color: Color.lerp(
            ZipColors.ember,
            ZipPathRibbon.colorAt(i),
            0.35 + random.nextDouble() * 0.45,
          )!.withValues(alpha: 0.35 + random.nextDouble() * 0.4),
        ),
      );
    }
  }

  void clear() => _flecks.clear();

  void update(double dt) {
    for (final fleck in _flecks) {
      fleck.angle += fleck.speed * dt;
    }
  }

  void paint(
    Canvas canvas, {
    required Offset tip,
    required double tipRadius,
  }) {
    if (_flecks.isEmpty) return;
    for (final fleck in _flecks) {
      final r = tipRadius * fleck.radiusFactor;
      final pos = tip + Offset(math.cos(fleck.angle) * r, math.sin(fleck.angle) * r);
      canvas.drawCircle(pos, fleck.size, Paint()..color = fleck.color);
    }
  }
}

class _Fleck {
  _Fleck({
    required this.angle,
    required this.speed,
    required this.radiusFactor,
    required this.size,
    required this.color,
  });

  double angle;
  final double speed;
  final double radiusFactor;
  final double size;
  final Color color;
}
```

Notes for implementer:
- Drop the erroneous `abstract final class ZipTipSparks` stub — only the concrete class.
- Keep `debugAngles()` for tests (or `@visibleForTesting`).
- If `approximateBytesUsed` assertion is flaky across platforms, replace the paint no-op test with: call `paint` when inactive and assert `count == 0` / `isActive == false` only (skip canvas byte check).

- [ ] **Step 4: Run tests — confirm GREEN**

```bash
flutter test test/features/zip/game/zip_tip_sparks_test.dart
dart format lib/features/zip/game/zip_tip_sparks.dart test/features/zip/game/zip_tip_sparks_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/zip/game/zip_tip_sparks.dart test/features/zip/game/zip_tip_sparks_test.dart
git commit -m "$(cat <<'EOF'
feat(zip): add tip orbit sparks helper

EOF
)"
```

---

### Task 2: Wire sparks into `ZipGame` draw lifecycle

**Files:**
- Modify: `lib/features/zip/game/zip_game.dart`
- Test: reuse `test/features/zip/game/zip_tip_sparks_test.dart` (helper already covered); run existing Zip draw tests for regression

**Interfaces:**
- Consumes: `ZipTipSparks` from Task 1 (`ensureActive`, `clear`, `update`, `paint`)
- Produces: sparks visible while drawing; cleared when `_drawing` becomes false

- [ ] **Step 1: Add field + import**

Near other private fields in `ZipGame`:

```dart
final ZipTipSparks _tipSparks = ZipTipSparks();
```

Import:

```dart
import 'zip_tip_sparks.dart';
```

- [ ] **Step 2: Update `update(dt)`**

```dart
@override
void update(double dt) {
  super.update(dt);
  if (_celebrate) {
    _celebrateT += dt;
  }
  if (_drawing && _clampedLiveTip() != null) {
    _tipSparks.ensureActive(seed: path.length);
    _tipSparks.update(dt);
  } else if (_tipSparks.isActive) {
    _tipSparks.clear();
  }
}
```

- [ ] **Step 3: Draw after path stroke**

In `render`, after `_drawPathStroke(canvas);`:

```dart
_drawTipSparks(canvas);
```

Add:

```dart
void _drawTipSparks(Canvas canvas) {
  if (!_drawing) return;
  final tip = _clampedLiveTip();
  if (tip == null) return;
  final width = _cellSize * 0.46;
  _tipSparks.paint(canvas, tip: tip, tipRadius: width * 0.42);
}
```

Also clear on every place `_drawing` is set to `false` if you prefer immediate clear without waiting for next `update` — optional belt-and-suspenders:

```dart
void _stopDrawing() {
  _drawing = false;
  _tipSparks.clear();
}
```

Then replace bare `_drawing = false;` assignments that end a stroke with `_stopDrawing()` (do **not** change places that briefly set false then true in the same handler unless you read the control flow carefully — prefer clear-in-`update` if unsure).

Recommended safe approach: rely on `update` clear (Step 2) only; do not mass-refactor all `_drawing = false` sites.

- [ ] **Step 4: Regression tests + format**

```bash
flutter test test/features/zip/game/
dart format lib/features/zip/game/zip_game.dart
```

Expected: all Zip game tests PASS.

- [ ] **Step 5: Manual check checklist (device/simulator)**

1. Press and hold on start cell → flecks orbit tip
2. Drag along path → flecks follow tip
3. Lift finger → flecks gone immediately
4. Complete puzzle → win glow still works; no idle sparks after lift
5. Read-only / solution view (if available) → no sparks

- [ ] **Step 6: Commit**

```bash
git add lib/features/zip/game/zip_game.dart
git commit -m "$(cat <<'EOF'
feat(zip): orbit ember sparks at live stroke tip while drawing

EOF
)"
```

---

### Task 3: Spec status + analyze

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-zip-tip-orbit-sparks-design.md` (status line only)

- [ ] **Step 1: Mark spec implemented**

Change status to: `Implemented`

- [ ] **Step 2: Analyze touched Dart files**

```bash
dart analyze lib/features/zip/game/zip_tip_sparks.dart lib/features/zip/game/zip_game.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-30-zip-tip-orbit-sparks-design.md
git commit -m "$(cat <<'EOF'
docs: mark Zip tip orbit sparks design implemented

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
| --- | --- |
| Orbit soft ember flecks at live tip while drawing | Task 1 + 2 |
| Stop immediately on release | Task 2 `update` clear |
| Canvas inside `ZipGame`, helper file | Task 1 + 2 |
| No Bloc / packages / trail / white glitter | Global constraints |
| Unit tests spawn / clear / inactive | Task 1 |
| Existing draw tests green | Task 2 Step 4 |
| Read-only no sparks | Task 2 (`_drawing` false in readOnly) |

No placeholders remaining. Types consistent: `ZipTipSparks.ensureActive` / `clear` / `update` / `paint`.
