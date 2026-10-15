import '../../../domain/entities/app_language.dart';

/// The Settings choice and the language it resolves to (`en` or `ml`).
class LocaleState {
  const LocaleState({required this.choice, required this.languageCode});

  final AppLanguage choice;
  final String languageCode;

  @override
  bool operator ==(Object other) =>
      other is LocaleState &&
      other.choice == choice &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(choice, languageCode);

  @override
  String toString() => 'LocaleState(choice: $choice, code: $languageCode)';
}
