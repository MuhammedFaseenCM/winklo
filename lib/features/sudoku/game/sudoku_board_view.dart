class SudokuBoardView {
  const SudokuBoardView({
    required this.size,
    required this.boxRows,
    required this.boxCols,
    required this.given,
    required this.grid,
    required this.notes,
    required this.selectedIndex,
    required this.hintFlashIndex,
    required this.errorIndices,
    required this.unitFlashIndices,
    required this.inputEnabled,
    required this.celebrate,
    this.coachTargetIndex,
    this.coachEvidenceIndices = const {},
    this.coachExcludedIndices = const {},
  });

  final int size;
  final int boxRows;
  final int boxCols;
  final List<int> given;
  final List<int> grid;
  final List<Set<int>> notes;
  final int? selectedIndex;
  final int? hintFlashIndex;
  final Set<int> errorIndices;
  final Set<int> unitFlashIndices;
  final bool inputEnabled;
  final bool celebrate;
  final int? coachTargetIndex;
  final Set<int> coachEvidenceIndices;
  final Set<int> coachExcludedIndices;
}
