import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import 'confirm_action_dialog.dart';

/// Returns `true` when the user wants to continue to the deletion page.
Future<bool> showDeleteAccountConfirmDialog(BuildContext context) {
  return showConfirmActionDialog(
    context,
    icon: Icons.person_remove_outlined,
    title: AppStrings.deleteAccountConfirmTitle,
    body: AppStrings.deleteAccountConfirmBody,
    noteIcon: Icons.open_in_new,
    note: AppStrings.deleteAccountConfirmNote,
    cancelLabel: AppStrings.signOutConfirmCancel,
    confirmLabel: AppStrings.deleteAccountConfirmContinue,
  );
}
