import '../../domain/habit/weekly_recap.dart';

/// Every user-facing string, one member per string. `AppStrings` delegates
/// to the table for the current language (`AppTextEn`, `AppTextMl`); a new
/// language is a new implementation of this interface.
///
/// Implementations implement it in full (never extend another table), so
/// the compiler asks for every string. Strings that are deliberately the
/// same in every language (game names, "Winklo", symbols) are returned
/// explicitly.
abstract interface class AppText {
  String get appTitle;

  // Home
  String get homeTagline;
  String get zipTitle;
  String get zipTagline;
  String get playTodaysZip;
  String get zipUndo;
  String get zipClear;
  String get zipReplay;
  String get zipHint;
  String get zipHowToPlayTitle;
  String get zipTutorialStart;
  String get zipTutorialFinish;
  String get zipTutorialFillEveryCell;
  String get zipTutorialWalls;
  String get zipHowToPlayGotIt;
  String get tutorialGotIt;
  String get tutorialSkip;
  String get tutorialNext;
  String get zipTipStartAtOne;
  String get zipTipFillEveryCell;
  String get zipTipFinishOnLast;
  String get zipTipVisitInOrder;
  String get zipClearedTitle;
  String get zipLoading;
  String get zipFailed;
  String get playAgain;
  String get result;
  String get today;
  String get wordMatch;
  String get categoryRace;
  String get streakProtectedLabel;
  String get cleared;
  String bestTimeLabel(String formatted);
  String get streakFreezeReady;

  /// "Best 0:48 · Longest streak 9" under a Home tile's title; empty when
  /// there is nothing to show yet. Streaks count from 2 days, as on the
  /// leaderboard.
  String homeTileStats({int? bestSeconds, int longestStreak});

  /// "2 of 3 cleared · 3:41 total" above the Home tiles.
  String homeTodaySummary({
    required int cleared,
    required int total,
    int? totalSeconds,
  });
  String get homePerfectDayBadge;

  /// The small chip next to the Home title.
  String get homeDailyBadge;

  // Path Words
  String get pathWordsTitle;
  String get pathWordsTagline;
  String get playTodaysPathWords;
  String get pathWordsUndo;
  String get pathWordsHint;
  String get pathWordsHowToPlayTitle;
  String get pathWordsTutorialMatchList;
  String get pathWordsTutorialFindEveryWord;
  String get pathWordsTutorialFillEveryCell;
  String get pathWordsHowToPlayGotIt;
  String get pathWordsTipMatchList;
  String pathWordsUnfoundWordLabel(int letterCount);
  String pathWordsTracingWordLabel(String letters);
  String get pathWordsClearedTitle;
  String get pathWordsLoading;
  String get pathWordsFailed;
  String pathWordsThemeReveal(String theme);
  String pathWordsBonusWord(String word);
  String pathWordsBonusCount(int count);
  String get pathWordsTapForMeaning;
  String pathWordsWordWithMeaningLabel(String word);
  String get weekendSpecial;
  String get retry;

  // Sudoku
  String get sudokuTitle;
  String get sudokuTagline;
  String get playTodaysSudoku;
  String get sudokuHint;
  String get sudokuHintUnitRegion;
  String get sudokuHintUnitRow;
  String get sudokuHintUnitColumn;
  String sudokuHintLastRemaining({required int digit, required String unit});
  String sudokuHintNakedSingle({required int digit});
  String get sudokuHintNoSimple;
  String sudokuHintMistakeInRow(int row);
  String get sudokuErase;
  String get sudokuReset;
  String get sudokuNotes;
  String get sudokuHowToPlayTitle;
  String get sudokuHowToPlayBody;
  String get sudokuHowToPlayGotIt;
  String get sudokuClearedTitle;
  String get sudokuLoading;
  String get sudokuFailed;
  String get puzzleNeedsUpdate;
  String get sudokuDifficultyEasy;
  String get sudokuDifficultyMedium;
  String get sudokuDifficultyHard;

  // Results
  String get newPersonalBest;
  String get newPuzzleUnlocksTomorrow;
  String get newPuzzleReady;

