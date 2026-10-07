import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/activity_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivityRepositoryImpl prefs', () {
    test(
      'markRecorded / lastRecordedAt round-trip via SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = ActivityRepositoryImpl(prefs);
        expect(repo.lastRecordedAt(), isNull);
        final at = DateTime.utc(2026, 10, 5, 12);
        await repo.markRecorded(at);
        expect(repo.lastRecordedAt(), at);
      },
    );
  });

  group('ActivityRepositoryImpl when Firebase is not ready', () {
    late bool wasReady;

    setUp(() {
      wasReady = FirebaseBootstrap.isReady;
      FirebaseBootstrap.isReady = false;
    });

    tearDown(() {
      FirebaseBootstrap.isReady = wasReady;
    });

    test('recordOpen returns false when Firebase is not ready', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ActivityRepositoryImpl(prefs);
      final wrote = await repo.recordOpen(
        uid: 'u1',
        dayId: '2026-10-05',
        platform: 'android',
        at: DateTime(2026, 10, 5),
      );
      expect(wrote, isFalse);
    });
  });
}
