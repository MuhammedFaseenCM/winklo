import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';
import 'package:winklo/features/profile/cubit/report_issue_cubit.dart';
import 'package:winklo/features/profile/cubit/report_issue_state.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockIssueReportRepository extends Mock
    implements IssueReportRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada');

  late _MockIssueReportRepository repo;
  late MockAnalyticsRepository analytics;

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    repo = _MockIssueReportRepository();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
  });

  ReportIssueCubit buildCubit() => ReportIssueCubit(
    submitIssueReport: SubmitIssueReport(repo),
    analytics: analytics,
    user: user,
  );

  blocTest<ReportIssueCubit, ReportIssueState>(
    'submit success',
    build: buildCubit,
    seed: () => const ReportIssueState(
      titleDraft: 'Bug',
      descriptionDraft: 'Broken button',
    ),
    setUp: () {
      when(
        () => repo.submit(
          title: any(named: 'title'),
          description: any(named: 'description'),
          user: any(named: 'user'),
        ),
      ).thenAnswer((_) async {});
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ReportIssueState(
        status: ReportIssueStatus.submitting,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
      ),
      const ReportIssueState(
        status: ReportIssueStatus.success,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
      ),
    ],
    verify: (_) {
      verify(() => analytics.logProfileReportSubmitted()).called(1);
    },
  );

  blocTest<ReportIssueCubit, ReportIssueState>(
    'empty title fails without repo',
    build: buildCubit,
    seed: () => const ReportIssueState(
      titleDraft: '',
      descriptionDraft: 'Broken button',
    ),
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ReportIssueState(
        status: ReportIssueStatus.failure,
        titleDraft: '',
        descriptionDraft: 'Broken button',
        error: AppStrings.profileReportTitleEmpty,
      ),
    ],
    verify: (_) {
      verifyNever(
        () => repo.submit(
          title: any(named: 'title'),
          description: any(named: 'description'),
          user: any(named: 'user'),
        ),
      );
      verifyNever(() => analytics.logProfileReportSubmitted());
    },
  );

  blocTest<ReportIssueCubit, ReportIssueState>(
    'repo failure emits failure with message after submitting',
    build: buildCubit,
    seed: () => const ReportIssueState(
      titleDraft: 'Bug',
      descriptionDraft: 'Broken button',
    ),
    setUp: () {
      when(
        () => repo.submit(
          title: any(named: 'title'),
          description: any(named: 'description'),
          user: any(named: 'user'),
        ),
      ).thenAnswer((_) async => throw const Failure('offline'));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ReportIssueState(
        status: ReportIssueStatus.submitting,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
      ),
      const ReportIssueState(
        status: ReportIssueStatus.failure,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
        error: 'offline',
      ),
    ],
    verify: (_) {
      verifyNever(() => analytics.logProfileReportSubmitted());
    },
  );

  blocTest<ReportIssueCubit, ReportIssueState>(
    'unexpected error uses profile report failed',
    build: buildCubit,
    seed: () => const ReportIssueState(
      titleDraft: 'Bug',
      descriptionDraft: 'Broken button',
    ),
    setUp: () {
      when(
        () => repo.submit(
          title: any(named: 'title'),
          description: any(named: 'description'),
          user: any(named: 'user'),
        ),
      ).thenAnswer((_) async => throw Exception('boom'));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ReportIssueState(
        status: ReportIssueStatus.submitting,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
      ),
      const ReportIssueState(
        status: ReportIssueStatus.failure,
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
        error: AppStrings.profileReportFailed,
      ),
    ],
    verify: (_) {
      verifyNever(() => analytics.logProfileReportSubmitted());
    },
  );

  blocTest<ReportIssueCubit, ReportIssueState>(
    'setTitle and setDescription update drafts',
    build: buildCubit,
    act: (cubit) {
      cubit.setTitle('Bug');
      cubit.setDescription('Broken button');
    },
    expect: () => [
      const ReportIssueState(titleDraft: 'Bug'),
      const ReportIssueState(
        titleDraft: 'Bug',
        descriptionDraft: 'Broken button',
      ),
    ],
  );
}
