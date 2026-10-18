/// The language the player picked in Settings. [system] follows the phone.
enum AppLanguage {
  system('system'),
  english('en'),
  malayalam('ml');

  const AppLanguage(this.storageId);

  /// How the choice is stored (`system`, or the language code).
  final String storageId;

  /// The language codes the app has copy for, English first (the fallback).
  static const supportedCodes = ['en', 'ml'];

  /// [id] as stored; anything missing or unknown reads as [system].
  static AppLanguage fromStorageId(String? id) => values.firstWhere(
    (language) => language.storageId == id,
    orElse: () => system,
  );
}

/// The language code to show for [choice]: System takes the first of the
/// phone's languages ([deviceLanguageCodes], in its order of preference)
/// that the app has, and English when there's none.
String resolveLanguageCode(
  AppLanguage choice,
  List<String> deviceLanguageCodes,
) => switch (choice) {
  AppLanguage.english => 'en',
  AppLanguage.malayalam => 'ml',
  AppLanguage.system => deviceLanguageCodes.firstWhere(
    AppLanguage.supportedCodes.contains,
    orElse: () => 'en',
  ),
};
