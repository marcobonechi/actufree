import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  final domino = BlockShape.fromRows(<String>['##']);
  final square = BlockShape.fromRows(<String>['##', '##']);

  test('an empty board holds nothing', () {
    final board = BlockBoard.empty();
    expect(board.isEmpty, isTrue);
    expect(board.filledCount, 0);
    for (final coord in Coord.all) {
      expect(board.isFilled(coord), isFalse);
      expect(board.paintAt(coord), 0);
    }
  });

  test('a placed shape keeps its paint', () {
    final board = BlockBoard.empty().withShape(square, const Coord(2, 3), 4);
    expect(board.filledCount, 4);
    expect(board.paintAt(const Coord(2, 3)), 4);
    expect(board.paintAt(const Coord(3, 4)), 4);
    expect(board.paintAt(const Coord(2, 5)), 0);
  });

  test('placing does not change the board it came from', () {
    final before = BlockBoard.empty();
    before.withShape(square, const Coord(0, 0), 1);
    expect(before.isEmpty, isTrue);
  });

  test('a shape does not fit off the edge', () {
    final board = BlockBoard.empty();
    expect(board.fits(domino, const Coord(0, boardSize - 2)), isTrue);
    expect(board.fits(domino, const Coord(0, boardSize - 1)), isFalse);
    expect(board.fits(domino, const Coord(boardSize, 0)), isFalse);
    expect(board.fits(domino, const Coord(-1, 0)), isFalse);
  });

  test('a shape does not fit over an occupied cell', () {
    final board = BlockBoard.empty().withShape(domino, const Coord(0, 0), 1);
    expect(board.fits(domino, const Coord(0, 0)), isFalse);
    expect(board.fits(domino, const Coord(0, 1)), isFalse);
    expect(board.fits(domino, const Coord(0, 2)), isTrue);
  });

  test('placing where it does not fit throws rather than doing nothing', () {
    final board = BlockBoard.empty().withShape(domino, const Coord(0, 0), 1);
    expect(
      () => board.withShape(domino, const Coord(0, 0), 2),
      throwsArgumentError,
    );
  });

  test('anchors are every legal spot, in row-major order', () {
    final board = BlockBoard.empty();
    final anchors = board.anchorsFor(square);
    expect(anchors, hasLength((boardSize - 1) * (boardSize - 1)));
    expect(anchors.first, const Coord(0, 0));
    expect(anchors.last, const Coord(boardSize - 2, boardSize - 2));
    for (final anchor in anchors) {
      expect(board.fits(square, anchor), isTrue);
    }
  });

  test('fitsAnywhere agrees with anchorsFor', () {
    final board = BlockBoard.fromRows(<String>[
      '1111111.',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
    ]);
    for (final shape in ShapeCatalogue.shapes) {
      expect(board.fitsAnywhere(shape), board.anchorsFor(shape).isNotEmpty);
    }
    expect(board.fitsAnywhere(BlockShape.fromRows(<String>['#'])), isTrue);
    expect(board.fitsAnywhere(domino), isFalse);
  });

  test('a full row clears', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, <int>[0]);
    expect(clear.cols, isEmpty);
    expect(clear.lineCount, 1);
    expect(clear.cells, hasLength(boardSize));
    expect(clear.board.isEmpty, isTrue);
  });

  test('a full column clears', () {
    final board = BlockBoard.fromRows(<String>[
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, isEmpty);
    expect(clear.cols, <int>[0]);
    expect(clear.board.isEmpty, isTrue);
  });

  test('a crossing row and column both clear, sharing their cell', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, <int>[0]);
    expect(clear.cols, <int>[0]);
    expect(clear.lineCount, 2);
    // Fifteen, not sixteen: r1c1 belongs to both lines.
    expect(clear.cells, hasLength(boardSize * 2 - 1));
    expect(clear.board.isEmpty, isTrue);
  });

  test('cells outside the cleared lines are left alone', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '3.......',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final clear = board.clearFullLines();
    expect(clear.board.paintAt(const Coord(1, 0)), 3);
    expect(clear.board.filledCount, 1);
  });

  test('nothing full means nothing changes', () {
    final board = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    final clear = board.clearFullLines();
    expect(clear.isEmpty, isTrue);
    expect(clear.lineCount, 0);
    expect(clear.board, board);
  });

  test('a board round-trips through JSON', () {
    final board = BlockBoard.empty()
        .withShape(square, const Coord(1, 1), 3)
        .withShape(domino, const Coord(5, 5), 6);
    expect(BlockBoard.fromJson(board.toJson()), board);
  });

  test('malformed board JSON is refused', () {
    expect(() => BlockBoard.fromJson(<Object?>[1, 2]), throwsFormatException);
    expect(
      () => BlockBoard.fromJson(List<Object?>.filled(cellCount, 'x')),
      throwsFormatException,
    );
  });

  test('boards of the same cells are equal and hash alike', () {
    final one = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    final two = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    expect(one, two);
    expect(<BlockBoard>{one, two}, hasLength(1));
    expect(
      one,
      isNot(BlockBoard.empty().withShape(square, const Coord(0, 0), 2)),
    );
  });
}
