import 'candidate_grid.dart';
import 'constants.dart';
import 'deduction.dart';
import 'tables.dart';
import 'technique.dart';

/// Looks for one application of a single technique.
typedef DeductionFinder = Deduction? Function(CandidateGrid grid);

/// Every implemented technique paired with its finder, ordered from most to
/// least elementary.
///
/// The solver walks this list in order and takes the first hit, which is what
/// makes both the hint ("what would a player spot next?") and the difficulty
/// rating ("what is the hardest thing this puzzle forces?") meaningful.
final List<({Technique technique, DeductionFinder find})> orderedFinders =
    <({Technique technique, DeductionFinder find})>[
  (technique: Technique.nakedSingle, find: findNakedSingle),
  (technique: Technique.hiddenSingle, find: findHiddenSingle),
  (technique: Technique.nakedPair, find: findNakedPair),
  (technique: Technique.hiddenPair, find: findHiddenPair),
  (technique: Technique.nakedTriple, find: findNakedTriple),
  (technique: Technique.pointingPair, find: findPointingPair),
  (technique: Technique.boxLineReduction, find: findBoxLineReduction),
  (technique: Technique.xWing, find: findXWing),
  (technique: Technique.yWing, find: findYWing),
];

/// A cell with exactly one candidate left.
Deduction? findNakedSingle(CandidateGrid grid) {
  for (var index = 0; index < cellCount; index++) {
    if (grid.values[index] != 0) continue;
    final digit = soleDigitOf(grid.candidates[index]);
    if (digit < 0) continue;
    final because = <int>{};
    for (final peer in cellPeers[index]) {
      if (grid.values[peer] != 0) because.add(peer);
    }
    return Deduction.placement(
      technique: Technique.nakedSingle,
      explanation: 'Every digit but $digit already appears in the row, column '
          'or box of ${cellName(index)}.',
      because: because,
      index: index,
      digit: digit,
    );
  }
  return null;
}

/// A digit with exactly one place left in some unit.
Deduction? findHiddenSingle(CandidateGrid grid) {
  for (var unit = 0; unit < unitCount; unit++) {
    for (var digit = 1; digit <= boardSize; digit++) {
      final spots = grid.spotsFor(unit, digit);
      if (spots.length != 1) continue;
      final index = spots.single;
      if (soleDigitOf(grid.candidates[index]) == digit) continue;
      return Deduction.placement(
        technique: Technique.hiddenSingle,
        explanation: '$digit has nowhere else to go in ${unitName(unit)}, so '
            'it belongs in ${cellName(index)}.',
        because: unitCells[unit].where((cell) => cell != index).toSet(),
        index: index,
        digit: digit,
      );
    }
  }
  return null;
}

/// Two cells in a unit holding the same two candidates.
Deduction? findNakedPair(CandidateGrid grid) =>
    _findNakedSubset(grid, 2, Technique.nakedPair);

/// Three cells in a unit holding only three candidates between them.
Deduction? findNakedTriple(CandidateGrid grid) =>
    _findNakedSubset(grid, 3, Technique.nakedTriple);

Deduction? _findNakedSubset(CandidateGrid grid, int size, Technique technique) {
  for (var unit = 0; unit < unitCount; unit++) {
    final open = _openCells(grid, unit);
    if (open.length <= size) continue;
    for (final combination in _combinations(open, size)) {
      var mask = 0;
      for (final index in combination) {
        mask |= grid.candidates[index];
      }
      if (countOf(mask) != size) continue;
      final eliminations = <int, int>{};
      for (final index in open) {
        if (combination.contains(index)) continue;
        final hit = grid.candidates[index] & mask;
        if (hit != 0) eliminations[index] = hit;
      }
      if (eliminations.isEmpty) continue;
      final shared = digitsOf(mask).join(', ');
      return Deduction.elimination(
        technique: technique,
        explanation: '${cellNames(combination)} in ${unitName(unit)} hold only '
            '$shared between them, so no other cell there can take those.',
        because: combination.toSet(),
        eliminations: eliminations,
      );
    }
  }
  return null;
}

