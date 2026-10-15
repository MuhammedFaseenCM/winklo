import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/tutorial_repository.dart';
import '../router/pop_or_go_home.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// The rules of a bonus game (Word Match, Category Race) in a dialog, like
/// Sudoku's How to play.
abstract final class BonusHowToPlay {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ZipColors.paper,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.tutorialGotIt),
          ),
        ],
      ),
    );
  }

  /// Shows the rules once, on a player's first run of [gameId]; later runs
  /// return at once. Finishes when the dialog is closed, so the round can
  /// start after it.
  static Future<void> maybeShow(
    BuildContext context, {
    required String gameId,
    required String title,
    required String body,
  }) async {
    final TutorialRepository repo;
    try {
      repo = context.read<TutorialRepository>();
    } on ProviderNotFoundException {
      return; // Not provided in focused widget tests.
    }
    if (await repo.hasSeen(gameId)) return;
    if (!context.mounted) return;
    final analytics = _analytics(context);
    await analytics?.logTutorialShown(gameId: gameId);
    if (!context.mounted) return;
    await show(context, title: title, body: body);
    await analytics?.logTutorialDismissed(gameId: gameId);
    await repo.markSeen(gameId);
  }
}

AnalyticsRepository? _analytics(BuildContext context) {
  try {
    return context.read<AnalyticsRepository>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// A bonus game's top row: back, title, an optional clock and How to play.
class BonusGameHeader extends StatelessWidget {
  const BonusGameHeader({
    super.key,
    required this.title,
    required this.gameId,
    required this.howToPlayBody,
    this.secondsLeft,
  });

  final String title;
  final String gameId;
  final String howToPlayBody;

  /// The round's clock; hidden when null.
  final int? secondsLeft;

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => popOrGoHome(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (seconds != null) BonusClockPill(secondsLeft: seconds),
          IconButton(
            tooltip: AppStrings.zipHowToPlayTitle,
            onPressed: () async {
              await _analytics(context)?.logHowToPlayOpened(gameId: gameId);
              if (!context.mounted) return;
              await BonusHowToPlay.show(
                context,
                title: AppStrings.zipHowToPlayTitle,
                body: howToPlayBody,
              );
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// Seconds left in a round; red in the last ten.
class BonusClockPill extends StatelessWidget {
  const BonusClockPill({super.key, required this.secondsLeft});

  final int secondsLeft;

  static const _hurry = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final hurry = secondsLeft <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hurry ? _hurry.withValues(alpha: 0.2) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hurry ? _hurry.withValues(alpha: 0.55) : ZipColors.glassBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: hurry ? _hurry : ZipColors.ember,
          ),
          const SizedBox(width: 4),
          Text(
            AppStrings.bonusSecondsLeft(secondsLeft),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: hurry ? _hurry : ZipColors.onInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bonus game's error, with Retry.
class BonusGameMessage extends StatelessWidget {
  const BonusGameMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
