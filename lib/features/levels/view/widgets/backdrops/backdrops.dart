import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../../core/theme/app_theme.dart';
import '../ink_palette.dart';
import '../level_theme_palette.dart';

/// Paints one world's band [r] in its [theme]: its ground and motif when the
/// world is [open], a faint outline of it ("unprinted") when it isn't. An
/// unknown theme gets the plain app ground. [seed] (the world's order) keeps
/// scattered motifs in the same place on every paint.
void paintThemeBackdrop(
  Canvas canvas,
  Rect r,
  String theme, {
  required bool open,
  int seed = 0,
}) {
  if (!open) {
    _unprinted(canvas, r);
    return;
  }
  final palette = LevelThemePalette.of(theme);
  switch (theme) {
    case 'ink':
      _ink(canvas, r);
    case 'metro':
      _metro(canvas, r);
    case 'embroidery':
      _ground(canvas, r, palette);
      _embroidery(canvas, r, palette.motif);
    case 'neon':
      _ground(canvas, r, palette);
      _neon(canvas, r);
    case 'sparkler':
      _ground(canvas, r, palette);
      _sparkler(canvas, r, palette.motif, seed);
    case 'animals':
      _ground(canvas, r, palette);
      _pawPrints(canvas, r, palette.motif, seed);
    case 'food':
      _ground(canvas, r, palette);
      _gingham(canvas, r, palette.motif);
    case 'sports':
      _ground(canvas, r, palette);
      _pitch(canvas, r, palette.motif);
    case 'nature':
      _ground(canvas, r, palette);
      _contours(canvas, r, palette.motif, seed);
    case 'home':
      _ground(canvas, r, palette);
      _wallpaper(canvas, r, palette.motif);
    case 'body':
      _ground(canvas, r, palette);
      _cells(canvas, r, palette.motif, seed);
    default:
      canvas.drawRect(r, Paint()..color = ZipColors.ink);
  }
}

void _ground(Canvas canvas, Rect r, LevelThemePalette p) {
  final end = p.baseEnd;
  final paint = Paint();
  if (end == null) {
    paint.color = p.base;
  } else {
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.base, end],
    ).createShader(r);
  }
  canvas.drawRect(r, paint);
}

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

// ---------------------------------------------------------------- Zip

void _ink(Canvas canvas, Rect r) {
  canvas.drawRect(r, Paint()..color = InkPalette.stone);
  final grid = Paint()
    ..color = InkPalette.vermilion.withValues(alpha: InkPalette.gridAlpha)
    ..strokeWidth = 0.8;
  for (var i = 1; i < 4; i++) {
    final x = r.left + r.width * i / 4;
    canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
  }
  for (var y = r.bottom - 70; y > r.top; y -= 70) {
    canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
  }
}

/// Metro's night ground.
const metroNight = Color(0xFF13233A);

void _metro(Canvas canvas, Rect r) {
  canvas.drawRect(r, Paint()..color = metroNight);
  for (final (path, color) in metroLines(r)) {
    canvas.drawPath(path, _stroke(color.withValues(alpha: 0.35), 5));
  }
}

void _unprinted(Canvas canvas, Rect r) {
  canvas.drawRect(r, Paint()..color = ZipColors.ink);
  final dash = Paint()
    ..style = PaintingStyle.stroke
    ..color = ZipColors.outlineQuiet
    ..strokeWidth = 1;
  for (final (path, _) in metroLines(r)) {
    canvas.drawPath(_dashed(path, 3, 4), dash);
  }
}

Path _dashed(Path path, double on, double off) {
  final dashes = Path();
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += on + off) {
      dashes.addPath(
        metric.extractPath(d, math.min(d + on, metric.length)),
        Offset.zero,
      );
    }
  }
  return dashes;
}

/// Three transit lines across [r]: the Metro look, and the outline of any
/// world before it's printed.
List<(Path, Color)> metroLines(Rect r) {
  final w = r.width;
  final h = r.height;
  return [
    (
      Path()
        ..moveTo(r.left + w * 0.12, r.bottom)
        ..lineTo(r.left + w * 0.12, r.top),
      const Color(0xFFF472B6),
    ),
    (
      Path()
        ..moveTo(r.left, r.top + h * 0.4)
        ..lineTo(r.left + w * 0.3, r.top + h * 0.4)
        ..lineTo(r.left + w * 0.38, r.top + h * 0.4 - w * 0.08)
        ..lineTo(r.right, r.top + h * 0.4 - w * 0.08),
      const Color(0xFFA3E635),
    ),
    (
      Path()
        ..moveTo(r.left + w * 0.86, r.top)
        ..lineTo(r.left + w * 0.86, r.top + h * 0.3)
        ..lineTo(r.left + w * 0.94, r.top + h * 0.3 + w * 0.08)
        ..lineTo(r.left + w * 0.94, r.bottom),
      const Color(0xFFFBBF24),
    ),
  ];
}

