import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/features/app_update/cubit/app_update_cubit.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _MockInAppUpdates extends Mock implements InAppUpdateRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCheckAppUpdate checkAppUpdate;
  late _MockAppUpdateRepository repo;
  late MockAnalyticsRepository analytics;
  late _MockInAppUpdates inAppUpdates;

  const forced = AppUpdateDecision(
    status: AppUpdateStatus.forced,
    storeUrl: 'https://play.google.com/store/apps/details?id=x',
  );

  setUp(() {
    checkAppUpdate = _MockCheckAppUpdate();
    repo = _MockAppUpdateRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => repo.openStore(any())).thenAnswer((_) async => true);
    inAppUpdates = _MockInAppUpdates();
    when(
      () => inAppUpdates.performImmediateUpdate(),
    ).thenAnswer((_) async => InAppUpdateOutcome.accepted);
  });

  AppUpdateCubit build() => AppUpdateCubit(
    checkAppUpdate: checkAppUpdate,
    appUpdateRepository: repo,
    inAppUpdates: inAppUpdates,
    analytics: analytics,
  );

  test('the forced screen logs update_prompt_shown once', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    final cubit = build();

    await cubit.check();
    await cubit.check(); // Rechecked on every resume.

    verify(() => analytics.logUpdatePromptShown(forced: true)).called(1);
    await cubit.close();
  });

  test('tapping update on the forced screen logs it as accepted', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    final cubit = build();
    await cubit.check();

    await cubit.startUpdate();

    verify(() => analytics.logUpdatePromptAccepted(forced: true)).called(1);
    await cubit.close();
  });

  test('the forced screen starts Play\'s immediate update', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    final cubit = build();
    await cubit.check();

    await cubit.startUpdate();

    verify(() => inAppUpdates.performImmediateUpdate()).called(1);
    verifyNever(() => repo.openStore(any()));
    await cubit.close();
  });

  test('falls back to the store when Play can\'t update in place', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    when(
      () => inAppUpdates.performImmediateUpdate(),
    ).thenAnswer((_) async => InAppUpdateOutcome.unavailable);
    final cubit = build();
    await cubit.check();

    await cubit.startUpdate();

    verify(() => repo.openStore(forced.storeUrl)).called(1);
    await cubit.close();
  });

  test('saying no to Play keeps the forced screen up', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    when(
      () => inAppUpdates.performImmediateUpdate(),
    ).thenAnswer((_) async => InAppUpdateOutcome.declined);
    final cubit = build();
    await cubit.check();

    await cubit.startUpdate();

    verifyNever(() => repo.openStore(any()));
    expect(cubit.isForced, isTrue);
    await cubit.close();
  });

  test('without Play in-app updates it opens the store', () async {
    when(() => checkAppUpdate()).thenAnswer((_) async => forced);
    final cubit = AppUpdateCubit(
      checkAppUpdate: checkAppUpdate,
      appUpdateRepository: repo,
      analytics: analytics,
    );
    await cubit.check();

    await cubit.startUpdate();

    verify(() => repo.openStore(forced.storeUrl)).called(1);
    await cubit.close();
  });

  test('a soft update is left to the Home banner', () async {
    when(() => checkAppUpdate()).thenAnswer(
      (_) async => const AppUpdateDecision(
        status: AppUpdateStatus.soft,
        storeUrl: 'https://play.google.com/store/apps/details?id=x',
      ),
    );
    final cubit = build();

    await cubit.check();

    verifyNever(
      () => analytics.logUpdatePromptShown(forced: any(named: 'forced')),
    );
    await cubit.close();
  });
}
