import 'dart:async';
import 'dart:math';

import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/foundation.dart';

import 'bot_runner.dart';

/// A pawn waiting to be told what it becomes.
///
/// The move cannot be played until the player has chosen, and the choice is
/// made in a dialog — so the half-made move has to live somewhere in the
/// meantime. It lives here rather than in the screen's state because the
/// board draws differently while it is pending: the pawn is still on its own
/// square and the destination is still lit.
typedef PendingPromotion = ({Square from, Square to});

/// One game of chess between two people at the same screen.
///
/// The engine's [ChessGame] is immutable and knows only the rules; this holds
/// the current one and the things that exist between a player's two taps —
/// which square is picked up, where it may go, and which pawn is waiting to
/// be promoted.
///
/// It also holds which way up the board is drawn, which is the one piece of
/// state that belongs to neither the rules nor a single move. Two players
/// sharing a phone will want to turn it around, and the game has no opinion
/// about that.
///
/// When the [opponent] is the computer, this is also what notices that it is
/// the computer's turn and goes and asks it. The engine does not know it is
/// playing anyone; it answers questions about positions.
class ChessMatch extends ChangeNotifier {
  /// Plays [game] against [opponent].
  ///
  /// [chooser] is how the computer's move is worked out, and exists to be
  /// replaced in tests with something that answers immediately: a widget test
  /// should not be waiting on a real search, and a real search would make it
  /// slow and its failures hard to read.
  ChessMatch(
    this._game, {
    this.opponent = const Opponent.twoPlayers(),
    this.chooser = chooseMoveOffThread,
    int? seed,
  }) : _seed = seed ?? Random().nextInt(1 << 31) {
    _considerComputerMove();
  }

  /// Who is playing the other side.
  final Opponent opponent;

  /// How the computer's move is worked out.
  final MoveChooser chooser;

  /// Fixes the computer's choice between moves it rates equally.
  ///
  /// Drawn once per match rather than fixed, so that two games at the same
  /// level are not the same game. A resumed match draws a new one — the seed
  /// is not worth a field in the save, and nobody can tell from the board
  /// that the coin was tossed again.
  final int _seed;

  ChessGame _game;
  Square? _selected;
  PendingPromotion? _promoting;
  bool _flipped = false;
  bool _thinking = false;

  /// Counts the times the game has been changed by something other than the
  /// computer's own move.
  ///
  /// A search that is already running cannot be called back, so a move that
  /// arrives for a board that has moved on — because the player took their
  /// move back while it was thinking — is dropped rather than played.
  int _generation = 0;

  /// The game as the engine sees it.
  ChessGame get game => _game;

  /// The position on the board.
  Position get position => _game.position;

  /// Whose turn it is.
  PieceColor get sideToMove => _game.sideToMove;

  /// How the game ended, or `null` while it is still going.
  Outcome? get outcome => _game.outcome;

  /// Whether the game is over.
  bool get isOver => _game.isOver;

  /// The move just played, which the board draws behind the pieces.
  Move? get lastMove => _game.lastMove;

  /// Whether there is a move to take back.
  bool get canUndo => _game.canUndo;

  /// The square a piece has been picked up from, or `null`.
  Square? get selected => _selected;

  /// The pawn waiting on a choice of piece, or `null`.
  PendingPromotion? get promoting => _promoting;

  /// Whether the board is drawn from Black's side.
  bool get flipped => _flipped;

  /// Whether the computer is working out its move.
  bool get isThinking => _thinking;

  /// Whether it is the computer's turn, so the player should be kept from
  /// moving the pieces.
  bool get computersTurn => !isOver && opponent.controls(sideToMove);

  /// Where the selected piece may go, and what it would do there.
  ///
  /// Split into quiet moves and captures because the board marks them
  /// differently — a dot on an empty square, a ring around an occupied one —
  /// and because a player deciding what to do wants to see the difference
  /// before committing to it, not after.
  Map<Square, bool> get targets {
    final from = _selected;
    if (from == null) return const <Square, bool>{};
    return <Square, bool>{
      for (final move in position.movesFrom(from)) move.to: move.isCapture,
    };
  }

