import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/avatars/avatar_catalog.dart';
import '../../cubit/profile_cubit.dart';
import '../../cubit/profile_state.dart';

class AvatarEditSheet extends StatelessWidget {
  const AvatarEditSheet({super.key, this.imagePicker});

  final ImagePicker? imagePicker;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final isSaving = state.status == ProfileStatus.saving;
            final selectedId = state.profile?.avatarId;
            final displayName = state.profile?.displayName ?? '';
            final avatarError =
                state.status == ProfileStatus.failure &&
                    state.failureKind == ProfileFailureKind.avatar
                ? state.error
                : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZipColors.mistDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.profileEditAvatar,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: ZipColors.onInk),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.profilePresets,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: ZipColors.inkSoft),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final avatarId in AvatarCatalog.presetIds)
                      _PresetTile(
                        avatarId: avatarId,
                        displayName: displayName,
                        isSelected: avatarId == selectedId,
                        onTap: isSaving
                            ? null
                            : () {
                                unawaited(
                                  context.read<ProfileCubit>().selectPreset(
                                    avatarId,
                                  ),
                                );
                              },
                      ),
                  ],
                ),
                if (avatarError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    avatarError,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () => unawaited(_pickPhoto(context)),
                  child: const Text(AppStrings.profileChoosePhoto),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final picker = imagePicker ?? ImagePicker();
    try {
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      await context.read<ProfileCubit>().uploadPhoto(
        bytes,
        contentType: file.mimeType ?? 'image/jpeg',
      );
    } on PlatformException catch (error) {
      if (!context.mounted || !_isPermissionDenied(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profilePermissionDenied)),
      );
    }
  }

  bool _isPermissionDenied(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('denied') ||
        code.contains('permission') ||
        message.contains('denied') ||
        message.contains('permission');
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.avatarId,
    required this.displayName,
    required this.isSelected,
    required this.onTap,
  });

  final String avatarId;
  final String displayName;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZipColors.wall,
      shape: CircleBorder(
        side: BorderSide(
          color: isSelected ? ZipColors.ember : ZipColors.outlineQuiet,
          width: isSelected ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: UserAvatar(
            displayName: displayName,
            avatarId: avatarId,
            radius: 28,
          ),
        ),
      ),
    );
  }
}
