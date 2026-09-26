import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:winklo/app.dart';
import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/streak_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Winklo',
      packageName: 'com.winklo.faseencm',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('Home shows Winklo brand and daily CTAs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: const WinkloApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTagline), findsOneWidget);
    expect(find.text(AppStrings.zipTitle), findsOneWidget);
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);
    if (DevFlags.zipOnlyTesting) {
      expect(find.text(AppStrings.pathWordsTitle), findsNothing);
      expect(find.text(AppStrings.playTodaysPathWords), findsNothing);
      expect(find.text(AppStrings.today), findsOneWidget);
    } else {
      expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
      expect(find.text(AppStrings.playTodaysPathWords), findsOneWidget);
      expect(find.text(AppStrings.today), findsNWidgets(2));
    }
    expect(find.text('Choose a puzzle'), findsNothing);
    expect(find.text('Parked for later'), findsNothing);
    expect(find.text(AppStrings.wordMatch), findsNothing);
    expect(find.text(AppStrings.categoryRace), findsNothing);
  });

  testWidgets('Home shows Path Words streak independently of Zip', (
    tester,
  ) async {
    if (DevFlags.zipOnlyTesting) return;
    final todayId = StreakCalculator.dateId(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'streak_current_${GameIds.pathWords}': 3,
      'streak_longest_${GameIds.pathWords}': 5,
      'streak_last_${GameIds.pathWords}': todayId,
      'best_pts_path_words_$todayId': 18,
      'best_time_path_words_$todayId': 29,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: const WinkloApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.streakLabel(3)), findsOneWidget);
    expect(
      find.textContaining(AppStrings.longestStreakLabel(5)),
      findsNothing,
    );
    expect(find.text(AppStrings.cleared), findsNothing);
    expect(find.text(AppStrings.result), findsOneWidget);
    expect(find.text(AppStrings.comeBackTomorrow), findsNothing);
    expect(find.text(AppStrings.playAgain), findsNothing);
    expect(find.text(AppStrings.playTodaysPathWords), findsNothing);
    expect(find.text(AppStrings.playTodaysZip), findsOneWidget);

    await tester.tap(find.text(AppStrings.result));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(AppStrings.pathWordsClearedTitle), findsNothing);
    expect(find.text(AppStrings.newPuzzleUnlocksTomorrow), findsNothing);
    expect(find.text(AppStrings.backHome), findsNothing);
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
    expect(find.text(AppStrings.pathWordsUndo), findsNothing);
  });
}
