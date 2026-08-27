import 'dart:typed_data';

import 'constants.dart';
import 'tables.dart';

/// A working grid: the digits placed so far plus the candidates still open in
/// every cell.
///
/// This is the solver's scratch space, not game state. It knows nothing about
/// givens or the player's pencil marks.
final class CandidateGrid {
  CandidateGrid._(this.values, this.candidates, this.unsolved);

  /// A grid with nothing placed and every digit open everywhere.
  factory CandidateGrid.empty() {
    final candidates = Uint16List(cellCount)
      ..fillRange(0, cellCount, allDigitsMask);
    return CandidateGrid._(Int8List(cellCount), candidates, cellCount);
  }

  /// A grid holding [placed], where `0` marks an empty cell.
  ///
  /// Returns `null` when the digits already contradict each other.
  static CandidateGrid? fromDigits(List<int> placed) {
    final grid = CandidateGrid.empty();
    for (var index = 0; index < cellCount; index++) {
      final digit = placed[index];
      if (digit == 0) continue;
      if (grid.candidates[index] & maskOf(digit) == 0) return null;
      if (!grid.place(index, digit)) return null;
    }
    return grid;
  }

  /// The digit in each cell, `0` when empty.
  final Int8List values;

  /// The candidate bitmask for each cell.
  ///
  /// A placed cell's mask holds exactly its own digit.
  final Uint16List candidates;

  /// How many cells are still empty.
  int unsolved;

  /// Whether every cell holds a digit.
  bool get isSolved => unsolved == 0;

  /// An independent copy.
  CandidateGrid copy() => CandidateGrid._(
        Int8List.fromList(values),
        Uint16List.fromList(candidates),
        unsolved,
      );

  /// Places [digit] in [index] and strikes it from every peer's candidates.
  ///
  /// Returns `false` when that empties a peer or clashes with one, which means
  /// the grid is contradictory and the caller should abandon this branch.
  bool place(int index, int digit) {
    if (values[index] != 0) return values[index] == digit;
    values[index] = digit;
    candidates[index] = maskOf(digit);
    unsolved--;
    final without = ~maskOf(digit);
    for (final peer in cellPeers[index]) {
      if (values[peer] == digit) return false;
      final before = candidates[peer];
      final after = before & without;
      if (after == before) continue;
      candidates[peer] = after;
      if (after == 0) return false;
    }
    return true;
  }

  /// Strikes [digit] from [index]'s candidates.
  ///
  /// Returns `false` when that leaves the cell with nothing.
  bool eliminate(int index, int digit) {
    final bit = maskOf(digit);
    if (candidates[index] & bit == 0) return true;
    candidates[index] &= ~bit;
    return candidates[index] != 0;
  }

  /// Whether [digit] is still open in [index].
  bool isOpen(int index, int digit) =>
      values[index] == 0 && candidates[index] & maskOf(digit) != 0;

  /// The empty cells of [unit] where [digit] is still open.
  List<int> spotsFor(int unit, int digit) {
    final spots = <int>[];
    for (final index in unitCells[unit]) {
      if (values[index] == digit) return const <int>[];
      if (isOpen(index, digit)) spots.add(index);
    }
    return spots;
  }

  /// Repeatedly places naked and hidden singles until neither is available.
  ///
  /// Returns `false` on a contradiction. This is the cheap propagation the
  /// backtracking search leans on; the technique-by-technique solver used for
  /// rating applies the same two rules one step at a time instead, so it can
  /// attribute each placement.
  bool propagateSingles() {
    var progress = true;
    while (progress) {
      progress = false;
      for (var index = 0; index < cellCount; index++) {
        if (values[index] != 0) continue;
        final mask = candidates[index];
        if (mask == 0) return false;
        final sole = soleDigitOf(mask);
        if (sole < 0) continue;
        if (!place(index, sole)) return false;
        progress = true;
      }
      for (var unit = 0; unit < unitCount; unit++) {
        for (var digit = 1; digit <= boardSize; digit++) {
          var placed = false;
          var spot = -1;
          var count = 0;
          for (final index in unitCells[unit]) {
            if (values[index] == digit) {
              placed = true;
              break;
            }
            if (isOpen(index, digit)) {
              count++;
              spot = index;
            }
          }
          if (placed) continue;
          if (count == 0) return false;
          if (count != 1) continue;
          if (!place(spot, digit)) return false;
          progress = true;
        }
      }
    }
    return true;
  }
}
