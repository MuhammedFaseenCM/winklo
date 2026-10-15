import 'play_mode.dart';
import 'repositories/hint_quota_repository.dart';

/// The hint quota a run of [PlayMode] spends: the daily quota for dailies,
/// the archive's own (3 per run, never synced) and practice's (no limit).
/// DI provides the three; a past day or a practice board never spends
/// today's hints.
class HintQuotaForMode {
  const HintQuotaForMode({
    required this.daily,
    required this.archive,
    required this.practice,
  });

  final HintQuotaRepository daily;
  final HintQuotaRepository archive;
  final HintQuotaRepository practice;

  HintQuotaRepository call(PlayMode mode) {
    switch (mode.kind) {
      case PlayModeKind.daily:
        return daily;
      case PlayModeKind.archive:
        return archive;
      case PlayModeKind.practice:
        return practice;
    }
  }
}
