import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dev_run_timer_label.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/cell.dart';
import '../../../domain/sudoku/sudoku_hint_coach.dart';
import '../../../domain/entities/sudoku_difficulty.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/usecases/generate_daily_sudoku.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/sudoku_bloc.dart';
import '../bloc/sudoku_event.dart';
import '../bloc/sudoku_state.dart';
import '../game/sudoku_board_view.dart';
import '../game/sudoku_game.dart';
import 'widgets/sudoku_how_to_play.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, this.date, this.bloc, this.autoStart = true});

  final DateTime? date;
  final SudokuBloc? bloc;
  final bool autoStart;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with WidgetsBindingObserver {
  late final SudokuBloc _bloc;
  late final bool _ownsBloc;
  SudokuGame? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.bloc;
    _ownsBloc = injected == null;
    _bloc =
        injected ??
        SudokuBloc(
          submitScore: context.read<SubmitScore>(),
          submitLeaderboardTime: context.read<SubmitLeaderboardTime>(),
          recordDailyClear: context.read<RecordDailyClear>(),
          getBestPoints: context.read<GetBestPoints>(),
          getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
          analytics: context.read<AnalyticsRepository>(),
          hintQuota: context.read<HintQuotaRepository>(),
          inProgressRuns: context.read<InProgressRunRepository>(),
          generatePuzzle: ({required day}) =>
              context.read<GenerateDailySudoku>()(day: day),
          playPeriod: DevFlags.playPeriod,
        );

    if (widget.autoStart) {
      _bloc.add(SudokuEvent.started(date: widget.date));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _bloc.add(const SudokuEvent.resumeRun());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _bloc.add(const SudokuEvent.pauseRun());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(const SudokuEvent.pauseRun());
    final game = _game;
    _game = null;
    game?.pauseEngine();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _applyViewToGame(SudokuBoardView view) {
    final game = _game;
    if (game == null) return;
    if (game.hasLayout) {
      game.applyView(view);
      return;
    }
    game.view = view;
  }

  SudokuBoardView? _viewFor(SudokuState state) {
    final puzzle = state.puzzle;
    if (puzzle == null) return null;
    final canPlay = !state.finished && state.status == SudokuStatus.ready;
    final coach = state.activeCoachHint;
    return SudokuBoardView(
      size: puzzle.size,
      boxRows: puzzle.boxRows,
      boxCols: puzzle.boxCols,
      given: puzzle.given,
      grid: state.grid,
      notes: state.notes,
      selectedIndex: state.selectedIndex,
      hintFlashIndex: state.hintFlashIndex,
      errorIndices: state.errorIndices,
      unitFlashIndices: state.unitFlashIndices,
      inputEnabled: canPlay,
      celebrate: state.status == SudokuStatus.celebrating,
      coachTargetIndex: coach?.targetIndex,
      coachEvidenceIndices: coach?.evidenceIndices ?? const {},
      coachExcludedIndices: coach?.excludedIndices ?? const {},
    );
  }

  String _coachMessage(SudokuCoachHint hint) {
    switch (hint.technique) {
      case SudokuHintTechnique.lastRemainingRegion:
        return AppStrings.sudokuHintLastRemaining(
          digit: hint.digit,
          unit: AppStrings.sudokuHintUnitRegion,
        );
      case SudokuHintTechnique.lastRemainingRow:
        return AppStrings.sudokuHintLastRemaining(
          digit: hint.digit,
          unit: AppStrings.sudokuHintUnitRow,
        );
      case SudokuHintTechnique.lastRemainingCol:
        return AppStrings.sudokuHintLastRemaining(
          digit: hint.digit,
          unit: AppStrings.sudokuHintUnitColumn,
        );
      case SudokuHintTechnique.nakedSingle:
        return AppStrings.sudokuHintNakedSingle(digit: hint.digit);
    }
  }

  bool _ensureGame(SudokuState state) {
    final view = _viewFor(state);
    if (view == null) return false;
    final puzzle = state.puzzle!;
    final current = _game;
    if (current != null) {
      _applyViewToGame(view);
      return false;
    }
    _game = SudokuGame(
      view: view,
      onCellTap: (Cell cell) {
        _bloc.add(SudokuEvent.cellSelected(cell));
      },
    );
    // Silence unused — puzzle id tracked via view updates.
    assert(puzzle.id.isNotEmpty);
    return true;
  }

  String _difficultyLabel(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return AppStrings.sudokuDifficultyEasy;
      case SudokuDifficulty.medium:
        return AppStrings.sudokuDifficultyMedium;
      case SudokuDifficulty.hard:
        return AppStrings.sudokuDifficultyHard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<SudokuBloc, SudokuState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.status == SudokuStatus.navigating,
            listener: (context, state) {
              context.pushReplacement('/results', extra: state.resultsExtra);
            },
          ),
          BlocListener<SudokuBloc, SudokuState>(
            listenWhen: (prev, curr) => prev.puzzle?.id != curr.puzzle?.id,
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
            },
          ),
          BlocListener<SudokuBloc, SudokuState>(
            listenWhen: (prev, curr) =>
                prev.puzzle?.id == curr.puzzle?.id && prev != curr,
            listener: (context, state) {
              final view = _viewFor(state);
              if (view == null) return;
              _applyViewToGame(view);
            },
          ),
        ],
        child: BlocBuilder<SudokuBloc, SudokuState>(
          builder: (context, state) {
            if (state.puzzle != null && _game == null) {
              _ensureGame(state);
            }
            final puzzle = state.puzzle;
            final isReview = state.status == SudokuStatus.locked;
            final isReadyToPlay =
                !state.finished &&
                state.status == SudokuStatus.ready &&
                puzzle != null;
            final game = _game;
            final showHintBanner =
                state.activeCoachHint != null || state.showNoSimpleHint;
            final activeCoach = state.activeCoachHint;

            return Scaffold(
              resizeToAvoidBottomInset: false,
              body: ZipAtmosphere(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            Expanded(
                              child: Text(
                                AppStrings.sudokuTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (isReadyToPlay)
                              DevRunTimerLabel(
                                elapsedMs: state.elapsedMs,
                                resumedAt: state.resumedAt,
                              ),
                            if (puzzle != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _DifficultyBadge(
                                  label: _difficultyLabel(puzzle.difficulty),
                                ),
                              ),
                            if (!isReview)
                              IconButton(
                                onPressed: !isReadyToPlay
                                    ? null
                                    : () =>
                                          _bloc.add(const SudokuEvent.reset()),
                                tooltip: AppStrings.sudokuReset,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            const SudokuHowToPlayButton(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Reserve space for notes + two pad rows so the
                            // board stays square and controls sit right under it.
                            const controlsReserve = 148.0;
                            final boardSide = (constraints.maxWidth - 24)
                                .clamp(
                                  0.0,
                                  math.max(
                                    0.0,
                                    constraints.maxHeight -
                                        (isReadyToPlay || isReview
                                            ? controlsReserve
                                            : 0),
                                  ),
                                )
                                .toDouble();

                            return Align(
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: boardSide,
                                    height: boardSide,
                                    child: game == null
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : GameWidget(game: game),
                                  ),
                                  if (isReadyToPlay) ...[
                                    _NotesToggle(
                                      enabled: state.notesMode,
                                      onPressed: () => _bloc.add(
                                        const SudokuEvent.notesModeToggled(),
                                      ),
                                    ),
                                    _NumberPad(
                                      hintsRemaining: state.hintsRemaining,
                                      onDigit: (d) =>
                                          _bloc.add(SudokuEvent.digitTapped(d)),
                                      onErase: () =>
                                          _bloc.add(const SudokuEvent.erase()),
                                      onHint: () =>
                                          _bloc.add(const SudokuEvent.hint()),
                                    ),
                                  ],
                                  if (isReview)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        8,
                                      ),
                                      child: Text(
                                        AppStrings.comeBackTomorrow,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: ZipColors.inkSoft,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (isReadyToPlay && showHintBanner)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Material(
                            color: ZipColors.success.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state.showNoSimpleHint
                                          ? AppStrings.sudokuHintNoSimple
                                          : _coachMessage(activeCoach!),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _bloc.add(
                                      const SudokuEvent.dismissHint(),
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ZipColors.skySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZipColors.sky.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ZipColors.sky,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotesToggle extends StatelessWidget {
  const _NotesToggle({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          selected: enabled,
          label: const Text(AppStrings.sudokuNotes),
          onSelected: (_) => onPressed(),
          selectedColor: ZipColors.skySoft,
          checkmarkColor: ZipColors.sky,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.hintsRemaining,
    required this.onDigit,
    required this.onErase,
    required this.onHint,
  });

  final int hintsRemaining;
  final void Function(int digit) onDigit;
  final VoidCallback onErase;
  final VoidCallback onHint;

  static const _digitStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const _actionLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const _buttonHeight = 56.0;

  static ButtonStyle get _digitButtonStyle => FilledButton.styleFrom(
    backgroundColor: ZipColors.paper,
    foregroundColor: ZipColors.onInk,
    minimumSize: const Size(0, _buttonHeight),
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  static ButtonStyle get _actionButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: ZipColors.onInk,
    minimumSize: const Size(0, _buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    side: BorderSide(color: ZipColors.outline.withValues(alpha: 0.7)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _digitButton(int digit) {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox(
          height: _buttonHeight,
          child: FilledButton(
            onPressed: () => onDigit(digit),
            style: _digitButtonStyle,
            child: Text('$digit', style: _digitStyle),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    // Slightly wider than digit cells so "Hint (n)" fits without ellipsis.
    return Expanded(
      flex: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox(
          height: _buttonHeight,
          child: OutlinedButton(
            onPressed: onPressed,
            style: _actionButtonStyle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: _actionLabelStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _digitButton(1),
              _digitButton(2),
              _digitButton(3),
              _actionButton(
                onPressed: onErase,
                icon: Icons.backspace_outlined,
                label: AppStrings.sudokuErase,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _digitButton(4),
              _digitButton(5),
              _digitButton(6),
              _actionButton(
                onPressed: hintsRemaining > 0 ? onHint : null,
                icon: Icons.lightbulb_outline,
                label: AppStrings.sudokuHintWithCount(hintsRemaining),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
