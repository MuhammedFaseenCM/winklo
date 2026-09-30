import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/client_error_repository_impl.dart';
import 'package:winklo/domain/entities/client_error_report.dart';

void main() {
  tearDown(() {
    FirebaseBootstrap.isReady = false;
  });

  test('report is a no-op when Firebase is not ready', () async {
    FirebaseBootstrap.isReady = false;
    final repo = ClientErrorRepositoryImpl();

    await expectLater(
      repo.report(
        const ClientErrorReport(
          severity: 'error',
          source: 'handled',
          code: 'test',
          message: 'should not write',
        ),
      ),
      completes,
    );
  });

  test('buildClientErrorFields includes metadata and optional fields', () {
    final fields = buildClientErrorFields(
      report: const ClientErrorReport(
        severity: 'error',
        source: 'handled',
        code: 'google_sign_in_canceled',
        message: 'Sign-in failed',
        cause: 'GoogleSignInException',
        stack: 'stack line',
        screen: 'home',
        function: 'AuthRepositoryImpl.signInWithGoogle',
        uid: 'user-1',
      ),
      appVersion: '1.0.0',
      buildNumber: '9',
      platform: 'android',
      locale: 'en-US',
    );

    expect(fields['severity'], 'error');
    expect(fields['source'], 'handled');
    expect(fields['code'], 'google_sign_in_canceled');
    expect(fields['message'], 'Sign-in failed');
    expect(fields['cause'], 'GoogleSignInException');
    expect(fields['stack'], 'stack line');
    expect(fields['screen'], 'home');
    expect(fields['function'], 'AuthRepositoryImpl.signInWithGoogle');
    expect(fields['uid'], 'user-1');
    expect(fields['appVersion'], '1.0.0');
    expect(fields['buildNumber'], '9');
    expect(fields['platform'], 'android');
    expect(fields['locale'], 'en-US');
    expect(fields.containsKey('createdAt'), isFalse);
  });

  test('buildClientErrorFields clips oversized message', () {
    final fields = buildClientErrorFields(
      report: ClientErrorReport(
        severity: 'fatal',
        source: 'flutter',
        code: 'flutter_error',
        message: 'x' * 600,
      ),
      appVersion: '1.0.0',
      buildNumber: '1',
      platform: 'android',
    );
    expect((fields['message'] as String).length, 500);
  });
}