/// Two digits confined to the same two cells of a unit.
Deduction? findHiddenPair(CandidateGrid grid) {
  for (var unit = 0; unit < unitCount; unit++) {
    final spots = <int, List<int>>{};
    for (var digit = 1; digit <= boardSize; digit++) {
      final places = grid.spotsFor(unit, digit);
      if (places.length == 2) spots[digit] = places;
    }
    final candidates = spots.keys.toList();
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final first = candidates[i];
        final second = candidates[j];
        final places = spots[first]!;
        if (!_sameCells(places, spots[second]!)) continue;
        final keep = maskOf(first) | maskOf(second);
        final eliminations = <int, int>{};
        for (final index in places) {
          final extra = grid.candidates[index] & ~keep;
          if (extra != 0) eliminations[index] = extra;
        }
        if (eliminations.isEmpty) continue;
        return Deduction.elimination(
          technique: Technique.hiddenPair,
          explanation: 'In ${unitName(unit)}, $first and $second fit only in '
              '${cellNames(places)}, so those two cells hold nothing else.',
          because: places.toSet(),
          eliminations: eliminations,
        );
      }
    }
  }
  return null;
}

/// A digit whose places within a box all share one row or column.
Deduction? findPointingPair(CandidateGrid grid) {
  for (var box = 0; box < boardSize; box++) {
    final unit = boardSize * 2 + box;
    for (var digit = 1; digit <= boardSize; digit++) {
      final spots = grid.spotsFor(unit, digit);
      if (spots.length < 2) continue;
      final rows = spots.map((index) => index ~/ boardSize).toSet();
      final cols = spots.map((index) => index % boardSize).toSet();
      final line = rows.length == 1
          ? rows.single
          : cols.length == 1
              ? boardSize + cols.single
              : -1;
      if (line < 0) continue;
      final eliminations = <int, int>{};
      for (final index in unitCells[line]) {
        if (boxOf(index) == box) continue;
        if (grid.isOpen(index, digit)) eliminations[index] = maskOf(digit);
      }
      if (eliminations.isEmpty) continue;
      return Deduction.elimination(
        technique: Technique.pointingPair,
        explanation: 'In ${unitName(unit)}, $digit fits only in '
            '${cellNames(spots)}, all on ${unitName(line)}. It must be one of '
            'those, so it can go nowhere else on that line.',
        because: spots.toSet(),
        eliminations: eliminations,
      );
    }
  }
  return null;
}

/// A digit whose places within a row or column all fall in one box.
Deduction? findBoxLineReduction(CandidateGrid grid) {
  for (var line = 0; line < boardSize * 2; line++) {
    for (var digit = 1; digit <= boardSize; digit++) {
      final spots = grid.spotsFor(line, digit);
      if (spots.length < 2) continue;
      final boxes = spots.map(boxOf).toSet();
      if (boxes.length != 1) continue;
      final box = boxes.single;
      final eliminations = <int, int>{};
      for (final index in unitCells[boardSize * 2 + box]) {
        if (cellUnits[index].contains(line)) continue;
        if (grid.isOpen(index, digit)) eliminations[index] = maskOf(digit);
      }
      if (eliminations.isEmpty) continue;
      return Deduction.elimination(
        technique: Technique.boxLineReduction,
        explanation: 'On ${unitName(line)}, $digit fits only in '
            '${cellNames(spots)}, all inside ${unitName(boardSize * 2 + box)}. '
            'That box must use $digit on the line, so it can go nowhere else '
            'in the box.',
        because: spots.toSet(),
        eliminations: eliminations,
      );
    }
  }
  return null;
}

