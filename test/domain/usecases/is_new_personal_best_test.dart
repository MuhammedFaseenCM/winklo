import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/score_repository_impl.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<IsNewPersonalBest> build(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    return IsNewPersonalBest(
      ScoreRepositoryImpl(await SharedPreferences.getInstance()),
    );
  }

  test('a first clear has nothing to beat', () async {
    final isBest = await build({});
    expect(isBest(gameId: 'zip', playId: '20261009', timeSeconds: 40), isFalse);
  });

  test('beating every earlier daily is a new best', () async {
    final isBest = await build({'best_time_zip_daily_20261008': 60});
    expect(isBest(gameId: 'zip', playId: '20261009', timeSeconds: 59), isTrue);
  });

  test('a tie or a slower time is not', () async {
    final isBest = await build({'best_time_zip_daily_20261008': 60});
    expect(isBest(gameId: 'zip', playId: '20261009', timeSeconds: 60), isFalse);
    expect(isBest(gameId: 'zip', playId: '20261009', timeSeconds: 75), isFalse);
  });

  test('the day being cleared never counts against itself', () async {
    // The day's own best is written by the same clear.
    final isBest = await build({
      'best_time_zip_daily_20261008': 60,
      'best_time_zip_daily_20261009': 40,
    });
    expect(isBest(gameId: 'zip', playId: '20261009', timeSeconds: 40), isTrue);
  });
}
