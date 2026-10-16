import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/hint_penalty.dart';
import 'package:winklo/domain/play_mode.dart';

void main() {
  group('HintPenalty.secondsFor', () {
    test('grows by ten seconds a hint', () {
      expect(HintPenalty.secondsFor(1), 10);
      expect(HintPenalty.secondsFor(2), 20);
      expect(HintPenalty.secondsFor(5), 50);
    });

    test('stops growing at a minute', () {
      expect(HintPenalty.secondsFor(6), 60);
      expect(HintPenalty.secondsFor(7), 60);
      expect(HintPenalty.secondsFor(40), 60);
    });

    test('is zero before the first hint', () {
      expect(HintPenalty.secondsFor(0), 0);
      expect(HintPenalty.secondsFor(-1), 0);
    });
  });

  group('HintPenalty.totalSeconds', () {
    test('adds up every hint spent', () {
      expect(HintPenalty.totalSeconds(0), 0);
      expect(HintPenalty.totalSeconds(1), 10);
      expect(HintPenalty.totalSeconds(3), 60);
      // 10 + 20 + 30 + 40 + 50 + 60 + 60
      expect(HintPenalty.totalSeconds(7), 270);
    });
  });

  group('HintPenalty.appliesTo', () {
    test('charges dailies and the archive, not practice', () {
      expect(HintPenalty.appliesTo(PlayMode.daily), isTrue);
      expect(
        HintPenalty.appliesTo(PlayMode.archive(DateTime(2026, 10, 9))),
        isTrue,
      );
      expect(HintPenalty.appliesTo(PlayMode.practice), isFalse);
    });
  });

  group('HintPenalty.nextSeconds', () {
    test('is the cost of the next hint in a charged mode', () {
      expect(HintPenalty.nextSeconds(PlayMode.daily, hintsUsed: 0), 10);
      expect(HintPenalty.nextSeconds(PlayMode.daily, hintsUsed: 2), 30);
    });

    test('is zero in practice', () {
      expect(HintPenalty.nextSeconds(PlayMode.practice, hintsUsed: 4), 0);
    });
  });
}
