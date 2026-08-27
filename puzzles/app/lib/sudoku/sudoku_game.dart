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

/// One game in progress: the board and the selection.
///
/// There is no undo. Every edit here writes one cell, and Erase already
/// reverses any of them, so a history would be weight without a use. Block
/// Blast will be a different question — placing a shape writes many cells and
/// clears lines, which is not reversible by hand.
class SudokuGame extends ChangeNotifier {
  /// Starts a game on [puzzle], optionally resuming from [board].
  SudokuGame(this.puzzle, {SudokuBoard? board})
      : _board = board ?? puzzle.givens,
        _conflicts = const <Cell>{} {
    // Resuming means conflicts, mistakes and which units are already finished
    // must be worked out before the first frame, not on the first move. Units
    // already complete in a resumed game are recorded, not announced: the
    // player finished them last time and does not need congratulating again.
    _apply(_board, announce: false);
  }

  static const SudokuSolver _solver = SudokuSolver();
  static const MoveValidator _validator = MoveValidator();

  /// The puzzle being played, including its solution.
  final SudokuPuzzle puzzle;

  SudokuBoard _board;
  Set<Cell> _conflicts;
  Set<Cell> _mistakes = const <Cell>{};
  Cell? _selected;
  bool _noteMode = false;
  Set<Cell> _highlighted = const <Cell>{};
  Set<int> _completeUnits = const <int>{};
  Set<Cell> _justCompleted = const <Cell>{};
  int _completionTick = 0;

  /// The board as it stands.
  SudokuBoard get board => _board;

  /// The selected cell, or `null` when nothing is selected.
  Cell? get selected => _selected;

  /// Whether digit presses write pencil marks instead of values.
  bool get noteMode => _noteMode;

  /// Cells whose digit duplicates a peer's.
  Set<Cell> get conflicts => _conflicts;

  /// Player entries that disagree with the solution.
  ///
  /// Always shown on the board. A wrong digit that happens not to clash with
  /// anything would otherwise sit there unnoticed until the puzzle had
  /// quietly become unsolvable.
  Set<Cell> get mistakes => _mistakes;

  /// Cells the last hint pointed at, for highlighting.
  Set<Cell> get highlighted => _highlighted;

  /// The cells of every row, column or box finished by the most recent move.
  Set<Cell> get justCompleted => _justCompleted;

  /// Counts completions, so the board can tell a fresh one from a rebuild.
  ///
  /// [justCompleted] alone is not enough: finishing the same-shaped unit twice
  /// in a row would produce an equal set and the animation would not replay.
  int get completionTick => _completionTick;

  /// Whether [cell] should be drawn as wrong: a mistaken entry, or a clue
  /// caught up in a clash with one.
  bool isWrong(Cell cell) =>
      _mistakes.contains(cell) || _conflicts.contains(cell);

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
  Cell? get firstMistake => _mistakes.isEmpty ? null : _mistakes.first;

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

  /// Fills the grid from the solution, leaving the last cell for the player.
  ///
  /// A testing affordance, not a game feature — see [kShowAutocomplete].
  ///
  /// One cell is deliberately left empty. Filling the whole grid would finish
  /// the puzzle in the same frame it completed the last units, so the win
  /// dialog would cover the completion flash — exactly the thing worth
  /// looking at. Leaving one cell means a single tap plays the flash and the
  /// win in sequence.
  ///
  /// The fill itself is applied without announcing completions: otherwise two
  /// dozen units would finish at once and the board would go entirely green.
  void autocomplete() {
    final open = Cell.all.where((Cell cell) => !_board.isGiven(cell)).toList();
    if (open.isEmpty) return;
    final last = open.last;
    var next = _board;
    for (final cell in open) {
      if (cell == last) {
        if (next.valueAt(cell) != null) next = next.withValue(cell, null);
        continue;
      }
      final answer = puzzle.solution.valueAt(cell)!;
      if (next.valueAt(cell) != answer) next = next.withValue(cell, answer);
    }
    _selected = last;
    _apply(next, announce: false);
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

  void _commit(SudokuBoard next) => _apply(next, announce: true);

  void _apply(SudokuBoard next, {required bool announce}) {
    _board = next;
    _conflicts = next.conflicts;
    _mistakes = <Cell>{
      for (final cell in Cell.all)
        if (!next.isGiven(cell) &&
            next.valueAt(cell) != null &&
            next.valueAt(cell) != puzzle.solution.valueAt(cell))
          cell,
    };
    final complete = <int>{};
    for (var unit = 0; unit < allUnits.length; unit++) {
      if (_isUnitComplete(next, allUnits[unit])) complete.add(unit);
    }
    final finished = complete.difference(_completeUnits);
    _completeUnits = complete;
    if (announce && finished.isNotEmpty) {
      _justCompleted = <Cell>{
        for (final unit in finished) ...allUnits[unit],
      };
      _completionTick++;
    } else {
      _justCompleted = const <Cell>{};
    }
    _highlighted = const <Cell>{};
    notifyListeners();
  }

  /// A unit counts as done only when it is right: nine cells, nine different
  /// digits. Filling a row with a repeat is not an achievement.
  static bool _isUnitComplete(SudokuBoard board, List<Cell> unit) {
    final seen = <int>{};
    for (final cell in unit) {
      final value = board.valueAt(cell);
      if (value == null) return false;
      seen.add(value);
    }
    return seen.length == boardSize;
  }
}
