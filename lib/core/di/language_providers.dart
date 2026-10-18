import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/data/repositories/language_repository_impl.dart';
import 'package:winklo/domain/repositories/language_repository.dart';

/// The language choice (Settings). Reads [SharedPreferences] from
/// [buildRepositoryProviders].
List<SingleChildWidget> buildLanguageProviders() => [
  RepositoryProvider<LanguageRepository>(
    create: (context) =>
        LanguageRepositoryImpl(context.read<SharedPreferences>()),
  ),
];
