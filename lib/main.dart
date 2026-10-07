import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/app_repositories.dart';
import 'core/errors/client_error_reporter.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'data/repositories/client_error_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/clear_notification_token.dart';
import 'domain/usecases/initialize_notifications.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/sync_fcm_token.dart';
import 'domain/usecases/sync_progress.dart';
import 'features/auth/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.init();

  final clientErrorRepository = ClientErrorRepositoryImpl();
  ClientErrorReporter.install(
    ClientErrorReporter(
      repository: clientErrorRepository,
      uidProvider: () {
        if (!FirebaseBootstrap.isReady) return null;
        try {
          return FirebaseAuth.instance.currentUser?.uid;
        } catch (_) {
          return null;
        }
      },
    ),
  );

  Bloc.observer = AppBlocObserver();
  FirebaseBootstrap.installErrorHandlers();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiRepositoryProvider(
      providers: [
        ...buildRepositoryProviders(
          prefs: prefs,
          clientErrorRepository: clientErrorRepository,
        ),
      ],
      child: BlocProvider(
        create: (context) => AuthCubit(
          authRepository: context.read<AuthRepository>(),
          signInWithGoogle: context.read<SignInWithGoogle>(),
          signOut: context.read<SignOut>(),
          syncFcmToken: context.read<SyncFcmToken>(),
          clearNotificationToken: context.read<ClearNotificationToken>(),
          syncProgress: context.read<SyncProgress>(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final init = context.read<InitializeNotifications>();
    try {
      await init();
    } catch (e, st) {
      debugPrint('Notification bootstrap failed: $e\n$st');
      ClientErrorReporter.instance.reportHandled(
        code: 'notification_bootstrap',
        message: e.toString(),
        cause: e.runtimeType.toString(),
        stack: st.toString(),
        function: '_BootstrapNotificationsState._init',
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