/// A digit confined to the same two columns in two rows, or the reverse.
Deduction? findXWing(CandidateGrid grid) {
  for (var digit = 1; digit <= boardSize; digit++) {
    for (var transposed = 0; transposed < 2; transposed++) {
      final lineOffset = transposed == 0 ? 0 : boardSize;
      final pairs = <int, List<int>>{};
      for (var line = 0; line < boardSize; line++) {
        final spots = grid.spotsFor(lineOffset + line, digit);
        if (spots.length != 2) continue;
        pairs[line] = spots
            .map((index) =>
                transposed == 0 ? index % boardSize : index ~/ boardSize)
            .toList();
      }
      final lines = pairs.keys.toList();
      for (var i = 0; i < lines.length; i++) {
        for (var j = i + 1; j < lines.length; j++) {
          final first = pairs[lines[i]]!;
          final second = pairs[lines[j]]!;
          if (first[0] != second[0] || first[1] != second[1]) continue;
          final corners = <int>{};
          for (final line in <int>[lines[i], lines[j]]) {
            for (final cross in first) {
              corners.add(transposed == 0
                  ? line * boardSize + cross
                  : cross * boardSize + line);
            }
          }
          final eliminations = <int, int>{};
          for (final cross in first) {
            for (final index in unitCells[
                transposed == 0 ? boardSize + cross : cross]) {
              if (corners.contains(index)) continue;
              if (grid.isOpen(index, digit)) {
                eliminations[index] = maskOf(digit);
              }
            }
          }
          if (eliminations.isEmpty) continue;
          final lineWord = transposed == 0 ? 'rows' : 'columns';
          final crossWord = transposed == 0 ? 'columns' : 'rows';
          return Deduction.elimination(
            technique: Technique.xWing,
            explanation: 'In $lineWord ${lines[i] + 1} and ${lines[j] + 1}, '
                '$digit fits only in $crossWord ${first[0] + 1} and '
                '${first[1] + 1}. Those two $crossWord are then used up by '
                'this pair, so $digit can go nowhere else in them.',
            because: corners,
            eliminations: eliminations,
          );
        }
      }
    }
  }
  return null;
}

/// A two-candidate pivot whose two pincers share a digit.
Deduction? findYWing(CandidateGrid grid) {
  for (var pivot = 0; pivot < cellCount; pivot++) {
    if (grid.values[pivot] != 0) continue;
    if (countOf(grid.candidates[pivot]) != 2) continue;
    final pivotDigits = digitsOf(grid.candidates[pivot]);
    final first = pivotDigits[0];
    final second = pivotDigits[1];
    for (final left in cellPeers[pivot]) {
      if (grid.values[left] != 0) continue;
      if (countOf(grid.candidates[left]) != 2) continue;
      if (!grid.isOpen(left, first)) continue;
      if (grid.isOpen(left, second)) continue;
      final shared = digitsOf(grid.candidates[left] & ~maskOf(first)).single;
      for (final right in cellPeers[pivot]) {
        if (right == left) continue;
        if (grid.values[right] != 0) continue;
        if (countOf(grid.candidates[right]) != 2) continue;
        if (grid.candidates[right] != (maskOf(second) | maskOf(shared))) {
          continue;
        }
        final eliminations = <int, int>{};
        for (final index in cellPeers[left]) {
          if (index == pivot || index == right) continue;
          if (!cellPeers[right].contains(index)) continue;
          if (grid.isOpen(index, shared)) {
            eliminations[index] = maskOf(shared);
          }
        }
        if (eliminations.isEmpty) continue;
        return Deduction.elimination(
          technique: Technique.yWing,
          explanation: '${cellName(pivot)} is $first or $second. Either way '
              'one of ${cellName(left)} or ${cellName(right)} is forced to '
              '$shared, so $shared is out anywhere both can see.',
          because: <int>{pivot, left, right},
          eliminations: eliminations,
        );
      }
    }
  }
  return null;
}

List<int> _openCells(CandidateGrid grid, int unit) =>
    unitCells[unit].where((index) => grid.values[index] == 0).toList();

bool _sameCells(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<List<int>> _combinations(List<int> source, int size) {
  final result = <List<int>>[];
  final current = List<int>.filled(size, 0);
  void build(int start, int depth) {
    if (depth == size) {
      result.add(List<int>.of(current));
      return;
    }
    for (var i = start; i <= source.length - (size - depth); i++) {
      current[depth] = source[i];
      build(i + 1, depth + 1);
    }
  }

  build(0, 0);
  return result;
}
