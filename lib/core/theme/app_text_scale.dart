import 'package:flutter/material.dart';

/// Game UI ignores OS accessibility font size so layouts stay consistent.
const TextScaler kAppTextScaler = TextScaler.noScaling;

TextScaler clampAppTextScaler(TextScaler scaler) => kAppTextScaler;

/// Forces [kAppTextScaler] for the subtree (system font size has no effect).
class AppTextScale extends StatelessWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: kAppTextScaler),
      child: child,
    );
  }
}
