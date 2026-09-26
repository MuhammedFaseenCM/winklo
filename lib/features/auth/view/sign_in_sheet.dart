import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Shows Google sign-in UI. Returns `true` when the user ends signed in.
Future<bool> showSignInSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: ZipColors.wall,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: ZipColors.glassBorder),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: BlocConsumer<AuthCubit, AuthState>(
          // Only close on the transition into signed-in. Follow-up profile
          // merges emit signedIn again and must not pop the shell page.
          listenWhen: (prev, next) =>
              next.status == AuthStatus.signedIn &&
              next.user != null &&
              prev.status != AuthStatus.signedIn,
          listener: (context, state) {
            final navigator = Navigator.of(context);
            if (!navigator.canPop()) return;
            navigator.pop(true);
          },
          builder: (context, state) {
            final isBusy = state.status == AuthStatus.signingIn;
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
                const Center(child: ZipMark(size: 40)),
                const SizedBox(height: 12),
                Text(
                  AppStrings.signInTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.signInBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ZipColors.inkSoft,
                  ),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 4),
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
