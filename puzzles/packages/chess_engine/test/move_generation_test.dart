import 'package:chess_engine/chess_engine.dart';
import 'package:test/test.dart';

/// Counts the leaves of the move tree [depth] plies below [position].
int perft(Position position, int depth) {
  if (depth == 0) return 1;
  if (depth == 1) return position.legalMoves.length;
  var nodes = 0;
  for (final move in position.legalMoves) {
    nodes += perft(position.makeMove(move), depth - 1);
  }
  return nodes;
}

void main() {
  group('perft', () {
    // Perft counts every position a given number of moves deep. It is worth
    // the odd shape of a test that checks one number: a generator that gets
    // castling through check right and en passant wrong produces the correct
    // count nowhere, and these counts are published, so a mismatch is a bug
    // here rather than a disagreement about the rules.
    //
    // The positions are the standard ones from the Chess Programming Wiki,
    // each chosen to break a different piece of a generator: the second is
    // dense with castling and pins, the third with promotions and en passant
    // along a rank, the fourth with a pinned promotion.
    //
    // The depths are as far as a test can go and still be quick. `dart run
    // tool/measure_perft.dart` goes deeper — the starting position matches at
    // depth five and Kiwipete at depth four, which is several million
    // positions each and not something to run on every save.
    const cases = <String, Map<String, List<int>>>{
      'the starting position': <String, List<int>>{
        startingFen: <int>[20, 400, 8902, 197281],
        // 4865609 at depth five, from the tool.
      },
      'Kiwipete': <String, List<int>>{
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1':
            <int>[48, 2039, 97862],
      },
      'a rook endgame with en passant': <String, List<int>>{
        '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1': <int>[14, 191, 2812, 43238],
      },
      'a position with a pinned promotion': <String, List<int>>{
        'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1':
            <int>[6, 264, 9467],
      },
      'a cramped middlegame': <String, List<int>>{
        'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8':
            <int>[44, 1486, 62379],
      },
    };

    cases.forEach((String name, Map<String, List<int>> byFen) {
      byFen.forEach((String fen, List<int> expected) {
        test('counts the moves below $name', () {
          final position = Position.fromFen(fen);
          for (var depth = 1; depth <= expected.length; depth++) {
            expect(
              perft(position, depth),
              expected[depth - 1],
              reason: 'depth $depth of $fen',
            );
          }
        });
      });
    });
  });

  group('castling', () {
    test('is offered when the way is clear', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final king = position.movesFrom(Square.parse('e1'));
      expect(
        king.where((Move move) => move.kind.isCastle).map((Move m) => m.to.name),
        containsAll(<String>['g1', 'c1']),
      );
    });

    test('is refused out of check, through check and into check', () {
      // A rook on e8 stares down the e-file at the king: it cannot castle out
      // of the check. The black king stands in the corner in each of these,
      // out of the way of what is being asked.
      final outOf = Position.fromFen('4r2k/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      expect(_castles(outOf), isEmpty);

      // A rook on f8 covers f1, the square the king would pass over.
      final through = Position.fromFen('5r1k/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      expect(_castles(through), <String>['c1']);

      // A rook on g8 covers the square the king would land on.
      final into = Position.fromFen('k5r1/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      expect(_castles(into), <String>['c1']);
    });

    test('is refused when anything stands between king and rook', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3KB1R w KQkq - 0 1');
      expect(_castles(position), <String>['c1']);
    });

    test('lets the queenside king pass over an attacked b-file square', () {
      // b1 is attacked, but the king never stands on it — only the rook
      // crosses it, and rooks are not checked on the way.
      final position = Position.fromFen('1r5k/8/8/8/8/8/8/R3K3 w Q - 0 1');
      expect(_castles(position), <String>['c1']);
    });

    test('is gone once the right is', () {
      final position = Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1');
      expect(_castles(position), isEmpty);
    });
  });

  group('pawns', () {
    test('promote four ways', () {
      final position = Position.fromFen('4k3/P7/8/8/8/8/8/4K3 w - - 0 1');
      final promotions = position.movesFrom(Square.parse('a7'));
      expect(promotions, hasLength(4));
      expect(
        promotions.map((Move move) => move.promotion),
        containsAll(PieceKind.promotions),
      );
      expect(position.isPromotion(Square.parse('a7'), Square.parse('a8')),
          isTrue);
      expect(
        position.findMove(Square.parse('a7'), Square.parse('a8'))?.promotion,
        PieceKind.queen,
        reason: 'asking without saying what to promote to gets a queen',
      );
    });

    test('can only take en passant on the move after the push', () {
      var position = Position.fromFen(
        'rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 3',
      );
      expect(
        position.findMove(Square.parse('d4'), Square.parse('e3'))?.kind,
        MoveKind.enPassant,
      );

      // A quiet move by each side and the chance is gone.
      position = position
          .makeMove(position.findMove(Square.parse('b8'), Square.parse('c6'))!);
      position = position
          .makeMove(position.findMove(Square.parse('b1'), Square.parse('c3'))!);
      expect(position.enPassant, isNull);
      expect(position.findMove(Square.parse('d4'), Square.parse('e3')), isNull);
    });

    test('may not push through a piece', () {
      final position = Position.fromFen('4k3/8/8/8/8/4n3/4P3/4K3 w - - 0 1');
      expect(position.movesFrom(Square.parse('e2')), isEmpty);
    });

    test('may not take straight ahead', () {
      final position = Position.fromFen('4k3/8/8/8/8/4r3/4P3/4K3 w - - 0 1');
      expect(
        position.movesFrom(Square.parse('e2')).map((Move move) => move.to.name),
        isEmpty,
      );
    });
  });

  group('legality', () {
    test('a pinned piece stays where it is', () {
      // The knight on e2 is the only thing between the king and a rook.
      final position = Position.fromFen('4k3/8/8/8/4r3/8/4N3/4K3 w - - 0 1');
      expect(position.movesFrom(Square.parse('e2')), isEmpty);
    });

    test('a pinned piece may still take the pinner', () {
      // The bishop on f2 is pinned along the diagonal by the one on g3, which
      // leaves it exactly one move.
      final position = Position.fromFen('4k3/8/8/8/8/6b1/5B2/4K3 w - - 0 1');
      expect(
        position.movesFrom(Square.parse('f2')).map((Move move) => move.to.name),
        <String>['g3'],
      );
    });

    test('a king may not step onto an attacked square', () {
      // The queen on f2 has the king in check and is defended by the rook on
      // f8, so taking it is not the way out. Every other square but d1 is
      // covered by the queen.
      final position = Position.fromFen('4kr2/8/8/8/8/8/5q2/4K3 w - - 0 1');
      expect(
        position.legalMoves.map((Move move) => move.uci).toSet(),
        <String>{'e1d1'},
      );
    });

    test('in check, only moves that answer it are offered', () {
      final position =
          Position.fromFen('4k3/8/8/8/8/8/4r3/4K1R1 w - - 0 1');
      expect(
        position.legalMoves.map((Move move) => move.uci).toSet(),
        <String>{'e1d1', 'e1f1', 'e1e2'},
        reason: 'the checking rook is beside the king, so there is nothing to '
            'block with: the king steps aside or takes it',
      );
    });
  });
}

List<String> _castles(Position position) => position.legalMoves
    .where((Move move) => move.kind.isCastle)
    .map((Move move) => move.to.name)
    .toList();
