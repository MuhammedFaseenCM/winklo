import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/features/auth/cubit/auth_state.dart';

void main() {
  group('isPlayableLocation', () {
    test('marks game routes playable', () {
      expect(isPlayableLocation('/zip'), isTrue);
      expect(isPlayableLocation('/path-words'), isTrue);
      expect(isPlayableLocation('/sudoku'), isTrue);
      expect(isPlayableLocation('/word-match'), isTrue);
      expect(isPlayableLocation('/word-match/deck1'), isTrue);
      expect(isPlayableLocation('/category-race'), isTrue);
    });

    test('allows shell and results routes', () {
      expect(isPlayableLocation('/'), isFalse);
      expect(isPlayableLocation('/leaderboard'), isFalse);
      expect(isPlayableLocation('/profile'), isFalse);
      expect(isPlayableLocation('/profile/privacy'), isFalse);
      expect(isPlayableLocation('/results'), isFalse);
    });
  });

  group('playAuthRedirect', () {
    test('signed-out playable path redirects home', () {
      expect(
        playAuthRedirect(
          status: AuthStatus.signedOut,
          isSignedIn: false,
          matchedLocation: '/zip',
        ),
        '/',
      );
    });

    test('auth unknown does not redirect', () {
      expect(
        playAuthRedirect(
          status: AuthStatus.unknown,
          isSignedIn: false,
          matchedLocation: '/zip',
        ),
        isNull,
      );
    });

    test('signed-in playable path allowed', () {
      expect(
        playAuthRedirect(
          status: AuthStatus.signedIn,
          isSignedIn: true,
          matchedLocation: '/sudoku',
        ),
        isNull,
      );
    });

    test('signed-out leaderboard allowed', () {
      expect(
        playAuthRedirect(
          status: AuthStatus.signedOut,
          isSignedIn: false,
          matchedLocation: '/leaderboard',
        ),
        isNull,
      );
    });
  });
}