/// Embroidery: rows of cross-stitches in a diamond pattern on navy linen.
void _embroidery(Canvas canvas, Rect r, Color motif) {
  const step = 22.0;
  const arm = 4.5;
  final paint = _stroke(motif, 1.6);
  final cols = (r.width / step).ceil();
  final rows = (r.height / step).ceil();
  for (var j = 0; j <= rows; j++) {
    for (var i = 0; i <= cols; i++) {
      // Two crossing diagonals of stitches make a diamond lattice.
      if ((i + j) % 7 != 0 && (i - j) % 7 != 0) continue;
      final c = Offset(r.left + i * step, r.bottom - j * step);
      canvas.drawLine(
        c - const Offset(arm, arm),
        c + const Offset(arm, arm),
        paint,
      );
      canvas.drawLine(
        c - const Offset(-arm, arm),
        c + const Offset(-arm, arm),
        paint,
      );
    }
  }
}

/// Neon: three glowing tubes bending across the band.
void _neon(Canvas canvas, Rect r) {
  const tubes = [Color(0xFFE879F9), Color(0xFF22D3EE), Color(0xFFFB7185)];
  final w = r.width;
  for (var k = 0; k < tubes.length; k++) {
    final path = Path();
    final x0 = r.left + w * (0.1 + 0.4 * k);
    path.moveTo(x0, r.bottom);
    var y = r.bottom;
    var right = k.isEven;
    while (y > r.top) {
      final ny = y - 260;
      path.quadraticBezierTo(
        x0 + (right ? 1 : -1) * w * 0.12,
        (y + ny) / 2,
        x0,
        ny,
      );
      y = ny;
      right = !right;
    }
    canvas.drawPath(
      path,
      _stroke(tubes[k].withValues(alpha: 0.28), 9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, _stroke(tubes[k].withValues(alpha: 0.45), 2));
  }
}

/// Sparkler: four-point sparks scattered over a night sky.
void _sparkler(Canvas canvas, Rect r, Color motif, int seed) {
  final rng = math.Random(seed * 7919 + 1);
  final count = (r.width * r.height / 5200).round();
  final paint = Paint()..color = motif;
  for (var i = 0; i < count; i++) {
    final c = Offset(
      r.left + rng.nextDouble() * r.width,
      r.top + rng.nextDouble() * r.height,
    );
    final s = 2.0 + rng.nextDouble() * 4.5;
    final star = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(star, paint);
  }
}

// ------------------------------------------------------- Path Words

/// Animals: trails of paw prints wandering up the band.
void _pawPrints(Canvas canvas, Rect r, Color motif, int seed) {
  final rng = math.Random(seed * 104729 + 11);
  final paint = Paint()..color = motif;
  const trails = 3;
  for (var t = 0; t < trails; t++) {
    var x = r.left + r.width * (0.12 + 0.38 * t) + rng.nextDouble() * 20;
    var y = r.bottom - 30 - rng.nextDouble() * 60;
    var left = rng.nextBool();
    while (y > r.top) {
      final angle = -0.25 + rng.nextDouble() * 0.5;
      _paw(canvas, Offset(x + (left ? -9 : 9), y), angle, paint);
      left = !left;
      y -= 46 + rng.nextDouble() * 10;
      x += -6 + rng.nextDouble() * 12;
      if (x < r.left + 16) x = r.left + 16;
      if (x > r.right - 16) x = r.right - 16;
    }
  }
}

void _paw(Canvas canvas, Offset c, double angle, Paint paint) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 11, height: 9),
    paint,
  );
  for (final (dx, dy) in const [
    (-6.5, -6.0),
    (-2.4, -9.0),
    (2.4, -9.0),
    (6.5, -6.0),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(dx, dy), width: 4, height: 5),
      paint,
    );
  }
  canvas.restore();
}

/// Food: a faded gingham tablecloth.
void _gingham(Canvas canvas, Rect r, Color motif) {
  const step = 30.0;
  const band = 15.0;
  final paint = Paint()..color = motif;
  for (var x = r.left; x < r.right; x += step) {
    canvas.drawRect(Rect.fromLTWH(x, r.top, band, r.height), paint);
  }
  for (var y = r.bottom - band; y > r.top - band; y -= step) {
    canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, band), paint);
  }
}

