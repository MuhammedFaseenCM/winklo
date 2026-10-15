import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';
import 'package:winklo/features/app_update/cubit/soft_update_cubit.dart';
import 'package:winklo/features/app_update/cubit/soft_update_state.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockInAppUpdates extends Mock implements InAppUpdateRepository {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _MemorySnooze implements UpdateBannerSnoozeRepository {
  _MemorySnooze([this.until]);
  DateTime? until;

  @override
  DateTime? snoozedUntil() => until;

  @override
  Future<void> snoozeUntil(DateTime until) async => this.until = until;
}

void main() {
  const storeUrl = 'https://play.google.com/store/apps/details?id=x';
  final now = DateTime.utc(2026, 10, 15, 9);

  late _MockInAppUpdates inAppUpdates;
  late _MockAppUpdateRepository store;
  late MockAnalyticsRepository analytics;
  late _MemorySnooze snooze;

  setUp(() {
    inAppUpdates = _MockInAppUpdates();
    store = _MockAppUpdateRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    snooze = _MemorySnooze();
    when(() => store.openStore(any())).thenAnswer((_) async => true);
    when(
      () => inAppUpdates.hasDownloadedUpdate(),
    ).thenAnswer((_) async => false);
    when(
      () => inAppUpdates.completeFlexibleUpdate(),
    ).thenAnswer((_) async => true);
  });

  SoftUpdateCubit build({DateTime Function()? clock}) => SoftUpdateCubit(
    inAppUpdates: inAppUpdates,
    appUpdateRepository: store,
    snooze: snooze,
    analytics: analytics,
    clock: clock ?? () => now,
  );

  group('snooze', () {
    test('the banner shows when it was never closed', () {
      expect(build().isHidden, isFalse);
    });

    test('the banner stays hidden while an earlier snooze runs', () {
      snooze.until = now.add(const Duration(hours: 3));

      expect(build().isHidden, isTrue);
    });

    test('closing the banner hides it for 24 hours', () async {
      var clockNow = now;
      final cubit = build(clock: () => clockNow);

      await cubit.snooze();

      expect(snooze.until, now.add(const Duration(hours: 24)));
      expect(cubit.isHidden, isTrue);
      clockNow = now.add(const Duration(hours: 23, minutes: 59));
      expect(cubit.isHidden, isTrue);
      clockNow = now.add(const Duration(hours: 24));
      expect(cubit.isHidden, isFalse);
      await cubit.close();
    });
  });

  group('update', () {
    blocTest<SoftUpdateCubit, SoftUpdateState>(
      'downloads in place, then offers a restart',
      setUp: () => when(
        () => inAppUpdates.startFlexibleUpdate(),
      ).thenAnswer((_) async => InAppUpdateOutcome.downloaded),
      build: build,
      act: (cubit) => cubit.update(storeUrl),
      expect: () => const [
        SoftUpdateState(phase: SoftUpdatePhase.downloading),
        SoftUpdateState(phase: SoftUpdatePhase.readyToInstall),
      ],
      verify: (_) {
        verify(
          () => analytics.logUpdatePromptAccepted(forced: false),
        ).called(1);
        verifyNever(() => store.openStore(any()));
      },
    );

    blocTest<SoftUpdateCubit, SoftUpdateState>(
      'falls back to the store page when Play cannot update in place',
      setUp: () => when(
        () => inAppUpdates.startFlexibleUpdate(),
      ).thenAnswer((_) async => InAppUpdateOutcome.unavailable),
      build: build,
      act: (cubit) => cubit.update(storeUrl),
      expect: () => const [
        SoftUpdateState(phase: SoftUpdatePhase.downloading),
        SoftUpdateState(),
      ],
      verify: (_) => verify(() => store.openStore(storeUrl)).called(1),
    );

    blocTest<SoftUpdateCubit, SoftUpdateState>(
      'saying no in Play leaves the banner as it was',
      setUp: () => when(
        () => inAppUpdates.startFlexibleUpdate(),
      ).thenAnswer((_) async => InAppUpdateOutcome.declined),
      build: build,
      act: (cubit) => cubit.update(storeUrl),
      expect: () => const [
        SoftUpdateState(phase: SoftUpdatePhase.downloading),
        SoftUpdateState(),
      ],
      verify: (_) => verifyNever(() => store.openStore(any())),
    );

    test('taps while the update downloads are ignored', () async {
      final download = Completer<InAppUpdateOutcome>();
      when(
        () => inAppUpdates.startFlexibleUpdate(),
      ).thenAnswer((_) => download.future);
      final cubit = build();

      final first = cubit.update(storeUrl);
      await cubit.update(storeUrl);
      download.complete(InAppUpdateOutcome.downloaded);
      await first;

      verify(() => inAppUpdates.startFlexibleUpdate()).called(1);
      verify(() => analytics.logUpdatePromptAccepted(forced: false)).called(1);
      await cubit.close();
    });

    test('once downloaded, the button restarts into the update', () async {
      when(
        () => inAppUpdates.startFlexibleUpdate(),
      ).thenAnswer((_) async => InAppUpdateOutcome.downloaded);
      final cubit = build();
      await cubit.update(storeUrl);

      await cubit.update(storeUrl);

      verify(() => inAppUpdates.completeFlexibleUpdate()).called(1);
      verify(() => inAppUpdates.startFlexibleUpdate()).called(1);
      await cubit.close();
    });
  });

  blocTest<SoftUpdateCubit, SoftUpdateState>(
    'an update downloaded earlier offers the restart straight away',
    setUp: () => when(
      () => inAppUpdates.hasDownloadedUpdate(),
    ).thenAnswer((_) async => true),
    build: build,
    act: (cubit) => cubit.checkDownloaded(),
    expect: () => const [
      SoftUpdateState(phase: SoftUpdatePhase.readyToInstall),
    ],
  );

  blocTest<SoftUpdateCubit, SoftUpdateState>(
    'no earlier download leaves the banner as it was',
    build: build,
    act: (cubit) => cubit.checkDownloaded(),
    expect: () => const <SoftUpdateState>[],
  );
}
