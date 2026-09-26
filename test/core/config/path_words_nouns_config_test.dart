import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/path_words_nouns_config.dart';

void main() {
  test('baseUrl is a String and isConfigured reflects emptiness', () {
    expect(PathWordsNounsConfig.baseUrl, isA<String>());
    expect(
      PathWordsNounsConfig.isConfigured,
      PathWordsNounsConfig.baseUrl.trim().isNotEmpty,
    );
  });
}
