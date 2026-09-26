import '../entities/app_user.dart';

abstract class IssueReportRepository {
  Future<void> submit({
    required String title,
    required String description,
    required AppUser user,
  });
}
