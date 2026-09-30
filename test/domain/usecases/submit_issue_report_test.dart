import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/issue_report_repository.dart';
import 'package:winklo/domain/usecases/submit_issue_report.dart';

class _MockRepo extends Mock implements IssueReportRepository {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada');
  late _MockRepo repo;
  late SubmitIssueReport submit;

  setUp(() {
    repo = _MockRepo();
    submit = SubmitIssueReport(repo);
    when(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(user);
  });

  test('trims and submits valid report', () async {
    await submit(title: '  Bug  ', description: '  Details here  ', user: user);
    verify(
      () => repo.submit(title: 'Bug', description: 'Details here', user: user),
    ).called(1);
  });

  test('empty title throws and skips repo', () async {
    expect(
      () => submit(title: '  ', description: 'x', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportTitleEmpty,
        ),
      ),
    );
    verifyNever(
      () => repo.submit(
        title: any(named: 'title'),
        description: any(named: 'description'),
        user: any(named: 'user'),
      ),
    );
  });

  test('title over 80 throws', () async {
    expect(
      () => submit(title: 'a' * 81, description: 'x', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportTitleTooLong,
        ),
      ),
    );
  });

  test('empty description throws', () async {
    expect(
      () => submit(title: 't', description: ' \n ', user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportDescriptionEmpty,
        ),
      ),
    );
  });

  test('description over 2000 throws', () async {
    expect(
      () => submit(title: 't', description: 'd' * 2001, user: user),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          AppStrings.profileReportDescriptionTooLong,
        ),
      ),
    );
  });
}
