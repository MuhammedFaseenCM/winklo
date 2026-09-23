import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/app_repositories.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_out.dart';
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
        ),
        child: const WinkloApp(),
      ),
    ),
  );
}
