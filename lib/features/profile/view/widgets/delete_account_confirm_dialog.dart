import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import 'confirm_action_dialog.dart';

/// Returns `true` when the user wants to continue to the deletion page.
Future<bool> showDeleteAccountConfirmDialog(BuildContext context) {
  return showConfirmActionDialog(
    context,
    icon: AppIcons.userRemove,
    title: AppStrings.deleteAccountConfirmTitle,
    body: AppStrings.deleteAccountConfirmBody,
    noteIcon: AppIcons.openExternal,
    note: AppStrings.deleteAccountConfirmNote,
    cancelLabel: AppStrings.signOutConfirmCancel,
    confirmLabel: AppStrings.deleteAccountConfirmContinue,
  );
}
