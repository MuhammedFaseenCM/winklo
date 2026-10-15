import '../../domain/game_ids.dart';
import '../../domain/habit/weekly_recap.dart';

abstract final class AppStrings {
  static const appTitle = 'Winklo';

  // Home
  static const homeTagline = 'Quick solo mini-games.';
  static const zipTitle = 'Zip';
  static const zipTagline = 'Fill every cell from 1 to the finish.';
  static const playTodaysZip = "Play today's Zip";
  static const zipUndo = 'Undo';
  static const zipClear = 'Clear';
  static const zipReplay = 'Replay';
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
  static const today = 'TODAY';
  static const wordMatch = 'Word Match';
  static const categoryRace = 'Category Race';
  static const streakProtectedLabel = 'Streak protected';
  static const cleared = 'Cleared';
  static String bestTimeLabel(String formatted) => 'Best $formatted';
  static const streakFreezeReady =
      'Streak freeze ready: miss one day and your streak carries on.';

  /// "Best 0:48 · Longest streak 9" under a Home tile's title; empty when
  /// there is nothing to show yet. Streaks count from 2 days, as on the
  /// leaderboard.
  static String homeTileStats({int? bestSeconds, int longestStreak = 0}) => [
    if (bestSeconds != null) bestTimeLabel(formatPlayTime(bestSeconds)),
    if (longestStreak >= 2) longestStreakLabel(longestStreak),
  ].join(' · ');

  /// "2 of 3 cleared · 3:41 total" above the Home tiles.
  static String homeTodaySummary({
    required int cleared,
    required int total,
    int? totalSeconds,
  }) => [
    '$cleared of $total cleared',
    if (totalSeconds != null) '${formatPlayTime(totalSeconds)} total',
  ].join(' · ');
  static const homePerfectDayBadge = 'Perfect day';

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
  static String pathWordsThemeReveal(String theme) => 'Today: $theme';
  static String pathWordsBonusWord(String word) =>
      'Bonus word: ${word.toUpperCase()}';
  static String pathWordsBonusCount(int count) =>
      count == 1 ? '1 bonus word' : '$count bonus words';
  static const pathWordsTapForMeaning = 'Tap a word to see what it means';
  static String pathWordsWordWithMeaningLabel(String word) =>
      '${word.toUpperCase()}, tap for its meaning';
  static const weekendSpecial = 'Weekend special';
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
      'Fill every empty cell with 1–6 so each row, column and 2×3 box has every digit once. You can enter any digit; a full row, column or box that’s wrong lights up. Notes are unlimited. You get 3 hints per puzzle: each points out a wrong digit or explains the next step, and never fills a cell for you.';
  static const sudokuHowToPlayGotIt = 'Got it';
  static const sudokuClearedTitle = 'Puzzle cleared!';
  static const sudokuLoading = 'Building today’s puzzle…';
  static const sudokuFailed = 'Could not load today’s puzzle.';
  static const puzzleNeedsUpdate =
      'Today’s puzzle needs a newer version of Winklo. Update the app to play it.';
  static const sudokuDifficultyEasy = 'Easy';
  static const sudokuDifficultyMedium = 'Medium';
  static const sudokuDifficultyHard = 'Hard';

  // Results
  static const newPersonalBest = 'New personal best';
  static const newPuzzleUnlocksTomorrow = 'A new puzzle unlocks tomorrow.';
  static const newPuzzleReady = 'A new puzzle is ready';

  /// "New puzzle in 6h 12m". Minutes round up, so the last minute reads 1m
  /// rather than 0m.
  static String newPuzzleIn(Duration remaining) {
    if (remaining <= Duration.zero) return newPuzzleReady;
    const minute = Duration.microsecondsPerMinute;
    final minutes = (remaining.inMicroseconds + minute - 1) ~/ minute;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final parts = [if (h > 0) '${h}h', if (m > 0 || h == 0) '${m}m'];
    return 'New puzzle in ${parts.join(' ')}';
  }

