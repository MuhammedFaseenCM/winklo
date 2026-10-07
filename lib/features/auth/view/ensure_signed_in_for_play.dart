import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/usecases/sync_progress.dart';
import '../cubit/auth_cubit.dart';
import 'sign_in_sheet.dart';

/// How long a fresh sign-in waits for remote progress before opening a game.
const ensureSignedInSyncTimeout = Duration(seconds: 3);

/// True while a call waits for the post-sign-in sync (bounded by
/// [ensureSignedInSyncTimeout], so it always resets).
bool _syncAfterSignInPending = false;

/// Returns true if the user is (or becomes) signed in and may open a game.
///
/// After a fresh sign-in this waits (up to [ensureSignedInSyncTimeout]) for a
/// full progress sync, so a reinstalled user's cleared days are restored and
/// locked before the game opens.
///
/// Nothing on screen blocks input during that wait, so every other call
/// returns false until it ends: a second tap on Play cannot open the game
/// while the first call is about to.
Future<bool> ensureSignedInForPlay(BuildContext context) async {
  if (_syncAfterSignInPending) return false;
  final auth = context.read<AuthCubit>();
  if (auth.isSignedIn) return true;
  final ok = await showSignInSheet(
    context,
    title: AppStrings.playSignInTitle,
    body: AppStrings.playSignInBody,
  );
  if (!ok || !context.mounted) return ok;
  _syncAfterSignInPending = true;
  try {
    await context
        .read<SyncProgress>()
        .call(pull: true)
        .timeout(ensureSignedInSyncTimeout);
  } catch (_) {
    // Best effort: the progress sync lifecycle retries; play is not blocked.
  } finally {
    _syncAfterSignInPending = false;
  }
  return ok;
}
