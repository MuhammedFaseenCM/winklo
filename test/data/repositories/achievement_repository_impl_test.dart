import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/achievement_repository_impl.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AchievementRepositoryImpl, SharedPreferences)> build([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return (AchievementRepositoryImpl(prefs), prefs);
  }

  test('nothing is seen on a new device', () async {
    final (repo, _) = await build();
    expect(repo.seenIds(), isEmpty);
  });

  test('marking adds to the stored set', () async {
    final (repo, prefs) = await build();
    await repo.markSeen(['perfect_day', 'first_clear_zip']);
    await repo.markSeen(['first_clear_zip', 'streak_7_zip']);
    expect(repo.seenIds(), {'perfect_day', 'first_clear_zip', 'streak_7_zip'});
    expect(prefs.getStringList('achievements_seen'), [
      'first_clear_zip',
      'perfect_day',
      'streak_7_zip',
    ]);
  });

  test('the seen set is purged with the user progress', () async {
    final (repo, prefs) = await build();
    await repo.markSeen(['perfect_day']);
    await ProgressLocalRepositoryImpl(prefs).purgeUserProgress();
    expect(repo.seenIds(), isEmpty);
  });
}
