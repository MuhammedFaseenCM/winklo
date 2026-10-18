/// A streak a freeze carried over a missed day, for Home to mention once:
/// "Your freeze saved your 12-day Zip streak".
class FreezeSavedNotice {
  const FreezeSavedNotice({required this.gameId, required this.days});

  final String gameId;

  /// The streak after the clear that spent the freeze.
  final int days;

  @override
  bool operator ==(Object other) =>
      other is FreezeSavedNotice &&
      other.gameId == gameId &&
      other.days == days;

  @override
  int get hashCode => Object.hash(gameId, days);

  @override
  String toString() => 'FreezeSavedNotice($gameId, $days)';
}
