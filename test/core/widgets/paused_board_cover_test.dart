import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/paused_board_cover.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool playing,
    required bool paused,
    VoidCallback? onResume,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PausedBoardCover(
          playing: playing,
          paused: paused,
          onResume: onResume,
          child: const SizedBox.expand(child: Text('board')),
        ),
      ),
    ),
  );

  final cover = find.byKey(const Key('paused_board_cover'));

  testWidgets('covers the board while the run is paused', (tester) async {
    var resumed = 0;
    await pump(tester, playing: true, paused: true, onResume: () => resumed++);

    expect(cover, findsOneWidget);
    expect(find.text(AppStrings.gamePaused), findsOneWidget);
    expect(find.text(AppStrings.gamePausedResume), findsOneWidget);

    await tester.tap(cover);
    expect(resumed, 1);
  });

  testWidgets('shows the board while the run is going', (tester) async {
    await pump(tester, playing: true, paused: false);
    expect(cover, findsNothing);
  });

  testWidgets('leaves a finished or review board alone', (tester) async {
    await pump(tester, playing: false, paused: true);
    expect(cover, findsNothing);
  });

  testWidgets('covers the board while the app is in the background', (
    tester,
  ) async {
    await pump(tester, playing: true, paused: false);
    expect(cover, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(cover, findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(cover, findsNothing);
  });
}
