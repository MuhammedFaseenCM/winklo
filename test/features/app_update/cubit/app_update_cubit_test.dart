import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/features/app_update/cubit/app_update_cubit.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCheckAppUpdate checkAppUpdate;
  late _MockAppUpdateRepository repo;
  late MockAnalyticsRepository analytics;

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
  });

  AppUpdateCubit build() => AppUpdateCubit(
    checkAppUpdate: checkAppUpdate,
    appUpdateRepository: repo,
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

    await cubit.openStore();

    verify(() => analytics.logUpdatePromptAccepted(forced: true)).called(1);
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
