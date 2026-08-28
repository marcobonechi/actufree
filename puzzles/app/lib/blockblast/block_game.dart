import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/foundation.dart';

/// One step of a shown hint: where a piece goes, and how far into the plan.
final class HintStep {
  /// Records a step.
  const HintStep({
    required this.cells,
    required this.paint,
    required this.order,
  });

  /// The squares the piece would cover.
  final Set<Coord> cells;

  /// The colour of the piece going there.
  final int paint;

  /// Which step this is, counting from one.
  final int order;
}

/// One game of Block Blast, and the drag in progress over it.
///
/// The engine's [BlockGame] is immutable and knows only the rules; this holds
/// the current one and the things that exist for exactly as long as a finger
/// is down — which piece is being carried, where it would land, and what that
/// would clear.
///
/// There is no undo, by choice. A placement writes several cells and can take
/// two whole lines with it, so it is not something a player could reverse by
/// hand — but being able to reverse it is the game. Dropping a piece badly and
/// living with it is most of what a score means here.
class BlockBlastGame extends ChangeNotifier {
  /// Plays [state], which is either a new game or one restored from a save.
  BlockBlastGame(this._state);

  BlockGame _state;
  int? _carrying;
  Coord? _anchor;
  Set<Coord> _wouldFill = const <Coord>{};
  Set<Coord> _wouldClear = const <Coord>{};
  Set<Coord> _clearing = const <Coord>{};
  Set<Coord> _landed = const <Coord>{};
  int _clearTick = 0;
  int _lastPoints = 0;
  int _lastLines = 0;
  HandPlan? _hint;

  /// The game as the engine sees it.
  BlockGame get state => _state;

  /// Points so far.
  int get score => _state.score;

  /// Whether nothing in the hand fits any longer.
  bool get isOver => _state.isOver;

  /// Which slot of the hand is being carried, or `null` when nothing is.
  int? get carrying => _carrying;

  /// Where the carried piece would land, or `null` when it would not.
  Coord? get anchor => _anchor;

  /// The cells the carried piece would fill. Empty unless it would land.
  Set<Coord> get wouldFill => _wouldFill;

  /// The cells that would go out if the carried piece were dropped now.
  ///
  /// Shown while dragging, which is the difference between stumbling into a
  /// double and going looking for one.
  Set<Coord> get wouldClear => _wouldClear;

  /// The cells on their way out from the last placement.
  Set<Coord> get clearing => _clearing;

  /// Where the last placed piece landed.
  Set<Coord> get landed => _landed;

  /// Counts placements that cleared something, so the board can tell a fresh
  /// clear from an ordinary rebuild.
  ///
  /// [clearing] alone is not enough: clearing the same row twice running would
  /// produce an equal set and the animation would not replay.
  int get clearTick => _clearTick;

  /// What the last placement scored.
  int get lastPoints => _lastPoints;

  /// How many lines the last placement took out.
  int get lastLines => _lastLines;

  /// The plan being shown, or `null` when no hint is up.
  HandPlan? get hint => _hint;

  /// The shown plan as something the board can draw.
  ///
  /// Later steps are worked out against the board as it will be by then, so a
  /// step can land on squares that are filled now and will have been cleared
  /// by the step before it. That is the plan being worth asking for rather
  /// than a mistake, and the numbering is what makes it readable.
  List<HintStep> get hintSteps {
    final plan = _hint;
    if (plan == null) return const <HintStep>[];
    return <HintStep>[
      for (var step = 0; step < plan.moves.length; step++)
        if (_state.hand[plan.moves[step].handIndex] case final BlockPiece piece)
          HintStep(
            cells: piece.shape.at(plan.moves[step].anchor).toSet(),
            paint: piece.paint,
            order: step + 1,
          ),
    ];
  }

  /// Works out the best way to play the rest of the hand and shows it.
  ///
  /// Says whether there was anything to show: on a board with nowhere left to
  /// put anything there is no plan, and the screen should say so rather than
  /// appear to have ignored the button.
  bool requestHint() {
    _hint = HandPlanner.bestFor(_state);
    notifyListeners();
    return _hint != null;
  }

  /// Takes the hint back down.
  void clearHint() {
    if (_hint == null) return;
    _hint = null;
    notifyListeners();
  }

  /// The piece in [index], or `null` when that slot has been played.
  BlockPiece? pieceAt(int index) => _state.hand[index];

  /// Whether the piece in [index] still fits somewhere.
  ///
  /// A piece that does not is drawn spent: on a crowded board, knowing which
  /// of the three is already useless is most of the decision.
  bool fitsSomewhere(int index) {
    final piece = _state.hand[index];
    return piece != null && _state.board.fitsAnywhere(piece.shape);
  }

  /// Picks up the piece in [index].
  void startDrag(int index) {
    if (_carrying == index) return;
    _carrying = index;
    // The player is acting on it, or ignoring it. Either way it has done its
    // job and would only be in the way of the piece now being carried.
    _hint = null;
    _clearPreview();
    notifyListeners();
  }

  /// Moves the carried piece so its top-left corner sits at [anchor].
  ///
  /// A `null` [anchor], or one the piece cannot occupy, leaves the preview
  /// empty rather than showing a landing that will not happen.
  void updateDrag(Coord? anchor) {
    final index = _carrying;
    if (index == null) return;
    if (anchor == null || !_state.canPlace(index, anchor)) {
      if (_anchor == null && _wouldFill.isEmpty) return;
      _clearPreview();
      notifyListeners();
      return;
    }
    if (_anchor == anchor) return;
    final piece = _state.hand[index]!;
    _anchor = anchor;
    _wouldFill = piece.shape.at(anchor).toSet();
    _wouldClear = _state.board
        .withShape(piece.shape, anchor, piece.paint)
        .clearFullLines()
        .cells;
    notifyListeners();
  }

  /// Puts the carried piece down where the preview says it would go.
  ///
  /// Does nothing when there is no legal landing, which is how a drag that
  /// ends over the tray or off the board is undone: the piece goes back.
  void drop() {
    final index = _carrying;
    final anchor = _anchor;
    if (index == null || anchor == null) {
      endDrag();
      return;
    }
    final result = _state.place(index, anchor);
    _carrying = null;
    _clearPreview();
    if (result is! PlacementAccepted) {
      notifyListeners();
      return;
    }
    _state = result.game;
    _hint = null;
    _landed = result.filled;
    _lastPoints = result.points;
    _lastLines = result.clear.lineCount;
    if (result.clear.isEmpty) {
      _clearing = const <Coord>{};
    } else {
      _clearing = result.clear.cells;
      _clearTick++;
    }
    notifyListeners();
  }

  /// Abandons the drag without placing anything.
  void endDrag() {
    if (_carrying == null && _anchor == null) return;
    _carrying = null;
    _clearPreview();
    notifyListeners();
  }

  /// Throws the game away and starts another from [seed].
  void restart(int seed) {
    _state = BlockGame.newGame(seed);
    _carrying = null;
    _hint = null;
    _landed = const <Coord>{};
    _clearing = const <Coord>{};
    _lastPoints = 0;
    _lastLines = 0;
    _clearPreview();
    notifyListeners();
  }

  void _clearPreview() {
    _anchor = null;
    _wouldFill = const <Coord>{};
    _wouldClear = const <Coord>{};
  }
}
