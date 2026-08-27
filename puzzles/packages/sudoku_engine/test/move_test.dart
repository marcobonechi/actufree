import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

import 'puzzles.dart';

void main() {
  final board = SudokuBoard.parse(easyPuzzle);
  const lenient = MoveValidator();
  const strict = MoveValidator(strict: true);

  test('a legal move is accepted and applied', () {
    final result = lenient.apply(board, const Cell(0, 2), 4);
    expect(result, isA<MoveAccepted>());
    expect((result as MoveAccepted).board.valueAt(const Cell(0, 2)), 4);
  });

  test('a given cannot be overwritten by either validator', () {
    for (final validator in <MoveValidator>[lenient, strict]) {
      final result = validator.apply(board, const Cell(0, 0), 4);
      expect(result, isA<MoveRejected>());
      expect((result as MoveRejected).reason, MoveRejection.cellIsGiven);
      expect(result.culprits, isEmpty);
    }
  });

  test('digits outside 1-9 are rejected', () {
    for (final digit in <int>[0, -1, 10]) {
      final result = lenient.apply(board, const Cell(0, 2), digit);
      expect(result, isA<MoveRejected>());
      expect((result as MoveRejected).reason, MoveRejection.digitOutOfRange);
    }
  });

  test('a lenient validator lets a conflicting digit through', () {
    // 5 is already at r1c1, in the same row and box as r1c3.
    final result = lenient.apply(board, const Cell(0, 2), 5);
    expect(result, isA<MoveAccepted>());
    final played = (result as MoveAccepted).board;
    expect(played.conflicts, contains(const Cell(0, 2)));
  });

  test('a strict validator refuses it and names the culprits', () {
    final result = strict.apply(board, const Cell(0, 2), 5);
    expect(result, isA<MoveRejected>());
    final rejected = result as MoveRejected;
    expect(rejected.reason, MoveRejection.conflictsWithPeer);
    expect(rejected.culprits, contains(const Cell(0, 0)));
    for (final culprit in rejected.culprits) {
      expect(board.valueAt(culprit), 5);
      expect(const Cell(0, 2).peers, contains(culprit));
    }
  });

  test('clearing a cell is always allowed unless it is a given', () {
    final played = board.withValue(const Cell(0, 2), 5);
    for (final validator in <MoveValidator>[lenient, strict]) {
      final result = validator.apply(played, const Cell(0, 2), null);
      expect(result, isA<MoveAccepted>());
      expect((result as MoveAccepted).board.valueAt(const Cell(0, 2)), isNull);
    }
  });

  test('every rejection carries a message worth showing', () {
    for (final reason in MoveRejection.values) {
      expect(reason.message, isNotEmpty);
    }
  });
}
