class GameStreak {
  /// [freezeCount] is how many streak freezes are banked (0 to [maxFreezes]).
  /// When it is null it comes from [freezeAvailable], the yes/no flag older
  /// builds store: true is one freeze, false is none.
  const GameStreak({
    required this.gameId,
    this.current = 0,
    this.longest = 0,
    this.lastClearedDateId,
    int? freezeCount,
    bool freezeAvailable = true,
    this.isOnFreeze = false,
  }) : freezeCount = freezeCount ?? (freezeAvailable ? 1 : 0);

  /// Most freezes a streak can bank.
  static const maxFreezes = 2;

  /// A clear that brings the current streak to a multiple of this earns a
  /// freeze.
  static const freezeEarnEvery = 7;

  final String gameId;
  final int current;
  final int longest;
  final String? lastClearedDateId;

  /// Freezes banked for a missed day.
  final int freezeCount;

  /// Display-only: true when the streak is protected by an unused freeze.
  final bool isOnFreeze;

  /// Whether a freeze is banked. Still stored for older builds, which only
  /// know this flag.
  bool get freezeAvailable => freezeCount > 0;

  /// [freezeCount] wins over [freezeAvailable] when both are given;
  /// `freezeAvailable: true` keeps a count above zero as it is.
  GameStreak copyWith({
    String? gameId,
    int? current,
    int? longest,
    String? lastClearedDateId,
    int? freezeCount,
    bool? freezeAvailable,
    bool? isOnFreeze,
    bool clearLastClearedDateId = false,
  }) {
    return GameStreak(
      gameId: gameId ?? this.gameId,
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastClearedDateId: clearLastClearedDateId
          ? null
          : (lastClearedDateId ?? this.lastClearedDateId),
      freezeCount:
          freezeCount ??
          switch (freezeAvailable) {
            null => this.freezeCount,
            true => this.freezeCount > 0 ? this.freezeCount : 1,
            false => 0,
          },
      isOnFreeze: isOnFreeze ?? this.isOnFreeze,
    );
  }
}
