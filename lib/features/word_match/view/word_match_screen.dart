import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/word_match_deck.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/fetch_word_match_deck_by_id.dart';
import '../../../domain/usecases/submit_score.dart';
import '../bloc/word_match_play_bloc.dart';
import '../bloc/word_match_play_event.dart';
import '../bloc/word_match_play_state.dart';
import '../game/word_match_game.dart';

class WordMatchScreen extends StatefulWidget {
  const WordMatchScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<WordMatchScreen> createState() => _WordMatchScreenState();
}

class _WordMatchScreenState extends State<WordMatchScreen> {
  late final WordMatchPlayBloc _bloc;
  WordMatchGame? _game;

  WordMatchDeck? _deck;
  int _matched = 0;
  int _total = 0;

  bool _ensureGame(WordMatchPlayState state) {
    final deck = state.deck;
    if (deck == null) return false;

    final current = _game;
    if (current != null && _deck?.id == deck.id) return false;

    _deck = deck;
    _matched = state.matched;
    _total = state.total;
    _game = WordMatchGame(
      deck: deck,
      onWin: (points, elapsedSeconds) {
        _bloc.add(
          WordMatchPlayEvent.won(
            points: points,
            elapsedSeconds: elapsedSeconds,
          ),
        );
      },
      onProgress: (m, t) {
        if (!mounted) return;
        setState(() {
          _matched = m;
          _total = t;
        });
        _bloc.add(WordMatchPlayEvent.progressChanged(matched: m, total: t));
      },
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    _bloc = WordMatchPlayBloc(
      fetchDeckById: context.read<FetchWordMatchDeckById>(),
      submitScore: context.read<SubmitScore>(),
      analytics: context.read<AnalyticsRepository>(),
    )..add(WordMatchPlayEvent.started(deckId: widget.deckId));
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
          BlocListener<WordMatchPlayBloc, WordMatchPlayState>(
            listenWhen: (p, c) =>
                p.status != c.status &&
                c.status == WordMatchPlayStatus.navigating,
            listener: (context, state) {
              context.pushReplacement('/results', extra: state.resultsExtra);
            },
          ),
          BlocListener<WordMatchPlayBloc, WordMatchPlayState>(
            listenWhen: (p, c) => p.deck?.id != c.deck?.id,
            listener: (context, state) {
              if (_ensureGame(state)) setState(() {});
            },
          ),
        ],
        child: BlocBuilder<WordMatchPlayBloc, WordMatchPlayState>(
          builder: (context, state) {
            if (state.status == WordMatchPlayStatus.initial ||
                state.status == WordMatchPlayStatus.loading) {
              return const Scaffold(
                backgroundColor: ZipColors.ink,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (state.status == WordMatchPlayStatus.failure || _game == null) {
              return Scaffold(
                backgroundColor: ZipColors.ink,
                appBar: AppBar(
                  title: const Text('Word Match'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  foregroundColor: ZipColors.onInk,
                ),
                body: Center(
                  child: Text(
                    state.error ?? 'Unable to load deck',
                    style: const TextStyle(color: ZipColors.onInk),
                  ),
                ),
              );
            }

            final remaining = state.remainingSeconds;
            final deck = _deck!;

            return Scaffold(
              backgroundColor: ZipColors.ink,
              appBar: AppBar(
                title: Text(
                  deck.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: ZipColors.onInk,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: remaining <= 10
                              ? const Color(0x33EF4444)
                              : const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: remaining <= 10
                                ? const Color(0x88EF4444)
                                : const Color(0x1AFFFFFF),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: remaining <= 10
                                  ? const Color(0xFFEF4444)
                                  : ZipColors.ember,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${remaining}s',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: remaining <= 10
                                    ? const Color(0xFFEF4444)
                                    : ZipColors.onInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ZipColors.ember.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ZipColors.ember.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$_matched / $_total',
                            style: const TextStyle(
                              color: ZipColors.ember,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Drag word to its matching pair',
                            style: TextStyle(
                              color: ZipColors.inkSoft,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: GameWidget(game: _game!)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