  /// "New puzzle in 6h 12m". Minutes round up, so the last minute reads 1m
  /// rather than 0m.
  String newPuzzleIn(Duration remaining);
  String get backHome;
  String playNextGame(String gameTitle);
  String get perfectDay;
  String get shareResult;
  String get shareFailed;
  String get resultsFullBoard;
  String clearedIn(String time);
  String rankToday(int rank);
  String get resultsTimeLabel;
  String resultsHintPenalty(int seconds);
  String get resultsPointsLabel;
  String saveTimeToBoard(String timeLabel);
  String get saveTimeSignInTitle;
  String get saveTimeSignInBody;
  String get resultsBoardTeaseHint;

  /// "of 18 today" under the rank on Results; "of 50+ today" when the board
  /// filled its row limit.
  String resultsRankOfToday(int total, {bool capped = false});

  /// "Rank 14 of 18 today", read for the rank badge.
  String resultsRankSemantics(int rank, int total, {bool capped = false});

  /// "+20s", the time hints added, on a Results tile.
  String resultsHintTimeTile(int seconds);

  /// "from hints", under [resultsHintTimeTile].
  String get resultsFromHints;

  /// The two sides of the Board | Words switch on a Path Words result.
  String get resultsBoardTab;
  String resultsWordsTab(int count);

  // Zip game branding (feature, not app title)
  String get zipBrand;
  String streakLabel(int days);
  String longestStreakLabel(int days);

  // Stats
  String get statsTitle;
  String get statsProfileRow;
  String get statsProfileRowHint;
  String get statsFailed;
  String get statsLocalOnly;
  String get statsClears;
  String get statsCurrentStreak;
  String get statsLongestStreak;
  String get statsBestTime;
  String get statsAverageTime;
  String get statsHintFree;
  String get statsNoValue;
  String statsPercent(double share);
  String get statsTimesTitle;
  String get statsTimesEmpty;

  /// Lower edge of a histogram bar; the open-ended last bar reads "4:00+".
  String statsTimesBucket(int fromSeconds, {required bool open});
  String statsTimesBucketSemantics(int fromSeconds, int? toSeconds, int count);
  String statsClearCount(int count);
  String get statsCalendarTitle;
  String get statsCalendarEmpty;
  String statsCalendarCleared(int days);
  String get statsCalendarPrevious;
  String get statsCalendarNext;
  String get statsTrendTitle;
  String get statsTrendSubtitle;
  String get statsTrendEmpty;
  String get statsTrendTimes;
  String get statsTrendBest;
  String get statsTrendToday;
  String statsTrendSemantics({required int clears, required int? bestSeconds});

  // Achievements
  String get achievementsTitle;
  String achievementsProgress(int unlocked, int total);
  String get achievementsFirstClearsSection;
  String get achievementsStreaksSection;
  String get achievementsSpecialsSection;
  String get achievementLocked;
  String achievementFirstClearTitle(String game);
  String achievementFirstClearCondition(String game);
  String achievementStreakTitle(int days, String game);
  String achievementStreakCondition(int days, String game);
  String get achievementZipUnderMinuteTitle;
  String get achievementZipUnderMinuteCondition;
  String get achievementHintFreeWeekTitle;
  String get achievementHintFreeWeekCondition;
  String get achievementFlawlessSudokusTitle;
  String get achievementFlawlessSudokusCondition;
  String get achievementPerfectDayTitle;
  String get achievementPerfectDayCondition;

  // Badges: the Profile summary and the Badges screen
  String achievementNext(String title);
  String achievementStreakProgress(int current, int target);
  String get achievementsAllEarned;
  String get achievementLadderFirst;
  String achievementLadderDays(int days);
  String get achievementsSpecial;
  String get achievementEarned;
  String achievementCurrentStreak(int days);
  String newAchievementsTitle(int count);

  /// "First Zip", "First Zip and Perfect day", "First Zip, Perfect day and
  /// 2 more".
  String newAchievementsList(List<String> titles);

  // Force update / soft update
  String get updateRequiredTitle;
  String get updateAvailableTitle;
  String get updateRequiredBody;
  String get updateAvailableBody;
  String get updateNow;
  String get updateCantSkip;
  String get updateSnooze;
  String get updateDownloading;
  String get updateRestart;
  String updateVersionRow(String current, String requiredLabel);

