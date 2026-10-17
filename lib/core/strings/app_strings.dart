import '../../domain/habit/weekly_recap.dart';
import 'app_text.dart';
import 'app_text_en.dart';
import 'app_text_ml.dart';
import 'play_time_format.dart' as play_time;

/// All user-facing copy. Each member reads the table for the current
/// language ([AppText]); [use] switches it. English is the default, so code
/// and tests that never call [use] read English.
///
/// Plain Dart on purpose: `domain/` and `data/` (notifications, the
/// home-screen widget, issue reports) read it without a `BuildContext`.
abstract final class AppStrings {
  /// The languages with a table, English first (the fallback).
  static const supportedLanguageCodes = ['en', 'ml'];

  static AppText _t = const AppTextEn();
  static String _languageCode = 'en';

  /// Switches every string to [languageCode]'s table; a code without one
  /// reads English.
  static void use(String languageCode) {
    final (code, table) = switch (languageCode) {
      'ml' => ('ml', const AppTextMl() as AppText),
      _ => ('en', const AppTextEn() as AppText),
    };
    _languageCode = code;
    _t = table;
  }

  /// The language the strings are in: `en` or `ml`.
  static String get languageCode => _languageCode;

  /// "0:48": minutes and seconds, the same in every language.
  static String formatPlayTime(int totalSeconds) =>
      play_time.formatPlayTime(totalSeconds);

  static String get appTitle => _t.appTitle;

  // Home
  static String get homeTagline => _t.homeTagline;
  static String get zipTitle => _t.zipTitle;
  static String get zipTagline => _t.zipTagline;
  static String get playTodaysZip => _t.playTodaysZip;
  static String get zipUndo => _t.zipUndo;
  static String get zipClear => _t.zipClear;
  static String get zipReplay => _t.zipReplay;
  static String get zipHint => _t.zipHint;
  static String get zipHowToPlayTitle => _t.zipHowToPlayTitle;
  static String get zipTutorialStart => _t.zipTutorialStart;
  static String get zipTutorialFinish => _t.zipTutorialFinish;
  static String get zipTutorialFillEveryCell => _t.zipTutorialFillEveryCell;
  static String get zipTutorialWalls => _t.zipTutorialWalls;
  static String get zipHowToPlayGotIt => _t.zipHowToPlayGotIt;
  static String get tutorialGotIt => _t.tutorialGotIt;
  static String get tutorialSkip => _t.tutorialSkip;
  static String get tutorialNext => _t.tutorialNext;
  static String get zipTipStartAtOne => _t.zipTipStartAtOne;
  static String get zipTipFillEveryCell => _t.zipTipFillEveryCell;
  static String get zipTipFinishOnLast => _t.zipTipFinishOnLast;
  static String get zipTipVisitInOrder => _t.zipTipVisitInOrder;
  static String get zipClearedTitle => _t.zipClearedTitle;
  static String get zipLoading => _t.zipLoading;
  static String get zipFailed => _t.zipFailed;
  static String get playAgain => _t.playAgain;
  static String get result => _t.result;
  static String get today => _t.today;
  static String get wordMatch => _t.wordMatch;
  static String get categoryRace => _t.categoryRace;
  static String get streakProtectedLabel => _t.streakProtectedLabel;
  static String get cleared => _t.cleared;
  static String bestTimeLabel(String formatted) => _t.bestTimeLabel(formatted);
  static String get streakFreezeReady => _t.streakFreezeReady;
  static String homeTileStats({int? bestSeconds, int longestStreak = 0}) =>
      _t.homeTileStats(bestSeconds: bestSeconds, longestStreak: longestStreak);
  static String homeTodaySummary({
    required int cleared,
    required int total,
    int? totalSeconds,
  }) => _t.homeTodaySummary(
    cleared: cleared,
    total: total,
    totalSeconds: totalSeconds,
  );
  static String get homePerfectDayBadge => _t.homePerfectDayBadge;
  static String get homeDailyBadge => _t.homeDailyBadge;

