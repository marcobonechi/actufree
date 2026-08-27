import 'dart:typed_data';

import 'constants.dart';

/// A bitmask holding all nine digits.
///
/// Candidate sets are bitmasks: bit `d - 1` is set while digit `d` is still
/// possible. Nine bits fit one `Uint16List` entry, so a whole grid's
/// candidates take 162 bytes and set operations are single instructions.
const int allDigitsMask = 0x1FF;

/// Unit ids `0`-`8` are rows, `9`-`17` are columns, `18`-`26` are boxes.
const int unitCount = boardSize * 3;

/// The bit representing [digit].
int maskOf(int digit) => 1 << (digit - 1);

/// How many digits [mask] holds.
int countOf(int mask) => _popCounts[mask];

/// The one digit in [mask], or `-1` when [mask] holds none or several.
int soleDigitOf(int mask) => _soleDigits[mask];

/// The digits in [mask], ascending.
List<int> digitsOf(int mask) {
  final result = <int>[];
  for (var digit = 1; digit <= boardSize; digit++) {
    if (mask & (1 << (digit - 1)) != 0) result.add(digit);
  }
  return result;
}

/// The nine cell indices making up each of the 27 units.
final List<List<int>> unitCells = _buildUnitCells();

/// The three unit ids each cell belongs to: row, then column, then box.
final List<List<int>> cellUnits = _buildCellUnits();

/// The 20 cell indices sharing a unit with each cell.
final List<List<int>> cellPeers = _buildCellPeers();

/// The box id containing [index].
int boxOf(int index) =>
    (index ~/ boardSize ~/ boxSize) * boxSize + (index % boardSize) ~/ boxSize;

/// A readable name for [unitId], such as `row 4` or `box 5`.
String unitName(int unitId) {
  if (unitId < boardSize) return 'row ${unitId + 1}';
  if (unitId < boardSize * 2) return 'column ${unitId - boardSize + 1}';
  return 'box ${unitId - boardSize * 2 + 1}';
}

/// A readable name for cell [index], such as `r4c7`.
String cellName(int index) =>
    'r${index ~/ boardSize + 1}c${index % boardSize + 1}';

/// Renders [indices] as a readable list, such as `r1c2, r3c4`.
String cellNames(Iterable<int> indices) {
  final sorted = indices.toList()..sort();
  return sorted.map(cellName).join(', ');
}

Uint8List _buildPopCounts() {
  final table = Uint8List(allDigitsMask + 1);
  for (var mask = 1; mask <= allDigitsMask; mask++) {
    table[mask] = table[mask >> 1] + (mask & 1);
  }
  return table;
}

Int8List _buildSoleDigits() {
  final table = Int8List(allDigitsMask + 1)
    ..fillRange(0, allDigitsMask + 1, -1);
  for (var digit = 1; digit <= boardSize; digit++) {
    table[1 << (digit - 1)] = digit;
  }
  return table;
}

List<List<int>> _buildUnitCells() {
  final units = <List<int>>[];
  for (var row = 0; row < boardSize; row++) {
    units.add(
      List<int>.generate(boardSize, (col) => row * boardSize + col,
          growable: false),
    );
  }
  for (var col = 0; col < boardSize; col++) {
    units.add(
      List<int>.generate(boardSize, (row) => row * boardSize + col,
          growable: false),
    );
  }
  for (var box = 0; box < boardSize; box++) {
    final firstRow = (box ~/ boxSize) * boxSize;
    final firstCol = (box % boxSize) * boxSize;
    units.add(
      List<int>.generate(
        boardSize,
        (i) => (firstRow + i ~/ boxSize) * boardSize + firstCol + i % boxSize,
        growable: false,
      ),
    );
  }
  return List<List<int>>.unmodifiable(units);
}

List<List<int>> _buildCellUnits() {
  return List<List<int>>.generate(
    cellCount,
    (index) => List<int>.unmodifiable(<int>[
      index ~/ boardSize,
      boardSize + index % boardSize,
      boardSize * 2 + boxOf(index),
    ]),
    growable: false,
  );
}

List<List<int>> _buildCellPeers() {
  return List<List<int>>.generate(
    cellCount,
    (index) {
      final peers = <int>{};
      for (final unit in cellUnits[index]) {
        peers.addAll(unitCells[unit]);
      }
      peers.remove(index);
      return List<int>.unmodifiable(peers.toList()..sort());
    },
    growable: false,
  );
}

final Uint8List _popCounts = _buildPopCounts();
final Int8List _soleDigits = _buildSoleDigits();
