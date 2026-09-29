import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/zip_level.dart';
import '../logic/path_validator.dart';
import '../logic/zip_hints.dart';
import '../logic/zip_rule_tip.dart';
import 'zip_path_ribbon.dart';
import 'zip_stroke.dart';
import 'zip_tip_sparks.dart';

typedef ZipWinCallback = void Function(int points, int elapsedSeconds);
typedef ZipRuleTipCallback = void Function(ZipRuleTip tip);

class ZipGame extends FlameGame with DragCallbacks, TapCallbacks {
  ZipGame({
    required this.level,
    required this.onWin,
    required this.onStatsChanged,
    this.onRuleTip,
    this.readOnly = false,
  }) : _validator = PathValidator(level);

  final ZipLevel level;
  final ZipWinCallback onWin;
  final void Function(int pathLength, int nextNumber) onStatsChanged;
  final ZipRuleTipCallback? onRuleTip;
  final bool readOnly;
  final PathValidator _validator;
  final ZipTipSparks _tipSparks = ZipTipSparks();
  late double _cellSize;
  late Offset _origin;
  late double _boardRadius;
  final List<Cell> path = [];
  bool _won = false;
  bool _drawing = false;

  /// True after [onTapDown] armed a stroke; drag may cancel the tap later.
  bool _armedFromTapDown = false;
  DateTime? startedAt;
  int hintsRemaining = 3;
  int hintRevealLength = 0;
  int hintFromIndex = 0;
  DateTime? _hintFlashStartedAt;
  double _celebrateT = 0;
  bool _celebrate = false;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startedAt = DateTime.now();
    _layout();
    if (readOnly && level.solution.isNotEmpty) {
      path.addAll(level.solution);
      _won = true;
      onStatsChanged(path.length, level.maxNumber);
      return;
    }
    onStatsChanged(0, 1);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

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

  void _layout() {
    final padding = 10.0;
    final usable = math.min(size.x, size.y);
    _cellSize = (usable - padding * 2) / level.size;
    final board = _cellSize * level.size;
    _origin = Offset((size.x - board) / 2, (size.y - board) / 2);
    _boardRadius = math.min(22.0, _cellSize * 0.4);
  }

  Cell? _cellAt(Vector2 position) {
    final local = Offset(position.x - _origin.dx, position.y - _origin.dy);
    // Small edge tolerance so fast swipes near borders still register.
    final pad = _cellSize * 0.05;
    if (local.dx < -pad || local.dy < -pad) return null;
    final board = _cellSize * level.size;
    if (local.dx > board + pad || local.dy > board + pad) return null;
    final col = local.dx.clamp(0, board - 0.001) ~/ _cellSize;
    final row = local.dy.clamp(0, board - 0.001) ~/ _cellSize;
    final cell = Cell(row.toInt(), col.toInt());
    if (!_validator.inBounds(cell)) return null;
    return cell;
  }

  Offset _centerOf(Cell cell) {
    return Offset(
      _origin.dx + (cell.col + 0.5) * _cellSize,
      _origin.dy + (cell.row + 0.5) * _cellSize,
    );
  }

  Rect _cellRect(Cell cell, {double inset = 0}) {
    return Rect.fromLTWH(
      _origin.dx + cell.col * _cellSize + inset,
      _origin.dy + cell.row * _cellSize + inset,
      _cellSize - inset * 2,
      _cellSize - inset * 2,
    );
  }

  List<Cell> get hintedCells => ZipHints.revealedCells(
    solution: level.solution,
    path: path,
    fromIndex: hintFromIndex,
    revealLength: hintRevealLength,
  );

  bool get canHint {
    if (_won || readOnly || hintsRemaining <= 0) return false;
    return ZipHints.canReveal(
      solution: level.solution,
      path: path,
      fromIndex: hintFromIndex,
      revealLength: hintRevealLength,
    );
  }

  bool hint() {
    if (!canHint) return false;
    final next = ZipHints.afterHint(
      solution: level.solution,
      path: path,
      fromIndex: hintFromIndex,
      revealLength: hintRevealLength,
    );
    hintFromIndex = next.fromIndex;
    hintRevealLength = next.revealLength;
    hintsRemaining--;
    _hintFlashStartedAt = DateTime.now();
    return true;
  }

