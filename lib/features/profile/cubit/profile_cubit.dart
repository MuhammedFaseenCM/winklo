import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/failures.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../domain/usecases/update_avatar.dart';
import '../../../domain/usecases/update_display_name.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required ProfileRepository profileRepository,
    required UpdateDisplayName updateDisplayName,
    required UpdateAvatar updateAvatar,
    required String? uid,
  }) : _profileRepository = profileRepository,
       _updateDisplayName = updateDisplayName,
       _updateAvatar = updateAvatar,
       _uid = uid,
       super(const ProfileState()) {
    if (uid == null) return;
    _subscription = _profileRepository
        .watchProfile(uid)
        .listen(
          _onProfile,
          onError: (Object error) {
            if (isClosed) return;
            final message = error is Failure
                ? error.message
                : AppStrings.profileSaveFailed;
            emit(
              state.copyWith(
                status: ProfileStatus.failure,
                error: message,
                failureKind: ProfileFailureKind.watchProfile,
              ),
            );
          },
        );
  }

  final ProfileRepository _profileRepository;
  final UpdateDisplayName _updateDisplayName;
  final UpdateAvatar _updateAvatar;
  final String? _uid;
  StreamSubscription<AppUser?>? _subscription;

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null || isClosed) return;
    emit(
      state.copyWith(
        status: ProfileStatus.refreshing,
        error: null,
        failureKind: ProfileFailureKind.none,
      ),
    );
    try {
      final user = await _profileRepository.getProfile(uid);
      if (isClosed) return;
      final seedName = !state.nameDraftTouched && user != null;
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          profile: user,
          nameDraft: seedName ? user.displayName : state.nameDraft,
          error: null,
          failureKind: ProfileFailureKind.none,
        ),
      );
    } on Failure catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          error: error.message,
          failureKind: ProfileFailureKind.watchProfile,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          error: AppStrings.profileSaveFailed,
          failureKind: ProfileFailureKind.watchProfile,
        ),
      );
    }
  }

  void setNameDraft(String value) {
    emit(state.copyWith(nameDraft: value, nameDraftTouched: true));
  }

  Future<void> saveName() async {
    final Future<AppUser> pending;
    try {
      pending = _updateDisplayName(state.nameDraft);
    } on Failure catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          error: error.message,
          failureKind: ProfileFailureKind.name,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProfileStatus.saving,
        error: null,
        failureKind: ProfileFailureKind.none,
      ),
    );
    try {
      final user = await pending;
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          profile: user,
          nameDraft: user.displayName,
          error: null,
          failureKind: ProfileFailureKind.none,
        ),
      );
    } on Failure catch (error) {
      _emitNameFailure(error.message);
    } catch (_) {
      _emitNameFailure(AppStrings.profileSaveFailed);
    }
  }

  Future<void> selectPreset(String avatarId) async {
    emit(
      state.copyWith(
        status: ProfileStatus.saving,
        error: null,
        failureKind: ProfileFailureKind.none,
      ),
    );
    try {
      final user = await _updateAvatar.preset(avatarId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          profile: user,
          error: null,
          failureKind: ProfileFailureKind.none,
        ),
      );
    } on Failure catch (error) {
      _emitAvatarFailure(error.message);
    } catch (_) {
      _emitAvatarFailure(AppStrings.profileSaveFailed);
    }
  }

  Future<void> uploadPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    emit(
      state.copyWith(
        status: ProfileStatus.saving,
        error: null,
        failureKind: ProfileFailureKind.none,
      ),
    );
    try {
      final user = await _updateAvatar.photo(bytes, contentType: contentType);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileStatus.idle,
          profile: user,
          error: null,
          failureKind: ProfileFailureKind.none,
        ),
      );
    } on Failure catch (error) {
      _emitAvatarFailure(error.message);
    } catch (_) {
      _emitAvatarFailure(AppStrings.profileUploadFailed);
    }
  }

  void _onProfile(AppUser? user) {
    if (isClosed) return;
    final seedName = !state.nameDraftTouched && user != null;
    emit(
      state.copyWith(
        profile: user,
        nameDraft: seedName ? user.displayName : state.nameDraft,
      ),
    );
  }

  void _emitNameFailure(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileStatus.failure,
        error: message,
        failureKind: ProfileFailureKind.name,
      ),
    );
  }

  void _emitAvatarFailure(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileStatus.failure,
        error: message,
        failureKind: ProfileFailureKind.avatar,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