  /// The square of a king in check, or `null` when neither is.
  Square? get checkedKing =>
      position.inCheck ? position.kingSquare(sideToMove) : null;

  /// Handles a tap on [square].
  ///
  /// One method rather than a select and a move: from the board's point of
  /// view every tap is the same event, and which of the two it turns out to
  /// be depends on what is already picked up. Splitting it would only move
  /// this decision into the widget.
  void tap(Square square) {
    if (isOver || _promoting != null || computersTurn) return;
    final from = _selected;
    final piece = position.pieceAt(square);

    if (from == square) {
      _selected = null;
      notifyListeners();
      return;
    }

    if (from != null) {
      if (position.isPromotion(from, square)) {
        _promoting = (from: from, to: square);
        notifyListeners();
        return;
      }
      final move = position.findMove(from, square);
      if (move != null) {
        _play(move);
        return;
      }
    }

    // Not a move: either the player is picking a different piece up, or they
    // have tapped an empty square and want to put down the one they had.
    _selected = piece != null && piece.color == sideToMove ? square : null;
    notifyListeners();
  }

  /// Finishes the pending promotion as [kind].
  void promote(PieceKind kind) {
    final pending = _promoting;
    if (pending == null) return;
    final move = position.findMove(
      pending.from,
      pending.to,
      promotion: kind,
    );
    _promoting = null;
    if (move == null) {
      notifyListeners();
      return;
    }
    _play(move);
  }

  /// Abandons the pending promotion, leaving the pawn where it was.
  void cancelPromotion() {
    if (_promoting == null) return;
    _promoting = null;
    notifyListeners();
  }

  /// Takes the last move back.
  ///
  /// Against another person that is one move: whoever has just moved is the
  /// one reaching for it, and the other is sitting right there to object.
  /// Against the computer it is two — your move and its reply — because
  /// taking back only the computer's answer would leave you having played a
  /// move you were trying to unplay.
  void undo() {
    if (!_game.canUndo) return;
    _generation++;
    _game = _game.undo();
    if (opponent.isComputer && _game.canUndo && computersTurn) {
      _game = _game.undo();
    }
    _selected = null;
    _promoting = null;
    notifyListeners();
    _considerComputerMove();
  }

  /// Throws the game away and sets the pieces up again.
  ///
  /// The opponent stays: someone who has just lost to the computer and wants
  /// another game wants another game against the computer.
  void restart() {
    _generation++;
    _game = ChessGame.newGame();
    _selected = null;
    _promoting = null;
    notifyListeners();
    _considerComputerMove();
  }

  /// Turns the board around.
  void flip() {
    _flipped = !_flipped;
    notifyListeners();
  }

  void _play(Move move) {
    _game = _game.play(move);
    _selected = null;
    notifyListeners();
    _considerComputerMove();
  }

  /// Asks the computer for a move, if it is its turn.
  ///
  /// Deliberately not awaited by its callers: the board carries on drawing
  /// while the search runs, and the move arrives as another notification when
  /// it is ready.
  void _considerComputerMove() {
    if (!computersTurn || _thinking) return;
    _thinking = true;
    notifyListeners();
    unawaited(_think(_generation));
  }

  Future<void> _think(int generation) async {
    Move? move;
    try {
      move = await chooser(
        _game.position,
        opponent.level!,
        _game.seenPositions,
        _seed + _game.moves.length,
      );
    } finally {
      _thinking = false;
    }
    // The board may have moved on while it was thinking, and a move worked
    // out for a position that is no longer on the board is not a move.
    if (generation != _generation || isDisposed) return;
    if (move == null || !computersTurn) {
      notifyListeners();
      return;
    }
    _game = _game.play(move);
    notifyListeners();
  }

  /// Whether this match has been thrown away.
  ///
  /// A search outlives the screen that started it, and notifying a disposed
  /// [ChangeNotifier] throws.
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}
