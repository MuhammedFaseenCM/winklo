import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/league.dart';
import 'leaderboard_sheet_parts.dart';

/// What the scope sheet picked: a league (null for everyone), or the
/// leagues screen.
class LeaderboardScopeChoice {
  const LeaderboardScopeChoice.league(this.leagueId) : manageLeagues = false;

  const LeaderboardScopeChoice.manageLeagues()
    : leagueId = null,
      manageLeagues = true;

  final String? leagueId;
  final bool manageLeagues;
}

/// "Whose scores?": everyone, one of my [leagues], or the leagues screen.
/// Null when dismissed.
Future<LeaderboardScopeChoice?> showLeaderboardScopeSheet(
  BuildContext context, {
  required List<League> leagues,
  required String? selectedLeagueId,
}) {
  return showModalBottomSheet<LeaderboardScopeChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.ink,
    builder: (sheetContext) {
      void pick(LeaderboardScopeChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      return LeaderboardSheetFrame(
        title: AppStrings.leaderboardScopeSheetTitle,
        children: [
          LeaderboardSheetOption(
            key: const Key('leaderboard_scope_everyone'),
            leading: const Icon(Icons.public_rounded, color: ZipColors.ember),
            label: AppStrings.leaderboardScopeEveryone,
            subtitle: AppStrings.leaderboardTop50,
            selected: selectedLeagueId == null,
            onTap: () => pick(const LeaderboardScopeChoice.league(null)),
          ),
          for (final league in leagues)
            LeaderboardSheetOption(
              key: Key('leaderboard_scope_${league.id}'),
              leading: _LeagueMark(name: league.name),
              label: league.name,
              subtitle: AppStrings.leaderboardLeaguePlayers(
                league.memberUids.length,
              ),
              selected: league.id == selectedLeagueId,
              onTap: () => pick(LeaderboardScopeChoice.league(league.id)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('leaderboard_scope_manage'),
            onPressed: () => pick(const LeaderboardScopeChoice.manageLeagues()),
            icon: Icon(
              leagues.isEmpty ? Icons.group_add_rounded : Icons.group_rounded,
            ),
            label: Text(
              leagues.isEmpty
                  ? AppStrings.leaderboardCreateOrJoinLeague
                  : AppStrings.leaderboardManageLeagues,
            ),
          ),
        ],
      );
    },
  );
}

/// A league's first letter on a sky tile.
class _LeagueMark extends StatelessWidget {
  const _LeagueMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ZipColors.skySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          letter,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: ZipColors.sky,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
