import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Opens a sheet with a found word and its one-line definition.
Future<void> showPathWordsDefinition(
  BuildContext context, {
  required String word,
  required String definition,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: ZipColors.wall,
    builder: (context) =>
        PathWordsDefinitionSheet(word: word, definition: definition),
  );
}

class PathWordsDefinitionSheet extends StatelessWidget {
  const PathWordsDefinitionSheet({
    super.key,
    required this.word,
    required this.definition,
  });

  final String word;
  final String definition;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word.toUpperCase(),
              style: textTheme.headlineSmall?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              definition,
              style: textTheme.bodyLarge?.copyWith(
                color: ZipColors.inkSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
