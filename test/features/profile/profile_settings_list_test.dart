import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/profile/view/widgets/profile_settings_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('the Settings row opens Settings, even with others disabled', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettingsList(
              onSettings: () => opened++,
              onPrivacy: () {},
              onAbout: () {},
              onReport: () {},
              onSignOut: () {},
              onDeleteAccount: () {},
            ),
          ),
        ),
      ),
    );

    // Sound and vibration moved to Settings.
    expect(find.text(AppStrings.profileSoundEffects), findsNothing);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text(AppStrings.profileSettings));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('a disabled list keeps the Settings row inert', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettingsList(
              enabled: false,
              onSettings: () {},
              onPrivacy: () {},
              onAbout: () {},
              onReport: () {},
              onSignOut: () {},
              onDeleteAccount: () {},
            ),
          ),
        ),
      ),
    );

    final settings = tester.widget<ListTile>(
      find.widgetWithText(ListTile, AppStrings.profileSettings),
    );
    expect(settings.onTap, isNull);
    final privacy = tester.widget<ListTile>(
      find.widgetWithText(ListTile, AppStrings.profilePrivacyPolicy),
    );
    expect(privacy.onTap, isNull);
  });

  testWidgets('omits the Settings row when onSettings is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettingsList(
              onPrivacy: () {},
              onAbout: () {},
              onReport: () {},
              onSignOut: () {},
              onDeleteAccount: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.profileSettings), findsNothing);
  });

  testWidgets('delete account row calls onDeleteAccount', (tester) async {
    var deleteTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettingsList(
              onPrivacy: () {},
              onAbout: () {},
              onReport: () {},
              onSignOut: () {},
              onDeleteAccount: () => deleteTaps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.deleteAccount));
    await tester.pump();

    expect(deleteTaps, 1);
  });
}
