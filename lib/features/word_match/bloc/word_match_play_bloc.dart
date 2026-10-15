import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_word_match_deck_by_id.dart';
import '../../../domain/entities/word_match_deck.dart';
import '../../results/results_args.dart';
import 'word_match_play_event.dart';
import 'word_match_play_state.dart';

class WordMatchPlayBloc extends Bloc<WordMatchPlayEvent, WordMatchPlayState> {
  WordMatchPlayBloc({
    required this.fetchDeckById,
    required this.records,
    required this.analytics,
    Stream<int> Function()? ticker,
  }) : _ticker =
           ticker ??
           (() => Stream<int>.periodic(const Duration(seconds: 1), (i) => i)),
       super(const WordMatchPlayState()) {
    on<WordMatchPlayStarted>(_onStarted);
    on<WordMatchPlayTick>(_onTick);
    on<WordMatchPlayProgressChanged>(_onProgressChanged);
    on<WordMatchPlayWon>(_onWon);
  }

  final FetchWordMatchDeckById fetchDeckById;

  /// The local best time per deck. A bonus game never touches the dailies'
  /// scores, streaks, boards or sync.
  final PlayModeRecordRepository records;
  final AnalyticsRepository analytics;

  /// Where a deck's best time is kept.
  static String recordKey(String deckId) => 'bonus_word_match_$deckId';

  LocalResultInfo _local(WordMatchDeck deck, {int? best, int? matched}) =>
      LocalResultInfo(
        kind: LocalResultKind.bonus,
        label: AppStrings.bonusRunLabel(AppStrings.wordMatch, deck.title),
        bestSeconds: best,
        score: matched,
        scoreLabel: matched == null ? null : AppStrings.resultsPairsLabel,
        againLocation: '/word-match/${deck.id}',
      );
  final Stream<int> Function() _ticker;

  StreamSubscription<int>? _tickerSub;

  Future<void> _onStarted(
    WordMatchPlayStarted event,
    Emitter<WordMatchPlayState> emit,
  ) async {
    await _tickerSub?.cancel();
    _tickerSub = null;

    emit(
      state.copyWith(
        status: WordMatchPlayStatus.loading,
        deckId: event.deckId,
        deck: null,
        remainingSeconds: 0,
        matched: 0,
        total: 0,
        finished: false,
        error: null,
        resultsExtra: null,
      ),
    );

    try {
      final deck = await fetchDeckById(event.deckId);
      if (emit.isDone) return;

      if (deck == null) {
        emit(
          state.copyWith(
            status: WordMatchPlayStatus.failure,
            error: AppStrings.wordMatchDeckMissing,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: WordMatchPlayStatus.playing,
          deck: deck,
          remainingSeconds: deck.seconds,
          total: deck.pairs.length,
        ),
      );
      await analytics.logGameStarted(gameId: GameIds.wordMatch);

      _tickerSub = _ticker().listen((_) {
        add(const WordMatchPlayEvent.tick());
      });
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: WordMatchPlayStatus.failure,
          error: AppStrings.bonusLoadFailed,
        ),
      );
    }
  }

  Future<void> _onTick(
    WordMatchPlayTick event,
    Emitter<WordMatchPlayState> emit,
  ) async {
    if (state.status != WordMatchPlayStatus.playing || state.finished) return;
    if (state.remainingSeconds <= 0) return;

    final next = state.remainingSeconds - 1;
    emit(state.copyWith(remainingSeconds: next));

    if (next <= 0 && state.matched < state.total) {
      await _tickerSub?.cancel();
      _tickerSub = null;
      final points = state.matched * 25;
      final deck = state.deck!;
      final timeSeconds = deck.seconds;
      await analytics.logGameCompleted(
        gameId: GameIds.wordMatch,
        points: points,
        timeSeconds: timeSeconds,
      );
      emit(
        state.copyWith(
          status: WordMatchPlayStatus.navigating,
          finished: true,
          resultsExtra: ResultsArgs(
            title: AppStrings.wordMatchTimeUp,
            subtitle: AppStrings.wordMatchMatched(state.matched, state.total),
            timeSeconds: timeSeconds,
            improved: false,
            points: points,
            gameId: GameIds.wordMatch,
            local: _local(
              deck,
              best: records.bestTimeSeconds(recordKey(deck.id)),
              matched: state.matched,
            ),
          ),
        ),
      );
    }
  }

  void _onProgressChanged(
    WordMatchPlayProgressChanged event,
    Emitter<WordMatchPlayState> emit,
  ) {
    if (state.status != WordMatchPlayStatus.playing || state.finished) return;
    emit(state.copyWith(matched: event.matched, total: event.total));
  }

  Future<void> _onWon(
    WordMatchPlayWon event,
    Emitter<WordMatchPlayState> emit,
  ) async {
    if (state.status != WordMatchPlayStatus.playing || state.finished) return;
    final deckId = state.deckId;
    final deck = state.deck;
    if (deckId == null || deck == null) return;

    emit(
      state.copyWith(finished: true, status: WordMatchPlayStatus.submitting),
    );

    await _tickerSub?.cancel();
    _tickerSub = null;

    final best = await records.recordTime(
      recordKey(deckId),
      event.elapsedSeconds,
    );

    await analytics.logGameCompleted(
      gameId: GameIds.wordMatch,
      points: event.points,
      timeSeconds: event.elapsedSeconds,
    );

    if (emit.isDone) return;

    emit(
      state.copyWith(
        status: WordMatchPlayStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.wordMatchCleared,
          subtitle: deck.title,
          timeSeconds: event.elapsedSeconds,
          improved: best.improved,
          points: event.points,
          gameId: GameIds.wordMatch,
          local: _local(deck, best: best.best),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _tickerSub?.cancel();
    _tickerSub = null;
    return super.close();
  }
}
