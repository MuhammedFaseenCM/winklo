import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/entities/clear_meta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clean = ClearMeta(usedHints: false, hadMistakes: false);
  const hinted = ClearMeta(usedHints: true, hadMistakes: false);

  Future<(ScoreRepositoryImpl, SharedPreferences)> build([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return (ScoreRepositoryImpl(prefs), prefs);
  }

  test('submitScore improves points and time', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ScoreRepositoryImpl(prefs);

    expect(repo.getBestPoints('zip_x'), 0);
    expect(repo.getBestTimeSeconds('zip_x'), isNull);

    final improved = await repo.submitScore(
      modeKey: 'zip_x',
      points: 100,
      timeSeconds: 20,
    );
    expect(improved, isTrue);
    expect(repo.getBestPoints('zip_x'), 100);
    expect(repo.getBestTimeSeconds('zip_x'), 20);

    final notImproved = await repo.submitScore(
      modeKey: 'zip_x',
      points: 50,
      timeSeconds: 25,
    );
    expect(notImproved, isFalse);
  });

  group('clear meta', () {
    test('is null without flags and for legacy clears', () async {
      final (repo, _) = await build({'best_time_zip_x': 20});
      expect(repo.getClearMeta('zip_x'), isNull);
      await repo.submitScore(modeKey: 'match_x', points: 10);
      expect(repo.getClearMeta('match_x'), isNull);
    });

    test('submitScore stores flags with a new best time', () async {
      final (repo, prefs) = await build();
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 100,
        timeSeconds: 20,
        usedHints: false,
        hadMistakes: false,
      );
      expect(repo.getClearMeta('zip_x'), clean);
      expect(prefs.getString('clear_meta_zip_x'), isNotNull);
    });

    test('submitScore replaces meta when the time improves', () async {
      final (repo, _) = await build();
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 20,
        usedHints: true,
        hadMistakes: false,
      );
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 15,
        usedHints: false,
        hadMistakes: false,
      );
      expect(repo.getClearMeta('zip_x'), clean);
    });

    test('submitScore keeps meta when the time does not improve', () async {
      final (repo, _) = await build();
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 15,
        usedHints: false,
        hadMistakes: false,
      );
      final improved = await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 15,
        usedHints: true,
        hadMistakes: true,
      );
      expect(improved, isFalse);
      expect(repo.getClearMeta('zip_x'), clean);
    });

    test('submitScore fills missing meta for an equal best time', () async {
      final (repo, _) = await build({'best_time_zip_x': 15});
      final improved = await repo.submitScore(
        modeKey: 'zip_x',
        points: 0,
        timeSeconds: 15,
        usedHints: true,
        hadMistakes: false,
      );
      expect(improved, isFalse);
      expect(repo.getClearMeta('zip_x'), hinted);
    });

    test('submitScore never pairs a slower run with the best time', () async {
      final (repo, _) = await build({'best_time_zip_x': 15});
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 0,
        timeSeconds: 30,
        usedHints: true,
        hadMistakes: false,
      );
      expect(repo.getClearMeta('zip_x'), isNull);
    });

    test('submitScore ignores partial flags', () async {
      final (repo, _) = await build();
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 10,
        usedHints: true,
      );
      expect(repo.getClearMeta('zip_x'), isNull);
    });

    test('new best time without flags drops stale meta', () async {
      final (repo, _) = await build();
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 1,
        timeSeconds: 20,
        usedHints: true,
        hadMistakes: false,
      );
      await repo.submitScore(modeKey: 'zip_x', points: 1, timeSeconds: 10);
      expect(repo.getClearMeta('zip_x'), isNull);
    });

    test('corrupt stored meta reads as null', () async {
      for (final raw in ['not json', '[1]', '{"usedHints":1}']) {
        final (repo, _) = await build({'clear_meta_zip_x': raw});
        expect(repo.getClearMeta('zip_x'), isNull, reason: raw);
      }
    });
  });

  group('restoreBest', () {
    test('restores points, time and meta on an empty device', () async {
      final (repo, _) = await build();
      final changed = await repo.restoreBest(
        modeKey: 'sudoku_20261007',
        points: 900,
        timeSeconds: 80,
        meta: hinted,
      );
      expect(changed, isTrue);
      expect(repo.getBestPoints('sudoku_20261007'), 900);
      expect(repo.getBestTimeSeconds('sudoku_20261007'), 80);
      expect(repo.getClearMeta('sudoku_20261007'), hinted);
    });

    test(
      'is improve-only and reports no change when nothing improves',
      () async {
        final (repo, _) = await build({
          'best_pts_zip_x': 900,
          'best_time_zip_x': 20,
          'clear_meta_zip_x': '{"usedHints":false,"hadMistakes":false}',
        });
        final changed = await repo.restoreBest(
          modeKey: 'zip_x',
          points: 800,
          timeSeconds: 25,
          meta: hinted,
        );
        expect(changed, isFalse);
        expect(repo.getBestPoints('zip_x'), 900);
        expect(repo.getBestTimeSeconds('zip_x'), 20);
        expect(repo.getClearMeta('zip_x'), clean);
      },
    );

    test('equal values are not a change', () async {
      final (repo, _) = await build();
      await repo.restoreBest(
        modeKey: 'zip_x',
        points: 5,
        timeSeconds: 9,
        meta: clean,
      );
      expect(
        await repo.restoreBest(
          modeKey: 'zip_x',
          points: 5,
          timeSeconds: 9,
          meta: clean,
        ),
        isFalse,
      );
    });

    test('better time replaces meta', () async {
      final (repo, _) = await build({
        'best_time_zip_x': 20,
        'clear_meta_zip_x': '{"usedHints":true,"hadMistakes":false}',
      });
      expect(
        await repo.restoreBest(modeKey: 'zip_x', timeSeconds: 10, meta: clean),
        isTrue,
      );
      expect(repo.getBestTimeSeconds('zip_x'), 10);
      expect(repo.getClearMeta('zip_x'), clean);
    });

    test('better time without meta drops stale meta', () async {
      final (repo, _) = await build({
        'best_time_zip_x': 20,
        'clear_meta_zip_x': '{"usedHints":true,"hadMistakes":false}',
      });
      expect(await repo.restoreBest(modeKey: 'zip_x', timeSeconds: 10), isTrue);
      expect(repo.getClearMeta('zip_x'), isNull);
    });

    test('fills missing meta for an equal time', () async {
      final (repo, _) = await build({'best_time_zip_x': 20});
      expect(
        await repo.restoreBest(modeKey: 'zip_x', timeSeconds: 20, meta: clean),
        isTrue,
      );
      expect(repo.getClearMeta('zip_x'), clean);
    });

    test('points only leaves time and meta untouched', () async {
      final (repo, _) = await build({'best_pts_zip_x': 10});
      expect(await repo.restoreBest(modeKey: 'zip_x', points: 20), isTrue);
      expect(repo.getBestPoints('zip_x'), 20);
      expect(repo.getBestTimeSeconds('zip_x'), isNull);
      expect(await repo.restoreBest(modeKey: 'zip_x', meta: clean), isFalse);
      expect(repo.getClearMeta('zip_x'), isNull);
    });
  });

  group('onChanged', () {
    test(
      'fires after submitScore writes and not when nothing changes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var calls = 0;
        final repo = ScoreRepositoryImpl(prefs, onChanged: () => calls++);

        await repo.submitScore(modeKey: 'zip_x', points: 100, timeSeconds: 20);
        expect(calls, 1);
        await repo.submitScore(modeKey: 'zip_x', points: 50, timeSeconds: 25);
        expect(calls, 1);
        await repo.submitScore(modeKey: 'zip_x', points: 200);
        expect(calls, 2);
      },
    );

    test('fires when submitScore only fills missing meta', () async {
      SharedPreferences.setMockInitialValues({'best_time_zip_x': 15});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final repo = ScoreRepositoryImpl(prefs, onChanged: () => calls++);

      final improved = await repo.submitScore(
        modeKey: 'zip_x',
        points: 0,
        timeSeconds: 15,
        usedHints: false,
        hadMistakes: false,
      );
      expect(improved, isFalse);
      expect(calls, 1);
    });

    test('restoreBest never fires, even when it changes data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final repo = ScoreRepositoryImpl(prefs, onChanged: () => calls++);

      expect(
        await repo.restoreBest(
          modeKey: 'zip_x',
          points: 900,
          timeSeconds: 12,
          meta: clean,
        ),
        isTrue,
      );
      expect(calls, 0);
    });
  });

  group('clear board', () {
    test('is stored with the first clear and kept on a worse time', () async {
      final (repo, _) = await build();

      await repo.submitScore(
        modeKey: 'zip_x',
        points: 900,
        timeSeconds: 20,
        board: 'a',
      );
      await repo.submitScore(
        modeKey: 'zip_x',
        points: 800,
        timeSeconds: 30,
        board: 'b',
      );

      expect(repo.getClearBoard('zip_x'), 'a');
    });

    test(
      'follows a better time and is dropped by one without a board',
      () async {
        final (repo, _) = await build();
        await repo.submitScore(
          modeKey: 'zip_x',
          points: 900,
          timeSeconds: 20,
          board: 'a',
        );

        await repo.submitScore(
          modeKey: 'zip_x',
          points: 950,
          timeSeconds: 10,
          board: 'b',
        );
        expect(repo.getClearBoard('zip_x'), 'b');

        await repo.submitScore(modeKey: 'zip_x', points: 990, timeSeconds: 5);
        expect(repo.getClearBoard('zip_x'), isNull);
      },
    );

    test('a board-only submit signals a change', () async {
      SharedPreferences.setMockInitialValues({'best_time_zip_x': 20});
      final prefs = await SharedPreferences.getInstance();
      var changes = 0;
      final repo = ScoreRepositoryImpl(prefs, onChanged: () => changes++);

      await repo.submitScore(
        modeKey: 'zip_x',
        points: 0,
        timeSeconds: 20,
        board: 'a',
      );

      expect(repo.getClearBoard('zip_x'), 'a');
      expect(changes, 1);
    });

    test('restore fills a missing board for the same time', () async {
      final (repo, _) = await build({'best_time_zip_x': 20});

      final changed = await repo.restoreBest(
        modeKey: 'zip_x',
        timeSeconds: 20,
        board: 'remote',
      );

      expect(changed, isTrue);
      expect(repo.getClearBoard('zip_x'), 'remote');
    });

    test('restore replaces the board on a time tie', () async {
      final (repo, _) = await build({
        'best_time_zip_x': 20,
        'clear_board_zip_x': 'local',
      });

      await repo.restoreBest(
        modeKey: 'zip_x',
        timeSeconds: 20,
        board: 'remote',
      );

      expect(repo.getClearBoard('zip_x'), 'remote');
    });

    test('restore of a worse time keeps the local board', () async {
      final (repo, _) = await build({
        'best_time_zip_x': 20,
        'clear_board_zip_x': 'local',
      });

      final changed = await repo.restoreBest(
        modeKey: 'zip_x',
        timeSeconds: 30,
        board: 'remote',
      );

      expect(changed, isFalse);
      expect(repo.getClearBoard('zip_x'), 'local');
    });
  });

  group('getBestDailyTimeSeconds', () {
    test('takes the best of that game\'s dailies, skipping a period', () async {
      final (repo, _) = await build({
        'best_time_zip_daily_20261001': 95,
        'best_time_zip_daily_20261002': 61,
        'best_time_zip_daily_20261003': 70,
        'best_time_path_words_20261002': 12,
        'best_time_zip_level_1': 5, // not a daily
      });
      expect(repo.getBestDailyTimeSeconds('zip'), 61);
      expect(
        repo.getBestDailyTimeSeconds('zip', excludingPlayId: '20261002'),
        70,
      );
      expect(repo.getBestDailyTimeSeconds('path_words'), 12);
    });

    test('null when the game has no daily best', () async {
      final (repo, _) = await build({'best_time_zip_daily_20261001': 95});
      expect(repo.getBestDailyTimeSeconds('sudoku'), isNull);
      expect(
        repo.getBestDailyTimeSeconds('zip', excludingPlayId: '20261001'),
        isNull,
      );
    });

    test('sees a best submitted earlier', () async {
      final (repo, _) = await build();
      await repo.submitScore(
        modeKey: 'sudoku_20261001',
        points: 900,
        timeSeconds: 80,
      );
      expect(repo.getBestDailyTimeSeconds('sudoku'), 80);
    });
  });
}
