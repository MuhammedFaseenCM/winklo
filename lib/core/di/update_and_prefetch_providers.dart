import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/data/repositories/daily_puzzle_prefetch_repository_impl.dart';
import 'package:winklo/data/repositories/in_app_update_repository_impl.dart';
import 'package:winklo/data/repositories/update_banner_snooze_repository_impl.dart';
import 'package:winklo/domain/repositories/daily_puzzle_prefetch_repository.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';
import 'package:winklo/domain/usecases/prefetch_tomorrow_puzzles.dart';

/// Play in-app updates, the update banner's snooze and the prefetch of
/// tomorrow's dailies. Spread into `buildRepositoryProviders`, after
/// [SharedPreferences].
List<SingleChildWidget> buildUpdateAndPrefetchProviders() => [
  RepositoryProvider<InAppUpdateRepository>(
    create: (_) => InAppUpdateRepositoryImpl(),
  ),
  RepositoryProvider<UpdateBannerSnoozeRepository>(
    create: (context) =>
        UpdateBannerSnoozeRepositoryImpl(context.read<SharedPreferences>()),
  ),
  RepositoryProvider<DailyPuzzlePrefetchRepository>(
    create: (_) => DailyPuzzlePrefetchRepositoryImpl(),
  ),
  // One instance for the app session: it remembers the days it has tried.
  RepositoryProvider<PrefetchTomorrowPuzzles>(
    create: (context) => PrefetchTomorrowPuzzles(
      context.read<DailyPuzzlePrefetchRepository>(),
      period: DevFlags.playPeriod,
    ),
  ),
];
