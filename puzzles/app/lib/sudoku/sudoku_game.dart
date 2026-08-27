import 'package:flutter/foundation.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

/// What a press of the hint button produced, in a form the screen can show.
@immutable
class HintResult {
  /// Creates a hint result.
  const HintResult(this.message, {this.label});

  /// A sentence to show the player.
  final String message;

  /// The technique's short name, when a technique justified the step.
  final String? label;
}

/// One game in progress: the board, the selection, and the undo history.
///
/// Undo is a stack of whole boards rather than a stack of commands. Boards are
/// immutable and small, so keeping old values is cheaper than describing how
/// to reverse each edit. The generic command stack the shared layer wants can
/// be built on this once a second game needs one.
class SudokuGame extends ChangeNotifier {
  /// Starts a game on [puzzle].
  SudokuGame(this.puzzle)
      : _board = puzzle.givens,
        _conflicts = const <Cell>{};

  static const SudokuSolver _solver = SudokuSolver();
  static const MoveValidator _validator = MoveValidator();

  /// The puzzle being played, including its solution.
  final SudokuPuzzle puzzle;

  SudokuBoard _board;
  Set<Cell> _conflicts;
  final List<SudokuBoard> _past = <SudokuBoard>[];
  final List<SudokuBoard> _future = <SudokuBoard>[];
  Cell? _selected;
  bool _noteMode = false;
  Set<Cell> _highlighted = const <Cell>{};

  /// The board as it stands.
  SudokuBoard get board => _board;

  /// The selected cell, or `null` when nothing is selected.
  Cell? get selected => _selected;

  /// Whether digit presses write pencil marks instead of values.
  bool get noteMode => _noteMode;

  /// Cells whose digit duplicates a peer's.
  Set<Cell> get conflicts => _conflicts;

  /// Cells the last hint pointed at, for highlighting.
  Set<Cell> get highlighted => _highlighted;

  /// Whether there is anything to undo.
  bool get canUndo => _past.isNotEmpty;

  /// Whether there is anything to redo.
  bool get canRedo => _future.isNotEmpty;

  /// Whether the puzzle is finished and correct.
  bool get isSolved => _board.isSolved;

  /// How many of [digit] are still to be placed.
  int remaining(int digit) {
    var placed = 0;
    for (final cell in Cell.all) {
      if (_board.valueAt(cell) == digit) placed++;
    }
    return boardSize - placed;
  }

  /// The first player entry that disagrees with the solution, if any.
  Cell? get firstMistake {
    for (final cell in Cell.all) {
      if (_board.isGiven(cell)) continue;
      final value = _board.valueAt(cell);
      if (value == null) continue;
      if (value != puzzle.solution.valueAt(cell)) return cell;
    }
    return null;
  }

  /// Selects [cell].
  void select(Cell cell) {
    if (_selected == cell) return;
    _selected = cell;
    _highlighted = const <Cell>{};
    notifyListeners();
  }

  /// Turns pencil-mark entry on or off.
  void toggleNoteMode() {
    _noteMode = !_noteMode;
    notifyListeners();
  }

  /// Handles a press of [digit] on the number pad.
  void enter(int digit) {
    final cell = _selected;
    if (cell == null || _board.isGiven(cell)) return;
    if (_noteMode) {
      if (_board.valueAt(cell) != null) return;
      _commit(_board.withNoteToggled(cell, digit));
      return;
    }
    if (_board.valueAt(cell) == digit) {
      _commit(_board.withValue(cell, null));
      return;
    }
    final result = _validator.apply(_board, cell, digit);
    if (result is MoveAccepted) _commit(result.board);
  }

  /// Clears the selected cell's digit, or its notes when it has none.
  void erase() {
    final cell = _selected;
    if (cell == null || _board.isGiven(cell)) return;
    if (_board.valueAt(cell) != null) {
      _commit(_board.withValue(cell, null));
      return;
    }
    if (_board.notesAt(cell).isNotEmpty) {
      _commit(_board.withNotesCleared(cell));
    }
  }

  /// Steps back one move.
  void undo() {
    if (_past.isEmpty) return;
    _future.add(_board);
    _replace(_past.removeLast());
  }

  /// Steps forward one undone move.
  void redo() {
    if (_future.isEmpty) return;
    _past.add(_board);
    _replace(_future.removeLast());
  }

  /// Clears every entry and note, keeping the clues.
  void restart() {
    if (_board == puzzle.givens) return;
    _commit(puzzle.givens);
  }

  /// Works out the next step and applies what can be applied.
  ///
  /// A wrong entry already on the board is reported first: the engine reasons
  /// from what is on the board, so hinting past a mistake would cheerfully
  /// deduce its way into a dead end.
  HintResult? requestHint() {
    if (isSolved) return null;
    final mistake = firstMistake;
    if (mistake != null) {
      _selected = mistake;
      _highlighted = <Cell>{mistake};
      notifyListeners();
      return HintResult(
        'The ${_board.valueAt(mistake)} at $mistake is wrong. Clear it and '
        'the rest will follow.',
        label: 'Mistake',
      );
    }
    final hint = _solver.nextHint(_board);
    if (hint == null) {
      return const HintResult(
        'No further step follows from logic alone — this one needs a guess.',
      );
    }
    switch (hint) {
      case PlacementHint():
        _commit(_board.withValue(hint.cell, hint.digit));
        _selected = hint.cell;
        _highlighted = <Cell>{hint.cell};
      case EliminationHint():
        var next = _board;
        for (final entry in hint.eliminations.entries) {
          for (final digit in entry.value) {
            if (next.notesAt(entry.key).contains(digit)) {
              next = next.withNoteToggled(entry.key, digit);
            }
          }
        }
        if (next != _board) _commit(next);
        _highlighted = hint.because;
    }
    notifyListeners();
    return HintResult(hint.explanation, label: hint.technique.label);
  }

  void _commit(SudokuBoard next) {
    _past.add(_board);
    _future.clear();
    _replace(next);
  }

  void _replace(SudokuBoard next) {
    _board = next;
    _conflicts = next.conflicts;
    _highlighted = const <Cell>{};
    notifyListeners();
  }
}
