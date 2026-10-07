import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/progress_collections.dart';

void main() {
  group('progressCollections', () {
    test('returns the _debug twins when isDebugMode is true', () {
      final names = progressCollections(isDebugMode: true);
      expect(names.gameDays, 'game_days_debug');
      expect(names.gameStreaks, 'game_streaks_debug');
    });

    test('returns release names when isDebugMode is false', () {
      final names = progressCollections(isDebugMode: false);
      expect(names.gameDays, 'game_days');
      expect(names.gameStreaks, 'game_streaks');
    });
  });
}
