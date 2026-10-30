import 'play_mode.dart';
import 'repositories/hint_quota_repository.dart';

/// Where a run of [PlayMode] counts its hints: the daily count for dailies,
/// the archive's own (per run, never synced) and practice's (in memory).
/// DI provides the three; a past day or a practice board never spends
/// today's hints.
class HintQuotaForMode {
  const HintQuotaForMode({
    required this.daily,
    required this.archive,
    required this.practice,
    required this.level,
  });

  final HintQuotaRepository daily;
  final HintQuotaRepository archive;
  final HintQuotaRepository practice;

  /// Level runs count hints in memory: a hint costs a star, not time, and a
  /// draft keeps `usedHintsThisRun` itself.
  final HintQuotaRepository level;

  HintQuotaRepository call(PlayMode mode) {
    switch (mode.kind) {
      case PlayModeKind.daily:
        return daily;
      case PlayModeKind.archive:
        return archive;
      case PlayModeKind.practice:
        return practice;
      case PlayModeKind.level:
        return level;
    }
  }
}
