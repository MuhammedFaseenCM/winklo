import 'dart:math' as math;

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
import '../../../domain/entities/cell.dart';
import '../../../domain/path_words/path_words_rules.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/generate_daily_path_words.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/path_words_bloc.dart';
import '../bloc/path_words_event.dart';
import '../bloc/path_words_state.dart';
import '../game/path_words_board_view.dart';
import '../game/path_words_game.dart';
import 'widgets/path_words_how_to_play.dart';
import 'widgets/path_words_tutorial.dart';
import 'widgets/path_words_word_list.dart';

class PathWordsScreen extends StatefulWidget {
  const PathWordsScreen({
    super.key,
    this.date,
    this.bloc,
    this.autoStart = true,
  });

  final DateTime? date;
  final PathWordsBloc? bloc;
  final bool autoStart;

  @override
  State<PathWordsScreen> createState() => _PathWordsScreenState();
}

class _PathWordsScreenState extends State<PathWordsScreen> {
  late final PathWordsBloc _bloc;
  late final bool _ownsBloc;
  PathWordsGame? _game;
  bool _tutorialPrompted = false;

  void _applyViewToGame(PathWordsBoardView view) {
    final game = _game;
    if (game == null) return;

    if (game.hasLayout) {
      game.applyView(view);
      return;
    }

    // Game isn't attached to a GameWidget yet; avoid touching layout.
    game.view = view;
  }

  PathWordsBoardView? _viewFor(PathWordsState state) {
    final puzzle = state.puzzle;
    if (puzzle == null) return null;

    final completedPaths = <String, List<Cell>>{};
    for (final target in puzzle.targets) {
      if (state.completedTargetIds.contains(target.id)) {
        completedPaths[target.id] = target.path;
      }
    }

    return PathWordsBoardView(
      puzzle: puzzle,
      activePath: state.activePath,
      placedPaths: state.placedPaths,
      completedPathsByTargetId: completedPaths,
      hintPath: PathWordsRules.hintedPath(
        puzzle: puzzle,
        completedTargetIds: state.completedTargetIds,
        revealedLength: state.hintRevealLength,
      ),
      hintRevealLength: state.hintRevealLength,
      celebrate: state.status == PathWordsStatus.celebrating,
      inputEnabled:
          !state.finished &&
          (state.status == PathWordsStatus.ready ||
              state.status == PathWordsStatus.playing),
    );
  }

  bool _ensureGame(PathWordsState state) {
    final view = _viewFor(state);
    if (view == null) return false;

    final current = _game;
    if (current != null && current.view.puzzle.id == view.puzzle.id) {
      _applyViewToGame(view);
      return false;
    }

    _game = PathWordsGame(
      view: view,
      onPointerDown: (cell) => _bloc.add(PathWordsEvent.pointerDown(cell)),
      onPointerEnter: (cell) => _bloc.add(PathWordsEvent.pointerEnter(cell)),
      onPointerUp: () => _bloc.add(const PathWordsEvent.pointerUp()),
    );
    return true;
  }

