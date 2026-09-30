import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/cell.dart';
import 'sudoku_board_view.dart';

class SudokuGame extends FlameGame with TapCallbacks {
  SudokuGame({required this.view, required this.onCellTap});

  SudokuBoardView view;
  final void Function(Cell) onCellTap;

  double _cellSize = 0;
  Offset _origin = Offset.zero;

  DateTime? _hintFlashStartedAt;
  DateTime? _rejectFlashStartedAt;
  DateTime? _unitFlashStartedAt;
  Set<int> _unitFlashIndices = const {};
  double _celebrateT = 0;
  double _unitFlashT = 0;

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

  void applyView(SudokuBoardView view) {
    final wasCelebrating = this.view.celebrate;
    final oldHint = this.view.hintFlashIndex;
    final oldReject = this.view.rejectFlashIndex;
    final oldUnits = this.view.unitFlashIndices;
    this.view = view;
    if (view.hintFlashIndex != null && view.hintFlashIndex != oldHint) {
      _hintFlashStartedAt = DateTime.now();
    }
    if (view.hintFlashIndex == null) _hintFlashStartedAt = null;
    if (view.rejectFlashIndex != null && view.rejectFlashIndex != oldReject) {
      _rejectFlashStartedAt = DateTime.now();
    }
    if (view.rejectFlashIndex == null) _rejectFlashStartedAt = null;
    if (view.unitFlashIndices.isNotEmpty && view.unitFlashIndices != oldUnits) {
      _unitFlashIndices = view.unitFlashIndices;
      _unitFlashStartedAt = DateTime.now();
      _unitFlashT = 0;
    }
    if (view.unitFlashIndices.isEmpty) {
      _unitFlashIndices = const {};
      _unitFlashStartedAt = null;
      _unitFlashT = 0;
    }
    if (view.celebrate && !wasCelebrating) _celebrateT = 0;
    if (!view.celebrate) _celebrateT = 0;
    if (hasLayout) _layout();
  }

  void _layout() {
    if (!hasLayout) return;
    final padding = 8.0;
    final usable = math.min(size.x, size.y);
    _cellSize = (usable - padding * 2) / view.size;
    final board = _cellSize * view.size;
    _origin = Offset((size.x - board) / 2, (size.y - board) / 2);
  }

