import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/usecases/handle_notification_tap.dart';

void main() {
  final handle = HandleNotificationTap();

  test('defaults empty route to home', () {
    expect(handle(const NotificationTap(type: 'x', route: '')), '/');
    expect(handle(const NotificationTap(type: 'x', route: '  ')), '/');
  });

  test('keeps absolute routes', () {
    expect(handle(const NotificationTap(type: 'x', route: '/')), '/');
    expect(
      handle(
        const NotificationTap(type: 'announcement', route: '/leaderboard'),
      ),
      '/leaderboard',
    );
  });

  test('rejects non-absolute routes', () {
    expect(handle(const NotificationTap(type: 'x', route: 'zip')), '/');
  });
}
