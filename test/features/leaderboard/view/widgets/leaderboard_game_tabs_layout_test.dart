import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_game_tabs.dart';

import '../../../../helpers/screenshot.dart';

/// With the app's theme and real fonts, so the tabs measure as on a phone.
void main() {
  setUpAll(loadScreenshotFonts);

  for (final width in [360.0, 411.0]) {
    for (final selected in [GameIds.zip, GameIds.pathWords]) {
      testWidgets(
        'at ${width.toInt()} px the Path Words tab reads in full ($selected picked)',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(
                body: Padding(
                  // The board screen's side padding.
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LeaderboardGameTabs(
                    gameId: selected,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final text = find.text(AppStrings.pathWordsTitle);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse);
        },
      );
    }
  }
}
