import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/dev_flags.dart';
import '../../core/haptics/haptics_service.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/next_puzzle_countdown.dart';
import '../../core/widgets/zip_ui.dart';
import '../../domain/game_ids.dart';
import '../../domain/play_period.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/usecases/submit_leaderboard_time.dart';
import '../achievements/view/new_achievements_banner.dart';
import '../auth/cubit/auth_cubit.dart';
import '../auth/view/sign_in_sheet.dart';
import '../path_words/view/widgets/path_words_results_panel.dart';
import 'results_args.dart';
import 'view/counting_play_time.dart';
import 'view/ember_burst.dart';
import 'view/local_results_view.dart';
import 'view/mini_leaderboard_panel.dart';
import 'view/results_actions.dart';
import 'view/results_board_tease.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.args});

  final ResultsArgs args;

  Future<void> _logAction(BuildContext context, String action) {
    final gameId = args.gameId;
    if (gameId == null || gameId.isEmpty) return Future<void>.value();
    return context.read<AnalyticsRepository>().logResultsAction(
      gameId: gameId,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Archive, practice and bonus runs: a local best, nothing of the dailies.
    if (args.local != null) return LocalResultsView(args: args);
    switch (args.gameId) {
      case GameIds.zip:
      case GameIds.pathWords:
      case GameIds.sudoku:
        return _CelebrateAndClaimResults(args: args);
      default:
        break;
    }

    final title = args.title;
    final subtitle = args.subtitle;
    final time = args.timeSeconds;
    final improved = args.improved;
    final replayDaily = args.replayDaily;
    final replayId = args.replayLevelId;
    final nextId = args.nextLevelId;
    final points = args.points;

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const ZipMark(size: 72)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: ZipColors.inkSoft),
                  ).animate().fadeIn(delay: 120.ms),
                ],
                const SizedBox(height: 28),
                _ResultsCelebrationCard(
                      timeSeconds: time,
                      improved: improved,
                      points: points,
                      currentStreak: args.currentStreak,
                      longestStreak: args.longestStreak,
                    )
                    .animate()
                    .fadeIn(delay: 160.ms, duration: 450.ms)
                    .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                if (replayDaily)
                  Text(
                    AppStrings.newPuzzleUnlocksTomorrow,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
                  ),
                const Spacer(),
                if (!replayDaily &&
                    (replayId != null || args.replayRoute != null))
                  ZipPrimaryButton(
                    label: AppStrings.playAgain,
                    icon: Icons.refresh_rounded,
                    onPressed: () async {
                      await _logAction(context, 'play_again');
                      if (!context.mounted) return;
                      final route =
                          args.replayRoute ??
                          (replayId != null ? '/zip' : null);
                      if (route != null) {
                        context.pushReplacement(route);
                      }
                    },
                  ).animate().fadeIn(delay: 220.ms)
                else if (replayDaily)
                  ZipPrimaryButton(
                    label: AppStrings.backHome,
                    icon: Icons.home_rounded,
                    onPressed: () async {
                      await _logAction(context, 'home');
                      if (!context.mounted) return;
                      context.go('/');
                    },
                  ).animate().fadeIn(delay: 220.ms),
                if (nextId != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await _logAction(context, 'play_other');
                      if (!context.mounted) return;
                      context.pushReplacement('/zip');
                    },
                    child: const Text(AppStrings.resultsNextPuzzle),
                  ),
                ],
                if (!replayDaily) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () async {
                      await _logAction(context, 'home');
                      if (!context.mounted) return;
                      context.go('/');
                    },
                    child: Text(AppStrings.backHome),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zip / Path Words: celebrate first; soft claim for guests; mini board when signed in.
class _CelebrateAndClaimResults extends StatelessWidget {
  const _CelebrateAndClaimResults({required this.args});

  /// The mini board's title, a row or two and the actions footer.
  static const _minBoardHeight = 300.0;

  /// Enough of the celebration to show the clear time.
  static const _minHeaderHeight = 200.0;

  final ResultsArgs args;

