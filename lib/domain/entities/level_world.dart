import 'zip_level.dart';

/// One world of a game's Levels (`level_worlds/{game}_{order}`): its look
/// and its levels in play order.
class LevelWorld {
  const LevelWorld({
    required this.id,
    required this.game,
    required this.order,
    required this.theme,
    required this.levels,
  });

  /// The doc id, `zip_1`.
  final String id;
  final String game;

  /// The world's place on the map, from 1.
  final int order;

  /// `ink`, `metro`, `embroidery`, `neon` or `sparkler`; the map draws a
  /// plain backdrop for anything else.
  final String theme;
  final List<LevelEntry> levels;

  /// Throws [FormatException] when the doc isn't a world.
  factory LevelWorld.fromJson(String id, Map<String, dynamic> json) {
    final order = json['order'];
    final rawLevels = json['levels'];
    if (order is! num || !order.isFinite || rawLevels is! List) {
      throw FormatException('World $id needs an order and a levels list');
    }
    return LevelWorld(
      id: id,
      game: _string(json['game']),
      order: order.toInt(),
      theme: _string(json['theme']),
      levels: [for (final raw in rawLevels) LevelEntry.fromJson(raw)],
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}

/// One level: a Zip board in `ZipLevel.toJson` shape, its stable id and the
/// time that earns its third star.
class LevelEntry {
  const LevelEntry({required this.id, required this.board, this.targetSeconds});

  /// Stable id, `zip_1_07`; progress is keyed by it.
  final String id;
  final Map<String, dynamic> board;

  /// Null when the CMS left it out or set it to 0 or less: the level then
  /// has no time goal.
  final int? targetSeconds;

  /// Throws (TypeError or FormatException) on a malformed board; callers
  /// catch broadly.
  ZipLevel get zipLevel => ZipLevel.fromJson(board, id: id);

  /// Throws [FormatException] when [raw] isn't a level with an id.
  factory LevelEntry.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('A level must be a map');
    final board = Map<String, dynamic>.from(raw);
    final id = board['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('A level needs an id');
    }
    final target = board['targetSeconds'];
    final seconds = target is num && target.isFinite ? target.toInt() : null;
    return LevelEntry(
      id: id,
      board: Map.unmodifiable(board),
      targetSeconds: seconds != null && seconds > 0 ? seconds : null,
    );
  }
}
