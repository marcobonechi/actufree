import 'cell.dart';

/// The state of one Sudoku grid: the clues, the player's entries, and the
/// player's pencil marks.
///
/// Boards are immutable. Every mutating method returns a new board and leaves
/// the receiver untouched, which is what makes the undo stack in `puzzle_kit`
/// a matter of holding onto old values.
final class SudokuBoard {
  /// An entirely empty board with no givens.
  factory SudokuBoard.empty() => throw UnimplementedError();

  /// A board whose clues are [givens], with no entries and no pencil marks.
  ///
  /// [givens] must have [cellCount] elements; `null` marks an empty cell.
  factory SudokuBoard.fromGivens(List<int?> givens) => throw UnimplementedError();

  /// Parses 81 characters of `1`-`9`, treating `.`, `0` and `-` as empty.
  ///
  /// Whitespace is ignored, so multi-line grids parse as written. Every filled
  /// cell becomes a given.
  factory SudokuBoard.parse(String source) => throw UnimplementedError();

  /// Restores a board previously written by [toJson].
  factory SudokuBoard.fromJson(Map<String, Object?> json) =>
      throw UnimplementedError();

  /// The digit in [cell], whether it is a given or a player entry.
  int? valueAt(Cell cell) => throw UnimplementedError();

  /// Whether [cell] holds a clue, which the player may not change.
  bool isGiven(Cell cell) => throw UnimplementedError();

  /// The player's pencil marks for [cell].
  ///
  /// These are notes the player has written, not a deduction — see
  /// [legalDigitsAt] for what the rules currently allow.
  Set<int> notesAt(Cell cell) => throw UnimplementedError();

  /// The digits that could legally go in [cell] given the digits already on
  /// the board.
  ///
  /// Returns an empty set for a filled cell.
  Set<int> legalDigitsAt(Cell cell) => throw UnimplementedError();

  /// Whether writing [digit] into [cell] would leave the board consistent.
  bool isLegal(Cell cell, int digit) => throw UnimplementedError();

  /// Every cell whose digit duplicates another digit in its row, column or
  /// box.
  ///
  /// Empty on a consistent board. Both members of a clashing pair appear.
  Set<Cell> get conflicts => throw UnimplementedError();

  /// Whether every cell holds a digit, regardless of correctness.
  bool get isComplete => throw UnimplementedError();

  /// Whether every cell holds a digit and no cell conflicts.
  bool get isSolved => throw UnimplementedError();

  /// The cells that are still empty, in index order.
  List<Cell> get emptyCells => throw UnimplementedError();

  /// This board with [digit] written into [cell], or cleared when [digit] is
  /// `null`.
  ///
  /// Clears the cell's pencil marks. Throws [StateError] if [cell] is a given.
  /// Performs no legality check: use [MoveValidator] to decide whether the
  /// move should be offered, and this to apply it.
  SudokuBoard withValue(Cell cell, int? digit) => throw UnimplementedError();

  /// This board with [digit] added to or removed from [cell]'s pencil marks.
  ///
  /// Throws [StateError] if [cell] is a given or already holds a digit.
  SudokuBoard withNoteToggled(Cell cell, int digit) => throw UnimplementedError();

  /// This board with [cell]'s pencil marks removed.
  SudokuBoard withNotesCleared(Cell cell) => throw UnimplementedError();

  /// This board with every player entry and pencil mark removed, keeping the
  /// givens.
  SudokuBoard reset() => throw UnimplementedError();

  /// The 81 digits as characters, using `.` for empty cells.
  ///
  /// Drops the given/entry distinction and the pencil marks; round-trips
  /// through [SudokuBoard.parse] only for boards that are all givens.
  String toCompactString() => throw UnimplementedError();

  /// A lossless representation, including entries and pencil marks.
  Map<String, Object?> toJson() => throw UnimplementedError();
}
