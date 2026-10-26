import '../../domain/game_ids.dart';
import '../../domain/hint_penalty.dart';
import '../../domain/habit/weekly_recap.dart';
import 'app_text.dart';
import 'play_time_format.dart';

/// English: the app's original copy.
final class AppTextEn implements AppText {
  const AppTextEn();

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

  @override
  String get appTitle => 'Winklo';

  // Home
  @override
  String get homeTagline => 'Quick solo mini-games.';

  @override
  String get zipTitle => 'Zip';

  @override
  String get zipTagline => 'Fill every cell from 1 to the finish.';

  @override
  String get playTodaysZip => "Play today's Zip";

  @override
  String get zipUndo => 'Undo';

  @override
  String get zipClear => 'Clear';

  @override
  String get zipReplay => 'Replay';

  @override
  String get zipHint => 'Hint';

  @override
  String get zipHowToPlayTitle => 'How to play';

  @override
  String get zipTutorialStart => 'Start at 1';

  @override
  String get zipTutorialFinish => 'Finish on the last number';

  @override
  String get zipTutorialFillEveryCell => 'Fill every cell';

  @override
  String get zipTutorialWalls => 'Walls block the path';

  @override
  String get zipHowToPlayGotIt => 'Got it';

  @override
  String get tutorialGotIt => 'Got it';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get zipTipStartAtOne => 'Start at 1';

  @override
  String get zipTipFillEveryCell => 'Fill every cell before you finish';

  @override
  String get zipTipFinishOnLast => 'Finish on the last number';

  @override
  String get zipTipVisitInOrder => 'Visit the numbers in order';

  @override
  String get zipClearedTitle => 'Puzzle cleared!';

  @override
  String get zipLoading => 'Building today’s puzzle…';

  @override
  String get zipFailed => 'Could not load today’s puzzle.';

  @override
  String get playAgain => 'Play again';

  @override
  String get result => 'Result';

  @override
  String get today => 'TODAY';

  @override
  String get wordMatch => 'Word Match';

  @override
  String get categoryRace => 'Category Race';

  @override
  String get streakProtectedLabel => 'Streak protected';

  @override
  String get cleared => 'Cleared';

  @override
  String bestTimeLabel(String formatted) => 'Best $formatted';

  @override
  String get streakFreezeReady =>
      'Streak freeze ready: miss one day and your streak carries on.';

  @override
  String homeTileStats({int? bestSeconds, int longestStreak = 0}) => [
    if (bestSeconds != null) bestTimeLabel(formatPlayTime(bestSeconds)),
    if (longestStreak >= 2) longestStreakLabel(longestStreak),
  ].join(' · ');

  @override
  String homeTodaySummary({
    required int cleared,
    required int total,
    int? totalSeconds,
  }) => [
    '$cleared of $total cleared',
    if (totalSeconds != null) '${formatPlayTime(totalSeconds)} total',
  ].join(' · ');

  @override
  String get homePerfectDayBadge => 'Perfect day';

  @override
  String get homeDailyBadge => 'DAILY';

  // Path Words
  @override
  String get pathWordsTitle => 'Path Words';

  @override
  String get pathWordsTagline => 'Trace every word across the grid.';

  @override
  String get playTodaysPathWords => "Play today's Path Words";

  @override
  String get pathWordsUndo => 'Undo';

  @override
  String get pathWordsHint => 'Hint';

  @override
  String get pathWordsHowToPlayTitle => 'How to play';

  @override
  String get pathWordsTutorialMatchList => 'Match a word on the list';

  @override
  String get pathWordsTutorialFindEveryWord => 'Find every word';

  @override
  String get pathWordsTutorialFillEveryCell => 'Every cell should fill';

  @override
  String get pathWordsHowToPlayGotIt => 'Got it';

  @override
  String get pathWordsTipMatchList =>
      'That path isn’t on the list — match a listed word';

  @override
  String pathWordsUnfoundWordLabel(int letterCount) =>
      '$letterCount-letter word, not found yet';

  @override
  String pathWordsTracingWordLabel(String letters) =>
      'Tracing ${letters.toUpperCase()}';

  @override
  String get pathWordsClearedTitle => 'Puzzle cleared!';

  @override
  String get pathWordsLoading => 'Building today’s puzzle…';

  @override
  String get pathWordsFailed => 'Could not load today’s puzzle.';

  @override
  String pathWordsThemeReveal(String theme) => 'Today: $theme';

  @override
  String pathWordsBonusWord(String word) => 'Bonus word: ${word.toUpperCase()}';

  @override
  String pathWordsBonusCount(int count) =>
      count == 1 ? '1 bonus word' : '$count bonus words';

  @override
  String get pathWordsTapForMeaning => 'Tap a word to see what it means';

  @override
  String pathWordsWordWithMeaningLabel(String word) =>
      '${word.toUpperCase()}, tap for its meaning';

  @override
  String get weekendSpecial => 'Weekend special';

  @override
  String get retry => 'Retry';

  // Sudoku
  @override
  String get sudokuTitle => 'Sudoku';

  @override
  String get sudokuTagline => 'Fill every cell with 1–6.';

  @override
  String get playTodaysSudoku => "Play today's Sudoku";

  @override
  String get sudokuHint => 'Hint';

  @override
  String get sudokuHintUnitRegion => 'region';

  @override
  String get sudokuHintUnitRow => 'row';

  @override
  String get sudokuHintUnitColumn => 'column';

  @override
  String sudokuHintLastRemaining({required int digit, required String unit}) =>
      'This cell has to be $digit due to all other cells in this $unit being blocked by other ${digit}s.';

  @override
  String sudokuHintNakedSingle({required int digit}) =>
      'This cell has to be $digit — every other digit conflicts with the row, column, or region.';

  @override
  String get sudokuHintNoSimple => 'No simple hint right now.';

  @override
  String sudokuHintMistakeInRow(int row) =>
      'One of the digits in row $row is wrong. Fix it first, then ask for another hint.';

