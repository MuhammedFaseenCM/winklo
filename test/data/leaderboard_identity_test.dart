import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/leaderboard_identity.dart';

void main() {
  group('leaderboardDisplayName', () {
    test('trims and keeps short names', () {
      expect(leaderboardDisplayName('  Ada  '), 'Ada');
    });

    test('falls back to Player when blank', () {
      expect(leaderboardDisplayName('   '), 'Player');
    });

    test('cuts long names to the limit', () {
      final name = leaderboardDisplayName('x' * 100);
      expect(name.length, leaderboardDisplayNameMaxLength);
    });

    test('never splits a surrogate pair', () {
      // 39 ASCII units, then an emoji (two UTF-16 units) across the limit.
      final name = leaderboardDisplayName('${'a' * 39}😀tail');
      expect(name, 'a' * 39);
    });
  });

  group('leaderboardPhotoUrl', () {
    test('accepts Google account photos', () {
      const url = 'https://lh3.googleusercontent.com/a/ACg8oc=s96-c';
      expect(leaderboardPhotoUrl(url), url);
    });

    test('accepts our R2 avatars', () {
      const url =
          'https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev/avatars/u1.jpg';
      expect(leaderboardPhotoUrl(url), url);
    });

    test('rejects other hosts, plain http and look-alikes', () {
      for (final url in [
        'https://example.com/a.jpg',
        'http://lh3.googleusercontent.com/a/b',
        'https://lh3.googleusercontent.com.evil.example/a',
        'https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev/other/u1.jpg',
      ]) {
        expect(leaderboardPhotoUrl(url), isNull, reason: url);
      }
    });

    test('rejects null and overlong URLs', () {
      expect(leaderboardPhotoUrl(null), isNull);
      final long = 'https://lh3.googleusercontent.com/${'a' * 2100}';
      expect(leaderboardPhotoUrl(long), isNull);
    });
  });

  group('leaderboardAvatarId', () {
    test('keeps preset ids and drops blank or overlong ones', () {
      expect(leaderboardAvatarId('preset_01'), 'preset_01');
      expect(leaderboardAvatarId(''), isNull);
      expect(leaderboardAvatarId(null), isNull);
      expect(leaderboardAvatarId('a' * 65), isNull);
    });
  });
}
