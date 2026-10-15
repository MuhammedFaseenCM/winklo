import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/play_mode_route.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_mode.dart';
import '../../auth/view/ensure_signed_in_for_play.dart';
import 'more_play_widgets.dart';

/// "More ways to play": the archive of past dailies, practice boards and the
/// bonus games. None of them touch streaks, boards or the daily stats.
class MorePlayScreen extends StatelessWidget {
  const MorePlayScreen({super.key});

  static const practiceGames = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  Future<void> _open(BuildContext context, String location) async {
    final ok = await ensureSignedInForPlay(context);
    if (!ok || !context.mounted) return;
    await context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final archiveStyle = MorePlayGameStyle.of(GameIds.zip);
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MorePlayHeader(title: AppStrings.moreWaysTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    const MorePlaySectionTitle(title: AppStrings.archiveTitle),
                    MorePlayCard(
                      icon: Icons.calendar_month_rounded,
                      title: AppStrings.archiveTitle,
                      subtitle: AppStrings.archiveHint,
                      accent: archiveStyle.accent,
                      accentSoft: archiveStyle.accentSoft,
                      onTap: () => context.push(archiveLocation()),
                    ),
                    const SizedBox(height: 12),
                    const MorePlaySectionTitle(
                      title: AppStrings.practiceTitle,
                      hint: AppStrings.practiceHint,
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < practiceGames.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _PracticeTile(
                              gameId: practiceGames[i],
                              onTap: () => _open(
                                context,
                                PlayMode.practice.location(
                                  gameRoute(practiceGames[i]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    const MorePlaySectionTitle(
                      title: AppStrings.bonusGamesTitle,
                      hint: AppStrings.bonusGamesHint,
                    ),
                    for (final (gameId, subtitle, location) in const [
                      (
                        GameIds.wordMatch,
                        AppStrings.wordMatchHint,
                        '/word-match',
                      ),
                      (
                        GameIds.categoryRace,
                        AppStrings.categoryRaceHint,
                        '/category-race',
                      ),
                    ]) ...[
                      Builder(
                        builder: (context) {
                          final style = MorePlayGameStyle.of(gameId);
                          return MorePlayCard(
                            icon: style.icon,
                            title: style.title,
                            subtitle: subtitle,
                            accent: style.accent,
                            accentSoft: style.accentSoft,
                            onTap: () => _open(context, location),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ].animate(interval: 40.ms).fadeIn(duration: 300.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({required this.gameId, required this.onTap});

  final String gameId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = MorePlayGameStyle.of(gameId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            gradient: ZipColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(style.icon, color: style.accent),
              const SizedBox(height: 6),
              Text(
                style.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
