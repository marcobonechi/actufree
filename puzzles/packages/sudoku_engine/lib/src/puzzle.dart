import 'cell.dart';
import 'difficulty.dart';
import 'rating.dart';
import 'sudoku_board.dart';
import 'technique.dart';

/// A generated puzzle: its clues, its unique solution, and its rating.
final class SudokuPuzzle {
  /// Creates a puzzle.
  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.difficulty,
    required this.rating,
    required this.seed,
  });

  /// Restores a puzzle previously written by [toJson].
  factory SudokuPuzzle.fromJson(Map<String, Object?> json) {
    final givens = json['givens'];
    final solution = json['solution'];
    final seed = json['seed'];
    if (givens is! Map<String, Object?> ||
        solution is! Map<String, Object?> ||
        seed is! int) {
      throw const FormatException('malformed puzzle');
    }
    final counts = json['techniquesUsed'];
    if (counts is! Map<String, Object?>) {
      throw const FormatException('malformed puzzle: techniquesUsed');
    }
    final byName = <String, Technique>{
      for (final technique in Technique.values) technique.name: technique,
    };
    final used = <Technique, int>{};
    counts.forEach((key, value) {
      final technique = byName[key];
      if (technique == null || value is! int) {
        throw FormatException('unknown technique "$key"');
      }
      used[technique] = value;
    });
    final tier = json['difficulty'];
    return SudokuPuzzle(
      givens: SudokuBoard.fromJson(givens),
      solution: SudokuBoard.fromJson(solution),
      difficulty: Difficulty.values.firstWhere(
        (Difficulty value) => value.name == tier,
        orElse: () => throw FormatException('unknown difficulty "$tier"'),
      ),
      rating: ratingFrom(used),
      seed: seed,
    );
  }

  /// The starting board: clues only, no entries.
  final SudokuBoard givens;

  /// The one board that completes [givens].
  final SudokuBoard solution;

  /// The tier this puzzle was generated for.
  ///
  /// Distinct from [rating], which measures what solving it actually took. A
  /// tier is a promise about the shape of the puzzle — how many clues it
  /// starts with, and the hardest technique it may demand — not a claim that
  /// every puzzle in it needs that technique. Insisting on the latter forced
  /// medium puzzles sparser than hard ones, since making a naked pair
  /// *necessary* means stripping the grid until singles run out.
  final Difficulty difficulty;

  /// What solving it actually took.
  final DifficultyRating rating;

  /// The generator seed that produced it, so a report can be reproduced.
  final int seed;

  /// How many clues the puzzle starts with.
  int get clueCount =>
      Cell.all.where((cell) => givens.valueAt(cell) != null).length;

  /// A lossless representation.
  ///
  /// The rating is stored as its technique counts rather than its tier, so a
  /// restored puzzle recomputes the same tier and score from the same source
  /// of truth.
  Map<String, Object?> toJson() => <String, Object?>{
        'version': 1,
        'seed': seed,
        'difficulty': difficulty.name,
        'givens': givens.toJson(),
        'solution': solution.toJson(),
        'techniquesUsed': <String, int>{
          for (final entry in rating.techniquesUsed.entries)
            entry.key.name: entry.value,
        },
      };
}
