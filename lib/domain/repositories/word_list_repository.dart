abstract class WordListRepository {
  Future<List<String>> loadEnglishWords({int minLen = 4, int maxLen = 10});

  /// Shared daily noun pool for Path Words (`dateId` = PlayPeriod id).
  Future<List<String>> loadDailyNouns({required String dateId});

  /// Real English words of 4–8 lowercase letters (the public-domain ENABLE
  /// list, without slurs or profanity), for Path Words bonus words. Read
  /// once, on the first call; a failed read is tried again next time.
  Future<Set<String>> loadBonusWords();
}
