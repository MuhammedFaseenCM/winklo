import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/profile/view/widgets/profile_settings_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('tapping sound effects switch calls onSfxChanged(false)', (
    tester,
  ) async {
    bool? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ProfileSettingsList(
            sfxEnabled: true,
            onSfxChanged: (value) => changedTo = value,
            onPrivacy: () {},
            onAbout: () {},
            onReport: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.profileSoundEffects), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(changedTo, isFalse);
  });
}
