import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A page's back arrow: pops when there is a page underneath, and goes Home
/// when there isn't, as when an App Link, a notification or the home-screen
/// widget opened the page (go_router's `pop` throws then).
void popOrGoHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