  static const backHome = 'Back home';
  static String playNextGame(String gameTitle) => 'Play $gameTitle next';
  static const perfectDay = 'Perfect day! All three puzzles cleared.';
  static const shareResult = 'Share';
  static const shareFailed = 'Couldn’t open sharing. Try again.';
  static const resultsFullBoard = 'Full board';
  static String clearedIn(String time) => 'Cleared in $time';
  static String rankToday(int rank) => '#$rank today';
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

  static String longestStreakLabel(int days) => 'Longest streak $days';

  // Stats
  static const statsTitle = 'Stats';
  static const statsProfileRow = 'Your stats';
  static const statsProfileRowHint = 'Times, streaks and cleared days';
  static const statsFailed = 'Could not load your stats.';
  static const statsLocalOnly =
      'Showing this phone’s clears only. Pull down to try again.';
  static const statsClears = 'Clears';
  static const statsCurrentStreak = 'Streak';
  static const statsLongestStreak = 'Longest';
  static const statsBestTime = 'Best';
  static const statsAverageTime = 'Average';
  static const statsHintFree = 'Hint-free';
  static const statsNoValue = '–';
  static String statsPercent(double share) => '${(share * 100).round()}%';
  static const statsTimesTitle = 'Clear times';
  static const statsTimesEmpty = 'Clear a puzzle to see your times here.';

  /// Lower edge of a histogram bar; the open-ended last bar reads "4:00+".
  static String statsTimesBucket(int fromSeconds, {required bool open}) =>
      open ? '${formatPlayTime(fromSeconds)}+' : formatPlayTime(fromSeconds);
  static String statsTimesBucketSemantics(
    int fromSeconds,
    int? toSeconds,
    int count,
  ) {
    final range = toSeconds == null
        ? '${formatPlayTime(fromSeconds)} or more'
        : '${formatPlayTime(fromSeconds)} to ${formatPlayTime(toSeconds)}';
    return '$range: ${statsClearCount(count)}';
  }

  static String statsClearCount(int count) =>
      count == 1 ? '1 clear' : '$count clears';
  static const statsCalendarTitle = 'Cleared days';
  static const statsCalendarEmpty = 'Your cleared days will show here.';
  static String statsCalendarCleared(int days) =>
      days == 1 ? '1 day cleared' : '$days days cleared';
  static const statsCalendarPrevious = 'Previous month';
  static const statsCalendarNext = 'Next month';
  static const statsTrendTitle = 'Personal best trend';
  static const statsTrendSubtitle = 'Last 30 days';
  static const statsTrendEmpty =
      'Clear a puzzle in the next few days to start your trend.';
  static const statsTrendTimes = 'Clear time';
  static const statsTrendBest = 'Personal best';
  static const statsTrendToday = 'Today';
  static String statsTrendSemantics({
    required int clears,
    required int? bestSeconds,
  }) => [
    'Last 30 days: ${statsClearCount(clears)}',
    if (bestSeconds != null) 'personal best ${formatPlayTime(bestSeconds)}',
  ].join(', ');

  // Achievements
  static const achievementsTitle = 'Badges';
  static String achievementsProgress(int unlocked, int total) =>
      '$unlocked of $total';
  static const achievementLocked = 'Locked';
  static String achievementFirstClearTitle(String game) => 'First $game';
  static String achievementFirstClearCondition(String game) =>
      'Clear your first $game';
  static String achievementStreakTitle(int days, String game) =>
      '$days-day $game streak';
  static String achievementStreakCondition(int days, String game) =>
      'Clear $game $days days in a row';
  static const achievementZipUnderMinuteTitle = 'Under a minute';
  static const achievementZipUnderMinuteCondition =
      'Clear a Zip in under a minute';
  static const achievementHintFreeWeekTitle = 'Hint-free week';
  static const achievementHintFreeWeekCondition =
      'Clear one game 7 days in a row without hints';
  static const achievementFlawlessSudokusTitle = 'Flawless ten';
  static const achievementFlawlessSudokusCondition =
      'Clear 10 Sudokus with no hints or mistakes';
  static const achievementPerfectDayTitle = 'Perfect day';
  static const achievementPerfectDayCondition =
      'Clear all three games on the same day';
  static String newAchievementsTitle(int count) =>
      count == 1 ? 'New badge unlocked' : '$count new badges unlocked';

