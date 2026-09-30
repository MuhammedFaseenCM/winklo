import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/cell.dart';
import '../../../domain/entities/path_words_puzzle.dart';
import '../../../domain/path_words/path_words_rules.dart';
import 'path_words_board_view.dart';

class PathWordsGame extends FlameGame with DragCallbacks, TapCallbacks {
  PathWordsGame({
    required this.view,
    required this.onPointerDown,
    required this.onPointerEnter,
    required this.onPointerUp,
  });

  PathWordsBoardView view;
  final void Function(Cell) onPointerDown;
  final void Function(Cell) onPointerEnter;
  final void Function() onPointerUp;

  late double _cellSize;
  late Offset _origin;
  late double _boardRadius;

  Vector2? _lastPointer;
  Cell? _lastEnteredCell;
  bool _drawing = false;
  bool _tapGesture = false;

  DateTime? _hintFlashStartedAt;
  double _celebrateT = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  void applyView(PathWordsBoardView view) {
    final oldPath = this.view.hintPath;
    final oldReveal = this.view.hintRevealLength;
    final wasCelebrating = this.view.celebrate;
    this.view = view;
    if (view.hintPath.isNotEmpty &&
        (view.hintRevealLength != oldReveal ||
            view.hintPath.length != oldPath.length ||
            view.hintPath.last != (oldPath.isEmpty ? null : oldPath.last))) {
      _hintFlashStartedAt = DateTime.now();
    }
    if (view.hintPath.isEmpty) {
      _hintFlashStartedAt = null;
    }
    if (view.celebrate && !wasCelebrating) {
      _celebrateT = 0;
    }
    if (!view.celebrate) {
      _celebrateT = 0;
    }
    _layout();
  }

  void _layout() {
    final padding = 10.0;
    final usable = math.min(size.x, size.y);
    final boardSize = view.puzzle.size;
    _cellSize = (usable - padding * 2) / boardSize;
    final board = _cellSize * boardSize;
    _origin = Offset((size.x - board) / 2, (size.y - board) / 2);
    _boardRadius = math.min(22.0, _cellSize * 0.4);
  }

  Cell? _cellAt(Vector2 position) {
    final local = Offset(position.x - _origin.dx, position.y - _origin.dy);
    final pad = _cellSize * 0.05;
    if (local.dx < -pad || local.dy < -pad) return null;
    final board = _cellSize * view.puzzle.size;
    if (local.dx > board + pad || local.dy > board + pad) return null;

    final col = local.dx.clamp(0, board - 0.001) ~/ _cellSize;
    final row = local.dy.clamp(0, board - 0.001) ~/ _cellSize;
    final cell = Cell(row.toInt(), col.toInt());
    if (!_inBounds(cell)) return null;
    return cell;
  }

