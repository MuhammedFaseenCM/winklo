import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/paused_board_cover.dart';
import '../../bloc/sudoku_bloc.dart';
import '../../bloc/sudoku_event.dart';
import '../../bloc/sudoku_state.dart';

/// [PausedBoardCover] over the Sudoku board, driven by [SudokuBloc].
class SudokuPausedCover extends StatelessWidget {
  const SudokuPausedCover({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (playing, paused) = context.select<SudokuBloc, (bool, bool)>((bloc) {
      final state = bloc.state;
      return (
        state.status == SudokuStatus.ready && !state.finished,
        !state.isClockRunning,
      );
    });
    return PausedBoardCover(
      playing: playing,
      paused: paused,
      onResume: () =>
          context.read<SudokuBloc>().add(const SudokuEvent.resumeRun()),
      child: child,
    );
  }
}
