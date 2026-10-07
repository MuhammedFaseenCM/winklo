import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';

void main() {
  test('GenerateDailyPathWords throws when firestore is null', () async {
    final usecase = GenerateDailyPathWords(firestore: null);
    await expectLater(
      () => usecase(day: DateTime(2026, 9, 17)),
      throwsA(isA<DailyPuzzleUnavailable>()),
    );
  });
}
