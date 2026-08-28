import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'chess_match.dart';
import 'piece_paint.dart';

/// How big the dot on a square a piece may move to is, across.
const double kMoveDot = 0.26;

/// How thick the ring around a piece that may be taken is.
const double kCaptureRing = 0.07;

/// The board.
///
/// Painted rather than built from widgets, for the same reason Block Blast's
/// is: sixty-four squares that redraw together, and pieces that are drawings
/// rather than glyphs.
///
/// Every tap goes to the same place — [ChessMatch.tap] — and what it means
/// depends on what is already picked up. There is no drag here. Tapping the
/// piece and then the square is the input a board this size can be played
/// with accurately by a thumb, and it is the one that works the same whether
/// the phone is on the table between two players or in someone's hand.
class ChessBoardView extends StatelessWidget {
  /// Draws [match]'s board.
  const ChessBoardView({required this.match, super.key});

  /// The game being played.
  final ChessMatch match;

  @override
  Widget build(BuildContext context) {
    final palette = chessPaletteOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final cell = constraints.maxWidth / boardSize;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) {
              final square = _squareAt(details.localPosition, cell);
              if (square != null) match.tap(square);
            },
            child: Semantics(
              label: 'Chess board',
              value: _describeBoard(match),
              child: CustomPaint(
                painter: _BoardPainter(
                  position: match.position,
                  palette: palette,
                  selected: match.selected ?? match.promoting?.from,
                  targets: match.targets,
                  lastMove: match.lastMove,
                  checkedKing: match.checkedKing,
                  flipped: match.flipped,
                ),
                size: Size.square(constraints.maxWidth),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The square under [local], or `null` when the tap missed the board.
  Square? _squareAt(Offset local, double cell) {
    final col = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) return null;
    return match.flipped
        ? Square(boardSize - 1 - row, boardSize - 1 - col)
        : Square(row, col);
  }

  /// What the board says to a screen reader.
  ///
  /// Whose move it is and what just happened, rather than sixty-four squares
  /// read out one at a time. The state that changes is the state worth
  /// announcing.
  static String _describeBoard(ChessMatch match) {
    final parts = <String>['${match.sideToMove.label} to move'];
    if (match.position.inCheck) parts.add('in check');
    final last = match.game.notation.isEmpty ? null : match.game.notation.last;
    if (last != null) parts.add('last move $last');
    return parts.join(', ');
  }
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.position,
    required this.palette,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.checkedKing,
    required this.flipped,
  });

  final Position position;
  final ChessPalette palette;
  final Square? selected;
  final Map<Square, bool> targets;
  final Move? lastMove;
  final Square? checkedKing;
  final bool flipped;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / boardSize;

    for (final square in Square.all) {
      final rect = _rectFor(square, cell);
      canvas.drawRect(
        rect,
        Paint()
          ..color = square.isLight ? palette.lightSquare : palette.darkSquare,
      );
    }

    // The move just played sits under everything else: it is context, not an
    // instruction, and it should not compete with the square the player has
    // their finger on.
    for (final square in <Square?>[lastMove?.from, lastMove?.to]) {
      if (square == null) continue;
      canvas.drawRect(
        _rectFor(square, cell),
        Paint()..color = palette.lastMove.withValues(alpha: 0.38),
      );
    }

    if (checkedKing != null) {
      _paintCheck(canvas, _rectFor(checkedKing!, cell));
    }

    if (selected != null) {
      canvas.drawRect(
        _rectFor(selected!, cell),
        Paint()..color = palette.selected.withValues(alpha: 0.45),
      );
    }

    _paintCoordinates(canvas, cell);

    for (final square in Square.all) {
      final piece = position.pieceAt(square);
      if (piece == null) continue;
      paintPiece(
        canvas,
        _rectFor(square, cell),
        piece,
        body: palette.body(piece.color),
        outline: palette.outline(piece.color),
      );
    }

    // The marks go on last so that a ring lands around the piece it would
    // take rather than under it.
    targets.forEach((Square square, bool isCapture) {
      final rect = _rectFor(square, cell);
      if (isCapture) {
        canvas.drawCircle(
          rect.center,
          cell * (0.5 - kCaptureRing / 2) - 1,
          Paint()
            ..color = palette.legalMark.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * kCaptureRing,
        );
      } else {
        canvas.drawCircle(
          rect.center,
          cell * kMoveDot / 2,
          Paint()..color = palette.legalMark.withValues(alpha: 0.42),
        );
      }
    });
  }

  /// Rings the king in check rather than flooding its square.
  ///
  /// A filled square would hide the piece the player most needs to look at,
  /// and check is not a place to move to — it is a fact about the piece
  /// standing there.
  void _paintCheck(Canvas canvas, Rect rect) {
    canvas.drawCircle(
      rect.center,
      rect.width * 0.44,
      Paint()
        ..color = palette.check
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.075,
    );
  }

  /// The file letters along the bottom and the rank numbers up the left.
  ///
  /// Drawn in the colour of the square they are *not* on, which is the old
  /// printed-diagram trick: it keeps them legible on both colours without a
  /// third colour appearing on the board.
  void _paintCoordinates(Canvas canvas, double cell) {
    final style = TextStyle(
      color: palette.coordinate,
      fontSize: cell * 0.2,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i < boardSize; i++) {
      final file = flipped ? boardSize - 1 - i : i;
      final rank = flipped ? boardSize - 1 - i : i;
      _paintLabel(
        canvas,
        Square(0, file).file,
        style,
        Offset(
          (i + 1) * cell - cell * 0.06,
          boardSize * cell - cell * 0.04,
        ),
        alignRight: true,
        alignBottom: true,
      );
      _paintLabel(
        canvas,
        '${Square(rank, 0).rank}',
        style,
        Offset(cell * 0.06, i * cell + cell * 0.04),
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    bool alignRight = false,
    bool alignBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      at -
          Offset(
            alignRight ? painter.width : 0,
            alignBottom ? painter.height : 0,
          ),
    );
  }

  /// Where [square] lands on the canvas, which is the only place the board
  /// being turned around is allowed to matter.
  Rect _rectFor(Square square, double cell) {
    final row = flipped ? boardSize - 1 - square.row : square.row;
    final col = flipped ? boardSize - 1 - square.col : square.col;
    return Rect.fromLTWH(col * cell, row * cell, cell, cell);
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.position != position ||
      old.palette != palette ||
      old.selected != selected ||
      !mapEquals(old.targets, targets) ||
      old.lastMove != lastMove ||
      old.checkedKing != checkedKing ||
      old.flipped != flipped;
}