  // Auth / leaderboard
  String get playSignInTitle;
  String get playSignInBody;
  String get signInTitle;
  String get signInBody;
  String get signInWithGoogle;
  String get signInCancel;
  String get signInRequired;
  String get signOut;
  String get signOutConfirmTitle;
  String get signOutConfirmBody;
  String get signOutConfirmCancel;
  String get signOutConfirmNote;
  String get deleteAccount;
  String get deleteAccountConfirmTitle;
  String get deleteAccountConfirmBody;
  String get deleteAccountConfirmNote;
  String get deleteAccountConfirmContinue;
  String get deleteAccountOpenFailed;
  String get leaderboardTitle;
  String get leaderboardDaily;
  String get leaderboardAllTime;
  String get leaderboardEmpty;
  String get leaderboardFailed;
  String get leaderboardSignInHint;
  String get seeFullLeaderboard;
  String get leaderboardGapEllipsis;
  String get youLabel;
  String get leaderboardNoHintChip;
  String get leaderboardNoMistakesChip;

  /// The badge key's name for the streak flame.
  String get leaderboardKeyStreak;

  /// Under the pinned row: how far you are behind the player at [rank].
  String leaderboardBehind(String gap, int rank);

  /// A podium place read aloud.
  String leaderboardPodiumSemantics(int rank, String name, String time);

  /// Days cleared this week, under a weekly podium time.
  String leaderboardDaysShort(int days);

  // Leaderboard: past days, the weekly board and leagues (roadmap area C)
  String get leaderboardThisWeek;
  String get leaderboardToday;
  String get leaderboardYesterday;
  String leaderboardShortDate(int day, int month);
  String leaderboardDaysCleared(int days);
  String leaderboardWeeklyRow(int days, String time);
  String get leaderboardPastDayEmpty;
  String get leaderboardWeeklyEmpty;
  String get leaderboardWeeklyDebugNote;
  String get leaderboardLeagueEmpty;
  String get leaderboardScopeEveryone;
  String get leaderboardLeagues;

  // Leaderboard: the board and scope pickers and the table
  String get leaderboardBoardSheetTitle;
  String get leaderboardScopeSheetTitle;
  String get leaderboardThisWeekHint;
  String get leaderboardAllTimeHint;
  String get leaderboardSingleDayLabel;
  String get leaderboardColumnPlayer;
  String get leaderboardColumnTime;
  String get leaderboardColumnDays;
  String get leaderboardColumnTotal;
  String get leaderboardColumnBest;
  String get leaderboardTop50;
  String get leaderboardManageLeagues;
  String get leaderboardCreateOrJoinLeague;
  String leaderboardLeaguePlayers(int count);
  String leaderboardBoardPillLabel(String board);
  String leaderboardScopePillLabel(String scope);

  String playerCardRank(int rank);
  String get playerCardTime;
  String get playerCardWeekTotal;
  String get playerCardDays;
  String get gamePaused;
  String get gamePausedResume;
  String get leaguesTitle;
  String get leaguesIntro;
  String get leaguesEmpty;
  String get leaguesFailed;
  String get leaguesSignIn;
  String get leaguesCreate;
  String get leaguesJoin;
  String get leagueNameLabel;
  String get leagueNameHint;
  String get leagueNameInvalid;
  String get leagueCodeLabel;
  String get leagueCodeHint;
  String get leagueCodeInvalid;
  String get leagueCreateAction;
  String get leagueJoinAction;
  String get leagueCancel;
  String get leagueSave;
  String leagueMembers(int count);
  String get leagueOwner;
  String leagueCode(String code);
  String get leagueShareInvite;
  String get leagueCopyCode;
  String get leagueCodeCopied;
  String leagueInviteText(String name, String url);
  String get leagueMembersHeading;
  String get leagueMemberFallbackName;
  String get leagueLoadFailed;
  String get leagueRename;
  String get leagueRemove;
  String leagueRemoveConfirm(String name);
  String get leagueLeave;
  String get leagueLeaveConfirm;
  String get leagueDelete;
  String get leagueDeleteConfirm;
  String get leagueGone;
  String get leagueSeeBoard;
  String get leagueActionFailed;
  String get joinLeagueTitle;
  String get joinLeagueSignIn;
  String joinLeagueNotFound(String code);
  String get joinLeagueBadCode;
  String get joinLeagueFull;
  String get joinLeagueButton;
  String get joinLeagueAlreadyIn;