  // Path Words
  static String get pathWordsTitle => _t.pathWordsTitle;
  static String get pathWordsTagline => _t.pathWordsTagline;
  static String get playTodaysPathWords => _t.playTodaysPathWords;
  static String get pathWordsUndo => _t.pathWordsUndo;
  static String get pathWordsHint => _t.pathWordsHint;
  static String get pathWordsHowToPlayTitle => _t.pathWordsHowToPlayTitle;
  static String get pathWordsTutorialMatchList => _t.pathWordsTutorialMatchList;
  static String get pathWordsTutorialFindEveryWord =>
      _t.pathWordsTutorialFindEveryWord;
  static String get pathWordsTutorialFillEveryCell =>
      _t.pathWordsTutorialFillEveryCell;
  static String get pathWordsHowToPlayGotIt => _t.pathWordsHowToPlayGotIt;
  static String get pathWordsTipMatchList => _t.pathWordsTipMatchList;
  static String pathWordsUnfoundWordLabel(int letterCount) =>
      _t.pathWordsUnfoundWordLabel(letterCount);
  static String pathWordsTracingWordLabel(String letters) =>
      _t.pathWordsTracingWordLabel(letters);
  static String get pathWordsClearedTitle => _t.pathWordsClearedTitle;
  static String get pathWordsLoading => _t.pathWordsLoading;
  static String get pathWordsFailed => _t.pathWordsFailed;
  static String pathWordsThemeReveal(String theme) =>
      _t.pathWordsThemeReveal(theme);
  static String pathWordsBonusWord(String word) => _t.pathWordsBonusWord(word);
  static String pathWordsBonusCount(int count) => _t.pathWordsBonusCount(count);
  static String get pathWordsTapForMeaning => _t.pathWordsTapForMeaning;
  static String pathWordsWordWithMeaningLabel(String word) =>
      _t.pathWordsWordWithMeaningLabel(word);
  static String get weekendSpecial => _t.weekendSpecial;
  static String get retry => _t.retry;

  // Sudoku
  static String get sudokuTitle => _t.sudokuTitle;
  static String get sudokuTagline => _t.sudokuTagline;
  static String get playTodaysSudoku => _t.playTodaysSudoku;
  static String get sudokuHint => _t.sudokuHint;
  static String get sudokuHintUnitRegion => _t.sudokuHintUnitRegion;
  static String get sudokuHintUnitRow => _t.sudokuHintUnitRow;
  static String get sudokuHintUnitColumn => _t.sudokuHintUnitColumn;
  static String sudokuHintLastRemaining({
    required int digit,
    required String unit,
  }) => _t.sudokuHintLastRemaining(digit: digit, unit: unit);
  static String sudokuHintNakedSingle({required int digit}) =>
      _t.sudokuHintNakedSingle(digit: digit);
  static String get sudokuHintNoSimple => _t.sudokuHintNoSimple;
  static String sudokuHintMistakeInRow(int row) =>
      _t.sudokuHintMistakeInRow(row);
  static String get sudokuErase => _t.sudokuErase;
  static String get sudokuReset => _t.sudokuReset;
  static String get sudokuNotes => _t.sudokuNotes;
  static String get sudokuHowToPlayTitle => _t.sudokuHowToPlayTitle;
  static String get sudokuHowToPlayBody => _t.sudokuHowToPlayBody;
  static String get sudokuHowToPlayGotIt => _t.sudokuHowToPlayGotIt;
  static String get sudokuClearedTitle => _t.sudokuClearedTitle;
  static String get sudokuLoading => _t.sudokuLoading;
  static String get sudokuFailed => _t.sudokuFailed;
  static String get puzzleNeedsUpdate => _t.puzzleNeedsUpdate;
  static String get sudokuDifficultyEasy => _t.sudokuDifficultyEasy;
  static String get sudokuDifficultyMedium => _t.sudokuDifficultyMedium;
  static String get sudokuDifficultyHard => _t.sudokuDifficultyHard;

  // Results
  static String get newPersonalBest => _t.newPersonalBest;
  static String get newPuzzleUnlocksTomorrow => _t.newPuzzleUnlocksTomorrow;
  static String get newPuzzleReady => _t.newPuzzleReady;
  static String newPuzzleIn(Duration remaining) => _t.newPuzzleIn(remaining);
  static String get backHome => _t.backHome;
  static String playNextGame(String gameTitle) => _t.playNextGame(gameTitle);
  static String get perfectDay => _t.perfectDay;
  static String get shareResult => _t.shareResult;
  static String get shareFailed => _t.shareFailed;
  static String get resultsFullBoard => _t.resultsFullBoard;
  static String clearedIn(String time) => _t.clearedIn(time);
  static String rankToday(int rank) => _t.rankToday(rank);
  static String get resultsTimeLabel => _t.resultsTimeLabel;
  static String resultsHintPenalty(int seconds) =>
      _t.resultsHintPenalty(seconds);
  static String get resultsPointsLabel => _t.resultsPointsLabel;
  static String saveTimeToBoard(String timeLabel) =>
      _t.saveTimeToBoard(timeLabel);
  static String get saveTimeSignInTitle => _t.saveTimeSignInTitle;
  static String get saveTimeSignInBody => _t.saveTimeSignInBody;
  static String get resultsBoardTeaseHint => _t.resultsBoardTeaseHint;

