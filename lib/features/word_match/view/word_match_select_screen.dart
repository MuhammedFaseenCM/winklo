import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/usecases/fetch_word_match_decks.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../cubit/word_match_select_cubit.dart';
import '../cubit/word_match_select_state.dart';

class WordMatchSelectScreen extends StatelessWidget {
  const WordMatchSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WordMatchSelectCubit(
        fetchWordMatchDecks: context.read<FetchWordMatchDecks>(),
        getBestPoints: context.read<GetBestPoints>(),
      )..load(),
      child: BlocBuilder<WordMatchSelectCubit, WordMatchSelectState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: ZipColors.ink,
            appBar: AppBar(
              title: const Text(
                'Word Match Decks',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: ZipColors.onInk,
            ),
            body: ZipAtmosphere(
              child: switch (state.status) {
                WordMatchSelectStatus.initial ||
                WordMatchSelectStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                WordMatchSelectStatus.failure => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.error ?? 'Unable to load decks',
                        style: const TextStyle(color: ZipColors.onInk),
                      ),
                      const SizedBox(height: 12),
                      ZipPrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        onPressed: () =>
                            context.read<WordMatchSelectCubit>().load(),
                      ),
                    ],
                  ),
                ),
                WordMatchSelectStatus.ready => _DeckList(items: state.items),
              },
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
      return const Center(
        child: Text(
          'No decks found',
          style: TextStyle(color: ZipColors.inkSoft),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = items[i];
        final deck = item.deck;
        final best = item.bestPoints;
        return Container(
          decoration: BoxDecoration(
            gradient: ZipColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZipColors.glassBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/word-match/${deck.id}'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: ZipColors.emberGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ZipColors.emberGlow.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        color: ZipColors.onInk,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: ZipColors.onInk,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _DeckBadge(
                                icon: Icons.sync_alt_rounded,
                                label: '${deck.pairs.length} pairs',
                              ),
                              _DeckBadge(
                                icon: Icons.timer_outlined,
                                label: '${deck.seconds}s',
                              ),
                              if (best > 0)
                                _DeckBadge(
                                  icon: Icons.emoji_events_rounded,
                                  label: '$best pts',
                                  isHighlight: true,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: ZipColors.ember,
                        size: 20,
                      ),
                    ),
                  ],
                ),
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
    final fg = isHighlight ? const Color(0xFFFBBF24) : ZipColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0x22FBBF24) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? const Color(0x44FBBF24)
              : const Color(0x1AFFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
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
