import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dev_run_timer_label.dart';
import '../../../core/widgets/game_rule_tip_banner.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_clear_board.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/zip_bloc.dart';
import '../bloc/zip_event.dart';
import '../bloc/zip_state.dart';
import '../game/zip_game.dart';
import '../logic/zip_rule_tip.dart';
import 'widgets/zip_how_to_play.dart';
import 'widgets/zip_shimmer.dart';
import 'widgets/zip_tutorial.dart';

class ZipScreen extends StatefulWidget {
  const ZipScreen({super.key, this.date});

  final DateTime? date;

  @override
  State<ZipScreen> createState() => _ZipScreenState();
}

class _ZipScreenState extends State<ZipScreen> with WidgetsBindingObserver {
  late final ZipBloc _bloc;
  late final HintQuotaRepository _hintQuota;
  late final SfxService _sfx;
  ZipGame? _game;
  bool _tutorialPrompted = false;
  String? _ruleTip;

  static String _messageForTip(ZipRuleTip tip) {
    switch (tip) {
      case ZipRuleTip.startAtOne:
        return AppStrings.zipTipStartAtOne;
      case ZipRuleTip.fillEveryCell:
        return AppStrings.zipTipFillEveryCell;
      case ZipRuleTip.finishOnLast:
        return AppStrings.zipTipFinishOnLast;
      case ZipRuleTip.visitInOrder:
        return AppStrings.zipTipVisitInOrder;
    }
  }

  bool _ensureGame(ZipState state) {
    if (state.status == ZipStatus.initial || state.status == ZipStatus.failed) {
      return false;
    }
    final current = _game;
    if (current != null && identical(current.level, state.level)) return false;
    final remaining = _hintQuota.remaining(GameIds.zip, _bloc.playId);
    _game = ZipGame(
      level: state.level,
      initialHintsRemaining: remaining,
      initialPath: state.path,
      readOnly: state.status == ZipStatus.locked || state.finished,
      onWin: () {
        if (mounted) setState(() => _ruleTip = null);
        _bloc.add(const ZipEvent.completed());
      },
      onPathChanged: (path) {
        _bloc.add(ZipEvent.pathChanged(path: path));
      },
      onStatsChanged: (_, _) {
        if (mounted) setState(() {});
      },
      onRuleTip: (tip) {
        if (!mounted) return;
        setState(() => _ruleTip = _messageForTip(tip));
      },
      onSfx: (id) => unawaited(_sfx.play(id)),
    );
    return true;
  }

