import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/dashboard/view/widgets/tab_switch_animator.dart';

void main() {
  testWidgets('restarts fade/slide when index changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TabSwitchAnimator(
          index: 0,
          child: SizedBox(key: Key('body'), width: 100, height: 100),
        ),
      ),
    );

    expect(find.byKey(const Key('body')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: TabSwitchAnimator(
          index: 1,
          child: SizedBox(key: Key('body'), width: 100, height: 100),
        ),
      ),
    );
    await tester.pump();
    // Mid-animation: child still present (IndexedStack-friendly wrapper).
    expect(find.byKey(const Key('body')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('body')), findsOneWidget);
  });
}