  /// Compact game-tab label (full title stays [pathWordsTitle]).
  String get pathWordsTab;

  // Notifications
  String get notifDailyReadyTitle;
  String get notifDailyReadyBody;
  String get notifStreakAtRiskTitle;

  // Habit: freezes, reminders, weekly recap, home-screen widget, Settings
  String gameTitle(String gameId);
  String streakFreezesReady(int count);
  String freezeCountLabel(int count);
  String freezeSavedStreak(String gameId, int days);
  String get dismiss;

  /// "Your 12-day Zip streak ends at midnight", or "… and 2 more end …".
  String notifStreakEndsTonight(String gameId, int days, {int others});
  String get notifWeeklyRecapTitle;

  /// "This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak".
  String weeklyRecapLine(WeeklyRecap recap, {bool lastWeek});
  String get homeRecapTitle;

  // Android notification channels
  String get channelRemindersName;
  String get channelRemindersDescription;
  String get channelAnnouncementsName;
  String get channelAnnouncementsDescription;

  // Home-screen widget
  String get widgetCleared;
  String widgetStreak(int days);
  String get widgetPlay;
  String get widgetFooter;

  // Settings
  String get profileSettings;
  String get settingsTitle;
  String get settingsSoundSection;
  String get settingsRemindersSection;
  String get settingsLanguageSection;

  /// The Language row that follows the phone.
  String get settingsLanguageSystem;

  /// Under System: the language it gives now, named in its own script.
  String settingsLanguageSystemHint(String language);

  /// Each language is named in its own script, whatever the app shows.
  String get languageEnglish;
  String get languageMalayalam;
  String get settingsDailyReady;
  String get settingsDailyReadyHint;
  String get settingsStreakAtRisk;
  String get settingsStreakAtRiskHint;
  String get settingsWeeklyRecap;
  String settingsWeeklyRecapHint(String time);
  String get settingsAnnouncements;
  String get settingsAnnouncementsHint;
  String get settingsReminderTime;
  String settingsReminderTimeLabel(String reminder, String time);

  // Dashboard nav
  String get navHome;
  String get navLeaderboard;
  String get navProfile;

  // Profile
  String get profileTitle;
  String get profileSignedOutTitle;
  String get profileSignedOutBody;
  String get profileEditName;
  String get profileNameHint;
  String get profileNameEmpty;
  String get profileNameTooLong;
  String get profileSave;
  String get profileEditAvatar;
  String get profileChoosePhoto;
  String get profileAvatarHint;
  String get profileAvatarPhoto;
  String get avatarCritterFox;
  String get avatarCritterCat;
  String get avatarCritterOwl;
  String get avatarCritterFrog;
  String get avatarCritterPanda;
  String get avatarCritterBunny;
  String get avatarCritterPenguin;
  String get avatarCritterTiger;
  String get avatarCritterKoala;
  String get avatarCritterBear;
  String get avatarCritterRaccoon;
  String get avatarCritterChick;
  String get profileSaveFailed;
  String get profilePhotoTooLarge;
  String get profileUploadFailed;
  String get profilePermissionDenied;
  String get profileEditDisplayName;
  String get profileSoundEffects;
  String get profileVibration;
  String get profilePrivacyPolicy;
  String get profileAboutGame;
  String get profileRateOnPlayStore;
  String get reviewOpenStoreFailed;
  String get profileReportIssue;
  String get profileAboutBody;
  String get profileAboutGamesHeading;
  String get profileAboutDailyHeading;
  String get profileAboutDailyBody;
  String profileAboutVersion(String version);
  String get profileReportTitleLabel;
  String get profileReportTitleHint;
  String get profileReportDescriptionLabel;
  String get profileReportDescriptionHint;
  String get profileReportTitleEmpty;
  String get profileReportTitleTooLong;
  String get profileReportDescriptionEmpty;
  String get profileReportDescriptionTooLong;
  String get profileReportSend;
  String get profileReportSent;
  String get profileReportFailed;
  String get profilePrivacyFailed;
  String get profilePrivacyRetry;

