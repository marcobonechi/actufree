import 'package:puzzle_store/puzzle_store.dart';

import 'puzzle.dart';
import 'sudoku_board.dart';

/// A Sudoku game in progress: the puzzle, and how far the player has got.
///
/// The puzzle is stored alongside the board rather than regenerated from its
/// seed. Regenerating would tie every saved game to the generator's exact
/// behaviour, so a change to the technique ladder would silently hand the
/// player a different puzzle than the one they were solving.
final class SudokuSave implements SavedGame {
  /// Creates a save.
  const SudokuSave({required this.puzzle, required this.board});

  /// Restores a save previously written by [toJson].
  factory SudokuSave.fromJson(Map<String, Object?> json) {
    final puzzle = json['puzzle'];
    final board = json['board'];
    if (puzzle is! Map<String, Object?> || board is! Map<String, Object?>) {
      throw const FormatException('malformed sudoku save');
    }
    return SudokuSave(
      puzzle: SudokuPuzzle.fromJson(puzzle),
      board: SudokuBoard.fromJson(board),
    );
  }

  /// The puzzle being played.
  final SudokuPuzzle puzzle;

  /// The board as the player left it, entries and pencil marks included.
  final SudokuBoard board;

  @override
  String get gameId => 'sudoku';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'puzzle': puzzle.toJson(),
        'board': board.toJson(),
      };
}
