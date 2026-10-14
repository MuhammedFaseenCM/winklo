import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/next_puzzle_countdown.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_clear_meta.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../cubit/cleared_summary_cubit.dart';
import '../cubit/cleared_summary_state.dart';
import '../logic/cleared_summary_text.dart';

/// Under a cleared daily's board: "Cleared in 1:12 · #4 today · Hint-free",
/// the countdown to the next puzzle and a link to the full board.
class ClearedSummaryCard extends StatelessWidget {
  const ClearedSummaryCard({
    super.key,
    required this.gameId,
    required this.modeKey,
    required this.day,
  });

  final String gameId;

  /// The key the game stores this daily's best under.
  final String modeKey;

  /// The daily's calendar day.
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ClearedSummaryCubit(
        gameId: gameId,
        modeKey: modeKey,
        day: day,
        getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
        getClearMeta: context.read<GetClearMeta>(),
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
      ),
      child: _ClearedSummaryBody(gameId: gameId, day: day),
    );
  }
}

/// Lets a narrow card wrap only at the " · " between chunks, so "#48 today"
/// never splits across lines.
String _wrapBetweenChunks(String summary) => summary
    .split(' · ')
    .map((chunk) => chunk.replaceAll(' ', '\u00A0'))
    .join(' · ');

class _ClearedSummaryBody extends StatelessWidget {
  const _ClearedSummaryBody({required this.gameId, required this.day});

  final String gameId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period = DevFlags.playPeriod;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: ZipColors.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<ClearedSummaryCubit, ClearedSummaryState>(
                  builder: (context, state) => Text(
                    _wrapBetweenChunks(
                      clearedSummaryText(
                        gameId: gameId,
                        timeSeconds: state.timeSeconds,
                        rank: state.rank,
                        usedHints: state.usedHints,
                        hadMistakes: state.hadMistakes,
                      ),
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                NextPuzzleCountdown(
                  period: period,
                  // A date can't place a minute-long debug period.
                  periodOf: PlayPeriod.isSubDaily(period) ? null : day,
                  style: textTheme.bodySmall?.copyWith(
                    color: ZipColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/leaderboard?game=$gameId'),
            style: TextButton.styleFrom(foregroundColor: ZipColors.ember),
            child: const Text(AppStrings.resultsFullBoard),
          ),
        ],
      ),
    );
  }
}
