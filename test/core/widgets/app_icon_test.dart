import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/widgets/app_icon.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('a duotone glyph draws its fill layer under the outline', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppIcon(AppIcons.streak, size: 20, color: Color(0xFFFFC27A)),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, hasLength(2));
    expect(icons.first.icon, AppIcons.duotoneFill(AppIcons.streak));
    expect(icons.first.icon, isNot(AppIcons.streak));
    expect(icons.first.color!.a, closeTo(appIconDuotoneOpacity, 0.01));
    expect(icons.last.icon, AppIcons.streak);
    expect(icons.last.color, const Color(0xFFFFC27A));
    expect(find.byIcon(AppIcons.streak), findsOneWidget);
  });

  testWidgets('a filled glyph is a single Icon', (tester) async {
    await _pump(tester, const AppIcon(AppIcons.star, size: 20));
    expect(find.byType(Icon), findsOneWidget);
  });

  test('only duotone glyphs have a fill layer', () {
    expect(AppIcons.duotoneFill(AppIcons.trophy), isNotNull);
    expect(AppIcons.duotoneFill(AppIcons.trophySelected), isNull);
    expect(AppIcons.duotoneFill(AppIcons.expand), isNull);
  });

  testWidgets('a duotone glyph is announced once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const AppIcon(AppIcons.streak, semanticLabel: 'Streak'),
    );
    expect(find.bySemanticsLabel('Streak'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('without a colour, both layers take the IconTheme colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const IconTheme(
        data: IconThemeData(color: Color(0xFF38BDF8)),
        child: AppIcon(AppIcons.trophy),
      ),
    );
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.first.color!.withValues(alpha: 1), const Color(0xFF38BDF8));
    expect(icons.last.color, isNull);
  });
}
