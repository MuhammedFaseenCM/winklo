import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/bonus_game_chrome.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/fetch_word_match_decks.dart';
import '../cubit/word_match_select_cubit.dart';
import '../cubit/word_match_select_state.dart';

/// Word Match decks from the CMS, each with its local best time.
class WordMatchSelectScreen extends StatelessWidget {
  const WordMatchSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WordMatchSelectCubit(
        fetchWordMatchDecks: context.read<FetchWordMatchDecks>(),
        records: context.read<PlayModeRecordRepository>(),
      )..load(),
      child: BlocBuilder<WordMatchSelectCubit, WordMatchSelectState>(
        builder: (context, state) {
          return Scaffold(
            body: ZipAtmosphere(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BonusGameHeader(
                      title: AppStrings.wordMatch,
                      gameId: GameIds.wordMatch,
                      howToPlayBody: AppStrings.wordMatchHowToBody,
                    ),
                    Expanded(
                      child: switch (state.status) {
                        WordMatchSelectStatus.initial ||
                        WordMatchSelectStatus.loading => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        WordMatchSelectStatus.failure => BonusGameMessage(
                          message: AppStrings.bonusLoadFailed,
                          onRetry: () =>
                              context.read<WordMatchSelectCubit>().load(),
                        ),
                        WordMatchSelectStatus.ready => _DeckList(
                          items: state.items,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeckList extends StatelessWidget {
  const _DeckList({required this.items});

  final List<WordMatchSelectItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return BonusGameMessage(message: AppStrings.wordMatchNoDecks);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = items[i];
        final deck = item.deck;
        final best = item.bestSeconds;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/word-match/${deck.id}'),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: ZipColors.cardGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ZipColors.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: ZipColors.emberGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppIcon(
                      AppIcons.cards,
                      color: ZipColors.onInk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _DeckBadge(
                              icon: AppIcons.swap,
                              label: AppStrings.wordMatchPairs(
                                deck.pairs.length,
                              ),
                            ),
                            _DeckBadge(
                              icon: AppIcons.timer,
                              label: AppStrings.bonusSecondsLeft(deck.seconds),
                            ),
                            if (best != null)
                              _DeckBadge(
                                icon: AppIcons.trophy,
                                label: AppStrings.localBest(
                                  AppStrings.formatPlayTime(best),
                                ),
                                isHighlight: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const AppIcon(AppIcons.play, color: ZipColors.ember),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeckBadge extends StatelessWidget {
  const _DeckBadge({
    required this.icon,
    required this.label,
    this.isHighlight = false,
  });

  final IconData icon;
  final String label;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final fg = isHighlight ? ZipColors.success : ZipColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight ? ZipColors.successSoft : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? ZipColors.success.withValues(alpha: 0.4)
              : const Color(0x1AFFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