  @override
  String get sudokuErase => 'Erase';

  @override
  String get sudokuReset => 'Reset';

  @override
  String get sudokuNotes => 'Notes';

  @override
  String get sudokuHowToPlayTitle => 'How to play';

  @override
  String get sudokuHowToPlayBody =>
      'Fill every empty cell with 1–6 so each row, column and 2×3 box has every digit once. You can enter any digit; a full row, column or box that’s wrong lights up. Notes are unlimited, and so are hints, but each hint adds time: +${HintPenalty.stepSeconds}s, then +${HintPenalty.stepSeconds * 2}s, and so on up to +${HintPenalty.maxSeconds}s. A hint points out a wrong digit or explains the next step, and never fills a cell for you.';

  @override
  String get sudokuHowToPlayGotIt => 'Got it';

  @override
  String get sudokuClearedTitle => 'Puzzle cleared!';

  @override
  String get sudokuLoading => 'Building today’s puzzle…';

  @override
  String get sudokuFailed => 'Could not load today’s puzzle.';

  @override
  String get puzzleNeedsUpdate =>
      'Today’s puzzle needs a newer version of Winklo. Update the app to play it.';

  @override
  String get sudokuDifficultyEasy => 'Easy';

  @override
  String get sudokuDifficultyMedium => 'Medium';

  @override
  String get sudokuDifficultyHard => 'Hard';

  // Results
  @override
  String get newPersonalBest => 'New personal best';

  @override
  String get newPuzzleUnlocksTomorrow => 'A new puzzle unlocks tomorrow.';

  @override
  String get newPuzzleReady => 'A new puzzle is ready';

  @override
  String newPuzzleIn(Duration remaining) {
    if (remaining <= Duration.zero) return newPuzzleReady;
    const minute = Duration.microsecondsPerMinute;
    final minutes = (remaining.inMicroseconds + minute - 1) ~/ minute;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final parts = [if (h > 0) '${h}h', if (m > 0 || h == 0) '${m}m'];
    return 'New puzzle in ${parts.join(' ')}';
  }

  @override
  String get backHome => 'Back home';

  @override
  String playNextGame(String gameTitle) => 'Play $gameTitle next';

  @override
  String get perfectDay => 'Perfect day! All three puzzles cleared.';

  @override
  String get shareResult => 'Share';

  @override
  String get shareFailed => 'Couldn’t open sharing. Try again.';

  @override
  String get resultsFullBoard => 'Full board';

  @override
  String clearedIn(String time) => 'Cleared in $time';

  @override
  String rankToday(int rank) => '#$rank today';

  @override
  String get resultsTimeLabel => 'time';

  @override
  String resultsHintPenalty(int seconds) => 'Includes +${seconds}s from hints';

  @override
  String get resultsPointsLabel => 'points';

  @override
  String saveTimeToBoard(String timeLabel) =>
      'Save $timeLabel to today’s board';

  @override
  String get saveTimeSignInTitle => 'Save your time';

  @override
  String get saveTimeSignInBody =>
      'Sign in with Google to put this run on the live daily leaderboard.';

  @override
  String get resultsBoardTeaseHint =>
      'Today’s board is live — tap to save your time and join.';

  @override
  String resultsRankOfToday(int total, {bool capped = false}) =>
      'of $total${capped ? '+' : ''} today';

  @override
  String resultsRankSemantics(int rank, int total, {bool capped = false}) =>
      'Rank $rank of $total${capped ? '+' : ''} today';

  @override
  String resultsHintTimeTile(int seconds) => '+${seconds}s';

  @override
  String get resultsFromHints => 'from hints';

  @override
  String get resultsBoardTab => 'Board';

  @override
  String resultsWordsTab(int count) => 'Words · $count';

  // Zip game branding (feature, not app title)
  @override
  String get zipBrand => 'ZIP';

  @override
  String streakLabel(int days) {
    if (days == 1) return '1-day streak';
    return '$days-day streak';
  }

  @override
  String longestStreakLabel(int days) => 'Longest streak $days';

  // Stats
  @override
  String get statsTitle => 'Stats';

  @override
  String get statsProfileRow => 'Your stats';

  @override
  String get statsProfileRowHint => 'Times, streaks and cleared days';

  @override
  String get statsFailed => 'Could not load your stats.';

  @override
  String get statsLocalOnly =>
      'Showing this phone’s clears only. Pull down to try again.';

  @override
  String get statsClears => 'Clears';

  @override
  String get statsCurrentStreak => 'Streak';

  @override
  String get statsLongestStreak => 'Longest';

  @override
  String get statsBestTime => 'Best';

  @override
  String get statsAverageTime => 'Average';

  @override
  String get statsHintFree => 'Hint-free';

  @override
  String get statsNoValue => '–';

  @override
  String statsPercent(double share) => '${(share * 100).round()}%';

  @override
  String get statsTimesTitle => 'Clear times';

  @override
  String get statsTimesEmpty => 'Clear a puzzle to see your times here.';

  @override
  String statsTimesBucket(int fromSeconds, {required bool open}) =>
      open ? '${formatPlayTime(fromSeconds)}+' : formatPlayTime(fromSeconds);

  @override
  String statsTimesBucketSemantics(int fromSeconds, int? toSeconds, int count) {
    final range = toSeconds == null
        ? '${formatPlayTime(fromSeconds)} or more'
        : '${formatPlayTime(fromSeconds)} to ${formatPlayTime(toSeconds)}';
    return '$range: ${statsClearCount(count)}';
  }

  @override
  String statsClearCount(int count) => count == 1 ? '1 clear' : '$count clears';

  @override
  String get statsCalendarTitle => 'Cleared days';

  @override
  String get statsCalendarEmpty => 'Your cleared days will show here.';

  @override
  String statsCalendarCleared(int days) =>
      days == 1 ? '1 day cleared' : '$days days cleared';

  @override
  String get statsCalendarPrevious => 'Previous month';

