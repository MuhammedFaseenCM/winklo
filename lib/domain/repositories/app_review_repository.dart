/// How a review request ended (for analytics and Profile snackbars).
enum ReviewOutcome { inApp, store, failed }

abstract class AppReviewRepository {
  /// Explicit ask (Profile): try in-app review, else open the store listing.
  Future<ReviewOutcome> requestReviewOrOpenStore();

  /// Auto prompt gate: PB or streak ≥ 7, and cooldown / attempt cap allow it.
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  });

  /// Call after every auto attempt (in-app, store, or failed).
  Future<void> recordAutoPromptAttempt();
}
