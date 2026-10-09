import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/profile/view/widgets/profile_settings_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'sound effects switch calls onSfxChanged(false) when other rows are disabled',
    (tester) async {
      bool? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ProfileSettingsList(
              enabled: false,
              sfxEnabled: true,
              onSfxChanged: (value) => changedTo = value,
              onPrivacy: () {},
              onAbout: () {},
              onReport: () {},
              onSignOut: () {},
              onDeleteAccount: () {},
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.profileSoundEffects), findsOneWidget);

      final privacy = tester.widget<ListTile>(
        find.widgetWithText(ListTile, AppStrings.profilePrivacyPolicy),
      );
      expect(privacy.onTap, isNull);
      final delete = tester.widget<ListTile>(
        find.widgetWithText(ListTile, AppStrings.deleteAccount),
      );
      expect(delete.onTap, isNull);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changedTo, isFalse);
    },
  );

  testWidgets('omits the sound effects row when onSfxChanged is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ProfileSettingsList(
            onPrivacy: () {},
            onAbout: () {},
            onReport: () {},
            onSignOut: () {},
            onDeleteAccount: () {},
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.profileSoundEffects), findsNothing);
    expect(find.byType(Switch), findsNothing);
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
