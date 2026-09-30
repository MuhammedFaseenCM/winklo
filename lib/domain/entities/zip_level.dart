export 'cell.dart';
export 'wall.dart';

import 'cell.dart';
import 'wall.dart';

class ZipLevel {
  const ZipLevel({
    required this.id,
    required this.size,
    required this.numbers,
    required this.walls,
    this.order = 0,
    this.solution = const [],
  });

  final String id;
  final int size;
  final Map<Cell, int> numbers;
  final List<Wall> walls;
  final int order;
  final List<Cell> solution;

  int get maxNumber {
    if (numbers.isEmpty) return 0;
    return numbers.values.reduce((a, b) => a > b ? a : b);
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
  };
}
