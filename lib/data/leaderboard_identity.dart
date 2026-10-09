// Identity values written onto public leaderboard docs, kept within what
// `validLeaderboardIdentity` in firestore/firestore.rules accepts. A value
// the rules reject fails the whole write, so the player's time would never
// reach the board.

/// Longest display name written to a leaderboard doc. The rules allow up to
/// 120, so names with multi-byte characters fit however `size()` counts them.
const leaderboardDisplayNameMaxLength = 40;

/// Longest avatar id the rules accept.
const leaderboardAvatarIdMaxLength = 64;

const _photoUrlMaxLength = 2048;

/// Photo hosts the rules accept on leaderboard docs: Google account photos
/// and our R2 avatars (`PUBLIC_BASE_URL` in workers/avatar-upload). Any other
/// host would see the IP address of everyone who opens the board.
///
/// Must match the pattern in `validLeaderboardIdentity`;
/// test/firestore/rules_leaderboard_identity_test.dart pins both.
const leaderboardPhotoHostsPattern =
    r'([a-z0-9-]+[.]googleusercontent[.]com|pub-94fd8286c7fa4508a0e988821039d2a8[.]r2[.]dev/avatars)';

/// The full `photoUrl` pattern, as written in the rules.
const leaderboardPhotoUrlPattern =
    '^https://$leaderboardPhotoHostsPattern/.*\$';

final _photoUrl = RegExp(leaderboardPhotoUrlPattern);

/// [name] trimmed and cut to [leaderboardDisplayNameMaxLength] UTF-16 units
/// without splitting a surrogate pair; `'Player'` when blank.
String leaderboardDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Player';
  if (trimmed.length <= leaderboardDisplayNameMaxLength) return trimmed;
  var end = leaderboardDisplayNameMaxLength;
  final last = trimmed.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return trimmed.substring(0, end).trimRight();
}

/// [url] when the rules accept it as a leaderboard photo, otherwise null.
String? leaderboardPhotoUrl(String? url) {
  if (url == null || url.length > _photoUrlMaxLength) return null;
  return _photoUrl.hasMatch(url) ? url : null;
}

/// [avatarId] when the rules accept it, otherwise null.
String? leaderboardAvatarId(String? avatarId) {
  if (avatarId == null || avatarId.isEmpty) return null;
  return avatarId.length <= leaderboardAvatarIdMaxLength ? avatarId : null;
}
