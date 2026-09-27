import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_row.dart';

/// Decorative fake rows for signed-out leaderboard tease.
class LeaderboardSignedOutMock extends StatelessWidget {
  const LeaderboardSignedOutMock({super.key, this.rowCount = 5});

  /// How many mock rows to show (clamped to available entries).
  final int rowCount;

  static final List<LeaderboardEntry> _entries = [
    LeaderboardEntry(
      uid: 'mock-1',
      displayName: 'Nova',
      timeSeconds: 42,
      updatedAt: DateTime(2026, 1, 1),
      rank: 1,
    ),
    LeaderboardEntry(
      uid: 'mock-2',
      displayName: 'Kai',
      timeSeconds: 58,
      updatedAt: DateTime(2026, 1, 1),
      rank: 2,
    ),
    LeaderboardEntry(
      uid: 'mock-3',
      displayName: 'Remy',
      timeSeconds: 71,
      updatedAt: DateTime(2026, 1, 1),
      rank: 3,
    ),
    LeaderboardEntry(
      uid: 'mock-4',
      displayName: 'Sage',
      timeSeconds: 89,
      updatedAt: DateTime(2026, 1, 1),
      rank: 4,
    ),
    LeaderboardEntry(
      uid: 'mock-5',
      displayName: 'Quin',
      timeSeconds: 104,
      updatedAt: DateTime(2026, 1, 1),
      rank: 5,
    ),
  ];

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final count = rowCount.clamp(1, _entries.length);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: layout.pagePadding,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: layout.space(8)),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return LeaderboardRow(
          entry: entry,
          timeLabel: _formatTime(entry.timeSeconds),
          isYou: false,
        );
      },
    );
  }
}