  // Zip game branding (feature, not app title)
  static String get zipBrand => _t.zipBrand;
  static String streakLabel(int days) => _t.streakLabel(days);
  static String longestStreakLabel(int days) => _t.longestStreakLabel(days);

  // Stats
  static String get statsTitle => _t.statsTitle;
  static String get statsProfileRow => _t.statsProfileRow;
  static String get statsProfileRowHint => _t.statsProfileRowHint;
  static String get statsFailed => _t.statsFailed;
  static String get statsLocalOnly => _t.statsLocalOnly;
  static String get statsClears => _t.statsClears;
  static String get statsCurrentStreak => _t.statsCurrentStreak;
  static String get statsLongestStreak => _t.statsLongestStreak;
  static String get statsBestTime => _t.statsBestTime;
  static String get statsAverageTime => _t.statsAverageTime;
  static String get statsHintFree => _t.statsHintFree;
  static String get statsNoValue => _t.statsNoValue;
  static String statsPercent(double share) => _t.statsPercent(share);
  static String get statsTimesTitle => _t.statsTimesTitle;
  static String get statsTimesEmpty => _t.statsTimesEmpty;
  static String statsTimesBucket(int fromSeconds, {required bool open}) =>
      _t.statsTimesBucket(fromSeconds, open: open);
  static String statsTimesBucketSemantics(
    int fromSeconds,
    int? toSeconds,
    int count,
  ) => _t.statsTimesBucketSemantics(fromSeconds, toSeconds, count);
  static String statsClearCount(int count) => _t.statsClearCount(count);
  static String get statsCalendarTitle => _t.statsCalendarTitle;
  static String get statsCalendarEmpty => _t.statsCalendarEmpty;
  static String statsCalendarCleared(int days) => _t.statsCalendarCleared(days);
  static String get statsCalendarPrevious => _t.statsCalendarPrevious;
  static String get statsCalendarNext => _t.statsCalendarNext;
  static String get statsTrendTitle => _t.statsTrendTitle;
  static String get statsTrendSubtitle => _t.statsTrendSubtitle;
  static String get statsTrendEmpty => _t.statsTrendEmpty;
  static String get statsTrendTimes => _t.statsTrendTimes;
  static String get statsTrendBest => _t.statsTrendBest;
  static String get statsTrendToday => _t.statsTrendToday;
  static String statsTrendSemantics({
    required int clears,
    required int? bestSeconds,
  }) => _t.statsTrendSemantics(clears: clears, bestSeconds: bestSeconds);

  // Achievements
  static String get achievementsTitle => _t.achievementsTitle;
  static String achievementsProgress(int unlocked, int total) =>
      _t.achievementsProgress(unlocked, total);
  static String get achievementsFirstClearsSection =>
      _t.achievementsFirstClearsSection;
  static String get achievementsStreaksSection => _t.achievementsStreaksSection;
  static String get achievementsSpecialsSection =>
      _t.achievementsSpecialsSection;
  static String get achievementLocked => _t.achievementLocked;
  static String achievementFirstClearTitle(String game) =>
      _t.achievementFirstClearTitle(game);
  static String achievementFirstClearCondition(String game) =>
      _t.achievementFirstClearCondition(game);
  static String achievementStreakTitle(int days, String game) =>
      _t.achievementStreakTitle(days, game);
  static String achievementStreakCondition(int days, String game) =>
      _t.achievementStreakCondition(days, game);
  static String get achievementZipUnderMinuteTitle =>
      _t.achievementZipUnderMinuteTitle;
  static String get achievementZipUnderMinuteCondition =>
      _t.achievementZipUnderMinuteCondition;
  static String get achievementHintFreeWeekTitle =>
      _t.achievementHintFreeWeekTitle;
  static String get achievementHintFreeWeekCondition =>
      _t.achievementHintFreeWeekCondition;
  static String get achievementFlawlessSudokusTitle =>
      _t.achievementFlawlessSudokusTitle;
  static String get achievementFlawlessSudokusCondition =>
      _t.achievementFlawlessSudokusCondition;
  static String get achievementPerfectDayTitle => _t.achievementPerfectDayTitle;
  static String get achievementPerfectDayCondition =>
      _t.achievementPerfectDayCondition;

