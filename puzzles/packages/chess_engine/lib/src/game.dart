import 'move.dart';
import 'notation.dart';
import 'outcome.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// How many times a position has to come round before the game is drawn.
const int repetitionLimit = 3;

/// A game of chess: every position it has been in, and every move that got it
/// there.
///
/// Immutable, like the other engines here: [play] and [undo] hand back a new
/// game. Keeping the whole history rather than only the current position is
/// not sentiment — two of the drawing rules are about the past, and taking a
/// move back is what a game between two people at one screen is going to need
/// most often.
///
/// There is no opponent in here and no clock. The game's job is to know the
/// rules; who is playing it — a second person, or the computer — is [ChessSave]
/// and the screen's business.
final class ChessGame {
  const ChessGame._(
    this._positions,
    this._moves,
    this._notation, {
    required this.startFen,
  });

  /// A game from the starting position.
  factory ChessGame.newGame() => ChessGame.fromPosition(Position.initial());

  /// A game beginning at [start], for tests and for anything that wants to
  /// set a board up rather than play into it.
  factory ChessGame.fromPosition(Position start) => ChessGame._(
        List<Position>.unmodifiable(<Position>[start]),
        const <Move>[],
        const <String>[],
        startFen: start.toFen(),
      );

  /// Restores a game previously written by [toJson].
  ///
  /// The moves are replayed rather than the positions restored: it is fewer
  /// bytes, and it means a save cannot describe a board that could not have
  /// been reached by playing.
  factory ChessGame.fromJson(Map<String, Object?> json) {
    final start = json['start'];
    final moves = json['moves'];
    if (start is! String || moves is! List<Object?>) {
      throw const FormatException('malformed chess save');
    }
    var game = ChessGame.fromPosition(Position.fromFen(start));
    for (final uci in moves) {
      if (uci is! String) throw const FormatException('malformed chess move');
      final move = parseUci(game.position, uci);
      if (move == null) {
        throw FormatException('illegal move in save', uci);
      }
      game = game.play(move);
    }
    return game;
  }

  final List<Position> _positions;
  final List<Move> _moves;
  final List<String> _notation;

  /// The position the game started from, as FEN.
  final String startFen;

  /// The position on the board now.
  Position get position => _positions.last;

  /// Whose turn it is.
  PieceColor get sideToMove => position.sideToMove;

  /// Every move played, in order.
  List<Move> get moves => _moves;

  /// Every move played, written the way a score sheet would.
  List<String> get notation => _notation;

  /// The move just played, or `null` at the start of the game.
  ///
  /// The board draws it: coming to a shared screen halfway through a
  /// conversation, the first thing either player needs is to see what just
  /// happened.
  Move? get lastMove => _moves.isEmpty ? null : _moves.last;

  /// Whether there is a move to take back.
  bool get canUndo => _moves.isNotEmpty;

  /// Whether the game has finished.
  bool get isOver => outcome != null;

  /// How the game finished, or `null` while it is still going.
  ///
  /// Repetition and the fifty-move rule are claims a player makes at the
  /// board, not things that happen on their own — but a claim nobody offers
  /// is a rule nobody can use, and a hot-seat game does not want a "claim a
  /// draw" button that sits unpressed for the entire game. So they are
  /// declared here, at threefold and at fifty, where the official automatic
  /// draws are fivefold and seventy-five.
  Outcome? get outcome {
    if (position.isCheckmate) {
      return Outcome(GameEnding.checkmate, winner: sideToMove.opponent);
    }
    if (position.isStalemate) return const Outcome(GameEnding.stalemate);
    if (position.hasInsufficientMaterial) {
      return const Outcome(GameEnding.insufficientMaterial);
    }
    if (position.halfmoveClock >= fiftyMoveLimit) {
      return const Outcome(GameEnding.fiftyMoveRule);
    }
    if (repetitionCount >= repetitionLimit) {
      return const Outcome(GameEnding.threefoldRepetition);
    }
    return null;
  }

  /// Every position the game has been in, as repetition keys.
  ///
  /// What the computer needs in order to know that a move it is considering
  /// would repeat. It builds the keys on demand rather than keeping them,
  /// because it is asked once per move rather than once per position looked
  /// at.
  Set<String> get seenPositions => <String>{
        for (final position in _positions) position.repetitionKey,
      };

  /// How many times the position now on the board has occurred.
  int get repetitionCount {
    final key = position.repetitionKey;
    return _positions
        .where((Position past) => past.repetitionKey == key)
        .length;
  }

  /// The pieces [color] has taken, heaviest first.
  ///
  /// Worked out from the moves rather than kept alongside them: a list that
  /// has to be maintained in step with the history is a list that will one
  /// day disagree with it, most likely just after an undo.
  List<PieceKind> capturedBy(PieceColor color) {
    final taken = <PieceKind>[
      for (var i = 0; i < _moves.length; i++)
        if (_positions[i].sideToMove == color && _moves[i].captured != null)
          _moves[i].captured!,
    ]..sort((PieceKind a, PieceKind b) => b.value.compareTo(a.value));
    return List<PieceKind>.unmodifiable(taken);
  }

  /// How far ahead [color] is on material, in pawns. Negative when behind.
  int materialLead(PieceColor color) {
    int total(PieceColor side) => capturedBy(side).fold(
          0,
          (int sum, PieceKind kind) => sum + kind.value,
        );
    return total(color) - total(color.opponent);
  }

  /// The game with [move] played.
  ///
  /// Throws when the move is not legal in the current position. The screen
  /// picks its moves out of [Position.legalMoves], so an illegal one arriving
  /// here is a bug rather than a player doing something unexpected — and
  /// swallowing it would leave the board and the game disagreeing about where
  /// the pieces are.
  ChessGame play(Move move) {
    if (!position.legalMoves.contains(move)) {
      throw ArgumentError.value(move, 'move', 'not legal in this position');
    }
    return ChessGame._(
      List<Position>.unmodifiable(<Position>[
        ..._positions,
        position.makeMove(move),
      ]),
      List<Move>.unmodifiable(<Move>[..._moves, move]),
      List<String>.unmodifiable(<String>[
        ..._notation,
        describeMove(position, move),
      ]),
      startFen: startFen,
    );
  }

  /// The game with the move from [from] to [to] played, or `null` when that
  /// is not a legal move.
  ///
  /// [promotion] says what a pawn reaching the far rank becomes; without it,
  /// a queen.
  ChessGame? playFrom(Square from, Square to, {PieceKind? promotion}) {
    final move = position.findMove(from, to, promotion: promotion);
    return move == null ? null : play(move);
  }

  /// The game with the last move taken back.
  ///
  /// Gives back this same game when there is nothing to undo, so a screen can
  /// wire a button to it without guarding first.
  ///
  /// One move, not two. Both players are at the same board: whoever just moved
  /// is the one asking, and taking back a pair would undo their opponent's
  /// move as well.
  ChessGame undo() {
    if (_moves.isEmpty) return this;
    return ChessGame._(
      List<Position>.unmodifiable(
        _positions.sublist(0, _positions.length - 1),
      ),
      List<Move>.unmodifiable(_moves.sublist(0, _moves.length - 1)),
      List<String>.unmodifiable(
        _notation.sublist(0, _notation.length - 1),
      ),
      startFen: startFen,
    );
  }

  /// The game as JSON: where it started, and every move since.
  ///
  /// Written into a [ChessSave] rather than stored on its own.
  Map<String, Object?> toJson() => <String, Object?>{
        'start': startFen,
        'moves': <String>[for (final move in _moves) move.uci],
      };
}
