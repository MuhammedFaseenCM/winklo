import 'package:flutter/widgets.dart';

/// The Settings screen's Language section, reserved for the Malayalam work
/// (area G of the 2026-10-15 roadmap batch): System, English and മലയാളം.
///
/// Hidden until that lands: set [visible] to true and build the row here.
class SettingsLanguageSlot extends StatelessWidget {
  const SettingsLanguageSlot({super.key});

  static const visible = false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
