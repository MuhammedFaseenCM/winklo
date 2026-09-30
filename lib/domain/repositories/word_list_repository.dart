abstract class WordListRepository {
  Future<List<String>> loadEnglishWords({int minLen = 4, int maxLen = 10});

  /// Shared daily noun pool for Path Words (`dateId` = PlayPeriod id).
  Future<List<String>> loadDailyNouns({required String dateId});
}