  @override
  String get statsCalendarNext => 'Next month';

  @override
  String get statsTrendTitle => 'Personal best trend';

  @override
  String get statsTrendSubtitle => 'Last 30 days';

  @override
  String get statsTrendEmpty =>
      'Clear a puzzle in the next few days to start your trend.';

  @override
  String get statsTrendTimes => 'Clear time';

  @override
  String get statsTrendBest => 'Personal best';

  @override
  String get statsTrendToday => 'Today';

  @override
  String statsTrendSemantics({
    required int clears,
    required int? bestSeconds,
  }) => [
    'Last 30 days: ${statsClearCount(clears)}',
    if (bestSeconds != null) 'personal best ${formatPlayTime(bestSeconds)}',
  ].join(', ');

  // Achievements
  @override
  String get achievementsTitle => 'Badges';

  @override
  String achievementsProgress(int unlocked, int total) => '$unlocked of $total';

  @override
  String get achievementsFirstClearsSection => 'First clears';

  @override
  String get achievementsStreaksSection => 'Streaks';

  @override
  String get achievementsSpecialsSection => 'Specials';

  @override
  String get achievementLocked => 'Locked';

  @override
  String achievementFirstClearTitle(String game) => 'First $game';

  @override
  String achievementFirstClearCondition(String game) =>
      'Clear your first $game';

  @override
  String achievementStreakTitle(int days, String game) =>
      '$days-day $game streak';

  @override
  String achievementStreakCondition(int days, String game) =>
      'Clear $game $days days in a row';

  @override
  String get achievementZipUnderMinuteTitle => 'Under a minute';

  @override
  String get achievementZipUnderMinuteCondition =>
      'Clear a Zip in under a minute';

  @override
  String get achievementHintFreeWeekTitle => 'Hint-free week';

  @override
  String get achievementHintFreeWeekCondition =>
      'Clear one game 7 days in a row without hints';

  @override
  String get achievementFlawlessSudokusTitle => 'Flawless ten';

  @override
  String get achievementFlawlessSudokusCondition =>
      'Clear 10 Sudokus with no hints or mistakes';

  @override
  String get achievementPerfectDayTitle => 'Perfect day';

  @override
  String get achievementPerfectDayCondition =>
      'Clear all three games on the same day';

  // Badges: the Profile summary and the Badges screen
  @override
  String achievementNext(String title) => 'Next: $title';

  @override
  String achievementStreakProgress(int current, int target) =>
      '$current of $target days';

  @override
  String get achievementsAllEarned => 'Every badge earned';

  @override
  String get achievementLadderFirst => 'First clear';

  @override
  String achievementLadderDays(int days) => '$days days';

  @override
  String get achievementsSpecial => 'Special';

  @override
  String get achievementEarned => 'Earned';

  @override
  String achievementCurrentStreak(int days) =>
      days == 1 ? 'Current streak: 1 day' : 'Current streak: $days days';

  @override
  String newAchievementsTitle(int count) =>
      count == 1 ? 'New badge unlocked' : '$count new badges unlocked';

  @override
  String newAchievementsList(List<String> titles) {
    if (titles.length <= 1) return titles.join();
    if (titles.length == 2) return '${titles[0]} and ${titles[1]}';
    return '${titles[0]}, ${titles[1]} and ${titles.length - 2} more';
  }

  // Force update / soft update
  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateRequiredBody =>
      'A new version of Winklo is required to continue. Please update from the Play Store.';

  @override
  String get updateAvailableBody => 'Get the latest fixes and puzzles.';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateCantSkip => "This update can't be skipped.";

  @override
  String get updateSnooze => 'Hide for a day';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateRestart => 'Restart to update';

  @override
  String updateVersionRow(String current, String requiredLabel) {
    return '$current → $requiredLabel';
  }

  // Auth / leaderboard
  @override
  String get playSignInTitle => 'Sign in to play';

  @override
  String get playSignInBody =>
      'Sign in with Google to play today’s puzzles and save your time on the board.';

  @override
  String get signInTitle => 'Sign in to join the board';

  @override
  String get signInBody =>
      'Browse live rankings anytime. Sign in with Google to play and save your scores.';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInCancel => 'Not now';

  @override
  String get signInRequired => 'Sign in to join the board';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You’ll need to sign in again to play. You can still view the live leaderboard signed out.';

  @override
  String get signOutConfirmCancel => 'Cancel';

  @override
  String get signOutConfirmNote =>
      'Your streaks & stats stay safe in the cloud.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'You’ll finish on our website: sign in there with the same Google account and confirm. Your profile, leaderboard entries and synced progress are deleted for good.';

  @override
  String get deleteAccountConfirmNote =>
      'We’ll sign you out here first, then open the page in your browser.';

  @override
  String get deleteAccountConfirmContinue => 'Continue';

  @override
  String get deleteAccountOpenFailed =>
      'Couldn’t open your browser. Visit winklo.pages.dev/delete-account to delete your account.';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardDaily => 'Daily';

  @override
  String get leaderboardAllTime => 'All-time';

  @override
  String get leaderboardEmpty => 'No scores yet. Be the first!';

  @override
  String get leaderboardFailed => 'Could not load the leaderboard.';

  @override
  String get leaderboardSignInHint => 'Sign in to view live rankings.';

  @override
  String get seeFullLeaderboard => 'See full leaderboard';

  @override
  String get leaderboardGapEllipsis => '…';

  @override
  String get youLabel => 'You';

  @override
  String get leaderboardNoHintChip => 'Hint-free';

  @override
  String get leaderboardNoMistakesChip => 'Flawless';

  @override
  String get leaderboardKeyStreak => 'Day streak';

  @override
  String leaderboardBehind(String gap, int rank) => '$gap behind #$rank';

  @override
  String leaderboardPodiumSemantics(int rank, String name, String time) =>
      'Rank $rank, $name, $time';

  @override
  String leaderboardDaysShort(int days) => days == 1 ? '1 day' : '$days days';

