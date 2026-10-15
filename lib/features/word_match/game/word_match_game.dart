import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/word_match_deck.dart';

typedef WordMatchWinCallback = void Function(int points, int elapsedSeconds);

class WordMatchGame extends FlameGame with DragCallbacks {
  WordMatchGame({
    required this.deck,
    required this.onWin,
    required this.onProgress,
    this.onMatch,
    this.onMiss,
  });

  final WordMatchDeck deck;
  final WordMatchWinCallback onWin;
  final void Function(int matched, int total) onProgress;

  /// One-shot: a pair was matched (not called for the winning pair, which
  /// calls [onWin]).
  final VoidCallback? onMatch;

  /// One-shot: a word was dropped on the wrong partner.
  final VoidCallback? onMiss;

  final List<_WordNode> _nodes = [];
  final Set<String> _matchedIds = {};
  _WordNode? _dragSource;
  Vector2? _dragPos;
  bool _won = false;
  DateTime? _startedAt;
  final _rand = Random(42);

  @override
  Color backgroundColor() => ZipColors.ink;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _startedAt = DateTime.now();
    _spawnNodes();
    onProgress(0, deck.pairs.length);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_nodes.isNotEmpty) {
      _layoutNodes();
    }
  }

  void _spawnNodes() {
    _nodes.clear();
    final words = <({String id, String text, String pairKey})>[];
    for (var i = 0; i < deck.pairs.length; i++) {
      final pair = deck.pairs[i];
      final key = 'pair_$i';
      words.add((id: '${key}_a', text: pair.a, pairKey: key));
      words.add((id: '${key}_b', text: pair.b, pairKey: key));
    }
    words.shuffle(_rand);
    for (final w in words) {
      final node = _WordNode(
        id: w.id,
        text: w.text,
        pairKey: w.pairKey,
        size: Vector2(120, 48),
      );
      _nodes.add(node);
      add(node);
    }
    _layoutNodes();
  }

  void _layoutNodes() {
    if (size.x == 0 || size.y == 0) return;
    final cols = 2;
    final rows = (_nodes.length / cols).ceil();
    final cellW = size.x / cols;
    final cellH = (size.y - 40) / rows;
    for (var i = 0; i < _nodes.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final jitter = Offset(
        (_rand.nextDouble() - 0.5) * 20,
        (_rand.nextDouble() - 0.5) * 16,
      );
      _nodes[i].position = Vector2(
        cellW * col + cellW / 2 + jitter.dx,
        24 + cellH * row + cellH / 2 + jitter.dy,
      );
      _nodes[i].anchor = Anchor.center;
    }
  }

  _WordNode? _hit(Vector2 p) {
    for (final n in _nodes.reversed) {
      if (_matchedIds.contains(n.id) || n.isMatched) continue;
      final half = n.size / 2;
      if ((p.x - n.position.x).abs() <= half.x &&
          (p.y - n.position.y).abs() <= half.y) {
        return n;
      }
    }
    return null;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragSource = _hit(event.localPosition);
    _dragPos = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragPos = event.localEndPosition.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final source = _dragSource;
    final pos = _dragPos;
    _dragSource = null;
    _dragPos = null;
    if (source == null || pos == null || _won) return;
    final target = _hit(pos);
    if (target == null || target.id == source.id) return;

    final ok = source.pairKey == target.pairKey;
    if (ok) {
      _matchedIds.add(source.id);
      _matchedIds.add(target.id);
      source.isMatched = true;
      target.isMatched = true;
      onProgress(_matchedIds.length ~/ 2, deck.pairs.length);
      if (_matchedIds.length < deck.pairs.length * 2) onMatch?.call();
      if (_matchedIds.length == deck.pairs.length * 2) {
        _won = true;
        final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
        final points =
            (800 - elapsed * 4).clamp(50, 800) + deck.pairs.length * 20;
        onWin(points, elapsed);
      }
    } else {
      source.shake();
      target.shake();
      onMiss?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_dragSource != null && _dragPos != null && !_dragSource!.isMatched) {
      final paint = Paint()
        ..color = ZipColors.ember
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(_dragSource!.position.x, _dragSource!.position.y),
        Offset(_dragPos!.x, _dragPos!.y),
        paint,
      );
    }
  }
}

class _WordNode extends PositionComponent {
  _WordNode({
    required this.id,
    required this.text,
    required this.pairKey,
    required super.size,
  });

  final String id;
  final String text;
  final String pairKey;
  bool isMatched = false;
  double _shake = 0;

  void shake() => _shake = 8;

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) {
      _shake = (_shake - dt * 30).clamp(0, 20);
    }
  }

  @override
  void render(Canvas canvas) {
    final dx = _shake > 0 ? sin(_shake * 3) * _shake : 0.0;
    canvas.save();
    canvas.translate(dx, 0);
    final rect = Offset.zero & Size(size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rrect,
      Paint()..color = isMatched ? ZipColors.successSoft : ZipColors.wall,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isMatched ? ZipColors.success : ZipColors.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isMatched ? ZipColors.success : ZipColors.onInk,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.x - 12);
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
    canvas.restore();
  }
}
