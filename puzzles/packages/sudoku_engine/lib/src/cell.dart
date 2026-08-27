import 'constants.dart';
import 'tables.dart';

export 'constants.dart';

/// A coordinate on the 9x9 grid.
///
/// [row] and [col] are zero-based with `(0, 0)` at the top left. Cells are
/// value types: two cells with the same coordinates are equal and hash alike.
final class Cell {
  /// The cell at [row], [col].
  const Cell(this.row, this.col)
      : assert(row >= 0 && row < boardSize, 'row out of range'),
        assert(col >= 0 && col < boardSize, 'col out of range');

  /// The cell at [index], counting left to right then top to bottom.
  factory Cell.fromIndex(int index) {
    RangeError.checkValueInInterval(index, 0, cellCount - 1, 'index');
    return _allCells[index];
  }

  /// Every cell on the board, in index order.
  static List<Cell> get all => _allCells;

  /// The zero-based row.
  final int row;

  /// The zero-based column.
  final int col;

  /// The position of this cell in row-major order, `0` to `80`.
  int get index => row * boardSize + col;

  /// The zero-based box, numbered left to right then top to bottom.
  int get box => (row ~/ boxSize) * boxSize + col ~/ boxSize;

  /// The 20 cells that share a row, column or box with this one.
  ///
  /// Does not include this cell.
  Set<Cell> get peers => _peers[index];

  /// The three units — row, column, box — this cell belongs to.
  ///
  /// Each unit is the full set of nine cells, including this one.
  List<List<Cell>> get units => _cellUnits[index];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => index;

  @override
  String toString() => 'r${row + 1}c${col + 1}';
}

/// All 27 units on the board: nine rows, then nine columns, then nine boxes.
List<List<Cell>> get allUnits => _allUnits;

final List<Cell> _allCells = List<Cell>.generate(
  cellCount,
  (index) => Cell(index ~/ boardSize, index % boardSize),
  growable: false,
);

final List<List<Cell>> _allUnits = List<List<Cell>>.unmodifiable(
  List<List<Cell>>.generate(
    unitCount,
    (unit) => List<Cell>.unmodifiable(unitCells[unit].map(Cell.fromIndex)),
    growable: false,
  ),
);

final List<Set<Cell>> _peers = List<Set<Cell>>.generate(
  cellCount,
  (index) => Set<Cell>.unmodifiable(cellPeers[index].map(Cell.fromIndex)),
  growable: false,
);

final List<List<List<Cell>>> _cellUnits = List<List<List<Cell>>>.generate(
  cellCount,
  (index) => List<List<Cell>>.unmodifiable(
    cellUnits[index].map((unit) => _allUnits[unit]),
  ),
  growable: false,
);
