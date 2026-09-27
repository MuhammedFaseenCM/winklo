import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/sudoku/sudoku_scoring.dart';

void main() {
  test('pointsForElapsed clamps and scales', () {
    expect(SudokuScoring.pointsForElapsed(0), 1000);
    expect(SudokuScoring.pointsForElapsed(12), 940);
    expect(SudokuScoring.pointsForElapsed(10000), 50);
  });
}
