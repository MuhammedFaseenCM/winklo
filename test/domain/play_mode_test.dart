import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  final now = DateTime(2026, 10, 15, 9);

  group('fromQuery', () {
    test('daily is the default when mode is missing', () {
      expect(PlayMode.fromQuery(const {}, now: now), PlayMode.daily);
      expect(
        PlayMode.fromQuery(const {'mode': 'daily'}, now: now),
        PlayMode.daily,
      );
    });

    test('an unknown mode is daily, as an older build reads it', () {
      expect(
        PlayMode.fromQuery(const {'mode': 'weekly'}, now: now),
        PlayMode.daily,
      );
    });

    test('archive parses a past day', () {
      final mode = PlayMode.fromQuery(const {
        'mode': 'archive',
        'day': '2026-10-11',
      }, now: now);
      expect(mode, PlayMode.archive(DateTime(2026, 10, 11)));
      expect(mode!.isArchive, isTrue);
      expect(mode.day, DateTime(2026, 10, 11));
    });

    test('archive accepts yesterday', () {
      expect(
        PlayMode.fromQuery(const {
          'mode': 'archive',
          'day': '2026-10-14',
        }, now: now),
        PlayMode.archive(DateTime(2026, 10, 14)),
      );
    });

    test('archive refuses today, the future and days before 11 Oct 2026', () {
      for (final day in [
        '2026-10-15',
        '2026-10-16',
        '2026-10-10',
        '2025-1-1',
      ]) {
        expect(
          PlayMode.fromQuery({'mode': 'archive', 'day': day}, now: now),
          isNull,
          reason: day,
        );
      }
    });

    test('archive refuses a missing or broken day', () {
      expect(PlayMode.fromQuery(const {'mode': 'archive'}, now: now), isNull);
      for (final day in ['', 'yesterday', '2026-13-01', '2026-10-1x']) {
        expect(
          PlayMode.fromQuery({'mode': 'archive', 'day': day}, now: now),
          isNull,
          reason: day,
        );
      }
    });

    test('practice parses', () {
      final mode = PlayMode.fromQuery(const {'mode': 'practice'}, now: now);
      expect(mode, PlayMode.practice);
      expect(mode!.isPractice, isTrue);
    });
  });

  test('location round-trips through fromQuery', () {
    for (final mode in [
      PlayMode.daily,
      PlayMode.practice,
      PlayMode.archive(DateTime(2026, 10, 9)),
      PlayMode.archive(DateTime(2026, 10, 12)),
    ]) {
      final uri = Uri.parse(mode.location('/zip'));
      expect(uri.path, '/zip');
      expect(
        PlayMode.fromQuery(uri.queryParameters, now: now),
        // 9 Oct is before the archive starts.
        mode.day == DateTime(2026, 10, 9) ? isNull : mode,
      );
    }
    expect(PlayMode.daily.location('/sudoku'), '/sudoku');
    expect(
      PlayMode.archive(DateTime(2026, 10, 9)).location('/zip'),
      '/zip?mode=archive&day=2026-10-09',
    );
    expect(
      PlayMode.practice.location('/path-words'),
      '/path-words?mode=practice',
    );
  });

  test('runId is the period id, archive_<day> or practice', () {
    expect(PlayMode.daily.runId(dailyPlayId: '20261015'), '20261015');
    expect(
      PlayMode.archive(DateTime(2026, 10, 12)).runId(dailyPlayId: '20261015'),
      'archive_20261012',
    );
    expect(PlayMode.practice.runId(dailyPlayId: '20261015'), 'practice');
  });

  test(
    'recordKey puts the mode first and never starts with a daily prefix',
    () {
      final archive = PlayMode.archive(DateTime(2026, 10, 12));
      expect(archive.recordKey(GameIds.zip), 'archive_zip_20261012');
      expect(
        archive.recordKey(GameIds.pathWords),
        'archive_path_words_20261012',
      );
      expect(archive.recordKey(GameIds.sudoku), 'archive_sudoku_20261012');
      expect(PlayMode.practice.recordKey(GameIds.zip), 'practice_zip');
      expect(
        PlayMode.practice.recordKey(GameIds.pathWords),
        'practice_path_words',
      );
      expect(PlayMode.practice.recordKey(GameIds.sudoku), 'practice_sudoku');
      for (final mode in [archive, PlayMode.practice]) {
        for (final game in [GameIds.zip, GameIds.pathWords, GameIds.sudoku]) {
          final key = mode.recordKey(game);
          for (final daily in ['zip_daily_', 'path_words_', 'sudoku_']) {
            expect(key.startsWith(daily), isFalse, reason: key);
          }
        }
      }
      expect(() => PlayMode.daily.recordKey(GameIds.zip), throwsStateError);
    },
  );

  test('archive days run from 11 Oct 2026 to yesterday', () {
    expect(PlayMode.archiveFirstDay, DateTime(2026, 10, 11));
    expect(PlayMode.archiveLastDay(now), DateTime(2026, 10, 14));
    expect(PlayMode.isArchiveDay(DateTime(2026, 10, 11), now: now), isTrue);
    expect(PlayMode.isArchiveDay(DateTime(2026, 10, 14, 23), now: now), isTrue);
    expect(PlayMode.isArchiveDay(DateTime(2026, 10, 15), now: now), isFalse);
    expect(PlayMode.isArchiveDay(DateTime(2026, 10, 10), now: now), isFalse);
  });

  test('archive keeps only the calendar day', () {
    final mode = PlayMode.archive(DateTime(2026, 10, 12, 18, 30));
    expect(mode.day, DateTime(2026, 10, 12));
    expect(mode, PlayMode.archive(DateTime(2026, 10, 12)));
    expect(mode.hashCode, PlayMode.archive(DateTime(2026, 10, 12)).hashCode);
    expect(mode == PlayMode.practice, isFalse);
  });

  group('level', () {
    test('parses a level id', () {
      final mode = PlayMode.fromQuery(const {
        'mode': 'level',
        'level': 'zip_1_07',
      }, now: now);
      expect(mode, const PlayMode.level('zip_1_07'));
      expect(mode!.isLevel, isTrue);
      expect(mode.isDaily, isFalse);
      expect(mode.levelId, 'zip_1_07');
    });

    test('accepts a multi-word game id', () {
      expect(
        PlayMode.fromQuery(const {
          'mode': 'level',
          'level': 'path_words_2_13',
        }, now: now),
        const PlayMode.level('path_words_2_13'),
      );
    });

    test('refuses a missing or malformed id', () {
      for (final query in const <Map<String, String>>[
        {'mode': 'level'},
        {'mode': 'level', 'level': ''},
        {'mode': 'level', 'level': 'zip'},
        {'mode': 'level', 'level': '../zip_1_01'},
        {'mode': 'level', 'level': 'Zip_1_07'},
        {'mode': 'level', 'level': 'zip__1_07'},
        {'mode': 'level', 'level': 'zip_01_07'},
        {'mode': 'level', 'level': 'zip_1_7'},
      ]) {
        expect(PlayMode.fromQuery(query, now: now), isNull, reason: '$query');
      }
    });

    test('round-trips through its location', () {
      const mode = PlayMode.level('zip_2_13');
      final uri = Uri.parse(mode.location('/zip'));
      expect(uri.toString(), '/zip?mode=level&level=zip_2_13');
      expect(PlayMode.fromQuery(uri.queryParameters, now: now), mode);
    });

    test('keeps drafts under its own run id and has no record key', () {
      const mode = PlayMode.level('zip_1_07');
      expect(mode.runId(dailyPlayId: '20261015'), 'level_zip_1_07');
      expect(() => mode.recordKey('zip'), throwsStateError);
    });

    test('equality includes the level id', () {
      expect(
        const PlayMode.level('zip_1_01'),
        isNot(const PlayMode.level('zip_1_02')),
      );
      expect(
        const PlayMode.level('zip_1_01').hashCode,
        const PlayMode.level('zip_1_01').hashCode,
      );
      expect(
        const PlayMode.level('zip_1_01').toString(),
        'PlayMode.level(zip_1_01)',
      );
    });
  });
}
