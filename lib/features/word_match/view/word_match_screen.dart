import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/sfx/sfx_id.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bonus_game_chrome.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/word_match_deck.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_word_match_deck_by_id.dart';
import '../bloc/word_match_play_bloc.dart';
import '../bloc/word_match_play_event.dart';
import '../bloc/word_match_play_state.dart';
import '../game/word_match_game.dart';

/// A Word Match round: drag each word onto its pair before the clock runs
/// out. A bonus game: its best time stays on the device.
class WordMatchScreen extends StatefulWidget {
  const WordMatchScreen({super.key, required this.deckId});

  final String deckId;

  @override
  State<WordMatchScreen> createState() => _WordMatchScreenState();
}

class _WordMatchScreenState extends State<WordMatchScreen> {
  late final WordMatchPlayBloc _bloc;
  late final SfxService? _sfx;
  late final HapticsService? _haptics;
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
        unawaited(_sfx?.play(SfxId.clear));
        _haptics?.play(HapticKind.win);
        _bloc.add(
          WordMatchPlayEvent.won(
            points: points,
            elapsedSeconds: elapsedSeconds,
          ),
        );
      },
      onMatch: () {
        unawaited(_sfx?.play(SfxId.success));
        _haptics?.play(HapticKind.success);
      },
      onMiss: () {
        unawaited(_sfx?.play(SfxId.reject));
        _haptics?.play(HapticKind.light);
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
    _sfx = context.read<SfxService?>();
    _haptics = context.read<HapticsService?>();
    _bloc = WordMatchPlayBloc(
      fetchDeckById: context.read<FetchWordMatchDeckById>(),
      records: context.read<PlayModeRecordRepository>(),
      analytics: context.read<AnalyticsRepository>(),
    );
    // The rules come first on a player's first round; the clock starts
    // after they close.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await BonusHowToPlay.maybeShow(
        context,
        gameId: GameIds.wordMatch,
        title: AppStrings.zipHowToPlayTitle,
        body: AppStrings.wordMatchHowToBody,
      );
      if (!mounted || _bloc.isClosed) return;
      _bloc.add(WordMatchPlayEvent.started(deckId: widget.deckId));
    });
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
            final playing =
                state.status != WordMatchPlayStatus.initial &&
                state.status != WordMatchPlayStatus.loading &&
                state.status != WordMatchPlayStatus.failure &&
                _game != null;
            return Scaffold(
              body: ZipAtmosphere(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BonusGameHeader(
                        title: _deck?.title ?? AppStrings.wordMatch,
                        gameId: GameIds.wordMatch,
                        howToPlayBody: AppStrings.wordMatchHowToBody,
                        secondsLeft: playing ? state.remainingSeconds : null,
                      ),
                      if (state.status == WordMatchPlayStatus.failure)
                        Expanded(
                          child: BonusGameMessage(
                            message: state.error ?? AppStrings.bonusLoadFailed,
                            onRetry: () => _bloc.add(
                              WordMatchPlayEvent.started(deckId: widget.deckId),
                            ),
                          ),
                        )
                      else if (!playing)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _ProgressBar(matched: _matched, total: _total),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: GameWidget(game: _game!),
                            ),
                          ),
                        ),
                      ],
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.matched, required this.total});

  final int matched;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ZipColors.ember.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZipColors.ember.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$matched / $total',
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
              AppStrings.wordMatchInstruction,
              style: TextStyle(
                color: ZipColors.inkSoft,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
