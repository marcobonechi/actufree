import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Cell', () {
    test('index and coordinates round-trip', () {
      for (var index = 0; index < cellCount; index++) {
        final cell = Cell.fromIndex(index);
        expect(cell.index, index);
        expect(Cell(cell.row, cell.col), cell);
      }
    });

    test('boxes are numbered in reading order', () {
      expect(const Cell(0, 0).box, 0);
      expect(const Cell(0, 8).box, 2);
      expect(const Cell(4, 4).box, 4);
      expect(const Cell(8, 0).box, 6);
      expect(const Cell(8, 8).box, 8);
    });

    test('every cell has 20 peers and is not its own peer', () {
      for (final cell in Cell.all) {
        expect(cell.peers, hasLength(20));
        expect(cell.peers, isNot(contains(cell)));
      }
    });

    test('peers are exactly the cells sharing a row, column or box', () {
      for (final cell in <Cell>[
        const Cell(0, 0),
        const Cell(4, 4),
        const Cell(8, 3),
      ]) {
        for (final other in Cell.all) {
          if (other == cell) continue;
          final shares = other.row == cell.row ||
              other.col == cell.col ||
              other.box == cell.box;
          expect(cell.peers.contains(other), shares, reason: '$cell vs $other');
        }
      }
    });

    test('peering is symmetric', () {
      for (final cell in Cell.all) {
        for (final peer in cell.peers) {
          expect(peer.peers, contains(cell));
        }
      }
    });

    test('there are 27 units of 9 distinct cells', () {
      expect(allUnits, hasLength(27));
      for (final unit in allUnits) {
        expect(unit, hasLength(boardSize));
        expect(unit.toSet(), hasLength(boardSize));
      }
    });

    test('each cell belongs to exactly three units', () {
      for (final cell in Cell.all) {
        expect(cell.units, hasLength(3));
        expect(allUnits.where((unit) => unit.contains(cell)), hasLength(3));
      }
    });

    test('equal cells hash alike', () {
      expect(const Cell(3, 5), Cell.fromIndex(3 * boardSize + 5));
      expect(const Cell(3, 5).hashCode, Cell.fromIndex(3 * boardSize + 5).hashCode);
      expect(const Cell(3, 5) == const Cell(5, 3), isFalse);
    });

    test('rejects indices outside the board', () {
      expect(() => Cell.fromIndex(-1), throwsRangeError);
      expect(() => Cell.fromIndex(cellCount), throwsRangeError);
    });
  });
}
