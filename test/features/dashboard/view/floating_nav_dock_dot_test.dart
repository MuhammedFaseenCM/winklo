import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool dot}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingNavDock(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              showLevelsDot: dot,
            ),
          ),
        ),
      );

  testWidgets('a dot marks the Levels tab until it is opened', (tester) async {
    await pump(tester, dot: true);
    final dot = find.byKey(FloatingNavDock.levelsDotKey);
    expect(dot, findsOneWidget);
    // It sits on the Levels tab.
    final levels = tester.getRect(
      find.ancestor(
        of: find.text(AppStrings.levelsTitle),
        matching: find.byType(InkWell),
      ),
    );
    expect(levels.contains(tester.getCenter(dot)), isTrue);
  });

  testWidgets('no dot once the tab was opened', (tester) async {
    await pump(tester, dot: false);
    expect(find.byKey(FloatingNavDock.levelsDotKey), findsNothing);
  });

  testWidgets('the dot tells screen readers Levels is new', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, dot: true);
    expect(
      find.bySemanticsLabel(
        RegExp('${AppStrings.levelsTitle}.*${AppStrings.levelsIntroBadge}'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
