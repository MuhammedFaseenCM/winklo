import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/app_review_repository_impl.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late bool available;
  late bool reviewThrows;
  late bool launchOk;
  late int reviewCalls;
  late int launchCalls;
  late AppReviewRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 10, 18);
    available = true;
    reviewThrows = false;
    launchOk = true;
    reviewCalls = 0;
    launchCalls = 0;
    repo = AppReviewRepositoryImpl(
      prefs: prefs,
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
      clock: () => now,
      isReviewAvailable: () async => available,
      requestReview: () async {
        reviewCalls++;
        if (reviewThrows) throw StateError('no');
      },
      openStoreUrl: (url) async {
        launchCalls++;
        return launchOk;
      },
    );
  });

  group('shouldPromptAfterMilestone', () {
    test('false when neither PB nor streak >= 7', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: false, streak: 6),
        isFalse,
      );
    });

    test('true for PB when never asked', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 0),
        isTrue,
      );
    });

    test('true for streak 7', () {
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: false, streak: 7),
        isTrue,
      );
    });

    test('false within 30 days after an attempt', () async {
      await repo.recordAutoPromptAttempt();
      now = now.add(const Duration(days: 29));
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 7),
        isFalse,
      );
    });

    test('true again after 30 days', () async {
      await repo.recordAutoPromptAttempt();
      now = now.add(const Duration(days: 30));
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: null),
        isTrue,
      );
    });

    test('false forever after 3 attempts', () async {
      for (var i = 0; i < 3; i++) {
        await repo.recordAutoPromptAttempt();
        now = now.add(const Duration(days: 31));
      }
      expect(
        repo.shouldPromptAfterMilestone(isPersonalBest: true, streak: 99),
        isFalse,
      );
    });
  });

  group('requestReviewOrOpenStore', () {
    test('inApp when available', () async {
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.inApp);
      expect(reviewCalls, 1);
      expect(launchCalls, 0);
    });

    test('store when unavailable', () async {
      available = false;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.store);
      expect(launchCalls, 1);
    });

    test('store when requestReview throws', () async {
      reviewThrows = true;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.store);
    });

    test('failed when store launch fails', () async {
      available = false;
      launchOk = false;
      expect(await repo.requestReviewOrOpenStore(), ReviewOutcome.failed);
    });

    test('empty store URL uses default package URL', () async {
      available = false;
      final emptyUrlRepo = AppReviewRepositoryImpl(
        prefs: prefs,
        playStoreUrl: '  ',
        clock: () => now,
        isReviewAvailable: () async => false,
        requestReview: () async {},
        openStoreUrl: (url) async {
          expect(
            url,
            'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
          );
          return true;
        },
      );
      expect(
        await emptyUrlRepo.requestReviewOrOpenStore(),
        ReviewOutcome.store,
      );
    });
  });
}
