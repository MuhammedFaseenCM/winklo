import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/app_calendar.dart';
import 'package:winklo/domain/logic/daily_live_window.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/daily_puzzle_prefetch_repository.dart';
import 'package:winklo/domain/usecases/prefetch_tomorrow_puzzles.dart';

class _RecordingPrefetch implements DailyPuzzlePrefetchRepository {
  final List<String> days = [];
  Object? error;

  @override
  Future<void> prefetch(String dateId) async {
    days.add(dateId);
    final error = this.error;
    if (error != null) throw error;
  }
}

void main() {
  late _RecordingPrefetch repo;
  late PrefetchTomorrowPuzzles prefetch;

  // Tomorrow's day, and when it goes live, worked out on this machine's
  // calendar the same way the use case does.
  final today = DateTime(2026, 10, 15, 8);
  final tomorrow = DateTime(2026, 10, 16);
  final opens = DailyLiveWindow.opensAt(tomorrow);

  /// [opens] shifted, as long as it is still [today] on the local calendar.
  DateTime atOpening(Duration shift) {
    final at = opens.add(shift);
    expect(
      AppCalendar.calendarDay(at),
      DateTime(today.year, today.month, today.day),
    );
    return at;
  }

  setUp(() {
    repo = _RecordingPrefetch();
    prefetch = PrefetchTomorrowPuzzles(repo);
  });

  test('waits until tomorrow is live', () async {
    await prefetch(atOpening(const Duration(minutes: -1)));

    expect(repo.days, isEmpty);
  });

  test('reads tomorrow once it is live', () async {
    await prefetch(atOpening(const Duration(minutes: 1)));

    expect(repo.days, ['20261016']);
  });

  test('reads a day at most once per session', () async {
    await prefetch(atOpening(const Duration(minutes: 1)));
    await prefetch(atOpening(const Duration(minutes: 30)));

    expect(repo.days, ['20261016']);
  });

  test('a failed read is not retried in the same session', () async {
    repo.error = Exception('[cloud_firestore/permission-denied]');

    await prefetch(atOpening(const Duration(minutes: 1)));
    await prefetch(atOpening(const Duration(minutes: 2)));

    expect(repo.days, ['20261016']);
  });

  test('errors never reach Home', () async {
    repo.error = Exception('[cloud_firestore/permission-denied]');

    await expectLater(
      prefetch(atOpening(const Duration(minutes: 1))),
      completes,
    );
  });

  test('the next day is read again', () async {
    await prefetch(atOpening(const Duration(minutes: 1)));
    await prefetch(
      atOpening(const Duration(minutes: 1)).add(const Duration(days: 1)),
    );

    expect(repo.days, ['20261016', '20261017']);
  });

  test('debug minute periods never prefetch', () async {
    prefetch = PrefetchTomorrowPuzzles(repo, period: PlayPeriod.minute);

    await prefetch(atOpening(const Duration(minutes: 1)));

    expect(repo.days, isEmpty);
  });
}
