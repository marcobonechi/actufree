import 'package:puzzle_store/puzzle_store.dart';

import 'board.dart';
import 'coord.dart';
import 'dealer.dart';
import 'piece.dart';
import 'placement.dart';
import 'score.dart';

/// A game of Block Blast: the board, the hand and the score.
///
/// Immutable. [place] hands back a new game rather than changing this one, so
/// a state can be held on to, compared or written out without any risk of it
/// moving underneath.
///
/// This implements [SavedGame] directly, where Sudoku has a separate
/// `SudokuSave`. Sudoku needs the wrapper because a game in progress is a
/// puzzle *and* a board; here the game already is the entire state, and a
/// wrapper holding one field would be ceremony.
final class BlockGame implements SavedGame {
  const BlockGame._({
    required this.board,
    required this.hand,
    required this.score,
    required this.seed,
  });

  /// Starts a game from [seed], which fixes every deal that follows.
  ///
  /// The same seed always plays out the same way given the same moves, so a
  /// run worth complaining about can be handed back verbatim.
  factory BlockGame.newGame(int seed) {
    final deal = Dealer.deal(BlockBoard.empty(), seed);
    return BlockGame._(
      board: BlockBoard.empty(),
      hand: List<BlockPiece?>.unmodifiable(deal.pieces),
      score: 0,
      seed: deal.nextSeed,
    );
  }

  /// Restores a game previously written by [toJson].
  factory BlockGame.fromJson(Map<String, Object?> json) {
    final board = json['board'];
    final hand = json['hand'];
    final score = json['score'];
    final seed = json['seed'];
    if (board is! List<Object?> ||
        hand is! List<Object?> ||
        hand.length != handSize ||
        score is! int ||
        seed is! int) {
      throw const FormatException('malformed block blast save');
    }
    return BlockGame._(
      board: BlockBoard.fromJson(board),
      hand: List<BlockPiece?>.unmodifiable(<BlockPiece?>[
        for (final piece in hand)
          if (piece == null)
            null
          else if (piece is Map<String, Object?>)
            BlockPiece.fromJson(piece)
          else
            throw const FormatException('malformed piece in hand'),
      ]),
      score: score,
      seed: seed,
    );
  }

  /// The board as it stands.
  final BlockBoard board;

  /// The pieces on offer, [handSize] slots with `null` where one has been
  /// played.
  final List<BlockPiece?> hand;

  /// Points so far.
  final int score;

  /// The seed the next deal will use.
  final int seed;

  /// The pieces still to be played.
  Iterable<BlockPiece> get remaining => hand.whereType<BlockPiece>();

  /// Whether nothing left in the hand fits anywhere: the game is over.
  bool get isOver =>
      !remaining.any((BlockPiece piece) => board.fitsAnywhere(piece.shape));

  /// Whether the piece in [handIndex] can be dropped with its top-left corner
  /// at [anchor].
  ///
  /// The cheap question the drag preview asks on every frame, which is why it
  /// does not go the whole way through [place].
  bool canPlace(int handIndex, Coord anchor) {
    final piece = _pieceAt(handIndex);
    return piece != null && board.fits(piece.shape, anchor);
  }

  /// Drops the piece in [handIndex] with its top-left corner at [anchor].
  ///
  /// Clears any lines it completed, scores it, and deals a new hand when it
  /// was the last piece.
  PlacementResult place(int handIndex, Coord anchor) {
    final piece = _pieceAt(handIndex);
    if (piece == null) {
      return const PlacementRejected(PlacementRejection.noPieceThere);
    }
    if (!board.fits(piece.shape, anchor)) {
      return const PlacementRejected(PlacementRejection.doesNotFit);
    }
    final filled = piece.shape.at(anchor).toSet();
    final clear =
        board.withShape(piece.shape, anchor, piece.paint).clearFullLines();
    final played = List<BlockPiece?>.of(hand)..[handIndex] = null;
    final points = Scoring.forPlacement(
      cells: piece.shape.size,
      lines: clear.lineCount,
    );

    // The new hand is dealt against the board *after* the clear, so the
    // fairness guarantee is made about the board the player will actually be
    // looking at rather than the crowded one that existed mid-move.
    final emptyHanded = played.every((BlockPiece? slot) => slot == null);
    final deal = emptyHanded ? Dealer.deal(clear.board, seed) : null;

    return PlacementAccepted(
      game: BlockGame._(
        board: clear.board,
        hand: List<BlockPiece?>.unmodifiable(deal?.pieces ?? played),
        score: score + points,
        seed: deal?.nextSeed ?? seed,
      ),
      filled: filled,
      clear: clear,
      points: points,
      dealt: deal != null,
    );
  }

  @override
  String get gameId => 'blockblast';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'board': board.toJson(),
        'hand': <Object?>[
          for (final piece in hand) piece?.toJson(),
        ],
        'score': score,
        'seed': seed,
      };

  BlockPiece? _pieceAt(int handIndex) =>
      handIndex < 0 || handIndex >= hand.length ? null : hand[handIndex];
}