  bool _inBounds(Cell cell) {
    return cell.row >= 0 &&
        cell.row < view.puzzle.size &&
        cell.col >= 0 &&
        cell.col < view.puzzle.size;
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

  Color _fillColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.78).clamp(0.4, 0.85))
        .withLightness(0.38)
        .toColor();
  }

  /// Flat in-cell fill — no lift/shadow so tiles stay inside their grid.
  void _drawPathCell(
    Canvas canvas, {
    required Cell cell,
    required Color color,
  }) {
    final radius = Radius.circular(_cellSize * 0.18);
    final rect = _cellRect(cell, inset: _cellSize * 0.1);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, Paint()..color = _fillColor(color));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, _cellSize * 0.03),
    );
  }

  Color _activeStrokeColor() {
    final index = PathWordsRules.nextUnusedColorIndex(
      puzzle: view.puzzle,
      completedTargetIds: view.completedPathsByTargetId.keys.toSet(),
      placedPaths: view.placedPaths,
      paletteLength: pathColors.length,
    );
    return pathColors[index % pathColors.length];
  }

  void _drawStartRing(Canvas canvas, Cell cell, Color color) {
    final center = _centerOf(cell);
    final radius = _cellSize * 0.34;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, _cellSize * 0.07),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, _cellSize * 0.035),
    );
  }

  void _tracePointer(Vector2 from, Vector2 to) {
    final delta = to - from;
    final distance = delta.length;
    final step = math.max(_cellSize * 0.1, 1.0);
    final samples = math.max(1, (distance / step).ceil());
    for (var i = 0; i <= samples; i++) {
      final t = samples == 0 ? 1.0 : i / samples;
      final point = from + delta * t;
      final cell = _cellAt(point);
      if (cell == null) continue;

      if (_lastEnteredCell == cell) continue;
      _lastEnteredCell = cell;
      if (!view.inputEnabled) continue;
      onPointerEnter(cell);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final pos = event.localPosition;
    _lastPointer = pos.clone();
    if (!_tapGesture) {
      _lastEnteredCell = null;
    }

    final cell = _cellAt(pos);
    if (cell == null || !view.inputEnabled) {
      _drawing = false;
      return;
    }

    _drawing = true;
    if (_tapGesture) {
      return;
    }
    _lastEnteredCell = cell;
    onPointerDown(cell);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final pos = event.localPosition;
    final cell = _cellAt(pos);
    if (cell == null || !view.inputEnabled) return;

    _tapGesture = true;
    _lastEnteredCell = cell;
    onPointerDown(cell);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_tapGesture) return;
    _tapGesture = false;
    if (!_drawing && view.inputEnabled) {
      onPointerUp();
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (!_tapGesture) return;
    _tapGesture = false;
    if (!_drawing && view.inputEnabled) {
      onPointerUp();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_drawing) return;
    final to = event.localEndPosition;
    final from = _lastPointer ?? to;
    _tracePointer(from, to);
    _lastPointer = to.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_drawing && view.inputEnabled) {
      onPointerUp();
    }
    _drawing = false;
    _tapGesture = false;
    _lastPointer = null;
    _lastEnteredCell = null;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (_drawing && view.inputEnabled) {
      onPointerUp();
    }
    _drawing = false;
    _tapGesture = false;
    _lastPointer = null;
    _lastEnteredCell = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (view.celebrate) {
      _celebrateT += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBoardShadow(canvas);
    _drawBoard(canvas);
    _drawUnusedCells(canvas);
    _drawCompletedPaths(canvas);
    _drawPlacedPaths(canvas);
    _drawCelebrateGlow(canvas);
    _drawActivePath(canvas);
    _drawStartMarkers(canvas);
    _drawLiveNeighbor(canvas);
    _drawHintFlash(canvas);
    _drawLetters(canvas);
  }

  void _drawBoardShadow(Canvas canvas) {
    final board = _cellSize * view.puzzle.size;
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
    final board = _cellSize * view.puzzle.size;
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
    for (var i = 1; i < view.puzzle.size; i++) {
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

  void _drawUnusedCells(Canvas canvas) {
    final board = _cellSize * view.puzzle.size;
    final rect = Rect.fromLTWH(_origin.dx, _origin.dy, board, board);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(_boardRadius)),
    );

    final fill = Paint()..color = ZipColors.ink.withValues(alpha: 0.72);
    for (var row = 0; row < view.puzzle.size; row++) {
      for (var col = 0; col < view.puzzle.size; col++) {
        final cell = Cell(row, col);
        if (view.puzzle.hasLetter(cell)) continue;
        canvas.drawRect(_cellRect(cell), fill);
      }
    }
    canvas.restore();
  }

  static const List<Color> pathColors = [
    Color(0xFFFB7185), // rose
    Color(0xFF38BDF8), // sky
    Color(0xFF34D399), // emerald
    Color(0xFFFBBF24), // amber
    Color(0xFFA78BFA), // violet
    Color(0xFF2DD4BF), // teal
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
  ];

  Map<String, PathWordsTarget> _targetsById(PathWordsPuzzle puzzle) {
    return {for (final t in puzzle.targets) t.id: t};
  }

  void _drawPlacedPaths(Canvas canvas) {
    for (final stroke in view.placedPaths) {
      if (stroke.isCorrect) continue;
      final color = pathColors[stroke.colorIndex % pathColors.length];
      for (final cell in stroke.cells) {
        _drawPathCell(canvas, cell: cell, color: color);
      }
    }
  }

  void _drawStartMarkers(Canvas canvas) {
    for (final stroke in view.placedPaths) {
      if (stroke.cells.isEmpty) continue;
      final color = pathColors[stroke.colorIndex % pathColors.length];
      _drawStartRing(canvas, stroke.cells.first, color);
    }

    final targets = _targetsById(view.puzzle);
    for (final entry in view.completedPathsByTargetId.entries) {
      final path = entry.value;
      if (path.isEmpty) continue;
      final target = targets[entry.key];
      final color = pathColors[(target?.colorIndex ?? 0) % pathColors.length];
      _drawStartRing(canvas, path.first, color);
    }

    if (view.activePath.isNotEmpty) {
      _drawStartRing(canvas, view.activePath.first, _activeStrokeColor());
    }
  }

  void _drawCompletedPaths(Canvas canvas) {
    if (view.completedPathsByTargetId.isEmpty) return;

    final targets = _targetsById(view.puzzle);
    final orderedIds = view.puzzle.targets
        .map((t) => t.id)
        .where(view.completedPathsByTargetId.containsKey);

    for (final targetId in orderedIds) {
      final path = view.completedPathsByTargetId[targetId];
      if (path == null || path.isEmpty) continue;
      final target = targets[targetId];
      final colorIndex = target?.colorIndex ?? 0;
      final color = pathColors[colorIndex % pathColors.length];
      for (final cell in path) {
        _drawPathCell(canvas, cell: cell, color: color);
      }
    }
  }

  void _drawCelebrateGlow(Canvas canvas) {
    if (!view.celebrate) return;

    final board = _cellSize * view.puzzle.size;
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

  void _drawActivePath(Canvas canvas) {
    if (view.activePath.isEmpty) return;
    final color = _activeStrokeColor();
    for (final cell in view.activePath) {
      _drawPathCell(canvas, cell: cell, color: color);
    }
  }

  void _drawLiveNeighbor(Canvas canvas) {
    if (!_drawing || _lastPointer == null || view.activePath.isEmpty) return;

    final last = view.activePath.last;
    final origin = _centerOf(last);
    final finger = Offset(_lastPointer!.x, _lastPointer!.y);
    final dx = finger.dx - origin.dx;
    final dy = finger.dy - origin.dy;
    if (dx * dx + dy * dy < 1) return;

    final Cell next;
    final double progress;
    if (dx.abs() >= dy.abs()) {
      next = Cell(last.row, last.col + (dx > 0 ? 1 : -1));
      progress = (dx.abs() / _cellSize).clamp(0.0, 1.0);
    } else {
      next = Cell(last.row + (dy > 0 ? 1 : -1), last.col);
      progress = (dy.abs() / _cellSize).clamp(0.0, 1.0);
    }
    if (progress <= 0.02) return;

    final locked = {
      for (final path in view.completedPathsByTargetId.values) ...path,
      for (final stroke in view.placedPaths) ...stroke.cells,
    };
    if (PathWordsRules.tryExtend(
          puzzle: view.puzzle,
          path: view.activePath,
          candidate: next,
          locked: locked,
        ) ==
        null) {
      return;
    }

    final full = _cellRect(next, inset: _cellSize * 0.1);
    final Rect growing;
    if (next.col > last.col) {
      growing = Rect.fromLTRB(
        full.left,
        full.top,
        full.left + full.width * progress,
        full.bottom,
      );
    } else if (next.col < last.col) {
      growing = Rect.fromLTRB(
        full.right - full.width * progress,
        full.top,
        full.right,
        full.bottom,
      );
    } else if (next.row > last.row) {
      growing = Rect.fromLTRB(
        full.left,
        full.top,
        full.right,
        full.top + full.height * progress,
      );
    } else {
      growing = Rect.fromLTRB(
        full.left,
        full.bottom - full.height * progress,
        full.right,
        full.bottom,
      );
    }

    final color = _activeStrokeColor();
    canvas.save();
    canvas.clipRect(growing);
    _drawPathCell(canvas, cell: next, color: color);
    canvas.restore();
  }

  void _drawHintFlash(Canvas canvas) {
    final path = view.hintPath;
    if (path.isEmpty) return;

    final startedAt = _hintFlashStartedAt ?? DateTime.now();
    final t = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final color = Color.lerp(ZipColors.success, Colors.white, pulse * 0.16)!;
    for (final cell in path) {
      _drawPathCell(canvas, cell: cell, color: color);
    }
  }

  void _drawLetters(Canvas canvas) {
    final completedCells = <Cell>{};
    for (final path in view.completedPathsByTargetId.values) {
      completedCells.addAll(path);
    }
    for (final stroke in view.placedPaths) {
      completedCells.addAll(stroke.cells);
    }
    final activeCells = view.activePath.toSet();

    for (var row = 0; row < view.puzzle.size; row++) {
      for (var col = 0; col < view.puzzle.size; col++) {
        final cell = Cell(row, col);
        final letter = view.puzzle.letterAt(cell);
        if (letter.isEmpty) continue;

        final center = _centerOf(cell);
        final isCompleted = completedCells.contains(cell);
        final isActive = activeCells.contains(cell);
        final isHint = view.hintPath.contains(cell);

        final isFilled = isActive || isCompleted || isHint;
        final color = isFilled ? Colors.white : ZipColors.onInk;

        final tp = TextPainter(
          text: TextSpan(
            text: letter.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: _cellSize * 0.4,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1,
              shadows: isFilled
                  ? const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
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
  }
}
