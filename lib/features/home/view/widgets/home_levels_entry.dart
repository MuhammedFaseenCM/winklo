import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/play_mode_route.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/level_progress_repository.dart';
import '../../../../domain/repositories/levels_intro_repository.dart';
import '../../../../domain/usecases/get_levels_overview.dart';

/// Home's way into Levels, under the daily tiles: the stars earned across
/// every Levels game and the level to continue (in the game a level was
/// last started in; Path Words before any). As compact as
/// [HomeMorePlayEntry]. Offline it still opens the Levels tab.
class HomeLevelsEntry extends StatefulWidget {
  const HomeLevelsEntry({super.key});

  @override
  State<HomeLevelsEntry> createState() => _HomeLevelsEntryState();
}

class _HomeLevelsEntryState extends State<HomeLevelsEntry> {
  LevelsOverview? _overview;
  final _subs = <StreamSubscription<void>>[];

  @override
  void initState() {
    super.initState();
    _load();
    _subs
      ..add(
        context.read<LevelProgressRepository>().changes.listen((_) => _load()),
      )
      ..add(
        context.read<LevelsIntroRepository>().changes.listen((_) => _load()),
      );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  Future<void> _load() async {
    LevelsOverview overview;
    try {
      overview = await context.read<GetLevelsOverview>()();
    } catch (_) {
      overview = const LevelsOverview({});
    }
    if (mounted) setState(() => _overview = overview);
  }

  GameLevelsOverview? get _continue {
    final overview = _overview;
    if (overview == null) return null;
    final last = context.read<LevelsIntroRepository>().lastGame;
    return overview.of(last ?? GameIds.pathWords) ??
        overview.of(GameIds.pathWords) ??
        overview.of(GameIds.zip);
  }

  static String _title(String gameId) => gameId == GameIds.pathWords
      ? AppStrings.pathWordsTitle
      : AppStrings.zipTitle;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(layout.space(16));
    final next = _continue;
    final stars = _overview?.totalStars;
    final hint = [
      if (stars != null) '★ $stars',
      if (next != null)
        AppStrings.levelsHomeContinue(_title(next.gameId), next.nextNumber),
    ].join(' · ');
    final subtitle = hint.isEmpty ? AppStrings.levelsIntroTitle : hint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          final next = _continue;
          context.go(
            next == null
                ? levelsLocation
                : levelsOpenLocation(next.nextLevelId),
          );
        },
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: layout.space(12),
            vertical: layout.space(layout.isCompact ? 8 : 10),
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: ZipColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: layout.space(34),
                height: layout.space(34),
                decoration: BoxDecoration(
                  color: ZipColors.star.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(layout.space(10)),
                  border: Border.all(
                    color: ZipColors.star.withValues(alpha: 0.45),
                  ),
                ),
                child: AppIcon(
                  AppIcons.levels,
                  size: layout.space(20),
                  color: ZipColors.star,
                ),
              ),
              SizedBox(width: layout.space(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.levelsTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const AppIcon(AppIcons.chevronRight, color: ZipColors.inkSoft),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 450.ms);
  }
}
