import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Back from a screen that may be the only page: one opened straight from
/// a home-screen widget or a notification has nothing to pop to.
void popOrGoHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
