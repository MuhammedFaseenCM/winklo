import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../cubit/auth_cubit.dart';
import 'sign_in_sheet.dart';

/// Returns true if the user is (or becomes) signed in and may open a game.
Future<bool> ensureSignedInForPlay(BuildContext context) async {
  final auth = context.read<AuthCubit>();
  if (auth.isSignedIn) return true;
  return showSignInSheet(
    context,
    title: AppStrings.playSignInTitle,
    body: AppStrings.playSignInBody,
  );
}
