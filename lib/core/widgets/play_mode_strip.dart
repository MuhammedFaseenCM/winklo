import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/play_mode.dart';
import '../../domain/play_mode_hints.dart';
import '../../domain/repositories/hint_quota_repository.dart';
import '../../domain/repositories/play_mode_record_repository.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// Reads what a game run of a [PlayMode] spends and keeps.
extension PlayModeReads on BuildContext {
  /// The daily quota for a daily; the mode's own quota otherwise, so a past
  /// day or a practice board never spends today's hints.
  HintQuotaRepository hintQuotaFor(PlayMode mode) => mode.isDaily
      ? read<HintQuotaRepository>()
      : read<HintQuotaForMode>()(mode);

  /// Where archive and practice runs keep their bests; null for a daily.
  PlayModeRecordRepository? modeRecordsFor(PlayMode mode) =>
      mode.isDaily ? null : read<PlayModeRecordRepository>();
}

/// The hint button's label: "Hint (2)", or plain "Hint" when [quota] never
/// runs out (practice).
String hintLabelFor(
  HintQuotaRepository quota,
  int remaining,
  String Function(int remaining) withCount,
) => UnlimitedHintQuota.isUnlimited(quota)
    ? AppStrings.hintUnlimited
    : withCount(remaining);

/// "Archive · 9 Oct" or "Practice" under a game's header, so a run off the
/// dailies never looks like today's puzzle. Practice adds New board.
class PlayModeStrip extends StatelessWidget {
  const PlayModeStrip({super.key, required this.mode, this.onNewBoard});

  final PlayMode mode;

  /// Practice only; null hides the button (or disables it mid-celebration).
  final VoidCallback? onNewBoard;

  @override
  Widget build(BuildContext context) {
    if (mode.isDaily) return const SizedBox.shrink();
    final label = mode.isArchive
        ? AppStrings.archiveRunLabel(mode.day!)
        : AppStrings.practiceRunLabel;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: ZipColors.sky,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZipColors.skySoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ZipColors.sky.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode.isArchive
                      ? Icons.calendar_month_rounded
                      : Icons.all_inclusive_rounded,
                  size: 14,
                  color: style?.color,
                ),
                const SizedBox(width: 6),
                Text(label, style: style),
              ],
            ),
          ),
          const Spacer(),
          if (mode.isPractice)
            TextButton.icon(
              onPressed: onNewBoard,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: ZipColors.onInk,
              ),
              icon: const Icon(Icons.casino_rounded, size: 18),
              label: const Text(AppStrings.practiceNewBoard),
            ),
        ],
      ),
    );
  }
}
