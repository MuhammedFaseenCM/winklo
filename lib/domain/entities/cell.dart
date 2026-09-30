class Cell {
  const Cell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '$row,$col';

  static Cell parse(String key) {
    final parts = key.split(',');
    return Cell(int.parse(parts[0]), int.parse(parts[1]));
  }

  static Cell fromJson(dynamic json) {
    if (json is List) {
      return Cell((json[0] as num).toInt(), (json[1] as num).toInt());
    }
    if (json is Map) {
      return Cell((json['row'] as num).toInt(), (json['col'] as num).toInt());
    }
    if (json is String) {
      return Cell.parse(json);
    }
    throw ArgumentError('Invalid cell json: $json');
  }

  List<int> toList() => [row, col];

  Map<String, dynamic> toJson() => {'row': row, 'col': col};
}
