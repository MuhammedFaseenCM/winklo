import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/word_match_deck.dart';

part 'word_match_select_state.freezed.dart';

enum WordMatchSelectStatus { initial, loading, ready, failure }

@freezed
sealed class WordMatchSelectItem with _$WordMatchSelectItem {
  const factory WordMatchSelectItem({
    required WordMatchDeck deck,

    /// The deck's local best time; null before a clear.
    int? bestSeconds,
  }) = _WordMatchSelectItem;
}

@freezed
sealed class WordMatchSelectState with _$WordMatchSelectState {
  const factory WordMatchSelectState({
    @Default(WordMatchSelectStatus.initial) WordMatchSelectStatus status,
    @Default(<WordMatchSelectItem>[]) List<WordMatchSelectItem> items,
    String? error,
  }) = _WordMatchSelectState;
}