  Future<void> _signInAndSync(BuildContext context) async {
    final ok = await showSignInSheet(
      context,
      title: AppStrings.saveTimeSignInTitle,
      body: AppStrings.saveTimeSignInBody,
    );
    if (!ok || !context.mounted) return;
    if (args.timeSeconds <= 0) return;
    final gameId = args.gameId;
    if (gameId == null || gameId.isEmpty) return;
    try {
      await context.read<SubmitLeaderboardTime>()(
        gameId: gameId,
        timeSeconds: args.timeSeconds,
        usedHints: args.usedHints ?? true,
        hadMistakes: args.hadMistakes ?? true,
        currentStreak: args.currentStreak ?? 0,
        dayId: args.leaderboardDay,
        proof: args.leaderboardProof,
      );
    } catch (_) {
      // Best-effort remote sync; signed-in UI still shows live board.
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthCubit>().isSignedIn;
    final timeLabel = AppStrings.formatPlayTime(args.timeSeconds);
    final gameId = args.gameId!;

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: signedIn
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final height = constraints.maxHeight;
                      final board = MiniLeaderboardPanel(
                        gameId: gameId,
                        timeSeconds: args.timeSeconds,
                        usedHints: args.usedHints,
                        hadMistakes: args.hadMistakes,
                        currentStreak: args.currentStreak,
                        footer: ResultsActions(args: args),
                        dayId: args.leaderboardDay,
                        leaderboardProof: args.leaderboardProof,
                      );
                      if (height < _minHeaderHeight + 12 + _minBoardHeight) {
                        // Sideways or split screen: no room for both, so the
                        // whole page scrolls, celebration first.
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _celebrationHeader(context, compact: true),
                              const SizedBox(height: 12),
                              SizedBox(height: _minBoardHeight, child: board),
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The celebration takes the height it needs, up to
                          // just over half the screen and never squeezing the
                          // board below its minimum (it scrolls past that);
                          // the board gets the rest.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.min(
                                height * 0.55,
                                height - 12 - _minBoardHeight,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: _celebrationHeader(context, compact: true),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: board),
                        ],
                      );
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _celebrationHeader(context, compact: true),
                              const SizedBox(height: 14),
                              ResultsBoardTease(
                                    height: 120,
                                    onTap: () => _signInAndSync(context),
                                  )
                                  .animate()
                                  .fadeIn(delay: 500.ms, duration: 400.ms)
                                  .slideY(
                                    begin: 0.08,
                                    curve: Curves.easeOutCubic,
                                  ),
                              const SizedBox(height: 16),
                              ZipPrimaryButton(
                                    label: AppStrings.saveTimeToBoard(
                                      timeLabel,
                                    ),
                                    icon: Icons.emoji_events_rounded,
                                    onPressed: () => _signInAndSync(context),
                                  )
                                  .animate()
                                  .fadeIn(delay: 850.ms, duration: 400.ms)
                                  .slideY(
                                    begin: 0.15,
                                    curve: Curves.easeOutCubic,
                                  ),
                              TextButton(
                                onPressed: () => context.go('/'),
                                child: Text(AppStrings.backHome),
                              ).animate().fadeIn(delay: 950.ms),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _celebrationHeader(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZipMark(size: compact ? 40 : 56)
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),
        SizedBox(height: compact ? 8 : 12),
        Text(
          args.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
        SizedBox(height: compact ? 12 : 20),
        _ResultsCelebrationCard(
              timeSeconds: args.timeSeconds,
              improved: args.improved,
              // Leaderboard ranks by time — points clutter the win card.
              points: null,
              currentStreak: args.currentStreak,
              longestStreak: args.longestStreak,
              celebrateMotion: true,
              compact: compact,
            )
            .animate()
            .fadeIn(delay: 160.ms, duration: 450.ms)
            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
        SizedBox(height: compact ? 10 : 14),
        _NextPuzzleLine(day: args.day).animate().fadeIn(delay: 700.ms),
        NewAchievementsBanner(occasion: args),
        if (args.pathWords != null) ...[
          SizedBox(height: compact ? 12 : 16),
          PathWordsResultsPanel(
            summary: args.pathWords!,
          ).animate().fadeIn(delay: 800.ms),
        ],
      ],
    );
  }
}

