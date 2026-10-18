import '../../../domain/entities/app_language.dart';

/// The Settings choice, the language it resolves to (`en` or `ml`), and the
/// one System would give on this phone (for the System row's hint, whatever
/// is chosen).
class LocaleState {
  const LocaleState({
    required this.choice,
    required this.languageCode,
    required this.systemLanguageCode,
  });

  final AppLanguage choice;
  final String languageCode;
  final String systemLanguageCode;

  @override
  bool operator ==(Object other) =>
      other is LocaleState &&
      other.choice == choice &&
      other.languageCode == languageCode &&
      other.systemLanguageCode == systemLanguageCode;

  @override
  int get hashCode => Object.hash(choice, languageCode, systemLanguageCode);

  @override
  String toString() =>
      'LocaleState(choice: $choice, code: $languageCode, '
      'system: $systemLanguageCode)';
}
