import 'difficulty.dart';
import 'puzzle.dart';
import 'sudoku_board.dart';

/// Produces puzzles with a guaranteed unique solution.
///
/// The approach is the standard one: fill a grid completely, then remove clues
/// one at a time, putting any clue back whose removal would allow a second
/// solution.
final class SudokuGenerator {
  /// A generator seeded from [seed].
  ///
  /// The same seed always yields the same puzzle for the same target
  /// difficulty, so a bug report only needs to carry the seed.
  const SudokuGenerator(this.seed);

  /// The seed driving every random choice.
  final int seed;

  /// Generates a puzzle rated [target].
  ///
  /// Removal is attempted until the puzzle's rating reaches [target] and no
  /// further clue can go without either losing uniqueness or overshooting the
  /// tier. Falls back to the closest tier reached after [maxAttempts] full
  /// grids, rather than looping forever on an unlucky seed.
  SudokuPuzzle generate(Difficulty target, {int maxAttempts = 20}) =>
      throw UnimplementedError();

  /// Generates a complete, valid, conflict-free grid.
  ///
  /// Exposed mainly for tests and for callers that want to build their own
  /// removal strategy.
  SudokuBoard generateSolvedGrid() => throw UnimplementedError();
}