/// "New puzzle in 6h 12m" under the daily result.
class _NextPuzzleLine extends StatelessWidget {
  const _NextPuzzleLine({this.day});

  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final period = DevFlags.playPeriod;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 16, color: style?.color),
        const SizedBox(width: 6),
        Flexible(
          child: NextPuzzleCountdown(
            period: period,
            // The run's day is a date, which can't place a minute-long
            // debug period.
            periodOf: PlayPeriod.isSubDaily(period) ? null : day,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ResultsCelebrationCard extends StatefulWidget {
  const _ResultsCelebrationCard({
    required this.timeSeconds,
    required this.improved,
    this.points,
    this.currentStreak,
    this.longestStreak,
    this.celebrateMotion = false,
    this.compact = false,
  });

  final int timeSeconds;
  final bool improved;
  final int? points;
  final int? currentStreak;
  final int? longestStreak;
  final bool celebrateMotion;
  final bool compact;

  @override
  State<_ResultsCelebrationCard> createState() =>
      _ResultsCelebrationCardState();
}

class _ResultsCelebrationCardState extends State<_ResultsCelebrationCard> {
  var _showBurst = false;

  void _onTimeLanded() {
    if (!mounted || _showBurst) return;
    context.read<HapticsService?>()?.play(HapticKind.light);
    setState(() => _showBurst = true);
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final timeStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w900,
      letterSpacing: -2,
      height: 1,
      fontSize: compact ? 64 : 72,
      shadows: [
        Shadow(
          color: ZipColors.emberGlow.withValues(alpha: 0.75),
          blurRadius: 36,
        ),
        Shadow(color: ZipColors.ember.withValues(alpha: 0.35), blurRadius: 18),
      ],
    );

    Widget timeWidget;
    if (widget.celebrateMotion) {
      timeWidget = SizedBox(
        height: compact ? 88 : 108,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_showBurst) const Positioned.fill(child: EmberBurst()),
            CountingPlayTime(
              timeSeconds: widget.timeSeconds,
              style: timeStyle,
              textAlign: TextAlign.center,
              onCompleted: _onTimeLanded,
            ),
          ],
        ),
      );
    } else {
      timeWidget = Text(
        AppStrings.formatPlayTime(widget.timeSeconds),
        textAlign: TextAlign.center,
        style: timeStyle,
      );
    }

    Widget badgeWrap(Widget child, {required int delayMs}) {
      if (!widget.celebrateMotion) return child;
      return child
          .animate()
          .fadeIn(delay: delayMs.ms, duration: 350.ms)
          .scale(
            begin: const Offset(0.86, 0.86),
            curve: Curves.easeOutBack,
            duration: 420.ms,
            delay: delayMs.ms,
          );
    }

    final pbDelay = 520;
    final streakDelay = widget.improved ? 600 : 520;
    final hasBadges =
        widget.improved ||
        (widget.currentStreak != null && widget.currentStreak! > 0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 20 : 28,
        horizontal: compact ? 16 : 24,
      ),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: ZipColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          timeWidget,
          SizedBox(height: compact ? 4 : 8),
          Text(
            AppStrings.resultsTimeLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          if (widget.points != null) ...[
            const SizedBox(height: 18),
            badgeWrap(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.points}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: ZipColors.onInk,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'points',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ZipColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              delayMs: 520,
            ),
          ],
          if (hasBadges) ...[
            SizedBox(height: compact ? 14 : 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.improved)
                  badgeWrap(
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 14,
                        vertical: compact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: ZipColors.successSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: ZipColors.success.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZipColors.success.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: ZipColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.newPersonalBest,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: ZipColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    delayMs: pbDelay,
                  ),
                if (widget.currentStreak != null && widget.currentStreak! > 0)
                  badgeWrap(
                    ZipHudPill(
                      icon: Icons.local_fire_department_rounded,
                      label: AppStrings.streakLabel(widget.currentStreak!),
                      emphasize: true,
                    ),
                    delayMs: streakDelay,
                  ),
              ],
            ),
            if (widget.longestStreak != null && widget.longestStreak! > 0) ...[
              SizedBox(height: compact ? 6 : 8),
              badgeWrap(
                Text(
                  AppStrings.longestStreakLabel(widget.longestStreak!),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: ZipColors.inkSoft),
                ),
                delayMs: streakDelay + 60,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
