import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/play_mode_strip.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  test('a level hint says it costs a star until one is used', () {
    const mode = PlayMode.level('zip_1_01');
    expect(hintLabelFor(mode, hintsUsed: 0), 'Hint · costs a star');
    expect(hintLabelFor(mode, hintsUsed: 1), 'Hint');
  });
}
