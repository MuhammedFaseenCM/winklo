abstract final class AppStrings {
  static const appTitle = 'Winklo';

  // Home
  static const homeTagline = 'Quick solo mini-games.';
  static const zipTitle = 'Zip';
  static const zipTagline = 'Fill every cell from 1 to the finish.';
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
  static const zipLoading = 'Building today’s puzzle…';
  static const zipFailed = 'Could not load today’s puzzle.';
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

  // Sudoku
  static const sudokuTitle = 'Sudoku';
  static const sudokuTagline = 'Fill every cell with 1–6.';
  static const playTodaysSudoku = "Play today's Sudoku";
  static const sudokuHint = 'Hint';
  static String sudokuHintWithCount(int n) => 'Hint ($n)';
  static const sudokuHintUnitRegion = 'region';
  static const sudokuHintUnitRow = 'row';
  static const sudokuHintUnitColumn = 'column';
  static String sudokuHintLastRemaining({
    required int digit,
    required String unit,
  }) =>
      'This cell has to be $digit due to all other cells in this $unit being blocked by other ${digit}s.';
  static String sudokuHintNakedSingle({required int digit}) =>
      'This cell has to be $digit — every other digit conflicts with the row, column, or region.';
  static const sudokuHintNoSimple = 'No simple hint right now.';
  static String sudokuHintMistakeInRow(int row) =>
      'One of the digits in row $row is wrong. Fix it first, then ask for another hint.';
  static const sudokuErase = 'Erase';
  static const sudokuReset = 'Reset';
  static const sudokuNotes = 'Notes';
  static const sudokuHowToPlayTitle = 'How to play';
  static const sudokuHowToPlayBody =
      'Fill every empty cell with 1–6 so each row, column, and 2×3 box has every digit once. Wrong entries are rejected. Notes are unlimited; you get 3 hints per day.';
  static const sudokuHowToPlayGotIt = 'Got it';
  static const sudokuClearedTitle = 'Puzzle cleared!';
  static const sudokuLoading = 'Building today’s puzzle…';
  static const sudokuFailed = 'Could not load today’s puzzle.';
  static const sudokuDifficultyEasy = 'Easy';
  static const sudokuDifficultyMedium = 'Medium';
  static const sudokuDifficultyHard = 'Hard';

  // Results
  static const newPersonalBest = 'New personal best';
  static const newPuzzleUnlocksTomorrow = 'A new puzzle unlocks tomorrow.';
  static const backHome = 'Back home';
  static const resultsTimeLabel = 'time';

  static String formatPlayTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String saveTimeToBoard(String timeLabel) =>
      'Save $timeLabel to today’s board';

  static const saveTimeSignInTitle = 'Save your time';
  static const saveTimeSignInBody =
      'Sign in with Google to put this run on the live daily leaderboard.';
  static const resultsBoardTeaseHint =
      'Today’s board is live — tap to save your time and join.';

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
  static const playSignInTitle = 'Sign in to play';
  static const playSignInBody =
      'Sign in with Google to play today’s puzzles and save your time on the board.';
  static const signInTitle = 'Sign in to join the board';
  static const signInBody =
      'Browse live rankings anytime. Sign in with Google to play and save your scores.';
  static const signInWithGoogle = 'Continue with Google';
  static const signInCancel = 'Not now';
  static const signInRequired = 'Sign in to join the board';
  static const signOut = 'Sign out';
  static const signOutConfirmTitle = 'Sign out?';
  static const signOutConfirmBody =
      'You’ll need to sign in again to play. You can still view the live leaderboard signed out.';
  static const signOutConfirmCancel = 'Cancel';
  static const signOutConfirmNote =
      'Your streaks & stats stay safe in the cloud.';
  static const deleteAccount = 'Delete account';
  static const deleteAccountConfirmTitle = 'Delete your account?';
  static const deleteAccountConfirmBody =
      'You’ll finish on our website: sign in there with the same Google account and confirm. Your profile, leaderboard entries and synced progress are deleted for good.';
  static const deleteAccountConfirmNote =
      'We’ll sign you out here first, then open the page in your browser.';
  static const deleteAccountConfirmContinue = 'Continue';
  static const deleteAccountOpenFailed =
      'Couldn’t open your browser. Visit winklo.pages.dev/delete-account to delete your account.';
  static const leaderboardTitle = 'Leaderboard';
  static const leaderboardDaily = 'Daily';
  static const leaderboardAllTime = 'All-time';
  static const leaderboardEmpty = 'No scores yet. Be the first!';
  static const leaderboardFailed = 'Could not load the leaderboard.';
  static const leaderboardSignInHint = 'Sign in to view live rankings.';
  static const seeFullLeaderboard = 'See full leaderboard';
  static const leaderboardGapEllipsis = '…';
  static const youLabel = 'You';
  static const leaderboardNoHintChip = 'Hint-free';
  static const leaderboardNoMistakesChip = 'Flawless';

  /// Compact game-tab label (full title stays [pathWordsTitle]).
  static const pathWordsTab = 'Path';

  // Notifications
  static const notifDailyReadyTitle = 'Today’s puzzles are ready';
  static const notifDailyReadyBody =
      'Play Zip, Path Words and Sudoku to keep your streaks going.';
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
  static const profilePhotoTooLarge =
      'That photo is too large to upload (2 MB at most). Try another one.';
  static const profileUploadFailed = 'Could not upload photo. Try again.';
  static const profilePermissionDenied =
      'Photo access was denied. Enable it in Settings to upload an avatar.';
  static const profileEditDisplayName = 'Edit display name';
  static const profileSoundEffects = 'Sound effects';
  static const profilePrivacyPolicy = 'Privacy policy';
  static const profileAboutGame = 'About the game';
  static const profileReportIssue = 'Report an issue';
  static const profileAboutBody =
      'Winklo is a daily puzzle app with solo mini-games you can clear at your own pace.';
  static const profileAboutGamesHeading = 'Games';
  static const profileAboutDailyHeading = 'Daily play';
  static const profileAboutDailyBody =
      'Each day brings fresh puzzles for Zip, Path Words, and Sudoku. '
      'Clear them to climb the leaderboard and keep your streak alive.';
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
