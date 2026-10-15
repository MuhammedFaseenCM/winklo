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
