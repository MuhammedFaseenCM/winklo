/// A 32-bit seed for [key] that is the same on every run.
///
/// Generators that promise "the same puzzle for the same day" can't seed
/// with `Object.hash`: Dart randomizes it per run. This is FNV-1a.
int stableSeed(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// A short id for a puzzle's [canonical] content, so a saved run can tell
/// whether the board it was played on has since been replaced.
String boardFingerprint(String canonical) =>
    stableSeed(canonical).toRadixString(16).padLeft(8, '0');
