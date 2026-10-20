import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/pill_tabs.dart';
import '../../../domain/entities/path_words_clear_summary.dart';
import '../../leaderboard/view/widgets/leaderboard_table.dart';
import '../../path_words/view/widgets/path_words_results_panel.dart';

/// The Board | Words tabs' height, with the gap under them.
const double resultsBoardSwitchHeight = 48;

/// The card under the tiles: the day's board and, for Path Words, tabs
/// above it to switch to the words found.
class ResultsBoardCard extends StatefulWidget {
  const ResultsBoardCard({super.key, required this.board, this.pathWords});

  /// The mini table, or the guest's tease.
  final Widget board;

  /// Path Words only: shows the tabs and the Words side.
  final PathWordsClearSummary? pathWords;

  @override
  State<ResultsBoardCard> createState() => _ResultsBoardCardState();
}

class _ResultsBoardCardState extends State<ResultsBoardCard> {
  // Which tab shows; view state only.
  var _showWords = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.pathWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (words != null) ...[
          PillTabs<bool>(
            tabs: [
              PillTab(
                key: const Key('resultsBoardTab'),
                value: false,
                icon: AppIcons.ranking,
                label: AppStrings.resultsBoardTab,
              ),
              PillTab(
                key: const Key('resultsWordsTab'),
                value: true,
                icon: AppIcons.textAa,
                label: AppStrings.resultsWordsTab(words.words.length),
              ),
            ],
            selected: _showWords,
            onChanged: (value) => setState(() => _showWords = value),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: DecoratedBox(
            decoration: leaderboardTableDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IndexedStack(
                index: _showWords && words != null ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  widget.board,
                  if (words != null) _WordsSide(summary: words),
                ],
              ),
            ),
          ),
        ),
      ],
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
