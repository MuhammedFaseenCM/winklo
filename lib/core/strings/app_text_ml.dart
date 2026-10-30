import '../../domain/game_ids.dart';
import '../../domain/hint_penalty.dart';
import '../../domain/habit/weekly_recap.dart';
import 'app_text.dart';
import 'play_time_format.dart';

/// Malayalam: short, friendly copy, in the polite imperative (കളിക്കൂ,
/// ശ്രമിക്കൂ). Gaming words players already use stay as loanwords
/// (സ്ട്രീക്ക്, ലീഡർബോർഡ്, റാങ്ക്, ലീഗ്); the game names Zip, Path Words
/// and Sudoku, and Winklo, stay English. Western digits.
///
/// Needs a native speaker's review before release (see the README).
final class AppTextMl implements AppText {
  const AppTextMl();

  /// CLDR's `ml` short months (what intl's `MMM` gives).
  static const _shortMonths = [
    'ജനു',
    'ഫെബ്രു',
    'മാർ',
    'ഏപ്രി',
    'മേയ്',
    'ജൂൺ',
    'ജൂലൈ',
    'ഓഗ',
    'സെപ്റ്റം',
    'ഒക്ടോ',
    'നവം',
    'ഡിസം',
  ];

  @override
  String get appTitle => 'Winklo';

  // Home
  @override
  String get homeTagline => 'ഒറ്റയ്ക്ക് കളിക്കാൻ കുഞ്ഞു ഗെയിമുകൾ.';

  @override
  String get zipTitle => 'Zip';

  @override
  String get zipTagline => '1 മുതൽ അവസാനം വരെ എല്ലാ കളങ്ങളും നിറയ്ക്കൂ.';

  @override
  String get playTodaysZip => 'ഇന്നത്തെ Zip കളിക്കൂ';

  @override
  String get zipUndo => 'പഴയപടി';

  @override
  String get zipClear => 'മായ്ക്കൂ';

  @override
  String get zipReplay => 'റീപ്ലേ';

  @override
  String get zipHint => 'സൂചന';

  @override
  String get zipHowToPlayTitle => 'എങ്ങനെ കളിക്കാം';

  @override
  String get zipTutorialStart => '1-ൽ തുടങ്ങൂ';

  @override
  String get zipTutorialFinish => 'അവസാന നമ്പറിൽ നിർത്തൂ';

  @override
  String get zipTutorialFillEveryCell => 'എല്ലാ കളങ്ങളും നിറയ്ക്കൂ';

  @override
  String get zipTutorialWalls => 'ചുമരുകൾ വഴി തടയും';

  @override
  String get zipHowToPlayGotIt => 'മനസ്സിലായി';

  @override
  String get tutorialGotIt => 'മനസ്സിലായി';

  @override
  String get tutorialSkip => 'ഒഴിവാക്കൂ';

  @override
  String get tutorialNext => 'അടുത്തത്';

  @override
  String get zipTipStartAtOne => '1-ൽ തുടങ്ങൂ';

  @override
  String get zipTipFillEveryCell => 'തീർക്കും മുമ്പ് എല്ലാ കളങ്ങളും നിറയ്ക്കൂ';

  @override
  String get zipTipFinishOnLast => 'അവസാന നമ്പറിൽ നിർത്തൂ';

  @override
  String get zipTipVisitInOrder => 'നമ്പറുകൾ ക്രമത്തിൽ തൊടൂ';

  @override
  String get zipClearedTitle => 'പൂർത്തിയായി!';

  @override
  String get zipLoading => 'ഇന്നത്തെ പസിൽ ഒരുക്കുന്നു…';

  @override
  String get zipFailed => 'ഇന്നത്തെ പസിൽ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get playAgain => 'വീണ്ടും കളിക്കൂ';

  @override
  String get result => 'ഫലം';

  @override
  String get today => 'ഇന്ന്';

  @override
  String get wordMatch => 'വാക്കുജോടി';

  @override
  String get categoryRace => 'വാക്കോട്ടം';

  @override
  String get streakProtectedLabel => 'സ്ട്രീക്ക് സുരക്ഷിതം';

  @override
  String get cleared => 'പൂർത്തിയായി';

  @override
  String bestTimeLabel(String formatted) => 'മികച്ചത് $formatted';

