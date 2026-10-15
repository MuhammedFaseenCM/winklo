import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/app_language.dart';
import '../../cubit/locale_cubit.dart';
import 'settings_section.dart';

/// The Settings screen's Language section: System, English and മലയാളം.
/// Each language is named in its own script, so it can be found whatever
/// the app shows.
class SettingsLanguageSlot extends StatelessWidget {
  const SettingsLanguageSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LocaleCubit>().state;
    return RadioGroup<AppLanguage>(
      groupValue: state.choice,
      onChanged: (choice) {
        if (choice == null) return;
        unawaited(context.read<LocaleCubit>().choose(choice));
      },
      child: SettingsSection(
        title: AppStrings.settingsLanguageSection,
        children: [
          _LanguageRow(
            value: AppLanguage.system,
            title: AppStrings.settingsLanguageSystem,
            subtitle: AppStrings.settingsLanguageSystemHint(
              _nameOf(state.systemLanguageCode),
            ),
          ),
          _LanguageRow(
            value: AppLanguage.english,
            title: AppStrings.languageEnglish,
          ),
          _LanguageRow(
            value: AppLanguage.malayalam,
            title: AppStrings.languageMalayalam,
          ),
        ],
      ),
    );
  }

  static String _nameOf(String languageCode) => switch (languageCode) {
    'ml' => AppStrings.languageMalayalam,
    _ => AppStrings.languageEnglish,
  };
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.title, this.subtitle});

  final AppLanguage value;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = subtitle;
    return RadioListTile<AppLanguage>(
      value: value,
      activeColor: ZipColors.teal,
      controlAffinity: ListTileControlAffinity.trailing,
      title: Text(
        title,
        style: textTheme.titleSmall?.copyWith(
          color: ZipColors.onInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
            ),
    );
  }
}