  // Leaderboard: past days, the weekly board and leagues (roadmap area C)
  @override
  String get leaderboardThisWeek => 'This week';

  @override
  String get leaderboardToday => 'Today';

  @override
  String get leaderboardYesterday => 'Yesterday';

  @override
  String leaderboardShortDate(int day, int month) =>
      '$day ${_shortMonths[month - 1]}';

  @override
  String leaderboardDaysCleared(int days) => days == 1 ? '1 day' : '$days days';

  @override
  String leaderboardWeeklyRow(int days, String time) =>
      '${leaderboardDaysCleared(days)} · $time';

  @override
  String get leaderboardPastDayEmpty => 'No times on this day.';

  @override
  String get leaderboardWeeklyEmpty =>
      'No one has cleared a day this week yet.';

  @override
  String get leaderboardWeeklyDebugNote =>
      'The server fills in the weekly board, so debug builds show it empty.';

  @override
  String get leaderboardLeagueEmpty =>
      'No one in this league has a time here yet.';

  @override
  String get leaderboardScopeEveryone => 'Everyone';

  @override
  String get leaderboardLeagues => 'Leagues';

  // Leaderboard: the board and scope pickers and the table
  @override
  String get leaderboardBoardSheetTitle => 'Which board?';

  @override
  String get leaderboardScopeSheetTitle => 'Whose scores?';

  @override
  String get leaderboardThisWeekHint => 'Days cleared, then total time';

  @override
  String get leaderboardAllTimeHint => 'Best time ever';

  @override
  String get leaderboardSingleDayLabel => 'A single day · last 14 days';

  @override
  String get leaderboardColumnPlayer => 'Player';

  @override
  String get leaderboardColumnTime => 'Time';

  @override
  String get leaderboardColumnDays => 'Days';

  @override
  String get leaderboardColumnTotal => 'Total';

  @override
  String get leaderboardColumnBest => 'Best';

  @override
  String get leaderboardTop50 => 'Top 50';

  @override
  String get leaderboardManageLeagues => 'Manage leagues';

  @override
  String get leaderboardCreateOrJoinLeague => 'Create or join a league';

  @override
  String leaderboardLeaguePlayers(int count) =>
      count == 1 ? '1 player' : '$count players';

  @override
  String leaderboardBoardPillLabel(String board) => 'Board: $board';

  @override
  String leaderboardScopePillLabel(String scope) => 'Scores: $scope';

  @override
  String playerCardRank(int rank) => 'Rank #$rank';

  @override
  String get playerCardTime => 'Time';

  @override
  String get playerCardWeekTotal => 'Week total';

  @override
  String get playerCardDays => 'Days cleared';

  @override
  String get gamePaused => 'Paused';

  @override
  String get gamePausedResume => 'Tap to resume';

  @override
  String get leaguesTitle => 'Leagues';

  @override
  String get leaguesIntro =>
      'A board for friends, family or a team. Share the code, and everyone '
      'who joins shows up on it.';

  @override
  String get leaguesEmpty => 'You’re not in a league yet.';

  @override
  String get leaguesFailed => 'Could not load your leagues.';

  @override
  String get leaguesSignIn => 'Sign in to make or join a league.';

  @override
  String get leaguesCreate => 'Create a league';

  @override
  String get leaguesJoin => 'Join with a code';

  @override
  String get leagueNameLabel => 'League name';

  @override
  String get leagueNameHint => 'Family, office, book club…';

  @override
  String get leagueNameInvalid => 'Use 1 to 30 characters.';

  @override
  String get leagueCodeLabel => 'Invite code';

  @override
  String get leagueCodeHint => 'ABC234';

  @override
  String get leagueCodeInvalid => 'A code is 6 letters and digits.';

  @override
  String get leagueCreateAction => 'Create';

  @override
  String get leagueJoinAction => 'Join';

  @override
  String get leagueCancel => 'Cancel';

  @override
  String get leagueSave => 'Save';

  @override
  String leagueMembers(int count) => count == 1 ? '1 player' : '$count players';

  @override
  String get leagueOwner => 'Owner';

  @override
  String leagueCode(String code) => 'Code $code';

  @override
  String get leagueShareInvite => 'Share invite';

  @override
  String get leagueCopyCode => 'Copy code';

  @override
  String get leagueCodeCopied => 'Code copied';

  @override
  String leagueInviteText(String name, String url) =>
      'Join my Winklo league “$name”: $url';

  @override
  String get leagueMembersHeading => 'Players';

  @override
  String get leagueMemberFallbackName => 'Player';

  @override
  String get leagueLoadFailed => 'Could not load this league.';

  @override
  String get leagueRename => 'Rename';

  @override
  String get leagueRemove => 'Remove';

  @override
  String leagueRemoveConfirm(String name) => 'Remove $name from the league?';

  @override
  String get leagueLeave => 'Leave league';

  @override
  String get leagueLeaveConfirm =>
      'Leave this league? You can join again with its code.';

  @override
  String get leagueDelete => 'Delete league';

  @override
  String get leagueDeleteConfirm =>
      'Delete this league for everyone? This can’t be undone.';

  @override
  String get leagueGone => 'This league no longer exists.';

  @override
  String get leagueSeeBoard => 'See the board';

  @override
  String get leagueActionFailed => 'Something went wrong. Try again.';

  @override
  String get joinLeagueTitle => 'Join a league';

  @override
  String get joinLeagueSignIn => 'Sign in to join this league.';

  @override
  String joinLeagueNotFound(String code) => 'No league has the code $code.';

  @override
  String get joinLeagueBadCode => 'That isn’t a league code.';

  @override
  String get joinLeagueFull => 'That league is full (30 players).';

  @override
  String get joinLeagueButton => 'Join league';

  @override
  String get joinLeagueAlreadyIn => 'You’re in this league.';

  @override
  String get pathWordsTab => 'Path';

