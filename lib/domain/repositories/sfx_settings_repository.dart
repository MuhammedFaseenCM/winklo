abstract class SfxSettingsRepository {
  bool get isEnabled;
  Future<void> setEnabled(bool value);
}
