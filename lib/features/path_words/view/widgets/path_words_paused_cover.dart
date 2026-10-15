import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/paused_board_cover.dart';
import '../../bloc/path_words_bloc.dart';
import '../../bloc/path_words_event.dart';
import '../../bloc/path_words_state.dart';

/// [PausedBoardCover] over the Path Words board, driven by [PathWordsBloc].
class PathWordsPausedCover extends StatelessWidget {
  const PathWordsPausedCover({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (playing, paused) = context.select<PathWordsBloc, (bool, bool)>((
      bloc,
    ) {
      final state = bloc.state;
      final live =
          state.status == PathWordsStatus.ready ||
          state.status == PathWordsStatus.playing;
      return (live && !state.finished, !state.isClockRunning);
    });
    return PausedBoardCover(
      playing: playing,
      paused: paused,
      onResume: () =>
          context.read<PathWordsBloc>().add(const PathWordsEvent.resumeRun()),
      child: child,
    );
  }
}
