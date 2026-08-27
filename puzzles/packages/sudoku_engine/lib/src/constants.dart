/// The side length of a standard Sudoku grid.
const int boardSize = 9;

/// The side length of one square region ("box").
const int boxSize = 3;

/// The total number of cells on the board.
const int cellCount = boardSize * boardSize;

/// The digits that may appear in a cell, in ascending order.
const List<int> digits = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];
