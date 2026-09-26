import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/profile/view/report_issue_screen.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockIssueReportRepository extends Mock
    implements IssueReportRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const user = AppUser(uid: 'u1', displayName: 'Ada');

  late _MockIssueReportRepository repo;
  late MockAnalyticsRepository analytics;
  late _MockAuthRepository auth;

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    repo = _MockIssueReportRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
  });

  Future<void> pumpReport(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/profile/report',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('profile-home')),
        ),
        GoRoute(
          path: '/profile/report',
          builder: (context, state) => const ReportIssueScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IssueReportRepository>.value(value: repo),
          RepositoryProvider<SubmitIssueReport>.value(
            value: SubmitIssueReport(repo),
          ),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  FilledButton sendButton(WidgetTester tester) {
    return tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.profileReportSend),
    );
  }

  testWidgets('send onPressed null until valid and while submitting', (
    tester,
  ) async {
    final completer = Completer<void>();
    when(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpReport(tester);
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Crash');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'App closes on save');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.text(AppStrings.profileReportSend));
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('can edit fields and tap send', (tester) async {
    when(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});

    await pumpReport(tester);

    await tester.enterText(find.byType(TextField).first, 'Crash');
    await tester.enterText(find.byType(TextField).last, 'App closes on save');
    await tester.pump();
    await tester.tap(find.text(AppStrings.profileReportSend));
    await tester.pumpAndSettle();

    verify(
      () => repo.submit(
        title: 'Crash',
        description: 'App closes on save',
        user: any(named: 'user'),
      ),
    ).called(1);
    verify(() => analytics.logProfileReportOpened()).called(1);
    verify(() => analytics.logProfileReportSubmitted()).called(1);
  });
}
