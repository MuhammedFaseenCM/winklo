# Sudoku free entry Implementation Plan

> Implemented 2026-10-02. See also `docs/superpowers/specs/2026-10-02-sudoku-free-entry-design.md`.

**Goal:** Free digit entry with persistent per-cell errors on full-wrong units and solution-based unit success flashes.

## Done

- [x] `tryPlaceDigit` accepts any digit; remove `rejectIndex`
- [x] `SudokuRules.errorIndices` + domain tests
- [x] Replace `rejectFlashIndex` with `errorIndices` in state/bloc
- [x] Persistent error paint in `SudokuGame` / `SudokuBoardView`
- [x] Bloc + rules tests passing
