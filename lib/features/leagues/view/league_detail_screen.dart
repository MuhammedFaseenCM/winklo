import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../../domain/repositories/share_repository.dart';
import '../cubit/league_detail_cubit.dart';
import 'widgets/league_dialogs.dart';
import 'widgets/leagues_page.dart';

/// `/leagues/{leagueId}`: the code to share, the players, and what the
/// owner or a member can do.
class LeagueDetailScreen extends StatelessWidget {
  const LeagueDetailScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeagueDetailCubit(
        leagueId: leagueId,
        leagueRepository: context.read<LeagueRepository>(),
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _LeagueDetailView(),
    );
  }
}

class _LeagueDetailView extends StatelessWidget {
  const _LeagueDetailView();

  void _leaveScreen(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/leaderboard');
    }
  }

  Future<void> _rename(BuildContext context, League league) async {
    final name = await showLeagueNameDialog(
      context,
      title: AppStrings.leagueRename,
      actionLabel: AppStrings.leagueSave,
      initialName: league.name,
    );
    if (name == null || !context.mounted) return;
    await context.read<LeagueDetailCubit>().rename(name);
  }

  Future<void> _share(BuildContext context, League league) async {
    try {
      await context.read<ShareRepository>().shareText(
        AppStrings.leagueInviteText(league.name, league.inviteUrl),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.shareFailed)));
    }
  }

  Future<void> _copyCode(BuildContext context, League league) async {
    await Clipboard.setData(ClipboardData(text: league.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.leagueCodeCopied)));
  }

  Future<void> _leaveOrDelete(BuildContext context, bool owner) async {
    final confirmed = await showLeagueConfirmDialog(
      context,
      message: owner
          ? AppStrings.leagueDeleteConfirm
          : AppStrings.leagueLeaveConfirm,
      confirmLabel: owner ? AppStrings.leagueDelete : AppStrings.leagueLeave,
    );
    if (!confirmed || !context.mounted) return;
    final cubit = context.read<LeagueDetailCubit>();
    final done = owner ? await cubit.delete() : await cubit.leave();
    if (done && context.mounted) _leaveScreen(context);
  }

  Future<void> _remove(BuildContext context, String uid, String name) async {
    final confirmed = await showLeagueConfirmDialog(
      context,
      message: AppStrings.leagueRemoveConfirm(name),
      confirmLabel: AppStrings.leagueRemove,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<LeagueDetailCubit>().removeMember(uid);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeagueDetailCubit, LeagueDetailState>(
      listenWhen: (p, n) => n.error != null && p.error != n.error,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<LeagueDetailCubit>().clearError();
      },
      builder: (context, state) {
        final league = state.league;
        final title = league?.name ?? AppStrings.leaguesTitle;
        return LeaguesPage(
          title: title,
          trailing: league != null && state.isOwner
              ? IconButton(
                  tooltip: AppStrings.leagueRename,
                  onPressed: state.busy ? null : () => _rename(context, league),
                  icon: const Icon(Icons.edit_rounded, color: ZipColors.onInk),
                )
              : null,
          child: switch (state.status) {
            LeagueDetailStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            LeagueDetailStatus.gone => CenteredMessageBody(
              message: AppStrings.leagueGone,
              actionLabel: AppStrings.leaguesTitle,
              onAction: () => _leaveScreen(context),
            ),
            LeagueDetailStatus.failure => CenteredMessageBody(
              message: AppStrings.leagueLoadFailed,
              actionLabel: AppStrings.retry,
              onAction: context.read<LeagueDetailCubit>().retry,
            ),
            LeagueDetailStatus.ready => _body(context, state, league!),
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, LeagueDetailState state, League league) {
    final theme = Theme.of(context);
    final owner = state.isOwner;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LeaguePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.leagueMembers(league.memberUids.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                league.code,
                key: const Key('league_code'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: ZipColors.ember,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _share(context, league),
                    icon: const Icon(Icons.share_rounded),
                    label: Text(AppStrings.leagueShareInvite),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyCode(context, league),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(AppStrings.leagueCopyCode),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ZipPrimaryButton(
          label: AppStrings.leagueSeeBoard,
          icon: Icons.emoji_events_rounded,
          onPressed: () => context.go('/leaderboard?league=${league.id}'),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.leagueMembersHeading,
          style: theme.textTheme.titleMedium?.copyWith(
            color: ZipColors.onInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final uid in league.memberUids)
          _MemberRow(
            name:
                state.members[uid]?.displayName ??
                AppStrings.leagueMemberFallbackName,
            photoUrl: state.members[uid]?.photoUrl,
            avatarId: state.members[uid]?.avatarId,
            isOwner: league.isOwner(uid),
            isYou: uid == state.uid,
            onRemove: owner && uid != state.uid && !state.busy
                ? () => _remove(
                    context,
                    uid,
                    state.members[uid]?.displayName ??
                        AppStrings.leagueMemberFallbackName,
                  )
                : null,
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: state.busy ? null : () => _leaveOrDelete(context, owner),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5252)),
          icon: Icon(
            owner ? Icons.delete_outline_rounded : Icons.logout_rounded,
          ),
          label: Text(owner ? AppStrings.leagueDelete : AppStrings.leagueLeave),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.isOwner,
    required this.isYou,
    this.photoUrl,
    this.avatarId,
    this.onRemove,
  });

  final String name;
  final String? photoUrl;
  final String? avatarId;
  final bool isOwner;
  final bool isYou;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = [
      if (isYou) AppStrings.youLabel,
      if (isOwner) AppStrings.leagueOwner,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          UserAvatar(displayName: name, photoUrl: photoUrl, avatarId: avatarId),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tags.isEmpty ? name : '$name · ${tags.join(' · ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: ZipColors.onInk,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: AppStrings.leagueRemove,
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_rounded,
                color: ZipColors.inkSoft,
              ),
            ),
        ],
      ),
    );
  }
}
