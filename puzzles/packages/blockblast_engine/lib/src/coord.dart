import 'constants.dart';

export 'constants.dart';

/// A square on the board.
///
/// [row] and [col] are zero-based with `(0, 0)` at the top left. Coordinates
/// are value types: two with the same row and column are equal and hash alike.
///
/// Shapes use the same type for their own cells, where the coordinates are
/// relative to the shape's top-left corner rather than to the board — which is
/// why this one is not range-checked the way Sudoku's `Cell` is. A shape's
/// cells are offsets, and offsets land off the board all the time while a
/// placement is being tested.
final class Coord {
  /// The square at [row], [col].
  const Coord(this.row, this.col);

  /// The square at [index], counting left to right then top to bottom.
  factory Coord.fromIndex(int index) {
    RangeError.checkValueInInterval(index, 0, cellCount - 1, 'index');
    return _allCoords[index];
  }

  /// Every square on the board, in index order.
  static List<Coord> get all => _allCoords;

  /// The zero-based row.
  final int row;

  /// The zero-based column.
  final int col;

  /// The position of this square in row-major order, `0` to `63`.
  ///
  /// Only meaningful for a coordinate that is on the board.
  int get index => row * boardSize + col;

  /// Whether this square lies on the board.
  bool get isOnBoard =>
      row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  /// This coordinate shifted down by [rows] and right by [cols].
  Coord translate(int rows, int cols) => Coord(row + rows, col + cols);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coord && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'r${row + 1}c${col + 1}';
}

final List<Coord> _allCoords = List<Coord>.unmodifiable(
  List<Coord>.generate(
    cellCount,
    (index) => Coord(index ~/ boardSize, index % boardSize),
    growable: false,
  ),
);
