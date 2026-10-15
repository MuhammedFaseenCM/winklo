import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/leagues_cubit.dart';
import 'widgets/league_dialogs.dart';
import 'widgets/leagues_page.dart';

/// `/leagues`: my leagues, and creating or joining one.
class LeaguesScreen extends StatelessWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaguesCubit(
        leagueRepository: context.read<LeagueRepository>(),
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _LeaguesView(),
    );
  }
}

class _LeaguesView extends StatelessWidget {
  const _LeaguesView();

  Future<void> _create(BuildContext context) async {
    final name = await showLeagueNameDialog(
      context,
      title: AppStrings.leaguesCreate,
      actionLabel: AppStrings.leagueCreateAction,
    );
    if (name == null || !context.mounted) return;
    final league = await context.read<LeaguesCubit>().create(name);
    if (league == null || !context.mounted) return;
    await context.push('/leagues/${league.id}');
  }

  Future<void> _join(BuildContext context) async {
    final code = await showLeagueCodeDialog(context);
    if (code == null || !context.mounted) return;
    await context.push('/join/$code');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LeaguesCubit, LeaguesState>(
      listenWhen: (p, n) => n.error != null && p.error != n.error,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<LeaguesCubit>().clearError();
      },
      child: LeaguesPage(
        title: AppStrings.leaguesTitle,
        child: BlocBuilder<LeaguesCubit, LeaguesState>(
          builder: (context, state) {
            switch (state.status) {
              case LeaguesStatus.signedOut:
                return CenteredMessageBody(
                  message: AppStrings.leaguesSignIn,
                  actionLabel: AppStrings.signInWithGoogle,
                  onAction: () => showSignInSheet(context),
                );
              case LeaguesStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case LeaguesStatus.failure:
                return CenteredMessageBody(
                  message: AppStrings.leaguesFailed,
                  actionLabel: AppStrings.retry,
                  onAction: context.read<LeaguesCubit>().retry,
                );
              case LeaguesStatus.ready:
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      AppStrings.leaguesIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.leagues.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          AppStrings.leaguesEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: ZipColors.onInk),
                        ),
                      ),
                    for (final league in state.leagues) ...[
                      _LeagueTile(league: league, uid: state.uid),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    ZipPrimaryButton(
                      label: AppStrings.leaguesCreate,
                      icon: Icons.add_rounded,
                      onPressed: state.busy ? null : () => _create(context),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _join(context),
                      icon: const Icon(Icons.vpn_key_rounded),
                      label: const Text(AppStrings.leaguesJoin),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({required this.league, required this.uid});

  final League league;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/leagues/${league.id}'),
        child: LeaguePanel(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZipColors.emberSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded, color: ZipColors.ember),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      league.isOwner(uid)
                          ? '${AppStrings.leagueMembers(league.memberUids.length)}'
                                ' · ${AppStrings.leagueOwner}'
                          : AppStrings.leagueMembers(league.memberUids.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ZipColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