  void _selfHealGame(PathWordsState state) {
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    final current = _game;
    final isSamePuzzle = current != null && current.view.puzzle.id == puzzle.id;

    if (isSamePuzzle) {
      _ensureGame(state); // applyView even if listener missed
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ensureGame(state)) setState(() {});
    });
  }

  void _maybeShowTutorial(PathWordsState state) {
    if (_tutorialPrompted) return;
    final canPlay =
        !state.finished &&
        state.puzzle != null &&
        (state.status == PathWordsStatus.ready ||
            state.status == PathWordsStatus.playing);
    if (!canPlay) return;
    _tutorialPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PathWordsTutorial.maybeShow(context);
    });
  }

  @override
  void initState() {
    super.initState();
    final injected = widget.bloc;
    _ownsBloc = injected == null;
    _bloc =
        injected ??
        PathWordsBloc(
          generateDailyPathWords: context.read<GenerateDailyPathWords>(),
          submitScore: context.read<SubmitScore>(),
          submitLeaderboardTime: context.read<SubmitLeaderboardTime>(),
          recordDailyClear: context.read<RecordDailyClear>(),
          getBestPoints: context.read<GetBestPoints>(),
          getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
          analytics: context.read<AnalyticsRepository>(),
          playPeriod: DevFlags.playPeriod,
        );

    if (widget.autoStart) {
      _bloc.add(PathWordsEvent.started(date: widget.date));
    }
  }

  @override
  void dispose() {
    final game = _game;
    _game = null;
    game?.pauseEngine();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<PathWordsBloc, PathWordsState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.status == PathWordsStatus.navigating,
            listener: (context, state) {
              context.pushReplacement('/results', extra: state.resultsExtra);
            },
          ),
          BlocListener<PathWordsBloc, PathWordsState>(
            listenWhen: (prev, curr) => prev.puzzle?.id != curr.puzzle?.id,
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
            },
          ),
          BlocListener<PathWordsBloc, PathWordsState>(
            listenWhen: (prev, curr) {
              return prev.puzzle?.id == curr.puzzle?.id && prev != curr;
            },
            listener: (context, state) {
              final view = _viewFor(state);
              if (view == null) return;
              _applyViewToGame(view);
            },
          ),
          BlocListener<PathWordsBloc, PathWordsState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.puzzle?.id != curr.puzzle?.id,
            listener: (context, state) => _maybeShowTutorial(state),
          ),
        ],
        child: BlocBuilder<PathWordsBloc, PathWordsState>(
          builder: (context, state) {
            _selfHealGame(state);
            _maybeShowTutorial(state);
            final puzzle = state.puzzle;
            final finished = state.finished;
            final game = _game;

            final isReview = state.status == PathWordsStatus.locked;
            final isReadyToPlay =
                !finished &&
                (state.status == PathWordsStatus.ready ||
                    state.status == PathWordsStatus.playing) &&
                puzzle != null;
            final canUndo =
                isReadyToPlay &&
                (state.activePath.isNotEmpty || state.placedPaths.isNotEmpty);
            final canHint = isReadyToPlay && state.hintsRemaining > 0;

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
                                AppStrings.pathWordsTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (!isReview)
                              IconButton(
                                onPressed: !isReadyToPlay
                                    ? null
                                    : () => _bloc.add(
                                        const PathWordsEvent.reset(),
                                      ),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            const PathWordsHowToPlayButton(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final available = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final grid = puzzle?.size ?? 6;
                              final boardSide = (available * grid / 6).clamp(
                                available * 0.78,
                                available,
                              );
                              final showTip =
                                  state.ruleTip != null && isReadyToPlay;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Center(
                                    child:
                                        SizedBox(
                                              width: boardSide,
                                              height: boardSide,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                child: _BoardPane(
                                                  game: game,
                                                  status: state.status,
                                                  errorMessage:
                                                      state.errorMessage,
                                                  onRetry: () => _bloc.add(
                                                    PathWordsEvent.started(
                                                      date: widget.date,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .animate(
                                              target:
                                                  state.status ==
                                                      PathWordsStatus
                                                          .celebrating
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
                                  ),
                                  // Overlay so the tip never changes Column
                                  // height or pushes the board upward.
                                  if (showTip)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: IgnorePointer(
                                        child: GameRuleTipBanner(
                                          message: state.ruleTip!,
                                          accent: ZipColors.sky,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (puzzle != null) ...[
                              PathWordsWordList(
                                puzzle: puzzle,
                                activePath: state.activePath,
                                placedPaths: state.placedPaths,
                                completedTargetIds: state.completedTargetIds,
                                palette: PathWordsGame.pathColors,
                              ),
                            ],
                            if (!isReview) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: canUndo
                                          ? () => _bloc.add(
                                              const PathWordsEvent.undo(),
                                            )
                                          : null,
                                      icon: const Icon(Icons.undo_rounded),
                                      label: const Text(
                                        AppStrings.pathWordsUndo,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: ZipColors.wall,
                                        foregroundColor: ZipColors.onInk,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: canHint
                                          ? () => _bloc.add(
                                              const PathWordsEvent.hint(),
                                            )
                                          : null,
                                      icon: const Icon(Icons.lightbulb_rounded),
                                      label: Text(
                                        AppStrings.pathWordsHintWithCount(
                                          state.hintsRemaining,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

class _BoardPane extends StatelessWidget {
  const _BoardPane({
    required this.game,
    required this.status,
    required this.errorMessage,
    required this.onRetry,
  });

  final PathWordsGame? game;
  final PathWordsStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = game;
    if (g != null) return GameWidget(game: g);

    if (status == PathWordsStatus.failed) {
      return Container(
        color: ZipColors.wall,
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.pathWordsFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: ZipColors.wall,
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              AppStrings.pathWordsLoading,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ZipColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
