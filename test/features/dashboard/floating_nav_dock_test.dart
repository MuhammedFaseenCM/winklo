import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';

void main() {
  testWidgets('shows three labels and reports taps', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 0,
            onDestinationSelected: taps.add,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);

    await tester.tap(find.text(AppStrings.navLeaderboard));
    await tester.pump();
    expect(taps, [1]);
  });

  testWidgets('dock is horizontally inset from screen edges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    final dock = tester.getRect(find.byKey(const Key('floating_nav_dock')));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(dock.left, greaterThan(screen.left + 8));
    expect(dock.right, lessThan(screen.right - 8));
  });

  testWidgets('leaderboard uses trophy icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.emoji_events), findsWidgets);
  });

  testWidgets('selected destination announces selected semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    final semanticsHandle = tester.ensureSemantics();

    final selected = tester.getSemantics(
      find.bySemanticsLabel(AppStrings.navLeaderboard),
    );
    expect(selected.hasFlag(SemanticsFlag.isSelected), isTrue);

    final unselected = tester.getSemantics(
      find.bySemanticsLabel(AppStrings.navHome),
    );
    expect(unselected.hasFlag(SemanticsFlag.isSelected), isFalse);

    semanticsHandle.dispose();
  });
}
