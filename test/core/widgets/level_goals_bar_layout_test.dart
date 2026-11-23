import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/level_goals.dart';

import '../../helpers/screenshot.dart';

/// With the app's theme and real fonts, so the goals measure as on a phone.
void main() {
  setUpAll(loadScreenshotFonts);

  Future<void> pump(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: LevelGoalsBar(
            targetSeconds: 30,
            usedHints: false,
            elapsedMs: 0,
            resumedAt: null,
            cleared: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 411.0]) {
    testWidgets('at ${width.toInt()} px every goal stays on one line', (
      tester,
    ) async {
      await pump(tester, width);
      final oneLine = tester.getSize(find.text('No hints')).height;
      expect(tester.getSize(find.text('Clear the board')).height, oneLine);
      expect(tester.getSize(find.text('0:30 or less')).height, oneLine);
    });
  }
}
