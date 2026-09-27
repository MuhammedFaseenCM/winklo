import '../entities/client_error_report.dart';

abstract class ClientErrorRepository {
  Future<void> report(ClientErrorReport report);
}
