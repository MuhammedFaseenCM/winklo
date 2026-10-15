import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/league_code.dart';

/// Asks for a league name (1–30 characters); null when cancelled.
Future<String?> showLeagueNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextEntryDialog(
      title: title,
      actionLabel: actionLabel,
      label: AppStrings.leagueNameLabel,
      hint: AppStrings.leagueNameHint,
      initialText: initialName,
      maxLength: leagueNameMaxLength,
      capitalization: TextCapitalization.sentences,
      validate: (text) =>
          cleanLeagueName(text) == null ? AppStrings.leagueNameInvalid : null,
      result: (text) => cleanLeagueName(text)!,
    ),
  );
}

/// Asks for an invite code (or a pasted invite link); null when cancelled.
Future<String?> showLeagueCodeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextEntryDialog(
      title: AppStrings.leaguesJoin,
      actionLabel: AppStrings.leagueJoinAction,
      label: AppStrings.leagueCodeLabel,
      hint: AppStrings.leagueCodeHint,
      capitalization: TextCapitalization.characters,
      validate: (text) => normalizeLeagueCode(text) == null
          ? AppStrings.leagueCodeInvalid
          : null,
      result: (text) => normalizeLeagueCode(text)!,
    ),
  );
}

/// A yes/no question; true when confirmed.
Future<bool> showLeagueConfirmDialog(
  BuildContext context, {
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: ZipColors.wall,
      content: Text(
        message,
        style: Theme.of(
          dialogContext,
        ).textTheme.bodyLarge?.copyWith(color: ZipColors.onInk),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(AppStrings.leagueCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.actionLabel,
    required this.label,
    required this.hint,
    required this.validate,
    required this.result,
    this.initialText = '',
    this.maxLength,
    this.capitalization = TextCapitalization.none,
  });

  final String title;
  final String actionLabel;
  final String label;
  final String hint;
  final String initialText;
  final int? maxLength;
  final TextCapitalization capitalization;

  /// An error message, or null when [text] is fine.
  final String? Function(String text) validate;
  final String Function(String text) result;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    final error = widget.validate(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(widget.result(text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ZipColors.wall,
      title: Text(
        widget.title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: ZipColors.onInk),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: widget.capitalization,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(color: ZipColors.onInk),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.leagueCancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