  @override
  String get streakFreezeReady =>
      'സ്ട്രീക്ക് ഫ്രീസ് റെഡി: ഒരു ദിവസം വിട്ടുപോയാലും സ്ട്രീക്ക് തുടരും.';

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
    '$total-ൽ $cleared പൂർത്തിയായി',
    if (totalSeconds != null) 'ആകെ ${formatPlayTime(totalSeconds)}',
  ].join(' · ');

  @override
  String get homePerfectDayBadge => 'സമ്പൂർണ ദിനം';

  @override
  String get homeDailyBadge => 'ദിവസേന';

  // Path Words
  @override
  String get pathWordsTitle => 'Path Words';

  @override
  String get pathWordsTagline => 'ഗ്രിഡിൽ ഓരോ വാക്കും വരച്ചെടുക്കൂ.';

  @override
  String get playTodaysPathWords => 'ഇന്നത്തെ Path Words കളിക്കൂ';

  @override
  String get pathWordsUndo => 'പഴയപടി';

  @override
  String get pathWordsHint => 'സൂചന';

  @override
  String get pathWordsHowToPlayTitle => 'എങ്ങനെ കളിക്കാം';

  @override
  String get pathWordsTutorialMatchList => 'ലിസ്റ്റിലെ ഒരു വാക്ക് കണ്ടെത്തൂ';

  @override
  String get pathWordsTutorialFindEveryWord => 'എല്ലാ വാക്കുകളും കണ്ടെത്തൂ';

  @override
  String get pathWordsTutorialFillEveryCell => 'എല്ലാ കളങ്ങളും നിറയണം';

  @override
  String get pathWordsHowToPlayGotIt => 'മനസ്സിലായി';

  @override
  String get pathWordsTipMatchList =>
      'ആ വാക്ക് ലിസ്റ്റിലില്ല — ലിസ്റ്റിലുള്ളത് കണ്ടെത്തൂ';

  @override
  String pathWordsUnfoundWordLabel(int letterCount) =>
      '$letterCount അക്ഷരമുള്ള വാക്ക്, ഇനിയും കണ്ടെത്തിയിട്ടില്ല';

  @override
  String pathWordsTracingWordLabel(String letters) =>
      '${letters.toUpperCase()} വരയ്ക്കുന്നു';

  @override
  String get pathWordsClearedTitle => 'പൂർത്തിയായി!';

  @override
  String get pathWordsLoading => 'ഇന്നത്തെ പസിൽ ഒരുക്കുന്നു…';

  @override
  String get pathWordsFailed => 'ഇന്നത്തെ പസിൽ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String pathWordsThemeReveal(String theme) => 'ഇന്ന്: $theme';

  @override
  String pathWordsBonusWord(String word) =>
      'ബോണസ് വാക്ക്: ${word.toUpperCase()}';

  @override
  String pathWordsBonusCount(int count) =>
      count == 1 ? '1 ബോണസ് വാക്ക്' : '$count ബോണസ് വാക്കുകൾ';

  @override
  String get pathWordsTapForMeaning => 'അർത്ഥം അറിയാൻ ഒരു വാക്കിൽ തൊടൂ';

  @override
  String pathWordsWordWithMeaningLabel(String word) =>
      '${word.toUpperCase()}, അർത്ഥത്തിന് തൊടൂ';

  @override
  String get weekendSpecial => 'വാരാന്ത്യ സ്പെഷ്യൽ';

  @override
  String get retry => 'വീണ്ടും ശ്രമിക്കൂ';

  // Sudoku
  @override
  String get sudokuTitle => 'Sudoku';

  @override
  String get sudokuTagline => 'എല്ലാ കളങ്ങളിലും 1–6 നിറയ്ക്കൂ.';

  @override
  String get playTodaysSudoku => 'ഇന്നത്തെ Sudoku കളിക്കൂ';

  @override
  String get sudokuHint => 'സൂചന';

  // Rows are വരി and columns നിര, as in Kerala school maths.
  @override
  String get sudokuHintUnitRegion => 'ബോക്സ്';

  @override
  String get sudokuHintUnitRow => 'വരി';

  @override
  String get sudokuHintUnitColumn => 'നിര';

  /// "in this row" for the units above.
  static String _inThis(String unit) => switch (unit) {
    'വരി' => 'ഈ വരിയിലെ',
    'നിര' => 'ഈ നിരയിലെ',
    'ബോക്സ്' => 'ഈ ബോക്സിലെ',
    _ => 'ഈ $unit-ലെ',
  };

  @override
  String sudokuHintLastRemaining({required int digit, required String unit}) =>
      '${_inThis(unit)} മറ്റ് കളങ്ങളെല്ലാം മറ്റ് $digit-കൾ തടയുന്നതിനാൽ '
      'ഈ കളത്തിൽ $digit തന്നെ വരണം.';

  @override
  String sudokuHintNakedSingle({required int digit}) =>
      'ഈ കളത്തിൽ $digit തന്നെ വരണം — മറ്റേത് അക്കം ഇട്ടാലും വരിയിലോ '
      'നിരയിലോ ബോക്സിലോ ആവർത്തിക്കും.';

  @override
  String get sudokuHintNoSimple => 'ഇപ്പോൾ എളുപ്പമുള്ള സൂചനയൊന്നുമില്ല.';

  @override
  String sudokuHintMistakeInRow(int row) =>
      '$row-ാം വരിയിലെ ഒരു അക്കം തെറ്റാണ്. അത് ശരിയാക്കിയിട്ട് വീണ്ടും '
      'സൂചന ചോദിക്കൂ.';

  @override
  String get sudokuErase => 'മായ്ക്കൂ';

  @override
  String get sudokuReset => 'റീസെറ്റ്';

  @override
  String get sudokuNotes => 'കുറിപ്പുകൾ';

  @override
  String get sudokuHowToPlayTitle => 'എങ്ങനെ കളിക്കാം';

  @override
  String get sudokuHowToPlayBody =>
      'ഓരോ വരിയിലും നിരയിലും 2×3 ബോക്സിലും 1–6 വരെയുള്ള ഓരോ അക്കവും '
      'ഒരിക്കൽ മാത്രം വരുന്ന വിധം ഒഴിഞ്ഞ കളങ്ങൾ നിറയ്ക്കൂ. ഏത് അക്കവും '
      'ഇടാം; നിറഞ്ഞ ഒരു വരിയോ നിരയോ ബോക്സോ തെറ്റാണെങ്കിൽ അത് തിളങ്ങും. '
      'കുറിപ്പുകൾക്കും സൂചനകൾക്കും പരിധിയില്ല, പക്ഷേ ഓരോ സൂചനയും സമയം '
      'കൂട്ടും: +${HintPenalty.stepSeconds}s, പിന്നെ '
      '+${HintPenalty.stepSeconds * 2}s, അങ്ങനെ +${HintPenalty.maxSeconds}s '
      'വരെ. ഓരോ സൂചനയും ഒരു തെറ്റായ അക്കം കാണിക്കും, അല്ലെങ്കിൽ അടുത്ത പടി '
      'വിശദീകരിക്കും; കളം നിങ്ങൾക്കായി നിറയ്ക്കില്ല.';

  @override
  String get sudokuHowToPlayGotIt => 'മനസ്സിലായി';

  @override
  String get sudokuClearedTitle => 'പൂർത്തിയായി!';

  @override
  String get sudokuLoading => 'ഇന്നത്തെ പസിൽ ഒരുക്കുന്നു…';

  @override
  String get sudokuFailed => 'ഇന്നത്തെ പസിൽ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get puzzleNeedsUpdate =>
      'ഇന്നത്തെ പസിലിന് Winklo-യുടെ പുതിയ പതിപ്പ് വേണം. കളിക്കാൻ ആപ്പ് '
      'അപ്ഡേറ്റ് ചെയ്യൂ.';

  @override
  String get sudokuDifficultyEasy => 'എളുപ്പം';

  @override
  String get sudokuDifficultyMedium => 'ഇടത്തരം';

  @override
  String get sudokuDifficultyHard => 'കഠിനം';

  // Results
  @override
  String get newPersonalBest => 'പുതിയ മികച്ച സമയം';

  @override
  String get newPuzzleUnlocksTomorrow => 'നാളെ പുതിയ പസിൽ എത്തും.';

  @override
  String get newPuzzleReady => 'പുതിയ പസിൽ റെഡി';

  /// "പുതിയ പസിലിന് ഇനി 6 മ. 12 മി." ("6 h 12 min to the new puzzle"),
  /// which needs no case ending; മ. and മി. are CLDR's short hour and
  /// minute. Minutes round up, as in English.
  @override
  String newPuzzleIn(Duration remaining) {
    if (remaining <= Duration.zero) return newPuzzleReady;
    const minute = Duration.microsecondsPerMinute;
    final minutes = (remaining.inMicroseconds + minute - 1) ~/ minute;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final parts = [if (h > 0) '$h മ.', if (m > 0 || h == 0) '$m മി.'];
    return 'പുതിയ പസിലിന് ഇനി ${parts.join(' ')}';
  }

  @override
  String get backHome => 'ഹോമിലേക്ക്';

  @override
  String playNextGame(String gameTitle) => 'അടുത്തത് $gameTitle കളിക്കൂ';

  @override
  String get perfectDay => 'സമ്പൂർണ ദിനം! മൂന്ന് പസിലുകളും പൂർത്തിയാക്കി.';

  @override
  String get shareResult => 'പങ്കിടൂ';

  @override
  String get shareFailed =>
      'പങ്കിടാനുള്ള ഓപ്ഷൻ തുറക്കാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get resultsFullBoard => 'ബോർഡ്';

  @override
  String clearedIn(String time) => '$time-ൽ പൂർത്തിയാക്കി';

  @override
  String rankToday(int rank) => 'ഇന്ന് #$rank';

  @override
  String get resultsTimeLabel => 'സമയം';

  @override
  String resultsHintPenalty(int seconds) => 'സൂചനകളുടെ +${seconds}s ഉൾപ്പെടെ';

  @override
  String get resultsPointsLabel => 'പോയിന്റ്';

  @override
  String saveTimeToBoard(String timeLabel) =>
      '$timeLabel ഇന്നത്തെ ബോർഡിൽ ചേർക്കൂ';

  @override
  String get saveTimeSignInTitle => 'നിങ്ങളുടെ സമയം സേവ് ചെയ്യൂ';

  @override
  String get saveTimeSignInBody =>
      'ഈ കളി ഇന്നത്തെ ലൈവ് ലീഡർബോർഡിൽ ചേർക്കാൻ Google ഉപയോഗിച്ച് സൈൻ ഇൻ '
      'ചെയ്യൂ.';

  @override
  String get resultsBoardTeaseHint =>
      'ഇന്നത്തെ ബോർഡ് ലൈവാണ് — സമയം സേവ് ചെയ്ത് ചേരാൻ തൊടൂ.';

  @override
  String resultsRankOfToday(int total, {bool capped = false}) =>
      '$total${capped ? '+' : ''} പേരിൽ';

  @override
  String resultsRankSemantics(int rank, int total, {bool capped = false}) =>
      'ഇന്ന് $total${capped ? '+' : ''} പേരിൽ $rank-ാം സ്ഥാനം';

  @override
  String resultsHintTimeTile(int seconds) => '+${seconds}s';

  @override
  String get resultsFromHints => 'സൂചനകൾ';

  @override
  String get resultsBoardTab => 'ബോർഡ്';

  @override
  String resultsWordsTab(int count) => 'വാക്കുകൾ · $count';

  // Zip game branding (feature, not app title)
  @override
  String get zipBrand => 'ZIP';

  @override
  String streakLabel(int days) => '$days ദിവസത്തെ സ്ട്രീക്ക്';

  @override
  String longestStreakLabel(int days) => 'മികച്ച സ്ട്രീക്ക് $days';

  // Stats
  @override
  String get statsTitle => 'കണക്കുകൾ';

  @override
  String get statsProfileRow => 'നിങ്ങളുടെ കണക്കുകൾ';

  @override
  String get statsProfileRowHint =>
      'സമയം, സ്ട്രീക്കുകൾ, പൂർത്തിയാക്കിയ ദിവസങ്ങൾ';

  @override
  String get statsFailed => 'നിങ്ങളുടെ കണക്കുകൾ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get statsLocalOnly =>
      'ഈ ഫോണിലെ കളികൾ മാത്രമാണ് കാണിക്കുന്നത്. വീണ്ടും ശ്രമിക്കാൻ താഴേക്ക് '
      'വലിക്കൂ.';

  @override
  String get statsClears => 'തീർത്തവ';

  @override
  String get statsCurrentStreak => 'സ്ട്രീക്ക്';

  @override
  String get statsLongestStreak => 'കൂടിയത്';

  @override
  String get statsBestTime => 'മികച്ചത്';

  @override
  String get statsAverageTime => 'ശരാശരി';

  @override
  String get statsHintFree => 'സ്വന്തമായി';

  @override
  String get statsNoValue => '–';

  @override
  String statsPercent(double share) => '${(share * 100).round()}%';

  @override
  String get statsTimesTitle => 'എടുത്ത സമയം';

  @override
  String get statsTimesEmpty =>
      'നിങ്ങളുടെ സമയങ്ങൾ ഇവിടെ കാണാൻ ഒരു പസിൽ പൂർത്തിയാക്കൂ.';

  @override
  String statsTimesBucket(int fromSeconds, {required bool open}) =>
      open ? '${formatPlayTime(fromSeconds)}+' : formatPlayTime(fromSeconds);

  @override
  String statsTimesBucketSemantics(int fromSeconds, int? toSeconds, int count) {
    final range = toSeconds == null
        ? '${formatPlayTime(fromSeconds)}-ഓ അതിൽ കൂടുതലോ'
        : '${formatPlayTime(fromSeconds)} മുതൽ ${formatPlayTime(toSeconds)} '
              'വരെ';
    return '$range: ${statsClearCount(count)}';
  }

  @override
  String statsClearCount(int count) => '$count തവണ';

  @override
  String get statsCalendarTitle => 'പൂർത്തിയാക്കിയ ദിവസങ്ങൾ';

  @override
  String get statsCalendarEmpty => 'പൂർത്തിയാക്കിയ ദിവസങ്ങൾ ഇവിടെ കാണാം.';

  @override
  String statsCalendarCleared(int days) => '$days ദിവസം പൂർത്തിയാക്കി';

  @override
  String get statsCalendarPrevious => 'മുൻ മാസം';

  @override
  String get statsCalendarNext => 'അടുത്ത മാസം';

  @override
  String get statsTrendTitle => 'മികച്ച സമയത്തിന്റെ ഗതി';

  @override
  String get statsTrendSubtitle => 'കഴിഞ്ഞ 30 ദിവസം';

  @override
  String get statsTrendEmpty =>
      'വരും ദിവസങ്ങളിൽ പസിലുകൾ പൂർത്തിയാക്കൂ, ഗ്രാഫ് ഇവിടെ തെളിയും.';

  @override
  String get statsTrendTimes => 'എടുത്ത സമയം';

  @override
  String get statsTrendBest => 'മികച്ച സമയം';

  @override
  String get statsTrendToday => 'ഇന്ന്';

  @override
  String statsTrendSemantics({
    required int clears,
    required int? bestSeconds,
  }) => [
    'കഴിഞ്ഞ 30 ദിവസം: ${statsClearCount(clears)}',
    if (bestSeconds != null) 'മികച്ച സമയം ${formatPlayTime(bestSeconds)}',
  ].join(', ');

  // Achievements
  @override
  String get achievementsTitle => 'ബാഡ്ജുകൾ';

  @override
  String achievementsProgress(int unlocked, int total) => '$total-ൽ $unlocked';

  @override
  String get achievementsFirstClearsSection => 'ആദ്യ ക്ലിയറുകൾ';

  @override
  String get achievementsStreaksSection => 'സ്ട്രീക്കുകൾ';

  @override
  String get achievementsSpecialsSection => 'പ്രത്യേകം';

  @override
  String get achievementLocked => 'നേടിയിട്ടില്ല';

  @override
  String achievementFirstClearTitle(String game) => 'ആദ്യ $game';

  @override
  String achievementFirstClearCondition(String game) =>
      'ആദ്യത്തെ $game തീർക്കൂ';

  @override
  String achievementStreakTitle(int days, String game) =>
      '$days ദിവസത്തെ $game സ്ട്രീക്ക്';

  @override
  String achievementStreakCondition(int days, String game) =>
      '$game തുടർച്ചയായി $days ദിവസം തീർക്കൂ';

  @override
  String get achievementZipUnderMinuteTitle => 'ഒരു മിനിറ്റിനുള്ളിൽ';

  @override
  String get achievementZipUnderMinuteCondition =>
      'ഒരു Zip ഒരു മിനിറ്റിനുള്ളിൽ തീർക്കൂ';

  @override
  String get achievementHintFreeWeekTitle => 'സൂചനയില്ലാത്ത ആഴ്ച';

  @override
  String get achievementHintFreeWeekCondition =>
      'സൂചനയില്ലാതെ തുടർച്ചയായി 7 ദിവസം';

  @override
  String get achievementFlawlessSudokusTitle => 'പിഴവില്ലാത്ത പത്ത്';

  @override
  String get achievementFlawlessSudokusCondition =>
      'സൂചനയും തെറ്റുമില്ലാതെ 10 Sudoku';

  @override
  String get achievementPerfectDayTitle => 'സമ്പൂർണ ദിനം';

  @override
  String get achievementPerfectDayCondition => 'ഒരു ദിവസം മൂന്നും തീർക്കൂ';

  // Badges: the Profile summary and the Badges screen
  @override
  String achievementNext(String title) => 'അടുത്തത്: $title';

  @override
  String achievementStreakProgress(int current, int target) =>
      '$target-ൽ $current ദിവസം';

  @override
  String get achievementsAllEarned => 'എല്ലാ ബാഡ്ജുകളും നേടി';

  @override
  String get achievementLadderFirst => 'ആദ്യ ജയം';

  @override
  String achievementLadderDays(int days) => '$days ദിവസം';

  @override
  String get achievementsSpecial => 'പ്രത്യേകം';

  @override
  String get achievementEarned => 'നേടി';

  @override
  String achievementCurrentStreak(int days) =>
      'ഇപ്പോഴത്തെ സ്ട്രീക്ക്: $days ദിവസം';

  @override
  String newAchievementsTitle(int count) =>
      count == 1 ? 'പുതിയ ബാഡ്ജ് നേടി' : '$count പുതിയ ബാഡ്ജുകൾ നേടി';

  /// "ആദ്യ Zip", "ആദ്യ Zip, സമ്പൂർണ ദിനം", "ആദ്യ Zip, സമ്പൂർണ ദിനം, ഒപ്പം
  /// 2 എണ്ണം കൂടി".
  @override
  String newAchievementsList(List<String> titles) {
    if (titles.length <= 1) return titles.join();
    if (titles.length == 2) return '${titles[0]}, ${titles[1]}';
    return '${titles[0]}, ${titles[1]}, ഒപ്പം ${titles.length - 2} എണ്ണം കൂടി';
  }

  // Force update / soft update
  @override
  String get updateRequiredTitle => 'അപ്ഡേറ്റ് വേണം';

  @override
  String get updateAvailableTitle => 'അപ്ഡേറ്റ് ലഭ്യമാണ്';

  @override
  String get updateRequiredBody =>
      'തുടരാൻ Winklo-യുടെ പുതിയ പതിപ്പ് വേണം. Play Store-ൽ നിന്ന് അപ്ഡേറ്റ് '
      'ചെയ്യൂ.';

  @override
  String get updateAvailableBody => 'പുതിയ പസിലുകളും മറ്റും.';

  @override
  String get updateNow => 'അപ്ഡേറ്റ് ചെയ്യൂ';

  @override
  String get updateCantSkip => 'ഈ അപ്ഡേറ്റ് ഒഴിവാക്കാനാകില്ല.';

  @override
  String get updateSnooze => 'ഒരു ദിവസത്തേക്ക് മറയ്ക്കൂ';

  @override
  String get updateDownloading => 'ഡൗൺലോഡ് ചെയ്യുന്നു…';

  @override
  String get updateRestart => 'അപ്ഡേറ്റിനായി റീസ്റ്റാർട്ട് ചെയ്യൂ';

  @override
  String updateVersionRow(String current, String requiredLabel) {
    return '$current → $requiredLabel';
  }

  // Auth / leaderboard
  @override
  String get playSignInTitle => 'കളിക്കാൻ സൈൻ ഇൻ ചെയ്യൂ';

  @override
  String get playSignInBody =>
      'ഇന്നത്തെ പസിലുകൾ കളിക്കാനും സമയം ബോർഡിൽ ചേർക്കാനും Google '
      'ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get signInTitle => 'ബോർഡിൽ ചേരാൻ സൈൻ ഇൻ ചെയ്യൂ';

  @override
  String get signInBody =>
      'ലൈവ് റാങ്കിങ് എപ്പോഴും കാണാം. കളിക്കാനും സ്കോർ സേവ് ചെയ്യാനും Google '
      'ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get signInWithGoogle => 'Google ഉപയോഗിച്ച് തുടരൂ';

  @override
  String get signInCancel => 'ഇപ്പോൾ വേണ്ട';

  @override
  String get signInRequired => 'ബോർഡിൽ ചേരാൻ സൈൻ ഇൻ ചെയ്യൂ';

  @override
  String get signOut => 'സൈൻ ഔട്ട്';

  @override
  String get signOutConfirmTitle => 'സൈൻ ഔട്ട് ചെയ്യണോ?';

  @override
  String get signOutConfirmBody =>
      'കളിക്കാൻ വീണ്ടും സൈൻ ഇൻ ചെയ്യണം. സൈൻ ഔട്ട് ചെയ്താലും ലൈവ് '
      'ലീഡർബോർഡ് കാണാം.';

  @override
  String get signOutConfirmCancel => 'റദ്ദാക്കൂ';

  @override
  String get signOutConfirmNote =>
      'നിങ്ങളുടെ സ്ട്രീക്കുകളും കണക്കുകളും ക്ലൗഡിൽ സുരക്ഷിതമാണ്.';

  @override
  String get deleteAccount => 'അക്കൗണ്ട് ഇല്ലാതാക്കൂ';

  @override
  String get deleteAccountConfirmTitle => 'അക്കൗണ്ട് ഇല്ലാതാക്കണോ?';

  @override
  String get deleteAccountConfirmBody =>
      'ഇത് ഞങ്ങളുടെ വെബ്സൈറ്റിലാണ് പൂർത്തിയാക്കുക: അതേ Google അക്കൗണ്ടിൽ '
      'അവിടെ സൈൻ ഇൻ ചെയ്ത് ഉറപ്പിക്കൂ. നിങ്ങളുടെ പ്രൊഫൈലും ലീഡർബോർഡ് '
      'എൻട്രികളും സിങ്ക് ചെയ്ത പുരോഗതിയും എന്നേക്കുമായി ഇല്ലാതാകും.';

  @override
  String get deleteAccountConfirmNote =>
      'ആദ്യം ഇവിടെ സൈൻ ഔട്ട് ചെയ്യും, പിന്നെ ബ്രൗസറിൽ പേജ് തുറക്കും.';

  @override
  String get deleteAccountConfirmContinue => 'തുടരൂ';

  @override
  String get deleteAccountOpenFailed =>
      'ബ്രൗസർ തുറക്കാനായില്ല. അക്കൗണ്ട് ഇല്ലാതാക്കാൻ '
      'winklo.pages.dev/delete-account സന്ദർശിക്കൂ.';

  @override
  String get leaderboardTitle => 'ലീഡർബോർഡ്';

  @override
  String get leaderboardDaily => 'ദിവസം';

  @override
  String get leaderboardAllTime => 'എക്കാലവും';

  @override
  String get leaderboardEmpty => 'ഇതുവരെ സ്കോറുകളില്ല. ആദ്യം നിങ്ങളാകൂ!';

  @override
  String get leaderboardFailed => 'ലീഡർബോർഡ് ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get leaderboardSignInHint => 'ലൈവ് റാങ്കിങ് കാണാൻ സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get seeFullLeaderboard => 'മുഴുവൻ ലീഡർബോർഡ് കാണൂ';

  @override
  String get leaderboardGapEllipsis => '…';

  @override
  String get youLabel => 'നിങ്ങൾ';

  @override
  String get leaderboardNoHintChip => 'സൂചനയില്ലാതെ';

  @override
  String get leaderboardNoMistakesChip => 'പിഴവില്ലാതെ';

  @override
  String get leaderboardKeyStreak => 'ദിവസ സ്ട്രീക്ക്';

  @override
  String leaderboardBehind(String gap, int rank) =>
      '#$rank-നേക്കാൾ $gap പിന്നിൽ';

  @override
  String leaderboardPodiumSemantics(int rank, String name, String time) =>
      'റാങ്ക് $rank, $name, $time';

  @override
  String leaderboardDaysShort(int days) => '$days ദിവസം';

  // Leaderboard: past days, the weekly board and leagues (roadmap area C)
  @override
  String get leaderboardThisWeek => 'ഈ ആഴ്ച';

  @override
  String get leaderboardToday => 'ഇന്ന്';

  @override
  String get leaderboardYesterday => 'ഇന്നലെ';

  /// "ഒക്ടോ 9": CLDR's `ml` "MMM d".
  @override
  String leaderboardShortDate(int day, int month) =>
      '${_shortMonths[month - 1]} $day';

  @override
  String leaderboardDaysCleared(int days) => '$days ദിവസം';

  @override
  String leaderboardWeeklyRow(int days, String time) =>
      '${leaderboardDaysCleared(days)} · $time';

  @override
  String get leaderboardPastDayEmpty => 'ഈ ദിവസം സമയങ്ങളൊന്നുമില്ല.';

  @override
  String get leaderboardWeeklyEmpty =>
      'ഈ ആഴ്ച ഇതുവരെ ആരും ഒരു ദിവസവും പൂർത്തിയാക്കിയിട്ടില്ല.';

  @override
  String get leaderboardWeeklyDebugNote =>
      'ആഴ്ചയിലെ ബോർഡ് സെർവറാണ് നിറയ്ക്കുന്നത്, അതിനാൽ ഡീബഗ് ബിൽഡുകളിൽ ഇത് '
      'ശൂന്യമായിരിക്കും.';

  @override
  String get leaderboardLeagueEmpty => 'ഈ ലീഗിൽ ആർക്കും ഇവിടെ ഇതുവരെ സമയമില്ല.';

  @override
  String get leaderboardScopeEveryone => 'എല്ലാവരും';

  @override
  String get leaderboardLeagues => 'ലീഗുകൾ';

  // Leaderboard: the board and scope pickers and the table
  @override
  String get leaderboardBoardSheetTitle => 'ഏത് ബോർഡ്?';

  @override
  String get leaderboardScopeSheetTitle => 'ആരുടെ സ്കോറുകൾ?';

  @override
  String get leaderboardThisWeekHint =>
      'പൂർത്തിയാക്കിയ ദിവസങ്ങൾ, പിന്നെ ആകെ സമയം';

  @override
  String get leaderboardAllTimeHint => 'എക്കാലത്തെയും മികച്ച സമയം';

  @override
  String get leaderboardSingleDayLabel => 'ഒരു ദിവസം · കഴിഞ്ഞ 14 ദിവസം';

  @override
  String get leaderboardColumnPlayer => 'കളിക്കാർ';

  @override
  String get leaderboardColumnTime => 'സമയം';

  @override
  String get leaderboardColumnDays => 'ദിവസം';

  @override
  String get leaderboardColumnTotal => 'ആകെ';

  @override
  String get leaderboardColumnBest => 'മികച്ചത്';

  @override
  String get leaderboardTop50 => 'ആദ്യ 50 പേർ';

  @override
  String get leaderboardManageLeagues => 'ലീഗുകൾ നിയന്ത്രിക്കൂ';

  @override
  String get leaderboardCreateOrJoinLeague => 'ലീഗ് ഉണ്ടാക്കൂ അല്ലെങ്കിൽ ചേരൂ';

  @override
  String leaderboardLeaguePlayers(int count) => '$count പേർ';

  @override
  String leaderboardBoardPillLabel(String board) => 'ബോർഡ്: $board';

  @override
  String leaderboardScopePillLabel(String scope) => 'സ്കോറുകൾ: $scope';

  @override
  String playerCardRank(int rank) => 'റാങ്ക് #$rank';

  @override
  String get playerCardTime => 'സമയം';

  @override
  String get playerCardWeekTotal => 'ആഴ്ചയിലെ ആകെ';

  @override
  String get playerCardDays => 'പൂർത്തിയാക്കിയ ദിവസം';

  @override
  String get gamePaused => 'നിർത്തിവെച്ചു';

  @override
  String get gamePausedResume => 'തുടരാൻ തൊടൂ';

  @override
  String get leaguesTitle => 'ലീഗുകൾ';

  @override
  String get leaguesIntro =>
      'കൂട്ടുകാർക്കും കുടുംബത്തിനും ടീമിനുമായി ഒരു ബോർഡ്. കോഡ് പങ്കിടൂ, '
      'ചേരുന്നവരെല്ലാം അതിൽ വരും.';

  @override
  String get leaguesEmpty => 'നിങ്ങൾ ഇതുവരെ ഒരു ലീഗിലുമില്ല.';

  @override
  String get leaguesFailed => 'നിങ്ങളുടെ ലീഗുകൾ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get leaguesSignIn => 'ലീഗ് ഉണ്ടാക്കാനോ ചേരാനോ സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get leaguesCreate => 'ലീഗ് ഉണ്ടാക്കൂ';

  @override
  String get leaguesJoin => 'കോഡ് വഴി ചേരൂ';

  @override
  String get leagueNameLabel => 'ലീഗിന്റെ പേര്';

  @override
  String get leagueNameHint => 'കുടുംബം, ഓഫീസ്, വായനക്കൂട്ടം…';

  @override
  String get leagueNameInvalid => '1 മുതൽ 30 വരെ അക്ഷരങ്ങൾ ഉപയോഗിക്കൂ.';

  @override
  String get leagueCodeLabel => 'ക്ഷണ കോഡ്';

  @override
  String get leagueCodeHint => 'ABC234';

  @override
  String get leagueCodeInvalid => 'കോഡിൽ 6 അക്ഷരങ്ങളും അക്കങ്ങളുമാണ്.';

  @override
  String get leagueCreateAction => 'ഉണ്ടാക്കൂ';

  @override
  String get leagueJoinAction => 'ചേരൂ';

  @override
  String get leagueCancel => 'റദ്ദാക്കൂ';

  @override
  String get leagueSave => 'സേവ് ചെയ്യൂ';

  @override
  String leagueMembers(int count) => '$count പേർ';

  @override
  String get leagueOwner => 'ഉടമ';

  @override
  String leagueCode(String code) => 'കോഡ് $code';

  @override
  String get leagueShareInvite => 'ക്ഷണം പങ്കിടൂ';

  @override
  String get leagueCopyCode => 'കോഡ് കോപ്പി ചെയ്യൂ';

  @override
  String get leagueCodeCopied => 'കോഡ് കോപ്പി ചെയ്തു';

  @override
  String leagueInviteText(String name, String url) =>
      '“$name” എന്ന എന്റെ Winklo ലീഗിൽ ചേരൂ: $url';

  @override
  String get leagueMembersHeading => 'കളിക്കാർ';

  @override
  String get leagueMemberFallbackName => 'പ്ലെയർ';

  @override
  String get leagueLoadFailed => 'ഈ ലീഗ് ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get leagueRename => 'പേര് മാറ്റൂ';

  @override
  String get leagueRemove => 'നീക്കം ചെയ്യൂ';

  @override
  String leagueRemoveConfirm(String name) => '$name-നെ ലീഗിൽ നിന്ന് നീക്കണോ?';

  @override
  String get leagueLeave => 'ലീഗ് വിടൂ';

  @override
  String get leagueLeaveConfirm =>
      'ഈ ലീഗ് വിടണോ? കോഡ് ഉപയോഗിച്ച് വീണ്ടും ചേരാം.';

  @override
  String get leagueDelete => 'ലീഗ് ഇല്ലാതാക്കൂ';

  @override
  String get leagueDeleteConfirm =>
      'എല്ലാവർക്കുമായി ഈ ലീഗ് ഇല്ലാതാക്കണോ? ഇത് തിരിച്ചെടുക്കാനാകില്ല.';

  @override
  String get leagueGone => 'ഈ ലീഗ് ഇപ്പോൾ നിലവിലില്ല.';

  @override
  String get leagueSeeBoard => 'ബോർഡ് കാണൂ';

  @override
  String get leagueActionFailed => 'എന്തോ പിശക് പറ്റി. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get joinLeagueTitle => 'ലീഗിൽ ചേരൂ';

  @override
  String get joinLeagueSignIn => 'ഈ ലീഗിൽ ചേരാൻ സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String joinLeagueNotFound(String code) => '$code എന്ന കോഡുള്ള ലീഗില്ല.';

  @override
  String get joinLeagueBadCode => 'അതൊരു ലീഗ് കോഡല്ല.';

  @override
  String get joinLeagueFull => 'ആ ലീഗ് നിറഞ്ഞു (30 പേർ).';

  @override
  String get joinLeagueButton => 'ലീഗിൽ ചേരൂ';

  @override
  String get joinLeagueAlreadyIn => 'നിങ്ങൾ ഈ ലീഗിലുണ്ട്.';

  /// Compact game-tab label (full title stays [pathWordsTitle]).
  @override
  String get pathWordsTab => 'Path';

  // Notifications
  @override
  String get notifDailyReadyTitle => 'ഇന്നത്തെ പസിലുകൾ റെഡി';

  @override
  String get notifDailyReadyBody =>
      'സ്ട്രീക്ക് തുടരാൻ Zip, Path Words, Sudoku കളിക്കൂ.';

  @override
  String get notifStreakAtRiskTitle => 'സ്ട്രീക്ക് അപകടത്തിൽ';

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
      '$count സ്ട്രീക്ക് ഫ്രീസുകൾ റെഡി: ഒരു ദിവസം വിട്ടുപോയാലും സ്ട്രീക്ക് '
      'തുടരും.';

  @override
  String freezeCountLabel(int count) => '×$count';

  @override
  String freezeSavedStreak(String gameId, int days) =>
      'ഫ്രീസ് നിങ്ങളുടെ $days ദിവസത്തെ ${gameTitle(gameId)} സ്ട്രീക്ക് '
      'രക്ഷിച്ചു';

  @override
  String get dismiss => 'മറയ്ക്കൂ';

  /// "നിങ്ങളുടെ 12 ദിവസത്തെ Zip സ്ട്രീക്ക് അർധരാത്രി അവസാനിക്കും", or
  /// "… സ്ട്രീക്കും മറ്റ് 2 എണ്ണവും …".
  @override
  String notifStreakEndsTonight(String gameId, int days, {int others = 0}) {
    final streak = '$days ദിവസത്തെ ${gameTitle(gameId)}';
    if (others <= 0) {
      return 'നിങ്ങളുടെ $streak സ്ട്രീക്ക് അർധരാത്രി അവസാനിക്കും';
    }
    return 'നിങ്ങളുടെ $streak സ്ട്രീക്കും മറ്റ് $others എണ്ണവും അർധരാത്രി '
        'അവസാനിക്കും';
  }

  @override
  String get notifWeeklyRecapTitle => 'Winklo-യിൽ നിങ്ങളുടെ ആഴ്ച';

  /// "ഈ ആഴ്ച: 21-ൽ 18 പൂർത്തിയാക്കി, മികച്ച Zip 0:58, 5 ദിവസത്തെ Sudoku
  /// സ്ട്രീക്ക്".
  @override
  String weeklyRecapLine(WeeklyRecap recap, {bool lastWeek = false}) {
    final best = recap.bestGameId;
    final bestSeconds = recap.bestSeconds;
    final streak = recap.streakGameId;
    final parts = [
      '${recap.possible}-ൽ ${recap.cleared} പൂർത്തിയാക്കി',
      if (best != null && bestSeconds != null)
        'മികച്ച ${gameTitle(best)} ${formatPlayTime(bestSeconds)}',
      if (streak != null)
        '${recap.streakDays} ദിവസത്തെ ${gameTitle(streak)} സ്ട്രീക്ക്',
    ];
    return '${lastWeek ? 'കഴിഞ്ഞ ആഴ്ച' : 'ഈ ആഴ്ച'}: ${parts.join(', ')}';
  }

  @override
  String get homeRecapTitle => 'നിങ്ങളുടെ ആഴ്ച';

  // Android notification channels
  @override
  String get channelRemindersName => 'ഓർമ്മപ്പെടുത്തലുകൾ';

  @override
  String get channelRemindersDescription =>
      'ദിവസേനയുള്ള പസിലുകൾ, അപകടത്തിലായ സ്ട്രീക്കുകൾ, ആഴ്ചയിലെ ചുരുക്കം.';

  @override
  String get channelAnnouncementsName => 'അറിയിപ്പുകൾ';

  @override
  String get channelAnnouncementsDescription =>
      'വാർത്തകളും ആപ്പ് അപ്ഡേറ്റുകളും.';

  // Home-screen widget
  @override
  String get widgetCleared => '✓';

  @override
  String widgetStreak(int days) => '🔥$days';

  @override
  String get widgetPlay => 'കളിക്കൂ';

  @override
  String get widgetFooter => 'അർധരാത്രി പുതിയ പസിൽ';

  // Settings
  @override
  String get profileSettings => 'ക്രമീകരണം';

  @override
  String get settingsTitle => 'ക്രമീകരണം';

  @override
  String get settingsSoundSection => 'ശബ്ദവും വൈബ്രേഷനും';

  @override
  String get settingsRemindersSection => 'ഓർമ്മപ്പെടുത്തലുകൾ';

  @override
  String get settingsLanguageSection => 'ഭാഷ';

  @override
  String get settingsLanguageSystem => 'സിസ്റ്റം';

  @override
  String settingsLanguageSystemHint(String language) =>
      'ഫോണിന്റെ ഭാഷ: $language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get settingsDailyReady => 'പസിലുകൾ റെഡി';

  @override
  String get settingsDailyReadyHint => 'ഇന്നത്തെ പസിലുകൾ എത്തുമ്പോൾ';

  @override
  String get settingsStreakAtRisk => 'സ്ട്രീക്ക് അപകടത്തിൽ';

  @override
  String get settingsStreakAtRiskHint => 'സ്ട്രീക്ക് പോകുമെങ്കിൽ മാത്രം';

  @override
  String get settingsWeeklyRecap => 'ആഴ്ചയിലെ ചുരുക്കം';

  @override
  String settingsWeeklyRecapHint(String time) => 'ഞായറാഴ്ചകളിൽ, $time';

  @override
  String get settingsAnnouncements => 'അറിയിപ്പുകൾ';

  @override
  String get settingsAnnouncementsHint => 'Winklo വാർത്തകൾ';

  @override
  String get settingsReminderTime => 'സമയം';

  @override
  String settingsReminderTimeLabel(String reminder, String time) =>
      '$reminder സമയം, $time';

  // Dashboard nav
  @override
  String get navHome => 'ഹോം';

  @override
  String get navLeaderboard => 'ലീഡർബോർഡ്';

  @override
  String get navProfile => 'പ്രൊഫൈൽ';

  // Profile
  @override
  String get profileTitle => 'പ്രൊഫൈൽ';

  @override
  String get profileSignedOutTitle => 'നിങ്ങളുടെ പ്രൊഫൈൽ';

  @override
  String get profileSignedOutBody =>
      'ലീഡർബോർഡിനായി പേരും അവതാറും ഒരുക്കാൻ സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get profileEditName => 'കാണിക്കുന്ന പേര്';

  @override
  String get profileNameHint => 'കാണിക്കേണ്ട പേര് നൽകൂ';

  @override
  String get profileNameEmpty => 'പേര് ശൂന്യമാകരുത്.';

  @override
  String get profileNameTooLong => 'പേര് 24 അക്ഷരങ്ങളിൽ കൂടരുത്.';

  @override
  String get profileSave => 'സേവ് ചെയ്യൂ';

  @override
  String get profileEditAvatar => 'അവതാർ മാറ്റൂ';

  @override
  String get profileChoosePhoto => 'ഫോട്ടോകളിൽ നിന്ന് എടുക്കൂ';

  @override
  String get profileAvatarHint => 'മാറ്റാൻ ഒന്നിൽ തൊടൂ';

  @override
  String get profileAvatarPhoto => 'ഫോട്ടോ';

  @override
  String get avatarCritterFox => 'കുറുക്കൻ';

  @override
  String get avatarCritterCat => 'പൂച്ച';

  @override
  String get avatarCritterOwl => 'മൂങ്ങ';

  @override
  String get avatarCritterFrog => 'തവള';

  @override
  String get avatarCritterPanda => 'പാണ്ട';

  @override
  String get avatarCritterBunny => 'മുയൽ';

  @override
  String get avatarCritterPenguin => 'പെൻഗ്വിൻ';

  @override
  String get avatarCritterTiger => 'കടുവ';

  @override
  String get avatarCritterKoala => 'കോവാല';

  @override
  String get avatarCritterBear => 'കരടി';

  @override
  String get avatarCritterRaccoon => 'റാക്കൂൺ';

  @override
  String get avatarCritterChick => 'കോഴിക്കുഞ്ഞ്';

  @override
  String get profileSaveFailed =>
      'പ്രൊഫൈൽ സേവ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get profilePhotoTooLarge =>
      'ആ ഫോട്ടോ അപ്‌ലോഡ് ചെയ്യാൻ വലുതാണ് (പരമാവധി 2 MB). മറ്റൊന്ന് '
      'നോക്കൂ.';

  @override
  String get profileUploadFailed =>
      'ഫോട്ടോ അപ്‌ലോഡ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get profilePermissionDenied =>
      'ഫോട്ടോ ആക്സസ് നിഷേധിച്ചു. അവതാർ അപ്‌ലോഡ് ചെയ്യാൻ ഫോണിന്റെ '
      'ക്രമീകരണത്തിൽ അത് ഓണാക്കൂ.';

  @override
  String get profileEditDisplayName => 'പേര് മാറ്റൂ';

  @override
  String get profileSoundEffects => 'ശബ്ദ ഇഫക്റ്റുകൾ';

  @override
  String get profileVibration => 'വൈബ്രേഷൻ';

  @override
  String get profilePrivacyPolicy => 'സ്വകാര്യതാ നയം';

  @override
  String get profileAboutGame => 'ഗെയിമിനെക്കുറിച്ച്';

  @override
  String get profileRateOnPlayStore => 'Play Store-ൽ റേറ്റ് ചെയ്യൂ';

  @override
  String get reviewOpenStoreFailed => 'Play Store തുറക്കാനായില്ല';

  @override
  String get profileReportIssue => 'പ്രശ്നം അറിയിക്കൂ';

  @override
  String get profileAboutBody =>
      'നിങ്ങളുടെ സൗകര്യത്തിന് കളിച്ചുതീർക്കാവുന്ന ചെറു ഗെയിമുകളുള്ള '
      'ദിവസേനയുള്ള പസിൽ ആപ്പാണ് Winklo.';

  @override
  String get profileAboutGamesHeading => 'ഗെയിമുകൾ';

  @override
  String get profileAboutDailyHeading => 'ദിവസേനയുള്ള കളി';

  @override
  String get profileAboutDailyBody =>
      'ഓരോ ദിവസവും Zip, Path Words, Sudoku എന്നിവയ്ക്ക് പുതിയ പസിലുകൾ. '
      'അവ പൂർത്തിയാക്കി ലീഡർബോർഡിൽ മുന്നേറൂ, സ്ട്രീക്ക് നിലനിർത്തൂ.';

  @override
  String profileAboutVersion(String version) => 'പതിപ്പ് $version';

  @override
  String get profileReportTitleLabel => 'തലക്കെട്ട്';

  @override
  String get profileReportTitleHint => 'ചുരുക്കത്തിൽ';

  @override
  String get profileReportDescriptionLabel => 'വിവരണം';

  @override
  String get profileReportDescriptionHint =>
      'എന്താണ് പ്രശ്നം, അല്ലെങ്കിൽ എന്താണ് കാണാൻ ആഗ്രഹിക്കുന്നത്?';

  @override
  String get profileReportTitleEmpty => 'തലക്കെട്ട് ശൂന്യമാകരുത്.';

  @override
  String get profileReportTitleTooLong => 'തലക്കെട്ട് 80 അക്ഷരങ്ങളിൽ കൂടരുത്.';

  @override
  String get profileReportDescriptionEmpty => 'വിവരണം ശൂന്യമാകരുത്.';

  @override
  String get profileReportDescriptionTooLong =>
      'വിവരണം 2000 അക്ഷരങ്ങളിൽ കൂടരുത്.';

  @override
  String get profileReportSend => 'അയയ്ക്കൂ';

  @override
  String get profileReportSent => 'നന്ദി — നിങ്ങളുടെ റിപ്പോർട്ട് അയച്ചു.';

  @override
  String get profileReportFailed =>
      'റിപ്പോർട്ട് അയയ്ക്കാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get profilePrivacyFailed => 'സ്വകാര്യതാ നയം ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get profilePrivacyRetry => 'വീണ്ടും ശ്രമിക്കൂ';

  // More ways to play: archive, practice and bonus games (roadmap area F)
  @override
  String get moreWaysTitle => 'കൂടുതൽ കളികൾ';

  @override
  String get moreWaysEntryHint => 'ആർക്കൈവ് · പരിശീലനം · ബോണസ് ഗെയിമുകൾ';

  @override
  String get archiveTitle => 'ആർക്കൈവ്';

  @override
  String get archiveHint =>
      'പഴയ ഏത് പസിലും വീണ്ടും കളിക്കൂ. സ്ട്രീക്കും ബോർഡുമില്ല.';

  @override
  String get practiceTitle => 'പരിശീലനം';

  @override
  String get practiceHint => 'ഓഫ്‌ലൈനായി എത്ര ബോർഡുകളും. സൂചനകൾ സൗജന്യം.';

  @override
  String get bonusGamesTitle => 'ബോണസ് ഗെയിമുകൾ';

  @override
  String get bonusGamesHint => 'വെറുതെ രസത്തിന് ചെറു വാക്ക് കളികൾ.';

  @override
  String archiveRunLabel(DateTime day) =>
      'ആർക്കൈവ് · ${leaderboardShortDate(day.day, day.month)}';

  @override
  String get practiceRunLabel => 'പരിശീലനം';

  @override
  String get practiceNewBoard => 'പുതിയ ബോർഡ്';

  @override
  String get hintUnlimited => 'സൂചന';

  @override
  String hintWithCost(int seconds) => 'സൂചന +${seconds}s';

  @override
  String localBest(String time) => 'മികച്ചത് $time';

  @override
  String archiveBest(String time) => 'ആർക്കൈവിലെ മികച്ചത് $time';

  @override
  String get newLocalBest => 'പുതിയ മികച്ചത്';

  @override
  String get backToArchive => 'ആർക്കൈവിലേക്ക്';

  @override
  String get archivePickGame => 'ഗെയിം';

  @override
  String archiveMonthCleared(int days) => '$days ദിവസം പൂർത്തിയാക്കി';

  @override
  String get archiveDayCleared => 'പൂർത്തിയായി';

  @override
  String get archiveDayOpen => 'കളിച്ചിട്ടില്ല';

  @override
  String get archivePrevious => 'മുൻ മാസം';

  @override
  String get archiveNext => 'അടുത്ത മാസം';

  @override
  String get archiveLegend => 'അന്നോ ആർക്കൈവിലോ പൂർത്തിയാക്കിയത്';

  @override
  String pathWordsThemeOf(String theme) => 'വിഷയം: $theme';

  @override
  String get archiveOpenHint => 'വീണ്ടും കളിക്കാൻ ഒരു ദിവസം തിരഞ്ഞെടുക്കൂ.';

  @override
  String get practicePickGame => 'പുതിയ ബോർഡിനായി ഒരു ഗെയിം തിരഞ്ഞെടുക്കൂ.';

  @override
  String get wordMatchHint => 'ഓരോ വാക്കും അതിന്റെ ജോടിയിലേക്ക് വലിച്ചിടൂ.';

  @override
  String get categoryRaceHint => 'സമയം തീരും മുമ്പ് ചേരുന്ന വാക്കുകൾ പറയൂ.';

  @override
  String get archiveEmpty => 'ആർക്കൈവ് നാളെ തുറക്കും.';

  @override
  String bonusRunLabel(String game, String item) => '$game · $item';

  @override
  String get bonusLoadFailed =>
      'ഈ ഗെയിം ലോഡ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get resultsPairsLabel => 'ജോടികൾ';

  /// A countdown chip ("45s"); the unit stays the short Latin "s".
  @override
  String bonusSecondsLeft(int seconds) => '${seconds}s';

  @override
  String wordMatchPairs(int n) => '$n ജോടി';

  @override
  String get wordMatchNoDecks => 'ഇതുവരെ ഡെക്കുകളില്ല. ഉടൻ വീണ്ടും നോക്കൂ.';

  @override
  String get wordMatchDeckMissing => 'ഈ ഡെക്ക് ഇപ്പോൾ ലഭ്യമല്ല.';

  @override
  String get wordMatchInstruction =>
      'ഒരു വാക്ക് അതിന്റെ ജോടിയിലേക്ക് വലിച്ചിടൂ';

  @override
  String get wordMatchCleared => 'എല്ലാം ചേർന്നു!';

  @override
  String get wordMatchTimeUp => 'സമയം കഴിഞ്ഞു';

  @override
  String wordMatchMatched(int matched, int total) =>
      '$total-ൽ $matched ജോടി ചേർത്തു';

  /// The decks are English words; the copy says so.
  @override
  String get wordMatchHowToBody =>
      'ഓരോ (ഇംഗ്ലീഷ്) വാക്കും അതിന്റെ ജോടിയായ വാക്കിലേക്ക് വലിച്ചിടൂ. '
      'സമയം തീരും മുമ്പ് എല്ലാ ജോടികളും ചേർക്കൂ. ഓരോ ഡെക്കിലെയും '
      'നിങ്ങളുടെ മികച്ച സമയം ഈ ഫോണിൽ മാത്രം സൂക്ഷിക്കും; സ്ട്രീക്കോ '
      'ലീഡർബോർഡോ ഇല്ല.';

  /// The categories and answers are English; the copy says so.
  @override
  String get categoryRaceHowToBody =>
      'ഒരു വിഭാഗവും ഒരു അക്ഷരവും കിട്ടും. സമയം തീരും മുമ്പ് ആ വിഭാഗത്തിൽ '
      'പെടുന്ന, ആ അക്ഷരത്തിൽ തുടങ്ങുന്ന പരമാവധി ഇംഗ്ലീഷ് വാക്കുകൾ ടൈപ്പ് '
      'ചെയ്യൂ. നിങ്ങളുടെ മികച്ച എണ്ണം ഈ ഫോണിൽ മാത്രം സൂക്ഷിക്കും; '
      'സ്ട്രീക്കോ ലീഡർബോർഡോ ഇല്ല.';

  @override
  String categoryRaceStart(int seconds) => 'തുടങ്ങൂ · ${seconds}s';

  @override
  String categoryRaceInstruction(String letter) =>
      'ഈ വിഭാഗത്തിൽ പെടുന്ന, $letter-ൽ തുടങ്ങുന്ന വാക്കുകൾ ടൈപ്പ് ചെയ്യൂ';

  @override
  String get categoryRaceYourWord => 'നിങ്ങളുടെ വാക്ക്';

  @override
  String get categoryRaceSubmit => 'വാക്ക് ചേർക്കൂ';

  @override
  String categoryRaceAccepted(int n) => 'സ്വീകരിച്ചവ ($n)';

  @override
  String categoryRaceMustStart(String letter) => '$letter-ൽ തുടങ്ങണം';

  @override
  String categoryRaceNotIn(String category) => '$category-ൽ പെടില്ല';

  @override
  String get categoryRaceAlreadyUsed => 'ഇതിനകം ഉപയോഗിച്ചു';

  @override
  String get categoryRaceRoundOver => 'റൗണ്ട് കഴിഞ്ഞു';

  @override
  String get categoryRaceNoCategories =>
      'ഇതുവരെ വിഭാഗങ്ങളില്ല. ഉടൻ വീണ്ടും നോക്കൂ.';

  @override
  String get resultsWordsLabel => 'വാക്കുകൾ';

  @override
  String localBestScore(int words) => 'മികച്ചത് $words വാക്ക്';

  // Levels
  @override
  String get levelsTitle => 'ലെവലുകൾ';

  @override
  String levelWorldName(String theme) => switch (theme) {
    'ink' => 'മഷി',
    'metro' => 'മെട്രോ',
    'embroidery' => 'ചിത്രത്തുന്നൽ',
    'neon' => 'നിയോൺ',
    'sparkler' => 'കമ്പിത്തിരി',
    _ => levelsTitle,
  };

  @override
  String levelRunLabel(int number, String worldName) =>
      'ലെവൽ $number · $worldName';

  @override
  String levelClearedTitle(int number) => 'ലെവൽ $number പൂർത്തിയായി';

  @override
  String get levelFailed => 'ഈ ലെവൽ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get levelHintCostsStar => 'സൂചന · ഒരു നക്ഷത്രം കുറയും';

  @override
  String levelTarget(String time) => 'ലക്ഷ്യം $time';

  @override
  String get levelGoalClear => 'ബോർഡ് പൂർത്തിയാക്കുക';

  @override
  String get levelGoalNoHints => 'സൂചനയില്ലാതെ';

  @override
  String levelGoalUnder(String time) => '$time-നുള്ളിൽ';

  @override
  String get levelGoalNoHintsHow =>
      'ഈ നക്ഷത്രത്തിന് സൂചനയില്ലാതെ വീണ്ടും കളിക്കുക';

  @override
  String levelGoalUnderHow(String time) =>
      'ഈ നക്ഷത്രത്തിന് $time-നുള്ളിൽ വീണ്ടും കളിക്കുക';

  @override
  String levelNewBestStars(int from, int to) =>
      'പുതിയ മികച്ചത് · $from → $to നക്ഷത്രങ്ങൾ';

  @override
  String get levelNewBestTime => 'പുതിയ മികച്ച സമയം';

  @override
  String get levelNext => 'അടുത്ത ലെവൽ';

  @override
  String levelOpenWorld(String worldName) => '$worldName തുറക്കുക';

  @override
  String levelGoalEarned(String goal) => '$goal, നേടി';

  @override
  String levelGoalMissed(String goal) => '$goal, നേടിയില്ല';

  @override
  String get levelsSoon => 'ഉടൻ';

  @override
  String get levelsNeedConnection =>
      'ആദ്യമായി ലെവലുകൾ തുറക്കാൻ ഇന്റർനെറ്റ് വേണം.';

  @override
  String get levelsComingSoon => 'ലെവലുകൾ ഉടൻ വരുന്നു.';

  @override
  String levelWorldTitle(int order, String worldName) =>
      'ലോകം $order · $worldName';

  @override
  String levelWorldLocked(int lastLevel) =>
      'തുറക്കാൻ ലെവൽ $lastLevel പൂർത്തിയാക്കുക';

  @override
  String levelLocked(int number) => 'ആദ്യം ലെവൽ $number പൂർത്തിയാക്കുക';

  @override
  String get levelLockedMessage => 'ഈ ലെവൽ ഇനിയും തുറന്നിട്ടില്ല.';

  @override
  String get levelPlay => 'കളിക്കുക';

  @override
  String levelBestTime(String time) => 'മികച്ചത് $time';

  @override
  String get levelBackToMap => 'മാപ്പ്';

  @override
  String levelNodeDone(int number, int stars, int maxStars) =>
      'ലെവൽ $number, $maxStars-ൽ $stars നക്ഷത്രം';

  @override
  String levelNodeCurrent(int number) => 'ലെവൽ $number, അടുത്തത്';

  @override
  String levelNodeLocked(int number) => 'ലെവൽ $number, പൂട്ടിയത്';

  @override
  String levelNumber(int number) => 'ലെവൽ $number';

  @override
  String get levelReplay => 'വീണ്ടും കളിക്കുക';

  @override
  String get levelAllDone => 'കൂടുതൽ ലോകങ്ങൾ ഉടൻ വരുന്നു';

  // Copy moved out of widgets and repositories (roadmap area G)
  @override
  String get resultsTitle => 'ഫലം';

  @override
  String get resultsNextPuzzle => 'അടുത്ത പസിൽ';

  @override
  String get leaderboardYourRank => 'നിങ്ങളുടെ റാങ്ക്';

  @override
  String leaderboardPlayGame(String game) => '$game കളിക്കൂ';

  /// Shown for a player with no name on a board or in a league.
  @override
  String get playerFallbackName => 'പ്ലെയർ';

  /// The first line of a shared result: "Winklo Zip · ഒക്ടോ 9".
  @override
  String shareHeadline(String game, DateTime day) =>
      'Winklo $game · ${leaderboardShortDate(day.day, day.month)}';

  @override
  String get signInFailed => 'സൈൻ ഇൻ ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get serviceUnavailable =>
      'ഇപ്പോൾ കണക്റ്റ് ചെയ്യാനാകുന്നില്ല. പിന്നീട് ശ്രമിക്കൂ.';

  @override
  String get signInRequiredShort => 'സൈൻ ഇൻ ചെയ്യണം.';

  @override
  String get profileUpdateFailed => 'പ്രൊഫൈൽ അപ്ഡേറ്റ് ചെയ്യാനായില്ല.';

  @override
  String get profileLoadFailed => 'പ്രൊഫൈൽ ലോഡ് ചെയ്യാനായില്ല.';

  @override
  String get avatarUploadUnavailable => 'ഫോട്ടോ അപ്‌ലോഡ് ഇപ്പോൾ ലഭ്യമല്ല.';

  @override
  String get avatarInvalid => 'ഈ അവതാർ ഉപയോഗിക്കാനാകില്ല.';

  @override
  String get leaguesSignedOut => 'ലീഗുകൾ ഉപയോഗിക്കാൻ സൈൻ ഇൻ ചെയ്യൂ.';

  @override
  String get leagueLookupFailed => 'ആ കോഡ് പരിശോധിക്കാനായില്ല.';

  @override
  String get leagueCreateFailed => 'ലീഗ് ഉണ്ടാക്കാനായില്ല.';

  @override
  String get leagueCreateRetry => 'ലീഗ് ഉണ്ടാക്കാനായില്ല. വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String get leagueJoinFailed => 'ലീഗിൽ ചേരാനായില്ല.';

  @override
  String get leagueLeaveFailed => 'ലീഗ് വിടാനായില്ല.';

  @override
  String get leagueRemoveFailed => 'ആ പ്ലെയറെ നീക്കാനായില്ല.';

  @override
  String get leagueRenameFailed => 'ലീഗിന്റെ പേര് മാറ്റാനായില്ല.';

  @override
  String get leagueDeleteFailed => 'ലീഗ് ഇല്ലാതാക്കാനായില്ല.';

  @override
  String get leagueNameLength => 'ലീഗിന്റെ പേരിൽ 1 മുതൽ 30 വരെ അക്ഷരങ്ങൾ വേണം.';

  @override
  String get leagueCodeNotFound => 'ആ കോഡുള്ള ലീഗില്ല.';
}
