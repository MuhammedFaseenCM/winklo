import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/join_league_cubit.dart';
import 'widgets/leagues_page.dart';

/// `/join/{code}`, where an invite link lands.
class JoinLeagueScreen extends StatelessWidget {
  const JoinLeagueScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => JoinLeagueCubit(
        code: code,
        leagueRepository: context.read<LeagueRepository>(),
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _JoinLeagueView(),
    );
  }
}

class _JoinLeagueView extends StatelessWidget {
  const _JoinLeagueView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JoinLeagueCubit, JoinLeagueState>(
      listenWhen: (p, n) => n.status == JoinLeagueStatus.joined,
      listener: (context, state) {
        final league = state.league;
        if (league != null) context.go('/leagues/${league.id}');
      },
      builder: (context, state) {
        final cubit = context.read<JoinLeagueCubit>();
        return LeaguesPage(
          title: AppStrings.joinLeagueTitle,
          child: switch (state.status) {
            JoinLeagueStatus.loading ||
            JoinLeagueStatus.joining ||
            JoinLeagueStatus.joined => const Center(
              child: CircularProgressIndicator(),
            ),
            JoinLeagueStatus.badCode => CenteredMessageBody(
              message: AppStrings.joinLeagueBadCode,
            ),
            JoinLeagueStatus.signedOut => CenteredMessageBody(
              message: AppStrings.joinLeagueSignIn,
              actionLabel: AppStrings.signInWithGoogle,
              onAction: () => showSignInSheet(context),
            ),
            JoinLeagueStatus.notFound => CenteredMessageBody(
              message: AppStrings.joinLeagueNotFound(state.code),
            ),
            JoinLeagueStatus.full => CenteredMessageBody(
              message: AppStrings.joinLeagueFull,
            ),
            JoinLeagueStatus.failure => CenteredMessageBody(
              message: AppStrings.leagueActionFailed,
              actionLabel: AppStrings.retry,
              onAction: cubit.retry,
            ),
            JoinLeagueStatus.found ||
            JoinLeagueStatus.alreadyMember => _Invite(state: state),
          },
        );
      },
    );
  }
}

class _Invite extends StatelessWidget {
  const _Invite({required this.state});

  final JoinLeagueState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final league = state.league!;
    final member = state.status == JoinLeagueStatus.alreadyMember;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LeaguePanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIcons.group, color: ZipColors.ember, size: 40),
              const SizedBox(height: 12),
              Text(
                league.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.leagueMembers(league.memberUids.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              if (member) ...[
                Text(
                  AppStrings.joinLeagueAlreadyIn,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: ZipColors.onInk,
                  ),
                ),
                const SizedBox(height: 12),
                ZipPrimaryButton(
                  label: AppStrings.leagueSeeBoard,
                  icon: AppIcons.trophy,
                  onPressed: () =>
                      context.go('/leaderboard?league=${league.id}'),
                ),
              ] else
                ZipPrimaryButton(
                  key: const Key('join_league_button'),
                  label: AppStrings.joinLeagueButton,
                  icon: AppIcons.groupAdd,
                  onPressed: context.read<JoinLeagueCubit>().join,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
