import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('header shows brand copy without auth or leaderboard chrome', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTagline), findsOneWidget);
    expect(find.byIcon(Icons.login), findsNothing);
    expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
  });
}
