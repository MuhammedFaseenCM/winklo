import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
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

  testWidgets('centers title, message, and default action', (tester) async {
    var tapped = false;
    await pumpBody(
      tester,
      CenteredMessageBody(
        title: 'Your profile',
        message: 'Sign in please',
        actionLabel: 'Continue with Google',
        onAction: () => tapped = true,
      ),
    );

    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Sign in please'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Continue with Google'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('omits title and action when not provided', (tester) async {
    await pumpBody(tester, const CenteredMessageBody(message: 'Empty board'));

    expect(find.text('Empty board'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('custom action replaces default button', (tester) async {
    await pumpBody(
      tester,
      CenteredMessageBody(
        message: 'Retry?',
        actionLabel: 'Unused',
        onAction: () {},
        action: TextButton(onPressed: () {}, child: const Text('Custom')),
      ),
    );

    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Unused'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
