import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/path_words_bloc.dart';
import '../../bloc/path_words_state.dart';

/// "Bonus word: STARE" each time the run finds one.
BlocListener<PathWordsBloc, PathWordsState> pathWordsBonusToastListener() {
  return BlocListener<PathWordsBloc, PathWordsState>(
    listenWhen: (prev, curr) =>
        curr.bonusWords.length > prev.bonusWords.length &&
        prev.puzzle?.id == curr.puzzle?.id,
    listener: (context, state) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('pathWordsBonusToast'),
            content: Text(
              AppStrings.pathWordsBonusWord(state.bonusWords.last),
              style: const TextStyle(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            backgroundColor: ZipColors.successSoft,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    },
  );
}
