import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/achievements/achievement.dart';
import '../../../domain/usecases/claim_new_achievements.dart';
import '../cubit/new_achievements_cubit.dart';
import 'achievement_copy.dart';

/// "New badge unlocked" under a daily result, shown once per new badge.
/// Renders nothing when there is none, or when the app provides no
/// [ClaimNewAchievements] (screen tests of Results).
class NewAchievementsBanner extends StatelessWidget {
  const NewAchievementsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final claim = context.read<ClaimNewAchievements?>();
    if (claim == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => NewAchievementsCubit(claim: claim),
      child: BlocBuilder<NewAchievementsCubit, List<Achievement>>(
        builder: (context, fresh) {
          if (fresh.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Banner(achievements: fresh)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titles = [for (final a in achievements) achievementTitle(a)];
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          gradient: ZipColors.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZipColors.ember.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: ZipColors.emberGlow.withValues(alpha: 0.3),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZipColors.emberGradient,
              ),
              child: Icon(
                achievementIcon(achievements.first),
                size: 22,
                color: ZipColors.onInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.newAchievementsTitle(achievements.length),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ZipColors.ember,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.newAchievementsList(titles),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
