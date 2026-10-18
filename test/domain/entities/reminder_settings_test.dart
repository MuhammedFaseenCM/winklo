import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';

void main() {
  test('defaults: everything on, 08:00 and 20:00', () {
    const settings = ReminderSettings();
    expect(settings.dailyReadyEnabled, isTrue);
    expect(settings.streakAtRiskEnabled, isTrue);
    expect(settings.weeklyRecapEnabled, isTrue);
    expect(settings.announcementsEnabled, isTrue);
    expect(settings.dailyReadyMinutes, 8 * 60);
    expect(settings.streakReminderMinutes, 20 * 60);
  });

  test('the weekly recap is an hour before the streak reminder', () {
    expect(const ReminderSettings().weeklyRecapMinutes, 19 * 60);
    expect(
      const ReminderSettings(
        streakReminderMinutes: 21 * 60 + 30,
      ).weeklyRecapMinutes,
      20 * 60 + 30,
    );
  });

  test('a streak time before 01:00 puts the recap at 00:00', () {
    expect(
      const ReminderSettings(streakReminderMinutes: 30).weeklyRecapMinutes,
      0,
    );
  });

  test('clampMinutes keeps a time within the day', () {
    expect(ReminderSettings.clampMinutes(-5), 0);
    expect(ReminderSettings.clampMinutes(24 * 60), 24 * 60 - 1);
    expect(ReminderSettings.clampMinutes(615), 615);
  });

  test('copyWith and equality', () {
    const settings = ReminderSettings();
    final changed = settings.copyWith(
      weeklyRecapEnabled: false,
      dailyReadyMinutes: 9 * 60,
    );
    expect(changed.weeklyRecapEnabled, isFalse);
    expect(changed.dailyReadyMinutes, 9 * 60);
    expect(changed.streakReminderMinutes, settings.streakReminderMinutes);
    expect(changed, isNot(settings));
    expect(settings.copyWith(), settings);
    expect(settings.copyWith().hashCode, settings.hashCode);
  });
}
