import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:winklo/data/repositories/share_repository_impl.dart';
import 'package:winklo/domain/failures.dart';

void main() {
  ShareRepositoryImpl answering(ShareResultStatus status) =>
      ShareRepositoryImpl(share: (_) async => ShareResult('', status));

  test('a picked app counts as shared', () async {
    expect(await answering(ShareResultStatus.success).shareText('hi'), isTrue);
  });

  test('closing the sheet is not a share', () async {
    expect(
      await answering(ShareResultStatus.dismissed).shareText('hi'),
      isFalse,
    );
  });

  test('a share replaced by another one is not a share', () async {
    expect(
      await answering(ShareResultStatus.unavailable).shareText('hi'),
      isFalse,
    );
  });

  test('passes the text to the share sheet', () async {
    ShareParams? sent;
    final repo = ShareRepositoryImpl(
      share: (params) async {
        sent = params;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await repo.shareText('Winklo Zip');
    expect(sent?.text, 'Winklo Zip');
  });

  test('a sheet that cannot open becomes a Failure', () async {
    final repo = ShareRepositoryImpl(
      share: (_) => throw PlatformException(code: 'Share failed'),
    );
    await expectLater(repo.shareText('hi'), throwsA(isA<Failure>()));
  });
}
