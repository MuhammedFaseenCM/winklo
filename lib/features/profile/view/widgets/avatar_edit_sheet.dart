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

/// Longest side, in pixels, of a picked avatar photo.
const avatarPickMaxSide = 512.0;

/// JPEG quality of a picked avatar photo.
const avatarPickQuality = 85;

class AvatarEditSheet extends StatelessWidget {
  const AvatarEditSheet({super.key, this.imagePicker});

  final ImagePicker? imagePicker;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.profileEditAvatar,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.profilePresets,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ZipColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => unawaited(_pickPhoto(context)),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text(AppStrings.profileChoosePhoto),
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
      // Avatars show at most ~128 dp; scaling and re-encoding here keeps a
      // camera photo far below the upload limit (2 MiB) instead of
      // rejecting it.
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: avatarPickMaxSide,
        maxHeight: avatarPickMaxSide,
        imageQuality: avatarPickQuality,
      );
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? ZipColors.ember : const Color(0x22FFFFFF),
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ZipColors.emberGlow.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(2),
      child: Material(
        color: ZipColors.wall,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(
                displayName: displayName,
                avatarId: avatarId,
                radius: 28,
              ),
              if (isSelected)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ZipColors.ember,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: ZipColors.onInk,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
