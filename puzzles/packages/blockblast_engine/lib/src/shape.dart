import 'coord.dart';

/// A polyomino the player can drop onto the board.
///
/// Cells are offsets from the shape's own top-left corner, normalised so that
/// the smallest row and the smallest column are both zero and the cells are in
/// row-major order. Two shapes drawn the same way are therefore equal however
/// they were built, which is what makes the catalogue's rotations comparable
/// and lets a test say "this is the S tetromino" without knowing how it was
/// spelled.
///
/// Shapes carry no rotation of their own. Block Blast does not let the player
/// turn a piece, so every orientation that can be dealt is a separate entry in
/// the catalogue.
final class BlockShape {
  BlockShape._(this.cells, this.width, this.height);

  /// A shape covering [cells], which are normalised on the way in.
  ///
  /// Throws when [cells] is empty or holds a repeat: neither describes a piece
  /// anyone could place.
  factory BlockShape(Iterable<Coord> cells) {
    final unique = cells.toSet();
    if (unique.isEmpty) {
      throw ArgumentError.value(cells, 'cells', 'a shape needs a cell');
    }
    if (unique.length != cells.length) {
      throw ArgumentError.value(cells, 'cells', 'repeated cell');
    }
    var minRow = unique.first.row;
    var minCol = unique.first.col;
    for (final cell in unique) {
      if (cell.row < minRow) minRow = cell.row;
      if (cell.col < minCol) minCol = cell.col;
    }
    final normalised = unique
        .map((Coord cell) => cell.translate(-minRow, -minCol))
        .toList()
      ..sort(_rowMajor);
    var width = 0;
    var height = 0;
    for (final cell in normalised) {
      if (cell.col + 1 > width) width = cell.col + 1;
      if (cell.row + 1 > height) height = cell.row + 1;
    }
    return BlockShape._(List<Coord>.unmodifiable(normalised), width, height);
  }

  /// A shape drawn as text, one string per row, `#` for a filled cell.
  ///
  /// Reads the way the piece looks, which is worth a great deal in the
  /// catalogue and in tests:
  ///
  /// ```dart
  /// BlockShape.fromRows(<String>['.##', '##.']);  // the S tetromino
  /// ```
  factory BlockShape.fromRows(List<String> rows) {
    final cells = <Coord>[];
    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < rows[row].length; col++) {
        if (rows[row][col] == '#') cells.add(Coord(row, col));
      }
    }
    return BlockShape(cells);
  }

  /// Restores a shape previously written by [toJson].
  factory BlockShape.fromJson(List<Object?> json) {
    if (json.length.isOdd) {
      throw const FormatException('shape needs row and column per cell');
    }
    final cells = <Coord>[];
    for (var i = 0; i < json.length; i += 2) {
      final row = json[i];
      final col = json[i + 1];
      if (row is! int || col is! int) {
        throw const FormatException('malformed shape cell');
      }
      cells.add(Coord(row, col));
    }
    return BlockShape(cells);
  }

  /// The cells covered, normalised and in row-major order.
  final List<Coord> cells;

  /// How many columns the shape spans.
  final int width;

  /// How many rows the shape spans.
  final int height;

  /// How many cells the shape covers.
  int get size => cells.length;

  /// The cells this shape would cover with its top-left corner at [anchor].
  Iterable<Coord> at(Coord anchor) =>
      cells.map((Coord cell) => cell.translate(anchor.row, anchor.col));

  /// The cells as flat row, column pairs.
  ///
  /// Written out cell by cell rather than as a catalogue name so that a saved
  /// game survives the catalogue being reshuffled. A piece the player is
  /// holding should not turn into a different piece because a later version
  /// added a shape ahead of it in the list.
  List<Object?> toJson() => <Object?>[
        for (final cell in cells) ...<int>[cell.row, cell.col],
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BlockShape || other.cells.length != cells.length) {
      return false;
    }
    for (var i = 0; i < cells.length; i++) {
      if (other.cells[i] != cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(cells);

  @override
  String toString() {
    final filled = cells.toSet();
    return <String>[
      for (var row = 0; row < height; row++)
        <String>[
          for (var col = 0; col < width; col++)
            filled.contains(Coord(row, col)) ? '#' : '.',
        ].join(),
    ].join('/');
  }

  static int _rowMajor(Coord a, Coord b) =>
      a.row == b.row ? a.col - b.col : a.row - b.row;
}
