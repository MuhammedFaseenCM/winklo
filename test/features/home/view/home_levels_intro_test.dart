import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/home/view/home_screen.dart';

/// Home shows the "New: Levels" card once per install.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<SharedPreferences> pumpHome(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      HomeScreen.permissionPromptedKey: true,
      ...prefsValues,
    });
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    return prefs;
  }

  testWidgets('the first Home visit shows the Levels card and marks it seen', (
    tester,
  ) async {
    final prefs = await pumpHome(tester);
    expect(find.text(AppStrings.levelsIntroTitle), findsOneWidget);
    expect(prefs.getBool('levels_intro_seen'), isTrue);
  });

  testWidgets('once seen, Home never shows it again', (tester) async {
    await pumpHome(tester, prefsValues: {'levels_intro_seen': true});
    expect(find.text(AppStrings.levelsIntroTitle), findsNothing);
  });
}
