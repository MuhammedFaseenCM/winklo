import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    forMode = HintQuotaForMode(daily: daily, records: records);
  });

  test('daily mode uses the daily quota', () {
    expect(identical(forMode(PlayMode.daily), daily), isTrue);
  });

  test('archive allows 3 per run without touching the daily quota', () async {
    final quota = forMode(PlayMode.archive(DateTime(2026, 10, 12)));
    const run = 'archive_20261012';
    expect(quota.remaining(GameIds.zip, run), 3);
    expect(await quota.tryConsume(GameIds.zip, run), 2);
    expect(await quota.tryConsume(GameIds.zip, run), 1);
    expect(await quota.tryConsume(GameIds.zip, run), 0);
    expect(await quota.tryConsume(GameIds.zip, run), 0);
    expect(quota.usedFor(GameIds.zip, run), 3);
    expect(quota.remaining(GameIds.sudoku, run), 3);
    expect(await quota.restoreUsed(GameIds.zip, run, 3), isFalse);
    await records.clearHints(GameIds.zip, run);
    expect(quota.remaining(GameIds.zip, run), 3);
    verifyZeroInteractions(daily);
  });

  test('practice never runs out', () async {
    final quota = forMode(PlayMode.practice);
    var before = quota.remaining(GameIds.zip, 'practice');
    for (var i = 0; i < 20; i++) {
      final after = await quota.tryConsume(GameIds.zip, 'practice');
      expect(after, lessThan(before));
      expect(after, greaterThan(0));
      before = after;
    }
    expect(UnlimitedHintQuota.isUnlimited(quota), isTrue);
    expect(UnlimitedHintQuota.isUnlimited(daily), isFalse);
    verifyZeroInteractions(daily);
  });
}
