import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DateTime clock;

  HintQuotaRepositoryImpl repo({Duration period = PlayPeriod.daily}) {
    return HintQuotaRepositoryImpl(prefs, playPeriod: period, now: () => clock);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 9, 30, 10, 0);
  });

  test('fresh period has full remaining', () {
    expect(repo().remaining('sudoku'), HintQuotaRepository.cap);
  });

  test('tryConsume decrements until zero and does not go negative', () async {
    final r = repo();
    expect(await r.tryConsume('sudoku'), 2);
    expect(await r.tryConsume('sudoku'), 1);
    expect(await r.tryConsume('sudoku'), 0);
    expect(await r.tryConsume('sudoku'), 0);
    expect(r.remaining('sudoku'), 0);
  });

  test('gameIds are independent', () async {
    final r = repo();
    await r.tryConsume('sudoku');
    expect(r.remaining('sudoku'), 2);
    expect(r.remaining('zip'), HintQuotaRepository.cap);
  });

  test('new play period refreshes quota', () async {
    final r = repo(period: PlayPeriod.minute);
    await r.tryConsume('zip');
    expect(r.remaining('zip'), 2);
    clock = clock.add(const Duration(minutes: 1));
    expect(r.remaining('zip'), HintQuotaRepository.cap);
  });

  test('usedFor reads any period by playId', () async {
    final r = repo();
    await r.tryConsume('zip');
    await r.tryConsume('zip');
    expect(r.usedFor('zip', '20260930'), 2);
    expect(r.usedFor('zip', '20260929'), 0);
    expect(r.usedFor('sudoku', '20260930'), 0);
  });

  test('usedFor reads debug minute periods', () async {
    final r = repo(period: PlayPeriod.minute);
    await r.tryConsume('sudoku');
    expect(r.usedFor('sudoku', '202609301000'), 1);
  });

  test('restoreUsed only raises the count', () async {
    final r = repo();
    await r.tryConsume('path_words');
    expect(await r.restoreUsed('path_words', '20260930', 0), isFalse);
    expect(await r.restoreUsed('path_words', '20260930', 1), isFalse);
    expect(r.usedFor('path_words', '20260930'), 1);
    expect(await r.restoreUsed('path_words', '20260930', 2), isTrue);
    expect(r.usedFor('path_words', '20260930'), 2);
    expect(r.remaining('path_words'), 1);
  });

  test(
    'restoreUsed for another period does not touch the current one',
    () async {
      final r = repo();
      expect(await r.restoreUsed('zip', '20260929', 3), isTrue);
      expect(r.usedFor('zip', '20260929'), 3);
      expect(r.remaining('zip'), HintQuotaRepository.cap);
    },
  );

  test('restored count above the cap leaves nothing remaining', () async {
    final r = repo();
    await r.restoreUsed('zip', '20260930', 5);
    expect(r.remaining('zip'), 0);
    expect(await r.tryConsume('zip'), 0);
  });

  test('onChanged fires after each spent hint, never on restoreUsed', () async {
    var calls = 0;
    final r = HintQuotaRepositoryImpl(
      prefs,
      playPeriod: PlayPeriod.daily,
      now: () => clock,
      onChanged: () => calls++,
    );
    await r.tryConsume('zip');
    await r.tryConsume('zip');
    expect(calls, 2);
    await r.tryConsume('zip');
    await r.tryConsume('zip');
    expect(calls, 3, reason: 'an exhausted quota writes nothing');
    expect(await r.restoreUsed('sudoku', '20260930', 2), isTrue);
    expect(calls, 3);
  });
}
