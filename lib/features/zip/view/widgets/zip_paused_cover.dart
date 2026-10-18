import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/paused_board_cover.dart';
import '../../bloc/zip_bloc.dart';
import '../../bloc/zip_event.dart';
import '../../bloc/zip_state.dart';

/// [PausedBoardCover] over the Zip board, driven by [ZipBloc].
class ZipPausedCover extends StatelessWidget {
  const ZipPausedCover({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (playing, paused) = context.select<ZipBloc, (bool, bool)>((bloc) {
      final state = bloc.state;
      return (
        state.status == ZipStatus.ready && !state.finished,
        !state.isClockRunning,
      );
    });
    return PausedBoardCover(
      playing: playing,
      paused: paused,
      onResume: () => context.read<ZipBloc>().add(const ZipEvent.resumeRun()),
      child: child,
    );
  }
}
