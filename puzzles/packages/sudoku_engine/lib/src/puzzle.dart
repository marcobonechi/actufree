import 'difficulty.dart';
import 'sudoku_board.dart';

/// A generated puzzle: its clues, its unique solution, and its rating.
final class SudokuPuzzle {
  /// Creates a puzzle.
  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.rating,
    required this.seed,
  });

  /// Restores a puzzle previously written by [toJson].
  factory SudokuPuzzle.fromJson(Map<String, Object?> json) =>
      throw UnimplementedError();

  /// The starting board: clues only, no entries.
  final SudokuBoard givens;

  /// The one board that completes [givens].
  final SudokuBoard solution;

  /// How hard it is, and why.
  final DifficultyRating rating;

  /// The generator seed that produced it, so a report can be reproduced.
  final int seed;

  /// How many clues the puzzle starts with.
  int get clueCount => throw UnimplementedError();

  /// The tier this puzzle was rated into.
  Difficulty get difficulty => rating.tier;

  /// A lossless representation.
  Map<String, Object?> toJson() => throw UnimplementedError();
}
