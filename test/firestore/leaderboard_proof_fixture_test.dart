import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/logic/path_validator.dart';

/// workers/leaderboard/src/fixtures/app_proofs.json holds puzzle docs and the
/// proofs a clear of each sends; the Worker's fixture.test.ts checks it
/// accepts them, and this checks the app builds exactly those proofs.
void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture =
        jsonDecode(
              File(
                'workers/leaderboard/src/fixtures/app_proofs.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  Map<String, dynamic> puzzle(String game) =>
      Map<String, dynamic>.from(fixture[game]['puzzle'] as Map);

  Object? proof(String game) => fixture[game]['proof'];

  test('Zip: the drawn path of a clear', () {
    final level = ZipLevel.fromJson(puzzle('zip'), id: 'daily_20261015');
    expect(PathValidator(level).isWon(level.solution), isTrue);
    expect(ZipLeaderboardProof(level.solution).toJson(), proof('zip'));
  });

  test('Sudoku: the finished grid', () {
    final sudoku = SudokuPuzzle.fromJson(
      puzzle('sudoku'),
      id: 'daily_20261015',
    );
    expect(SudokuLeaderboardProof(sudoku.solution).toJson(), proof('sudoku'));
  });

  test('Path Words: each found word as traced', () {
    final board = PathWordsPuzzle.fromJson(
      puzzle('path_words'),
      id: 'daily_20261015',
    );
    final built = PathWordsLeaderboardProof.fromRun(
      puzzle: board,
      completedTargetIds: {for (final t in board.targets) t.id},
      placedPaths: [
        for (final t in board.targets)
          PathWordsStroke(cells: t.path, colorIndex: 0, targetId: t.id),
      ],
    );
    expect(built.toJson(), proof('path_words'));
  });
}
