import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/leaderboard_identity.dart';

/// The client trims leaderboard identity to what the rules accept; a value the
/// rules reject fails the whole score write. Pin both sides together, along
/// with the avatar Worker's public R2 host.
void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore/firestore.rules').readAsStringSync();
  });

  test('rules use the same photo URL pattern as the client', () {
    expect(rules, contains("photoUrl.matches('$leaderboardPhotoUrlPattern')"));
  });

  test('avatar Worker uploads to a host the pattern accepts', () {
    final wrangler = File(
      'workers/avatar-upload/wrangler.toml',
    ).readAsStringSync();
    final base = RegExp(
      r'PUBLIC_BASE_URL\s*=\s*"([^"]+)"',
    ).firstMatch(wrangler)?.group(1);
    expect(base, isNotNull, reason: 'PUBLIC_BASE_URL not found');
    expect(leaderboardPhotoUrl('$base/avatars/u1.jpg'), isNotNull);
  });

  test('rules allow at least the client name and avatar limits', () {
    final nameCap = RegExp(
      r'displayName\.size\(\) <= (\d+)',
    ).firstMatch(rules)?.group(1);
    final avatarCap = RegExp(
      r'avatarId\.size\(\) <= (\d+)',
    ).firstMatch(rules)?.group(1);
    expect(nameCap, isNotNull);
    expect(avatarCap, isNotNull);
    expect(
      int.parse(nameCap!),
      greaterThanOrEqualTo(leaderboardDisplayNameMaxLength),
    );
    expect(int.parse(avatarCap!), leaderboardAvatarIdMaxLength);
  });
}
