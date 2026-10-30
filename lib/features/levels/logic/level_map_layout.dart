import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/logic/level_map.dart';

/// One world's stretch of the map.
class LevelMapBand {
  const LevelMapBand({required this.world, required this.rect});

  final LevelMapWorld world;
  final Rect rect;

  /// Where this world meets the one below it (the gate); for the bottom
  /// world, the map's bottom edge.
  double get gateY => rect.bottom;
}

/// Where each level sits on the map: Level 1 at the bottom, the path
/// climbing and winding left and right, a wider gap where worlds meet.
class LevelMapLayout {
  LevelMapLayout._({
    required this.size,
    required this.nodes,
    required this.centers,
    required this.bands,
  });

  static const step = 76.0;
  static const gateGap = 180.0;
  static const topPad = 96.0;
  static const bottomPad = 120.0;
  static const amplitudeFraction = 0.24;

  factory LevelMapLayout.of(
    LevelMap map,
    double width, {
    double minHeight = 0,
  }) {
    final worlds = [
      for (final w in map.worlds)
        if (w.nodes.isNotEmpty) w,
    ];
    final count = worlds.fold<int>(0, (sum, w) => sum + w.nodes.length);
    // At least [minHeight] (the viewport), so a short map fills the
    // screen; positions are measured from the bottom, so the extra goes
    // to the top world.
    final height = math.max(
      minHeight,
      topPad +
          bottomPad +
          math.max(0, count - 1) * step +
          math.max(0, worlds.length - 1) * (gateGap - step),
    );
    final cx = width / 2;
    final amp = width * amplitudeFraction;
    final nodes = <LevelMapNode>[];
    final centers = <String, Offset>{};
    final spans = <(double, double)>[];
    var y = height - bottomPad;
    var index = 0;
    for (var w = 0; w < worlds.length; w++) {
      if (w > 0) y -= gateGap - step;
      final firstY = y;
      for (final node in worlds[w].nodes) {
        nodes.add(node);
        centers[node.slot.entry.id] = Offset(
          cx + amp * math.sin(index * math.pi / 2),
          y,
        );
        index++;
        y -= step;
      }
      spans.add((firstY, y + step));
    }
    final bands = <LevelMapBand>[
      for (var w = 0; w < worlds.length; w++)
        LevelMapBand(
          world: worlds[w],
          rect: Rect.fromLTRB(
            0,
            w == worlds.length - 1 ? 0 : (spans[w].$2 + spans[w + 1].$1) / 2,
            width,
            w == 0 ? height : (spans[w].$1 + spans[w - 1].$2) / 2,
          ),
        ),
    ];
    return LevelMapLayout._(
      size: Size(width, height),
      nodes: List.unmodifiable(nodes),
      centers: Map.unmodifiable(centers),
      bands: List.unmodifiable(bands),
    );
  }

  final Size size;

  /// Every level, Level 1 first.
  final List<LevelMapNode> nodes;

  /// Each level's centre, by id.
  final Map<String, Offset> centers;

  /// The worlds that have levels, bottom world first.
  final List<LevelMapBand> bands;
}
