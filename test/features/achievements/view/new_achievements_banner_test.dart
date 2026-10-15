import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/usecases/claim_new_achievements.dart';
import 'package:winklo/features/achievements/view/new_achievements_banner.dart';

class _MockClaim extends Mock implements ClaimNewAchievements {}

List<Achievement> _ids(List<String> ids) => [
  for (final id in ids) Achievements.byId(id)!,
];

void main() {
  late _MockClaim claim;

  setUp(() => claim = _MockClaim());

  Future<void> pumpBanner(WidgetTester tester, {bool provide = true}) async {
    const app = MaterialApp(
      home: Scaffold(body: Center(child: NewAchievementsBanner())),
    );
    await tester.pumpWidget(
      Theme(
        data: buildAppTheme(),
        child: provide
            ? RepositoryProvider<ClaimNewAchievements>.value(
                value: claim,
                child: app,
              )
            : app,
      ),
    );
    await tester.pumpAndSettle();
    // The banner's entrance starts on a zero-delay timer once it builds.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('one new badge by name', (tester) async {
    when(() => claim()).thenAnswer((_) async => _ids(['first_clear_zip']));
    await pumpBanner(tester);

    expect(find.text(AppStrings.newAchievementsTitle(1)), findsOneWidget);
    expect(find.text('First Zip'), findsOneWidget);
    verify(() => claim()).called(1);
  });

  testWidgets('several new badges are summarised', (tester) async {
    when(() => claim()).thenAnswer(
      (_) async => _ids([
        'first_clear_zip',
        'streak_7_zip',
        'perfect_day',
        'zip_under_minute',
      ]),
    );
    await pumpBanner(tester);

    expect(find.text(AppStrings.newAchievementsTitle(4)), findsOneWidget);
    expect(find.text('First Zip, 7-day Zip streak and 2 more'), findsOneWidget);
  });

  testWidgets('nothing new shows nothing', (tester) async {
    when(() => claim()).thenAnswer((_) async => const []);
    await pumpBanner(tester);

    expect(find.text(AppStrings.newAchievementsTitle(1)), findsNothing);
    expect(tester.getSize(find.byType(NewAchievementsBanner)), Size.zero);
  });

  testWidgets('a failed claim shows nothing', (tester) async {
    when(() => claim()).thenAnswer((_) async => throw const Failure('x'));
    await pumpBanner(tester);

    expect(find.textContaining('badge'), findsNothing);
  });

  testWidgets('hidden without ClaimNewAchievements', (tester) async {
    await pumpBanner(tester, provide: false);

    expect(tester.getSize(find.byType(NewAchievementsBanner)), Size.zero);
  });

  test('the list copy', () {
    expect(AppStrings.newAchievementsList(['A']), 'A');
    expect(AppStrings.newAchievementsList(['A', 'B']), 'A and B');
    expect(AppStrings.newAchievementsList(['A', 'B', 'C']), 'A, B and 1 more');
  });
}
