import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
