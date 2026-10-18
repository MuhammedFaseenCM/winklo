import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/features/zip/logic/zip_hints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const solution = [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2), Cell(1, 1)];

  test('empty path skips the start cell and reveals the next one', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: 1,
      ),
      const [Cell(0, 1)],
    );
  });

  test('later hints keep connected cells after the start', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: 2,
      ),
      const [Cell(0, 1), Cell(0, 2)],
    );
  });

  test('drawing a hinted cell does not reveal extra cells ahead', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: const [Cell(0, 0), Cell(0, 1)],
        fromIndex: 1,
        revealLength: 2,
      ),
      const [Cell(0, 2)],
    );
  });

  test('a wrong path still shows the frozen hint cells', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: const [Cell(0, 0), Cell(1, 0)],
        fromIndex: 1,
        revealLength: 1,
      ),
      const [Cell(0, 1)],
    );
  });

  test('startIndex skips 1 when the path is empty', () {
    expect(ZipHints.startIndex(solution: solution, path: const []), 1);
  });

  test('startIndex is the matching prefix length', () {
    expect(
      ZipHints.startIndex(
        solution: solution,
        path: const [Cell(0, 0), Cell(0, 1)],
      ),
      2,
    );
  });

  test('revealLength 0 shows nothing', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: 0,
      ),
      isEmpty,
    );
  });

  test('does not reveal past the end of the solution', () {
    expect(
      ZipHints.revealedCells(
        solution: solution,
        path: solution.sublist(0, 4),
        fromIndex: 4,
        revealLength: 3,
      ),
      [solution.last],
    );
  });

  test('canReveal is false when nothing new would show', () {
    expect(
      ZipHints.canReveal(
        solution: solution,
        path: solution,
        fromIndex: solution.length,
        revealLength: 0,
      ),
      isFalse,
    );
  });

  test('canReveal is false once every remaining cell is already shown', () {
    // Hints now cost time, so one that shows nothing new must not be offered.
    expect(
      ZipHints.canReveal(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: solution.length - 1,
      ),
      isFalse,
    );
    expect(
      ZipHints.canReveal(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: solution.length - 2,
      ),
      isTrue,
    );
  });

  test('a new hint after catching up starts from the current cell', () {
    expect(
      ZipHints.afterHint(
        solution: solution,
        path: const [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
        fromIndex: 1,
        revealLength: 1,
      ),
      (fromIndex: 3, revealLength: 1),
    );
  });

  test('stacking hints without progress keeps the original start', () {
    expect(
      ZipHints.afterHint(
        solution: solution,
        path: const [],
        fromIndex: 1,
        revealLength: 1,
      ),
      (fromIndex: 1, revealLength: 2),
    );
  });
}
