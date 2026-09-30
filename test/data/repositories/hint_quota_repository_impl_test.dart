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
}
