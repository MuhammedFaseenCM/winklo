import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/errors/client_error_reporter.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/repositories/client_error_repository.dart';

class _RecordingRepo implements ClientErrorRepository {
  final reports = <ClientErrorReport>[];

  @override
  Future<void> report(ClientErrorReport report) async {
    reports.add(report);
  }
}

void main() {
  setUp(() {
    ClientErrorReporter.allowInDebug = true;
  });

  tearDown(() {
    FirebaseBootstrap.isReady = false;
    ClientErrorReporter.allowInDebug = false;
    ClientErrorReporter.install(
      ClientErrorReporter(repository: _RecordingRepo(), maxWritesPerSession: 0),
    );
  });

  test('throttle skips duplicate keys within cooldown', () async {
    FirebaseBootstrap.isReady = true;
    final repo = _RecordingRepo();
    final reporter = ClientErrorReporter(
      repository: repo,
      maxWritesPerSession: 20,
      dedupeCooldown: const Duration(seconds: 60),
    );

    reporter.reportHandled(code: 'x', message: 'same', function: 'fn');
    reporter.reportHandled(code: 'x', message: 'same', function: 'fn');

    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(1));
  });

  test('session cap stops further writes', () async {
    FirebaseBootstrap.isReady = true;
    final repo = _RecordingRepo();
    final reporter = ClientErrorReporter(
      repository: repo,
      maxWritesPerSession: 2,
      dedupeCooldown: Duration.zero,
    );

    reporter.reportHandled(code: 'a', message: '1');
    reporter.reportHandled(code: 'b', message: '2');
    reporter.reportHandled(code: 'c', message: '3');

    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(2));
  });
}
