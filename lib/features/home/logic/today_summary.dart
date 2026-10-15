import '../cubit/home_state.dart';

/// Today's dailies at a glance: "2 of 3 cleared · 3:41 total".
class TodaySummary {
  const TodaySummary({
    required this.cleared,
    this.total = 3,
    this.totalSeconds,
  });

  final int cleared;
  final int total;

  /// The sum of today's clear times; null when no clear has a stored time.
  final int? totalSeconds;

  bool get isPerfectDay => cleared >= total;

  /// Null when none of today's dailies is cleared. A clear counts the same
  /// way the Home tiles do: a stored score or a stored time.
  static TodaySummary? of(HomeState state) {
    final clears = <({bool cleared, int? seconds})>[
      (
        cleared: state.bestPoints > 0 || state.bestTimeSeconds != null,
        seconds: state.bestTimeSeconds,
      ),
      (
        cleared:
            state.pathWordsBestPoints > 0 ||
            state.pathWordsBestTimeSeconds != null,
        seconds: state.pathWordsBestTimeSeconds,
      ),
      (
        cleared:
            state.sudokuBestPoints > 0 || state.sudokuBestTimeSeconds != null,
        seconds: state.sudokuBestTimeSeconds,
      ),
    ].where((game) => game.cleared).toList();
    if (clears.isEmpty) return null;
    final times = [
      for (final game in clears)
        if (game.seconds != null) game.seconds!,
    ];
    return TodaySummary(
      cleared: clears.length,
      totalSeconds: times.isEmpty ? null : times.reduce((a, b) => a + b),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodaySummary &&
      other.cleared == cleared &&
      other.total == total &&
      other.totalSeconds == totalSeconds;

  @override
  int get hashCode => Object.hash(cleared, total, totalSeconds);

  @override
  String toString() =>
      'TodaySummary(cleared: $cleared, total: $total, '
      'totalSeconds: $totalSeconds)';
}
