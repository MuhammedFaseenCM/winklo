import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/haptics/haptics_service.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';

void main() {
  // 1 → (0,1) → 2 → 3: a plain cell, then each number.
  const solution = [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)];
  final level = ZipLevel(
    id: 'haptics',
    size: 2,
    numbers: {const Cell(0, 0): 1, const Cell(1, 1): 2, const Cell(1, 0): 3},
    walls: const [],
    solution: solution,
  );

  ({ZipGame game, List<HapticKind> felt}) harness({bool readOnly = false}) {
    final felt = <HapticKind>[];
    final game = ZipGame(
      level: level,
      readOnly: readOnly,
      onWin: () {},
      onStatsChanged: (_, _) {},
      onHaptic: felt.add,
    );
    return (game: game, felt: felt);
  }

  test('ticks for each cell, a stronger one at each number and a win', () {
    final (:game, :felt) = harness();

    for (final cell in solution) {
      game.extendTo(cell);
    }

    expect(felt, [
      HapticKind.tick,
      HapticKind.tick,
      HapticKind.success,
      HapticKind.win,
    ]);
  });

  test('backing up or a blocked move stays still', () {
    final (:game, :felt) = harness();
    game.extendTo(const Cell(0, 0));
    game.extendTo(const Cell(0, 1));
    felt.clear();

    game.extendTo(const Cell(0, 0)); // Pops the tip.
    game.extendTo(const Cell(1, 1)); // Not next to the tip.

    expect(felt, isEmpty);
  });

  test('review mode never vibrates', () {
    final (:game, :felt) = harness(readOnly: true);
    for (final cell in solution) {
      game.extendTo(cell);
    }
    expect(felt, isEmpty);
  });
}
