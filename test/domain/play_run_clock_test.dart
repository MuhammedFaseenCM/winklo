import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/play_run_clock.dart';

void main() {
  group('PlayRunClock', () {
    test('starts at zero and accumulates while resumed', () {
      final t0 = DateTime.utc(2026, 10, 3, 12);
      var clock = PlayRunClock.start(at: t0);

      expect(clock.elapsedMs, 0);
      expect(clock.isRunning, isTrue);
      expect(
        clock.displayedMs(at: t0.add(const Duration(seconds: 5))),
        5000,
      );
    });

    test('pause folds live delta and stops accumulation', () {
      final t0 = DateTime.utc(2026, 10, 3, 12);
      var clock = PlayRunClock.start(at: t0);
      final pausedAt = t0.add(const Duration(seconds: 10));
      clock = clock.pause(at: pausedAt);

      expect(clock.elapsedMs, 10000);
      expect(clock.isRunning, isFalse);
      expect(
        clock.displayedMs(at: pausedAt.add(const Duration(minutes: 30))),
        10000,
      );
    });

    test('resume continues from frozen elapsed', () {
      final t0 = DateTime.utc(2026, 10, 3, 12);
      var clock = PlayRunClock.start(at: t0)
          .pause(at: t0.add(const Duration(seconds: 8)))
          .resume(at: t0.add(const Duration(minutes: 5)));

      expect(clock.elapsedMs, 8000);
      expect(clock.isRunning, isTrue);
      expect(
        clock.displayedMs(at: t0.add(const Duration(minutes: 5, seconds: 2))),
        10000,
      );
    });

    test('displayedSeconds floors milliseconds', () {
      final t0 = DateTime.utc(2026, 10, 3, 12);
      final clock = PlayRunClock.start(at: t0);
      expect(
        clock.displayedSeconds(at: t0.add(const Duration(milliseconds: 1999))),
        1,
      );
    });

    test('restore creates paused clock from saved elapsed', () {
      final clock = PlayRunClock.restore(elapsedMs: 42000);
      expect(clock.elapsedMs, 42000);
      expect(clock.isRunning, isFalse);
      expect(clock.displayedMs(at: DateTime.utc(2026, 10, 3)), 42000);
    });
  });
}
