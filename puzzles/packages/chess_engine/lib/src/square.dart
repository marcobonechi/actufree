/// How many squares along one edge of the board.
const int boardSize = 8;

/// How many squares there are in total.
const int squareCount = boardSize * boardSize;

/// A square on the board.
///
/// [row] and [col] are zero-based with `(0, 0)` at the top left, which is a8:
/// the board is stored the way it is drawn, White at the bottom, so the row
/// index and the printed rank run in opposite directions. [rank] and [file]
/// are the chess-facing names, and [name] is the algebraic one.
///
/// Range-checked, unlike Block Blast's `Coord`. There is no such thing as a
/// chess square off the board — a knight's jump that lands outside is not a
/// square at all — so off-board arithmetic is caught by [offset] returning
/// `null` rather than by squares being allowed to hold nonsense.
final class Square {
  /// The square at [row], [col].
  factory Square(int row, int col) {
    RangeError.checkValueInInterval(row, 0, boardSize - 1, 'row');
    RangeError.checkValueInInterval(col, 0, boardSize - 1, 'col');
    return _all[row * boardSize + col];
  }

  const Square._(this.row, this.col);

  /// The square at [index], counting left to right from a8 then down.
  factory Square.fromIndex(int index) {
    RangeError.checkValueInInterval(index, 0, squareCount - 1, 'index');
    return _all[index];
  }

  /// The square [name] refers to, such as `e4`.
  factory Square.parse(String name) {
    final square = tryParse(name);
    if (square == null) {
      throw FormatException('not a square', name);
    }
    return square;
  }

  /// The square [name] refers to, or `null` when it is not one.
  static Square? tryParse(String name) {
    if (name.length != 2) return null;
    final col = name.codeUnitAt(0) - 0x61; // 'a'
    final rank = name.codeUnitAt(1) - 0x30; // '0'
    if (col < 0 || col >= boardSize || rank < 1 || rank > boardSize) return null;
    return _all[(boardSize - rank) * boardSize + col];
  }

  /// Every square, in index order: a8 first, h1 last.
  static List<Square> get all => _all;

  /// The zero-based row, `0` at the top of the board as drawn.
  final int row;

  /// The zero-based column, `0` on the a-file.
  final int col;

  /// The position of this square in row-major order, `0` to `63`.
  int get index => row * boardSize + col;

  /// The printed rank, `1` to `8`.
  int get rank => boardSize - row;

  /// The printed file, `a` to `h`.
  String get file => String.fromCharCode(0x61 + col);

  /// The algebraic name, such as `e4`.
  String get name => '$file$rank';

  /// Whether this is one of the light squares.
  ///
  /// a1 is dark and h1 is light, which is the rule the board is set up by.
  bool get isLight => (row + col).isEven;

  /// This square moved [rows] down and [cols] right, or `null` when that is
  /// off the board.
  Square? offset(int rows, int cols) {
    final r = row + rows;
    final c = col + cols;
    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) return null;
    return _all[r * boardSize + c];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Square && other.row == row && other.col == col;

  @override
  int get hashCode => index;

  @override
  String toString() => name;
}

final List<Square> _all = List<Square>.unmodifiable(
  List<Square>.generate(
    squareCount,
    (index) => Square._(index ~/ boardSize, index % boardSize),
    growable: false,
  ),
);
