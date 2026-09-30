import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/cubit/auth_cubit.dart';

/// Bridges [AuthCubit] emissions to GoRouter's [refreshListenable].
final class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(AuthCubit authCubit) {
    _subscription = authCubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
