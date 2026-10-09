import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/sudoku/sudoku_hint_coach.dart';

/// 6×6, boxes 2×3. Middle-right box (rows 2–3, cols 3–5):
/// - 6 at index 12 (r2c0) blocks row 2
/// - 6 at index 33 (r5c3) blocks col 3
/// - digit 3 at index 23 (r3c5)
/// → only index 22 (r3c4) can be 6 in that box.
List<int> regionLastRemainingGrid() {
  return <int>[
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0,
    6, 0, 0, 0, 0, 0, // index 12 = 6
    0, 0, 0, 0, 0, 3, // index 22 empty target; 23 = 3
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 6, 0, 0, // index 33 = 6
  ];
}

SudokuPuzzle puzzleFor(List<int> grid) {
  // solution unused by coach; provide zeros + size metadata
  return SudokuPuzzle(
    id: 't',
    dateId: 't',
    given: List<int>.filled(36, 0),
    solution: List<int>.filled(36, 1),
    difficulty: SudokuDifficulty.easy,
  );
}

void main() {
  test('finds last-remaining region for digit 6', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(puzzle: puzzleFor(grid), grid: grid);
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingRegion);
    expect(hint.targetIndex, 22);
    expect(hint.digit, 6);
    expect(hint.evidenceIndices, containsAll(<int>[12, 33]));
    expect(hint.excludedIndices.contains(22), isFalse);
  });

  test('prefers selected cell when it has a teachable move', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 22,
    );
    expect(hint!.targetIndex, 22);
  });

  test('falls back when preferred cell has no teachable move', () {
    final grid = regionLastRemainingGrid();
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 0, // empty but not the region single
    );
    expect(hint, isNotNull);
    expect(hint!.targetIndex, 22);
  });

  test('naked single when preferred cell has only one candidate', () {
    // Cell 0: peers eliminate every digit except 5.
    // Row 0 has 1,2,3,4 elsewhere; col 0 has 6 below — leaving only 5.
    // Prefer index 0 so scan does not pick a last-remaining elsewhere first.
    final grid = <int>[
      0, 1, 2, 3, 4, 0, // r0: cell0 empty; 1–4 present in row
      6, 0, 0, 0, 0, 0, // r1: 6 in col0
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0,
    ];
    // Box (0,0) also needs digit conflicts for naked single of 5:
    // already have 1,2 in row and 6 in box via (1,0). Add 3,4 already in row.
    // Missing elimination of nothing else — candidates at 0 are {5} if box
    // doesn't also need more. Digits in box rows0-1 cols0-2: 1,2 at r0c1-2, 6 at r1c0.
    // Still missing peer that blocks nothing for 5. candidates = {5} ✓
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 0,
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.nakedSingle);
    expect(hint.targetIndex, 0);
    expect(hint.digit, 5);
  });

  test('last-remaining row', () {
    // Row 0: only col5 can hold 6. Top-right box still has r1c5 as a second 6
    // candidate so region last-remaining does not apply at index 5.
    final grid = List<int>.filled(36, 0);
    grid[12] = 6; // r2c0 blocks col0
    grid[13] = 6; // r2c1 blocks col1
    grid[20] = 6; // r3c2 blocks col2
    grid[15] = 6; // r2c3 blocks col3
    grid[22] = 6; // r3c4 blocks col4
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 5,
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingRow);
    expect(hint.targetIndex, 5);
    expect(hint.digit, 6);
  });

  test('last-remaining column', () {
    final grid = List<int>.filled(36, 0);
    // Col 0: only r5c0 can hold 6. Bottom-left box also allows r4c2 for 6 so
    // region last-remaining does not apply at index 30.
    grid[1] = 6; // r0c1 blocks row0
    grid[7] = 6; // r1c1 blocks row1
    grid[15] = 6; // r2c3 blocks row2
    grid[21] = 6; // r3c3 blocks row3
    grid[29] = 6; // r4c5 blocks row4
    final hint = SudokuHintCoach.find(
      puzzle: puzzleFor(grid),
      grid: grid,
      preferredIndex: 30, // r5c0
    );
    expect(hint, isNotNull);
    expect(hint!.technique, SudokuHintTechnique.lastRemainingCol);
    expect(hint.targetIndex, 30);
    expect(hint.digit, 6);
  });

  test('returns null when no v1 technique applies', () {
    final grid = List<int>.filled(36, 0);
    expect(SudokuHintCoach.find(puzzle: puzzleFor(grid), grid: grid), isNull);
  });

  group('findMistake', () {
    // Solution: every row reads 1..6 shifted; only the values matter here.
    final solution = [for (var i = 0; i < 36; i++) (i % 6) + 1];
    final given = List<int>.filled(36, 0)..[0] = 1;
    final puzzle = SudokuPuzzle(
      id: 't',
      dateId: 't',
      given: given,
      solution: solution,
      difficulty: SudokuDifficulty.easy,
    );

    test('null when every filled cell matches the solution', () {
      final grid = List<int>.from(given)
        ..[7] = 2
        ..[20] = 3;
      expect(SudokuHintCoach.findMistake(puzzle: puzzle, grid: grid), isNull);
    });

    test('points at the row of the first wrong digit', () {
      final grid = List<int>.from(given)
        ..[9] =
            2 // r1c3: should be 4
        ..[20] = 5; // r3c2: should be 3
      final hint = SudokuHintCoach.findMistake(puzzle: puzzle, grid: grid)!;
      expect(hint.technique, SudokuHintTechnique.mistakeInRow);
      expect(hint.row, 1);
      expect(hint.targetIndex, isNull);
      expect(hint.evidenceIndices, {6, 7, 8, 9, 10, 11});
    });

    test('prefers the selected cell when it is the wrong one', () {
      final grid = List<int>.from(given)
        ..[9] = 2
        ..[20] = 5;
      final hint = SudokuHintCoach.findMistake(
        puzzle: puzzle,
        grid: grid,
        preferredIndex: 20,
      )!;
      expect(hint.row, 3);
    });

    test('isResolved once the row holds no wrong digit', () {
      final wrong = List<int>.from(given)..[9] = 2;
      final hint = SudokuHintCoach.findMistake(puzzle: puzzle, grid: wrong)!;
      expect(
        SudokuHintCoach.isResolved(hint, puzzle: puzzle, grid: wrong),
        isFalse,
      );
      final erased = List<int>.from(wrong)..[9] = 0;
      expect(
        SudokuHintCoach.isResolved(hint, puzzle: puzzle, grid: erased),
        isTrue,
      );
    });
  });

  test('isResolved for a placement hint checks the target digit', () {
    final grid = regionLastRemainingGrid();
    final puzzle = puzzleFor(grid);
    final hint = SudokuHintCoach.find(puzzle: puzzle, grid: grid)!;
    expect(
      SudokuHintCoach.isResolved(hint, puzzle: puzzle, grid: grid),
      isFalse,
    );
    final placed = List<int>.from(grid)..[hint.targetIndex!] = hint.digit;
    expect(
      SudokuHintCoach.isResolved(hint, puzzle: puzzle, grid: placed),
      isTrue,
    );
  });
}
