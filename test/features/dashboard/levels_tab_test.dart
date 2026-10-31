import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';

void main() {
  testWidgets('Levels is the second destination', (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingNavDock(
            selectedIndex: 0,
            onDestinationSelected: (i) => picked = i,
          ),
        ),
      ),
    );
    expect(find.text('Levels'), findsOneWidget);
    await tester.tap(find.text('Levels'));
    expect(picked, 1);
  });
}
