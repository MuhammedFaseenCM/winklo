import '../../../domain/entities/cell.dart';

/// Encodes a Zip clear's drawn path as the score/progress `board` string:
/// `row,col` cells joined by `;` (e.g. `0,0;0,1;1,1`).
abstract final class ZipBoardCodec {
  static String encode(List<Cell> path) =>
      path.map((c) => '${c.row},${c.col}').join(';');

  /// Null for a missing, empty or malformed [board].
  static List<Cell>? decode(String? board) {
    if (board == null || board.isEmpty) return null;
    final cells = <Cell>[];
    for (final part in board.split(';')) {
      final rc = part.split(',');
      if (rc.length != 2) return null;
      final row = int.tryParse(rc[0]);
      final col = int.tryParse(rc[1]);
      if (row == null || col == null || row < 0 || col < 0) return null;
      cells.add(Cell(row, col));
    }
    return cells;
  }
}
