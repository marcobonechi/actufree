import 'dart:convert';

import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

import 'puzzles.dart';

/// Round-trips through real JSON text, not just the map, so anything that is
/// not actually encodable fails here rather than on a player's device.
SudokuBoard _reencode(SudokuBoard board) => SudokuBoard.fromJson(
    jsonDecode(jsonEncode(board.toJson())) as Map<String, Object?>);

void main() {
  group('board JSON', () {
    test('survives a round-trip through encoded text', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(_reencode(board), board);
    });

    test('keeps player entries separate from givens', () {
      final board =
          SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 4);
      final restored = _reencode(board);
      expect(restored, board);
      expect(restored.valueAt(const Cell(0, 2)), 4);
      expect(restored.isGiven(const Cell(0, 2)), isFalse);
      expect(restored.isGiven(const Cell(0, 0)), isTrue);
    });

    test('keeps pencil marks', () {
      final board = SudokuBoard.parse(easyPuzzle)
          .withNoteToggled(const Cell(0, 2), 4)
          .withNoteToggled(const Cell(0, 2), 7)
          .withNoteToggled(const Cell(8, 5), 1);
      final restored = _reencode(board);
      expect(restored, board);
      expect(restored.notesAt(const Cell(0, 2)), <int>{4, 7});
      expect(restored.notesAt(const Cell(8, 5)), <int>{1});
      expect(restored.notesAt(const Cell(4, 4)), isEmpty);
    });

    test('omits the notes key when there are none', () {
      expect(SudokuBoard.parse(easyPuzzle).toJson(), isNot(contains('notes')));
    });

    test('an empty board round-trips', () {
      expect(_reencode(SudokuBoard.empty()), SudokuBoard.empty());
    });

    test('rejects malformed input', () {
      expect(() => SudokuBoard.fromJson(<String, Object?>{}),
          throwsFormatException);
      expect(
        () => SudokuBoard.fromJson(<String, Object?>{
          'givens': 'too short',
          'entries': '.' * cellCount,
        }),
        throwsFormatException,
      );
      expect(
        () => SudokuBoard.fromJson(<String, Object?>{
          'givens': '.' * cellCount,
          'entries': '.' * cellCount,
          'notes': <String, Object?>{'0': <Object?>[99]},
        }),
        throwsFormatException,
      );
      expect(
        () => SudokuBoard.fromJson(<String, Object?>{
          'givens': '.' * cellCount,
          'entries': '.' * cellCount,
          'notes': <String, Object?>{'nonsense': <Object?>[1]},
        }),
        throwsFormatException,
      );
    });
  });

  group('puzzle JSON', () {
    test('survives a round-trip through encoded text', () {
      for (final difficulty in Difficulty.values) {
        final puzzle = const SudokuGenerator(77).generate(difficulty);
        final restored = SudokuPuzzle.fromJson(
            jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, Object?>);
        expect(restored.givens, puzzle.givens);
        expect(restored.solution, puzzle.solution);
        expect(restored.seed, puzzle.seed);
        expect(restored.clueCount, puzzle.clueCount);
        expect(restored.difficulty, puzzle.difficulty);
        expect(restored.rating.tier, puzzle.rating.tier);
        expect(restored.rating.score, puzzle.rating.score);
        expect(restored.rating.hardestTechnique,
            puzzle.rating.hardestTechnique);
        expect(restored.rating.techniquesUsed,
            equals(puzzle.rating.techniquesUsed));
      }
    });

    test('rejects malformed input', () {
      expect(() => SudokuPuzzle.fromJson(<String, Object?>{}),
          throwsFormatException);
      final good = const SudokuGenerator(1).generate(Difficulty.easy).toJson();
      final badTechnique = Map<String, Object?>.of(good)
        ..['techniquesUsed'] = <String, Object?>{'telepathy': 3};
      expect(() => SudokuPuzzle.fromJson(badTechnique), throwsFormatException);
    });
  });
}
