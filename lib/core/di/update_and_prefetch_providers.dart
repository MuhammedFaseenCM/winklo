import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/data/repositories/in_app_update_repository_impl.dart';
import 'package:winklo/data/repositories/update_banner_snooze_repository_impl.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';

/// Play in-app updates and the update banner's snooze. Spread into
/// `buildRepositoryProviders`, after [SharedPreferences].
List<SingleChildWidget> buildUpdateAndPrefetchProviders() => [
  RepositoryProvider<InAppUpdateRepository>(
    create: (_) => InAppUpdateRepositoryImpl(),
  ),
  RepositoryProvider<UpdateBannerSnoozeRepository>(
    create: (context) =>
        UpdateBannerSnoozeRepositoryImpl(context.read<SharedPreferences>()),
  ),
];
