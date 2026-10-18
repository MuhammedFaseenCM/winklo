import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/clear_meta.dart';

void main() {
  test('round-trips through JSON', () {
    const meta = ClearMeta(usedHints: true, hadMistakes: false);
    expect(meta.toJson(), {'usedHints': true, 'hadMistakes': false});
    expect(ClearMeta.fromJson(meta.toJson()), meta);
  });

  test('fromJson returns null for bad input', () {
    for (final bad in <Object?>[
      null,
      'x',
      42,
      <String>[],
      <String, dynamic>{},
      {'usedHints': true},
      {'hadMistakes': false},
      {'usedHints': 'true', 'hadMistakes': false},
      {'usedHints': true, 'hadMistakes': 0},
    ]) {
      expect(ClearMeta.fromJson(bad), isNull, reason: '$bad');
    }
  });

  test('value equality', () {
    const a = ClearMeta(usedHints: false, hadMistakes: true);
    expect(a, const ClearMeta(usedHints: false, hadMistakes: true));
    expect(
      a.hashCode,
      const ClearMeta(usedHints: false, hadMistakes: true).hashCode,
    );
    expect(a, isNot(const ClearMeta(usedHints: true, hadMistakes: true)));
    expect(a, isNot(const ClearMeta(usedHints: false, hadMistakes: false)));
  });

  group('bonus words', () {
    test('round-trip, and stay out of the JSON when there are none', () {
      const meta = ClearMeta(
        usedHints: false,
        hadMistakes: false,
        bonusWords: ['stare', 'tears'],
      );
      expect(meta.toJson(), {
        'usedHints': false,
        'hadMistakes': false,
        'bonusWords': ['stare', 'tears'],
      });
      expect(ClearMeta.fromJson(meta.toJson()), meta);
      expect(
        const ClearMeta(usedHints: false, hadMistakes: false).toJson(),
        isNot(contains('bonusWords')),
      );
    });

    test('a missing or malformed list reads as none', () {
      for (final raw in <Object?>[null, 'stare', 3, <Object>[]]) {
        final meta = ClearMeta.fromJson({
          'usedHints': true,
          'hadMistakes': false,
          'bonusWords': raw,
        });
        expect(meta?.bonusWords, isEmpty, reason: '$raw');
      }
      final mixed = ClearMeta.fromJson({
        'usedHints': true,
        'hadMistakes': false,
        'bonusWords': ['stare', 4, 'tears'],
      });
      expect(mixed?.bonusWords, ['stare', 'tears']);
    });

    test('are part of equality', () {
      const plain = ClearMeta(usedHints: false, hadMistakes: false);
      const withBonus = ClearMeta(
        usedHints: false,
        hadMistakes: false,
        bonusWords: ['stare'],
      );
      expect(withBonus, isNot(plain));
      expect(
        withBonus,
        const ClearMeta(
          usedHints: false,
          hadMistakes: false,
          bonusWords: ['stare'],
        ),
      );
      expect(
        withBonus.hashCode,
        const ClearMeta(
          usedHints: false,
          hadMistakes: false,
          bonusWords: ['stare'],
        ).hashCode,
      );
    });
  });
}
