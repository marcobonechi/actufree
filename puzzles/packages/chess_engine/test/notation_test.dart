import 'package:chess_engine/chess_engine.dart';
import 'package:test/test.dart';

/// Plays [uci] moves in turn from [position] and gives back what each was
/// called on the way past.
List<String> describeLine(Position position, List<String> line) {
  final written = <String>[];
  var current = position;
  for (final uci in line) {
    final move = parseUci(current, uci);
    expect(move, isNotNull, reason: '$uci should be legal in $current');
    written.add(describeMove(current, move!));
    current = current.makeMove(move);
  }
  return written;
}

void main() {
  group('describeMove', () {
    test('names a pawn move by where it lands', () {
      expect(
        describeLine(Position.initial(), <String>['e2e4', 'e7e5', 'g1f3']),
        <String>['e4', 'e5', 'Nf3'],
      );
    });

    test('names a pawn capture by the file it left', () {
      expect(
        describeLine(
          Position.initial(),
          <String>['e2e4', 'd7d5', 'e4d5'],
        ),
        <String>['e4', 'd5', 'exd5'],
      );
    });

    test('writes castling with the rook to the right of it', () {
      final position =
          Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(
        describeLine(position, <String>['e1g1', 'e8c8']),
        <String>['O-O', 'O-O-O'],
      );
    });

    test('writes what a pawn promoted to, and the check it gave', () {
      final position = Position.fromFen('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      expect(describeLine(position, <String>['b7b8q']), <String>['b8=Q+']);
      expect(describeLine(position, <String>['b7b8n']), <String>['b8=N']);
    });

    test('marks check and mate', () {
      // The fool's mate, which is the shortest way to get a # into a test.
      expect(
        describeLine(
          Position.initial(),
          <String>['f2f3', 'e7e5', 'g2g4', 'd8h4'],
        ),
        <String>['f3', 'e5', 'g4', 'Qh4#'],
      );
    });

    test('says only as much of the starting square as it has to', () {
      // Two knights reach d2, and they are on different files.
      final knights = Position.fromFen('4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1');
      expect(describeLine(knights, <String>['b1d2']), <String>['Nbd2']);
      expect(describeLine(knights, <String>['f3d2']), <String>['Nfd2']);

      // Two rooks reach a3 and share a file, so the rank is what tells them
      // apart.
      final rooks = Position.fromFen('4k3/8/8/R7/8/8/8/R3K3 w - - 0 1');
      expect(describeLine(rooks, <String>['a1a3']), <String>['R1a3']);
      expect(describeLine(rooks, <String>['a5a3']), <String>['R5a3']);

      // Three queens reach d4, and no single file or rank separates the one
      // on b2 from both others — so it takes the whole square.
      final queens =
          Position.fromFen('4k3/8/1Q6/8/8/8/1Q3Q2/4K3 w - - 0 1');
      expect(describeLine(queens, <String>['b2d4']), <String>['Qb2d4']);
      expect(describeLine(queens, <String>['b6d4']), <String>['Q6d4'],
          reason: 'the sixth rank holds only one of them');
      expect(describeLine(queens, <String>['f2d4']), <String>['Qfd4']);
    });
  });

  group('parseUci', () {
    test('reads a move and its promotion', () {
      final position = Position.fromFen('4k3/1P6/8/8/8/8/8/4K3 w - - 0 1');
      expect(parseUci(position, 'b7b8n')?.promotion, PieceKind.knight);
      expect(parseUci(position, 'b7b8')?.promotion, PieceKind.queen,
          reason: 'a promotion left unsaid is a queen');
    });

    test('gives back null for anything that is not a legal move here', () {
      final position = Position.initial();
      expect(parseUci(position, 'e2e5'), isNull);
      expect(parseUci(position, 'zzzz'), isNull);
      expect(parseUci(position, 'e2'), isNull);
      expect(parseUci(position, 'e7e8k'), isNull);
    });
  });
}
