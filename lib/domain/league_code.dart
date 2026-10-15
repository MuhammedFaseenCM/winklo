import 'dart:math';

/// Letters and digits a league code is made of: no I, L, O, 0 or 1, which
/// read alike. `validLeagueCode` in firestore/firestore.rules uses the same.
const leagueCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const leagueCodeLength = 6;

/// A league holds 1 to 30 players (`whereIn` takes at most 30 ids).
const leaguesMaxMembers = 30;

/// Longest league name, in characters.
const leagueNameMaxLength = 30;

/// Where an invite link points; the app opens it as `/join/CODE`.
const leagueInviteBaseUrl = 'https://winklo.pages.dev/join/';

final _codePattern = RegExp('^[$leagueCodeAlphabet]{$leagueCodeLength}\$');

/// League docs get Firestore's generated ids: 20 letters and digits.
final _leagueIdPattern = RegExp(r'^[A-Za-z0-9]{20}$');

/// Whether [id] can be a league's doc id (`/leagues/{leagueId}`).
bool isLeagueId(String id) => _leagueIdPattern.hasMatch(id);

/// A new random code (the caller checks it isn't taken).
String generateLeagueCode([Random? random]) {
  final rng = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < leagueCodeLength; i++)
      leagueCodeAlphabet.codeUnitAt(rng.nextInt(leagueCodeAlphabet.length)),
  ]);
}

/// [input] as a code (`ABC-DEF`, ` abcdef `, or a whole invite link), or null
/// when it can't be one.
String? normalizeLeagueCode(String input) {
  var text = input.trim();
  final slash = text.lastIndexOf('/');
  if (slash >= 0) text = text.substring(slash + 1);
  final code = text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return _codePattern.hasMatch(code) ? code : null;
}

String leagueInviteUrl(String code) => '$leagueInviteBaseUrl$code';

/// [name] trimmed, or null when it's blank or longer than
/// [leagueNameMaxLength].
String? cleanLeagueName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.length > leagueNameMaxLength) return null;
  return trimmed;
}