/// Sports: a pitch's white lines, a pitch every 640 px up the band.
void _pitch(Canvas canvas, Rect r, Color motif) {
  final paint = _stroke(motif, 2);
  const inset = 16.0;
  const length = 640.0;
  final left = r.left + inset;
  final right = r.right - inset;
  final w = right - left;
  canvas.drawLine(Offset(left, r.top), Offset(left, r.bottom), paint);
  canvas.drawLine(Offset(right, r.top), Offset(right, r.bottom), paint);
  for (var end = r.bottom; end > r.top; end -= length) {
    final mid = end - length / 2;
    canvas.drawLine(Offset(left, end), Offset(right, end), paint);
    canvas.drawLine(Offset(left, mid), Offset(right, mid), paint);
    canvas.drawCircle(Offset(left + w / 2, mid), w * 0.16, paint);
    canvas.drawCircle(Offset(left + w / 2, mid), 3, Paint()..color = motif);
    // A box at each end of the pitch.
    final boxW = w * 0.5;
    final boxL = left + (w - boxW) / 2;
    canvas.drawRect(Rect.fromLTWH(boxL, end - 90, boxW, 90), paint);
    canvas.drawRect(Rect.fromLTWH(boxL, end - length, boxW, 90), paint);
  }
}

/// Nature: topographic contour lines with a scatter of leaves.
void _contours(Canvas canvas, Rect r, Color motif, int seed) {
  final rng = math.Random(seed * 1299709 + 5);
  final line = _stroke(motif, 1.4);
  for (var base = r.bottom - 40; base > r.top - 40; base -= 84) {
    final phase = rng.nextDouble() * math.pi * 2;
    final amp = 14 + rng.nextDouble() * 12;
    final path = Path()..moveTo(r.left, base + amp * math.sin(phase));
    for (var x = r.left; x <= r.right + 8; x += 8) {
      path.lineTo(x, base + amp * math.sin(phase + (x - r.left) / 58));
    }
    canvas.drawPath(path, line);
  }
  final leaf = Paint()..color = motif;
  final count = (r.width * r.height / 14000).round();
  for (var i = 0; i < count; i++) {
    final c = Offset(
      r.left + rng.nextDouble() * r.width,
      r.top + rng.nextDouble() * r.height,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rng.nextDouble() * math.pi);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 4.5),
      leaf,
    );
    canvas.restore();
  }
}

/// Home: a diamond wallpaper lattice over wood-plank flooring at the bottom.
void _wallpaper(Canvas canvas, Rect r, Color motif) {
  final paint = _stroke(motif, 1.1);
  const step = 46.0;
  final h = r.height;
  canvas.save();
  canvas.clipRect(r);
  for (var x = r.left - h; x < r.right + h; x += step) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + h, r.top), paint);
    canvas.drawLine(Offset(x, r.top), Offset(x + h, r.bottom), paint);
  }
  // Small dots at the lattice crossings read as a printed wallpaper.
  final dot = Paint()..color = motif;
  for (var y = r.bottom; y > r.top; y -= step) {
    for (var x = r.left; x < r.right; x += step) {
      canvas.drawCircle(Offset(x + step / 2, y - step / 2), 1.8, dot);
    }
  }
  // Three rows of planks along the band's bottom edge.
  const plank = 22.0;
  final floor = Paint()..color = const Color(0x40A16207);
  final seam = _stroke(const Color(0x33000000), 1);
  for (var row = 0; row < 3; row++) {
    final top = r.bottom - plank * (row + 1);
    canvas.drawRect(Rect.fromLTWH(r.left, top, r.width, plank), floor);
    canvas.drawLine(Offset(r.left, top), Offset(r.right, top), seam);
    for (var x = r.left + (row.isEven ? 40.0 : 90.0); x < r.right; x += 110) {
      canvas.drawLine(Offset(x, top), Offset(x, top + plank), seam);
    }
  }
  canvas.restore();
}

/// Body: floating cells, rings of three sizes.
void _cells(Canvas canvas, Rect r, Color motif, int seed) {
  final rng = math.Random(seed * 15485863 + 3);
  final count = (r.width * r.height / 9000).round();
  const radii = [6.0, 13.0, 24.0];
  for (var i = 0; i < count; i++) {
    final c = Offset(
      r.left + rng.nextDouble() * r.width,
      r.top + rng.nextDouble() * r.height,
    );
    final radius = radii[rng.nextInt(radii.length)];
    canvas.drawCircle(c, radius, _stroke(motif, 1.5));
    // A nucleus in the larger cells.
    if (radius > 10) {
      canvas.drawCircle(c, radius * 0.28, Paint()..color = motif);
    }
  }
}
