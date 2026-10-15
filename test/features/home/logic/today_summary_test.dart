import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/features/home/cubit/home_state.dart';
import 'package:winklo/features/home/logic/today_summary.dart';

void main() {
  final idle = HomeState.initial(DateTime(2026, 10, 15));

  group('TodaySummary.of', () {
    test('is null when nothing is cleared today', () {
      expect(TodaySummary.of(idle), isNull);
    });

    test('counts the clears and adds up their times', () {
      final summary = TodaySummary.of(
        idle.copyWith(bestTimeSeconds: 72, sudokuBestTimeSeconds: 149),
      );

      expect(summary, const TodaySummary(cleared: 2, totalSeconds: 221));
      expect(summary!.isPerfectDay, isFalse);
    });

    test('a clear without a stored time counts but adds no time', () {
      final summary = TodaySummary.of(
        idle.copyWith(pathWordsBestPoints: 800, sudokuBestTimeSeconds: 61),
      );

      expect(summary, const TodaySummary(cleared: 2, totalSeconds: 61));
    });

    test('has no total when no clear has a time', () {
      final summary = TodaySummary.of(idle.copyWith(bestPoints: 900));

      expect(summary, const TodaySummary(cleared: 1));
    });

    test('all three cleared is a perfect day', () {
      final summary = TodaySummary.of(
        idle.copyWith(
          bestTimeSeconds: 60,
          pathWordsBestTimeSeconds: 90,
          sudokuBestTimeSeconds: 71,
        ),
      );

      expect(summary, const TodaySummary(cleared: 3, totalSeconds: 221));
      expect(summary!.isPerfectDay, isTrue);
    });
  });

  group('AppStrings.homeTodaySummary', () {
    test('reads "2 of 3 cleared · 3:41 total"', () {
      expect(
        AppStrings.homeTodaySummary(cleared: 2, total: 3, totalSeconds: 221),
        '2 of 3 cleared · 3:41 total',
      );
    });

    test('leaves the total out when there is none', () {
      expect(
        AppStrings.homeTodaySummary(cleared: 1, total: 3),
        '1 of 3 cleared',
      );
    });
  });
}
