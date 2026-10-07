import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blurred_mock_empty_body.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../domain/usecases/update_avatar.dart';
import '../../../domain/usecases/update_display_name.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import 'widgets/about_game_dialog.dart';
import 'widgets/avatar_edit_sheet.dart';
import 'widgets/name_edit_sheet.dart';
import 'widgets/profile_settings_list.dart';
import 'widgets/profile_shimmer.dart';
import 'widgets/profile_signed_out_mock.dart';
import 'widgets/sign_out_confirm_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipColors.ink,
      appBar: AppBar(
        title: const Text(
          AppStrings.profileTitle,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ZipColors.onInk,
      ),
      body: ZipAtmosphere(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state.status == AuthStatus.unknown) {
              return const ProfileShimmer();
            }
            final user = state.user;
            if (user == null) {
              return const _SignedOutBody();
            }
            return BlocProvider(
              create: (context) => ProfileCubit(
                profileRepository: context.read<ProfileRepository>(),
                updateDisplayName: context.read<UpdateDisplayName>(),
                updateAvatar: context.read<UpdateAvatar>(),
                uid: user.uid,
              ),
              child: _SignedInBody(fallbackUser: user),
            );
          },
        ),
      ),
    );
  }
}

class _SignedOutBody extends StatefulWidget {
  const _SignedOutBody();

  @override
  State<_SignedOutBody> createState() => _SignedOutBodyState();
}

class _SignedOutBodyState extends State<_SignedOutBody> {
  @override
  Widget build(BuildContext context) {
    final sfx = context.read<SfxService>();
    return BlurredMockEmptyBody(
      background: const ProfileSignedOutMock(),
      message: AppStrings.profileSignedOutBody,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.volume_up_outlined,
              color: ZipColors.teal,
            ),
            title: Text(
              AppStrings.profileSoundEffects,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Switch.adaptive(
              value: sfx.isEnabled,
              onChanged: (value) async {
                await sfx.setEnabled(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => showSignInSheet(context),
            child: const Text(AppStrings.signInWithGoogle),
          ),
        ],
      ),
    );
  }
}

class _SignedInBody extends StatefulWidget {
  const _SignedInBody({required this.fallbackUser});

  final AppUser fallbackUser;

  @override
  State<_SignedInBody> createState() => _SignedInBodyState();
}

class _SignedInBodyState extends State<_SignedInBody> {
  Future<void> _openAvatarSheet(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: ZipColors.wall,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(value: cubit, child: const AvatarEditSheet());
      },
    );
  }

  Future<void> _openNameSheet(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: ZipColors.wall,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(value: cubit, child: const NameEditSheet());
      },
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    await context.read<AnalyticsRepository>().logProfilePrivacyOpened();
    if (!context.mounted) return;
    await context.push('/profile/privacy');
  }

  Future<void> _openReport(BuildContext context) async {
    final user =
        context.read<ProfileCubit>().state.profile ?? widget.fallbackUser;
    if (!context.mounted) return;
    await context.push('/profile/report', extra: user);
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showSignOutConfirmDialog(context);
    if (!confirmed || !context.mounted) return;
    await context.read<AnalyticsRepository>().logProfileSignOut();
    if (!context.mounted) return;
    await context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final sfx = context.read<SfxService>();
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (previous, next) =>
          next.status == ProfileStatus.failure &&
          next.failureKind != ProfileFailureKind.name &&
          next.failureKind != ProfileFailureKind.avatar &&
          next.error != null &&
          (previous.status != next.status ||
              previous.error != next.error ||
              previous.failureKind != next.failureKind),
      listener: (context, state) {
        final message = state.error;
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.refreshing) {
            return const ProfileShimmer();
          }
          final profile = state.profile ?? widget.fallbackUser;
          return RefreshIndicator(
            color: ZipColors.ember,
            backgroundColor: ZipColors.wall,
            onRefresh: () => context.read<ProfileCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: layout.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: layout.space(8)),
                  Center(
                    child: Semantics(
                      button: true,
                      label: AppStrings.profileEditAvatar,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => unawaited(_openAvatarSheet(context)),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: ZipColors.emberGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: ZipColors.emberGlow.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ZipColors.ink,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: UserAvatar(
                                  displayName: profile.displayName,
                                  photoUrl: profile.photoUrl,
                                  avatarId: profile.avatarId,
                                  radius: 54,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Material(
                                color: ZipColors.ember,
                                shape: const CircleBorder(),
                                elevation: 4,
                                shadowColor: ZipColors.emberGlow,
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: ZipColors.onInk,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: layout.space(16)),
                  Text(
                    profile.displayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => unawaited(_openNameSheet(context)),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: ZipColors.ember,
                      ),
                      label: const Text(
                        AppStrings.profileEditDisplayName,
                        style: TextStyle(
                          color: ZipColors.ember,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: layout.space(16)),
                  ProfileSettingsList(
                    sfxEnabled: sfx.isEnabled,
                    onSfxChanged: (value) async {
                      await sfx.setEnabled(value);
                      if (!mounted) return;
                      setState(() {});
                    },
                    onPrivacy: () => unawaited(_openPrivacy(context)),
                    onAbout: () => unawaited(showAboutGameDialog(context)),
                    onReport: () => unawaited(_openReport(context)),
                    onSignOut: () => unawaited(_signOut(context)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
