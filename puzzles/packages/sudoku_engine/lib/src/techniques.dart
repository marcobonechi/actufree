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
  (technique: Technique.hiddenTriple, find: findHiddenTriple),
  (technique: Technique.pointingPair, find: findPointingPair),
  (technique: Technique.boxLineReduction, find: findBoxLineReduction),
  (technique: Technique.xWing, find: findXWing),
  (technique: Technique.yWing, find: findYWing),
  (technique: Technique.xyzWing, find: findXyzWing),
  (technique: Technique.swordfish, find: findSwordfish),
  (technique: Technique.simpleColouring, find: findSimpleColouring),
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

/// Three digits confined to the same three cells of a unit.
Deduction? findHiddenTriple(CandidateGrid grid) {
  for (var unit = 0; unit < unitCount; unit++) {
    final spots = <int, List<int>>{};
    for (var digit = 1; digit <= boardSize; digit++) {
      final places = grid.spotsFor(unit, digit);
      if (places.length >= 2 && places.length <= 3) spots[digit] = places;
    }
    if (spots.length < 3) continue;
    for (final combination in _combinations(spots.keys.toList(), 3)) {
      final cells = <int>{};
      var keep = 0;
      for (final digit in combination) {
        cells.addAll(spots[digit]!);
        keep |= maskOf(digit);
      }
      if (cells.length != 3) continue;
      final eliminations = <int, int>{};
      for (final index in cells) {
        final extra = grid.candidates[index] & ~keep;
        if (extra != 0) eliminations[index] = extra;
      }
      if (eliminations.isEmpty) continue;
      return Deduction.elimination(
        technique: Technique.hiddenTriple,
        explanation: 'In ${unitName(unit)}, ${combination.join(', ')} fit only '
            'in ${cellNames(cells)}, so those three cells hold nothing else.',
        because: cells,
        eliminations: eliminations,
      );
    }
  }
  return null;
}

/// A three-candidate pivot whose two pincers share one of its digits.
Deduction? findXyzWing(CandidateGrid grid) {
  for (var pivot = 0; pivot < cellCount; pivot++) {
    if (grid.values[pivot] != 0) continue;
    if (countOf(grid.candidates[pivot]) != 3) continue;
    final pivotMask = grid.candidates[pivot];
    for (final left in cellPeers[pivot]) {
      if (grid.values[left] != 0) continue;
      if (countOf(grid.candidates[left]) != 2) continue;
      if (grid.candidates[left] & pivotMask != grid.candidates[left]) continue;
      for (final right in cellPeers[pivot]) {
        if (right <= left) continue;
        if (grid.values[right] != 0) continue;
        if (countOf(grid.candidates[right]) != 2) continue;
        if (grid.candidates[right] & pivotMask != grid.candidates[right]) {
          continue;
        }
        if ((grid.candidates[left] | grid.candidates[right]) != pivotMask) {
          continue;
        }
        final shared = grid.candidates[left] & grid.candidates[right];
        if (countOf(shared) != 1) continue;
        final digit = soleDigitOf(shared);
        final eliminations = <int, int>{};
        // Only cells seeing all three corners are ruled out: one of the three
        // must take the digit, but which one is not yet known.
        for (final index in cellPeers[pivot]) {
          if (index == left || index == right) continue;
          if (!cellPeers[left].contains(index)) continue;
          if (!cellPeers[right].contains(index)) continue;
          if (grid.isOpen(index, digit)) eliminations[index] = maskOf(digit);
        }
        if (eliminations.isEmpty) continue;
        return Deduction.elimination(
          technique: Technique.xyzWing,
          explanation: 'One of ${cellName(pivot)}, ${cellName(left)} or '
              '${cellName(right)} must be $digit, so $digit is out anywhere '
              'all three can see.',
          because: <int>{pivot, left, right},
          eliminations: eliminations,
        );
      }
    }
  }
  return null;
}