  // Badges: the Profile summary and the Badges screen
  static String achievementNext(String title) => _t.achievementNext(title);
  static String achievementStreakProgress(int current, int target) =>
      _t.achievementStreakProgress(current, target);
  static String get achievementsAllEarned => _t.achievementsAllEarned;
  static String get achievementLadderFirst => _t.achievementLadderFirst;
  static String achievementLadderDays(int days) =>
      _t.achievementLadderDays(days);
  static String get achievementsSpecial => _t.achievementsSpecial;
  static String get achievementEarned => _t.achievementEarned;
  static String achievementCurrentStreak(int days) =>
      _t.achievementCurrentStreak(days);
  static String newAchievementsTitle(int count) =>
      _t.newAchievementsTitle(count);
  static String newAchievementsList(List<String> titles) =>
      _t.newAchievementsList(titles);

  // Force update / soft update
  static String get updateRequiredTitle => _t.updateRequiredTitle;
  static String get updateAvailableTitle => _t.updateAvailableTitle;
  static String get updateRequiredBody => _t.updateRequiredBody;
  static String get updateAvailableBody => _t.updateAvailableBody;
  static String get updateNow => _t.updateNow;
  static String get updateCantSkip => _t.updateCantSkip;
  static String get updateSnooze => _t.updateSnooze;
  static String get updateDownloading => _t.updateDownloading;
  static String get updateRestart => _t.updateRestart;
  static String updateVersionRow(String current, String requiredLabel) =>
      _t.updateVersionRow(current, requiredLabel);

  // Auth / leaderboard
  static String get playSignInTitle => _t.playSignInTitle;
  static String get playSignInBody => _t.playSignInBody;
  static String get signInTitle => _t.signInTitle;
  static String get signInBody => _t.signInBody;
  static String get signInWithGoogle => _t.signInWithGoogle;
  static String get signInCancel => _t.signInCancel;
  static String get signInRequired => _t.signInRequired;
  static String get signOut => _t.signOut;
  static String get signOutConfirmTitle => _t.signOutConfirmTitle;
  static String get signOutConfirmBody => _t.signOutConfirmBody;
  static String get signOutConfirmCancel => _t.signOutConfirmCancel;
  static String get signOutConfirmNote => _t.signOutConfirmNote;
  static String get deleteAccount => _t.deleteAccount;
  static String get deleteAccountConfirmTitle => _t.deleteAccountConfirmTitle;
  static String get deleteAccountConfirmBody => _t.deleteAccountConfirmBody;
  static String get deleteAccountConfirmNote => _t.deleteAccountConfirmNote;
  static String get deleteAccountConfirmContinue =>
      _t.deleteAccountConfirmContinue;
  static String get deleteAccountOpenFailed => _t.deleteAccountOpenFailed;
  static String get leaderboardTitle => _t.leaderboardTitle;
  static String get leaderboardDaily => _t.leaderboardDaily;
  static String get leaderboardAllTime => _t.leaderboardAllTime;
  static String get leaderboardEmpty => _t.leaderboardEmpty;
  static String get leaderboardFailed => _t.leaderboardFailed;
  static String get leaderboardSignInHint => _t.leaderboardSignInHint;
  static String get seeFullLeaderboard => _t.seeFullLeaderboard;
  static String get leaderboardGapEllipsis => _t.leaderboardGapEllipsis;
  static String get youLabel => _t.youLabel;
  static String get leaderboardNoHintChip => _t.leaderboardNoHintChip;
  static String get leaderboardNoMistakesChip => _t.leaderboardNoMistakesChip;

