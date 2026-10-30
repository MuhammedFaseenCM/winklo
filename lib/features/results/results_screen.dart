import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/zip_ui.dart';
import '../../domain/game_ids.dart';
import '../../domain/leaderboard_limits.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/app_review_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/submit_leaderboard_time.dart';
import '../../domain/usecases/watch_leaderboard.dart';
import '../achievements/view/new_achievements_banner.dart';
import '../auth/cubit/auth_cubit.dart';
import '../auth/view/sign_in_sheet.dart';
import '../leaderboard/cubit/leaderboard_cubit.dart';
import '../leaderboard/cubit/leaderboard_state.dart';
import '../leaderboard/view/widgets/leaderboard_table.dart';
import 'logic/result_tiles.dart';
import 'results_args.dart';
import 'view/level_results_view.dart';
import 'view/local_results_view.dart';
import 'view/mini_leaderboard_panel.dart';
import 'view/result_tiles_row.dart';
import 'view/results_actions.dart';
import 'view/results_board_card.dart';
import 'view/results_board_tease.dart';
import 'view/results_hero.dart';
import 'view/results_top_bar.dart';

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
    if (args.local?.kind == LocalResultKind.level) {
      return LevelResultsView(args: args);
    }
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
                    icon: AppIcons.refresh,
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
                    icon: AppIcons.home,
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
                    child: Text(AppStrings.resultsNextPuzzle),
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

/// Zip / Path Words / Sudoku: the scoreboard. Guests get the same page with
/// a soft claim in place of the board, and no rank.
class _CelebrateAndClaimResults extends StatelessWidget {
  const _CelebrateAndClaimResults({required this.args});

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
    final Widget page = signedIn
        ? BlocProvider(
            // One board for the page: the rank badge and the table read it.
            create: (context) => LeaderboardCubit(
              watchLeaderboard: context.read<WatchLeaderboard>(),
              authRepository: context.read<AuthRepository>(),
              initialGameId: args.gameId!,
            )..selectDay(args.leaderboardDay),
            child: _Scoreboard(args: args, signedIn: true),
          )
        : _Scoreboard(
            args: args,
            signedIn: false,
            onSave: () => _signInAndSync(context),
          );
    return _ReviewPromptHost(
      args: args,
      child: Scaffold(
        body: ZipAtmosphere(
          child: SafeArea(
            child: Center(
              // Tablets and sideways phones: the table's width, centred.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: leaderboardTableMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: page,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page: top bar, hero, tiles, any new badges, the board card and the
/// action bar. The card takes what's left; below [_scrollBelow] the whole
/// page scrolls and the card keeps room for four rows.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.args, required this.signedIn, this.onSave});

  final ResultsArgs args;
  final bool signedIn;

  /// Guests: sign in and save the time.
  final VoidCallback? onSave;

  /// Shorter than this (sideways, split screen), the page scrolls.
  static const double _scrollBelow = 560;

  /// Shorter than this, the hero, badge and tiles take a smaller step.
  static const double _compactBelow = 640;

  @override
  Widget build(BuildContext context) {
    final gameId = args.gameId!;
    final tiles = resultTilesFor(
      gameId: gameId,
      improved: args.improved,
      currentStreak: args.currentStreak,
      longestStreak: args.longestStreak,
      usedHints: args.usedHints,
      hadMistakes: args.hadMistakes,
      hintPenaltySeconds: args.hintPenaltySeconds,
      bonusWords: args.pathWords?.bonusWords.length ?? 0,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < _compactBelow;
        final gap = compact ? 8.0 : 12.0;

        final header = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResultsTopBar(gameId: gameId, day: args.day),
            SizedBox(height: gap),
            ResultsHero(
              title: args.title,
              timeSeconds: args.timeSeconds,
              compact: compact,
              rankBadge: signedIn ? _LiveRankBadge(compact: compact) : null,
            ).animate().fadeIn(duration: 400.ms),
            if (tiles.isNotEmpty) ...[
              SizedBox(height: gap),
              ResultTilesRow(tiles: tiles, compact: compact),
            ],
            NewAchievementsBanner(occasion: args),
          ],
        );

        final card =
            ResultsBoardCard(
                  pathWords: args.pathWords,
                  board: signedIn
                      ? MiniLeaderboardPanel(
                          gameId: gameId,
                          cubit: context.read<LeaderboardCubit>(),
                          timeSeconds: args.timeSeconds,
                          usedHints: args.usedHints,
                          hadMistakes: args.hadMistakes,
                          currentStreak: args.currentStreak,
                          dayId: args.leaderboardDay,
                          leaderboardProof: args.leaderboardProof,
                        )
                      : ResultsBoardTease(framed: false, onTap: onSave!),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms)
                .slideY(begin: 0.06, curve: Curves.easeOutCubic);

        final bar = signedIn
            ? ResultsActions(args: args)
            : _GuestBar(timeSeconds: args.timeSeconds, onSave: onSave!);
        final shownBar = bar.animate().fadeIn(delay: 400.ms, duration: 350.ms);

        if (height < _scrollBelow) {
          final cardHeight =
              4 * leaderboardTableRowHeight +
              miniLeaderboardGapRowHeight +
              (args.pathWords != null ? resultsBoardSwitchHeight : 0);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                SizedBox(height: gap),
                SizedBox(height: cardHeight, child: card),
                SizedBox(height: gap),
                shownBar,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            SizedBox(height: gap),
            Expanded(child: card),
            SizedBox(height: gap),
            shownBar,
          ],
        );
      },
    );
  }
}

/// The rank badge, fed by the board: an outline while it loads, nothing
/// when the player isn't on it.
class _LiveRankBadge extends StatelessWidget {
  const _LiveRankBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        Widget child = const SizedBox.shrink(key: ValueKey('none'));
        if (state.status == LeaderboardStatus.loading) {
          child = Padding(
            key: const ValueKey('loading'),
            padding: const EdgeInsets.only(left: 12),
            child: ResultsRankBadge(compact: compact),
          );
        } else if (state.status == LeaderboardStatus.ready) {
          final me = state.entries
              .where((e) => e.uid == state.currentUid)
              .firstOrNull;
          if (me != null) {
            child = Padding(
              key: const ValueKey('rank'),
              padding: const EdgeInsets.only(left: 12),
              child: ResultsRankBadge(
                rank: me.rank,
                total: state.entries.length,
                capped: state.entries.length >= leaderboardDailyLimit,
                compact: compact,
              ),
            );
          }
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// A guest's bar: home, and save the time to today's board.
class _GuestBar extends StatelessWidget {
  const _GuestBar({required this.timeSeconds, required this.onSave});

  final int timeSeconds;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ResultsIconAction(
          tooltip: AppStrings.backHome,
          icon: AppIcons.home,
          onPressed: () => context.go('/'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ZipPrimaryButton(
            label: AppStrings.saveTimeToBoard(
              AppStrings.formatPlayTime(timeSeconds),
            ),
            icon: AppIcons.trophy,
            compact: true,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}

/// One-shot Play Store review prompt after daily celebration settles.
class _ReviewPromptHost extends StatefulWidget {
  const _ReviewPromptHost({required this.args, required this.child});

  final ResultsArgs args;
  final Widget child;

  @override
  State<_ReviewPromptHost> createState() => _ReviewPromptHostState();
}

class _ReviewPromptHostState extends State<_ReviewPromptHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAsk());
    });
  }

