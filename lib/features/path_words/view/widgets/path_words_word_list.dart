import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/cell.dart';
import '../../../../domain/entities/path_words_puzzle.dart';
import '../../../../domain/path_words/path_words_rules.dart';

class PathWordsWordList extends StatelessWidget {
  const PathWordsWordList({
    super.key,
    required this.puzzle,
    required this.activePath,
    required this.placedPaths,
    required this.completedTargetIds,
    required this.palette,
  });

  final PathWordsPuzzle puzzle;
  final List<Cell> activePath;
  final List<PathWordsStroke> placedPaths;
  final Set<String> completedTargetIds;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final fills = PathWordsRules.listFills(
      puzzle: puzzle,
      activePath: activePath,
      placedPaths: placedPaths,
      completedTargetIds: completedTargetIds,
    );
    final orderedTargets = PathWordsRules.orderedTargets(puzzle);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ZipColors.outlineQuiet),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < orderedTargets.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _WordRow(
              target: orderedTargets[i],
              color: _rowColor(
                target: orderedTargets[i],
                fill: fills[orderedTargets[i].id],
              ),
              done: completedTargetIds.contains(orderedTargets[i].id),
              fill: fills[orderedTargets[i].id],
            ),
          ],
        ],
      ),
    );
  }

  Color _rowColor({
    required PathWordsTarget target,
    required PathWordsListFill? fill,
  }) {
    final index = fill?.colorIndex ?? target.colorIndex;
    return palette[index % palette.length];
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.target,
    required this.color,
    required this.done,
    required this.fill,
  });

  final PathWordsTarget target;
  final Color color;
  final bool done;
  final PathWordsListFill? fill;

  @override
  Widget build(BuildContext context) {
    final word = target.word.toUpperCase();
    final filledLetters = done
        ? [for (var i = 0; i < word.length; i++) word[i]]
        : fill?.letters ?? const <String>[];
    final overflowCount = done ? 0 : (fill?.overflowCount ?? 0);
    final semanticsLabel = done
        ? word
        : filledLetters.isEmpty
        ? AppStrings.pathWordsUnfoundWordLabel(target.word.length)
        : AppStrings.pathWordsTracingWordLabel(filledLetters.join());

    return Semantics(
      key: Key('pathWordsWord_${target.id}'),
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < target.word.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            _LetterCell(
              letter: i < filledLetters.length ? filledLetters[i] : null,
              color: color,
              done: done,
            ),
          ],
          for (var i = 0; i < overflowCount; i++) ...[
            const SizedBox(width: 3),
            _LetterCell(
              key: Key('pathWordsOverflow_${target.id}_$i'),
              letter: filledLetters[target.word.length + i],
              color: color,
              done: false,
              overflow: true,
            ),
          ],
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 18,
            child: done
                ? Icon(
                    key: Key('pathWordsCheck_${target.id}'),
                    Icons.check_circle_rounded,
                    size: 18,
                    color: ZipColors.success,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _LetterCell extends StatelessWidget {
  const _LetterCell({
    super.key,
    required this.letter,
    required this.color,
    required this.done,
    this.overflow = false,
  });

  final String? letter;
  final Color color;
  final bool done;
  final bool overflow;

  @override
  Widget build(BuildContext context) {
    final shownLetter = letter;
    final borderColor = overflow
        ? const Color(0xFFF87171).withValues(alpha: 0.85)
        : done
        ? ZipColors.success.withValues(alpha: 0.55)
        : shownLetter != null
        ? color.withValues(alpha: 0.7)
        : ZipColors.outlineQuiet;
    final fillColor = overflow
        ? const Color(0xFFF87171).withValues(alpha: 0.18)
        : done
        ? ZipColors.success.withValues(alpha: 0.14)
        : shownLetter != null
        ? color.withValues(alpha: 0.22)
        : ZipColors.paper.withValues(alpha: 0.55);

    return Container(
      width: 22,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: shownLetter == null
          ? null
          : Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  shownLetter,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
                if (overflow)
                  CustomPaint(
                    size: const Size(18, 22),
                    painter: _CrossLinePainter(
                      color: const Color(0xFFF87171).withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CrossLinePainter extends CustomPainter {
  const _CrossLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
