import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

void main() {
  late _MockGetBestPoints points;
  late _MockGetBestTimeSeconds times;
  late NextUnclearedDaily next;

  void cleared(Set<String> modeKeys) {
    when(() => points(any())).thenReturn(0);
    when(() => times(any())).thenAnswer(
      (inv) => modeKeys.contains(inv.positionalArguments.first) ? 60 : null,
    );
  }

  setUp(() {
    points = _MockGetBestPoints();
    times = _MockGetBestTimeSeconds();
    next = NextUnclearedDaily(getBestPoints: points, getBestTimeSeconds: times);
  });

  test('after Zip, suggests Path Words', () {
    cleared({'zip_daily_20261014'});
    expect(
      next(justCleared: GameIds.zip, playId: '20261014'),
      GameIds.pathWords,
    );
  });

  test('skips a game that is already cleared', () {
    cleared({'zip_daily_20261014', 'path_words_20261014'});
    expect(next(justCleared: GameIds.zip, playId: '20261014'), GameIds.sudoku);
  });

  test('wraps around from Sudoku to Zip', () {
    cleared({'sudoku_20261014'});
    expect(next(justCleared: GameIds.sudoku, playId: '20261014'), GameIds.zip);
  });

  test('is null once every daily is cleared', () {
    cleared({'zip_daily_20261014', 'path_words_20261014', 'sudoku_20261014'});
    expect(next(justCleared: GameIds.pathWords, playId: '20261014'), isNull);
  });

  test('a clear counted only by points still counts', () {
    when(() => times(any())).thenReturn(null);
    when(() => points(any())).thenAnswer(
      (inv) => inv.positionalArguments.first == 'path_words_20261014' ? 500 : 0,
    );
    expect(next(justCleared: GameIds.zip, playId: '20261014'), GameIds.sudoku);
  });

  test('only looks at the given day', () {
    cleared({'path_words_20261013'});
    expect(
      next(justCleared: GameIds.zip, playId: '20261014'),
      GameIds.pathWords,
    );
  });

  test('routes open each daily', () {
    expect(NextUnclearedDaily.routeFor(GameIds.zip), '/zip');
    expect(NextUnclearedDaily.routeFor(GameIds.pathWords), '/path-words');
    expect(NextUnclearedDaily.routeFor(GameIds.sudoku), '/sudoku');
  });
}
