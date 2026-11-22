import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/levels_game_preference_repository_impl.dart';

void main() {
  Future<SharedPreferences> prefs(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  test('reads Zip when unset', () async {
    final repo = LevelsGamePreferenceRepositoryImpl(await prefs({}));
    expect(repo.read(), 'zip');
  });

  test('round-trips a written game', () async {
    final p = await prefs({});
    await LevelsGamePreferenceRepositoryImpl(p).write('path_words');
    expect(LevelsGamePreferenceRepositoryImpl(p).read(), 'path_words');
  });

  test('an unknown stored value reads as Zip', () async {
    final repo = LevelsGamePreferenceRepositoryImpl(
      await prefs({'levels_selected_game': 'sudoku'}),
    );
    expect(repo.read(), 'zip');
  });
}
