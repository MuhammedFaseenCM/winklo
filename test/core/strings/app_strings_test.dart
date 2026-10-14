import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';

void main() {
  group('newPuzzleIn', () {
    test('hours and minutes', () {
      expect(
        AppStrings.newPuzzleIn(const Duration(hours: 6, minutes: 12)),
        'New puzzle in 6h 12m',
      );
    });

    test('rounds a part minute up, so it never says 0m', () {
      expect(
        AppStrings.newPuzzleIn(
          const Duration(hours: 6, minutes: 11, seconds: 1),
        ),
        'New puzzle in 6h 12m',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(seconds: 5)),
        'New puzzle in 1m',
      );
    });

    test('drops zero minutes and zero hours', () {
      expect(
        AppStrings.newPuzzleIn(const Duration(hours: 3)),
        'New puzzle in 3h',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(minutes: 59, seconds: 30)),
        'New puzzle in 1h',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(minutes: 42)),
        'New puzzle in 42m',
      );
    });

    test('says the puzzle is ready once the time is up', () {
      expect(AppStrings.newPuzzleIn(Duration.zero), AppStrings.newPuzzleReady);
      expect(
        AppStrings.newPuzzleIn(const Duration(seconds: -3)),
        AppStrings.newPuzzleReady,
      );
    });
  });
}
