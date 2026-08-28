import 'dart:async';

import 'package:chess_engine/chess_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles_app/chess/chess_match.dart';

/// A match on the position [fen] describes.
ChessMatch matchOn(String fen) =>
    ChessMatch(ChessGame.fromPosition(Position.fromFen(fen)));

/// A stand-in for the computer that plays the first legal move at once.
///
/// Every test below is about what the match does with a move, not about which
/// move a search would pick — and a real search in a widget test would be slow
/// and would tie these tests to how the bot happens to play.
Future<Move?> firstLegalMove(
  Position position,
  BotLevel level,
  Set<String> history,
  int seed,
) async =>
    position.legalMoves.isEmpty ? null : position.legalMoves.first;

/// A stand-in that answers only when told to.
class HeldMove {
  Completer<Move?> _completer = Completer<Move?>();
  Position? asked;

  Future<Move?> choose(
    Position position,
    BotLevel level,
    Set<String> history,
    int seed,
  ) {
    asked = position;
    return _completer.future;
  }

  /// Answers the outstanding request with the first legal move.
  void answer() {
    final position = asked!;
    _completer.complete(position.legalMoves.first);
    _completer = Completer<Move?>();
  }
}

const Opponent playsBlack = Opponent.computer(
  level: BotLevel.easy,
  plays: PieceColor.black,
);

/// Taps each of [squares] in turn.
void tapAll(ChessMatch match, List<String> squares) {
  for (final square in squares) {
    match.tap(Square.parse(square));
  }
}

