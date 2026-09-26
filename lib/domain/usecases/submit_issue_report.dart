import '../../core/strings/app_strings.dart';
import '../entities/app_user.dart';
import '../failures.dart';
import '../repositories/issue_report_repository.dart';

class SubmitIssueReport {
  const SubmitIssueReport(this._repo);
  final IssueReportRepository _repo;

  Future<void> call({
    required String title,
    required String description,
    required AppUser user,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    if (trimmedTitle.isEmpty) {
      throw const Failure(AppStrings.profileReportTitleEmpty);
    }
    if (trimmedTitle.length > 80) {
      throw const Failure(AppStrings.profileReportTitleTooLong);
    }
    if (trimmedDescription.isEmpty) {
      throw const Failure(AppStrings.profileReportDescriptionEmpty);
    }
    if (trimmedDescription.length > 2000) {
      throw const Failure(AppStrings.profileReportDescriptionTooLong);
    }
    return _repo.submit(
      title: trimmedTitle,
      description: trimmedDescription,
      user: user,
    );
  }
}
