import 'package:puzzle_store/puzzle_store.dart';
import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

void main() {
  test('a game in progress round-trips through a store', () async {
    final puzzle = const SudokuGenerator(31).generate(Difficulty.medium);
    final played = puzzle.givens
        .withValue(puzzle.givens.emptyCells.first, 5)
        .withNoteToggled(puzzle.givens.emptyCells.last, 7);

    final store = GameStore(MemoryStore());
    await store.save(
      SudokuSave(puzzle: puzzle, board: played),
      slot: puzzle.difficulty.name,
    );
    final restored = await store.load(
      'sudoku',
      SudokuSave.fromJson,
      slot: puzzle.difficulty.name,
    );

    expect(restored, isNotNull);
    expect(restored!.board, played);
    expect(restored.puzzle.givens, puzzle.givens);
    expect(restored.puzzle.solution, puzzle.solution);
    expect(restored.puzzle.difficulty, puzzle.difficulty);
    expect(restored.board.notesAt(puzzle.givens.emptyCells.last), <int>{7});
  });

  test('each difficulty keeps its own game', () async {
    final store = GameStore(MemoryStore());
    for (final difficulty in Difficulty.values) {
      final puzzle = const SudokuGenerator(9).generate(difficulty);
      await store.save(
        SudokuSave(puzzle: puzzle, board: puzzle.givens),
        slot: difficulty.name,
      );
    }
    for (final difficulty in Difficulty.values) {
      final restored = await store.load(
        'sudoku',
        SudokuSave.fromJson,
        slot: difficulty.name,
      );
      expect(restored?.puzzle.difficulty, difficulty);
    }
  });

  test('the game id is stable', () {
    final puzzle = const SudokuGenerator(1).generate(Difficulty.easy);
    expect(SudokuSave(puzzle: puzzle, board: puzzle.givens).gameId, 'sudoku');
  });
}
