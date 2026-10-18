import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/recorded_open.dart';
import 'package:winklo/domain/repositories/activity_repository.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockActivity extends Mock implements ActivityRepository {}

class _MockAnalytics extends Mock implements AnalyticsRepository {}

const _install = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const _user = AppUser(uid: 'u1', displayName: 'A');

void main() {
  late _MockAuth auth;
  late _MockActivity activity;
  late _MockAnalytics analytics;
  late RecordAppOpen usecase;

  setUpAll(() {
    registerFallbackValue(RecordedOpen(at: DateTime(2026), key: ''));
  });

  setUp(() {
    auth = _MockAuth();
    activity = _MockActivity();
    analytics = _MockAnalytics();
    usecase = RecordAppOpen(auth, activity, analytics);
    when(() => activity.installId()).thenAnswer((_) async => _install);
    when(() => activity.lastRecorded()).thenReturn(null);
    when(() => activity.markRecorded(any())).thenAnswer((_) async {});
    when(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => analytics.logAppOpen(platform: any(named: 'platform')),
    ).thenAnswer((_) async {});
  });

  void verifyNothingWritten() {
    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
    verifyNever(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    );
    verifyNever(() => activity.markRecorded(any()));
  }

  test('records a signed-in open with the install ID', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
    verify(
      () => activity.markRecorded(RecordedOpen(at: now, key: 'u:u1')),
    ).called(1);
    verify(() => analytics.logAppOpen(platform: 'android')).called(1);
  });

  test('records a guest open through the guest path', () async {
    when(() => auth.currentUser).thenReturn(null);
    final now = DateTime(2026, 10, 5, 12);

    await usecase(now: now, platform: 'ios');

    verify(
      () => activity.recordGuestOpen(
        installId: _install,
        dayId: '2026-10-05',
        platform: 'ios',
      ),
    ).called(1);
    verify(
      () => activity.markRecorded(RecordedOpen(at: now, key: 'g:$_install')),
    ).called(1);
    verify(() => analytics.logAppOpen(platform: 'ios')).called(1);
  });

  test('skips the same identity within 5 minutes on the same day', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);
    when(() => activity.lastRecorded()).thenReturn(
      RecordedOpen(at: now.subtract(const Duration(minutes: 2)), key: 'u:u1'),
    );

    await usecase(now: now, platform: 'android');

    verifyNothingWritten();
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });

  test('a sign-in right after a guest open is recorded', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);
    when(() => activity.lastRecorded()).thenReturn(
      RecordedOpen(
        at: now.subtract(const Duration(minutes: 1)),
        key: 'g:$_install',
      ),
    );

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
  });

  test('an open just past midnight counts for the new day', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 6, 0, 1);
    when(
      () => activity.lastRecorded(),
    ).thenReturn(RecordedOpen(at: DateTime(2026, 10, 5, 23, 58), key: 'u:u1'));

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-06',
        platform: 'android',
        at: now,
      ),
    ).called(1);
  });

  test('does not throttle or log when the write was skipped', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async => false);

    await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');

    verifyNever(() => activity.markRecorded(any()));
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });

  test('a failed write is swallowed and not throttled', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenThrow(Exception('offline'));

    await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');

    verifyNever(() => activity.markRecorded(any()));
  });

  group('overlapping calls', () {
    test('two at once write once; a later one runs normally', () async {
      when(() => auth.currentUser).thenReturn(_user);
      final gate = Completer<bool>();
      when(
        () => activity.recordOpen(
          uid: any(named: 'uid'),
          installId: any(named: 'installId'),
          dayId: any(named: 'dayId'),
          platform: any(named: 'platform'),
          at: any(named: 'at'),
        ),
      ).thenAnswer((_) => gate.future);
      final now = DateTime(2026, 10, 5, 12);

      final first = usecase(now: now, platform: 'android');
      final second = usecase(now: now, platform: 'android');
      gate.complete(true);
      await Future.wait([first, second]);

      verify(
        () => activity.recordOpen(
          uid: 'u1',
          installId: _install,
          dayId: '2026-10-05',
          platform: 'android',
          at: now,
        ),
      ).called(1);

      // Past the throttle, the next call is not swallowed by the old one.
      when(() => activity.lastRecorded()).thenReturn(null);
      when(
        () => activity.recordOpen(
          uid: any(named: 'uid'),
          installId: any(named: 'installId'),
          dayId: any(named: 'dayId'),
          platform: any(named: 'platform'),
          at: any(named: 'at'),
        ),
      ).thenAnswer((_) async => true);
      await usecase(now: now.add(const Duration(minutes: 10)));
      verify(
        () => activity.recordOpen(
          uid: any(named: 'uid'),
          installId: any(named: 'installId'),
          dayId: any(named: 'dayId'),
          platform: any(named: 'platform'),
          at: any(named: 'at'),
        ),
      ).called(1);
    });

    test('a failed call does not block the next one', () async {
      when(() => auth.currentUser).thenReturn(null);
      var calls = 0;
      when(
        () => activity.recordGuestOpen(
          installId: any(named: 'installId'),
          dayId: any(named: 'dayId'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return true;
      });

      await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');
      await usecase(now: DateTime(2026, 10, 5, 12, 1), platform: 'ios');
      expect(calls, 2);
    });
  });
}
