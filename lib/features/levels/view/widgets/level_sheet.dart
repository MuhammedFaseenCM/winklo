import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/play_mode_route.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/level_goals.dart';
import '../../../../core/widgets/zip_ui.dart';
import '../../../../domain/entities/level_world.dart';
import '../../../../domain/logic/level_map.dart';
import '../../../../domain/play_mode.dart';
import '../../../auth/view/ensure_signed_in_for_play.dart';

/// [entry]'s board size, "5 × 5", as the sheet and a locked world's label
/// show it; null when the size is unknown.
String? levelBoardSize(LevelEntry entry) {
  final size = entry.boardSize;
  return size > 0 ? '$size × $size' : null;
}

/// Opens the sheet for a playable [node]: its world, number, best, goals,
/// and Play (or Replay). On the root navigator, so it covers the shell's
/// nav dock instead of opening under it in the tab's branch. Play asks a
/// signed-out player to sign in first, like every other Play.
///
/// [boardLevelIds] are the levels the Levels board holds, when known: a
/// cleared level missing from them says it isn't on the board yet.
Future<void> showLevelSheet(
  BuildContext context,
  LevelMapNode node, {
  Set<String>? boardLevelIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // Sized to its content rather than capped at 9/16 of the screen, so
    // Play never hides below the fold; it scrolls only on a short screen.
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ZipColors.paper,
    builder: (_) => LevelSheet(node: node, boardLevelIds: boardLevelIds),
  );
}

class LevelSheet extends StatelessWidget {
  const LevelSheet({super.key, required this.node, this.boardLevelIds});

  final LevelMapNode node;

  /// The levels the Levels board holds; null when unknown.
  final Set<String>? boardLevelIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = node.slot;
    final best = node.record?.bestSeconds;
    final size = levelBoardSize(slot.entry);
    final target = slot.entry.targetSeconds;
    final cleared = node.state == LevelNodeState.done;
    // Stars are 1 (clear) + no hints + time, so all of them, or just the
    // clear, say which goals are in; two of three could be either.
    final allEarned = cleared && node.stars >= node.maxStars;
    LevelGoalStatus extra() =>
        allEarned ? LevelGoalStatus.earned : LevelGoalStatus.open;
    final goals = [
      LevelGoalTile(
        kind: LevelGoalKind.clear,
        label: AppStrings.levelGoalClear,
        status: cleared ? LevelGoalStatus.earned : LevelGoalStatus.open,
      ),
      LevelGoalTile(
        kind: LevelGoalKind.noHints,
        label: AppStrings.levelGoalNoHints,
        status: extra(),
      ),
      if (target != null)
        LevelGoalTile(
          kind: LevelGoalKind.time,
          label: AppStrings.levelGoalUnder(AppStrings.formatPlayTime(target)),
          status: extra(),
        ),
    ];
    final ids = boardLevelIds;
    final notOnBoard = cleared && ids != null && !ids.contains(slot.entry.id);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _NumberBadge(number: slot.number, cleared: cleared),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.levelWorldTitle(
                            slot.world.order,
                            AppStrings.levelWorldDisplayName(slot.world),
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: ZipColors.sky,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.levelNumber(slot.number),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cleared) ...[
                    const SizedBox(width: 8),
                    _StarRow(stars: node.stars, maxStars: node.maxStars),
                  ],
                ],
              ),
              if (size != null || best != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (size != null)
                      _InfoChip(icon: AppIcons.grid, text: size),
                    if (best != null)
                      _InfoChip(
                        icon: AppIcons.clock,
                        text: AppStrings.levelBestTime(
                          AppStrings.formatPlayTime(best),
                        ),
                      ),
                  ],
                ),
              ],
              if (notOnBoard) ...[
                const SizedBox(height: 12),
                Text(
                  AppStrings.levelSheetNotOnBoard,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ZipColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                AppStrings.levelStarGoals.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < goals.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: goals[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ZipPrimaryButton(
                label: cleared ? AppStrings.levelReplay : AppStrings.levelPlay,
                icon: cleared ? AppIcons.replay : AppIcons.play,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final navigator = Navigator.of(context);
                  final route = ModalRoute.of(context);
                  // Signed out: the sign-in sheet opens over this one (both on
                  // the root navigator). Cancelled, this sheet stays open.
                  if (!await ensureSignedInForPlay(context)) return;
                  // Dismissed while signing in or syncing: the sheet's route is
                  // on its way out, so a pop would take the page beneath it.
                  if (!context.mounted || route?.isCurrent != true) return;
                  navigator.pop();
                  router.push(
                    PlayMode.level(
                      slot.entry.id,
                    ).location(gameRoute(slot.world.game)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The level's number in a coin: ember while it waits, gold once cleared.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.cleared});

  final int number;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final glow = cleared ? ZipColors.star : ZipColors.ember;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: cleared
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                )
              : ZipColors.emberGradient,
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cleared ? ZipColors.ink : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars, required this.maxStars});

  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.levelStarsLabel(stars, maxStars),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < maxStars; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
              child: AppIcon(
                i < stars ? AppIcons.star : AppIcons.starOutline,
                size: 22,
                color: i < stars ? ZipColors.star : ZipColors.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: AppIcon(icon, size: 14, color: ZipColors.inkSoft),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
