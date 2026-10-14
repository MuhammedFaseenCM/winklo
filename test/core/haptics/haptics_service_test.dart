import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/haptics/haptics_service.dart';
import 'package:winklo/domain/repositories/haptics_settings_repository.dart';

class _MockSettings extends Mock implements HapticsSettingsRepository {}

void main() {
  late _MockSettings settings;
  late List<HapticKind> felt;
  late DateTime now;
  late HapticsService haptics;

  HapticsService build() => HapticsService(
    settings: settings,
    perform: (kind) async => felt.add(kind),
    now: () => now,
  );

  setUp(() {
    settings = _MockSettings();
    felt = [];
    now = DateTime(2026, 10, 15);
    when(() => settings.isEnabled).thenReturn(true);
    when(() => settings.setEnabled(any())).thenAnswer((_) async {});
    haptics = build();
  });

  test('plays each kind when on', () {
    haptics.play(HapticKind.tick);
    haptics.play(HapticKind.success);
    haptics.play(HapticKind.win);
    expect(felt, [HapticKind.tick, HapticKind.success, HapticKind.win]);
  });

  test('stays still when turned off in settings', () {
    when(() => settings.isEnabled).thenReturn(false);
    haptics = build();
    haptics.play(HapticKind.win);
    expect(haptics.isEnabled, isFalse);
    expect(felt, isEmpty);
  });

  test('setEnabled saves the choice and applies it at once', () async {
    await haptics.setEnabled(false);
    verify(() => settings.setEnabled(false)).called(1);
    haptics.play(HapticKind.success);
    expect(felt, isEmpty);
  });

  test('a fast swipe does not buzz on every cell', () {
    haptics.play(HapticKind.tick);
    now = now.add(const Duration(milliseconds: 10));
    haptics.play(HapticKind.tick);
    now = now.add(HapticsService.tickGap);
    haptics.play(HapticKind.tick);
    expect(felt, [HapticKind.tick, HapticKind.tick]);
  });

  test('a clock set back does not mute the ticks', () {
    haptics.play(HapticKind.tick);
    // E.g. the player turns the date back a day.
    now = now.subtract(const Duration(days: 1));
    haptics.play(HapticKind.tick);
    now = now.add(const Duration(milliseconds: 10));
    haptics.play(HapticKind.tick);
    expect(felt, [HapticKind.tick, HapticKind.tick]);
  });

  test('only ticks are spaced out', () {
    haptics.play(HapticKind.tick);
    haptics.play(HapticKind.success);
    haptics.play(HapticKind.win);
    expect(felt, [HapticKind.tick, HapticKind.success, HapticKind.win]);
  });

  test('a failing vibrator never breaks the game', () {
    haptics = HapticsService(
      settings: settings,
      perform: (_) async => throw Exception('no vibrator'),
    );
    expect(() => haptics.play(HapticKind.win), returnsNormally);
  });
}