  // Notifications. Mixed voice, simple English for learners worldwide, an
  // emoji in about one line in four, never guilt. Lines don't say "morning":
  // players pick their own reminder time.
  @override
  List<NotifCopy> get notifMorningLines => const [
    (
      title: 'Today’s puzzles are ready',
      body: 'Fresh Zip, Path Words and Sudoku boards. Which one first?',
    ),
    (
      title: 'New day, new puzzles ✨',
      body: 'Three fresh boards are waiting for you.',
    ),
    (
      title: 'Zip is ready. One line, every cell.',
      body: 'Can you find the path today?',
    ),
    (
      title: 'Got five minutes?',
      body: 'Today’s Sudoku fits nicely in a short break.',
    ),
    (
      title: 'Fresh words to find 🔤',
      body: 'Today’s Path Words board is live.',
    ),
    (
      title: 'Your brain worked out yesterday',
      body: 'Ready for another round? Today’s puzzles are up 💪',
    ),
    (
      title: 'Today’s Zip is waiting',
      body: 'Connect the numbers in order and fill every cell.',
    ),
    (
      title: 'Three puzzles, one day',
      body: 'Clear all three for a perfect day 🌟',
    ),
    (
      title: 'Sudoku time?',
      body: 'A new grid is ready. Take it one number at a time.',
    ),
    (
      title: 'Path Words is live',
      body: 'New letters, new words. Can you trace them all?',
    ),
    (
      title: 'Start with an easy win',
      body: 'Play the game you like most first, then try the others.',
    ),
    (
      title: 'Fresh boards for everyone',
      body: 'Everyone starts from zero today. See how you compare.',
    ),
    (
      title: 'Can you beat yesterday’s time?',
      body: 'Today’s Zip is ready to find out.',
    ),
    (
      title: 'Quiet puzzle, busy day',
      body: 'Even a few minutes with Sudoku is a nice break.',
    ),
    (title: 'Words are hiding 🔍', body: 'Find them in today’s Path Words.'),
    (
      title: 'Today’s Zip has one answer',
      body: 'Find the path that fills every cell.',
    ),
    (
      title: 'Ready when you are',
      body: 'Zip, Path Words and Sudoku are all new today.',
    ),
    (
      title: 'Time for your daily three',
      body: 'A few minutes, three puzzles and a clear head.',
    ),
    (
      title: 'Think you’re fast? ⏱️',
      body: 'The timer is waiting in today’s Zip.',
    ),
    (
      title: 'New Sudoku, new numbers',
      body: 'Every row, every column, every box. You’ve got this.',
    ),
    (
      title: 'A fresh start 🌱',
      body: 'Yesterday is done. Today’s puzzles are brand new.',
    ),
    (
      title: 'Path Words: new letters today',
      body: 'Trace every word across a brand new grid.',
    ),
    (title: 'Puzzle break? ☕', body: 'Today’s boards are ready when you are.'),
    (
      title: 'How about a Zip?',
      body: 'Draw one line through the numbers. It’s harder than it looks.',
    ),
    (
      title: 'Small puzzle, big smile',
      body: 'Clear one board today and feel good about it.',
    ),
    (
      title: 'Sharp mind, new day',
      body: 'Today’s Sudoku is here to keep it that way.',
    ),
    (
      title: 'Today’s top times are open',
      body: 'Post a quick time on any game and see where you land.',
    ),
    (
      title: 'One puzzle a day',
      body: 'That’s all a habit needs. Start with any game.',
    ),
    (
      title: 'A fresh Path Words board',
      body: 'Some words are easy to spot. Some are not. Find them all.',
    ),
    (
      title: 'Let’s play',
      body: 'Today’s Zip, Path Words and Sudoku are ready.',
    ),
  ];

  @override
  List<NotifCopy> notifMorningStreakLines(String gameId, int days) {
    final game = gameTitle(gameId);
    final next = days + 1;
    return [
      (
        title: 'Day $next of your $game streak 🔥',
        body: '$days days in a row so far. Keep it going today.',
      ),
      (
        title: '$days days of $game and counting',
        body: 'Today’s board is ready to make it $next.',
      ),
      (
        title: 'Your $game streak is at $days days',
        body: 'One more clear today keeps it alive.',
      ),
      (
        title: 'Keep the $game streak rolling',
        body: '$days days strong. Today’s puzzle is waiting.',
      ),
      (title: '$days-day $game streak 🔥', body: 'Nice habit. Don’t stop now.'),
      (
        title: 'Your streak says hi 👋',
        body: '$days days of $game. Make it $next today.',
      ),
      (
        title: 'Look at that $game streak',
        body: '$days days in a row. Today could be day $next.',
      ),
      (
        title: 'Streak check: $days days',
        body: 'Your $game run continues today. Ready?',
      ),
      (
        title: '$game, day $next?',
        body: 'Your streak is $days days long. Keep it going.',
      ),
      (
        title: 'Still going strong 💪',
        body: '$days days of $game. Today’s board is up.',
      ),
    ];
  }

  @override
  List<NotifCopy> get notifLapsedLines => const [
    (
      title: 'Missed a day? No problem',
      body: 'Today’s puzzles are new. Jump back in.',
    ),
    (
      title: 'Today is a clean board',
      body: 'Whatever happened yesterday, today starts fresh.',
    ),
    (
      title: 'Your puzzles are still here 🧩',
      body: 'Zip, Path Words and Sudoku are ready when you are.',
    ),
    (
      title: 'Come back for a quick one',
      body: 'One puzzle takes only a few minutes.',
    ),
    (
      title: 'Fresh boards, same fun',
      body: 'New Zip, Path Words and Sudoku today.',
    ),
    (
      title: 'Pick up where you left off',
      body: 'Today’s puzzles are waiting for you.',
    ),
    (
      title: 'An easy way back in',
      body: 'Start with your favourite game. Just one.',
    ),
    (
      title: 'Your spot is still here',
      body: 'Today’s leaderboard has room for your time.',
    ),
    (
      title: 'Today could be day one',
      body: 'Every streak starts with a single clear 🌱',
    ),
    (
      title: 'A puzzle a day, any day',
      body: 'It’s never too late to start again. Today’s boards are up.',
    ),
  ];

