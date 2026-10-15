import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/domain/entities/word_match_deck.dart';
import 'package:winklo/domain/entities/word_pair.dart';
import 'package:winklo/domain/usecases/fetch_word_match_deck_by_id.dart';
import 'package:winklo/domain/repositories/play_mode_record_repository.dart';
import 'package:winklo/features/word_match/bloc/word_match_play_bloc.dart';
import 'package:winklo/features/word_match/bloc/word_match_play_event.dart';
import 'package:winklo/features/word_match/bloc/word_match_play_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockFetchWordMatchDeckById extends Mock
    implements FetchWordMatchDeckById {}

class _MockRecords extends Mock implements PlayModeRecordRepository {}

void main() {
  late _MockFetchWordMatchDeckById fetchDeckById;
  late _MockRecords records;
  late StreamController<int> ticks;

  late MockAnalyticsRepository analytics;

  setUp(() {
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    fetchDeckById = _MockFetchWordMatchDeckById();
    records = _MockRecords();
    when(() => records.bestTimeSeconds(any())).thenReturn(null);
    ticks = StreamController<int>.broadcast();
  });

  tearDown(() async {
    await ticks.close();
  });

  WordMatchDeck _deck({required int seconds}) => WordMatchDeck(
    id: 'animals',
    title: 'Animals',
    seconds: seconds,
    pairs: const [
      WordPair(a: 'cat', b: 'meow'),
      WordPair(a: 'cow', b: 'moo'),
    ],
  );

  blocTest<WordMatchPlayBloc, WordMatchPlayState>(
    'started loads deck and begins playing',
    build: () {
      when(
        () => fetchDeckById(any()),
      ).thenAnswer((_) async => _deck(seconds: 3));
      return WordMatchPlayBloc(
        fetchDeckById: fetchDeckById,
        records: records,
        analytics: analytics,
        ticker: () => ticks.stream,
      );
    },
    act: (b) => b.add(const WordMatchPlayEvent.started(deckId: 'animals')),
    expect: () => [
      isA<WordMatchPlayState>()
          .having((s) => s.status, 'status', WordMatchPlayStatus.loading)
          .having((s) => s.deckId, 'deckId', 'animals'),
      isA<WordMatchPlayState>()
          .having((s) => s.status, 'status', WordMatchPlayStatus.playing)
          .having((s) => s.remainingSeconds, 'remainingSeconds', 3)
          .having((s) => s.total, 'total', 2)
          .having((s) => s.deck?.title, 'deck.title', 'Animals'),
    ],
    verify: (_) {
      verify(() => fetchDeckById('animals')).called(1);
    },
  );

  blocTest<WordMatchPlayBloc, WordMatchPlayState>(
    'ticks down and navigates on timeout without submit',
    build: () {
      when(
        () => fetchDeckById(any()),
      ).thenAnswer((_) async => _deck(seconds: 2));
      return WordMatchPlayBloc(
        fetchDeckById: fetchDeckById,
        records: records,
        analytics: analytics,
        ticker: () => ticks.stream,
      );
    },
    act: (b) async {
      b.add(const WordMatchPlayEvent.started(deckId: 'animals'));
      await pumpEventQueue();
      b.add(const WordMatchPlayEvent.progressChanged(matched: 1, total: 2));
      await pumpEventQueue();
      ticks.add(0);
      ticks.add(1);
      await pumpEventQueue();
    },
    expect: () => [
      isA<WordMatchPlayState>().having(
        (s) => s.status,
        'status',
        WordMatchPlayStatus.loading,
      ),
      isA<WordMatchPlayState>()
          .having((s) => s.status, 'status', WordMatchPlayStatus.playing)
          .having((s) => s.remainingSeconds, 'remainingSeconds', 2),
      isA<WordMatchPlayState>()
          .having((s) => s.matched, 'matched', 1)
          .having((s) => s.total, 'total', 2),
      isA<WordMatchPlayState>().having(
        (s) => s.remainingSeconds,
        'remainingSeconds',
        1,
      ),
      isA<WordMatchPlayState>().having(
        (s) => s.remainingSeconds,
        'remainingSeconds',
        0,
      ),
      isA<WordMatchPlayState>()
          .having((s) => s.status, 'status', WordMatchPlayStatus.navigating)
          .having((s) => s.resultsExtra?.title, 'title', 'Time up')
          .having((s) => s.resultsExtra?.points, 'points', 25)
          .having((s) => s.resultsExtra?.improved, 'improved', false),
    ],
    verify: (_) {
      verifyNever(() => records.recordTime(any(), any()));
    },
  );

  blocTest<WordMatchPlayBloc, WordMatchPlayState>(
    'won keeps the local best time then navigates',
    build: () {
      when(
        () => fetchDeckById(any()),
      ).thenAnswer((_) async => _deck(seconds: 10));
      when(() => records.recordTime('bonus_word_match_animals', 7)).thenAnswer(
        (_) async => const LocalBest(best: 7, previous: 9, improved: true),
      );

      return WordMatchPlayBloc(
        fetchDeckById: fetchDeckById,
        records: records,
        analytics: analytics,
        ticker: () => ticks.stream,
      );
    },
    act: (b) async {
      b.add(const WordMatchPlayEvent.started(deckId: 'animals'));
      await pumpEventQueue();
      b.add(const WordMatchPlayEvent.won(points: 500, elapsedSeconds: 7));
    },
    expect: () => [
      isA<WordMatchPlayState>().having(
        (s) => s.status,
        'status',
        WordMatchPlayStatus.loading,
      ),
      isA<WordMatchPlayState>().having(
        (s) => s.status,
        'status',
        WordMatchPlayStatus.playing,
      ),
      isA<WordMatchPlayState>().having(
        (s) => s.status,
        'status',
        WordMatchPlayStatus.submitting,
      ),
      isA<WordMatchPlayState>()
          .having((s) => s.status, 'status', WordMatchPlayStatus.navigating)
          .having((s) => s.resultsExtra?.title, 'title', 'All matched!')
          .having((s) => s.resultsExtra?.improved, 'improved', isTrue)
          .having((s) => s.resultsExtra?.local?.bestSeconds, 'best', 7)
          .having(
            (s) => s.resultsExtra?.local?.againLocation,
            'again',
            '/word-match/animals',
          ),
    ],
    verify: (_) {
      verify(() => records.recordTime('bonus_word_match_animals', 7)).called(1);
    },
  );

  test('close() cancels ticker subscription', () async {
    when(() => fetchDeckById(any())).thenAnswer((_) async => _deck(seconds: 3));
    final bloc = WordMatchPlayBloc(
      fetchDeckById: fetchDeckById,
      records: records,
      analytics: analytics,
      ticker: () => ticks.stream,
    );

    bloc.add(const WordMatchPlayEvent.started(deckId: 'animals'));
    await pumpEventQueue();
    expect(ticks.hasListener, isTrue);

    await bloc.close();
    expect(ticks.hasListener, isFalse);
  });
}
