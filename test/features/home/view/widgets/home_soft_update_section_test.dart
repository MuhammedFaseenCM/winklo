import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';
import 'package:winklo/features/home/view/widgets/home_soft_update_section.dart';

import '../../../../helpers/mock_analytics_repository.dart';

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

  late _MockInAppUpdates inAppUpdates;
  late _MockAppUpdateRepository store;
  late MockAnalyticsRepository analytics;

  setUp(() {
    inAppUpdates = _MockInAppUpdates();
    store = _MockAppUpdateRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => store.openStore(any())).thenAnswer((_) async => true);
    when(
      () => inAppUpdates.hasDownloadedUpdate(),
    ).thenAnswer((_) async => false);
  });

  Future<void> pump(WidgetTester tester, _MemorySnooze snooze) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<InAppUpdateRepository>.value(value: inAppUpdates),
          RepositoryProvider<AppUpdateRepository>.value(value: store),
          RepositoryProvider<UpdateBannerSnoozeRepository>.value(value: snooze),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeSoftUpdateSection(
                currentLabel: '1.0.0+18',
                requiredLabel: '1.1.0+19',
                storeUrl: storeUrl,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the banner', (tester) async {
    await pump(tester, _MemorySnooze());

    expect(find.text(AppStrings.updateAvailableTitle), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
  });

  testWidgets('stays hidden while snoozed', (tester) async {
    await pump(
      tester,
      _MemorySnooze(DateTime.now().add(const Duration(hours: 2))),
    );

    expect(find.text(AppStrings.updateAvailableTitle), findsNothing);
  });

  testWidgets('the close button hides it for a day', (tester) async {
    final snooze = _MemorySnooze();
    await pump(tester, snooze);

    await tester.tap(find.byTooltip(AppStrings.updateSnooze));
    await tester.pump();

    expect(find.text(AppStrings.updateAvailableTitle), findsNothing);
    expect(
      snooze.until!.difference(DateTime.now()).inMinutes,
      closeTo(24 * 60, 1),
    );
  });

  testWidgets('Update downloads in place, then offers the restart', (
    tester,
  ) async {
    when(
      () => inAppUpdates.startFlexibleUpdate(),
    ).thenAnswer((_) async => InAppUpdateOutcome.downloaded);
    await pump(tester, _MemorySnooze());

    await tester.tap(find.text(AppStrings.updateNow));
    await tester.pump();

    expect(find.text(AppStrings.updateRestart), findsOneWidget);
    verifyNever(() => store.openStore(any()));
  });

  testWidgets('without Play, Update opens the store page', (tester) async {
    when(
      () => inAppUpdates.startFlexibleUpdate(),
    ).thenAnswer((_) async => InAppUpdateOutcome.unavailable);
    await pump(tester, _MemorySnooze());

    await tester.tap(find.text(AppStrings.updateNow));
    await tester.pump();

    verify(() => store.openStore(storeUrl)).called(1);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
  });

  testWidgets('an earlier download offers the restart straight away', (
    tester,
  ) async {
    when(
      () => inAppUpdates.hasDownloadedUpdate(),
    ).thenAnswer((_) async => true);

    await pump(tester, _MemorySnooze());

    expect(find.text(AppStrings.updateRestart), findsOneWidget);
  });
}
