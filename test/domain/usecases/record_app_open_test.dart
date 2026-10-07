import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/activity_repository.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockActivity extends Mock implements ActivityRepository {}

class _MockAnalytics extends Mock implements AnalyticsRepository {}

void main() {
  late _MockAuth auth;
  late _MockActivity activity;
  late _MockAnalytics analytics;
  late RecordAppOpen usecase;

  setUp(() {
    auth = _MockAuth();
    activity = _MockActivity();
    analytics = _MockAnalytics();
    usecase = RecordAppOpen(auth, activity, analytics);
    when(() => activity.markRecorded(any())).thenAnswer((_) async {});
    when(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => analytics.logAppOpen(platform: any(named: 'platform')),
    ).thenAnswer((_) async {});
  });

  test('no-ops when signed out', () async {
    when(() => auth.currentUser).thenReturn(null);
    await usecase(now: DateTime(2026, 10, 5, 12));
    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
  });

  test('records open and analytics when signed in', () async {
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'A'));
    when(() => activity.lastRecordedAt()).thenReturn(null);

    final now = DateTime(2026, 10, 5, 12, 0);
    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
    verify(() => activity.markRecorded(now)).called(1);
    verify(() => analytics.logAppOpen(platform: 'android')).called(1);
  });

  test('skips when within 5 minute throttle', () async {
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'A'));
    final now = DateTime(2026, 10, 5, 12, 0);
    when(
      () => activity.lastRecordedAt(),
    ).thenReturn(now.subtract(const Duration(minutes: 2)));

    await usecase(now: now, platform: 'android');

    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
    verifyNever(() => activity.markRecorded(any()));
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });

  test('does not throttle or log FA when Firestore write is skipped', () async {
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'A'));
    when(() => activity.lastRecordedAt()).thenReturn(null);
    when(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async => false);

    await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');

    verifyNever(() => activity.markRecorded(any()));
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });
}
