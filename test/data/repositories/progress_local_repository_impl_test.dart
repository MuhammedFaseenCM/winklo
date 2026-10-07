import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/domain/repositories/progress_local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProgressLocalRepositoryImpl, SharedPreferences)> build([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return (ProgressLocalRepositoryImpl(prefs), prefs);
  }

  group('owner uid', () {
    test('is null for legacy data and round-trips', () async {
      final (repo, prefs) = await build();
      expect(repo.ownerUid, isNull);
      await repo.setOwnerUid('u1');
      expect(repo.ownerUid, 'u1');
      expect(prefs.getString('progress_owner_uid'), 'u1');
    });

    test('an empty stored uid reads as unclaimed', () async {
      final (repo, _) = await build({'progress_owner_uid': ''});
      expect(repo.ownerUid, isNull);
    });
  });

  group('pushed signatures', () {
    test('use the spec prefs keys', () async {
      final (repo, prefs) = await build();
      expect(
        repo.pushedSignature(
          ProgressLocalRepository.dayMarkerKey('zip', '20261007'),
        ),
        isNull,
      );
      await repo.setPushedSignature(
        ProgressLocalRepository.dayMarkerKey('zip', '20261007'),
        'a',
      );
      await repo.setPushedSignature(
        ProgressLocalRepository.leaderboardMarkerKey('path_words', '20261007'),
        'b',
      );
      await repo.setPushedSignature(
        ProgressLocalRepository.streakMarkerKey('sudoku'),
        'c',
      );
      expect(prefs.getString('sync_day_zip_20261007'), 'a');
      expect(prefs.getString('sync_lb_path_words_20261007'), 'b');
      expect(prefs.getString('sync_streak_sudoku'), 'c');
      expect(
        repo.pushedSignature(
          ProgressLocalRepository.leaderboardMarkerKey(
            'path_words',
            '20261007',
          ),
        ),
        'b',
      );
    });

    test('overwrite the previous signature', () async {
      final (repo, _) = await build();
      final key = ProgressLocalRepository.streakMarkerKey('zip');
      await repo.setPushedSignature(key, 'old');
      await repo.setPushedSignature(key, 'new');
      expect(repo.pushedSignature(key), 'new');
    });
  });

  group('purgeUserProgress', () {
    test('removes every per-user progress key and nothing else', () async {
      final (repo, prefs) = await build({
        'best_pts_zip_daily_20261007': 900,
        'best_time_zip_daily_20261007': 12,
        'best_time_match_deck1': 30,
        'clear_meta_sudoku_20261007': '{"usedHints":false,"hadMistakes":true}',
        'streak_current_zip': 3,
        'streak_longest_zip': 4,
        'streak_last_zip': '20261007',
        'streak_freeze_zip': false,
        'hints_used_path_words_20261007': 2,
        'in_progress_sudoku_20261007': '{}',
        'sync_day_zip_20261007': 'sig',
        'sync_lb_zip_20261007': 'sig',
        'sync_streak_zip': 'sig',
        'progress_owner_uid': 'u1',
        'tutorial_seen_zip': true,
        'sfx_enabled': false,
        'notif_permission_prompted': true,
        'activity_last_recorded_at_ms': 1,
        'path_words_nouns_20261007': '["cat"]',
      });

      await repo.purgeUserProgress();

      expect(prefs.getKeys(), {
        'progress_owner_uid',
        'tutorial_seen_zip',
        'sfx_enabled',
        'notif_permission_prompted',
        'activity_last_recorded_at_ms',
        'path_words_nouns_20261007',
      });
      expect(repo.ownerUid, 'u1');
    });

    test('purged keys are gone after a reload', () async {
      final (repo, _) = await build({'best_time_sudoku_20261007': 80});
      await repo.purgeUserProgress();
      final reloaded = await SharedPreferences.getInstance();
      await reloaded.reload();
      expect(reloaded.containsKey('best_time_sudoku_20261007'), isFalse);
    });

    test('is a no-op on an empty device', () async {
      final (repo, prefs) = await build();
      await repo.purgeUserProgress();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('stash', () {
    test('survives a purge and restores every type for its uid', () async {
      final (repo, prefs) = await build({
        'best_time_zip_daily_20261007': 12,
        'clear_meta_zip_daily_20261007':
            '{"usedHints":false,"hadMistakes":false}',
        'streak_freeze_zip': false,
        'hints_used_zip_20261007': 2,
        'sync_streak_zip': 'sig',
        'tutorial_seen_zip': true,
      });
      await prefs.setDouble('best_ratio_x', 0.5);
      await prefs.setStringList('in_progress_list', ['a', 'b']);

      await repo.stashUserProgress('a');
      await repo.purgeUserProgress();
      expect(prefs.getInt('best_time_zip_daily_20261007'), isNull);
      // Another account's progress comes and goes in between.
      await prefs.setInt('best_time_zip_daily_20261007', 99);
      await repo.purgeUserProgress();

      expect(await repo.restoreStashedProgress('b'), isFalse);
      expect(await repo.restoreStashedProgress('a'), isTrue);

      expect(prefs.getInt('best_time_zip_daily_20261007'), 12);
      expect(
        prefs.getString('clear_meta_zip_daily_20261007'),
        '{"usedHints":false,"hadMistakes":false}',
      );
      expect(prefs.getBool('streak_freeze_zip'), isFalse);
      expect(prefs.getInt('hints_used_zip_20261007'), 2);
      expect(prefs.getString('sync_streak_zip'), 'sig');
      expect(prefs.getDouble('best_ratio_x'), 0.5);
      expect(prefs.getStringList('in_progress_list'), ['a', 'b']);
      // Consumed: a second restore is a no-op.
      expect(await repo.restoreStashedProgress('a'), isFalse);
      expect(
        prefs.getKeys().where((k) => k.startsWith('progress_stash_')),
        isEmpty,
      );
    });

    test('nothing to stash writes no stash', () async {
      final (repo, prefs) = await build({'tutorial_seen_zip': true});
      await repo.stashUserProgress('a');
      expect(prefs.getKeys(), {'tutorial_seen_zip'});
    });

    test('a corrupt stash is dropped', () async {
      final (repo, prefs) = await build({'progress_stash_a': '{not json'});
      expect(await repo.restoreStashedProgress('a'), isFalse);
      expect(prefs.containsKey('progress_stash_a'), isFalse);
    });
  });
}
