import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/app_language.dart';
import '../../../domain/repositories/language_repository.dart';
import 'locale_state.dart';

/// The app's language. Lives above the app, so [AppStrings] is switched
/// before anything reads it, and every change switches [AppStrings] and
/// (through the state) the `MaterialApp` locale together.
///
/// A change of language also calls [onLanguageChanged]: the reminders and
/// the home-screen widget carry copy written when they were planned.
class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit({
    required this._languages,
    required this._deviceLanguageCodes,
    this._onLanguageChanged,
  }) : super(
         LocaleState(
           choice: _languages.language,
           languageCode: resolveLanguageCode(
             _languages.language,
             _deviceLanguageCodes(),
           ),
         ),
       ) {
    AppStrings.use(state.languageCode);
  }

  final LanguageRepository _languages;

  /// The phone's languages, most preferred first.
  final List<String> Function() _deviceLanguageCodes;
  final Future<void> Function()? _onLanguageChanged;

  /// Stores [choice] and switches to the language it resolves to.
  Future<void> choose(AppLanguage choice) async {
    if (choice == state.choice) return;
    await _languages.setLanguage(choice);
    _apply(choice);
  }

  /// The phone's languages changed; only System follows them.
  void deviceLanguagesChanged() {
    if (state.choice != AppLanguage.system) return;
    _apply(state.choice);
  }

  void _apply(AppLanguage choice) {
    if (isClosed) return;
    final code = resolveLanguageCode(choice, _deviceLanguageCodes());
    final changed = code != state.languageCode;
    if (!changed && choice == state.choice) return;
    AppStrings.use(code);
    emit(LocaleState(choice: choice, languageCode: code));
    if (changed) unawaited(_replan());
  }

  Future<void> _replan() async {
    try {
      await _onLanguageChanged?.call();
    } catch (e) {
      // The next app open or clear replans in the new language.
      debugPrint('LocaleCubit: replanning after a language change failed: $e');
    }
  }
}
