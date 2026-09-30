import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/cell.dart';

part 'sudoku_event.freezed.dart';

@freezed
sealed class SudokuEvent with _$SudokuEvent {
  const factory SudokuEvent.started({DateTime? date}) = SudokuStarted;
  const factory SudokuEvent.cellSelected(Cell cell) = SudokuCellSelected;
  const factory SudokuEvent.digitTapped(int digit) = SudokuDigitTapped;
  const factory SudokuEvent.erase() = SudokuErase;
  const factory SudokuEvent.notesModeToggled() = SudokuNotesModeToggled;
  const factory SudokuEvent.hint() = SudokuHint;
  const factory SudokuEvent.dismissHint() = SudokuDismissHint;
  const factory SudokuEvent.reset() = SudokuReset;
}
