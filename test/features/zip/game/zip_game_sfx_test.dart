import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';

void main() {
  const solution = [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)];

  ZipLevel level({List<Wall> walls = const []}) {
    return ZipLevel(
      id: 'sfx',
      size: 2,
      numbers: {const Cell(0, 0): 1, const Cell(1, 0): 2},
      walls: walls,
      solution: solution,
    );
  }

  ({ZipGame game, List<SfxId> played, List<String> events}) harness({
    List<Wall> walls = const [],
    bool readOnly = false,
  }) {
    final played = <SfxId>[];
    final events = <String>[];
    final game = ZipGame(
      level: level(walls: walls),
      readOnly: readOnly,
      onWin: () => events.add('win'),
      onStatsChanged: (_, _) {},
      onSfx: (id) {
        played.add(id);
        events.add(id.name);
      },
    );
    return (game: game, played: played, events: events);
  }

  test('a longer path plays tap', () {
    final (:game, :played, events: _) = harness();

    game.extendTo(const Cell(0, 0));
    game.extendTo(const Cell(0, 1));

    expect(played, [SfxId.tap, SfxId.tap]);
    expect(game.path, const [Cell(0, 0), Cell(0, 1)]);
  });

  test('an illegal extend plays reject', () {
    final (:game, :played, events: _) = harness(
      walls: const [Wall(Cell(0, 0), Cell(0, 1))],
    );

    game.extendTo(const Cell(0, 0));
    played.clear();
    game.extendTo(const Cell(0, 1));

    expect(played, [SfxId.reject]);
    expect(game.path, const [Cell(0, 0)]);
  });

  test('staying on the tip and LIFO pops play nothing', () {
    final (:game, :played, events: _) = harness();
    game.path.addAll(const [Cell(0, 0), Cell(0, 1)]);

    game.extendTo(const Cell(0, 1));
    game.extendTo(const Cell(0, 0));

    expect(played, isEmpty);
    expect(game.path, const [Cell(0, 0)]);
  });

  test('the winning cell plays clear once before onWin', () {
    final (:game, :played, :events) = harness();

    for (final cell in solution) {
      game.extendTo(cell);
    }
    game.extendTo(const Cell(0, 1));

    expect(played, [SfxId.tap, SfxId.tap, SfxId.tap, SfxId.tap, SfxId.clear]);
    expect(events, ['tap', 'tap', 'tap', 'tap', 'clear', 'win']);
  });

  test('starting away from 1 plays reject', () {
    final (:game, :played, events: _) = harness();

    expect(game.beginStrokeAt(const Cell(1, 0)), isFalse);

    expect(played, [SfxId.reject]);
    expect(game.path, isEmpty);
  });

  test('read-only play is silent', () {
    final (:game, :played, events: _) = harness(readOnly: true);

    game.extendTo(const Cell(0, 0));
    game.beginStrokeAt(const Cell(1, 0));

    expect(played, isEmpty);
  });
}
