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

  testWidgets('dock clears bottom view padding / home indicator', (
    tester,
  ) async {
    const bottomInset = 34.0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: FloatingNavDock(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final dock = tester.getRect(find.byKey(const Key('floating_nav_dock')));
    final screen = tester.getRect(find.byType(Scaffold));
    // Dock bottom edge stays above the home-indicator inset (+ 12px gap).
    expect(dock.bottom, lessThanOrEqualTo(screen.bottom - bottomInset - 11));
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

  testWidgets('selection pill slides when index changes', (tester) async {
    Future<void> pumpIndex(int index) {
      return tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            bottomNavigationBar: FloatingNavDock(
              selectedIndex: index,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
    }

    await pumpIndex(0);
    final start = tester.getTopLeft(
      find.byKey(const Key('floating_nav_dock_pill')),
    );

    await pumpIndex(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final mid = tester.getTopLeft(
      find.byKey(const Key('floating_nav_dock_pill')),
    );
    expect(mid.dx, greaterThan(start.dx));

    await tester.pumpAndSettle();
    final end = tester.getTopLeft(
      find.byKey(const Key('floating_nav_dock_pill')),
    );
    expect(end.dx, greaterThan(mid.dx));
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
