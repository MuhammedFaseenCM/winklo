import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/profile/view/widgets/sign_out_confirm_dialog.dart';

void main() {
  testWidgets('confirm returns true and cancel returns false', (tester) async {
    late bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await showSignOutConfirmDialog(context);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signOutConfirmTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.signOutConfirmCancel));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, AppStrings.signOut));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
