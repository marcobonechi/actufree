import 'package:chess_engine/chess_engine.dart';
import 'package:puzzle_store/puzzle_store.dart';
import 'package:test/test.dart';

/// Plays [line], given as UCI moves, from [game].
ChessGame playLine(ChessGame game, List<String> line) {
  var current = game;
  for (final uci in line) {
    final move = parseUci(current.position, uci);
    expect(move, isNotNull, reason: '$uci should be legal');
    current = current.play(move!);
  }
  return current;
}

/// The fool's mate: the shortest game there is.
const List<String> foolsMate = <String>['f2f3', 'e7e5', 'g2g4', 'd8h4'];

void main() {
  group('playing', () {
    test('keeps the moves and what they were called', () {
      final game = playLine(ChessGame.newGame(), foolsMate);
      expect(game.notation, <String>['f3', 'e5', 'g4', 'Qh4#']);
      expect(game.moves.map((Move move) => move.uci), foolsMate);
      expect(game.lastMove?.uci, 'd8h4');
      expect(game.sideToMove, PieceColor.white);
    });

    test('refuses a move that is not legal here', () {
      final game = ChessGame.newGame();
      final elsewhere = Position.fromFen('4k3/8/8/8/8/5N2/8/4K3 w - - 0 1');
      final foreign = elsewhere.legalMoves.first;
      expect(() => game.play(foreign), throwsArgumentError);
    });

    test('plays from a pair of squares, and says no to a pair that is not a '
        'move', () {
      final game = ChessGame.newGame();
      expect(
        game.playFrom(Square.parse('e2'), Square.parse('e4'))?.notation,
        <String>['e4'],
      );
      expect(game.playFrom(Square.parse('e2'), Square.parse('e5')), isNull);
    });

    test('leaves the game it was played from alone', () {
      final start = ChessGame.newGame();
      playLine(start, foolsMate);
      expect(start.moves, isEmpty);
      expect(start.position.toFen(), startingFen);
    });
  });

  group('undo', () {
    test('takes back one move, not the pair', () {
      final game = playLine(ChessGame.newGame(), <String>['e2e4', 'e7e5']);
      final back = game.undo();
      expect(back.notation, <String>['e4']);
      expect(back.sideToMove, PieceColor.black);
      expect(back.canUndo, isTrue);
      expect(back.undo().canUndo, isFalse);
    });

    test('is a no-op at the start rather than an error', () {
      final start = ChessGame.newGame();
      expect(start.canUndo, isFalse);
      expect(start.undo().position.toFen(), startingFen);
    });

    test('puts a captured piece back', () {
      final game = playLine(
        ChessGame.newGame(),
        <String>['e2e4', 'd7d5', 'e4d5'],
      );
      expect(game.capturedBy(PieceColor.white), <PieceKind>[PieceKind.pawn]);
      expect(game.undo().capturedBy(PieceColor.white), isEmpty);
      expect(
        game.undo().position.pieceAt(Square.parse('d5')),
        const ChessPiece(PieceColor.black, PieceKind.pawn),
      );
    });
  });

  group('outcome', () {
    test('is nothing while the game is going', () {
      expect(ChessGame.newGame().outcome, isNull);
      expect(ChessGame.newGame().isOver, isFalse);
    });

    test('names the winner of a mate', () {
      final game = playLine(ChessGame.newGame(), foolsMate);
      expect(game.isOver, isTrue);
      expect(
        game.outcome,
        const Outcome(GameEnding.checkmate, winner: PieceColor.black),
      );
      expect(game.outcome!.label, 'Checkmate — Black wins');
    });

    test('calls a stalemate a draw', () {
      // The king on h8 has nowhere to go and is not in check.
      final game = ChessGame.fromPosition(
        Position.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1'),
      );
      expect(game.outcome, const Outcome(GameEnding.stalemate));
      expect(game.outcome!.isDraw, isTrue);
      expect(game.outcome!.label, 'Draw — stalemate');
    });

    test('sees when there is not enough left to mate with', () {
      const drawn = <String>[
        '4k3/8/8/8/8/8/8/4K3 w - - 0 1',
        '4k3/8/8/8/8/8/8/4KB2 w - - 0 1',
        '4k3/8/8/8/8/8/8/4KN2 w - - 0 1',
        '4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1',
      ];
      for (final fen in drawn) {
        expect(
          ChessGame.fromPosition(Position.fromFen(fen)).outcome,
          const Outcome(GameEnding.insufficientMaterial),
          reason: fen,
        );
      }

      const playable = <String>[
        '4k3/8/8/8/8/8/7P/4K3 w - - 0 1',
        '4k3/8/8/8/8/8/8/4KNN1 w - - 0 1',
        '4kb2/8/8/8/8/8/8/3BK3 w - - 0 1',
        '4k3/8/8/8/8/8/8/4KR2 w - - 0 1',
      ];
      for (final fen in playable) {
        expect(
          ChessGame.fromPosition(Position.fromFen(fen)).outcome,
          isNull,
          reason: '$fen can still be won by someone',
        );
      }
    });

    test('draws on the fiftieth quiet move by each side', () {
      // One short of the limit, so a single shuffle reaches it.
      final game = ChessGame.fromPosition(
        // A knight each: enough on the board that the draw being tested is
        // the clock rather than the material.
        Position.fromFen('4k3/5n2/8/8/8/5N2/8/4K3 w - - 99 60'),
      );
      expect(game.outcome, isNull);
      final drawn = playLine(game, <String>['f3d4']);
      expect(drawn.position.halfmoveClock, fiftyMoveLimit);
      expect(drawn.outcome, const Outcome(GameEnding.fiftyMoveRule));
    });

    test('draws when the same position comes round a third time', () {
      // Both sides walk their knights out and back, twice.
      const shuffle = <String>[
        'g1f3', 'g8f6', 'f3g1', 'f6g8', //
        'g1f3', 'g8f6', 'f3g1', 'f6g8',
      ];
      var game = ChessGame.newGame();
      for (var i = 0; i < shuffle.length; i++) {
        expect(game.outcome, isNull, reason: 'not yet, after $i moves');
        game = playLine(game, <String>[shuffle[i]]);
      }
      expect(game.repetitionCount, repetitionLimit);
      expect(game.outcome, const Outcome(GameEnding.threefoldRepetition));
      expect(game.undo().outcome, isNull,
          reason: 'taking the last move back takes the draw back with it');
    });
  });

  group('material', () {
    test('counts what each side has taken, heaviest first', () {
      // 1. e4 d5 2. exd5 Qxd5 3. Nc3 Qxd2+ 4. Qxd2: White is a queen up on
      // the exchange and two pawns down.
      final game = playLine(
        ChessGame.newGame(),
        <String>['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5d2', 'd1d2'],
      );
      expect(game.capturedBy(PieceColor.white),
          <PieceKind>[PieceKind.queen, PieceKind.pawn]);
      expect(game.capturedBy(PieceColor.black),
          <PieceKind>[PieceKind.pawn, PieceKind.pawn]);
      expect(game.materialLead(PieceColor.white), 8);
      expect(game.materialLead(PieceColor.black), -8);
    });

    test('reports the lead from each side', () {
      final game =
          playLine(ChessGame.newGame(), <String>['e2e4', 'd7d5', 'e4d5']);
      expect(game.materialLead(PieceColor.white), 1);
      expect(game.materialLead(PieceColor.black), -1);
    });
  });

  group('saving', () {
    test('round trips through a store', () async {
      final store = GameStore(MemoryStore());
      final game = playLine(
        ChessGame.newGame(),
        <String>['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5'],
      );
      await store.save(ChessSave(game: game), slot: 'current');
      final loaded =
          await store.load('chess', ChessSave.fromJson, slot: 'current');
      expect(loaded, isNotNull);
      expect(loaded!.game.position.toFen(), game.position.toFen());
      expect(loaded.game.notation, game.notation);
      expect(loaded.game.canUndo, isTrue,
          reason: 'the history comes back with the game, so undo still works');
      expect(loaded.game.undo().position.toFen(), game.undo().position.toFen());
      expect(loaded.opponent, const Opponent.twoPlayers());
    });

    test('carries who was playing', () async {
      final store = GameStore(MemoryStore());
      const opponent = Opponent.computer(
        level: BotLevel.medium,
        plays: PieceColor.black,
      );
      await store.save(
        ChessSave(game: ChessGame.newGame(), opponent: opponent),
        slot: 'current',
      );
      final loaded =
          await store.load('chess', ChessSave.fromJson, slot: 'current');
      expect(loaded!.opponent, opponent);
      expect(loaded.opponent.human, PieceColor.white);
    });

    test('reads a save written before there was a computer', () {
      // No opponent field at all: the game between two people that it was.
      final restored = ChessSave.fromJson(<String, Object?>{
        'start': startingFen,
        'moves': <String>['e2e4'],
      });
      expect(restored.opponent, const Opponent.twoPlayers());
      expect(restored.game.notation, <String>['e4']);
    });

    test('writes the moves rather than the board', () {
      final game = playLine(ChessGame.newGame(), <String>['e2e4', 'e7e5']);
      expect(game.toJson(), <String, Object?>{
        'start': startingFen,
        'moves': <String>['e2e4', 'e7e5'],
      });
    });

    test('keeps a game that started from a set-up board', () {
      const fen = '4k3/1P6/8/8/8/8/8/4K3 w - - 0 1';
      final game = playLine(
        ChessGame.fromPosition(Position.fromFen(fen)),
        <String>['b7b8n'],
      );
      final restored = ChessGame.fromJson(game.toJson());
      expect(restored.startFen, fen);
      expect(restored.notation, <String>['b8=N']);
    });

    test('refuses a save it cannot replay', () {
      expect(
        () => ChessGame.fromJson(<String, Object?>{
          'start': startingFen,
          'moves': <String>['e2e5'],
        }),
        throwsFormatException,
      );
      expect(
        () => ChessGame.fromJson(<String, Object?>{'moves': <String>[]}),
        throwsFormatException,
      );
    });

    test('a store hands back nothing rather than throwing on a bad save',
        () async {
      // The contract the store makes: a record it cannot read costs the
      // player one game, not the app.
      final storage = MemoryStore();
      final store = GameStore(storage);
      await store.save(ChessSave(game: ChessGame.newGame()), slot: 'current');
      await storage.write(
        GameStore.keyFor('chess', 'current'),
        '{"version":1,"gameId":"chess","slot":"current",'
            '"state":{"start":"$startingFen","moves":["e2e5"]}}',
      );
      expect(
        await store.load('chess', ChessSave.fromJson, slot: 'current'),
        isNull,
      );
    });
  });
}
