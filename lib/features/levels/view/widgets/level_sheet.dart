import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/zip_ui.dart';
import '../../../../domain/entities/level_world.dart';
import '../../../../domain/logic/level_map.dart';
import '../../../../domain/play_mode.dart';

/// [entry]'s board size, "5 × 5", as the sheet and a locked world's label
/// show it; null when the size is unknown.
String? levelBoardSize(LevelEntry entry) {
  final size = entry.zipLevelSize;
  return size > 0 ? '$size × $size' : null;
}

/// Opens the sheet for a playable [node]: its world, number, best, goals,
/// and Play (or Replay). On the root navigator, so it covers the shell's
/// nav dock instead of opening under it in the tab's branch.
Future<void> showLevelSheet(BuildContext context, LevelMapNode node) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: ZipColors.paper,
    builder: (_) => LevelSheet(node: node),
  );
}

class LevelSheet extends StatelessWidget {
  const LevelSheet({super.key, required this.node});

  final LevelMapNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = node.slot;
    final best = node.record?.bestSeconds;
    final bestText = best == null
        ? null
        : AppStrings.levelBestTime(AppStrings.formatPlayTime(best));
    final meta = [?levelBoardSize(slot.entry), ?bestText].join(' · ');
    final target = slot.entry.targetSeconds;
    final cleared = node.state == LevelNodeState.done;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.levelWorldTitle(slot.world.order, slot.world.theme),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.levelNumber(slot.number),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Flexible(
                      child: Text(
                        meta,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: ZipColors.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
              if (cleared) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: AppStrings.levelStarsLabel(node.stars, node.maxStars),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var i = 0; i < node.maxStars; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: AppIcon(
                            i < node.stars
                                ? AppIcons.star
                                : AppIcons.starOutline,
                            size: 20,
                            color: i < node.stars
                                ? ZipColors.star
                                : ZipColors.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final goal in [
                AppStrings.levelGoalClear,
                AppStrings.levelGoalNoHints,
                if (target != null)
                  AppStrings.levelGoalUnder(AppStrings.formatPlayTime(target)),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: AppIcon(
                          AppIcons.starOutline,
                          size: 18,
                          color: ZipColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(goal, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ZipPrimaryButton(
                label: cleared ? AppStrings.levelReplay : AppStrings.levelPlay,
                icon: AppIcons.play,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(PlayMode.level(slot.entry.id).location('/zip'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
