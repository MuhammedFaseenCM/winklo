import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/failures.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/submit_issue_report.dart';
import 'report_issue_state.dart';

class ReportIssueCubit extends Cubit<ReportIssueState> {
  ReportIssueCubit({
    required this._submitIssueReport,
    required this._analytics,
    required this._user,
  }) : super(const ReportIssueState());

  final SubmitIssueReport _submitIssueReport;
  final AnalyticsRepository _analytics;
  final AppUser _user;

  void setTitle(String value) {
    emit(state.copyWith(titleDraft: value));
  }

  void setDescription(String value) {
    emit(state.copyWith(descriptionDraft: value));
  }

  Future<void> submit() async {
    final Future<void> pending;
    try {
      pending = _submitIssueReport(
        title: state.titleDraft,
        description: state.descriptionDraft,
        user: _user,
      );
    } on Failure catch (error) {
      _emitFailure(error.message);
      return;
    }

    emit(state.copyWith(status: ReportIssueStatus.submitting, error: null));
    try {
      await pending;
    } on Failure catch (error) {
      _emitFailure(error.message);
      return;
    } catch (_) {
      _emitFailure(AppStrings.profileReportFailed);
      return;
    }

    if (isClosed) return;
    emit(state.copyWith(status: ReportIssueStatus.success, error: null));
    await _analytics.logProfileReportSubmitted();
  }

  void _emitFailure(String message) {
    if (isClosed) return;
    emit(state.copyWith(status: ReportIssueStatus.failure, error: message));
  }
}
