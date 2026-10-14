import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/haptics_settings_repository_impl.dart';

void main() {
  test('vibration is on until the player turns it off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = HapticsSettingsRepositoryImpl(prefs);
    expect(repo.isEnabled, isTrue);

    await repo.setEnabled(false);

    expect(HapticsSettingsRepositoryImpl(prefs).isEnabled, isFalse);
  });
}
