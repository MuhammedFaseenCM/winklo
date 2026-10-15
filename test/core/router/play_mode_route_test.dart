import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  final now = DateTime(2026, 10, 15, 9);

  group('playModeOf', () {
    test('a game route without mode is the daily', () {
      expect(playModeOf(Uri.parse('/zip'), now: now), PlayMode.daily);
      expect(playModeOf(Uri.parse('/sudoku?x=1'), now: now), PlayMode.daily);
    });

    test('an archive link opens that day', () {
      expect(
        playModeOf(Uri.parse('/zip?mode=archive&day=2026-10-12'), now: now),
        PlayMode.archive(DateTime(2026, 10, 12)),
      );
    });

    test('a practice link opens practice', () {
      expect(
        playModeOf(Uri.parse('/path-words?mode=practice'), now: now),
        PlayMode.practice,
      );
    });
  });

  group('playModeRedirect', () {
    test('leaves daily, practice and valid archive links alone', () {
      for (final link in [
        '/zip',
        '/zip?mode=practice',
        '/zip?mode=archive&day=2026-10-14',
      ]) {
        expect(
          playModeRedirect(Uri.parse(link), gameId: GameIds.zip, now: now),
          isNull,
          reason: link,
        );
      }
    });

    test('sends today, the future and broken days to the archive', () {
      for (final day in ['2026-10-15', '2026-11-01', '2026-10-01', 'x']) {
        expect(
          playModeRedirect(
            Uri.parse('/sudoku?mode=archive&day=$day'),
            gameId: GameIds.sudoku,
            now: now,
          ),
          '/more/archive?game=sudoku',
          reason: day,
        );
      }
    });
  });

  test('the hub and the archive have routes', () {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final router = buildRouter(analytics: analytics, authCubit: authCubit);
    addTearDown(router.dispose);
    for (final path in [
      '/more',
      '/more/archive',
      '/more/archive?game=sudoku',
      '/zip?mode=practice',
      '/path-words?mode=archive&day=2026-10-12',
    ]) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.isError, isFalse, reason: path);
    }
    expect(isPlayableLocation('/more'), isFalse);
    expect(isPlayableLocation('/more/archive'), isFalse);
  });
}
