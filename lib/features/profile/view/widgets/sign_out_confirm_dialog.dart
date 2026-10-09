import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import 'confirm_action_dialog.dart';

/// Returns `true` when the user confirms sign-out.
Future<bool> showSignOutConfirmDialog(BuildContext context) {
  return showConfirmActionDialog(
    context,
    icon: Icons.logout_rounded,
    title: AppStrings.signOutConfirmTitle,
    body: AppStrings.signOutConfirmBody,
    noteIcon: Icons.shield_outlined,
    note: AppStrings.signOutConfirmNote,
    cancelLabel: AppStrings.signOutConfirmCancel,
    confirmLabel: AppStrings.signOut,
  );
}
