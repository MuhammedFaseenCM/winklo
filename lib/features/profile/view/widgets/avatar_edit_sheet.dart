import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/strings/avatar_critter_name.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/avatars/avatar_catalog.dart';
import '../../cubit/profile_cubit.dart';
import '../../cubit/profile_state.dart';

/// Longest side, in pixels, of a picked avatar photo.
const avatarPickMaxSide = 512.0;

/// JPEG quality of a picked avatar photo.
const avatarPickQuality = 85;

/// Largest a critter tile gets; narrow phones shrink it to keep 3 across.
const critterTileMaxSize = 84.0;

/// Your avatar and name over a grid of critters: a tap saves one, and the
/// Photo pill uploads a picture instead.
class AvatarEditSheet extends StatefulWidget {
  const AvatarEditSheet({super.key, this.imagePicker});

  final ImagePicker? imagePicker;

  @override
  State<AvatarEditSheet> createState() => _AvatarEditSheetState();
}

class _AvatarEditSheetState extends State<AvatarEditSheet> {
  /// The critter last tapped, so its tile can show the save in progress.
  String? _pendingId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final isSaving = state.status == ProfileStatus.saving;
            final profile = state.profile;
            final selectedId = profile?.avatarId;
            final savingId = isSaving ? _pendingId : null;
            final avatarError =
                state.status == ProfileStatus.failure &&
                    state.failureKind == ProfileFailureKind.avatar
                ? state.error
                : null;
            return Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: AppStrings.profileEditAvatar,
              child: Column(
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
                  _SheetHeader(
                    displayName: profile?.displayName ?? '',
                    photoUrl: profile?.photoUrl,
                    avatarId: selectedId,
                    onPhoto: isSaving ? null : () => unawaited(_pickPhoto()),
                  ),
                  const SizedBox(height: 20),
                  _CritterGrid(
                    activeId: savingId ?? selectedId,
                    savingId: savingId,
                    onPick: isSaving
                        ? null
                        : (avatarId) {
                            if (avatarId != selectedId) _selectPreset(avatarId);
                          },
                  ),
                  if (avatarError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      avatarError,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectPreset(String avatarId) {
    setState(() => _pendingId = avatarId);
    unawaited(context.read<ProfileCubit>().selectPreset(avatarId));
  }

  Future<void> _pickPhoto() async {
    setState(() => _pendingId = null);
    final picker = widget.imagePicker ?? ImagePicker();
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
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await context.read<ProfileCubit>().uploadPhoto(
        bytes,
        contentType: file.mimeType ?? 'image/jpeg',
      );
    } on PlatformException catch (error) {
      if (!mounted || !_isPermissionDenied(error)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.profilePermissionDenied)),
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

/// Your current avatar and name, the hint, and the Photo pill.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.displayName,
    required this.photoUrl,
    required this.avatarId,
    required this.onPhoto,
  });

  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final VoidCallback? onPhoto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ZipColors.ember, width: 2),
          ),
          child: UserAvatar(
            displayName: displayName,
            photoUrl: photoUrl,
            avatarId: avatarId,
            radius: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.profileAvatarHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: AppStrings.profileChoosePhoto,
          child: OutlinedButton.icon(
            onPressed: onPhoto,
            icon: const AppIcon(AppIcons.photos, size: 16),
            label: Text(AppStrings.profileAvatarPhoto),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              side: const BorderSide(color: ZipColors.outline),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The critters, 3 across.
class _CritterGrid extends StatelessWidget {
  const _CritterGrid({
    required this.activeId,
    required this.savingId,
    required this.onPick,
  });

  /// The ringed tile: the one being saved, else the current avatar.
  final String? activeId;
  final String? savingId;

  /// Null while a save is in flight, which disables every tile.
  final ValueChanged<String>? onPick;

  static const _columns = 3;
  static const _columnGap = 12.0;
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final ids = AvatarCatalog.presetIds.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - _columnGap * (_columns - 1)) / _columns;
        // The selection ring takes 6 dp on each side.
        final size = math.min(critterTileMaxSize, cell - 12);
        return Column(
          children: [
            for (var row = 0; row * _columns < ids.length; row++)
              Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : _rowGap),
                child: Row(
                  children: [
                    for (var col = 0; col < _columns; col++) ...[
                      if (col > 0) const SizedBox(width: _columnGap),
                      Expanded(
                        child: row * _columns + col < ids.length
                            ? _tile(ids[row * _columns + col], size)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tile(String avatarId, double size) {
    final pick = onPick;
    return _CritterTile(
      key: ValueKey('avatar-preset-$avatarId'),
      avatarId: avatarId,
      size: size,
      isActive: avatarId == activeId,
      isSaving: avatarId == savingId,
      onTap: pick == null ? null : () => pick(avatarId),
    );
  }
}

class _CritterTile extends StatelessWidget {
  const _CritterTile({
    super.key,
    required this.avatarId,
    required this.size,
    required this.isActive,
    required this.isSaving,
    required this.onTap,
  });

  final String avatarId;
  final double size;
  final bool isActive;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final critter = AvatarCatalog.critterFor(avatarId)!;
    return Semantics(
      button: true,
      selected: isActive,
      enabled: onTap != null,
      label: avatarCritterName(critter),
      excludeSemantics: true,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZipColors.wall,
            border: Border.all(
              color: isActive ? ZipColors.ember : Colors.transparent,
              width: 3,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: ZipColors.emberGlow,
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(displayName: '', avatarId: avatarId, radius: size / 2),
              // Above the art, so the splash shows on it.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onTap),
                ),
              ),
              if (isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _TileBadge(isSaving: isSaving),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A check on the current critter, or a spinner while it saves.
class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ZipColors.ember,
        shape: BoxShape.circle,
        border: Border.all(color: ZipColors.wall, width: 2),
      ),
      child: isSaving
          ? const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ZipColors.onInk,
              ),
            )
          : const AppIcon(AppIcons.check, size: 12, color: ZipColors.onInk),
    );
  }
}
