import 'dart:math';

import 'candidate_grid.dart';
import 'constants.dart';
import 'tables.dart';

/// Backtracking search over a [CandidateGrid].
///
/// Propagates singles before every branch and always splits on a cell with the
/// fewest candidates, which is what keeps counting solutions cheap enough to
/// run after each clue removal during generation.
final class SolutionSearch {
  /// Searches for at most [limit] solutions.
  SolutionSearch({this.limit = 2, this.random});

  /// How many solutions to find before giving up early.
  final int limit;

  /// When set, candidate digits are tried in a shuffled order, which turns
  /// the search into a random complete-grid generator.
  final Random? random;

  /// How many solutions were found, capped at [limit].
  int solutionCount = 0;

  /// The first solution found, or `null` when there is none.
  CandidateGrid? solution;

  /// Runs the search over [grid], which is consumed.
  void run(CandidateGrid grid) {
    if (solutionCount >= limit) return;
    if (!grid.propagateSingles()) return;
    if (grid.isSolved) {
      solutionCount++;
      solution ??= grid;
      return;
    }
    var target = -1;
    var fewest = boardSize + 1;
    for (var index = 0; index < cellCount; index++) {
      if (grid.values[index] != 0) continue;
      final open = countOf(grid.candidates[index]);
      if (open >= fewest) continue;
      fewest = open;
      target = index;
      if (open == 2) break;
    }
    if (target < 0) return;
    final options = digitsOf(grid.candidates[target]);
    final shuffler = random;
    if (shuffler != null) options.shuffle(shuffler);
    for (final digit in options) {
      final branch = grid.copy();
      if (branch.place(target, digit)) run(branch);
      if (solutionCount >= limit) return;
    }
  }
}
