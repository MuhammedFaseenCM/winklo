import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_rule_tip_banner.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/zip_bloc.dart';
import '../bloc/zip_event.dart';
import '../bloc/zip_state.dart';
import '../game/zip_game.dart';
import '../logic/zip_rule_tip.dart';
import 'widgets/zip_how_to_play.dart';
import 'widgets/zip_tutorial.dart';

class ZipScreen extends StatefulWidget {
  const ZipScreen({super.key, this.date});

  final DateTime? date;

  @override
  State<ZipScreen> createState() => _ZipScreenState();
}

class _ZipScreenState extends State<ZipScreen> {
  late final ZipBloc _bloc;
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
    final current = _game;
    if (current != null && current.level.id == state.level.id) return false;
    _game = ZipGame(
      level: state.level,
      readOnly: state.status == ZipStatus.locked || state.finished,
      onWin: (points, elapsedSeconds) {
        if (mounted) setState(() => _ruleTip = null);
        _bloc.add(
          ZipEvent.completed(points: points, timeSeconds: elapsedSeconds),
        );
      },
      onStatsChanged: (_, _) {
        if (mounted) setState(() {});
      },
      onRuleTip: (tip) {
        if (!mounted) return;
        setState(() => _ruleTip = _messageForTip(tip));
      },
    );
    return true;
  }

  void _maybeShowTutorial(ZipState state) {
    if (_tutorialPrompted) return;
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
    _bloc = ZipBloc(
      submitScore: context.read<SubmitScore>(),
      submitLeaderboardTime: context.read<SubmitLeaderboardTime>(),
      recordDailyClear: context.read<RecordDailyClear>(),
      getBestPoints: context.read<GetBestPoints>(),
      getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
      analytics: context.read<AnalyticsRepository>(),
      now: widget.date,
      ignoreDailyLock: DevFlags.zipOnlyTesting,
      playPeriod: DevFlags.playPeriod,
    );
    _bloc.add(ZipEvent.started(date: widget.date));
    _ensureGame(_bloc.state);
    _maybeShowTutorial(_bloc.state);
  }

  @override
  void dispose() {
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
            listenWhen: (prev, curr) => prev.level.id != curr.level.id,
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
            },
          ),
        ],
        child: BlocBuilder<ZipBloc, ZipState>(
          builder: (context, state) {
            final finished = state.finished;
            final game = _game;
            final isReview = state.status == ZipStatus.locked;
            final canPlay = !finished && !isReview;
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
                            if (!isReview)
                              IconButton(
                                tooltip: AppStrings.zipClear,
                                onPressed: !canPlay
                                    ? null
                                    : () {
                                        _game?.clearPath();
                                        _bloc.add(const ZipEvent.reset());
                                        setState(() => _ruleTip = null);
                                      },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            const ZipHowToPlayButton(),
                          ],
                        ),
                      ).animate().fadeIn(duration: 350.ms),
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
                                    color: Colors.white.withValues(alpha: 0.28),
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
                                      ? () {
                                          final game = _game;
                                          if (game == null || !game.hint()) {
                                            return;
                                          }
                                          _bloc.add(
                                            ZipEvent.hint(
                                              hintsRemaining:
                                                  game.hintsRemaining,
                                            ),
                                          );
                                          setState(() {});
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
