import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';

class MockAppReviewRepository extends Mock implements AppReviewRepository {}

/// Default for results widget tests: no auto prompt during pumpAndSettle.
void stubAppReviewNoAutoPrompt(MockAppReviewRepository review) {
  when(
    () => review.shouldPromptAfterMilestone(
      isPersonalBest: any(named: 'isPersonalBest'),
      streak: any(named: 'streak'),
    ),
  ).thenReturn(false);
  when(
    () => review.requestReviewOrOpenStore(),
  ).thenAnswer((_) async => ReviewOutcome.inApp);
  when(() => review.recordAutoPromptAttempt()).thenAnswer((_) async {});
}
