import 'package:winklo/domain/play_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily ids stay YYYYMMDD', () {
    expect(
      PlayPeriod.id(DateTime(2026, 9, 20, 14, 31), PlayPeriod.daily),
      '20260920',
    );
    expect(
      PlayPeriod.bucket(DateTime(2026, 9, 20, 14, 31), PlayPeriod.daily),
      DateTime(2026, 9, 20),
    );
  });

  test('minute ids include hour and minute', () {
    expect(
      PlayPeriod.id(DateTime(2026, 9, 20, 14, 31, 59), PlayPeriod.minute),
      '202609201431',
    );
    expect(
      PlayPeriod.bucket(DateTime(2026, 9, 20, 14, 31, 59), PlayPeriod.minute),
      DateTime(2026, 9, 20, 14, 31),
    );
  });

  test('adjacent minutes get different ids', () {
    expect(
      PlayPeriod.id(DateTime(2026, 9, 20, 14, 31), PlayPeriod.minute),
      isNot(PlayPeriod.id(DateTime(2026, 9, 20, 14, 32), PlayPeriod.minute)),
    );
  });

  group('nextStart', () {
    test('a day ends at the next local midnight', () {
      expect(
        PlayPeriod.nextStart(DateTime(2026, 10, 14, 18, 30), PlayPeriod.daily),
        DateTime(2026, 10, 15),
      );
      expect(
        PlayPeriod.nextStart(
          DateTime(2026, 10, 14, 23, 59, 59, 999),
          PlayPeriod.daily,
        ),
        DateTime(2026, 10, 15),
      );
    });

    test('midnight itself starts a whole new day', () {
      expect(
        PlayPeriod.nextStart(DateTime(2026, 10, 15), PlayPeriod.daily),
        DateTime(2026, 10, 16),
      );
    });

    test('rolls over months and years', () {
      expect(
        PlayPeriod.nextStart(DateTime(2026, 12, 31, 22), PlayPeriod.daily),
        DateTime(2027, 1, 1),
      );
    });

    test('a minute period ends at the next minute', () {
      expect(
        PlayPeriod.nextStart(
          DateTime(2026, 9, 20, 14, 31, 20),
          PlayPeriod.minute,
        ),
        DateTime(2026, 9, 20, 14, 32),
      );
      expect(
        PlayPeriod.nextStart(
          DateTime(2026, 9, 20, 23, 59, 5),
          PlayPeriod.minute,
        ),
        DateTime(2026, 9, 21),
      );
    });
  });
}
