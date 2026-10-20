import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/leaderboard_proof.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../../leaderboard/cubit/leaderboard_cubit.dart';
import '../../leaderboard/cubit/leaderboard_state.dart';
import '../../leaderboard/logic/board_layout.dart';
import '../../leaderboard/logic/mini_leaderboard_slice.dart';
import '../../leaderboard/view/widgets/leaderboard_table.dart';
import '../../leaderboard/view/widgets/player_card_sheet.dart';

/// The "···" row between the podium and the player's part of the board.
const double miniLeaderboardGapRowHeight = 20;

/// The day's board on Results: the podium, the player and their neighbours,
/// as many as fit the height it's given.
class MiniLeaderboardPanel extends StatelessWidget {
  const MiniLeaderboardPanel({
    super.key,
    required this.gameId,
    this.cubit,
    this.timeSeconds = 0,
    this.usedHints,
    this.hadMistakes,
    this.currentStreak,
    this.dayId,
    this.leaderboardProof,
  });

  final String gameId;

  /// The board the Results screen already watches (its rank badge reads it
  /// too); null makes one here.
  final LeaderboardCubit? cubit;
  final int timeSeconds;
  final bool? usedHints;
  final bool? hadMistakes;
  final int? currentStreak;

  /// The cleared day's board (`yyyy-MM-dd`) and the run's proof, for a
  /// guest who signs in here to save the time.
  final String? dayId;
  final LeaderboardProof? leaderboardProof;

  @override
  Widget build(BuildContext context) {
    final body = _MiniLeaderboardBody(
      gameId: gameId,
      timeSeconds: timeSeconds,
      usedHints: usedHints,
      hadMistakes: hadMistakes,
      currentStreak: currentStreak,
      dayId: dayId,
      leaderboardProof: leaderboardProof,
    );
    final existing = cubit;
    if (existing != null) {
      return BlocProvider.value(value: existing, child: body);
    }
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: gameId,
      )..selectDay(dayId),
      child: body,
    );
  }
}

class _MiniLeaderboardBody extends StatelessWidget {
  const _MiniLeaderboardBody({
    required this.gameId,
    required this.timeSeconds,
    this.usedHints,
    this.hadMistakes,
    this.currentStreak,
    this.dayId,
    this.leaderboardProof,
  });

  final String gameId;
  final int timeSeconds;
  final bool? usedHints;
  final bool? hadMistakes;
  final int? currentStreak;
  final String? dayId;
  final LeaderboardProof? leaderboardProof;

  Future<void> _signInAndSync(BuildContext context) async {
    final ok = await showSignInSheet(context);
    if (!ok || !context.mounted) return;
    if (timeSeconds <= 0) return;
    try {
      await context.read<SubmitLeaderboardTime>()(
        gameId: gameId,
        timeSeconds: timeSeconds,
        usedHints: usedHints ?? true,
        hadMistakes: hadMistakes ?? true,
        currentStreak: currentStreak ?? 0,
        dayId: dayId,
        proof: leaderboardProof,
      );
    } catch (_) {
      // Best-effort remote sync; signed-in UI still shows live board.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        final signedIn = context.watch<AuthCubit>().isSignedIn;
        if (!signedIn) {
          return CenteredMessageBody(
            message: AppStrings.leaderboardSignInHint,
            actionLabel: AppStrings.signInWithGoogle,
            onAction: () => _signInAndSync(context),
          );
        }
        switch (state.status) {
          case LeaderboardStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case LeaderboardStatus.failure:
            return CenteredMessageBody(
              message: AppStrings.leaderboardFailed,
              actionLabel: AppStrings.retry,
              onAction: () => context.read<LeaderboardCubit>().retry(),
            );
          case LeaderboardStatus.ready:
            if (state.entries.isEmpty) {
              return CenteredMessageBody(message: AppStrings.leaderboardEmpty);
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                // Room for a gap row is always kept, so the rows that fit
                // never push the last one out of view.
                final rows =
                    ((constraints.maxHeight - miniLeaderboardGapRowHeight) /
                            leaderboardTableRowHeight)
                        .floor();
                return _MiniTable(
                  gameId: gameId,
                  entries: state.entries,
                  currentUid: state.currentUid,
                  items: fitLeaderboardForMini(
                    entries: state.entries,
                    currentUid: state.currentUid,
                    maxRows: math.max(1, rows),
                  ),
                );
              },
            );
        }
      },
    );
  }
}

/// The fitted rows. When even the podium and the player don't fit, the
/// list scrolls, and it starts with the player's row in view.
class _MiniTable extends StatefulWidget {
  const _MiniTable({
    required this.gameId,
    required this.entries,
    required this.currentUid,
    required this.items,
  });

  final String gameId;
  final List<LeaderboardEntry> entries;
  final String? currentUid;
  final List<MiniLeaderboardItem> items;

  @override
  State<_MiniTable> createState() => _MiniTableState();
}

class _MiniTableState extends State<_MiniTable> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMe());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _heightOf(MiniLeaderboardItem item) => switch (item) {
    MiniLeaderboardGap() => miniLeaderboardGapRowHeight,
    MiniLeaderboardEntryItem() => leaderboardTableRowHeight,
  };

  void _showMe() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    var top = 0.0;
    for (final item in widget.items) {
      if (item case MiniLeaderboardEntryItem(
        :final entry,
      ) when entry.uid == widget.currentUid) {
        final centred =
            top - (position.viewportDimension - leaderboardTableRowHeight) / 2;
        _controller.jumpTo(centred.clamp(0, position.maxScrollExtent));
        return;
      }
      top += _heightOf(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final leader = widget.entries.first;
    return ListView.builder(
      controller: _controller,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final last = index == items.length - 1;
        return switch (items[index]) {
          MiniLeaderboardGap() => const _GapRow(),
          MiniLeaderboardEntryItem(:final entry) => LeaderboardTableRow(
            entry: entry,
            period: LeaderboardPeriod.daily,
            gameId: widget.gameId,
            isYou: entry.uid == widget.currentUid,
            showMedals: true,
            showDivider: !last,
            gapSeconds: leaderboardGapSeconds(
              entry: entry,
              ahead: leader,
              period: LeaderboardPeriod.daily,
            ),
            onTap: () => showPlayerCardSheet(
              context,
              entry: entry,
              gameId: widget.gameId,
              period: LeaderboardPeriod.daily,
              isYou: entry.uid == widget.currentUid,
            ),
          ),
        };
      },
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: miniLeaderboardGapRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ZipColors.outlineQuiet.withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Text(
        AppStrings.leaderboardGapEllipsis,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: ZipColors.inkSoft, height: 1),
      ),
    );
  }
}
