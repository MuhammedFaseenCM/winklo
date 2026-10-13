import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Avoids [go_router] crashing on Android system back when the delegate's
/// match list is still empty (startup / transient refresh).
///
/// See https://github.com/flutter/flutter/issues/187616 — `popRoute` reads
/// `matches.last` without the empty guard that `canPop` already has.
class SafeGoRouterBackButtonDispatcher extends RootBackButtonDispatcher {
  SafeGoRouterBackButtonDispatcher(this._router);

  final GoRouter Function() _router;

  @override
  Future<bool> didPopRoute() {
    final matches = _router().routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty) {
      return SynchronousFuture<bool>(false);
    }
    return super.didPopRoute();
  }
}
