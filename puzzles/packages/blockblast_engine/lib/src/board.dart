import 'dart:typed_data';

import 'coord.dart';
import 'shape.dart';

/// What clearing full lines produced.
final class LineClear {
  /// Records a clear.
  const LineClear({
    required this.board,
    required this.rows,
    required this.cols,
    required this.cells,
  });

  /// The board with the full lines emptied.
  final BlockBoard board;

  /// The rows that were full, in ascending order.
  final List<int> rows;

  /// The columns that were full, in ascending order.
  final List<int> cols;

  /// Every cell emptied.
  ///
  /// A row and a column that cross share a cell, so this is not simply eight
  /// per line — which is also why scoring counts lines rather than cells.
  final Set<Coord> cells;

  /// How many lines came out.
  int get lineCount => rows.length + cols.length;

  /// Whether anything was cleared at all.
  bool get isEmpty => lineCount == 0;
}

/// The 8x8 playing field.
///
/// Immutable: every change hands back a new board. Each cell holds either zero
/// for empty or the paint of the piece that filled it, so the board remembers
/// where its squares came from without knowing what any of it looks like.
final class BlockBoard {
  BlockBoard._(this._cells);

  /// A board with nothing on it.
  factory BlockBoard.empty() => BlockBoard._(Uint8List(cellCount));

  /// A board drawn as text, one string per row, `.` for an empty cell and any
  /// digit `1`-`9` for a cell painted that colour.
  ///
  /// For tests, which otherwise spend more lines building a board than
  /// checking anything about it.
  factory BlockBoard.fromRows(List<String> rows) {
    if (rows.length != boardSize) {
      throw ArgumentError.value(rows, 'rows', 'need $boardSize rows');
    }
    final cells = Uint8List(cellCount);
    for (var row = 0; row < boardSize; row++) {
      if (rows[row].length != boardSize) {
        throw ArgumentError.value(rows, 'rows', 'row $row is not $boardSize wide');
      }
      for (var col = 0; col < boardSize; col++) {
        final glyph = rows[row][col];
        if (glyph == '.') continue;
        final paint = int.tryParse(glyph);
        if (paint == null || paint < 1) {
          throw ArgumentError.value(rows, 'rows', 'bad glyph "$glyph"');
        }
        cells[row * boardSize + col] = paint;
      }
    }
    return BlockBoard._(cells);
  }

  /// Restores a board previously written by [toJson].
  factory BlockBoard.fromJson(List<Object?> json) {
    if (json.length != cellCount) {
      throw const FormatException('board needs $cellCount cells');
    }
    final cells = Uint8List(cellCount);
    for (var i = 0; i < cellCount; i++) {
      final paint = json[i];
      if (paint is! int || paint < 0 || paint > 255) {
        throw const FormatException('malformed board cell');
      }
      cells[i] = paint;
    }
    return BlockBoard._(cells);
  }

  final Uint8List _cells;

  /// The paint filling [coord], or zero when it is empty.
  int paintAt(Coord coord) => _cells[coord.index];

  /// Whether [coord] holds anything.
  bool isFilled(Coord coord) => _cells[coord.index] != 0;

  /// How many cells are filled.
  int get filledCount {
    var filled = 0;
    for (final paint in _cells) {
      if (paint != 0) filled++;
    }
    return filled;
  }

  /// Whether nothing is on the board.
  bool get isEmpty => filledCount == 0;

  /// Whether [shape] can be dropped with its top-left corner at [anchor]:
  /// every cell on the board, and every cell empty.
  bool fits(BlockShape shape, Coord anchor) {
    for (final cell in shape.cells) {
      final target = cell.translate(anchor.row, anchor.col);
      if (!target.isOnBoard) return false;
      if (_cells[target.index] != 0) return false;
    }
    return true;
  }

  /// Every anchor where [shape] can be dropped, in row-major order.
  List<Coord> anchorsFor(BlockShape shape) => <Coord>[
        for (var row = 0; row <= boardSize - shape.height; row++)
          for (var col = 0; col <= boardSize - shape.width; col++)
            if (fits(shape, Coord(row, col))) Coord(row, col),
      ];

  /// Whether [shape] can be dropped anywhere at all.
  ///
  /// Stops at the first anchor that works, so it does not pay for the full
  /// list the way [anchorsFor] does. Worth the separate method: this is asked
  /// after every placement, for every piece still in the hand.
  bool fitsAnywhere(BlockShape shape) {
    for (var row = 0; row <= boardSize - shape.height; row++) {
      for (var col = 0; col <= boardSize - shape.width; col++) {
        if (fits(shape, Coord(row, col))) return true;
      }
    }
    return false;
  }

  /// This board with [shape] dropped at [anchor] in [paint].
  ///
  /// Throws when it does not fit; ask [fits] first. A placement that silently
  /// did nothing would be far harder to notice than one that threw.
  BlockBoard withShape(BlockShape shape, Coord anchor, int paint) {
    RangeError.checkValueInInterval(paint, 1, 255, 'paint');
    if (!fits(shape, anchor)) {
      throw ArgumentError.value(anchor, 'anchor', 'shape does not fit there');
    }
    final next = Uint8List.fromList(_cells);
    for (final cell in shape.at(anchor)) {
      next[cell.index] = paint;
    }
    return BlockBoard._(next);
  }

  /// This board with every full row and column emptied.
  ///
  /// Rows and columns are found before anything is emptied, so a row and a
  /// column that are both full both clear — emptying the row first would leave
  /// the column short a cell and it would survive.
  LineClear clearFullLines() {
    final rows = <int>[
      for (var row = 0; row < boardSize; row++)
        if (_isRowFull(row)) row,
    ];
    final cols = <int>[
      for (var col = 0; col < boardSize; col++)
        if (_isColFull(col)) col,
    ];
    if (rows.isEmpty && cols.isEmpty) {
      return LineClear(
        board: this,
        rows: const <int>[],
        cols: const <int>[],
        cells: const <Coord>{},
      );
    }
    final cleared = <Coord>{
      for (final row in rows)
        for (var col = 0; col < boardSize; col++) Coord(row, col),
      for (final col in cols)
        for (var row = 0; row < boardSize; row++) Coord(row, col),
    };
    final next = Uint8List.fromList(_cells);
    for (final cell in cleared) {
      next[cell.index] = 0;
    }
    return LineClear(
      board: BlockBoard._(next),
      rows: List<int>.unmodifiable(rows),
      cols: List<int>.unmodifiable(cols),
      cells: Set<Coord>.unmodifiable(cleared),
    );
  }

  /// The paint of every cell, in row-major order.
  List<Object?> toJson() => List<int>.unmodifiable(_cells);

  bool _isRowFull(int row) {
    for (var col = 0; col < boardSize; col++) {
      if (_cells[row * boardSize + col] == 0) return false;
    }
    return true;
  }

  bool _isColFull(int col) {
    for (var row = 0; row < boardSize; row++) {
      if (_cells[row * boardSize + col] == 0) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BlockBoard) return false;
    for (var i = 0; i < cellCount; i++) {
      if (other._cells[i] != _cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_cells);

  @override
  String toString() => <String>[
        for (var row = 0; row < boardSize; row++)
          <String>[
            for (var col = 0; col < boardSize; col++)
              _cells[row * boardSize + col] == 0
                  ? '.'
                  : '${_cells[row * boardSize + col]}',
          ].join(),
      ].join('/');
}