  @override
  List<NotifCopy> get notifMissYouLines => const [
    (
      title: 'It’s been a while 👋',
      body: 'Your daily puzzles are still here. Come take a look.',
    ),
    (
      title: 'We miss you at Winklo',
      body: 'There’s a new Zip, Path Words and Sudoku every day.',
    ),
    (
      title: 'Still up for a puzzle?',
      body: 'Today’s boards are fresh. One is all it takes.',
    ),
    (
      title: 'The puzzles kept coming',
      body: 'There’s a new set today. Want to try one?',
    ),
    (
      title: 'Your brain might enjoy this',
      body: 'A short puzzle break is waiting in Winklo.',
    ),
  ];

  @override
  List<NotifCopy> get notifLastCallLines => const [
    (
      title: 'We’ll stop reminding you for now',
      body: 'Your puzzles will be here whenever you want them.',
    ),
    (
      title: 'Our last reminder',
      body: 'We’ll go quiet now. Open Winklo any time for today’s puzzles.',
    ),
    (
      title: 'Taking a break from reminders',
      body: 'No more nudges for now. Come back whenever you like 👋',
    ),
    (
      title: 'This is our last nudge',
      body: 'We’re pausing reminders. Today’s puzzles are still waiting.',
    ),
  ];

  @override
  List<NotifCopy> notifStreakRiskLines(
    String gameId,
    int days, {
    int others = 0,
  }) {
    final game = gameTitle(gameId);
    final next = days + 1;
    final daysWord = days == 1 ? '1 day' : '$days days';
    final more = switch (others) {
      <= 0 => '',
      1 => ' 1 more streak ends tonight too.',
      _ => ' $others more streaks end tonight too.',
    };
    final List<NotifCopy> lines = switch (days) {
      <= 2 => [
        (
          title: 'Your new $game streak needs you',
          body: '$daysWord so far. Clear today’s board before midnight.',
        ),
        (
          title: 'Don’t let $game slip 🌱',
          body: 'Your streak is just getting started. Play before midnight.',
        ),
        (
          title: 'Keep the $game streak alive',
          body: 'A quick clear today makes it $next days.',
        ),
        (
          title: 'Small streak, big start',
          body: 'Your $days-day $game streak ends at midnight unless you play.',
        ),
        (
          title: '$game is still waiting today',
          body: 'Clear it to keep your $days-day streak going.',
        ),
      ],
      <= 6 => [
        (
          title: '$days days of $game at risk',
          body: 'Today’s board is still open. Play before midnight.',
        ),
        (
          title: 'Your $game streak ends tonight ⏳',
          body: '$days days in a row. Don’t stop now.',
        ),
        (
          title: 'Save your $days-day $game streak',
          body: 'One quick clear before midnight is all it takes.',
        ),
        (
          title: 'Keep the $game run going',
          body: 'Your $days-day streak needs today’s clear.',
        ),
        (
          title: '$game streak check ⏰',
          body: '$days days so far, and today isn’t cleared yet.',
        ),
      ],
      <= 29 => [
        (
          title: 'Your $days-day $game streak 🔥',
          body: 'It ends at midnight unless you clear today’s board.',
        ),
        (
          title: '$days days of $game. Keep going?',
          body: 'Today’s board is still open. A few minutes will do.',
        ),
        (
          title: 'Protect your $game streak',
          body: '$days days is a great run. Play before midnight to keep it.',
        ),
        (
          title: '$game is waiting for day $next',
          body: 'Your streak ends tonight if today stays empty.',
        ),
        (
          title: 'Tonight: $game, day $next',
          body: 'Clear today’s board to keep your $days-day streak.',
        ),
        (
          title: 'Still time for $game ⏳',
          body: 'Your $days-day streak is safe once you clear today.',
        ),
      ],
      _ => [
        (
          title: '$days days of $game! 🏆',
          body: 'A streak like this deserves one more day. Play by midnight.',
        ),
        (
          title: 'Your $days-day $game streak',
          body: 'That’s amazing. Clear today’s board to keep it alive.',
        ),
        (
          title: 'Day $next of $game is waiting',
          body: 'You’ve come so far. A quick clear keeps the streak going.',
        ),
        (
          title: 'Big streak alert 🔥',
          body: '$days days of $game end at midnight unless you play today.',
        ),
        (
          title: 'Keep your $days-day $game run',
          body: 'Today’s board is still open. A few minutes keeps it safe.',
        ),
      ],
    };
    return [
      for (final line in lines) (title: line.title, body: '${line.body}$more'),
    ];
  }

  @override
  List<String> get notifWeeklyRecapTitles => const [
    'Your week in Winklo',
    'Your week in puzzles 📊',
    'How did your week go?',
    'Your weekly recap',
    'This week, in numbers',
    'A week of puzzles, done ✅',
    'Your Sunday puzzle report',
  ];

  // Habit: freezes, reminders, weekly recap, home-screen widget, Settings
  @override
  String gameTitle(String gameId) => switch (gameId) {
    GameIds.zip => zipTitle,
    GameIds.pathWords => pathWordsTitle,
    GameIds.sudoku => sudokuTitle,
    GameIds.wordMatch => wordMatch,
    GameIds.categoryRace => categoryRace,
    _ => gameId,
  };

  @override
  String streakFreezesReady(int count) =>
      '$count streak freezes ready: miss a day and your streak carries on.';

  @override
  String freezeCountLabel(int count) => '×$count';

  @override
  String freezeSavedStreak(String gameId, int days) =>
      'Your freeze saved your $days-day ${gameTitle(gameId)} streak';

  @override
  String get dismiss => 'Dismiss';

