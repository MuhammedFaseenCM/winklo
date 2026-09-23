import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/app_repositories.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/notification_repository.dart';
import 'domain/usecases/clear_notification_token.dart';
import 'domain/usecases/handle_notification_tap.dart';
import 'domain/usecases/initialize_notifications.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/sync_fcm_token.dart';
import 'features/auth/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();
  await FirebaseBootstrap.init();
  FirebaseBootstrap.installErrorHandlers();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiRepositoryProvider(
      providers: buildRepositoryProviders(prefs: prefs),
      child: BlocProvider(
        create: (context) => AuthCubit(
          authRepository: context.read<AuthRepository>(),
          signInWithGoogle: context.read<SignInWithGoogle>(),
          signOut: context.read<SignOut>(),
          syncFcmToken: context.read<SyncFcmToken>(),
          clearNotificationToken: context.read<ClearNotificationToken>(),
        ),
        child: const _BootstrapNotifications(child: WinkloApp()),
      ),
    ),
  );
}

class _BootstrapNotifications extends StatefulWidget {
  const _BootstrapNotifications({required this.child});

  final Widget child;

  @override
  State<_BootstrapNotifications> createState() =>
      _BootstrapNotificationsState();
}

class _BootstrapNotificationsState extends State<_BootstrapNotifications> {
  StreamSubscription? _tapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final init = context.read<InitializeNotifications>();
    final repo = context.read<NotificationRepository>();
    final handleTap = context.read<HandleNotificationTap>();
    await init();
    if (!mounted) return;
    _tapSub = repo.watchTaps().listen((tap) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      router.go(handleTap(tap));
    });
  }

  @override
  void dispose() {
    unawaited(_tapSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
