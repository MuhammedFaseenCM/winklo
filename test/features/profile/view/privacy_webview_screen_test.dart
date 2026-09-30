import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/profile/view/privacy_webview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('privacy screen shows the policy title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PrivacyWebViewScreen(
          webViewOverride: (context) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text(AppStrings.profilePrivacyPolicy), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
