import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  const today = '20260930';
  const yesterday = '20260929';

  HintQuotaRepositoryImpl repo() => HintQuotaRepositoryImpl(prefs);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('fresh period has full remaining', () {
    expect(repo().remaining('sudoku', today), HintQuotaRepository.cap);
  });

  test('tryConsume decrements until zero and does not go negative', () async {
    final r = repo();
    expect(await r.tryConsume('sudoku', today), 2);
    expect(await r.tryConsume('sudoku', today), 1);
    expect(await r.tryConsume('sudoku', today), 0);
    expect(await r.tryConsume('sudoku', today), 0);
    expect(r.remaining('sudoku', today), 0);
  });

  test('gameIds are independent', () async {
    final r = repo();
    await r.tryConsume('sudoku', today);
    expect(r.remaining('sudoku', today), 2);
    expect(r.remaining('zip', today), HintQuotaRepository.cap);
  });

  test('each play period has its own quota', () async {
    final r = repo();
    await r.tryConsume('zip', yesterday);
    expect(r.remaining('zip', yesterday), 2);
    expect(r.remaining('zip', today), HintQuotaRepository.cap);
  });

  test(
    'a run finished after midnight spends its own period, not the next',
    () async {
      final r = repo();
      await r.tryConsume('path_words', yesterday);
      await r.tryConsume('path_words', yesterday);
      // Still yesterday's run after the clock passed midnight.
      expect(await r.tryConsume('path_words', yesterday), 0);
      expect(await r.tryConsume('path_words', yesterday), 0);
      expect(r.remaining('path_words', today), HintQuotaRepository.cap);
    },
  );

  test('usedFor reads any period by playId', () async {
    final r = repo();
    await r.tryConsume('zip', today);
    await r.tryConsume('zip', today);
    expect(r.usedFor('zip', today), 2);
    expect(r.usedFor('zip', yesterday), 0);
    expect(r.usedFor('sudoku', today), 0);
  });

  test('usedFor reads debug minute periods', () async {
    final r = repo();
    await r.tryConsume('sudoku', '202609301000');
    expect(r.usedFor('sudoku', '202609301000'), 1);
  });

  test('restoreUsed only raises the count', () async {
    final r = repo();
    await r.tryConsume('path_words', today);
    expect(await r.restoreUsed('path_words', today, 0), isFalse);
    expect(await r.restoreUsed('path_words', today, 1), isFalse);
    expect(r.usedFor('path_words', today), 1);
    expect(await r.restoreUsed('path_words', today, 2), isTrue);
    expect(r.usedFor('path_words', today), 2);
    expect(r.remaining('path_words', today), 1);
  });

  test(
    'restoreUsed for another period does not touch the current one',
    () async {
      final r = repo();
      expect(await r.restoreUsed('zip', yesterday, 3), isTrue);
      expect(r.usedFor('zip', yesterday), 3);
      expect(r.remaining('zip', today), HintQuotaRepository.cap);
    },
  );

  test('restored count above the cap leaves nothing remaining', () async {
    final r = repo();
    await r.restoreUsed('zip', today, 5);
    expect(r.remaining('zip', today), 0);
    expect(await r.tryConsume('zip', today), 0);
  });

  test('onChanged fires after each spent hint, never on restoreUsed', () async {
    var calls = 0;
    final r = HintQuotaRepositoryImpl(prefs, onChanged: () => calls++);
    await r.tryConsume('zip', today);
    await r.tryConsume('zip', today);
    expect(calls, 2);
    await r.tryConsume('zip', today);
    await r.tryConsume('zip', today);
    expect(calls, 3, reason: 'an exhausted quota writes nothing');
    expect(await r.restoreUsed('sudoku', today, 2), isTrue);
    expect(calls, 3);
  });
}
