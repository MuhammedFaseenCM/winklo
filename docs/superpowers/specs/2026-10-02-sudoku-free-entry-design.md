# Sudoku free entry + unit feedback

**Date:** 2026-10-02

## Problem

Wrong digits were rejected against the solution and showed a timed rose reject flash. Players could not leave incorrect numbers on the board.

## Behavior

- Any digit 1–6 may be placed in any non-given cell (overwrite allowed).
- No per-keystroke reject flash.
- When a row, column, or box is fully filled and matches the solution → existing green unit flash.
- When a unit is fully filled but does not match the solution → persistent rose tint on every cell in that unit where `grid[i] != solution[i]`.
- `errorIndices` is recomputed after every place and erase; incomplete units contribute no errors.
- Notes mode, given cells, and win (`isSolved` vs solution) are unchanged.

## Approach

Domain `SudokuRules.tryPlaceDigit` writes freely (except given / bounds / digit range). New `SudokuRules.errorIndices` unions mismatches from full-but-wrong units. Bloc stores `errorIndices` instead of `rejectFlashIndex`. Flame paints persistent rose; unit success flash unchanged.
