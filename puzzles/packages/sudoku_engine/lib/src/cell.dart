/// The side length of a standard Sudoku grid.
const int boardSize = 9;

/// The side length of one square region ("box").
const int boxSize = 3;

/// The total number of cells on the board.
const int cellCount = boardSize * boardSize;

/// The digits that may appear in a cell, in ascending order.
const List<int> digits = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

/// A coordinate on the 9x9 grid.
///
/// [row] and [col] are zero-based with `(0, 0)` at the top left. Cells are
/// value types: two cells with the same coordinates are equal and hash alike.
final class Cell {
  /// The cell at [row], [col].
  const Cell(this.row, this.col);

  /// The cell at [index], counting left to right then top to bottom.
  factory Cell.fromIndex(int index) => throw UnimplementedError();

  /// Every cell on the board, in index order.
  static List<Cell> get all => throw UnimplementedError();

  /// The zero-based row.
  final int row;

  /// The zero-based column.
  final int col;

  /// The position of this cell in row-major order, `0` to `80`.
  int get index => throw UnimplementedError();

  /// The zero-based box, numbered left to right then top to bottom.
  int get box => throw UnimplementedError();

  /// The 20 cells that share a row, column or box with this one.
  ///
  /// Does not include this cell.
  Set<Cell> get peers => throw UnimplementedError();

  /// The three units — row, column, box — this cell belongs to.
  ///
  /// Each unit is the full set of nine cells, including this one.
  List<List<Cell>> get units => throw UnimplementedError();
}

/// All 27 units on the board: nine rows, then nine columns, then nine boxes.
List<List<Cell>> get allUnits => throw UnimplementedError();