/// A digit confined to the same three columns across three rows, or the
/// reverse — the three-line form of an X-wing.
Deduction? findSwordfish(CandidateGrid grid) {
  for (var digit = 1; digit <= boardSize; digit++) {
    for (var transposed = 0; transposed < 2; transposed++) {
      final lineOffset = transposed == 0 ? 0 : boardSize;
      final byLine = <int, List<int>>{};
      for (var line = 0; line < boardSize; line++) {
        final spots = grid.spotsFor(lineOffset + line, digit);
        if (spots.length < 2 || spots.length > boxSize) continue;
        byLine[line] = spots
            .map((int index) =>
                transposed == 0 ? index % boardSize : index ~/ boardSize)
            .toList();
      }
      if (byLine.length < boxSize) continue;
      for (final combination in _combinations(byLine.keys.toList(), boxSize)) {
        final crosses = <int>{};
        for (final line in combination) {
          crosses.addAll(byLine[line]!);
        }
        if (crosses.length != boxSize) continue;
        final corners = <int>{};
        for (final line in combination) {
          for (final cross in byLine[line]!) {
            corners.add(transposed == 0
                ? line * boardSize + cross
                : cross * boardSize + line);
          }
        }
        final eliminations = <int, int>{};
        for (final cross in crosses) {
          final crossUnit = transposed == 0 ? boardSize + cross : cross;
          for (final index in unitCells[crossUnit]) {
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
          technique: Technique.swordfish,
          explanation: 'Across $lineWord '
              '${combination.map((int l) => l + 1).join(', ')}, $digit fits '
              'only in $crossWord '
              '${crosses.map((int c) => c + 1).join(', ')}. Those three '
              '$crossWord are used up, so $digit goes nowhere else in them.',
          because: corners,
          eliminations: eliminations,
        );
      }
    }
  }
  return null;
}

/// Two-colours a digit's conjugate-pair chains and reads off the
/// contradictions.
Deduction? findSimpleColouring(CandidateGrid grid) {
  for (var digit = 1; digit <= boardSize; digit++) {
    // An edge joins the only two cells of a unit that can still take the
    // digit: exactly one of them holds it, so the two always disagree.
    final links = <int, List<int>>{};
    for (var unit = 0; unit < unitCount; unit++) {
      final spots = grid.spotsFor(unit, digit);
      if (spots.length != 2) continue;
      links.putIfAbsent(spots[0], () => <int>[]).add(spots[1]);
      links.putIfAbsent(spots[1], () => <int>[]).add(spots[0]);
    }
    final seen = <int>{};
    for (final start in links.keys) {
      if (seen.contains(start)) continue;
      final first = <int>{start};
      final second = <int>{};
      final queue = <int>[start];
      seen.add(start);
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final target = first.contains(current) ? second : first;
        for (final next in links[current]!) {
          if (!seen.add(next)) continue;
          target.add(next);
          queue.add(next);
        }
      }
      // A colour appearing twice in one unit cannot be the true colour.
      for (final colour in <Set<int>>[first, second]) {
        final clash = _sameUnitPair(colour);
        if (clash == null) continue;
        return Deduction.elimination(
          technique: Technique.simpleColouring,
          explanation: 'Chaining $digit through its forced pairs puts '
              '${cellName(clash[0])} and ${cellName(clash[1])} on the same '
              'side, but they share a unit. That whole side is impossible, so '
              '$digit leaves ${cellNames(colour)}.',
          because: colour,
          eliminations: <int, int>{
            for (final index in colour) index: maskOf(digit),
          },
        );
      }
      // One side is true, so a cell seeing both sides cannot hold the digit.
      final eliminations = <int, int>{};
      for (var index = 0; index < cellCount; index++) {
        if (!grid.isOpen(index, digit)) continue;
        if (first.contains(index) || second.contains(index)) continue;
        final peers = cellPeers[index];
        if (!first.any(peers.contains)) continue;
        if (!second.any(peers.contains)) continue;
        eliminations[index] = maskOf(digit);
      }
      if (eliminations.isEmpty) continue;
      return Deduction.elimination(
        technique: Technique.simpleColouring,
        explanation: 'Chaining $digit through its forced pairs splits them '
            'into two sides, one of which is true. ${cellNames(
          eliminations.keys,
        )} can see both sides, so $digit is out there.',
        because: <int>{...first, ...second},
        eliminations: eliminations,
      );
    }
  }
  return null;
}

List<int>? _sameUnitPair(Set<int> group) {
  final members = group.toList()..sort();
  for (var i = 0; i < members.length; i++) {
    for (var j = i + 1; j < members.length; j++) {
      if (cellPeers[members[i]].contains(members[j])) {
        return <int>[members[i], members[j]];
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
