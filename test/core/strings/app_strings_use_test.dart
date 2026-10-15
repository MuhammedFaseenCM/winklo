import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';

void main() {
  tearDown(() => AppStrings.use('en'));

  test('reads English by default', () {
    expect(AppStrings.languageCode, 'en');
    expect(AppStrings.retry, 'Retry');
    expect(AppStrings.zipHintWithCount(2), 'Hint (2)');
  });

  test('a language without a table reads English', () {
    AppStrings.use('xx');
    expect(AppStrings.languageCode, 'en');
    expect(AppStrings.retry, 'Retry');
  });

  test('formatPlayTime is the same in every language', () {
    expect(AppStrings.formatPlayTime(48), '0:48');
    expect(AppStrings.formatPlayTime(605), '10:05');
  });
}
