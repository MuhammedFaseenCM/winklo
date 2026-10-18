import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/domain/entities/word_match_deck.dart';
import 'package:winklo/domain/entities/word_pair.dart';
import 'package:winklo/domain/usecases/fetch_word_match_decks.dart';
import 'package:winklo/domain/repositories/play_mode_record_repository.dart';
import 'package:winklo/features/word_match/cubit/word_match_select_cubit.dart';
import 'package:winklo/features/word_match/cubit/word_match_select_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchWordMatchDecks extends Mock implements FetchWordMatchDecks {}

class _MockRecords extends Mock implements PlayModeRecordRepository {}

void main() {
  late _MockFetchWordMatchDecks fetchDecks;
  late _MockRecords records;

  setUp(() {
    fetchDecks = _MockFetchWordMatchDecks();
    records = _MockRecords();
    when(() => records.changes).thenAnswer((_) => const Stream.empty());
  });

  blocTest<WordMatchSelectCubit, WordMatchSelectState>(
    'load() emits ready items with the local best times',
    build: () {
      when(() => fetchDecks()).thenAnswer(
        (_) async => [
          WordMatchDeck(
            id: 'animals',
            title: 'Animals',
            seconds: 30,
            pairs: const [WordPair(a: 'cat', b: 'meow')],
          ),
          WordMatchDeck(
            id: 'opposites',
            title: 'Opposites',
            seconds: 40,
            pairs: const [WordPair(a: 'hot', b: 'cold')],
          ),
        ],
      );
      when(() => records.bestTimeSeconds(any())).thenReturn(null);
      when(
        () => records.bestTimeSeconds('bonus_word_match_opposites'),
      ).thenReturn(42);

      return WordMatchSelectCubit(
        fetchWordMatchDecks: fetchDecks,
        records: records,
      );
    },
    act: (c) => c.load(),
    expect: () => [
      isA<WordMatchSelectState>().having(
        (s) => s.status,
        'status',
        WordMatchSelectStatus.loading,
      ),
      isA<WordMatchSelectState>()
          .having((s) => s.status, 'status', WordMatchSelectStatus.ready)
          .having((s) => s.items.length, 'items.length', 2)
          .having((s) => s.items[0].bestSeconds, 'items[0].best', isNull)
          .having((s) => s.items[1].bestSeconds, 'items[1].best', 42),
    ],
    verify: (_) {
      verify(() => fetchDecks()).called(1);
      verify(
        () => records.bestTimeSeconds('bonus_word_match_animals'),
      ).called(1);
      verify(
        () => records.bestTimeSeconds('bonus_word_match_opposites'),
      ).called(1);
    },
  );

  blocTest<WordMatchSelectCubit, WordMatchSelectState>(
    'load() emits failure on exception',
    build: () {
      when(() => fetchDecks()).thenThrow(Exception('boom'));
      return WordMatchSelectCubit(
        fetchWordMatchDecks: fetchDecks,
        records: records,
      );
    },
    act: (c) => c.load(),
    expect: () => [
      isA<WordMatchSelectState>().having(
        (s) => s.status,
        'status',
        WordMatchSelectStatus.loading,
      ),
      isA<WordMatchSelectState>()
          .having((s) => s.status, 'status', WordMatchSelectStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  test('refreshes the bests when a run stores one', () async {
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    when(() => records.changes).thenAnswer((_) => changes.stream);
    when(() => fetchDecks()).thenAnswer(
      (_) async => [
        WordMatchDeck(
          id: 'animals',
          title: 'Animals',
          pairs: const [WordPair(a: 'cat', b: 'meow')],
        ),
      ],
    );
    when(() => records.bestTimeSeconds(any())).thenReturn(null);
    final cubit = WordMatchSelectCubit(
      fetchWordMatchDecks: fetchDecks,
      records: records,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.items.single.bestSeconds, isNull);

    when(
      () => records.bestTimeSeconds('bonus_word_match_animals'),
    ).thenReturn(31);
    changes.add(null);
    await pumpEventQueue();
    expect(cubit.state.items.single.bestSeconds, 31);
    verify(() => fetchDecks()).called(1);
  });
}
