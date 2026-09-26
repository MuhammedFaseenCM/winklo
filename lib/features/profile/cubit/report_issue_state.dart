import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_issue_state.freezed.dart';

enum ReportIssueStatus { idle, submitting, success, failure }

@freezed
sealed class ReportIssueState with _$ReportIssueState {
  const factory ReportIssueState({
    @Default(ReportIssueStatus.idle) ReportIssueStatus status,
    @Default('') String titleDraft,
    @Default('') String descriptionDraft,
    String? error,
  }) = _ReportIssueState;
}
