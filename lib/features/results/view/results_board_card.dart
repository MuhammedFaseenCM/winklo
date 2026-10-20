import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../domain/entities/path_words_clear_summary.dart';
import '../../leaderboard/view/widgets/leaderboard_table.dart';
import '../../path_words/view/widgets/path_words_results_panel.dart';

/// The Board | Words switch's height, margins included.
const double resultsBoardSwitchHeight = 46;

/// The card under the tiles: the day's board and, for Path Words, a switch
/// to the words found.
class ResultsBoardCard extends StatefulWidget {
  const ResultsBoardCard({super.key, required this.board, this.pathWords});

  /// The mini table, or the guest's tease.
  final Widget board;

  /// Path Words only: shows the switch and the Words side.
  final PathWordsClearSummary? pathWords;

  @override
  State<ResultsBoardCard> createState() => _ResultsBoardCardState();
}

class _ResultsBoardCardState extends State<ResultsBoardCard> {
  // Which side of the switch shows; view state only.
  var _showWords = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.pathWords;
    return DecoratedBox(
      decoration: leaderboardTableDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (words != null)
              _BoardWordsSwitch(
                showWords: _showWords,
                wordCount: words.words.length,
                onChanged: (value) => setState(() => _showWords = value),
              ),
            Expanded(
              child: IndexedStack(
                index: _showWords && words != null ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  widget.board,
                  if (words != null) _WordsSide(summary: words),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardWordsSwitch extends StatelessWidget {
  const _BoardWordsSwitch({
    required this.showWords,
    required this.wordCount,
    required this.onChanged,
  });

  final bool showWords;
  final int wordCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: resultsBoardSwitchHeight - 12,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZipColors.ink.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              key: const Key('resultsBoardTab'),
              icon: AppIcons.ranking,
              label: AppStrings.resultsBoardTab,
              selected: !showWords,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              key: const Key('resultsWordsTab'),
              icon: AppIcons.textAa,
              label: AppStrings.resultsWordsTab(wordCount),
              selected: showWords,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipColors.onInk : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? ZipColors.mistDeep : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The theme, the words and the bonus count, centred in the card.
class _WordsSide extends StatelessWidget {
  const _WordsSide({required this.summary});

  final PathWordsClearSummary summary;

  static const _padding = EdgeInsets.fromLTRB(14, 8, 14, 14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: _padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - _padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(child: PathWordsResultsPanel(summary: summary)),
        ),
      ),
    );
  }
}
