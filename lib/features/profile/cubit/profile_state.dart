import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/app_user.dart';

part 'profile_state.freezed.dart';

enum ProfileStatus { idle, saving, failure, refreshing }

enum ProfileFailureKind { none, name, avatar, watchProfile }

@freezed
sealed class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(ProfileStatus.idle) ProfileStatus status,
    AppUser? profile,
    String? error,
    @Default(ProfileFailureKind.none) ProfileFailureKind failureKind,
    @Default('') String nameDraft,
    @Default(false) bool nameDraftTouched,
  }) = _ProfileState;
}
