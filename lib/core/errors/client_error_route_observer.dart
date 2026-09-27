import 'package:flutter/widgets.dart';

import 'client_error_context.dart';

/// Updates [ClientErrorContext.currentScreen] from Navigator / GoRouter.
class ClientErrorRouteObserver extends NavigatorObserver {
  void _capture(Route<dynamic>? route) {
    ClientErrorContext.updateFromRouteName(route?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _capture(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _capture(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _capture(previousRoute);
  }
}
