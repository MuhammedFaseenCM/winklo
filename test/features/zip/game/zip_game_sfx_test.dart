import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';

void main() {
  ZipLevel level() => ZipLevel(
    id: 'sfx-test',
    size: 2,
    numbers: {const Cell(0, 0): 1, const Cell(1, 0): 2},
    walls: const [],
    solution: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
  );

  ZipGame game({
    required List<SfxId> recorded,
    List<Cell> path = const [],
    void Function()? onWin,
  }) {
    final g = ZipGame(
      level: level(),
      onWin: onWin ?? () {},
      onStatsChanged: (_, _) {},
      onSfx: recorded.add,
    );
    g.path.addAll(path);
    return g;
  }

  test('successful extend plays tap', () {
    final recorded = <SfxId>[];
    final g = game(recorded: recorded);

    g.extendTo(const Cell(0, 0));

    expect(recorded, [SfxId.tap]);
  });

  test('failed extend plays reject', () {
    final recorded = <SfxId>[];
    final g = game(
      recorded: recorded,
      path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
    );

    g.extendTo(const Cell(0, 0));

    expect(recorded, [SfxId.reject]);
  });

  test('LIFO backtrack does not play sfx', () {
    final recorded = <SfxId>[];
    final g = game(
      recorded: recorded,
      path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
    );

    g.extendTo(const Cell(0, 1));

    expect(recorded, isEmpty);
  });

  test('winning extend plays tap then clear once', () {
    final recorded = <SfxId>[];
    var won = false;
    final g = game(
      recorded: recorded,
      path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
      onWin: () => won = true,
    );

    g.extendTo(const Cell(1, 0));

    expect(won, isTrue);
    expect(recorded, [SfxId.tap, SfxId.clear]);
  });

  test('start-at-one tip plays reject', () {
    final recorded = <SfxId>[];
    final g = game(recorded: recorded);

    expect(g.beginStrokeAt(const Cell(0, 1)), isFalse);

    expect(recorded, [SfxId.reject]);
  });
}
