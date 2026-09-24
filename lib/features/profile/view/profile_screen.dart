import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../domain/usecases/update_avatar.dart';
import '../../../domain/usecases/update_display_name.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import 'widgets/avatar_edit_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipColors.ink,
      appBar: AppBar(
        title: const Text(AppStrings.profileTitle),
        backgroundColor: ZipColors.ink,
        foregroundColor: ZipColors.onInk,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
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
    );
  }
}

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.profileSignedOutTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: ZipColors.onInk),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.profileSignedOutBody,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: ZipColors.inkSoft),
          ),
          const SizedBox(height: 24),
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
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<ProfileCubit>().state.nameDraft,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncName(String nameDraft) {
    if (_nameController.text == nameDraft) return;
    _nameController.value = TextEditingValue(
      text: nameDraft,
      selection: TextSelection.collapsed(offset: nameDraft.length),
    );
  }

  Future<void> _openAvatarSheet() {
    final cubit = context.read<ProfileCubit>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZipColors.wall,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(value: cubit, child: const AvatarEditSheet());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: BlocConsumer<ProfileCubit, ProfileState>(
        listenWhen: (previous, next) => previous.nameDraft != next.nameDraft,
        listener: (context, state) => _syncName(state.nameDraft),
        builder: (context, state) {
          final profile = state.profile ?? widget.fallbackUser;
          final isSaving = state.status == ProfileStatus.saving;
          final nameError =
              state.status == ProfileStatus.failure &&
                  state.failureKind == ProfileFailureKind.name
              ? state.error
              : null;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Semantics(
                    button: true,
                    label: AppStrings.profileEditAvatar,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => unawaited(_openAvatarSheet()),
                      child: UserAvatar(
                        displayName: profile.displayName,
                        photoUrl: profile.photoUrl,
                        avatarId: profile.avatarId,
                        radius: 56,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  enabled: !isSaving,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: ZipColors.onInk),
                  decoration: InputDecoration(
                    labelText: AppStrings.profileEditName,
                    hintText: AppStrings.profileNameHint,
                    errorText: nameError,
                  ),
                  onChanged: context.read<ProfileCubit>().setNameDraft,
                  onSubmitted: (_) =>
                      unawaited(context.read<ProfileCubit>().saveName()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () =>
                            unawaited(context.read<ProfileCubit>().saveName()),
                  child: const Text(AppStrings.profileSave),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    unawaited(context.read<AuthCubit>().signOut());
                  },
                  child: const Text(AppStrings.signOut),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
