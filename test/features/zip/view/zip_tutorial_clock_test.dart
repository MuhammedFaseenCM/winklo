import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/game_tutorial_overlay.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/features/zip/view/widgets/zip_tutorial.dart';
import 'package:winklo/features/zip/view/widgets/zip_how_to_play.dart';

class _Tutorials extends Mock implements TutorialRepository {}

class _Analytics extends Mock implements AnalyticsRepository {}

/// The guide holds the run's clock: the screen pauses it as the guide opens
/// and resumes it once it's closed, so reading it never costs time.
void main() {
  late _Tutorials tutorials;
  late _Analytics analytics;
  late List<String> clock;

  setUp(() {
    tutorials = _Tutorials();
    analytics = _Analytics();
    clock = [];
    when(() => tutorials.markSeen(GameIds.zip)).thenAnswer((_) async {});
    when(
      () => analytics.logTutorialShown(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logHowToPlayOpened(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logTutorialDismissed(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Widget Function(BuildContext) body) =>
      tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TutorialRepository>.value(value: tutorials),
            RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          ],
          child: MaterialApp(
            home: Scaffold(body: Builder(builder: body)),
          ),
        ),
      );

  Future<void> skip(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.tutorialSkip));
    await tester.pumpAndSettle();
  }

  testWidgets('a first-run guide pauses the clock until it closes', (
    tester,
  ) async {
    when(() => tutorials.hasSeen(GameIds.zip)).thenAnswer((_) async => false);
    await pump(
      tester,
      (context) => TextButton(
        onPressed: () => ZipTutorial.maybeShow(
          context,
          onOpen: () => clock.add('pause'),
          onClose: () => clock.add('resume'),
        ),
        child: const Text('start'),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameTutorialOverlay), findsOneWidget);
    expect(clock, ['pause']);
    await skip(tester);
    expect(clock, ['pause', 'resume']);
  });

  testWidgets('a guide already seen leaves the clock alone', (tester) async {
    when(() => tutorials.hasSeen(GameIds.zip)).thenAnswer((_) async => true);
    await pump(
      tester,
      (context) => TextButton(
        onPressed: () => ZipTutorial.maybeShow(
          context,
          onOpen: () => clock.add('pause'),
          onClose: () => clock.add('resume'),
        ),
        child: const Text('start'),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.byType(GameTutorialOverlay), findsNothing);
    expect(clock, isEmpty);
  });

  testWidgets('the help button pauses the clock while its guide is open', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => ZipHowToPlayButton(
        onOpen: () => clock.add('pause'),
        onClose: () => clock.add('resume'),
      ),
    );
    await tester.tap(find.byType(ZipHowToPlayButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(clock, ['pause']);
    await skip(tester);
    expect(clock, ['pause', 'resume']);
  });
}