  // Leaderboard: past days, the weekly board and leagues (roadmap area C)
  static String get leaderboardThisWeek => _t.leaderboardThisWeek;
  static String get leaderboardToday => _t.leaderboardToday;
  static String get leaderboardYesterday => _t.leaderboardYesterday;
  static String leaderboardShortDate(int day, int month) =>
      _t.leaderboardShortDate(day, month);
  static String leaderboardDaysCleared(int days) =>
      _t.leaderboardDaysCleared(days);
  static String leaderboardWeeklyRow(int days, String time) =>
      _t.leaderboardWeeklyRow(days, time);
  static String get leaderboardPastDayEmpty => _t.leaderboardPastDayEmpty;
  static String get leaderboardWeeklyEmpty => _t.leaderboardWeeklyEmpty;
  static String get leaderboardWeeklyDebugNote => _t.leaderboardWeeklyDebugNote;
  static String get leaderboardLeagueEmpty => _t.leaderboardLeagueEmpty;
  static String get leaderboardScopeEveryone => _t.leaderboardScopeEveryone;
  static String get leaderboardLeagues => _t.leaderboardLeagues;

  // Leaderboard: the board and scope pickers and the table
  static String get leaderboardBoardSheetTitle => _t.leaderboardBoardSheetTitle;
  static String get leaderboardScopeSheetTitle => _t.leaderboardScopeSheetTitle;
  static String get leaderboardThisWeekHint => _t.leaderboardThisWeekHint;
  static String get leaderboardAllTimeHint => _t.leaderboardAllTimeHint;
  static String get leaderboardSingleDayLabel => _t.leaderboardSingleDayLabel;
  static String get leaderboardColumnPlayer => _t.leaderboardColumnPlayer;
  static String get leaderboardColumnTime => _t.leaderboardColumnTime;
  static String get leaderboardColumnDays => _t.leaderboardColumnDays;
  static String get leaderboardColumnTotal => _t.leaderboardColumnTotal;
  static String get leaderboardColumnBest => _t.leaderboardColumnBest;
  static String get leaderboardTop50 => _t.leaderboardTop50;
  static String get leaderboardManageLeagues => _t.leaderboardManageLeagues;
  static String get leaderboardCreateOrJoinLeague =>
      _t.leaderboardCreateOrJoinLeague;
  static String leaderboardLeaguePlayers(int count) =>
      _t.leaderboardLeaguePlayers(count);
  static String leaderboardBoardPillLabel(String board) =>
      _t.leaderboardBoardPillLabel(board);
  static String leaderboardScopePillLabel(String scope) =>
      _t.leaderboardScopePillLabel(scope);
  static String playerCardRank(int rank) => _t.playerCardRank(rank);
  static String get playerCardTime => _t.playerCardTime;
  static String get playerCardWeekTotal => _t.playerCardWeekTotal;
  static String get playerCardDays => _t.playerCardDays;
  static String get gamePaused => _t.gamePaused;
  static String get gamePausedResume => _t.gamePausedResume;
  static String get leaguesTitle => _t.leaguesTitle;
  static String get leaguesIntro => _t.leaguesIntro;
  static String get leaguesEmpty => _t.leaguesEmpty;
  static String get leaguesFailed => _t.leaguesFailed;
  static String get leaguesSignIn => _t.leaguesSignIn;
  static String get leaguesCreate => _t.leaguesCreate;
  static String get leaguesJoin => _t.leaguesJoin;
  static String get leagueNameLabel => _t.leagueNameLabel;
  static String get leagueNameHint => _t.leagueNameHint;
  static String get leagueNameInvalid => _t.leagueNameInvalid;
  static String get leagueCodeLabel => _t.leagueCodeLabel;
  static String get leagueCodeHint => _t.leagueCodeHint;
  static String get leagueCodeInvalid => _t.leagueCodeInvalid;
  static String get leagueCreateAction => _t.leagueCreateAction;
  static String get leagueJoinAction => _t.leagueJoinAction;
  static String get leagueCancel => _t.leagueCancel;
  static String get leagueSave => _t.leagueSave;
  static String leagueMembers(int count) => _t.leagueMembers(count);
  static String get leagueOwner => _t.leagueOwner;
  static String leagueCode(String code) => _t.leagueCode(code);
  static String get leagueShareInvite => _t.leagueShareInvite;
  static String get leagueCopyCode => _t.leagueCopyCode;
  static String get leagueCodeCopied => _t.leagueCodeCopied;
  static String leagueInviteText(String name, String url) =>
      _t.leagueInviteText(name, url);
  static String get leagueMembersHeading => _t.leagueMembersHeading;
  static String get leagueMemberFallbackName => _t.leagueMemberFallbackName;
  static String get leagueLoadFailed => _t.leagueLoadFailed;
  static String get leagueRename => _t.leagueRename;
  static String get leagueRemove => _t.leagueRemove;
  static String leagueRemoveConfirm(String name) =>
      _t.leagueRemoveConfirm(name);
  static String get leagueLeave => _t.leagueLeave;
  static String get leagueLeaveConfirm => _t.leagueLeaveConfirm;
  static String get leagueDelete => _t.leagueDelete;
  static String get leagueDeleteConfirm => _t.leagueDeleteConfirm;
  static String get leagueGone => _t.leagueGone;
  static String get leagueSeeBoard => _t.leagueSeeBoard;
  static String get leagueActionFailed => _t.leagueActionFailed;
  static String get joinLeagueTitle => _t.joinLeagueTitle;
  static String get joinLeagueSignIn => _t.joinLeagueSignIn;
  static String joinLeagueNotFound(String code) => _t.joinLeagueNotFound(code);
  static String get joinLeagueBadCode => _t.joinLeagueBadCode;
  static String get joinLeagueFull => _t.joinLeagueFull;
  static String get joinLeagueButton => _t.joinLeagueButton;
  static String get joinLeagueAlreadyIn => _t.joinLeagueAlreadyIn;
  static String get pathWordsTab => _t.pathWordsTab;

