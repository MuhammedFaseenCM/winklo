abstract class HapticsSettingsRepository {
  bool get isEnabled;
  Future<void> setEnabled(bool value);
}
