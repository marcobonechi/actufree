import 'package:chess_engine/chess_engine.dart';
import 'package:test/test.dart';

/// The bot at [level] thinking about [fen].
SearchResult? thinkAbout(
  String fen, {
  BotLevel level = BotLevel.medium,
  int seed = 1,
  Set<String> history = const <String>{},
}) =>
    ChessBot(level: level, seed: seed)
        .think(Position.fromFen(fen), history: history);

void main() {
  group('tactics', () {
    test('plays the mate in one', () {
      // Ra8 is mate: the black king is boxed in by its own pawns.
      final result = thinkAbout('6k1/5ppp/8/8/8/8/8/R3K2R w - - 0 1');
      expect(result!.move.uci, 'a1a8');
      expect(result.isMate, isTrue);
      expect(result.score, greaterThan(0));
    });

    test('finds a mate in two with the rooks', () {
      // The ladder: one rook cuts the seventh rank, the other mates on the
      // eighth.
      final result =
          thinkAbout('7k/8/8/8/8/8/8/RR2K3 w - - 0 1', level: BotLevel.hard);
      expect(result!.isMate, isTrue);
      expect(result.score, greaterThan(0));
      expect(result.depth, greaterThanOrEqualTo(3));
    });

    test('takes a free queen', () {
      final result = thinkAbout('4k3/8/8/3q4/4B3/8/8/4K3 w - - 0 1');
      expect(result!.move.uci, 'e4d5');
    });

    test('does not take a defended pawn with its queen', () {
      // Qxd7 wins a pawn and loses a queen to Rxd7. Seeing that is the whole
      // job of the quiescence search: at plain depth one this is a capture
      // that looks like a free pawn.
      final result = thinkAbout('3rk3/3p4/8/8/8/8/8/3QK3 w - - 0 1');
      expect(result!.move.uci, isNot('d1d7'));
    });

    test('prefers mate to winning material', () {
      // Either rook can take the queen on b1 and be a queen up. Ra8 mates
      // instead — in two, because the c1 rook is pinned along the first rank
      // and cannot be the one to do it.
      final result = thinkAbout(
        '6k1/5ppp/8/8/8/8/8/RqR1K3 w - - 0 1',
        level: BotLevel.hard,
      );
      expect(result!.isMate, isTrue);
      expect(result.move.uci, 'a1a8');
    });

    test('gets out of check rather than anything else', () {
      final result = thinkAbout('4k3/8/8/8/8/8/4r3/4K1R1 w - - 0 1');
      expect(
        <String>['e1d1', 'e1f1', 'e1e2'],
        contains(result!.move.uci),
      );
    });
  });

  group('the levels', () {
    test('each answer with a legal move from the starting position', () {
      final start = Position.initial();
      for (final level in BotLevel.values) {
        final result = ChessBot(level: level).think(start);
        expect(result, isNotNull, reason: level.label);
        expect(start.legalMoves, contains(result!.move), reason: level.label);
      }
    });

    test('stay inside the work they are allowed', () {
      for (final level in BotLevel.values) {
        final result = ChessBot(level: level)
            .think(Position.fromFen(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        ));
        expect(result!.nodes, lessThanOrEqualTo(level.maxNodes),
            reason: level.label);
        expect(result.depth, greaterThanOrEqualTo(1), reason: level.label);
      }
    });

    test('the harder ones look deeper than the easier ones', () {
      final start = Position.initial();
      final easy = ChessBot(level: BotLevel.easy).think(start)!;
      final hard = ChessBot(level: BotLevel.hard).think(start)!;
      expect(hard.depth, greaterThan(easy.depth));
      expect(hard.nodes, greaterThan(easy.nodes));
    });

    test('the hard one takes the best move it found, every time', () {
      const fen = '4k3/8/8/3q4/4B3/8/8/4K3 w - - 0 1';
      for (var seed = 0; seed < 5; seed++) {
        expect(
          thinkAbout(fen, level: BotLevel.hard, seed: seed)!.move.uci,
          'e4d5',
          reason: 'a free queen is not a matter of taste',
        );
      }
    });
  });

  group('being predictable', () {
    test('the same position and seed give the same move', () {
      const fen = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';
      for (final level in BotLevel.values) {
        final first = thinkAbout(fen, level: level, seed: 7)!.move.uci;
        final second = thinkAbout(fen, level: level, seed: 7)!.move.uci;
        expect(second, first, reason: level.label);
      }
    });

    test('there is nothing to think about once the game is over', () {
      // Black is mated.
      final mated = Position.fromFen(
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
      );
      expect(ChessBot(level: BotLevel.easy).think(mated), isNull);
    });
  });

  group('draws', () {
    test('a winning side avoids a position it has already been in', () {
      // White is a rook up with plenty of reasonable moves. Told that the
      // position after its first choice has been on the board before, it
      // picks something else rather than walking into the threefold.
      const fen = '4k3/pppp4/8/8/8/8/PPPP4/R3K3 w - - 0 1';
      final first = thinkAbout(fen, level: BotLevel.hard)!;
      final after =
          Position.fromFen(fen).makeMove(first.move).repetitionKey;
      final second = thinkAbout(
        fen,
        level: BotLevel.hard,
        history: <String>{after},
      )!;
      expect(second.move.uci, isNot(first.move.uci));
    });
  });

  group('a whole game', () {
    test('two bots play one out without ever breaking a rule', () {
      var game = ChessGame.newGame();
      final bots = <PieceColor, ChessBot>{
        PieceColor.white: ChessBot(level: BotLevel.easy, seed: 3),
        PieceColor.black: ChessBot(level: BotLevel.easy, seed: 9),
      };
      for (var ply = 0; ply < 80 && !game.isOver; ply++) {
        final result = bots[game.sideToMove]!.think(game.position);
        expect(result, isNotNull, reason: 'move $ply');
        // play() throws on anything not legal in the position, so reaching
        // the end of this loop is the assertion.
        game = game.play(result!.move);
      }
      expect(game.moves, isNotEmpty);
      expect(game.notation.length, game.moves.length);
    });
  });
}