  // Notifications
  static String get notifDailyReadyTitle => _t.notifDailyReadyTitle;
  static String get notifDailyReadyBody => _t.notifDailyReadyBody;
  static String get notifStreakAtRiskTitle => _t.notifStreakAtRiskTitle;

  // Habit: freezes, reminders, weekly recap, home-screen widget, Settings
  static String gameTitle(String gameId) => _t.gameTitle(gameId);
  static String streakFreezesReady(int count) => _t.streakFreezesReady(count);
  static String freezeCountLabel(int count) => _t.freezeCountLabel(count);
  static String freezeSavedStreak(String gameId, int days) =>
      _t.freezeSavedStreak(gameId, days);
  static String get dismiss => _t.dismiss;
  static String notifStreakEndsTonight(
    String gameId,
    int days, {
    int others = 0,
  }) => _t.notifStreakEndsTonight(gameId, days, others: others);
  static String get notifWeeklyRecapTitle => _t.notifWeeklyRecapTitle;
  static String weeklyRecapLine(WeeklyRecap recap, {bool lastWeek = false}) =>
      _t.weeklyRecapLine(recap, lastWeek: lastWeek);
  static String get homeRecapTitle => _t.homeRecapTitle;

  // Android notification channels
  static String get channelRemindersName => _t.channelRemindersName;
  static String get channelRemindersDescription =>
      _t.channelRemindersDescription;
  static String get channelAnnouncementsName => _t.channelAnnouncementsName;
  static String get channelAnnouncementsDescription =>
      _t.channelAnnouncementsDescription;

  // Home-screen widget
  static String get widgetCleared => _t.widgetCleared;
  static String widgetStreak(int days) => _t.widgetStreak(days);
  static String get widgetPlay => _t.widgetPlay;
  static String get widgetFooter => _t.widgetFooter;

  // Settings
  static String get profileSettings => _t.profileSettings;
  static String get settingsTitle => _t.settingsTitle;
  static String get settingsSoundSection => _t.settingsSoundSection;
  static String get settingsRemindersSection => _t.settingsRemindersSection;
  static String get settingsLanguageSection => _t.settingsLanguageSection;
  static String get settingsLanguageSystem => _t.settingsLanguageSystem;
  static String settingsLanguageSystemHint(String language) =>
      _t.settingsLanguageSystemHint(language);
  static String get languageEnglish => _t.languageEnglish;
  static String get languageMalayalam => _t.languageMalayalam;
  static String get settingsDailyReady => _t.settingsDailyReady;
  static String get settingsDailyReadyHint => _t.settingsDailyReadyHint;
  static String get settingsStreakAtRisk => _t.settingsStreakAtRisk;
  static String get settingsStreakAtRiskHint => _t.settingsStreakAtRiskHint;
  static String get settingsWeeklyRecap => _t.settingsWeeklyRecap;
  static String settingsWeeklyRecapHint(String time) =>
      _t.settingsWeeklyRecapHint(time);
  static String get settingsAnnouncements => _t.settingsAnnouncements;
  static String get settingsAnnouncementsHint => _t.settingsAnnouncementsHint;
  static String get settingsReminderTime => _t.settingsReminderTime;
  static String settingsReminderTimeLabel(String reminder, String time) =>
      _t.settingsReminderTimeLabel(reminder, time);