  Cell? _cellAt(Vector2 position) {
    final local = Offset(position.x - _origin.dx, position.y - _origin.dy);
    final board = _cellSize * view.size;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= board ||
        local.dy >= board) {
      return null;
    }
    final col = (local.dx / _cellSize).floor();
    final row = (local.dy / _cellSize).floor();
    if (row < 0 || col < 0 || row >= view.size || col >= view.size) return null;
    return Cell(row, col);
  }

  Rect _cellRect(int row, int col, {double inset = 0}) {
    return Rect.fromLTWH(
      _origin.dx + col * _cellSize + inset,
      _origin.dy + row * _cellSize + inset,
      _cellSize - inset * 2,
      _cellSize - inset * 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (view.celebrate) {
      _celebrateT = (_celebrateT + dt).clamp(0.0, 1.0);
    }
    if (_unitFlashStartedAt != null) {
      _unitFlashT += dt;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!view.inputEnabled) return;
    final cell = _cellAt(event.localPosition);
    if (cell == null) return;
    onCellTap(cell);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!hasLayout || _cellSize <= 0) return;

    final board = _cellSize * view.size;
    final boardRect = Rect.fromLTWH(_origin.dx, _origin.dy, board, board);
    final rrect = RRect.fromRectAndRadius(boardRect, const Radius.circular(16));

    canvas.drawRRect(
      rrect,
      Paint()..color = ZipColors.paper.withValues(alpha: 0.92),
    );

    final now = DateTime.now();
    for (var row = 0; row < view.size; row++) {
      for (var col = 0; col < view.size; col++) {
        final index = row * view.size + col;
        _paintCell(canvas, row, col, index, now);
      }
    }

    _paintGridLines(canvas, board);
  }

  void _paintCell(Canvas canvas, int row, int col, int index, DateTime now) {
    final rect = _cellRect(row, col, inset: 1.5);
    final isGiven = index < view.given.length && view.given[index] != 0;
    final value = index < view.grid.length ? view.grid[index] : 0;
    final selected = view.selectedIndex == index;

    if (view.coachExcludedIndices.contains(index)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = ZipColors.success.withValues(alpha: 0.22),
      );
    }
    if (view.coachEvidenceIndices.contains(index)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = ZipColors.success.withValues(alpha: 0.40),
      );
    }
    if (view.coachTargetIndex == index) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = ZipColors.success
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = ZipColors.sky.withValues(alpha: 0.22),
      );
    }

    final hintFlash = view.hintFlashIndex == index;
    if (hintFlash && _hintFlashStartedAt != null) {
      final t = now.difference(_hintFlashStartedAt!).inMilliseconds / 500.0;
      if (t < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = ZipColors.success.withValues(alpha: (1 - t) * 0.45),
        );
      }
    }

    final rejectFlash = view.rejectFlashIndex == index;
    if (rejectFlash && _rejectFlashStartedAt != null) {
      final t = now.difference(_rejectFlashStartedAt!).inMilliseconds / 400.0;
      if (t < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = ZipColors.number.withValues(alpha: (1 - t) * 0.5),
        );
      }
    }

    if (_unitFlashIndices.contains(index) && _unitFlashStartedAt != null) {
      // Soft wash: ease in, gentle hold peak, ease out (no blink).
      const duration = 0.55;
      const staggerStep = 0.035;
      final ordered = _unitFlashIndices.toList()..sort();
      final rank = ordered.indexOf(index).clamp(0, ordered.length - 1);
      final localElapsed = _unitFlashT - rank * staggerStep;
      if (localElapsed > 0 && localElapsed < duration) {
        final t = (localElapsed / duration).clamp(0.0, 1.0);
        // Single smooth envelope (0→1→0); squared for softer edges.
        final envelope = math.sin(t * math.pi);
        final alpha = 0.28 * envelope * envelope;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = ZipColors.success.withValues(alpha: alpha),
        );
      }
    }

    if (view.celebrate) {
      final pulse = 0.12 + 0.1 * math.sin(_celebrateT * math.pi * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = ZipColors.success.withValues(alpha: pulse),
      );
    }

    if (value != 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            color: isGiven ? ZipColors.onInk : ZipColors.sky,
            fontSize: _cellSize * 0.48,
            fontWeight: isGiven ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
      );
      return;
    }

    final cellNotes = index < view.notes.length
        ? view.notes[index]
        : const <int>{};
    if (cellNotes.isEmpty) return;

    final noteSize = _cellSize * 0.18;
    for (final digit in cellNotes) {
      final nr = (digit - 1) ~/ 3;
      final nc = (digit - 1) % 3;
      final tp = TextPainter(
        text: TextSpan(
          text: '$digit',
          style: TextStyle(
            color: ZipColors.inkSoft,
            fontSize: noteSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ox = rect.left + (nc + 0.5) * (rect.width / 3) - tp.width / 2;
      final oy = rect.top + (nr + 0.5) * (rect.height / 2) - tp.height / 2;
      tp.paint(canvas, Offset(ox, oy));
    }
  }

  void _paintGridLines(Canvas canvas, double board) {
    final thin = Paint()
      ..color = ZipColors.outlineQuiet
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = ZipColors.onInk.withValues(alpha: 0.55)
      ..strokeWidth = 2.2;

    for (var i = 0; i <= view.size; i++) {
      final isBoxEdge = i % view.boxCols == 0;
      final paint = isBoxEdge ? thick : thin;
      final x = _origin.dx + i * _cellSize;
      canvas.drawLine(
        Offset(x, _origin.dy),
        Offset(x, _origin.dy + board),
        paint,
      );
    }
    for (var i = 0; i <= view.size; i++) {
      final isBoxEdge = i % view.boxRows == 0;
      final paint = isBoxEdge ? thick : thin;
      final y = _origin.dy + i * _cellSize;
      canvas.drawLine(
        Offset(_origin.dx, y),
        Offset(_origin.dx + board, y),
        paint,
      );
    }
  }
}
