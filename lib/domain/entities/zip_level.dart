export 'cell.dart';
export 'wall.dart';

import '../stable_seed.dart';
import 'cell.dart';
import 'daily_special.dart';
import 'wall.dart';

class ZipLevel {
  const ZipLevel({
    required this.id,
    required this.size,
    required this.numbers,
    required this.walls,
    this.order = 0,
    this.solution = const [],
    this.special,
  });

  final String id;
  final int size;
  final Map<Cell, int> numbers;
  final List<Wall> walls;
  final int order;
  final List<Cell> solution;

  /// `weekend` on a weekend special (see [DailySpecial]); null otherwise.
  /// Not part of the fingerprint.
  final String? special;

  bool get isWeekendSpecial => special == DailySpecial.weekend;

  int get maxNumber {
    if (numbers.isEmpty) return 0;
    return numbers.values.reduce((a, b) => a > b ? a : b);
  }

  /// Changes whenever the board does. Numbers and walls are sorted, so the
  /// order Firestore returns them in doesn't matter.
  String get fingerprint {
    final numberKeys = [for (final e in numbers.entries) '${e.key}=${e.value}']
      ..sort();
    final wallKeys = [
      for (final w in walls)
        ([w.a.toString(), w.b.toString()]..sort()).join('|'),
    ]..sort();
    return boardFingerprint(
      'zip|$size|${numberKeys.join(';')}|${wallKeys.join(';')}',
    );
  }

  factory ZipLevel.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawNumbers = Map<String, dynamic>.from(json['numbers'] as Map);
    final numbers = <Cell, int>{};
    for (final entry in rawNumbers.entries) {
      numbers[Cell.parse(entry.key)] = (entry.value as num).toInt();
    }
    final walls = (json['walls'] as List? ?? [])
        .map((e) => Wall.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final rawSolution = json['solution'] as List?;
    final solution = rawSolution != null
        ? rawSolution.map(Cell.fromJson).toList()
        : const <Cell>[];
    return ZipLevel(
      id: id ?? json['id'] as String,
      size: (json['size'] as num).toInt(),
      numbers: numbers,
      walls: walls,
      order: (json['order'] as num?)?.toInt() ?? 0,
      solution: solution,
      special: readDailySpecial(json['special']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'size': size,
    'order': order,
    'numbers': {for (final e in numbers.entries) e.key.toString(): e.value},
    'walls': walls.map((w) => w.toJson()).toList(),
    if (solution.isNotEmpty)
      'solution': solution.map((c) => c.toList()).toList(),
    if (special != null) 'special': special,
  };
}