  // More ways to play: archive, practice and bonus games (roadmap area F)
  String get moreWaysTitle;
  String get moreWaysEntryHint;
  String get archiveTitle;
  String get archiveHint;
  String get practiceTitle;
  String get practiceHint;
  String get bonusGamesTitle;
  String get bonusGamesHint;
  String archiveRunLabel(DateTime day);
  String get practiceRunLabel;
  String get practiceNewBoard;
  String get hintUnlimited;
  String hintWithCost(int seconds);
  String localBest(String time);
  String archiveBest(String time);
  String get newLocalBest;
  String get backToArchive;
  String get archivePickGame;
  String archiveMonthCleared(int days);
  String get archiveDayCleared;
  String get archiveDayOpen;
  String get archivePrevious;
  String get archiveNext;
  String get archiveLegend;
  String pathWordsThemeOf(String theme);
  String get archiveOpenHint;
  String get practicePickGame;
  String get wordMatchHint;
  String get categoryRaceHint;
  String get archiveEmpty;
  String bonusRunLabel(String game, String item);
  String get bonusLoadFailed;
  String get resultsPairsLabel;
  String bonusSecondsLeft(int seconds);
  String wordMatchPairs(int n);
  String get wordMatchNoDecks;
  String get wordMatchDeckMissing;
  String get wordMatchInstruction;
  String get wordMatchCleared;
  String get wordMatchTimeUp;
  String wordMatchMatched(int matched, int total);
  String get wordMatchHowToBody;
  String get categoryRaceHowToBody;
  String categoryRaceStart(int seconds);
  String categoryRaceInstruction(String letter);
  String get categoryRaceYourWord;
  String get categoryRaceSubmit;
  String categoryRaceAccepted(int n);
  String categoryRaceMustStart(String letter);
  String categoryRaceNotIn(String category);
  String get categoryRaceAlreadyUsed;
  String get categoryRaceRoundOver;
  String get categoryRaceNoCategories;
  String get resultsWordsLabel;
  String localBestScore(int words);

  // Levels
  String get levelsTitle;

  /// A world's name from its theme (`ink`, `metro`, …); [levelsTitle] for
  /// an unknown theme.
  String levelWorldName(String theme);
  String levelRunLabel(int number, String worldName);
  String levelClearedTitle(int number);
  String get levelFailed;
  String get levelHintCostsStar;
  String levelTarget(String time);
  String get levelGoalClear;
  String get levelGoalNoHints;
  String levelGoalUnder(String time);
  String get levelGoalNoHintsHow;
  String levelGoalUnderHow(String time);
  String levelNewBestStars(int from, int to);
  String get levelNewBestTime;
  String get levelNext;
  String levelOpenWorld(String worldName);
  String get levelReplay;
  String get levelAllDone;

  // Copy moved out of widgets and repositories (roadmap area G)
  String get resultsTitle;
  String get resultsNextPuzzle;
  String get leaderboardYourRank;
  String leaderboardPlayGame(String game);

  /// Shown for a player with no name on a board or in a league.
  String get playerFallbackName;

  /// The first line of a shared result: "Winklo Zip · 9 Oct".
  String shareHeadline(String game, DateTime day);
  String get signInFailed;
  String get serviceUnavailable;
  String get signInRequiredShort;
  String get profileUpdateFailed;
  String get profileLoadFailed;
  String get avatarUploadUnavailable;
  String get avatarInvalid;
  String get leaguesSignedOut;
  String get leagueLookupFailed;
  String get leagueCreateFailed;
  String get leagueCreateRetry;
  String get leagueJoinFailed;
  String get leagueLeaveFailed;
  String get leagueRemoveFailed;
  String get leagueRenameFailed;
  String get leagueDeleteFailed;
  String get leagueNameLength;
  String get leagueCodeNotFound;
}
