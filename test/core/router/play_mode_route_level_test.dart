import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a valid level link opens the level', () {
    final uri = Uri.parse('/zip?mode=level&level=zip_1_01');
    expect(playModeRedirect(uri, gameId: 'zip'), isNull);
    expect(playModeOf(uri), const PlayMode.level('zip_1_01'));
  });

  test('a malformed level link goes to Levels instead of the daily', () {
    final uri = Uri.parse('/zip?mode=level&level=nope');
    expect(playModeRedirect(uri, gameId: 'zip'), '/levels');
  });

  test('archive redirects are unchanged', () {
    final uri = Uri.parse('/zip?mode=archive&day=2020-01-01');
    expect(playModeRedirect(uri, gameId: 'zip'), '/more/archive?game=zip');
  });

  test('a level link on the wrong game goes to Levels', () {
    for (final (path, gameId, query) in const [
      ('/sudoku', 'sudoku', 'mode=level&level=zip_1_01'),
      ('/path-words', 'path_words', 'mode=level&level=zip_1_01'),
      ('/zip', 'zip', 'mode=level&level=path_words_1_01'),
      ('/zip', 'zip', 'mode=level'),
    ]) {
      final uri = Uri.parse('$path?$query');
      expect(playModeRedirect(uri, gameId: gameId), '/levels', reason: '$uri');
    }
  });

  test('levels locations', () {
    expect(levelsLocation, '/levels');
    expect(levelsOpenLocation('zip_1_02'), '/levels?open=zip_1_02');
  });
}
