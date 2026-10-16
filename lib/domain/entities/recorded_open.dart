/// The last app open this install wrote, and whose it was: `u:<uid>` for a
/// signed-in player, `g:<installId>` for a guest.
class RecordedOpen {
  const RecordedOpen({required this.at, required this.key});

  final DateTime at;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is RecordedOpen &&
      other.at.isAtSameMomentAs(at) &&
      other.key == key;

  @override
  int get hashCode => Object.hash(at.millisecondsSinceEpoch, key);
}