  void undo() {
    if (_won || path.isEmpty) return;
    path.removeLast();
    _notifyStats();
  }

  void clearPath() {
    if (_won) return;
    path.clear();
    hintRevealLength = 0;
    hintFromIndex = 0;
    hintsRemaining = 3;
    _hintFlashStartedAt = null;
    _notifyStats();
  }

  void _notifyStats() {
    onStatsChanged(path.length, _validator.nextRequiredAfter(path));
  }

  Vector2? _lastPointer;
  Cell? _downCell;
  double _pointerTravel = 0;

  /// Continue the path while dragging. Pops only the last cell (LIFO).
  void extendTo(Cell cell) {
    if (_won || readOnly) return;

    final popped = _validator.tryLifoBacktrack(path: path, candidate: cell);
    if (popped != null) {
      path
        ..clear()
        ..addAll(popped);
      _notifyStats();
      return;
    }

    final extended = _validator.tryExtend(path: path, candidate: cell);
    if (extended == null) return;

    path
      ..clear()
      ..addAll(extended);
    _notifyStats();

    if (_validator.isWon(path)) {
      _won = true;
      _celebrate = true;
      final elapsed = DateTime.now().difference(startedAt!).inSeconds;
      final points = (1000 - elapsed * 5).clamp(50, 1000);
      onWin(points, elapsed);
    }
  }

  /// Jump the tip back to [cell] after a tap, not a drag.
  void truncateTo(Cell cell) {
    if (_won || readOnly) return;
    final truncated = _validator.tryBacktrack(path: path, candidate: cell);
    if (truncated == null) return;
    path
      ..clear()
      ..addAll(truncated);
    _notifyStats();
  }

  /// Sample along the finger path so fast swipes still fill every cell.
  void _tracePointer(Vector2 from, Vector2 to) {
    final delta = to - from;
    final distance = delta.length;
    final step = math.max(_cellSize * 0.1, 1.0);
    final samples = math.max(1, (distance / step).ceil());
    for (var i = 0; i <= samples; i++) {
      final t = samples == 0 ? 1.0 : i / samples;
      final point = from + delta * t;
      final cell = _cellAt(point);
      if (cell != null) extendTo(cell);
      if (_won) return;
    }
  }

  bool _canStartDrawing(Cell cell) {
    return _validator.canEnter(path: path, candidate: cell);
  }

  bool _isTap() {
    final slop = math.max(12.0, _cellSize * 0.2);
    return _pointerTravel <= slop;
  }

  /// Starts a stroke at [cell]. Earlier path cells rewind the tip first.
  /// Returns whether this press should continue as an active draw stroke.
  bool beginStrokeAt(Cell cell) {
    if (_won || readOnly) return false;

    if (path.isEmpty) {
      if (level.numbers[cell] == 1) {
        extendTo(cell);
        return true;
      }
      onRuleTip?.call(ZipRuleTip.startAtOne);
      return false;
    }

    if (path.contains(cell) && cell != path.last) {
      truncateTo(cell);
      return true;
    }

    if (_canStartDrawing(cell)) {
      extendTo(cell);
      return true;
    }
    return false;
  }

  void _endStroke() {
    final tapped = _downCell;
    if (_isTap() && tapped != null) {
      truncateTo(tapped);
    }
    if (!_won && !readOnly) {
      final tip = _validator.ruleTipAfterStroke(path);
      if (tip != null) onRuleTip?.call(tip);
    }
    _drawing = false;
    _armedFromTapDown = false;
    _lastPointer = null;
    _downCell = null;
    _pointerTravel = 0;
  }

