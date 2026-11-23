import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../strings/app_strings.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Which of a level's star goals a [LevelGoalTile] shows.
enum LevelGoalKind { clear, noHints, time }

/// Where a goal stands: still possible, earned, or out of reach this run.
enum LevelGoalStatus { open, earned, lost }

/// One star goal: its icon, what it asks, and a star that fills when earned.
///
/// [compact] is the in-game pill (one line, beside its two siblings above the
/// board); otherwise the taller tile of the level sheet.
class LevelGoalTile extends StatelessWidget {
  const LevelGoalTile({
    super.key,
    required this.kind,
    required this.label,
    required this.status,
    this.compact = false,
  });

  final LevelGoalKind kind;
  final String label;
  final LevelGoalStatus status;
  final bool compact;

  IconData get _icon => switch (kind) {
    LevelGoalKind.clear => AppIcons.flag,
    LevelGoalKind.noHints => AppIcons.noHints,
    LevelGoalKind.time => AppIcons.timer,
  };

  Color get _accent => switch (kind) {
    LevelGoalKind.clear => ZipColors.success,
    LevelGoalKind.noHints => ZipColors.sky,
    LevelGoalKind.time => ZipColors.ember,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = status == LevelGoalStatus.earned;
    final lost = status == LevelGoalStatus.lost;
    final accent = lost ? ZipColors.outline : _accent;
    final spoken = switch (status) {
      LevelGoalStatus.open => AppStrings.levelGoalOpen(label),
      LevelGoalStatus.earned => AppStrings.levelGoalEarned(label),
      LevelGoalStatus.lost => AppStrings.levelGoalMissed(label),
    };
    final star = AppIcon(
      earned ? AppIcons.star : AppIcons.starOutline,
      size: compact ? 14 : 18,
      color: earned
          ? ZipColors.star
          : lost
          ? ZipColors.outline
          : ZipColors.inkSoft,
    );
    final text = Text(
      label,
      maxLines: compact && MediaQuery.textScalerOf(context).scale(10) <= 13
          ? 1
          : 2,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style:
          (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
              ?.copyWith(
                color: lost ? ZipColors.inkSoft : ZipColors.onInk,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: lost ? TextDecoration.lineThrough : null,
                decorationColor: ZipColors.inkSoft,
              ),
    );
    final decoration = BoxDecoration(
      color: earned
          ? ZipColors.star.withValues(alpha: 0.10)
          : accent.withValues(alpha: lost ? 0.04 : 0.08),
      borderRadius: BorderRadius.circular(compact ? 12 : 18),
      border: Border.all(
        color: earned
            ? ZipColors.star.withValues(alpha: 0.55)
            : accent.withValues(alpha: lost ? 0.25 : 0.35),
      ),
    );

    final Widget body;
    if (compact) {
      body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: decoration,
        child: Row(
          children: [
            star,
            const SizedBox(width: 6),
            // One line beside its siblings: a long label shrinks a little
            // rather than wrapping alone. At large text sizes it wraps
            // instead, so it stays readable (the bar keeps the tiles one
            // height).
            Expanded(
              child: MediaQuery.textScalerOf(context).scale(10) > 13
                  ? text
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: text,
                    ),
            ),
          ],
        ),
      );
    } else {
      body = Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
              ),
              child: AppIcon(_icon, size: 20, color: accent),
            ),
            const SizedBox(height: 8),
            text,
            const SizedBox(height: 6),
            star,
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: lost ? 0.6 : 1,
        duration: const Duration(milliseconds: 250),
        child: body,
      ),
    );
  }
}

/// A level run's star goals above the board, live: No hints drops on the
/// run's first hint, the time goal counts down and drops past the target,
/// and all of them fill once the board is cleared.
///
/// Reads the run clock the way the bloc does ([elapsedMs] plus the time
/// since [resumedAt]), so the countdown matches the stars the clear records.
class LevelGoalsBar extends StatefulWidget {
  const LevelGoalsBar({
    super.key,
    required this.targetSeconds,
    required this.usedHints,
    required this.elapsedMs,
    required this.resumedAt,
    required this.cleared,
  });

  /// Null (or 0 or less) when the level has no time goal.
  final int? targetSeconds;
  final bool usedHints;
  final int elapsedMs;
  final DateTime? resumedAt;
  final bool cleared;

  @override
  State<LevelGoalsBar> createState() => _LevelGoalsBarState();
}

class _LevelGoalsBarState extends State<LevelGoalsBar> {
  Timer? _tick;

  bool get _hasTarget => (widget.targetSeconds ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(covariant LevelGoalsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resumedAt != widget.resumedAt ||
        oldWidget.targetSeconds != widget.targetSeconds) {
      _syncTick();
    }
  }

  void _syncTick() {
    _tick?.cancel();
    _tick = null;
    if (!_hasTarget || widget.resumedAt == null) return;
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      // Nothing left to count once the time goal is gone.
      if (_seconds > widget.targetSeconds!) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _seconds {
    final resumed = widget.resumedAt;
    final live = resumed == null
        ? 0
        : DateTime.now().difference(resumed).inMilliseconds.clamp(0, 1 << 62);
    return (widget.elapsedMs + live) ~/ 1000;
  }

  @override
  Widget build(BuildContext context) {
    final cleared = widget.cleared;
    final target = _hasTarget ? widget.targetSeconds! : null;
    final seconds = _seconds;
    final timeLost = target != null && seconds > target;
    final tiles = <Widget>[
      LevelGoalTile(
        compact: true,
        kind: LevelGoalKind.clear,
        label: AppStrings.levelGoalClear,
        status: cleared ? LevelGoalStatus.earned : LevelGoalStatus.open,
      ),
      LevelGoalTile(
        compact: true,
        kind: LevelGoalKind.noHints,
        label: AppStrings.levelGoalNoHints,
        status: widget.usedHints
            ? LevelGoalStatus.lost
            : cleared
            ? LevelGoalStatus.earned
            : LevelGoalStatus.open,
      ),
      if (target != null)
        LevelGoalTile(
          compact: true,
          kind: LevelGoalKind.time,
          label: timeLost || cleared || seconds == 0
              ? AppStrings.levelGoalUnder(AppStrings.formatPlayTime(target))
              : AppStrings.levelTimeLeft(
                  AppStrings.formatPlayTime(target - seconds),
                ),
          status: timeLost
              ? LevelGoalStatus.lost
              : cleared
              ? LevelGoalStatus.earned
              : LevelGoalStatus.open,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }
}
