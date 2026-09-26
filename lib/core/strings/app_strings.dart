abstract final class AppStrings {
  static const appTitle = 'Winklo';

  // Home
  static const homeTagline = 'Quick solo mini-games.';
  static const zipTitle = 'Zip';
  static const zipTagline =
      'Start at 1. Fill every cell. Finish on the last number.';
  static const playTodaysZip = "Play today's Zip";
  static const zipUndo = 'Undo';
  static const zipClear = 'Clear';
  static const zipHint = 'Hint';
  static String zipHintWithCount(int n) => 'Hint ($n)';
  static const zipHowToPlayTitle = 'How to play';
  static const zipTutorialStart = 'Start at 1';
  static const zipTutorialFinish = 'Finish on the last number';
  static const zipTutorialFillEveryCell = 'Fill every cell';
  static const zipTutorialWalls = 'Walls block the path';
  static const zipHowToPlayGotIt = 'Got it';
  static const tutorialGotIt = 'Got it';
  static const tutorialSkip = 'Skip';
  static const tutorialNext = 'Next';
  static const zipTipStartAtOne = 'Start at 1';
  static const zipTipFillEveryCell = 'Fill every cell before you finish';
  static const zipTipFinishOnLast = 'Finish on the last number';
  static const zipTipVisitInOrder = 'Visit the numbers in order';
  static const zipClearedTitle = 'Puzzle cleared!';
  static const playAgain = 'Play again';
  static const result = 'Result';
  static const comeBackTomorrow = 'Come back tomorrow';
  static const today = 'TODAY';
  static const wordMatch = 'Word Match';
  static const categoryRace = 'Category Race';
  static const streakProtectedLabel = 'Streak protected';
  static const cleared = 'Cleared';
  static String bestTimeLabel(String formatted) => 'Best $formatted';

  // Path Words
  static const pathWordsTitle = 'Path Words';
  static const pathWordsTagline = 'Trace every word across the grid.';
  static const playTodaysPathWords = "Play today's Path Words";
  static const pathWordsUndo = 'Undo';
  static const pathWordsHint = 'Hint';
  static String pathWordsHintWithCount(int n) => 'Hint ($n)';
  static const pathWordsHowToPlayTitle = 'How to play';
  static const pathWordsTutorialMatchList = 'Match a word on the list';
  static const pathWordsTutorialFindEveryWord = 'Find every word';
  static const pathWordsTutorialFillEveryCell = 'Every cell should fill';
  static const pathWordsHowToPlayGotIt = 'Got it';
  static const pathWordsTipMatchList =
      'That path isn’t on the list — match a listed word';
  static String pathWordsUnfoundWordLabel(int letterCount) =>
      '$letterCount-letter word, not found yet';
  static String pathWordsTracingWordLabel(String letters) =>
      'Tracing ${letters.toUpperCase()}';
  static const pathWordsClearedTitle = 'Puzzle cleared!';
  static const pathWordsLoading = 'Building today’s puzzle…';
  static const pathWordsFailed = 'Could not load today’s puzzle.';
  static const retry = 'Retry';

  // Results
  static const newPersonalBest = 'New personal best';
  static const newPuzzleUnlocksTomorrow = 'A new puzzle unlocks tomorrow.';
  static const backHome = 'Back home';

  // Zip game branding (feature, not app title)
  static const zipBrand = 'ZIP';

  static String streakLabel(int days) {
    if (days == 1) return '1-day streak';
    return '$days-day streak';
  }

  static String longestStreakLabel(int days) {
    return 'Best: $days';
  }

  // Force update / soft update
  static const updateRequiredTitle = 'Update required';
  static const updateAvailableTitle = 'Update available';
  static const updateRequiredBody =
      'A new version of Winklo is required to continue. Please update from the Play Store.';
  static const updateAvailableBody =
      'A new version of Winklo is available. Please update for the latest fixes and puzzles.';
  static const updateNow = 'Update now';
  static const updateCantSkip = "This update can't be skipped.";

  static String updateVersionRow(String current, String requiredLabel) {
    return '$current → $requiredLabel';
  }

  // Auth / leaderboard
  static const signInTitle = 'Sign in to view rankings';
  static const signInBody =
      'Play Zip and Path Words anytime. Sign in with Google to join the live leaderboard.';
  static const signInWithGoogle = 'Continue with Google';
  static const signInCancel = 'Not now';
  static const signInRequired = 'Sign in to view rankings';
  static const signOut = 'Sign out';
  static const signOutConfirmTitle = 'Sign out?';
  static const signOutConfirmBody =
      'You’ll need to sign in again to view the live leaderboard.';
  static const signOutConfirmCancel = 'Cancel';
  static const leaderboardTitle = 'Leaderboard';
  static const leaderboardDaily = 'Daily';
  static const leaderboardAllTime = 'All-time';
  static const leaderboardEmpty = 'No scores yet. Be the first!';
  static const leaderboardFailed = 'Could not load the leaderboard.';
  static const leaderboardSignInHint = 'Sign in to view live rankings.';
  static const seeFullLeaderboard = 'See full leaderboard';
  static const leaderboardGapEllipsis = '…';
  static const youLabel = 'You';

  // Notifications
  static const notifDailyReadyTitle = 'Today’s puzzles are ready';
  static const notifDailyReadyBody =
      'Play Zip and Path Words to keep your streak going.';
  static const notifStreakAtRiskTitle = 'Streak at risk';
  static const notifStreakAtRiskBody =
      'You haven’t finished today’s puzzles yet. Play before midnight.';

  // Dashboard nav
  static const navHome = 'Home';
  static const navLeaderboard = 'Leaderboard';
  static const navProfile = 'Profile';

  // Profile
  static const profileTitle = 'Profile';
  static const profileSignedOutTitle = 'Your profile';
  static const profileSignedOutBody =
      'Sign in to set your name and avatar for the leaderboard.';
  static const profileEditName = 'Display name';
  static const profileNameHint = 'Enter a display name';
  static const profileNameEmpty = 'Name can’t be empty.';
  static const profileNameTooLong = 'Name must be 24 characters or fewer.';
  static const profileSave = 'Save';
  static const profileEditAvatar = 'Edit avatar';
  static const profileChoosePhoto = 'Choose from photos';
  static const profilePresets = 'Presets';
  static const profileSaveFailed = 'Could not save profile. Try again.';
  static const profileUploadFailed = 'Could not upload photo. Try again.';
  static const profilePermissionDenied =
      'Photo access was denied. Enable it in Settings to upload an avatar.';
  static const profileEditDisplayName = 'Edit display name';
  static const profilePrivacyPolicy = 'Privacy policy';
  static const profileAboutGame = 'About the game';
  static const profileReportIssue = 'Report an issue';
  static const profileAboutBody =
      'Winklo is a daily puzzle app with solo mini-games like Zip and Path Words. '
      'Clear today’s puzzles, climb the leaderboard, and keep your streak going.';
  static String profileAboutVersion(String version) => 'Version $version';
  static const profileReportTitleLabel = 'Title';
  static const profileReportTitleHint = 'Short summary';
  static const profileReportDescriptionLabel = 'Description';
  static const profileReportDescriptionHint =
      'What went wrong or what you’d like to see?';
  static const profileReportTitleEmpty = 'Title can’t be empty.';
  static const profileReportTitleTooLong =
      'Title must be 80 characters or fewer.';
  static const profileReportDescriptionEmpty = 'Description can’t be empty.';
  static const profileReportDescriptionTooLong =
      'Description must be 2000 characters or fewer.';
  static const profileReportSend = 'Send';
  static const profileReportSent = 'Thanks — your report was sent.';
  static const profileReportFailed = 'Could not send report. Try again.';
  static const profilePrivacyFailed = 'Could not load the privacy policy.';
  static const profilePrivacyRetry = 'Retry';
}
