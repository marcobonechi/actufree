import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

import 'puzzles.dart';

void main() {
  group('parsing', () {
    test('round-trips through a compact string', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(board.toCompactString(), easyPuzzle.replaceAll('0', '.'));
    });

    test('ignores whitespace so grids can be written out in rows', () {
      final spread = SudokuBoard.parse('''
        530 070 000
        600 195 000
        098 000 060
        800 060 003
        400 803 001
        700 020 006
        060 000 280
        000 419 005
        000 080 079
      ''');
      expect(spread, SudokuBoard.parse(easyPuzzle));
    });

    test('treats dot, zero and dash alike', () {
      expect(SudokuBoard.parse('1${'.' * 80}'),
          SudokuBoard.parse('1${'0' * 80}'));
      expect(SudokuBoard.parse('1${'.' * 80}'),
          SudokuBoard.parse('1${'-' * 80}'));
    });

    test('every parsed digit becomes a given', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(board.isGiven(const Cell(0, 0)), isTrue);
      expect(board.isGiven(const Cell(0, 2)), isFalse);
    });

    test('rejects the wrong number of cells', () {
      expect(() => SudokuBoard.parse('123'), throwsFormatException);
      expect(() => SudokuBoard.parse('.' * 82), throwsFormatException);
    });

    test('rejects characters that are not digits', () {
      expect(() => SudokuBoard.parse('x${'.' * 80}'), throwsFormatException);
    });

    test('fromGivens rejects a wrong-length list', () {
      expect(() => SudokuBoard.fromGivens(<int?>[1, 2, 3]), throwsArgumentError);
    });

    test('fromGivens rejects digits outside 1-9', () {
      final givens = List<int?>.filled(cellCount, null);
      givens[0] = 10;
      expect(() => SudokuBoard.fromGivens(givens), throwsRangeError);
    });
  });

  group('reading', () {
    test('an empty board has no values and no givens', () {
      final board = SudokuBoard.empty();
      for (final cell in Cell.all) {
        expect(board.valueAt(cell), isNull);
        expect(board.isGiven(cell), isFalse);
      }
      expect(board.emptyCells, hasLength(cellCount));
      expect(board.isComplete, isFalse);
    });

    test('legalDigitsAt excludes every digit already seen by the cell', () {
      final board = SudokuBoard.parse(easyPuzzle);
      // r1c3 sees 5 and 3 in its row, 8 and 9 in its box, 7 in its column.
      final legal = board.legalDigitsAt(const Cell(0, 2));
      expect(legal, isNot(contains(5)));
      expect(legal, isNot(contains(3)));
      expect(legal, isNot(contains(8)));
      expect(legal, contains(1));
      for (final digit in legal) {
        expect(board.isLegal(const Cell(0, 2), digit), isTrue);
      }
    });

    test('legalDigitsAt is empty for a filled cell', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(board.legalDigitsAt(const Cell(0, 0)), isEmpty);
    });

    test('isLegal refuses digits outside 1-9', () {
      final board = SudokuBoard.empty();
      expect(board.isLegal(const Cell(0, 0), 0), isFalse);
      expect(board.isLegal(const Cell(0, 0), 10), isFalse);
    });

    test('a consistent board reports no conflicts', () {
      expect(SudokuBoard.parse(easyPuzzle).conflicts, isEmpty);
      expect(SudokuBoard.parse(easySolution).conflicts, isEmpty);
    });

    test('conflicts name both cells of a clash', () {
      final board = SudokuBoard.parse(contradictoryPuzzle);
      expect(board.conflicts, contains(const Cell(0, 0)));
      expect(board.conflicts, contains(const Cell(0, 4)));
    });

    test('conflicts are found down columns and inside boxes', () {
      final column = SudokuBoard.empty()
          .withValue(const Cell(0, 3), 7)
          .withValue(const Cell(5, 3), 7);
      expect(column.conflicts,
          <Cell>{const Cell(0, 3), const Cell(5, 3)});

      final box = SudokuBoard.empty()
          .withValue(const Cell(3, 3), 2)
          .withValue(const Cell(5, 5), 2);
      expect(box.conflicts, <Cell>{const Cell(3, 3), const Cell(5, 5)});
    });

    test('a full but wrong board is complete and not solved', () {
      final wrong = SudokuBoard.parse('1' * 81);
      expect(wrong.isComplete, isTrue);
      expect(wrong.isSolved, isFalse);
    });

    test('the known solution is solved', () {
      expect(SudokuBoard.parse(easySolution).isSolved, isTrue);
    });
  });

  group('mutation', () {
    test('returns a new board and leaves the original alone', () {
      final before = SudokuBoard.parse(easyPuzzle);
      final after = before.withValue(const Cell(0, 2), 4);
      expect(after.valueAt(const Cell(0, 2)), 4);
      expect(before.valueAt(const Cell(0, 2)), isNull);
      expect(before, isNot(after));
    });

    test('refuses to change a given', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(() => board.withValue(const Cell(0, 0), 4), throwsStateError);
      expect(() => board.withNoteToggled(const Cell(0, 0), 4), throwsStateError);
    });

    test('refuses digits outside 1-9', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(() => board.withValue(const Cell(0, 2), 0), throwsRangeError);
      expect(() => board.withValue(const Cell(0, 2), 10), throwsRangeError);
    });

    test('a null digit clears the cell', () {
      final board = SudokuBoard.parse(easyPuzzle)
          .withValue(const Cell(0, 2), 4)
          .withValue(const Cell(0, 2), null);
      expect(board.valueAt(const Cell(0, 2)), isNull);
    });

    test('notes toggle on and off', () {
      const cell = Cell(0, 2);
      var board = SudokuBoard.parse(easyPuzzle);
      expect(board.notesAt(cell), isEmpty);
      board = board.withNoteToggled(cell, 4).withNoteToggled(cell, 7);
      expect(board.notesAt(cell), <int>{4, 7});
      board = board.withNoteToggled(cell, 4);
      expect(board.notesAt(cell), <int>{7});
    });

    test('notes are independent per cell', () {
      final board = SudokuBoard.parse(easyPuzzle)
          .withNoteToggled(const Cell(0, 2), 4)
          .withNoteToggled(const Cell(0, 3), 9);
      expect(board.notesAt(const Cell(0, 2)), <int>{4});
      expect(board.notesAt(const Cell(0, 3)), <int>{9});
    });

    test('writing a value clears that cell\'s notes', () {
      final board = SudokuBoard.parse(easyPuzzle)
          .withNoteToggled(const Cell(0, 2), 4)
          .withValue(const Cell(0, 2), 1);
      expect(board.notesAt(const Cell(0, 2)), isEmpty);
    });

    test('notes cannot be written on a filled cell', () {
      final board =
          SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 1);
      expect(
          () => board.withNoteToggled(const Cell(0, 2), 4), throwsStateError);
    });

    test('withNotesCleared empties one cell', () {
      final board = SudokuBoard.parse(easyPuzzle)
          .withNoteToggled(const Cell(0, 2), 4)
          .withNotesCleared(const Cell(0, 2));
      expect(board.notesAt(const Cell(0, 2)), isEmpty);
    });

    test('reset keeps the givens and drops everything else', () {
      final played = SudokuBoard.parse(easyPuzzle)
          .withValue(const Cell(0, 2), 4)
          .withNoteToggled(const Cell(0, 3), 9);
      final fresh = played.reset();
      expect(fresh, SudokuBoard.parse(easyPuzzle));
      expect(fresh.valueAt(const Cell(0, 2)), isNull);
      expect(fresh.notesAt(const Cell(0, 3)), isEmpty);
      expect(fresh.valueAt(const Cell(0, 0)), 5);
    });
  });

  group('equality', () {
    test('boards with the same content are equal and hash alike', () {
      final a = SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 4);
      final b = SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('notes count towards equality', () {
      final plain = SudokuBoard.parse(easyPuzzle);
      final noted = plain.withNoteToggled(const Cell(0, 2), 4);
      expect(noted, isNot(plain));
    });

    test('a given differs from the same digit entered by the player', () {
      final given = SudokuBoard.parse('5${'.' * 80}');
      final entered = SudokuBoard.empty().withValue(const Cell(0, 0), 5);
      expect(given.toCompactString(), entered.toCompactString());
      expect(given, isNot(entered));
    });
  });
}