  void _maybeShowTutorial(ZipState state) {
    if (_tutorialPrompted) return;
    if (state.status == ZipStatus.initial || state.status == ZipStatus.failed) {
      return;
    }
    if (state.status == ZipStatus.locked || state.finished) return;
    _tutorialPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ZipTutorial.maybeShow(context);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hintQuota = context.read<HintQuotaRepository>();
    _sfx = context.read<SfxService>();
    _bloc = ZipBloc(
      submitScore: context.read<SubmitScore>(),
      submitLeaderboardTime: context.read<SubmitLeaderboardTime>(),
      recordDailyClear: context.read<RecordDailyClear>(),
      getBestPoints: context.read<GetBestPoints>(),
      getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
      getClearBoard: context.read<GetClearBoard>(),
      analytics: context.read<AnalyticsRepository>(),
      inProgressRuns: context.read<InProgressRunRepository>(),
      zipLevelRepository: context.read<ZipLevelRepository>(),
      now: widget.date,
      ignoreDailyLock: DevFlags.zipOnlyTesting,
      playPeriod: DevFlags.playPeriod,
    );
    _bloc.add(ZipEvent.started(date: widget.date));
    _ensureGame(_bloc.state);
    _maybeShowTutorial(_bloc.state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _bloc.add(const ZipEvent.resumeRun());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _bloc.add(const ZipEvent.pauseRun());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(const ZipEvent.pauseRun());
    final game = _game;
    _game = null;
    game?.pauseEngine();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<ZipBloc, ZipState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.status == ZipStatus.navigating,
            listener: (context, state) {
              context.pushReplacement('/results', extra: state.resultsExtra);
            },
          ),
          BlocListener<ZipBloc, ZipState>(
            listenWhen: (prev, curr) =>
                prev.status == ZipStatus.initial &&
                curr.status != ZipStatus.initial,
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
              _maybeShowTutorial(state);
            },
          ),
          BlocListener<ZipBloc, ZipState>(
            listenWhen: (prev, curr) => !identical(prev.level, curr.level),
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
            },
          ),
        ],
        child: BlocBuilder<ZipBloc, ZipState>(
          builder: (context, state) {
            if (state.status != ZipStatus.initial &&
                state.status != ZipStatus.failed) {
              _ensureGame(state);
            }
            final finished = state.finished;
            final game = _game;
            final isReview = state.status == ZipStatus.locked;
            final isLoading = state.status == ZipStatus.initial;
            final isFailed = state.status == ZipStatus.failed;
            final canPlay = !isLoading && !isFailed && !finished && !isReview;
            final canUndo = canPlay && (game?.path.isNotEmpty ?? false);
            final canHint = canPlay && (game?.canHint ?? false);

            return Scaffold(
              body: ZipAtmosphere(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            Expanded(
                              child: Text(
                                AppStrings.zipTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (canPlay)
                              DevRunTimerLabel(
                                elapsedMs: state.elapsedMs,
                                resumedAt: state.resumedAt,
                              ),
                            if (!isReview)
                              IconButton(
                                tooltip: AppStrings.zipClear,
                                onPressed: !canPlay
                                    ? null
                                    : () {
                                        final game = _game;
                                        game?.clearPath();
                                        if (game != null) {
                                          game.hintsRemaining = _hintQuota
                                              .remaining(
                                                GameIds.zip,
                                                _bloc.playId,
                                              );
                                        }
                                        _bloc.add(const ZipEvent.reset());
                                        setState(() => _ruleTip = null);
                                      },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            const ZipHowToPlayButton(),
                          ],
                        ),
                      ).animate().fadeIn(duration: 350.ms),
                      if (isLoading)
                        Expanded(
                          child: Semantics(
                            label: AppStrings.zipLoading,
                            child: const ZipShimmer(),
                          ),
                        )
                      else if (isFailed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppStrings.zipFailed,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: ZipColors.onInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: () => _bloc.add(
                                      ZipEvent.started(date: widget.date),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text(AppStrings.retry),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child:
                                ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: game == null
                                          ? const SizedBox.shrink()
                                          : GameWidget(game: game),
                                    )
                                    .animate(
                                      target:
                                          state.status == ZipStatus.celebrating
                                          ? 1
                                          : 0,
                                    )
                                    .scaleXY(
                                      begin: 1,
                                      end: 1.045,
                                      duration: 520.ms,
                                      curve: Curves.easeOutBack,
                                    )
                                    .shimmer(
                                      duration: 1600.ms,
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                          ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                        ),
                        if (_ruleTip != null && canPlay)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: GameRuleTipBanner(message: _ruleTip!),
                          ),
                        if (!isReview)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: canUndo
                                        ? () {
                                            _game?.undo();
                                            setState(() => _ruleTip = null);
                                          }
                                        : null,
                                    icon: const Icon(Icons.undo_rounded),
                                    label: const Text(AppStrings.zipUndo),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: ZipColors.wall,
                                      foregroundColor: ZipColors.onInk,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: canHint
                                        ? () async {
                                            final game = _game;
                                            if (game == null || !game.canHint) {
                                              return;
                                            }
                                            final before = game.hintsRemaining;
                                            final remaining = await _hintQuota
                                                .tryConsume(
                                                  GameIds.zip,
                                                  _bloc.playId,
                                                );
                                            if (remaining >= before) {
                                              return;
                                            }
                                            if (!game.hint()) {
                                              return;
                                            }
                                            game.hintsRemaining = remaining;
                                            _bloc.add(
                                              ZipEvent.hint(
                                                hintsRemaining: remaining,
                                              ),
                                            );
                                            if (mounted) setState(() {});
                                          }
                                        : null,
                                    icon: const Icon(Icons.lightbulb_rounded),
                                    label: Text(
                                      AppStrings.zipHintWithCount(
                                        game?.hintsRemaining ?? 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
