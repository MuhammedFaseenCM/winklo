import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/repositories/levels_intro_repository.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/view/level_results_view.dart';

import 'level_results_view_test.dart' show args, phoneSize;

class _Intro extends Mock implements LevelsIntroRepository {}

const _level = LevelResultInfo(
  runStars: 2,
  bestStars: 2,
  usedHints: false,
  targetSeconds: 30,
  nextLevelId: 'zip_1_08',
);

void main() {
  late _Intro intro;

  setUp(() {
    intro = _Intro();
    when(() => intro.markFirstClearTipSeen()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepositoryProvider<LevelsIntroRepository>.value(
        value: intro,
        child: MaterialApp(
          home: LevelResultsView(args: args(level: _level)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first cleared level shows the tip and marks it seen', (
    tester,
  ) async {
    when(() => intro.firstClearTipSeen).thenReturn(false);
    await pump(tester);
    expect(find.text(AppStrings.levelsFirstClearTip), findsOneWidget);
    verify(() => intro.markFirstClearTipSeen()).called(1);
  });

  testWidgets('later clears don\'t show it', (tester) async {
    when(() => intro.firstClearTipSeen).thenReturn(true);
    await pump(tester);
    expect(find.text(AppStrings.levelsFirstClearTip), findsNothing);
    verifyNever(() => intro.markFirstClearTipSeen());
  });
}