  /// "First Zip", "First Zip and Perfect day", "First Zip, Perfect day and
  /// 2 more".
  static String newAchievementsList(List<String> titles) {
    if (titles.length <= 1) return titles.join();
    if (titles.length == 2) return '${titles[0]} and ${titles[1]}';
    return '${titles[0]}, ${titles[1]} and ${titles.length - 2} more';
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
  static const updateSnooze = 'Hide for a day';
  static const updateDownloading = 'Downloading…';
  static const updateRestart = 'Restart to update';

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

  // Leaderboard: past days, the weekly board and leagues (roadmap area C)
  static const leaderboardThisWeek = 'This week';
  static const leaderboardToday = 'Today';
  static const leaderboardYesterday = 'Yesterday';
  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String leaderboardShortDate(int day, int month) =>
      '$day ${_shortMonths[month - 1]}';
  static String leaderboardDaysCleared(int days) =>
      days == 1 ? '1 day' : '$days days';
  static String leaderboardWeeklyRow(int days, String time) =>
      '${leaderboardDaysCleared(days)} · $time';
  static const leaderboardPastDayEmpty = 'No times on this day.';
  static const leaderboardWeeklyEmpty =
      'No one has cleared a day this week yet.';
  static const leaderboardWeeklyDebugNote =
      'The server fills in the weekly board, so debug builds show it empty.';
  static const leaderboardLeagueEmpty =
      'No one in this league has a time here yet.';
  static const leaderboardScopeEveryone = 'Everyone';
  static const leaderboardLeagues = 'Leagues';
  static String playerCardRank(int rank) => 'Rank #$rank';
  static const playerCardTime = 'Time';
  static const playerCardWeekTotal = 'Week total';
  static const playerCardDays = 'Days cleared';
  static const gamePaused = 'Paused';
  static const gamePausedResume = 'Tap to resume';
  static const leaguesTitle = 'Leagues';
  static const leaguesIntro =
      'A board for friends, family or a team. Share the code, and everyone '
      'who joins shows up on it.';
  static const leaguesEmpty = 'You’re not in a league yet.';
  static const leaguesFailed = 'Could not load your leagues.';
  static const leaguesSignIn = 'Sign in to make or join a league.';
  static const leaguesCreate = 'Create a league';
  static const leaguesJoin = 'Join with a code';
  static const leagueNameLabel = 'League name';
  static const leagueNameHint = 'Family, office, book club…';
  static const leagueNameInvalid = 'Use 1 to 30 characters.';
  static const leagueCodeLabel = 'Invite code';
  static const leagueCodeHint = 'ABC234';
  static const leagueCodeInvalid = 'A code is 6 letters and digits.';
  static const leagueCreateAction = 'Create';
  static const leagueJoinAction = 'Join';
  static const leagueCancel = 'Cancel';
  static const leagueSave = 'Save';
  static String leagueMembers(int count) =>
      count == 1 ? '1 player' : '$count players';
  static const leagueOwner = 'Owner';
  static String leagueCode(String code) => 'Code $code';
  static const leagueShareInvite = 'Share invite';
  static const leagueCopyCode = 'Copy code';
  static const leagueCodeCopied = 'Code copied';
  static String leagueInviteText(String name, String url) =>
      'Join my Winklo league “$name”: $url';
  static const leagueMembersHeading = 'Players';
  static const leagueMemberFallbackName = 'Player';
  static const leagueLoadFailed = 'Could not load this league.';
  static const leagueRename = 'Rename';
  static const leagueRemove = 'Remove';
  static String leagueRemoveConfirm(String name) =>
      'Remove $name from the league?';
  static const leagueLeave = 'Leave league';
  static const leagueLeaveConfirm =
      'Leave this league? You can join again with its code.';
  static const leagueDelete = 'Delete league';
  static const leagueDeleteConfirm =
      'Delete this league for everyone? This can’t be undone.';
  static const leagueGone = 'This league no longer exists.';
  static const leagueSeeBoard = 'See the board';
  static const leagueActionFailed = 'Something went wrong. Try again.';
  static const joinLeagueTitle = 'Join a league';
  static const joinLeagueSignIn = 'Sign in to join this league.';
  static String joinLeagueNotFound(String code) =>
      'No league has the code $code.';
  static const joinLeagueBadCode = 'That isn’t a league code.';
  static const joinLeagueFull = 'That league is full (30 players).';
  static const joinLeagueButton = 'Join league';
  static const joinLeagueAlreadyIn = 'You’re in this league.';

  /// Compact game-tab label (full title stays [pathWordsTitle]).
  static const pathWordsTab = 'Path';

  // Notifications
  static const notifDailyReadyTitle = 'Today’s puzzles are ready';
  static const notifDailyReadyBody =
      'Play Zip, Path Words and Sudoku to keep your streaks going.';
  static const notifStreakAtRiskTitle = 'Streak at risk';

  // Habit: freezes, reminders, weekly recap, home-screen widget, Settings
  static String gameTitle(String gameId) => switch (gameId) {
    GameIds.zip => zipTitle,
    GameIds.pathWords => pathWordsTitle,
    GameIds.sudoku => sudokuTitle,
    GameIds.wordMatch => wordMatch,
    GameIds.categoryRace => categoryRace,
    _ => gameId,
  };
  static String streakFreezesReady(int count) =>
      '$count streak freezes ready: miss a day and your streak carries on.';
  static String freezeCountLabel(int count) => '×$count';
  static String freezeSavedStreak(String gameId, int days) =>
      'Your freeze saved your $days-day ${gameTitle(gameId)} streak';
  static const dismiss = 'Dismiss';

  /// "Your 12-day Zip streak ends at midnight", or "… and 2 more end …".
  static String notifStreakEndsTonight(
    String gameId,
    int days, {
    int others = 0,
  }) {
    final streak = '$days-day ${gameTitle(gameId)} streak';
    if (others <= 0) return 'Your $streak ends at midnight';
    return 'Your $streak and $others more end at midnight';
  }

  static const notifWeeklyRecapTitle = 'Your week in Winklo';

  /// "This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak".
  static String weeklyRecapLine(WeeklyRecap recap, {bool lastWeek = false}) {
    final best = recap.bestGameId;
    final bestSeconds = recap.bestSeconds;
    final streak = recap.streakGameId;
    final parts = [
      '${recap.cleared} of ${recap.possible} cleared',
      if (best != null && bestSeconds != null)
        'best ${gameTitle(best)} ${formatPlayTime(bestSeconds)}',
      if (streak != null) '${recap.streakDays}-day ${gameTitle(streak)} streak',
    ];
    return '${lastWeek ? 'Last week' : 'This week'}: ${parts.join(', ')}';
  }

  static const homeRecapTitle = 'Your week';

  // Android notification channels
  static const channelRemindersName = 'Reminders';
  static const channelRemindersDescription =
      'Daily puzzles, streaks at risk and your weekly recap.';
  static const channelAnnouncementsName = 'Announcements';
  static const channelAnnouncementsDescription = 'News and app updates.';

  // Home-screen widget
  static const widgetCleared = '✓';
  static String widgetStreak(int days) => '🔥$days';
  static const widgetPlay = 'Play';
  static const widgetFooter = 'New puzzle at midnight';

  // Settings
  static const profileSettings = 'Settings';
  static const settingsTitle = 'Settings';
  static const settingsSoundSection = 'Sound and vibration';
  static const settingsRemindersSection = 'Reminders';
  static const settingsLanguageSection = 'Language';
  static const settingsDailyReady = 'Daily puzzles ready';
  static const settingsDailyReadyHint = 'When today’s puzzles are out';
  static const settingsStreakAtRisk = 'Streak at risk';
  static const settingsStreakAtRiskHint = 'Only when a streak is at stake';
  static const settingsWeeklyRecap = 'Weekly recap';
  static String settingsWeeklyRecapHint(String time) => 'Sundays at $time';
  static const settingsAnnouncements = 'Announcements';
  static const settingsAnnouncementsHint = 'News about Winklo';
  static const settingsReminderTime = 'Time';
  static String settingsReminderTimeLabel(String reminder, String time) =>
      '$reminder time, $time';

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
  static const profileVibration = 'Vibration';
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

  // More ways to play: archive, practice and bonus games (roadmap area F)
  static const moreWaysTitle = 'More ways to play';
  static const moreWaysEntryHint = 'Archive · Practice · Bonus games';
  static const archiveTitle = 'Archive';
  static const archiveHint = 'Replay any past daily. No streak or board.';
  static const practiceTitle = 'Practice';
  static const practiceHint = 'Endless offline boards. Hints on the house.';
  static const bonusGamesTitle = 'Bonus games';
  static const bonusGamesHint = 'Quick word games, just for fun.';
  static String archiveRunLabel(DateTime day) =>
      'Archive · ${leaderboardShortDate(day.day, day.month)}';
  static const practiceRunLabel = 'Practice';
  static const practiceNewBoard = 'New board';
  static const hintUnlimited = 'Hint';
  static String localBest(String time) => 'Best $time';
  static String archiveBest(String time) => 'Archive best $time';
  static const newLocalBest = 'New best';
  static const backToArchive = 'Back to archive';
  static const archivePickGame = 'Game';
  static String archiveMonthCleared(int days) =>
      days == 1 ? '1 day cleared' : '$days days cleared';
  static const archiveDayCleared = 'Cleared';
  static const archiveDayOpen = 'Not played';
  static const archivePrevious = 'Previous month';
  static const archiveNext = 'Next month';
  static const archiveLegend = 'Cleared in the daily or the archive';
  static String pathWordsThemeOf(String theme) => 'Theme: $theme';
  static const archiveOpenHint = 'Pick a day to play it again.';
  static const practicePickGame = 'Pick a game for a fresh board.';
  static const wordMatchHint = 'Drag each word to its pair.';
  static const categoryRaceHint = 'Name words that fit, against the clock.';
  static const archiveEmpty = 'The archive opens tomorrow.';
  static String bonusRunLabel(String game, String item) => '$game · $item';
  static const bonusLoadFailed = 'Couldn’t load this game. Try again.';
  static const resultsPairsLabel = 'pairs';
  static String bonusSecondsLeft(int seconds) => '${seconds}s';
  static String wordMatchPairs(int n) => n == 1 ? '1 pair' : '$n pairs';
  static const wordMatchNoDecks = 'No decks yet. Check back soon.';
  static const wordMatchDeckMissing = 'This deck isn’t available any more.';
  static const wordMatchInstruction = 'Drag a word onto its pair';
  static const wordMatchCleared = 'All matched!';
  static const wordMatchTimeUp = 'Time up';
  static String wordMatchMatched(int matched, int total) =>
      'Matched $matched of $total';
  static const wordMatchHowToBody =
      'Drag each word onto the word it pairs with. Match every pair before '
      'the clock runs out. Your best time for each deck stays on this '
      'device; there is no streak or leaderboard.';
  static const categoryRaceHowToBody =
      'You get a category and a letter. Type as many words as you can that '
      'fit the category and start with that letter before time runs out. '
      'Your best count stays on this device; there is no streak or '
      'leaderboard.';
  static String categoryRaceStart(int seconds) => 'Start · ${seconds}s';
  static String categoryRaceInstruction(String letter) =>
      'Type words that fit the category and start with $letter';
  static const categoryRaceYourWord = 'Your word';
  static const categoryRaceSubmit = 'Submit word';
  static String categoryRaceAccepted(int n) => 'Accepted ($n)';
  static String categoryRaceMustStart(String letter) =>
      'Must start with $letter';
  static String categoryRaceNotIn(String category) => 'Not in $category';
  static const categoryRaceAlreadyUsed = 'Already used';
  static const categoryRaceRoundOver = 'Round over';
  static const categoryRaceNoCategories = 'No categories yet. Check back soon.';
  static const resultsWordsLabel = 'words';
  static String localBestScore(int words) =>
      words == 1 ? 'Best 1 word' : 'Best $words words';
}