  @override
  String weeklyRecapLine(WeeklyRecap recap, {bool lastWeek = false}) {
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

  @override
  String get homeRecapTitle => 'Your week';

  // Android notification channels
  @override
  String get channelRemindersName => 'Reminders';

  @override
  String get channelRemindersDescription =>
      'Daily puzzles, streaks at risk and your weekly recap.';

  @override
  String get channelAnnouncementsName => 'Announcements';

  @override
  String get channelAnnouncementsDescription => 'News and app updates.';

  // Home-screen widget
  @override
  String get widgetCleared => '✓';

  @override
  String widgetStreak(int days) => '🔥$days';

  @override
  String get widgetPlay => 'Play';

  @override
  String get widgetFooter => 'New puzzle at midnight';

  // Settings
  @override
  String get profileSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSoundSection => 'Sound and vibration';

  @override
  String get settingsRemindersSection => 'Reminders';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String settingsLanguageSystemHint(String language) =>
      'Follows your phone: $language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get settingsDailyReady => 'Daily puzzles ready';

  @override
  String get settingsDailyReadyHint => 'When today’s puzzles are out';

  @override
  String get settingsStreakAtRisk => 'Streak at risk';

  @override
  String get settingsStreakAtRiskHint => 'Only when a streak is at stake';

  @override
  String get settingsWeeklyRecap => 'Weekly recap';

  @override
  String settingsWeeklyRecapHint(String time) => 'Sundays at $time';

  @override
  String get settingsAnnouncements => 'Announcements';

  @override
  String get settingsAnnouncementsHint => 'News about Winklo';

  @override
  String get settingsReminderTime => 'Time';

  @override
  String settingsReminderTimeLabel(String reminder, String time) =>
      '$reminder time, $time';

  // Dashboard nav
  @override
  String get navHome => 'Home';

  @override
  String get navLeaderboard => 'Leaderboard';

  @override
  String get navProfile => 'Profile';

  // Profile
  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSignedOutTitle => 'Your profile';

  @override
  String get profileSignedOutBody =>
      'Sign in to set your name and avatar for the leaderboard.';

  @override
  String get profileEditName => 'Display name';

  @override
  String get profileNameHint => 'Enter a display name';

  @override
  String get profileNameEmpty => 'Name can’t be empty.';

  @override
  String get profileNameTooLong => 'Name must be 24 characters or fewer.';

  @override
  String get profileSave => 'Save';

  @override
  String get profileEditAvatar => 'Edit avatar';

  @override
  String get profileChoosePhoto => 'Choose from photos';

  @override
  String get profileAvatarHint => 'Tap a critter to switch';

  @override
  String get profileAvatarPhoto => 'Photo';

  @override
  String get avatarCritterFox => 'Fox';

  @override
  String get avatarCritterCat => 'Cat';

  @override
  String get avatarCritterOwl => 'Owl';

  @override
  String get avatarCritterFrog => 'Frog';

  @override
  String get avatarCritterPanda => 'Panda';

  @override
  String get avatarCritterBunny => 'Bunny';

  @override
  String get avatarCritterPenguin => 'Penguin';

  @override
  String get avatarCritterTiger => 'Tiger';

  @override
  String get avatarCritterKoala => 'Koala';

  @override
  String get avatarCritterBear => 'Bear';

  @override
  String get avatarCritterRaccoon => 'Raccoon';

  @override
  String get avatarCritterChick => 'Chick';

  @override
  String get profileSaveFailed => 'Could not save profile. Try again.';

  @override
  String get profilePhotoTooLarge =>
      'That photo is too large to upload (2 MB at most). Try another one.';

  @override
  String get profileUploadFailed => 'Could not upload photo. Try again.';

  @override
  String get profilePermissionDenied =>
      'Photo access was denied. Enable it in Settings to upload an avatar.';

  @override
  String get profileEditDisplayName => 'Edit display name';

  @override
  String get profileSoundEffects => 'Sound effects';

  @override
  String get profileVibration => 'Vibration';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String get profileAboutGame => 'About the game';

  @override
  String get profileRateOnPlayStore => 'Rate on Play Store';

  @override
  String get reviewOpenStoreFailed => "Couldn't open the Play Store";

  @override
  String get profileReportIssue => 'Report an issue';

  @override
  String get profileAboutBody =>
      'Winklo is a daily puzzle app with solo mini-games you can clear at your own pace.';

  @override
  String get profileAboutGamesHeading => 'Games';

  @override
  String get profileAboutDailyHeading => 'Daily play';

  @override
  String get profileAboutDailyBody =>
      'Each day brings fresh puzzles for Zip, Path Words, and Sudoku. '
      'Clear them to climb the leaderboard and keep your streak alive.';

  @override
  String profileAboutVersion(String version) => 'Version $version';

  @override
  String get profileReportTitleLabel => 'Title';

  @override
  String get profileReportTitleHint => 'Short summary';

  @override
  String get profileReportDescriptionLabel => 'Description';

  @override
  String get profileReportDescriptionHint =>
      'What went wrong or what you’d like to see?';

  @override
  String get profileReportTitleEmpty => 'Title can’t be empty.';

  @override
  String get profileReportTitleTooLong =>
      'Title must be 80 characters or fewer.';

  @override
  String get profileReportDescriptionEmpty => 'Description can’t be empty.';

  @override
  String get profileReportDescriptionTooLong =>
      'Description must be 2000 characters or fewer.';

  @override
  String get profileReportSend => 'Send';

  @override
  String get profileReportSent => 'Thanks — your report was sent.';

  @override
  String get profileReportFailed => 'Could not send report. Try again.';

  @override
  String get profilePrivacyFailed => 'Could not load the privacy policy.';

  @override
  String get profilePrivacyRetry => 'Retry';

  // More ways to play: archive, practice and bonus games (roadmap area F)
  @override
  String get moreWaysTitle => 'More ways to play';

  @override
  String get moreWaysEntryHint => 'Archive · Practice · Bonus games';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveHint => 'Replay any past daily. No streak or board.';

  @override
  String get practiceTitle => 'Practice';

  @override
  String get practiceHint => 'Endless offline boards. Hints on the house.';

  @override
  String get bonusGamesTitle => 'Bonus games';

  @override
  String get bonusGamesHint => 'Quick word games, just for fun.';

  @override
  String archiveRunLabel(DateTime day) =>
      'Archive · ${leaderboardShortDate(day.day, day.month)}';

  @override
  String get practiceRunLabel => 'Practice';

  @override
  String get practiceNewBoard => 'New board';

  @override
  String get hintUnlimited => 'Hint';

  @override
  String hintWithCost(int seconds) => 'Hint +${seconds}s';

  @override
  String localBest(String time) => 'Best $time';

  @override
  String archiveBest(String time) => 'Archive best $time';

  @override
  String get newLocalBest => 'New best';

  @override
  String get backToArchive => 'Back to archive';

  @override
  String get archivePickGame => 'Game';

  @override
  String archiveMonthCleared(int days) =>
      days == 1 ? '1 day cleared' : '$days days cleared';

  @override
  String get archiveDayCleared => 'Cleared';

  @override
  String get archiveDayOpen => 'Not played';

  @override
  String get archivePrevious => 'Previous month';

  @override
  String get archiveNext => 'Next month';

  @override
  String get archiveLegend => 'Cleared in the daily or the archive';

  @override
  String pathWordsThemeOf(String theme) => 'Theme: $theme';

  @override
  String get archiveOpenHint => 'Pick a day to play it again.';

  @override
  String get practicePickGame => 'Pick a game for a fresh board.';

  @override
  String get wordMatchHint => 'Drag each word to its pair.';

  @override
  String get categoryRaceHint => 'Name words that fit, against the clock.';

  @override
  String get archiveEmpty => 'The archive opens tomorrow.';

  @override
  String bonusRunLabel(String game, String item) => '$game · $item';

  @override
  String get bonusLoadFailed => 'Couldn’t load this game. Try again.';

  @override
  String get resultsPairsLabel => 'pairs';

  @override
  String bonusSecondsLeft(int seconds) => '${seconds}s';

  @override
  String wordMatchPairs(int n) => n == 1 ? '1 pair' : '$n pairs';

  @override
  String get wordMatchNoDecks => 'No decks yet. Check back soon.';

  @override
  String get wordMatchDeckMissing => 'This deck isn’t available any more.';

  @override
  String get wordMatchInstruction => 'Drag a word onto its pair';

  @override
  String get wordMatchCleared => 'All matched!';

  @override
  String get wordMatchTimeUp => 'Time up';

  @override
  String wordMatchMatched(int matched, int total) =>
      'Matched $matched of $total';

  @override
  String get wordMatchHowToBody =>
      'Drag each word onto the word it pairs with. Match every pair before '
      'the clock runs out. Your best time for each deck stays on this '
      'device; there is no streak or leaderboard.';

  @override
  String get categoryRaceHowToBody =>
      'You get a category and a letter. Type as many words as you can that '
      'fit the category and start with that letter before time runs out. '
      'Your best count stays on this device; there is no streak or '
      'leaderboard.';

  @override
  String categoryRaceStart(int seconds) => 'Start · ${seconds}s';

  @override
  String categoryRaceInstruction(String letter) =>
      'Type words that fit the category and start with $letter';

  @override
  String get categoryRaceYourWord => 'Your word';

  @override
  String get categoryRaceSubmit => 'Submit word';

  @override
  String categoryRaceAccepted(int n) => 'Accepted ($n)';

  @override
  String categoryRaceMustStart(String letter) => 'Must start with $letter';

  @override
  String categoryRaceNotIn(String category) => 'Not in $category';

  @override
  String get categoryRaceAlreadyUsed => 'Already used';

  @override
  String get categoryRaceRoundOver => 'Round over';

  @override
  String get categoryRaceNoCategories => 'No categories yet. Check back soon.';

  @override
  String get resultsWordsLabel => 'words';

  @override
  String localBestScore(int words) =>
      words == 1 ? 'Best 1 word' : 'Best $words words';

  // Copy moved out of widgets and repositories (roadmap area G)
  @override
  String get resultsTitle => 'Results';

  @override
  String get resultsNextPuzzle => 'Next puzzle';

  @override
  String get leaderboardYourRank => 'Your Rank';

  @override
  String leaderboardPlayGame(String game) => 'Play $game';

  @override
  String get playerFallbackName => 'Player';

  @override
  String shareHeadline(String game, DateTime day) =>
      'Winklo $game · ${leaderboardShortDate(day.day, day.month)}';

  @override
  String get signInFailed => 'Couldn’t sign in. Try again.';

  @override
  String get serviceUnavailable => 'Firebase is unavailable. Try again later.';

  @override
  String get signInRequiredShort => 'Sign in required.';

  @override
  String get profileUpdateFailed => 'Could not update profile.';

  @override
  String get profileLoadFailed => 'Could not load profile.';

  @override
  String get avatarUploadUnavailable => 'Avatar upload is not configured.';

  @override
  String get avatarInvalid => 'Invalid avatar.';

  @override
  String get leaguesSignedOut => 'Sign in to use leagues.';

  @override
  String get leagueLookupFailed => 'Could not look up that code.';

  @override
  String get leagueCreateFailed => 'Could not create the league.';

  @override
  String get leagueCreateRetry => 'Could not create the league. Try again.';

  @override
  String get leagueJoinFailed => 'Could not join the league.';

  @override
  String get leagueLeaveFailed => 'Could not leave the league.';

  @override
  String get leagueRemoveFailed => 'Could not remove that player.';

  @override
  String get leagueRenameFailed => 'Could not rename the league.';

  @override
  String get leagueDeleteFailed => 'Could not delete the league.';

  @override
  String get leagueNameLength => 'League names are 1 to 30 characters.';

  @override
  String get leagueCodeNotFound => 'No league has that code.';
}
