import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/app_user.dart';

part 'auth_state.freezed.dart';

enum AuthStatus { unknown, signedOut, signedIn, signingIn, failure }

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.unknown) AuthStatus status,
    AppUser? user,
    String? error,
  }) = _AuthState;
}
