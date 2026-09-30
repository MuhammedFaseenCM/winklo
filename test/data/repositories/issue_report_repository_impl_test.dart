import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/issue_report_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';

void main() {
  group('IssueReportRepositoryImpl when Firebase is not ready', () {
    late bool wasReady;
    late IssueReportRepositoryImpl repo;

    setUp(() {
      wasReady = FirebaseBootstrap.isReady;
      FirebaseBootstrap.isReady = false;
      repo = IssueReportRepositoryImpl();
    });

    tearDown(() {
      FirebaseBootstrap.isReady = wasReady;
    });

    test('submit throws Failure', () async {
      await expectLater(
        repo.submit(
          title: 'Crash',
          description: 'The board froze.',
          user: const AppUser(uid: 'u1', displayName: 'Ada'),
        ),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.message,
            'message',
            'Firebase is unavailable. Try again later.',
          ),
        ),
      );
    });
  });
}
