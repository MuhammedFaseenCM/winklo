enum SoftUpdatePhase {
  /// The banner offers "Update now".
  idle,

  /// Play is downloading the update in the background.
  downloading,

  /// The download is done; the banner offers "Restart to update".
  readyToInstall,
}

class SoftUpdateState {
  const SoftUpdateState({this.snoozedUntil, this.phase = SoftUpdatePhase.idle});

  /// The banner stays hidden until then, after the player closed it.
  final DateTime? snoozedUntil;
  final SoftUpdatePhase phase;

  SoftUpdateState copyWith({DateTime? snoozedUntil, SoftUpdatePhase? phase}) =>
      SoftUpdateState(
        snoozedUntil: snoozedUntil ?? this.snoozedUntil,
        phase: phase ?? this.phase,
      );

  @override
  bool operator ==(Object other) =>
      other is SoftUpdateState &&
      other.snoozedUntil == snoozedUntil &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(snoozedUntil, phase);

  @override
  String toString() =>
      'SoftUpdateState(snoozedUntil: $snoozedUntil, phase: $phase)';
}
