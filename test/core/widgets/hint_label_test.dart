import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/play_mode_strip.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a daily hint shows what the next one costs', () {
    expect(hintLabelFor(PlayMode.daily, hintsUsed: 0), 'Hint +10s');
    expect(hintLabelFor(PlayMode.daily, hintsUsed: 2), 'Hint +30s');
    expect(hintLabelFor(PlayMode.daily, hintsUsed: 9), 'Hint +60s');
  });

  test('archive hints cost the same', () {
    final archive = PlayMode.archive(DateTime(2026, 10, 12));
    expect(hintLabelFor(archive, hintsUsed: 1), 'Hint +20s');
  });

  test('practice hints are free, so the label is plain', () {
    expect(
      hintLabelFor(PlayMode.practice, hintsUsed: 4),
      AppStrings.hintUnlimited,
    );
  });
}
