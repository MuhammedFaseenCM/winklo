import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/blurred_mock_empty_body.dart';
import 'package:winklo/core/widgets/centered_message_body.dart';

void main() {
  Future<void> pumpBody(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('shows message, action, and background; action works', (
    tester,
  ) async {
    var tapped = false;
    await pumpBody(
      tester,
      BlurredMockEmptyBody(
        background: const Text('MockBackground'),
        message: 'Sign in please',
        actionLabel: 'Continue with Google',
        onAction: () => tapped = true,
      ),
    );

    expect(find.text('MockBackground'), findsOneWidget);
    expect(find.text('Sign in please'), findsOneWidget);
    expect(find.byType(CenteredMessageBody), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Continue with Google'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('ignores pointer events on background', (tester) async {
    var backgroundTapped = false;
    var actionTapped = false;
    await pumpBody(
      tester,
      BlurredMockEmptyBody(
        background: GestureDetector(
          onTap: () => backgroundTapped = true,
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(color: Colors.red),
          ),
        ),
        message: 'Locked',
        actionLabel: 'Sign in',
        onAction: () => actionTapped = true,
      ),
    );

    final redBackground = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == Colors.red,
    );
    await tester.tapAt(tester.getCenter(redBackground));
    await tester.pump();
    expect(backgroundTapped, isFalse);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(actionTapped, isTrue);
  });
}
