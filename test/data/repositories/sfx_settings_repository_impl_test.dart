import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/sfx_settings_repository_impl.dart';

void main() {
  test('defaults to enabled when unset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SfxSettingsRepositoryImpl(prefs);
    expect(repo.isEnabled, isTrue);
  });

  test('persists disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SfxSettingsRepositoryImpl(prefs);
    await repo.setEnabled(false);
    expect(repo.isEnabled, isFalse);
    expect(SfxSettingsRepositoryImpl(prefs).isEnabled, isFalse);
  });
}
