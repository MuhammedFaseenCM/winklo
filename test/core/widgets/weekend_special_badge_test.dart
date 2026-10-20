import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/widgets/app_icon.dart';
import 'package:winklo/core/widgets/weekend_special_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(children: [Expanded(child: child)]),
      ),
    ),
  );

  testWidgets('a weekend special header shows the title and the badge', (
    tester,
  ) async {
    await pump(
      tester,
      const GameScreenTitle(title: 'Path Words', special: 'weekend'),
    );
    expect(find.text('Path Words'), findsOneWidget);
    expect(find.text(AppStrings.weekendSpecial), findsOneWidget);
    expect(find.byType(WeekendSpecialBadge), findsOneWidget);
  });

  testWidgets('any other day shows the title alone', (tester) async {
    for (final special in [null, 'holiday']) {
      await pump(tester, GameScreenTitle(title: 'Zip', special: special));
      expect(find.text('Zip'), findsOneWidget);
      expect(find.text(AppStrings.weekendSpecial), findsNothing);
    }
  });

  testWidgets('fits a 360-wide header next to its buttons', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              IconButton(onPressed: () {}, icon: const AppIcon(AppIcons.back)),
              const Expanded(
                child: GameScreenTitle(title: 'Path Words', special: 'weekend'),
              ),
              IconButton(
                onPressed: () {},
                icon: const AppIcon(AppIcons.refresh),
              ),
              IconButton(onPressed: () {}, icon: const AppIcon(AppIcons.help)),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
