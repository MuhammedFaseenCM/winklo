import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/domain/repositories/share_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/leagues/view/league_routes.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockLeagues extends Mock implements LeagueRepository {}

class _MockShare extends Mock implements ShareRepository {}

class _MockSignIn extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

const _me = AppUser(uid: 'u1', displayName: 'Ada');

const _family = League(
  id: 'L1',
  name: 'Family',
  ownerUid: 'u1',
  code: 'ABC234',
  memberUids: ['u1', 'u2'],
);

const _office = League(
  id: 'L2',
  name: 'Office',
  ownerUid: 'u9',
  code: 'XYZ234',
  memberUids: ['u9', 'u1'],
);

void main() {
  late _MockAuth auth;
  late _MockLeagues leagues;
  late _MockShare share;

  setUpAll(() {
    registerFallbackValue(_family);
  });

  setUp(() {
    auth = _MockAuth();
    leagues = _MockLeagues();
    share = _MockShare();
    when(() => auth.currentUser).thenReturn(_me);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(_me));
    when(
      () => leagues.watchMyLeagues('u1'),
    ).thenAnswer((_) => Stream.value(const [_family, _office]));
    when(
      () => leagues.watchLeague('L1'),
    ).thenAnswer((_) => Stream.value(_family));
    when(
      () => leagues.watchLeague('L2'),
    ).thenAnswer((_) => Stream.value(_office));
    when(() => leagues.memberProfiles(any())).thenAnswer(
      (_) async => const {'u2': LeagueMember(uid: 'u2', displayName: 'Bo')},
    );
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignIn(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (_, state) =>
              Text('board ${state.uri.queryParameters['league']}'),
        ),
        ...leagueRoutes(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<LeagueRepository>.value(value: leagues),
          RepositoryProvider<ShareRepository>.value(value: share),
        ],
        child: BlocProvider.value(
          value: authCubit,
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('leagues lists mine at 360×640 and opens one', (tester) async {
    await pump(tester, '/leagues');

    expect(tester.takeException(), isNull);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text(AppStrings.leaguesCreate), findsOneWidget);
    expect(find.text(AppStrings.leaguesJoin), findsOneWidget);

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('league_code')), findsOneWidget);
  });

  testWidgets('creating a league opens it', (tester) async {
    when(() => leagues.create('Cousins')).thenAnswer((_) async => _family);
    await pump(tester, '/leagues');

    await tester.tap(find.text(AppStrings.leaguesCreate));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Cousins ');
    await tester.tap(find.text(AppStrings.leagueCreateAction));
    await tester.pumpAndSettle();

    verify(() => leagues.create('Cousins')).called(1);
    expect(find.byKey(const Key('league_code')), findsOneWidget);
  });

  testWidgets('a code that cannot be one is refused in the dialog', (
    tester,
  ) async {
    await pump(tester, '/leagues');
    await tester.tap(find.text(AppStrings.leaguesJoin));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text(AppStrings.leagueJoinAction));
    await tester.pump();
    expect(find.text(AppStrings.leagueCodeInvalid), findsOneWidget);
  });

  testWidgets('the owner sees the code, players, remove and delete', (
    tester,
  ) async {
    when(() => share.shareText(any())).thenAnswer((_) async => true);
    await pump(tester, '/leagues/L1');

    expect(tester.takeException(), isNull);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.textContaining('Bo'), findsOneWidget);
    expect(find.byTooltip(AppStrings.leagueRemove), findsOneWidget);
    expect(find.byTooltip(AppStrings.leagueRename), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AppStrings.leagueDelete),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.leagueDelete), findsOneWidget);

    await tester.tap(find.text(AppStrings.leagueShareInvite));
    await tester.pump();
    verify(
      () => share.shareText(
        AppStrings.leagueInviteText(
          'Family',
          'https://brain-zip-app.web.app/join/ABC234',
        ),
      ),
    ).called(1);
  });

  testWidgets('a member can leave but not manage', (tester) async {
    when(() => leagues.leave('L2')).thenAnswer((_) async {});
    await pump(tester, '/leagues/L2');

    expect(find.byTooltip(AppStrings.leagueRemove), findsNothing);
    expect(find.byTooltip(AppStrings.leagueRename), findsNothing);
    await tester.scrollUntilVisible(
      find.text(AppStrings.leagueLeave),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.leagueLeave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.leagueLeave).last);
    await tester.pumpAndSettle();

    verify(() => leagues.leave('L2')).called(1);
  });

  testWidgets('See the board opens the league on the leaderboard', (
    tester,
  ) async {
    await pump(tester, '/leagues/L1');
    await tester.tap(find.text(AppStrings.leagueSeeBoard));
    await tester.pumpAndSettle();
    expect(find.text('board L1'), findsOneWidget);
  });

  testWidgets('an invite link joins the league', (tester) async {
    const invited = League(
      id: 'L3',
      name: 'Book club',
      ownerUid: 'u7',
      code: 'QRS234',
      memberUids: ['u7'],
    );
    when(() => leagues.findByCode('QRS234')).thenAnswer((_) async => invited);
    when(() => leagues.join('QRS234')).thenAnswer(
      (_) async => const League(
        id: 'L3',
        name: 'Book club',
        ownerUid: 'u7',
        code: 'QRS234',
        memberUids: ['u7', 'u1'],
      ),
    );
    when(() => leagues.watchLeague('L3')).thenAnswer(
      (_) => Stream.value(
        const League(
          id: 'L3',
          name: 'Book club',
          ownerUid: 'u7',
          code: 'QRS234',
          memberUids: ['u7', 'u1'],
        ),
      ),
    );
    await pump(tester, '/join/qrs234');

    expect(tester.takeException(), isNull);
    expect(find.text('Book club'), findsOneWidget);
    expect(find.text(AppStrings.leagueMembers(1)), findsOneWidget);

    await tester.tap(find.byKey(const Key('join_league_button')));
    await tester.pumpAndSettle();

    verify(() => leagues.join('QRS234')).called(1);
    expect(find.byKey(const Key('league_code')), findsOneWidget);
  });

  testWidgets('an invite link asks a signed-out player to sign in', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));
    await pump(tester, '/join/QRS234');
    expect(find.text(AppStrings.joinLeagueSignIn), findsOneWidget);
    verifyNever(() => leagues.findByCode(any()));
  });
}
