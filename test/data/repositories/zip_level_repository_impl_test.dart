import 'package:winklo/data/repositories/zip_level_repository_impl.dart';
import 'package:winklo/domain/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchDailyLevel throws when firestore is null', () async {
    final repo = ZipLevelRepositoryImpl(firestore: null);
    await expectLater(
      () => repo.fetchDailyLevel(DateTime(2026, 9, 29)),
      throwsA(isA<DailyPuzzleUnavailable>()),
    );
  });
}
