import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/failures.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/share_repository.dart';
import '../../../domain/usecases/next_uncleared_daily.dart';
import '../logic/result_share_text.dart';
import '../results_args.dart';

/// What to do after clearing a daily: play the next uncleared one, share the
/// result, open the full board, or go home. Each tap logs a `results_action`.
class ResultsActions extends StatelessWidget {
  const ResultsActions({super.key, required this.args});

  final ResultsArgs args;

  String get _gameId => args.gameId!;

  Future<void> _log(BuildContext context, String action) {
    return context.read<AnalyticsRepository>().logResultsAction(
      gameId: _gameId,
      action: action,
    );
  }

  Future<void> _share(BuildContext context) async {
    final share = context.read<ShareRepository>();
    final analytics = context.read<AnalyticsRepository>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _log(context, 'share');
    final bool shared;
    try {
      shared = await share.shareText(
        resultShareText(
          gameId: _gameId,
          day: args.day ?? DateTime.now(),
          timeSeconds: args.timeSeconds,
          currentStreak: args.currentStreak,
          usedHints: args.usedHints,
          hadMistakes: args.hadMistakes,
        ),
      );
    } on Failure {
      messenger?.showSnackBar(SnackBar(content: Text(AppStrings.shareFailed)));
      return;
    }
    if (shared) await analytics.logShare(gameId: _gameId);
  }

  static String _routeFor(String gameId) => switch (gameId) {
    GameIds.pathWords => '/path-words',
    GameIds.sudoku => '/sudoku',
    _ => '/zip',
  };

  static String _titleFor(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTitle,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    // The game routes open today's puzzle, so ask about today even when the
    // run just cleared was left open over midnight.
    final next = context.read<NextUnclearedDaily>()(
      justCleared: _gameId,
      playId: PlayPeriod.id(DateTime.now(), DevFlags.playPeriod),
    );

    // Compact, with home as an icon, so the live board above (which shares
    // this Expanded) keeps room for its rows on small phones.
    const compactPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final compactStyle = OutlinedButton.styleFrom(padding: compactPadding);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          ZipPrimaryButton(
            label: AppStrings.playNextGame(_titleFor(next)),
            icon: AppIcons.play,
            compact: true,
            onPressed: () async {
              await _log(context, 'play_next');
              if (!context.mounted) return;
              context.pushReplacement(_routeFor(next));
            },
          )
        else
          Text(
            AppStrings.perfectDay,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _OneAtATimeButton(
                style: compactStyle,
                onPressed: () => _share(context),
                icon: AppIcons.share,
                label: AppStrings.shareResult,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: compactStyle,
                onPressed: () async {
                  await _log(context, 'leaderboard');
                  if (!context.mounted) return;
                  context.go('/leaderboard?game=$_gameId');
                },
                icon: const AppIcon(AppIcons.ranking),
                label: Text(
                  AppStrings.resultsFullBoard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: AppStrings.backHome,
              onPressed: () async {
                await _log(context, 'home');
                if (!context.mounted) return;
                context.go('/');
              },
              icon: const AppIcon(AppIcons.home),
            ),
          ],
        ),
      ],
    );
  }
}

/// An outlined button that ignores taps until its last press finishes, so a
/// double tap can't open the share sheet twice.
class _OneAtATimeButton extends StatefulWidget {
  const _OneAtATimeButton({
    required this.style,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final ButtonStyle style;
  final Future<void> Function() onPressed;
  final IconData icon;
  final String label;

  @override
  State<_OneAtATimeButton> createState() => _OneAtATimeButtonState();
}

class _OneAtATimeButtonState extends State<_OneAtATimeButton> {
  var _busy = false;

  Future<void> _press() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: widget.style,
      onPressed: _busy ? null : _press,
      icon: AppIcon(widget.icon),
      label: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
