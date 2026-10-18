import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/daily_live_window.dart';

void main() {
  final day = DateTime(2026, 10, 16);

  test('a day goes live at 10:00 UTC the day before', () {
    expect(DailyLiveWindow.opensAt(day), DateTime.utc(2026, 10, 15, 10));
    expect(
      DailyLiveWindow.isLive(day, DateTime.utc(2026, 10, 15, 9, 59, 59)),
      isFalse,
    );
    expect(DailyLiveWindow.isLive(day, DateTime.utc(2026, 10, 15, 10)), isTrue);
  });

  test('a day stays live until 12:00 UTC the day after', () {
    expect(DailyLiveWindow.closesAt(day), DateTime.utc(2026, 10, 17, 12));
    expect(
      DailyLiveWindow.isLive(day, DateTime.utc(2026, 10, 17, 11, 59, 59)),
      isTrue,
    );
    expect(
      DailyLiveWindow.isLive(day, DateTime.utc(2026, 10, 17, 12)),
      isFalse,
    );
  });

  test('works across month and year ends', () {
    expect(
      DailyLiveWindow.opensAt(DateTime(2027, 1, 1)),
      DateTime.utc(2026, 12, 31, 10),
    );
    expect(
      DailyLiveWindow.closesAt(DateTime(2026, 2, 28)),
      DateTime.utc(2026, 3, 1, 12),
    );
  });

  test('only the calendar day of the given date counts', () {
    expect(
      DailyLiveWindow.opensAt(DateTime(2026, 10, 16, 23, 30)),
      DateTime.utc(2026, 10, 15, 10),
    );
  });
}