  // Dashboard nav
  static String get navHome => _t.navHome;
  static String get navLeaderboard => _t.navLeaderboard;
  static String get navProfile => _t.navProfile;

  // Profile
  static String get profileTitle => _t.profileTitle;
  static String get profileSignedOutTitle => _t.profileSignedOutTitle;
  static String get profileSignedOutBody => _t.profileSignedOutBody;
  static String get profileEditName => _t.profileEditName;
  static String get profileNameHint => _t.profileNameHint;
  static String get profileNameEmpty => _t.profileNameEmpty;
  static String get profileNameTooLong => _t.profileNameTooLong;
  static String get profileSave => _t.profileSave;
  static String get profileEditAvatar => _t.profileEditAvatar;
  static String get profileChoosePhoto => _t.profileChoosePhoto;
  static String get profilePresets => _t.profilePresets;
  static String get profileSaveFailed => _t.profileSaveFailed;
  static String get profilePhotoTooLarge => _t.profilePhotoTooLarge;
  static String get profileUploadFailed => _t.profileUploadFailed;
  static String get profilePermissionDenied => _t.profilePermissionDenied;
  static String get profileEditDisplayName => _t.profileEditDisplayName;
  static String get profileSoundEffects => _t.profileSoundEffects;
  static String get profileVibration => _t.profileVibration;
  static String get profilePrivacyPolicy => _t.profilePrivacyPolicy;
  static String get profileAboutGame => _t.profileAboutGame;
  static String get profileReportIssue => _t.profileReportIssue;
  static String get profileAboutBody => _t.profileAboutBody;
  static String get profileAboutGamesHeading => _t.profileAboutGamesHeading;
  static String get profileAboutDailyHeading => _t.profileAboutDailyHeading;
  static String get profileAboutDailyBody => _t.profileAboutDailyBody;
  static String profileAboutVersion(String version) =>
      _t.profileAboutVersion(version);
  static String get profileReportTitleLabel => _t.profileReportTitleLabel;
  static String get profileReportTitleHint => _t.profileReportTitleHint;
  static String get profileReportDescriptionLabel =>
      _t.profileReportDescriptionLabel;
  static String get profileReportDescriptionHint =>
      _t.profileReportDescriptionHint;
  static String get profileReportTitleEmpty => _t.profileReportTitleEmpty;
  static String get profileReportTitleTooLong => _t.profileReportTitleTooLong;
  static String get profileReportDescriptionEmpty =>
      _t.profileReportDescriptionEmpty;
  static String get profileReportDescriptionTooLong =>
      _t.profileReportDescriptionTooLong;
  static String get profileReportSend => _t.profileReportSend;
  static String get profileReportSent => _t.profileReportSent;
  static String get profileReportFailed => _t.profileReportFailed;
  static String get profilePrivacyFailed => _t.profilePrivacyFailed;
  static String get profilePrivacyRetry => _t.profilePrivacyRetry;

