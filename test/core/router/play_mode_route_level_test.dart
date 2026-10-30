import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a valid level link opens the level', () {
    final uri = Uri.parse('/zip?mode=level&level=zip_1_01');
    expect(playModeRedirect(uri, gameId: 'zip'), isNull);
    expect(playModeOf(uri), const PlayMode.level('zip_1_01'));
  });

  test('a malformed level link goes Home instead of opening the daily', () {
    final uri = Uri.parse('/zip?mode=level&level=nope');
    expect(playModeRedirect(uri, gameId: 'zip'), '/');
  });

  test('archive redirects are unchanged', () {
    final uri = Uri.parse('/zip?mode=archive&day=2020-01-01');
    expect(playModeRedirect(uri, gameId: 'zip'), '/more/archive?game=zip');
  });
}
