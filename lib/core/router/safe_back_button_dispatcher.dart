import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Avoids [go_router] crashing on Android system back when the delegate's
/// match list is still empty (startup / transient refresh).
///
/// See https://github.com/flutter/flutter/issues/187616 — `popRoute` reads
/// `matches.last` without the empty guard that `canPop` already has.
///
/// Back from a page with nothing under it (a game opened from an App Link, a
/// notification or the home-screen widget) goes Home instead of closing the
/// app, as the back arrow's `popOrGoHome` does. Home itself still closes it.
class SafeGoRouterBackButtonDispatcher extends RootBackButtonDispatcher {
  SafeGoRouterBackButtonDispatcher(this._router);

  final GoRouter Function() _router;

  @override
  Future<bool> didPopRoute() async {
    final router = _router();
    final matches = router.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty) return false;
    if (await super.didPopRoute()) return true;
    if (router.routerDelegate.currentConfiguration.uri.path == '/') {
      return false;
    }
    router.go('/');
    return true;
  }
}
