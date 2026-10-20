import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import 'confirm_action_dialog.dart';

/// Returns `true` when the user confirms sign-out.
Future<bool> showSignOutConfirmDialog(BuildContext context) {
  return showConfirmActionDialog(
    context,
    icon: AppIcons.signOut,
    title: AppStrings.signOutConfirmTitle,
    body: AppStrings.signOutConfirmBody,
    noteIcon: AppIcons.shield,
    note: AppStrings.signOutConfirmNote,
    cancelLabel: AppStrings.signOutConfirmCancel,
    confirmLabel: AppStrings.signOut,
  );
}
