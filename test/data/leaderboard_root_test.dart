import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/leaderboard_root.dart';

void main() {
  group('leaderboardRootCollection', () {
    test('returns leaderboards_debug when isDebugMode is true', () {
      expect(
        leaderboardRootCollection(isDebugMode: true),
        'leaderboards_debug',
      );
    });

    test('returns leaderboards when isDebugMode is false', () {
      expect(leaderboardRootCollection(isDebugMode: false), 'leaderboards');
    });
  });
}
