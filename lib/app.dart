import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/lifecycle/app_open_lifecycle.dart';
import 'core/router/app_router.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_text_scale.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/analytics_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/notification_repository.dart';
import 'domain/usecases/handle_notification_tap.dart';
import 'domain/usecases/record_app_open.dart';
import 'features/auth/cubit/auth_cubit.dart';

class WinkloApp extends StatefulWidget {
  const WinkloApp({super.key});

  @override
  State<WinkloApp> createState() => _WinkloAppState();
}

class _WinkloAppState extends State<WinkloApp> {
  GoRouter? _router;
  StreamSubscription<NotificationTap>? _tapSub;
  bool _tapListening = false;
  AppOpenLifecycle? _appOpenLifecycle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureTapListening();
    _ensureAppOpenLifecycle();
  }

  void _ensureAppOpenLifecycle() {
    if (_appOpenLifecycle != null) return;
    final lifecycle = AppOpenLifecycle(
      context.read<RecordAppOpen>(),
      context.read<AuthRepository>(),
    );
    _appOpenLifecycle = lifecycle;
    lifecycle.start();
  }

  void _ensureTapListening() {
    if (_tapListening) return;
    _tapListening = true;
    final repo = context.read<NotificationRepository>();
    final handleTap = context.read<HandleNotificationTap>();
    _tapSub = repo.watchTaps().listen((tap) {
      final router = _router;
      if (router == null) return;
      router.go(handleTap(tap));
    });
  }

  @override
  void dispose() {
    unawaited(_tapSub?.cancel());
    _appOpenLifecycle?.dispose();
    _appOpenLifecycle = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _router ??= buildRouter(
      analytics: context.read<AnalyticsRepository>(),
      authCubit: context.read<AuthCubit>(),
    );
    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // Global tap-outside-to-dismiss: wraps every routed screen so a tap on
      // empty space drops keyboard focus app-wide. `translucent` lets taps on
      // real controls (buttons, list rows) still pass through underneath.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AppTextScale(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