  // More ways to play: archive, practice and bonus games (roadmap area F)
  static String get moreWaysTitle => _t.moreWaysTitle;
  static String get moreWaysEntryHint => _t.moreWaysEntryHint;
  static String get archiveTitle => _t.archiveTitle;
  static String get archiveHint => _t.archiveHint;
  static String get practiceTitle => _t.practiceTitle;
  static String get practiceHint => _t.practiceHint;
  static String get bonusGamesTitle => _t.bonusGamesTitle;
  static String get bonusGamesHint => _t.bonusGamesHint;
  static String archiveRunLabel(DateTime day) => _t.archiveRunLabel(day);
  static String get practiceRunLabel => _t.practiceRunLabel;
  static String get practiceNewBoard => _t.practiceNewBoard;
  static String get hintUnlimited => _t.hintUnlimited;
  static String hintWithCost(int seconds) => _t.hintWithCost(seconds);
  static String localBest(String time) => _t.localBest(time);
  static String archiveBest(String time) => _t.archiveBest(time);
  static String get newLocalBest => _t.newLocalBest;
  static String get backToArchive => _t.backToArchive;
  static String get archivePickGame => _t.archivePickGame;
  static String archiveMonthCleared(int days) => _t.archiveMonthCleared(days);
  static String get archiveDayCleared => _t.archiveDayCleared;
  static String get archiveDayOpen => _t.archiveDayOpen;
  static String get archivePrevious => _t.archivePrevious;
  static String get archiveNext => _t.archiveNext;
  static String get archiveLegend => _t.archiveLegend;
  static String pathWordsThemeOf(String theme) => _t.pathWordsThemeOf(theme);
  static String get archiveOpenHint => _t.archiveOpenHint;
  static String get practicePickGame => _t.practicePickGame;
  static String get wordMatchHint => _t.wordMatchHint;
  static String get categoryRaceHint => _t.categoryRaceHint;
  static String get archiveEmpty => _t.archiveEmpty;
  static String bonusRunLabel(String game, String item) =>
      _t.bonusRunLabel(game, item);
  static String get bonusLoadFailed => _t.bonusLoadFailed;
  static String get resultsPairsLabel => _t.resultsPairsLabel;
  static String bonusSecondsLeft(int seconds) => _t.bonusSecondsLeft(seconds);
  static String wordMatchPairs(int n) => _t.wordMatchPairs(n);
  static String get wordMatchNoDecks => _t.wordMatchNoDecks;
  static String get wordMatchDeckMissing => _t.wordMatchDeckMissing;
  static String get wordMatchInstruction => _t.wordMatchInstruction;
  static String get wordMatchCleared => _t.wordMatchCleared;
  static String get wordMatchTimeUp => _t.wordMatchTimeUp;
  static String wordMatchMatched(int matched, int total) =>
      _t.wordMatchMatched(matched, total);
  static String get wordMatchHowToBody => _t.wordMatchHowToBody;
  static String get categoryRaceHowToBody => _t.categoryRaceHowToBody;
  static String categoryRaceStart(int seconds) => _t.categoryRaceStart(seconds);
  static String categoryRaceInstruction(String letter) =>
      _t.categoryRaceInstruction(letter);
  static String get categoryRaceYourWord => _t.categoryRaceYourWord;
  static String get categoryRaceSubmit => _t.categoryRaceSubmit;
  static String categoryRaceAccepted(int n) => _t.categoryRaceAccepted(n);
  static String categoryRaceMustStart(String letter) =>
      _t.categoryRaceMustStart(letter);
  static String categoryRaceNotIn(String category) =>
      _t.categoryRaceNotIn(category);
  static String get categoryRaceAlreadyUsed => _t.categoryRaceAlreadyUsed;
  static String get categoryRaceRoundOver => _t.categoryRaceRoundOver;
  static String get categoryRaceNoCategories => _t.categoryRaceNoCategories;
  static String get resultsWordsLabel => _t.resultsWordsLabel;
  static String localBestScore(int words) => _t.localBestScore(words);

  // Copy moved out of widgets and repositories (roadmap area G)
  static String get resultsTitle => _t.resultsTitle;
  static String get resultsNextPuzzle => _t.resultsNextPuzzle;
  static String get leaderboardYourRank => _t.leaderboardYourRank;
  static String leaderboardPlayGame(String game) =>
      _t.leaderboardPlayGame(game);
  static String get playerFallbackName => _t.playerFallbackName;
  static String shareHeadline(String game, DateTime day) =>
      _t.shareHeadline(game, day);
  static String get signInFailed => _t.signInFailed;
  static String get serviceUnavailable => _t.serviceUnavailable;
  static String get signInRequiredShort => _t.signInRequiredShort;
  static String get profileUpdateFailed => _t.profileUpdateFailed;
  static String get profileLoadFailed => _t.profileLoadFailed;
  static String get avatarUploadUnavailable => _t.avatarUploadUnavailable;
  static String get avatarInvalid => _t.avatarInvalid;
  static String get leaguesSignedOut => _t.leaguesSignedOut;
  static String get leagueLookupFailed => _t.leagueLookupFailed;
  static String get leagueCreateFailed => _t.leagueCreateFailed;
  static String get leagueCreateRetry => _t.leagueCreateRetry;
  static String get leagueJoinFailed => _t.leagueJoinFailed;
  static String get leagueLeaveFailed => _t.leagueLeaveFailed;
  static String get leagueRemoveFailed => _t.leagueRemoveFailed;
  static String get leagueRenameFailed => _t.leagueRenameFailed;
  static String get leagueDeleteFailed => _t.leagueDeleteFailed;
  static String get leagueNameLength => _t.leagueNameLength;
  static String get leagueCodeNotFound => _t.leagueCodeNotFound;
}
