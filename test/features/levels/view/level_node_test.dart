import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/view/widgets/level_avatar_pin.dart';
import 'package:winklo/features/levels/view/widgets/level_node.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 3), levelWorld(2, 1, theme: 'metro')]),
    const LevelProgress({'zip_1_01': LevelRecord(stars: 2, bestSeconds: 20)}),
  );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('a done level reads its stars and taps', (tester) async {
    var taps = 0;
    await pump(
      tester,
      LevelNode(node: map.node('zip_1_01')!, onTap: () => taps++),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 1, 2 of 3 stars'), findsOneWidget);
    await tester.tap(find.byType(LevelNode));
    expect(taps, 1);
  });

  testWidgets('the current and a locked level', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          LevelNode(node: map.node('zip_1_02')!, onTap: () {}),
          LevelNode(node: map.node('zip_2_01')!, onTap: () {}),
        ],
      ),
    );
    expect(find.bySemanticsLabel('Level 2, next to play'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 4, locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the avatar pin draws with or without a player', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          LevelAvatarPin(
            user: AppUser(uid: 'u1', displayName: 'Asha'),
          ),
          LevelAvatarPin(user: null),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long number at a large text size stays inside', (
    tester,
  ) async {
    final big = LevelMap.build(
      LevelCatalog([levelWorld(1, 100)]),
      const LevelProgress({}),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: LevelNode(node: big.node('zip_1_100')!, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
