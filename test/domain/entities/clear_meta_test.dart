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
}
