import 'package:chess_engine/chess_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Position.fromFen', () {
    test('sets the men up', () {
      final start = Position.initial();
      expect(
        start.pieceAt(Square.parse('e1')),
        const ChessPiece(PieceColor.white, PieceKind.king),
      );
      expect(
        start.pieceAt(Square.parse('d8')),
        const ChessPiece(PieceColor.black, PieceKind.queen),
      );
      expect(start.pieceAt(Square.parse('e4')), isNull);
      expect(start.sideToMove, PieceColor.white);
      expect(start.enPassant, isNull);
      expect(start.halfmoveClock, 0);
      expect(start.fullmoveNumber, 1);
    });

    test('round trips a FEN', () {
      const fens = <String>[
        startingFen,
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
        'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
      ];
      for (final fen in fens) {
        expect(Position.fromFen(fen).toFen(), fen);
      }
    });

    test('reads castling rights', () {
      final some = Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1');
      expect(some.canCastleKingside(PieceColor.white), isTrue);
      expect(some.canCastleQueenside(PieceColor.white), isFalse);
      expect(some.canCastleKingside(PieceColor.black), isFalse);
      expect(some.canCastleQueenside(PieceColor.black), isTrue);
    });

    test('refuses nonsense', () {
      expect(() => Position.fromFen('what'), throwsFormatException);
      expect(
        () => Position.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1'),
        throwsFormatException,
      );
      expect(
        () => Position.fromFen('8/8/8/8/8/8/8/8 w - - 0 1'),
        throwsFormatException,
        reason: 'a board with no kings is not a position',
      );
      expect(
        () => Position.fromFen('4k3/8/8/8/8/8/8/4K3 x - - 0 1'),
        throwsFormatException,
      );
    });
  });

  group('isAttacked', () {
    test('sees a pawn attacking forwards for its own colour', () {
      // The king is parked in the corner so that everything this test asks
      // about is about the pawn.
      final position = Position.fromFen('4k3/8/8/8/8/4P3/8/K7 w - - 0 1');
      expect(position.isAttacked(Square.parse('d4'), by: PieceColor.white),
          isTrue);
      expect(position.isAttacked(Square.parse('f4'), by: PieceColor.white),
          isTrue);
      expect(position.isAttacked(Square.parse('e4'), by: PieceColor.white),
          isFalse, reason: 'a pawn does not attack the square ahead of it');
      expect(position.isAttacked(Square.parse('d3'), by: PieceColor.white),
          isFalse, reason: 'nor the ones beside it');
      expect(position.isAttacked(Square.parse('d2'), by: PieceColor.white),
          isFalse, reason: 'nor anything behind it');
    });

    test('stops a slider at the first piece in the way', () {
      final position =
          Position.fromFen('4k3/8/8/8/8/8/4P3/R3K2R w KQ - 0 1');
      expect(position.isAttacked(Square.parse('e2'), by: PieceColor.white),
          isTrue);
      expect(position.isAttacked(Square.parse('e4'), by: PieceColor.white),
          isFalse, reason: 'the pawn on e2 blocks the rank behind it');
      expect(position.isAttacked(Square.parse('a4'), by: PieceColor.white),
          isTrue);
    });

    test('finds check', () {
      final position =
          Position.fromFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
      expect(position.inCheck, isTrue);
      expect(position.isInCheck(PieceColor.black), isFalse);
    });
  });

  group('makeMove', () {
    test('moves the rook when the king castles', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final after =
          position.makeMove(position.findMove(Square.parse('e1'), Square.parse('g1'))!);
      expect(after.pieceAt(Square.parse('g1'))?.kind, PieceKind.king);
      expect(after.pieceAt(Square.parse('f1'))?.kind, PieceKind.rook);
      expect(after.pieceAt(Square.parse('h1')), isNull);
      expect(after.canCastleKingside(PieceColor.white), isFalse);
      expect(after.canCastleQueenside(PieceColor.white), isFalse,
          reason: 'the king has moved, so both rights are gone');
      expect(after.canCastleKingside(PieceColor.black), isTrue);
    });

    test('takes the passed pawn off the square beside the destination', () {
      final position = Position.fromFen(
        'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
      );
      final capture =
          position.findMove(Square.parse('e5'), Square.parse('f6'))!;
      expect(capture.kind, MoveKind.enPassant);
      expect(capture.captureSquare, Square.parse('f5'));
      final after = position.makeMove(capture);
      expect(after.pieceAt(Square.parse('f6'))?.kind, PieceKind.pawn);
      expect(after.pieceAt(Square.parse('f5')), isNull);
    });

    test('leaves an en passant square only after a double push', () {
      final start = Position.initial();
      final push = start.makeMove(
        start.findMove(Square.parse('e2'), Square.parse('e4'))!,
      );
      expect(push.enPassant, Square.parse('e3'));
      final reply =
          push.makeMove(push.findMove(Square.parse('b8'), Square.parse('c6'))!);
      expect(reply.enPassant, isNull);
    });

    test('drops the right when a rook is taken on its home square', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final grab =
          position.findMove(Square.parse('a1'), Square.parse('a8'))!;
      expect(grab.captured, PieceKind.rook);
      final after = position.makeMove(grab);
      expect(after.canCastleQueenside(PieceColor.black), isFalse);
      expect(after.canCastleKingside(PieceColor.black), isTrue);
    });

    test('keeps the clocks', () {
      var position = Position.fromFen('4k3/8/8/8/8/5N2/8/4K3 w - - 4 12');
      position = position
          .makeMove(position.findMove(Square.parse('f3'), Square.parse('d4'))!);
      expect(position.halfmoveClock, 5);
      expect(position.fullmoveNumber, 12, reason: 'White moved, so it stands');
      position = position
          .makeMove(position.findMove(Square.parse('e8'), Square.parse('d8'))!);
      expect(position.fullmoveNumber, 13);
    });

    test('resets the halfmove clock on a pawn move and on a capture', () {
      var position = Position.fromFen('4k3/8/8/8/8/5N2/P7/4K3 w - - 9 30');
      final pushed = position
          .makeMove(position.findMove(Square.parse('a2'), Square.parse('a3'))!);
      expect(pushed.halfmoveClock, 0);

      position = Position.fromFen('4k3/8/8/8/8/5n2/8/4K1N1 w - - 9 30');
      final took = position
          .makeMove(position.findMove(Square.parse('g1'), Square.parse('f3'))!);
      expect(took.halfmoveClock, 0);
    });
  });
}
