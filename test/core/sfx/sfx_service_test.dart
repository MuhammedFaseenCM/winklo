import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';

class _MockSettings extends Mock implements SfxSettingsRepository {}

void main() {
  late _MockSettings settings;
  late List<SfxId> played;
  late DateTime fakeNow;
  late SfxService sfx;

  setUp(() {
    settings = _MockSettings();
    played = [];
    fakeNow = DateTime(2026, 10, 7);
    when(() => settings.isEnabled).thenReturn(true);
    when(() => settings.setEnabled(any())).thenAnswer((_) async {});
    sfx = SfxService(
      settings: settings,
      playClip: (id) async => played.add(id),
      now: () => fakeNow,
    );
  });

  test('play records when enabled', () async {
    await sfx.play(SfxId.tap);
    expect(played, [SfxId.tap]);
  });

  test('play no-ops when muted', () async {
    when(() => settings.isEnabled).thenReturn(false);
    sfx = SfxService(
      settings: settings,
      playClip: (id) async => played.add(id),
      now: () => fakeNow,
    );
    await sfx.play(SfxId.tap);
    expect(played, isEmpty);
  });

  test('setEnabled updates prefs and gates play', () async {
    await sfx.setEnabled(false);
    verify(() => settings.setEnabled(false)).called(1);
    await sfx.play(SfxId.success);
    expect(played, isEmpty);
  });

  test('reject is rate-limited to 150ms', () async {
    await sfx.play(SfxId.reject);
    await sfx.play(SfxId.reject);
    expect(played, [SfxId.reject]);
    fakeNow = fakeNow.add(const Duration(milliseconds: 151));
    await sfx.play(SfxId.reject);
    expect(played, [SfxId.reject, SfxId.reject]);
  });

  test('playClip errors are swallowed', () async {
    sfx = SfxService(
      settings: settings,
      playClip: (_) async => throw StateError('boom'),
      now: () => fakeNow,
    );
    await expectLater(sfx.play(SfxId.tap), completes);
  });
}
