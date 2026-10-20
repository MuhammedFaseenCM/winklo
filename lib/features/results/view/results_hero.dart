import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import 'counting_play_time.dart';
import 'ember_burst.dart';

/// "Puzzle cleared!" over the counting time, with the rank badge beside it.
class ResultsHero extends StatefulWidget {
  const ResultsHero({
    super.key,
    required this.title,
    required this.timeSeconds,
    this.rankBadge,
    this.compact = false,
  });

  final String title;
  final int timeSeconds;

  /// Usually a live [ResultsRankBadge]; null for none (guests).
  final Widget? rankBadge;
  final bool compact;

  @override
  State<ResultsHero> createState() => _ResultsHeroState();
}

class _ResultsHeroState extends State<ResultsHero> {
  var _showBurst = false;

  void _landed() {
    if (!mounted || _showBurst) return;
    context.read<HapticsService?>()?.play(HapticKind.light);
    setState(() => _showBurst = true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeStyle = textTheme.displayLarge?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w900,
      letterSpacing: -2,
      height: 1,
      fontSize: widget.compact ? 48 : 56,
      shadows: [
        Shadow(
          color: ZipColors.emberGlow.withValues(alpha: 0.75),
          blurRadius: 32,
        ),
        Shadow(color: ZipColors.ember.withValues(alpha: 0.35), blurRadius: 16),
      ],
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_showBurst) const Positioned.fill(child: EmberBurst()),
                    CountingPlayTime(
                      timeSeconds: widget.timeSeconds,
                      style: timeStyle,
                      textAlign: TextAlign.start,
                      onCompleted: _landed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ?widget.rankBadge,
      ],
    );
  }
}

/// "#14 / of 18 today" in an ember square; an empty outline while [rank] is
/// null (the board is loading).
class ResultsRankBadge extends StatelessWidget {
  const ResultsRankBadge({
    super.key,
    this.rank,
    this.total = 0,
    this.capped = false,
    this.compact = false,
  });

  final int? rank;
  final int total;

  /// The board filled its row limit, so "of 50+".
  final bool capped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = compact ? 68.0 : 76.0;
    final rank = this.rank;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ZipColors.ember.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZipColors.ember.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: rank == null
          ? null
          : Semantics(
              label: AppStrings.resultsRankSemantics(
                rank,
                total,
                capped: capped,
              ),
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$rank',
                      style: textTheme.headlineSmall?.copyWith(
                        color: ZipColors.ember,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 22 : 24,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.resultsRankOfToday(total, capped: capped),
                      style: textTheme.labelSmall?.copyWith(
                        color: ZipColors.inkSoft,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
