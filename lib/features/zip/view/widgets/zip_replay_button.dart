import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/entities/zip_level.dart';
import '../../cubit/zip_replay_cubit.dart';
import '../../game/zip_game.dart';

/// Under a reviewed Zip board: redraws the player's saved path in order.
/// Nothing shows when there is no saved winning path to replay.
class ZipReplayButton extends StatelessWidget {
  const ZipReplayButton({
    super.key,
    required this.game,
    required this.level,
    required this.savedPath,
  });

  final ZipGame game;
  final ZipLevel level;
  final List<Cell> savedPath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ZipReplayCubit(level: level, savedPath: savedPath),
      child: BlocBuilder<ZipReplayCubit, ZipReplayState>(
        builder: (context, state) {
          if (!state.available) return const SizedBox.shrink();
          final cubit = context.read<ZipReplayCubit>();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: state.playing
                    ? null
                    : () {
                        if (!cubit.start()) return;
                        final started = game.replay(
                          cubit.path,
                          onReplayFinished: cubit.finished,
                        );
                        // Never leave the button stuck on a replay that
                        // didn't start.
                        if (!started) cubit.finished();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: ZipColors.ember,
                  disabledForegroundColor: ZipColors.inkSoft,
                ),
                icon: const AppIcon(AppIcons.replay),
                label: Text(AppStrings.zipReplay),
              ),
            ),
          );
        },
      ),
    );
  }
}
