import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/usecases/handle_notification_tap.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository {}

void main() {
  final handle = HandleNotificationTap();

  test('logs the tap with its type and the route it resolved to', () {
    final analytics = _MockAnalytics();
    when(
      () => analytics.logNotificationOpened(
        type: any(named: 'type'),
        route: any(named: 'route'),
      ),
    ).thenAnswer((_) async {});

    final route = HandleNotificationTap(analytics: analytics)(
      const NotificationTap(type: 'streak_at_risk', route: '/Home'),
    );

    expect(route, '/');
    verify(
      () => analytics.logNotificationOpened(type: 'streak_at_risk', route: '/'),
    ).called(1);
  });

  test('opens Settings', () {
    expect(
      handle(const NotificationTap(type: 'x', route: '/profile/settings')),
      '/profile/settings',
    );
  });

  test('opens Stats', () {
    expect(
      handle(const NotificationTap(type: 'x', route: '/profile/stats')),
      '/profile/stats',
    );
  });

  group('leagues', () {
    const leagueId = 'Ab3dEf6hIj9lMn2pQr5t';

    test('opens the leagues list and a league page', () {
      expect(
        handle(const NotificationTap(type: 'x', route: '/leagues')),
        '/leagues',
      );
      expect(
        handle(const NotificationTap(type: 'x', route: '/leagues/$leagueId')),
        '/leagues/$leagueId',
      );
    });

    test('a league id that is not one goes home', () {
      for (final route in [
        '/leagues/',
        '/leagues/short',
        '/leagues/$leagueId/extra',
        '/leagues/Ab3dEf6hIj9lMn2pQr5t1',
        '/leagues/Ab3dEf6hIj9lMn2pQr-t',
        '/leagues/%20b3dEf6hIj9lMn2pQr5t',
      ]) {
        expect(
          handle(NotificationTap(type: 'x', route: route)),
          '/',
          reason: route,
        );
      }
    });

    test('opens an invite, with its code as the join screen reads it', () {
      expect(
        handle(const NotificationTap(type: 'x', route: '/join/ABC234')),
        '/join/ABC234',
      );
      expect(
        handle(const NotificationTap(type: 'x', route: '/join/abc234')),
        '/join/ABC234',
      );
    });

    test('a code that is not one goes home', () {
      for (final route in [
        '/join',
        '/join/',
        '/join/ABC23',
        '/join/ABC2345',
        '/join/ABCDE1',
        '/join/ABC234/extra',
      ]) {
        expect(
          handle(NotificationTap(type: 'x', route: route)),
          '/',
          reason: route,
        );
      }
    });
  });

  test('defaults empty route to home', () {
    expect(handle(const NotificationTap(type: 'x', route: '')), '/');
    expect(handle(const NotificationTap(type: 'x', route: '  ')), '/');
  });

  test('keeps absolute known routes', () {
    expect(handle(const NotificationTap(type: 'x', route: '/')), '/');
    expect(
      handle(
        const NotificationTap(type: 'announcement', route: '/leaderboard'),
      ),
      '/leaderboard',
    );
    expect(handle(const NotificationTap(type: 'x', route: '/zip')), '/zip');
    expect(
      handle(const NotificationTap(type: 'x', route: '/path-words')),
      '/path-words',
    );
    expect(
      handle(const NotificationTap(type: 'x', route: '/sudoku')),
      '/sudoku',
    );
  });

  test('preserves leaderboard query params', () {
    expect(
      handle(const NotificationTap(type: 'x', route: '/leaderboard?game=zip')),
      '/leaderboard?game=zip',
    );
  });

  test('rejects non-absolute routes', () {
    expect(handle(const NotificationTap(type: 'x', route: 'zip')), '/');
  });

  test('maps common aliases to canonical routes', () {
    expect(handle(const NotificationTap(type: 'x', route: '/Home')), '/');
    expect(handle(const NotificationTap(type: 'x', route: '/home')), '/');
    expect(
      handle(const NotificationTap(type: 'x', route: '/word_match')),
      '/word-match',
    );
    expect(
      handle(const NotificationTap(type: 'x', route: '/path_words')),
      '/path-words',
    );
  });

  test('unknown absolute routes fall back to home', () {
    expect(handle(const NotificationTap(type: 'x', route: '/nope')), '/');
    expect(handle(const NotificationTap(type: 'x', route: '/results')), '/');
  });

  test('allows word-match deck deep-links', () {
    expect(
      handle(const NotificationTap(type: 'x', route: '/word-match/deck_1')),
      '/word-match/deck_1',
    );
  });
}
