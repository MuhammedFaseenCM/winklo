import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Shows Google sign-in UI. Returns `true` when the user ends signed in.
Future<bool> showSignInSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: ZipColors.wall,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return BlocProvider.value(
        value: context.read<AuthCubit>(),
        child: const _SignInSheetBody(),
      );
    },
  );
  return result ?? false;
}

class _SignInSheetBody extends StatelessWidget {
  const _SignInSheetBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: BlocConsumer<AuthCubit, AuthState>(
          listenWhen: (prev, next) =>
              prev.status != next.status || prev.user != next.user,
          listener: (context, state) {
            if (state.status == AuthStatus.signedIn && state.user != null) {
              Navigator.of(context).pop(true);
            }
          },
          builder: (context, state) {
            final isBusy = state.status == AuthStatus.signingIn;
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
                  AppStrings.signInTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: ZipColors.onInk),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.signInBody,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: ZipColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                if (state.status == AuthStatus.failure &&
                    state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: ZipColors.ember),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () => context.read<AuthCubit>().signIn(),
                  child: isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.signInWithGoogle),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(AppStrings.signInCancel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
