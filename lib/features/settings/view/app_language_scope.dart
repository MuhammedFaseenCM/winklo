import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/rebuild_descendants.dart';
import '../cubit/locale_cubit.dart';
import '../cubit/locale_state.dart';

/// Puts the app in [LocaleCubit]'s language. It builds the app with that
/// language's [Locale], rebuilds everything below when the language changes
/// (state is kept), and tells the cubit when the phone's languages change,
/// which System follows.
class AppLanguageScope extends StatefulWidget {
  const AppLanguageScope({super.key, required this.builder});

  /// Builds the `MaterialApp` for [locale].
  final Widget Function(BuildContext context, Locale locale) builder;

  /// The languages the app has copy for.
  static List<Locale> get supportedLocales => [
    for (final code in AppStrings.supportedLanguageCodes) Locale(code),
  ];

  /// Material, Cupertino and Widgets copy and formats (dates, times) in the
  /// app's language.
  static const localizationsDelegates = GlobalMaterialLocalizations.delegates;

  @override
  State<AppLanguageScope> createState() => _AppLanguageScopeState();
}

class _AppLanguageScopeState extends State<AppLanguageScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    context.read<LocaleCubit>().deviceLanguagesChanged();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocaleCubit, LocaleState>(
      listenWhen: (previous, next) =>
          previous.languageCode != next.languageCode,
      listener: (context, _) => rebuildDescendants(context),
      buildWhen: (previous, next) => previous.languageCode != next.languageCode,
      builder: (context, state) =>
          widget.builder(context, Locale(state.languageCode)),
    );
  }
}
