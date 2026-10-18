import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/leagues/view/league_routes.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockSignIn extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  late AuthCubit authCubit;

  setUp(() {
    final auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignIn(),
      signOut: _MockSignOut(),
    );
  });

  tearDown(() => authCubit.close());

  test('invite links and league pages reach the league screens', () {
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final router = buildRouter(analytics: analytics, authCubit: authCubit);
    addTearDown(router.dispose);

    final join = router.configuration.findMatch(Uri.parse('/join/ABC234'));
    expect(join.isError, isFalse);
    expect(join.pathParameters['code'], 'ABC234');
    expect(join.last.route.name, 'join_league');

    final league = router.configuration.findMatch(Uri.parse('/leagues/L1'));
    expect(league.pathParameters['leagueId'], 'L1');
    expect(league.last.route.name, 'league');
  });

  test('the league routes come first, ahead of any older /join route', () {
    expect(leagueRoutes(), hasLength(2));
    expect(isPlayableLocation('/join/ABC234'), isFalse);
    expect(isPlayableLocation('/leagues'), isFalse);
  });
}