  Future<void> _maybeAsk() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final review = context.read<AppReviewRepository>();
    final args = widget.args;
    if (!review.shouldPromptAfterMilestone(
      isPersonalBest: args.improved,
      streak: args.currentStreak,
    )) {
      return;
    }
    final outcome = await review.requestReviewOrOpenStore();
    await review.recordAutoPromptAttempt();
    if (!mounted) return;
    final source = args.improved ? 'personal_best' : 'streak';
    await context.read<AnalyticsRepository>().logReviewPrompt(
      source: source,
      outcome: switch (outcome) {
        ReviewOutcome.inApp => 'in_app',
        ReviewOutcome.store => 'store',
        ReviewOutcome.failed => 'failed',
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The time, points and badges of a result off the daily boards (the
/// legacy path; dailies show the scoreboard).
class _ResultsCelebrationCard extends StatelessWidget {
  const _ResultsCelebrationCard({
    required this.timeSeconds,
    required this.improved,
    this.points,
    this.currentStreak,
    this.longestStreak,
  });

  final int timeSeconds;
  final bool improved;
  final int? points;
  final int? currentStreak;
  final int? longestStreak;

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w900,
      letterSpacing: -2,
      height: 1,
      fontSize: 72,
      shadows: [
        Shadow(
          color: ZipColors.emberGlow.withValues(alpha: 0.75),
          blurRadius: 36,
        ),
        Shadow(color: ZipColors.ember.withValues(alpha: 0.35), blurRadius: 18),
      ],
    );
    final streak = currentStreak;
    final longest = longestStreak;
    final hasBadges = improved || (streak != null && streak > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(28),
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
          Text(
            AppStrings.formatPlayTime(timeSeconds),
            textAlign: TextAlign.center,
            style: timeStyle,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.resultsTimeLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: latinTracking(2.5),
            ),
          ),
          if (points != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Column(
                children: [
                  Text(
                    '$points',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    AppStrings.resultsPointsLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasBadges) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (improved)
                  ZipHudPill(
                    icon: AppIcons.star,
                    label: AppStrings.newPersonalBest,
                    emphasize: true,
                  ),
                if (streak != null && streak > 0)
                  ZipHudPill(
                    icon: AppIcons.streak,
                    label: AppStrings.streakLabel(streak),
                    emphasize: true,
                  ),
              ],
            ),
            if (longest != null && longest > 0) ...[
              const SizedBox(height: 8),
              Text(
                AppStrings.longestStreakLabel(longest),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: ZipColors.inkSoft),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
