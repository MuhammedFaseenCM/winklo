import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_mode_hints.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class _MockHintQuota extends Mock implements HintQuotaRepository {}

void main() {
  late _MockHintQuota daily;
  late PlayModeRecordRepositoryImpl records;
  late HintQuotaForMode forMode;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    records = PlayModeRecordRepositoryImpl(prefs);
    daily = _MockHintQuota();
    forMode = HintQuotaForMode(
      daily: daily,
      archive: ArchiveHintQuotaRepositoryImpl(records),
      practice: UnlimitedHintQuotaRepositoryImpl(),
    );
  });

  test('daily mode uses the daily quota', () {
    expect(identical(forMode(PlayMode.daily), daily), isTrue);
  });

  test(
    'archive counts hints per run without touching the daily quota',
    () async {
      final quota = forMode(PlayMode.archive(DateTime(2026, 10, 12)));
      const run = 'archive_20261012';
      expect(quota.usedFor(GameIds.zip, run), 0);
      for (var n = 1; n <= 5; n++) {
        expect(await quota.consume(GameIds.zip, run), n);
      }
      expect(quota.usedFor(GameIds.zip, run), 5);
      expect(quota.usedFor(GameIds.sudoku, run), 0);
      expect(await quota.restoreUsed(GameIds.zip, run, 9), isFalse);
      await records.clearHints(GameIds.zip, run);
      expect(quota.usedFor(GameIds.zip, run), 0);
      verifyZeroInteractions(daily);
    },
  );

  test('practice counts hints in memory only', () async {
    final quota = forMode(PlayMode.practice);
    for (var n = 1; n <= 20; n++) {
      expect(await quota.consume(GameIds.zip, 'practice'), n);
    }
    expect(quota.usedFor(GameIds.zip, 'practice'), 20);
    expect(
      UnlimitedHintQuotaRepositoryImpl().usedFor(GameIds.zip, 'practice'),
      0,
    );
    verifyZeroInteractions(daily);
  });
}
