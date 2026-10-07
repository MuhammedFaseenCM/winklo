import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/profile/view/profile_screen.dart';
import 'package:winklo/features/profile/view/report_issue_screen.dart';
import 'package:winklo/features/profile/view/widgets/profile_shimmer.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockIssueReportRepository extends Mock
    implements IssueReportRepository {}

class _MockSfxSettingsRepository extends Mock
    implements SfxSettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const user = AppUser(uid: 'u1', displayName: 'Ada');

  late _MockAuthRepository auth;
  late _MockSignOut signOut;
  late _MockProfileRepository profile;
  late MockAnalyticsRepository analytics;
  late _MockSfxSettingsRepository sfxSettings;
  late SfxService sfx;

  setUp(() {
    auth = _MockAuthRepository();
    signOut = _MockSignOut();
    profile = _MockProfileRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => signOut()).thenAnswer((_) async {});
    sfxSettings = _MockSfxSettingsRepository();
    when(() => sfxSettings.isEnabled).thenReturn(true);
    when(() => sfxSettings.setEnabled(any())).thenAnswer((_) async {});
    sfx = SfxService(settings: sfxSettings);
  });

  List<RepositoryProvider<dynamic>> profileProviders() => [
    RepositoryProvider<AuthRepository>.value(value: auth),
    RepositoryProvider<ProfileRepository>.value(value: profile),
    RepositoryProvider<UpdateDisplayName>.value(
      value: UpdateDisplayName(profile),
    ),
    RepositoryProvider<UpdateAvatar>.value(value: UpdateAvatar(profile)),
    RepositoryProvider<AnalyticsRepository>.value(value: analytics),
    RepositoryProvider<SignOut>.value(value: signOut),
    RepositoryProvider<SfxService>.value(value: sfx),
  ];

  Future<void> pumpProfile(WidgetTester tester, {AppUser? signedIn}) async {
    when(() => auth.currentUser).thenReturn(signedIn);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(signedIn));
    if (signedIn != null) {
      when(
        () => profile.watchProfile(signedIn.uid),
      ).thenAnswer((_) => Stream<AppUser?>.value(signedIn));
    }

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: profileProviders(),
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: signOut,
          ),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('signed-in avatar shows edit icon', (tester) async {
    await pumpProfile(tester, signedIn: user);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('signed-in profile shows hero and settings rows', (tester) async {
    await pumpProfile(tester, signedIn: user);

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text(AppStrings.profileEditDisplayName), findsOneWidget);
    expect(find.text(AppStrings.profilePrivacyPolicy), findsOneWidget);
    expect(find.text(AppStrings.profileAboutGame), findsOneWidget);
    expect(find.text(AppStrings.profileReportIssue), findsOneWidget);
    expect(find.text(AppStrings.signOut), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    final logout = tester.widget<ListTile>(
      find.widgetWithText(ListTile, AppStrings.signOut),
    );
    expect(logout.trailing, isNull);
    expect((logout.leading! as Icon).icon, Icons.logout);

    final privacy = tester.widget<ListTile>(
      find.widgetWithText(ListTile, AppStrings.profilePrivacyPolicy),
    );
    expect((privacy.trailing! as Icon).icon, Icons.chevron_right);
  });

  testWidgets('tapping edit display name opens sheet with field', (
    tester,
  ) async {
    await pumpProfile(tester, signedIn: user);

    await tester.tap(find.text(AppStrings.profileEditDisplayName));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(AppStrings.profileSave), findsOneWidget);
  });

  testWidgets('saving a name closes the sheet', (tester) async {
    when(
      () => profile.updateDisplayName('Grace'),
    ).thenAnswer((_) async => const AppUser(uid: 'u1', displayName: 'Grace'));
    await pumpProfile(tester, signedIn: user);

    await tester.tap(find.text(AppStrings.profileEditDisplayName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Grace');
    await tester.tap(find.text(AppStrings.profileSave));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('invalid name keeps the sheet open with an error', (
    tester,
  ) async {
    await pumpProfile(tester, signedIn: user);

    await tester.tap(find.text(AppStrings.profileEditDisplayName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text(AppStrings.profileSave));
    await tester.pump();

    expect(find.text(AppStrings.profileNameEmpty), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    verifyNever(() => profile.updateDisplayName(any()));
  });

  testWidgets(
    'log out shows confirm dialog then records analytics and signs out',
    (tester) async {
      await pumpProfile(tester, signedIn: user);

      await tester.tap(find.text(AppStrings.signOut));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signOutConfirmTitle), findsOneWidget);
      verifyNever(() => analytics.logProfileSignOut());
      verifyNever(() => signOut());

      await tester.tap(find.widgetWithText(TextButton, AppStrings.signOut));
      await tester.pumpAndSettle();

      verifyInOrder([() => analytics.logProfileSignOut(), () => signOut()]);
    },
  );

  testWidgets('canceling sign out confirm does not sign out', (tester) async {
    await pumpProfile(tester, signedIn: user);

    await tester.tap(find.text(AppStrings.signOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.signOutConfirmCancel));
    await tester.pumpAndSettle();

    verifyNever(() => analytics.logProfileSignOut());
    verifyNever(() => signOut());
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('auth unknown shows ProfileShimmer not sign-in CTA', (
    tester,
  ) async {
    final controller = StreamController<AppUser?>();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: profileProviders(),
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: signOut,
          ),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ProfileShimmer), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsNothing);

    await controller.close();
  });

  testWidgets('auth signedOut still shows sign-in CTA', (tester) async {
    await pumpProfile(tester, signedIn: null);
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
    expect(find.byType(ProfileShimmer), findsNothing);
  });

  testWidgets('signed-out mock shows an inert hero and settings list', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text(AppStrings.profileSignedOutBody), findsOneWidget);
    expect(find.text(AppStrings.profilePrivacyPolicy), findsOneWidget);
    expect(find.text(AppStrings.signOut), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, isNotEmpty);
    expect(tiles.every((tile) => tile.onTap == null), isTrue);
    expect(find.text(AppStrings.profileSoundEffects), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('signed-out foreground sound switch mutes SfxService', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(sfx.isEnabled, isTrue);
    expect(find.text(AppStrings.profileSoundEffects), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(sfx.isEnabled, isFalse);
    verify(() => sfxSettings.setEnabled(false)).called(1);
  });

  testWidgets('report row opens the report screen', (tester) async {
    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => profile.watchProfile(user.uid),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'report',
              builder: (context, state) => const ReportIssueScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          ...profileProviders(),
          RepositoryProvider<IssueReportRepository>.value(
            value: _MockIssueReportRepository(),
          ),
          RepositoryProvider<SubmitIssueReport>(
            create: (context) =>
                SubmitIssueReport(context.read<IssueReportRepository>()),
          ),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: signOut,
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.profileReportIssue));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileReportTitleLabel), findsOneWidget);
    expect(find.text(AppStrings.profileReportSend), findsOneWidget);
    verify(() => analytics.logProfileReportOpened()).called(1);
  });
}
