import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/hint_quota_repository_impl.dart';

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

  test('fresh period has no hints spent', () {
    expect(repo().usedFor('sudoku', today), 0);
  });

  test('consume counts every hint, with no cap', () async {
    final r = repo();
    for (var n = 1; n <= 8; n++) {
      expect(await r.consume('sudoku', today), n);
    }
    expect(r.usedFor('sudoku', today), 8);
  });

  test('gameIds are independent', () async {
    final r = repo();
    await r.consume('sudoku', today);
    expect(r.usedFor('sudoku', today), 1);
    expect(r.usedFor('zip', today), 0);
  });

  test('each play period counts its own hints', () async {
    final r = repo();
    await r.consume('zip', yesterday);
    expect(r.usedFor('zip', yesterday), 1);
    expect(r.usedFor('zip', today), 0);
  });

  test(
    'a run finished after midnight spends its own period, not the next',
    () async {
      final r = repo();
      await r.consume('path_words', yesterday);
      // Still yesterday's run after the clock passed midnight.
      expect(await r.consume('path_words', yesterday), 2);
      expect(r.usedFor('path_words', today), 0);
    },
  );

  test('usedFor reads debug minute periods', () async {
    final r = repo();
    await r.consume('sudoku', '202609301000');
    expect(r.usedFor('sudoku', '202609301000'), 1);
  });

  test('restoreUsed only raises the count', () async {
    final r = repo();
    await r.consume('path_words', today);
    expect(await r.restoreUsed('path_words', today, 0), isFalse);
    expect(await r.restoreUsed('path_words', today, 1), isFalse);
    expect(r.usedFor('path_words', today), 1);
    expect(await r.restoreUsed('path_words', today, 2), isTrue);
    expect(r.usedFor('path_words', today), 2);
    expect(await r.consume('path_words', today), 3);
  });

  test(
    'restoreUsed for another period does not touch the current one',
    () async {
      final r = repo();
      expect(await r.restoreUsed('zip', yesterday, 3), isTrue);
      expect(r.usedFor('zip', yesterday), 3);
      expect(r.usedFor('zip', today), 0);
    },
  );

  test('onChanged fires after each spent hint, never on restoreUsed', () async {
    var calls = 0;
    final r = HintQuotaRepositoryImpl(prefs, onChanged: () => calls++);
    await r.consume('zip', today);
    await r.consume('zip', today);
    await r.consume('zip', today);
    await r.consume('zip', today);
    expect(calls, 4);
    expect(await r.restoreUsed('sudoku', today, 2), isTrue);
    expect(calls, 4);
  });
}
