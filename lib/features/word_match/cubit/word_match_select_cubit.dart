import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_word_match_decks.dart';
import '../bloc/word_match_play_bloc.dart';
import 'word_match_select_state.dart';

class WordMatchSelectCubit extends Cubit<WordMatchSelectState> {
  WordMatchSelectCubit({
    required this.fetchWordMatchDecks,
    required this.records,
  }) : super(const WordMatchSelectState());

  final FetchWordMatchDecks fetchWordMatchDecks;

  /// Local best times per deck.
  final PlayModeRecordRepository records;

  Future<void> load() async {
    if (state.status == WordMatchSelectStatus.loading) return;
    emit(state.copyWith(status: WordMatchSelectStatus.loading, error: null));

    try {
      final decks = await fetchWordMatchDecks();
      final items = decks
          .map(
            (d) => WordMatchSelectItem(
              deck: d,
              bestSeconds: records.bestTimeSeconds(
                WordMatchPlayBloc.recordKey(d.id),
              ),
            ),
          )
          .toList(growable: false);

      emit(state.copyWith(status: WordMatchSelectStatus.ready, items: items));
    } catch (_) {
      emit(
        state.copyWith(
          status: WordMatchSelectStatus.failure,
          error: AppStrings.bonusLoadFailed,
        ),
      );
    }
  }
}
