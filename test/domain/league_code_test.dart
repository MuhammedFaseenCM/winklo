import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/league_code.dart';

void main() {
  test('codes are 6 characters from the alphabet', () {
    final rng = Random(7);
    for (var i = 0; i < 200; i++) {
      final code = generateLeagueCode(rng);
      expect(code, hasLength(leagueCodeLength));
      expect(code.split('').every(leagueCodeAlphabet.contains), isTrue);
    }
  });

  test('the alphabet leaves out look-alikes', () {
    for (final c in ['I', 'L', 'O', '0', '1']) {
      expect(leagueCodeAlphabet.contains(c), isFalse, reason: c);
    }
    expect(leagueCodeAlphabet, hasLength(31));
  });

  test('normalises typed codes and invite links', () {
    expect(normalizeLeagueCode(' abc-def '), 'ABCDEF');
    expect(normalizeLeagueCode('ab cd ef'), 'ABCDEF');
    expect(
      normalizeLeagueCode('https://brain-zip-app.web.app/join/XYZ234'),
      'XYZ234',
    );
    // Older invites still shared as pages.dev links.
    expect(
      normalizeLeagueCode('https://winklo.pages.dev/join/XYZ234'),
      'XYZ234',
    );
  });

  test('refuses what cannot be a code', () {
    for (final bad in ['', 'ABCDE', 'ABCDEFG', 'ABCDE1', 'ABCDEO', 'ABC_EF']) {
      expect(normalizeLeagueCode(bad), isNull, reason: bad);
    }
  });

  test('names are 1 to 30 characters after trimming', () {
    expect(cleanLeagueName('  Family  '), 'Family');
    expect(cleanLeagueName('   '), isNull);
    expect(cleanLeagueName('x' * 30), 'x' * 30);
    expect(cleanLeagueName('x' * 31), isNull);
  });

  test('invite links point at the join page', () {
    expect(
      leagueInviteUrl('ABCDEF'),
      'https://brain-zip-app.web.app/join/ABCDEF',
    );
  });
}
