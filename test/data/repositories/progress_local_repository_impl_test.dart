import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
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

    test('removes the announced achievements with the progress', () async {
      final (repo, prefs) = await build({
        'achievements_seen': ['first_clear_zip'],
        'history_uploaded_u1': true,
      });
      await repo.purgeUserProgress();
      expect(prefs.getKeys(), {'history_uploaded_u1'});
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

  group('clear proofs', () {
    const zip = ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]);

    test('are kept per daily mode key as the Worker reads them', () async {
      final (repo, prefs) = await build();
      expect(repo.clearProof('zip', '20261007'), isNull);

      await repo.setClearProof('zip', '20261007', zip);
      await repo.setClearProof(
        'sudoku',
        '20261007',
        const SudokuLeaderboardProof([1, 2]),
      );

      expect(
        jsonDecode(prefs.getString('clear_proof_zip_daily_20261007')!),
        zip.toJson(),
      );
      expect(prefs.getString('clear_proof_sudoku_20261007'), isNotNull);
      expect(repo.clearProof('zip', '20261007')?.toJson(), zip.toJson());
      expect(repo.clearProof('zip', '20261008'), isNull);
      expect(repo.clearProof('sudoku', '20261007')?.toJson(), {
        'grid': [1, 2],
      });
    });

    test('an unreadable proof reads as none', () async {
      final (repo, _) = await build({
        'clear_proof_zip_daily_20261007': '{not json',
        'clear_proof_sudoku_20261007': '{"path":[[0,0]]}',
      });
      expect(repo.clearProof('zip', '20261007'), isNull);
      expect(repo.clearProof('sudoku', '20261007'), isNull);
    });

    test('are per-user progress: purged, stashed and restored', () async {
      final (repo, prefs) = await build();
      await repo.setClearProof('zip', '20261007', zip);

      await repo.stashUserProgress('a');
      await repo.purgeUserProgress();
      expect(repo.clearProof('zip', '20261007'), isNull);
      expect(prefs.getKeys(), {'progress_stash_a'});

      expect(await repo.restoreStashedProgress('a'), isTrue);
      expect(repo.clearProof('zip', '20261007')?.toJson(), zip.toJson());
    });
  });

  group('history upload flag', () {
    test('is unset until set, per uid', () async {
      final (repo, prefs) = await build();
      expect(repo.isHistoryUploaded('u1'), isFalse);
      await repo.setHistoryUploaded('u1');
      expect(repo.isHistoryUploaded('u1'), isTrue);
      expect(repo.isHistoryUploaded('u2'), isFalse);
      expect(prefs.getBool('history_uploaded_u1'), isTrue);
    });

    test('survives a purge and a stash restore', () async {
      final (repo, _) = await build({'best_time_zip_daily_20261007': 12});
      await repo.setHistoryUploaded('u1');
      await repo.stashUserProgress('u1');
      await repo.purgeUserProgress();
      await repo.restoreStashedProgress('u1');
      expect(repo.isHistoryUploaded('u1'), isTrue);
    });

    test('an empty uid is never uploaded', () async {
      final (repo, _) = await build({'history_uploaded_': true});
      expect(repo.isHistoryUploaded(''), isFalse);
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
