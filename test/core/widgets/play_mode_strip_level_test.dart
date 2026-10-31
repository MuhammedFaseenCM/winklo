import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/widgets/app_icon.dart';
import 'package:winklo/core/widgets/play_mode_strip.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  testWidgets('a level run shows its level label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayModeStrip(
            mode: PlayMode.level('zip_1_07'),
            levelLabel: 'Level 7 · Ink · Target 0:30',
          ),
        ),
      ),
    );
    expect(find.text('Level 7 · Ink · Target 0:30'), findsOneWidget);
  });

  testWidgets('before the board loads it says Levels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlayModeStrip(mode: PlayMode.level('zip_1_07'))),
      ),
    );
    expect(find.text('Levels'), findsOneWidget);
  });

  testWidgets("a level run's strip shows the Levels icon", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlayModeStrip(mode: PlayMode.level('zip_1_07'))),
      ),
    );
    Finder icon(IconData data) =>
        find.byWidgetPredicate((w) => w is AppIcon && w.icon == data);
    expect(icon(AppIcons.levels), findsOneWidget);
    expect(icon(AppIcons.infinity), findsNothing);
  });

  testWidgets('a long label fits a narrow strip at a large text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PlayModeStrip(
                  mode: PlayMode.level('zip_27_01'),
                  levelLabel: 'ലെവൽ 27 · ചിത്രത്തുന്നൽ · ലക്ഷ്യം 0:30',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
