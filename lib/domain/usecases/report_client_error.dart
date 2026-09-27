import '../entities/client_error_report.dart';
import '../repositories/client_error_repository.dart';

class ReportClientError {
  const ReportClientError(this._repo);

  final ClientErrorRepository _repo;

  Future<void> call(ClientErrorReport report) => _repo.report(report);
}
