/// How a review request ended (for analytics and Profile snackbars).
enum ReviewOutcome { inApp, store, failed }

abstract class AppReviewRepository {
  /// Auto prompt (Results): try in-app review, else open the store listing.
  /// Play may silently show nothing (quota, already reviewed), so `inApp`
  /// only means the card was requested.
  Future<ReviewOutcome> requestReviewOrOpenStore();

  /// Explicit ask (Profile): always the store listing, which has no quota.
  Future<ReviewOutcome> openStoreListing();

  /// Auto prompt gate: PB or streak ≥ 7, and cooldown / attempt cap allow it.
  bool shouldPromptAfterMilestone({
    required bool isPersonalBest,
    required int? streak,
  });

  /// Call after every auto attempt (in-app, store, or failed).
  Future<void> recordAutoPromptAttempt();
}