  /// Arm the stroke on true pointer-down so press-rewind sees the press cell
  /// before drag recognition moves past it.
  @override
  void onTapDown(TapDownEvent event) {
    if (readOnly || _won) return;
    final pos = event.localPosition;
    final cell = _cellAt(pos);
    _lastPointer = pos.clone();
    _downCell = cell;
    _pointerTravel = 0;
    _armedFromTapDown = false;
    if (cell == null) return;
    if (beginStrokeAt(cell)) {
      _drawing = true;
      _armedFromTapDown = true;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_armedFromTapDown) return;
    // Pure tap (no drag took over) — finish the stroke.
    _endStroke();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    // Drag won the arena; keep [_drawing] and continue via drag handlers.
    _armedFromTapDown = false;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (readOnly || _won) {
      _drawing = false;
      _downCell = null;
      _armedFromTapDown = false;
      return;
    }
    final pos = event.localPosition;

    // Stroke already armed on pointer-down (typical press-rewind case).
    if (_drawing && _downCell != null) {
      final from = _lastPointer ?? pos;
      _pointerTravel += (pos - from).length;
      _tracePointer(from, pos);
      _lastPointer = pos.clone();
      _armedFromTapDown = false;
      return;
    }

    final cell = _cellAt(pos);
    _lastPointer = pos.clone();
    _downCell = cell;
    _pointerTravel = 0;
    _armedFromTapDown = false;
    if (cell == null) {
      _drawing = false;
      return;
    }

    if (beginStrokeAt(cell)) {
      _drawing = true;
      _lastPointer = pos.clone();
      return;
    }
    _drawing = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_won) return;
    final to = event.localEndPosition;
    final from = _lastPointer ?? to;
    _pointerTravel += (to - from).length;
    _lastPointer = to.clone();
    if (!_drawing) return;
    _tracePointer(from, to);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _endStroke();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _drawing = false;
    _armedFromTapDown = false;
    _lastPointer = null;
    _downCell = null;
    _pointerTravel = 0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBoardShadow(canvas);
    _drawBoard(canvas);
    _drawPathStroke(canvas);
    _drawTipSparks(canvas);
    _drawWalls(canvas);
    _drawHints(canvas);
    _drawNumbers(canvas);
    _drawCelebrateGlow(canvas);
  }

  void _drawCelebrateGlow(Canvas canvas) {
    if (!_celebrate) return;
    final board = _cellSize * level.size;
    final rect = Rect.fromLTWH(_origin.dx, _origin.dy, board, board);
    final pulse = 0.5 + 0.5 * math.sin(_celebrateT * math.pi * 2.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2.5), Radius.circular(_boardRadius)),
      Paint()
        ..color = ZipColors.success.withValues(alpha: 0.18 + pulse * 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + pulse * 3.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(5.5),
        Radius.circular(_boardRadius * 0.9),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12 + pulse * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawHints(Canvas canvas) {
    if (readOnly) return;
    final cells = hintedCells;
    if (cells.isEmpty) return;

    final startedAt = _hintFlashStartedAt ?? DateTime.now();
    final t = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final color = Color.lerp(ZipColors.success, Colors.white, pulse * 0.16)!;
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final isNewest = i == cells.length - 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(cell, inset: 4),
          const Radius.circular(8),
        ),
        Paint()..color = color.withValues(alpha: isNewest ? 0.55 : 0.32),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(cell, inset: 4),
          const Radius.circular(8),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isNewest ? 3.2 : 2.2,
      );
    }
  }

  void _drawBoardShadow(Canvas canvas) {
    final board = _cellSize * level.size;
    final rect = Rect.fromLTWH(_origin.dx, _origin.dy, board, board);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0, 6),
        Radius.circular(_boardRadius),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  void _drawBoard(Canvas canvas) {
    final board = _cellSize * level.size;
    final rect = Rect.fromLTWH(_origin.dx, _origin.dy, board, board);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(_boardRadius));

    canvas.drawRRect(rrect, Paint()..color = ZipColors.wall);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ZipColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final grid = Paint()
      ..color = ZipColors.mistDeep
      ..strokeWidth = 1.2;
    for (var i = 1; i < level.size; i++) {
      final x = _origin.dx + i * _cellSize;
      final y = _origin.dy + i * _cellSize;
      canvas.drawLine(
        Offset(x, _origin.dy),
        Offset(x, _origin.dy + board),
        grid,
      );
      canvas.drawLine(
        Offset(_origin.dx, y),
        Offset(_origin.dx + board, y),
        grid,
      );
    }
  }

  void _drawNumbers(Canvas canvas) {
    for (final entry in level.numbers.entries) {
      final n = entry.value;
      final center = _centerOf(entry.key);
      final onPath = path.contains(entry.key);
      final fontSize = _cellSize * 0.36;
      final fillColor = onPath ? Colors.white : ZipColors.number;

      if (onPath) {
        final outline = TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.22
                ..strokeJoin = StrokeJoin.round
                ..color = ZipColors.ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        outline.paint(
          canvas,
          Offset(center.dx - outline.width / 2, center.dy - outline.height / 2),
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: fillColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
  }

  Offset? _clampedLiveTip() {
    if (!_drawing || _lastPointer == null || path.isEmpty) return null;
    final origin = _centerOf(path.last);
    final finger = Offset(_lastPointer!.x, _lastPointer!.y);
    final bounds = Rect.fromLTRB(
      origin.dx -
          _validator.liveReachCells(path: path, dRow: 0, dCol: -1) * _cellSize,
      origin.dy -
          _validator.liveReachCells(path: path, dRow: -1, dCol: 0) * _cellSize,
      origin.dx +
          _validator.liveReachCells(path: path, dRow: 0, dCol: 1) * _cellSize,
      origin.dy +
          _validator.liveReachCells(path: path, dRow: 1, dCol: 0) * _cellSize,
    );
    return ZipStroke.railWithin(origin: origin, finger: finger, bounds: bounds);
  }

  void _drawPathStroke(Canvas canvas) {
    if (path.isEmpty) return;

    final width = _cellSize * 0.46;
    final centers = [for (final cell in path) _centerOf(cell)];
    final live = _clampedLiveTip();
    final pts = ZipStroke.points(cellCenters: centers, liveTip: live);
    if (pts.isEmpty) return;

    final tipColor = ZipPathRibbon.colorAt(path.length - 1);
    if (pts.length == 1) {
      _drawTip(canvas, pts.first, width, tipColor);
      return;
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final fromColor = ZipPathRibbon.colorAt(i);
      final toColor = ZipPathRibbon.colorAt(i + 1);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..shader = ui.Gradient.linear(a, b, [fromColor, toColor])
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    _drawTip(canvas, pts.last, width, tipColor);
  }

  void _drawTip(Canvas canvas, Offset tip, double width, Color color) {
    canvas.drawCircle(tip, width * 0.42, Paint()..color = color);
    canvas.drawCircle(
      tip,
      width * 0.42,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawTipSparks(Canvas canvas) {
    if (!_drawing) return;
    final tip = _clampedLiveTip();
    if (tip == null) return;
    final width = _cellSize * 0.46;
    _tipSparks.paint(canvas, tip: tip, tipRadius: width * 0.42);
  }

  void _drawWalls(Canvas canvas) {
    final paint = Paint()
      ..color = ZipColors.onInk.withValues(alpha: 0.85)
      ..strokeWidth = math.max(5.0, _cellSize * 0.12)
      ..strokeCap = StrokeCap.round;

    for (final wall in level.walls) {
      final a = wall.a;
      final b = wall.b;
      late Offset p1;
      late Offset p2;
      final inset = _cellSize * 0.16;
      if (a.row == b.row) {
        final row = a.row;
        final col = math.max(a.col, b.col);
        final x = _origin.dx + col * _cellSize;
        p1 = Offset(x, _origin.dy + row * _cellSize + inset);
        p2 = Offset(x, _origin.dy + (row + 1) * _cellSize - inset);
      } else {
        final col = a.col;
        final row = math.max(a.row, b.row);
        final y = _origin.dy + row * _cellSize;
        p1 = Offset(_origin.dx + col * _cellSize + inset, y);
        p2 = Offset(_origin.dx + (col + 1) * _cellSize - inset, y);
      }
      canvas.drawLine(p1, p2, paint);
    }
  }
}
