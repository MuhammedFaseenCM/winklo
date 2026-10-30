import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/view/widgets/level_sheet.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 2)]),
    const LevelProgress({'zip_1_01': LevelRecord(stars: 2, bestSeconds: 17)}),
  );

  Future<List<String>> openSheet(WidgetTester tester, String id) async {
    final visited = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLevelSheet(context, map.node(id)!),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/zip',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('a cleared level: world, number, best time, goals, Replay', (
    tester,
  ) async {
    final visited = await openSheet(tester, 'zip_1_01');
    expect(find.text('World 1 · Ink'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('3 × 3 · Best 0:17'), findsOneWidget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();
    expect(visited, ['/zip?mode=level&level=zip_1_01']);
  });

  testWidgets('the current level says Play', (tester) async {
    await openSheet(tester, 'zip_1_02');
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('3 × 3'), findsOneWidget);
  });
}
