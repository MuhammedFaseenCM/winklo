import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/sfx/sfx_id.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/word_category.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_categories.dart';
import '../../results/results_args.dart';
import 'category_race_event.dart';
import 'category_race_state.dart';

class CategoryRaceBloc extends Bloc<CategoryRaceEvent, CategoryRaceState> {
  CategoryRaceBloc({
    required this.fetchCategories,
    required this.records,
    required this.analytics,
    this.sfx,
    this.haptics,
    Random? random,
    int roundSeconds = 60,
    Stream<int> Function()? ticker,
  }) : _rng = random ?? Random(),
       _roundSeconds = roundSeconds,
       _ticker =
           ticker ??
           (() => Stream<int>.periodic(const Duration(seconds: 1), (i) => i)),
       super(
         CategoryRaceState(
           totalSeconds: roundSeconds,
           remainingSeconds: roundSeconds,
         ),
       ) {
    on<CategoryRaceFetchCategories>(_onFetchCategories);
    on<CategoryRaceStarted>(_onStarted);
    on<CategoryRaceTick>(_onTick);
    on<CategoryRaceAnswerSubmitted>(_onAnswerSubmitted);
    on<CategoryRaceFinishRequested>(_onFinishRequested);
  }

  final FetchCategories fetchCategories;

  /// The local best word count per category. A bonus game never touches
  /// the dailies' scores, streaks, boards or sync.
  final PlayModeRecordRepository records;
  final AnalyticsRepository analytics;
  final SfxService? sfx;
  final HapticsService? haptics;

  /// Where a category's best count is kept.
  static String recordKey(String categoryId) =>
      'bonus_category_race_$categoryId';
  final Random _rng;
  final int _roundSeconds;
  final Stream<int> Function() _ticker;

  StreamSubscription<int>? _tickerSub;

  Future<void> _onFetchCategories(
    CategoryRaceFetchCategories event,
    Emitter<CategoryRaceState> emit,
  ) async {
    await _tickerSub?.cancel();
    _tickerSub = null;

    emit(
      state.copyWith(
        status: CategoryRaceStatus.loading,
        category: null,
        letter: 'A',
        totalSeconds: _roundSeconds,
        remainingSeconds: _roundSeconds,
        answers: const [],
        feedback: null,
        error: null,
        improved: null,
        resultsExtra: null,
        finished: false,
      ),
    );

    try {
      final categories = await fetchCategories();
      if (emit.isDone) return;

      if (categories.isEmpty) {
        emit(state.copyWith(status: CategoryRaceStatus.ready));
        return;
      }

      final category = categories[_rng.nextInt(categories.length)];
      final letter = _pickLetter(category);

      emit(
        state.copyWith(
          status: CategoryRaceStatus.ready,
          category: category,
          letter: letter,
        ),
      );
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: CategoryRaceStatus.failure,
          error: AppStrings.bonusLoadFailed,
        ),
      );
    }
  }

  Future<void> _onStarted(
    CategoryRaceStarted event,
    Emitter<CategoryRaceState> emit,
  ) async {
    final category = state.category;
    if (category == null || state.finished) return;

    await _tickerSub?.cancel();
    _tickerSub = null;
    emit(
      state.copyWith(
        status: CategoryRaceStatus.playing,
        totalSeconds: _roundSeconds,
        remainingSeconds: _roundSeconds,
        answers: const [],
        feedback: null,
        error: null,
        improved: null,
        resultsExtra: null,
        finished: false,
      ),
    );
    await analytics.logGameStarted(gameId: GameIds.categoryRace);

    _tickerSub = _ticker().listen((_) {
      add(const CategoryRaceEvent.tick());
    });
  }

  Future<void> _onTick(
    CategoryRaceTick event,
    Emitter<CategoryRaceState> emit,
  ) async {
    if (state.status != CategoryRaceStatus.playing || state.finished) return;
    if (state.remainingSeconds <= 0) return;

    final next = state.remainingSeconds - 1;
    emit(state.copyWith(remainingSeconds: next));

    if (next <= 0) {
      await _onFinishRequested(const CategoryRaceFinishRequested(), emit);
    }
  }

  void _onAnswerSubmitted(
    CategoryRaceAnswerSubmitted event,
    Emitter<CategoryRaceState> emit,
  ) {
    if (state.status != CategoryRaceStatus.playing || state.finished) return;
    final category = state.category;
    if (category == null) return;

    final raw = event.raw.trim();
    if (raw.isEmpty) return;

    final word = raw.toLowerCase();
    final letterLower = state.letter.toLowerCase();

    String? rejection;
    if (!word.startsWith(letterLower)) {
      rejection = AppStrings.categoryRaceMustStart(state.letter);
    } else if (!category.normalizedWords.contains(word)) {
      rejection = AppStrings.categoryRaceNotIn(category.name);
    } else if (state.answers.contains(word)) {
      rejection = AppStrings.categoryRaceAlreadyUsed;
    }
    if (rejection != null) {
      emit(state.copyWith(feedback: rejection));
      unawaited(sfx?.play(SfxId.reject) ?? Future<void>.value());
      haptics?.play(HapticKind.light);
      return;
    }

    emit(state.copyWith(answers: [word, ...state.answers], feedback: null));
    unawaited(sfx?.play(SfxId.success) ?? Future<void>.value());
    haptics?.play(HapticKind.success);
  }

  Future<void> _onFinishRequested(
    CategoryRaceFinishRequested event,
    Emitter<CategoryRaceState> emit,
  ) async {
    if (state.status != CategoryRaceStatus.playing || state.finished) return;
    final category = state.category;
    if (category == null) return;

    emit(state.copyWith(finished: true, status: CategoryRaceStatus.submitting));

    await _tickerSub?.cancel();
    _tickerSub = null;

    final points = state.answers.length * 50;
    unawaited(sfx?.play(SfxId.clear) ?? Future<void>.value());
    haptics?.play(HapticKind.win);
    final best = await records.recordScore(
      recordKey(category.id),
      state.answers.length,
    );

    await analytics.logGameCompleted(
      gameId: GameIds.categoryRace,
      points: points,
      timeSeconds: state.totalSeconds,
    );

    if (emit.isDone) return;

    emit(
      state.copyWith(
        status: CategoryRaceStatus.navigating,
        improved: best.improved,
        resultsExtra: ResultsArgs(
          title: AppStrings.categoryRaceRoundOver,
          subtitle: '${category.name} · ${state.letter}',
          timeSeconds: state.totalSeconds,
          improved: best.improved,
          points: points,
          gameId: GameIds.categoryRace,
          local: LocalResultInfo(
            kind: LocalResultKind.bonus,
            label: AppStrings.bonusRunLabel(
              AppStrings.categoryRace,
              '${category.name} · ${state.letter}',
            ),
            score: state.answers.length,
            bestScore: best.best,
            againLocation: '/category-race',
          ),
        ),
      ),
    );
  }

  String _pickLetter(WordCategory category) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final viable = <String>[];
    final words = category.normalizedWords;
    for (var i = 0; i < letters.length; i++) {
      final l = letters[i];
      final lower = l.toLowerCase();
      if (words.any((w) => w.startsWith(lower))) viable.add(l);
    }
    if (viable.isEmpty) return 'A';
    return viable[_rng.nextInt(viable.length)];
  }

  @override
  Future<void> close() async {
    await _tickerSub?.cancel();
    _tickerSub = null;
    return super.close();
  }
}