void main() {
  group('picking a piece up', () {
    test('takes a piece belonging to the side to move', () {
      final match = ChessMatch(ChessGame.newGame());
      match.tap(Square.parse('e2'));
      expect(match.selected, Square.parse('e2'));
      expect(match.targets.keys.map((Square s) => s.name),
          containsAll(<String>['e3', 'e4']));
    });

    test('ignores the other side and empty squares', () {
      final match = ChessMatch(ChessGame.newGame());
      match.tap(Square.parse('e7'));
      expect(match.selected, isNull);
      match.tap(Square.parse('e4'));
      expect(match.selected, isNull);
    });

    test('is put back down by tapping it again', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['g1', 'g1']);
      expect(match.selected, isNull);
      expect(match.targets, isEmpty);
    });

    test('swaps to another piece rather than refusing', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['g1', 'b1']);
      expect(match.selected, Square.parse('b1'));
    });

    test('is dropped by tapping a square it cannot reach', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['g1', 'a5']);
      expect(match.selected, isNull);
    });

    test('marks which of its moves are captures', () {
      // A white knight on e4 with a black pawn on d6 and empty squares
      // elsewhere.
      final match = matchOn('4k3/8/3p4/8/4N3/8/8/4K3 w - - 0 1');
      match.tap(Square.parse('e4'));
      expect(match.targets[Square.parse('d6')], isTrue);
      expect(match.targets[Square.parse('f6')], isFalse);
    });
  });

  group('moving', () {
    test('plays the move and hands the turn over', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['e2', 'e4']);
      expect(match.game.notation, <String>['e4']);
      expect(match.sideToMove, PieceColor.black);
      expect(match.selected, isNull);
      expect(match.lastMove?.uci, 'e2e4');
    });

    test('notifies once per tap that changes anything', () {
      final match = ChessMatch(ChessGame.newGame());
      var notices = 0;
      match.addListener(() => notices++);
      tapAll(match, <String>['e2', 'e4']);
      expect(notices, 2);
    });

    test('does nothing once the game is over', () {
      // Black is mated: the fool's mate, one move in the past.
      final match = matchOn(
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
      );
      expect(match.isOver, isTrue);
      tapAll(match, <String>['e1', 'f2']);
      expect(match.selected, isNull);
      expect(match.game.moves, isEmpty);
    });

    test('reports the king in check', () {
      final match = matchOn('4k3/8/8/8/8/8/4r3/4K3 w - - 0 1');
      expect(match.checkedKing, Square.parse('e1'));
      final quiet = matchOn('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
      expect(quiet.checkedKing, isNull);
    });
  });

  group('promotion', () {
    test('waits for a piece to be chosen', () {
      final match = matchOn('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      tapAll(match, <String>['b7', 'b8']);
      expect(match.promoting, (from: Square.parse('b7'), to: Square.parse('b8')));
      expect(match.game.moves, isEmpty, reason: 'nothing is played yet');
      expect(match.position.pieceAt(Square.parse('b7'))?.kind, PieceKind.pawn);
    });

    test('ignores taps while it is waiting', () {
      final match = matchOn('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      tapAll(match, <String>['b7', 'b8', 'e1', 'e2']);
      expect(match.promoting, isNotNull);
      expect(match.game.moves, isEmpty);
    });

    test('plays the move once told what the pawn becomes', () {
      final match = matchOn('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      tapAll(match, <String>['b7', 'b8']);
      match.promote(PieceKind.knight);
      expect(match.promoting, isNull);
      expect(match.game.notation, <String>['b8=N']);
      expect(match.position.pieceAt(Square.parse('b8'))?.kind, PieceKind.knight);
    });

    test('leaves the pawn where it was when the choice is abandoned', () {
      final match = matchOn('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      tapAll(match, <String>['b7', 'b8']);
      match.cancelPromotion();
      expect(match.promoting, isNull);
      expect(match.game.moves, isEmpty);
      expect(match.position.pieceAt(Square.parse('b7'))?.kind, PieceKind.pawn);
    });
  });

  group('the board itself', () {
    test('takes a move back and lets go of the selection', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['e2', 'e4', 'e7']);
      match.undo();
      expect(match.game.moves, isEmpty);
      expect(match.sideToMove, PieceColor.white);
      expect(match.selected, isNull);
    });

    test('undo does nothing at the start', () {
      final match = ChessMatch(ChessGame.newGame());
      match.undo();
      expect(match.position.toFen(), startingFen);
    });

    test('sets the pieces up again', () {
      final match = ChessMatch(ChessGame.newGame());
      tapAll(match, <String>['e2', 'e4']);
      match.restart();
      expect(match.position.toFen(), startingFen);
      expect(match.canUndo, isFalse);
    });

    test('turns around', () {
      final match = ChessMatch(ChessGame.newGame());
      expect(match.flipped, isFalse);
      match.flip();
      expect(match.flipped, isTrue);
    });
  });

  computerTests();
}

void computerTests() {
  group('against the computer', () {
    test('replies once the player has moved', () async {
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: playsBlack,
        chooser: firstLegalMove,
      );
      tapAll(match, <String>['e2', 'e4']);
      await pumpEventQueue();

      expect(match.game.moves, hasLength(2));
      expect(match.sideToMove, PieceColor.white);
      expect(match.isThinking, isFalse);
    });

    test('moves first when it has White', () async {
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: const Opponent.computer(
          level: BotLevel.easy,
          plays: PieceColor.white,
        ),
        chooser: firstLegalMove,
      );
      await pumpEventQueue();

      expect(match.game.moves, hasLength(1));
      expect(match.sideToMove, PieceColor.black);
    });

    test('says when it is thinking, and ignores taps while it does', () async {
      final held = HeldMove();
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: playsBlack,
        chooser: held.choose,
      );
      tapAll(match, <String>['e2', 'e4']);
      await pumpEventQueue();

      expect(match.isThinking, isTrue);
      expect(match.computersTurn, isTrue);
      tapAll(match, <String>['d7', 'd5']);
      expect(match.selected, isNull, reason: 'not the player to move');
      expect(match.game.moves, hasLength(1));

      held.answer();
      await pumpEventQueue();
      expect(match.isThinking, isFalse);
      expect(match.game.moves, hasLength(2));
    });

    test('takes back the pair, so it is the player to move again', () async {
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: playsBlack,
        chooser: firstLegalMove,
      );
      tapAll(match, <String>['e2', 'e4']);
      await pumpEventQueue();
      expect(match.game.moves, hasLength(2));

      match.undo();
      await pumpEventQueue();
      expect(match.game.moves, isEmpty);
      expect(match.sideToMove, PieceColor.white);
    });

    test('drops a move worked out for a board that has moved on', () async {
      final held = HeldMove();
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: playsBlack,
        chooser: held.choose,
      );
      tapAll(match, <String>['e2', 'e4']);
      await pumpEventQueue();
      expect(match.isThinking, isTrue);

      // The player takes their move back while it is still thinking. The
      // answer, when it arrives, is about a position that is no longer on the
      // board.
      match.undo();
      held.answer();
      await pumpEventQueue();

      expect(match.game.moves, isEmpty);
      expect(match.sideToMove, PieceColor.white);
    });

    test('keeps the opponent when the pieces are set up again', () async {
      final match = ChessMatch(
        ChessGame.newGame(),
        opponent: playsBlack,
        chooser: firstLegalMove,
      );
      tapAll(match, <String>['e2', 'e4']);
      await pumpEventQueue();

      match.restart();
      await pumpEventQueue();
      expect(match.opponent, playsBlack);
      expect(match.game.moves, isEmpty, reason: 'it is the player to move');
    });

    test('has nothing to say once the game is over', () async {
      // Black is mated, and it is the computer that is mated.
      final match = ChessMatch(
        ChessGame.fromPosition(Position.fromFen(
          'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
        )),
        opponent: playsBlack,
        chooser: firstLegalMove,
      );
      await pumpEventQueue();
      expect(match.isThinking, isFalse);
      expect(match.game.moves, isEmpty);
    });
  });
}
