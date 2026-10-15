import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/path_words_clear_summary.dart';
import 'path_words_definition_sheet.dart';
import 'path_words_theme_line.dart';

/// Under a Path Words clear on Results: the day's theme, the words found
/// (tap one with a definition to read it) and how many bonus words.
class PathWordsResultsPanel extends StatelessWidget {
  const PathWordsResultsPanel({super.key, required this.summary});

  final PathWordsClearSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final anyDefinition = summary.words.any(
      (w) => summary.definitionFor(w) != null,
    );
    final bonusCount = summary.bonusWords.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.theme != null) ...[
          PathWordsThemeLine(theme: summary.theme),
          const SizedBox(height: 10),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final word in summary.words)
              _WordChip(word: word, definition: summary.definitionFor(word)),
          ],
        ),
        if (anyDefinition) ...[
          const SizedBox(height: 6),
          Text(
            AppStrings.pathWordsTapForMeaning,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(color: ZipColors.inkSoft),
          ),
        ],
        if (bonusCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.pathWordsBonusCount(bonusCount),
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(
              color: ZipColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.word, required this.definition});

  final String word;
  final String? definition;

  @override
  Widget build(BuildContext context) {
    final meaning = definition;
    final label = Text(
      word.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: ZipColors.onInk,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
    final shape = StadiumBorder(
      side: BorderSide(color: ZipColors.sky.withValues(alpha: 0.4)),
    );
    if (meaning == null) {
      return Chip(
        key: Key('pathWordsResultWord_$word'),
        label: label,
        backgroundColor: ZipColors.wall,
        shape: shape,
      );
    }
    return Semantics(
      label: AppStrings.pathWordsWordWithMeaningLabel(word),
      button: true,
      excludeSemantics: true,
      child: ActionChip(
        key: Key('pathWordsResultWord_$word'),
        label: label,
        avatar: const Icon(
          Icons.menu_book_rounded,
          size: 16,
          color: ZipColors.sky,
        ),
        backgroundColor: ZipColors.skySoft,
        shape: shape,
        onPressed: () =>
            showPathWordsDefinition(context, word: word, definition: meaning),
      ),
    );
  }
}
