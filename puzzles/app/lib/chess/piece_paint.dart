import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/material.dart';

/// How thick the line around a piece is, as a fraction of the square.
const double kPieceLine = 0.03;

/// How much smaller a piece is than the square it stands on.
///
/// Pieces are drawn to a unit box that already leaves a margin of its own, so
/// this is the little extra that keeps two pieces on neighbouring squares from
/// looking like one shape.
const double kPieceInset = 0.06;

/// Draws [piece] filling [square].
///
/// The pieces are abstractions rather than the Staunton silhouettes: a circle
/// on a plinth for a pawn, a notched tower for a rook, a mitre for a bishop,
/// a five-pointed crown for a queen and a cross for a king. They are built
/// from a handful of straight lines each, which is what makes them survive
/// being drawn at a fortieth of a phone screen — a faithful knight at that
/// size is a smudge, and an angular one is still a knight.
///
/// Each is filled in its side's colour and outlined in the other's. A white
/// piece on a light square and a black piece on a dark square are the two
/// cases that decide whether a board can be read at a glance, and an outline
/// settles both without tinting anything.
void paintPiece(
  Canvas canvas,
  Rect square,
  ChessPiece piece, {
  required Color body,
  required Color outline,
  double opacity = 1,
}) {
  final side = square.shortestSide * (1 - kPieceInset * 2);
  final origin = square.center - Offset(side / 2, side / 2);
  canvas
    ..save()
    ..translate(origin.dx, origin.dy)
    // Everything below is drawn in a unit square, this scale being the only
    // place the piece's size is decided. Line widths scale with it, which is
    // what keeps a piece on a small board looking like the same drawing
    // rather than a heavier one.
    ..scale(side)
    ..drawPath(
      _pathFor(piece.kind),
      Paint()..color = body.withValues(alpha: body.a * opacity),
    )
    ..drawPath(
      _pathFor(piece.kind),
      Paint()
        ..color = outline.withValues(alpha: outline.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = kPieceLine
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  _paintDetail(canvas, piece.kind, outline.withValues(alpha: outline.a * opacity));
  canvas.restore();
}

/// What to call [piece] out loud, for a screen reader.
String describePiece(ChessPiece piece) =>
    '${piece.color.label} ${piece.kind.name}';

/// The outline of [kind], in a unit square with the piece standing on its
/// floor.
Path _pathFor(PieceKind kind) => switch (kind) {
      PieceKind.pawn => _pawn(),
      PieceKind.knight => _knight(),
      PieceKind.bishop => _bishop(),
      PieceKind.rook => _rook(),
      PieceKind.queen => _queen(),
      PieceKind.king => _king(),
    };

/// The plinth every piece stands on.
///
/// Shared so that a row of pieces sits on one line. It is most of what makes
/// six unrelated shapes read as one set.
Path _base() => Path()
  ..moveTo(0.19, 0.90)
  ..lineTo(0.81, 0.90)
  ..lineTo(0.81, 0.84)
  ..lineTo(0.70, 0.78)
  ..lineTo(0.30, 0.78)
  ..lineTo(0.19, 0.84)
  ..close();

/// A collar between a piece's body and its plinth.
Path _collar(double top, double bottom, double inset) => Path()
  ..moveTo(inset, top)
  ..lineTo(1 - inset, top)
  ..lineTo(1 - inset - 0.02, bottom)
  ..lineTo(inset + 0.02, bottom)
  ..close();

Path _pawn() => _base()
  ..addPath(
    Path()
      ..moveTo(0.37, 0.78)
      ..lineTo(0.43, 0.46)
      ..lineTo(0.57, 0.46)
      ..lineTo(0.63, 0.78)
      ..close(),
    Offset.zero,
  )
  ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.30), radius: 0.125));

Path _rook() => _base()
  ..addPath(
    Path()
      ..moveTo(0.32, 0.78)
      ..lineTo(0.36, 0.44)
      ..lineTo(0.64, 0.44)
      ..lineTo(0.68, 0.78)
      ..close(),
    Offset.zero,
  )
  // The battlements: two notches cut out of a block, which is the whole of
  // what makes a rectangle read as a rook.
  ..addPath(
    Path()
      ..moveTo(0.27, 0.44)
      ..lineTo(0.27, 0.21)
      ..lineTo(0.38, 0.21)
      ..lineTo(0.38, 0.30)
      ..lineTo(0.45, 0.30)
      ..lineTo(0.45, 0.21)
      ..lineTo(0.55, 0.21)
      ..lineTo(0.55, 0.30)
      ..lineTo(0.62, 0.30)
      ..lineTo(0.62, 0.21)
      ..lineTo(0.73, 0.21)
      ..lineTo(0.73, 0.44)
      ..close(),
    Offset.zero,
  );

/// A head in profile, facing left: muzzle, forehead, two ears, and the neck
/// down to the plinth.
///
/// The one piece that cannot be built out of a circle and a trapezoid. It is
/// still only ten points.
Path _knight() => _base()
  ..addPath(
    Path()
      ..moveTo(0.32, 0.78)
      ..lineTo(0.33, 0.58)
      ..lineTo(0.22, 0.50)
      ..lineTo(0.27, 0.41)
      ..lineTo(0.35, 0.34)
      ..lineTo(0.39, 0.19)
      ..lineTo(0.47, 0.30)
      ..lineTo(0.55, 0.17)
      ..lineTo(0.67, 0.35)
      ..lineTo(0.71, 0.54)
      ..lineTo(0.69, 0.78)
      ..close(),
    Offset.zero,
  );

Path _bishop() => _base()
  ..addPath(_collar(0.68, 0.78, 0.30), Offset.zero)
  ..addPath(
    Path()
      ..moveTo(0.34, 0.68)
      ..quadraticBezierTo(0.33, 0.36, 0.50, 0.21)
      ..quadraticBezierTo(0.67, 0.36, 0.66, 0.68)
      ..close(),
    Offset.zero,
  )
  ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.17), radius: 0.052));

Path _queen() => _base()
  ..addPath(_collar(0.68, 0.78, 0.28), Offset.zero)
  ..addPath(
    Path()
      ..moveTo(0.26, 0.68)
      ..lineTo(0.20, 0.30)
      ..lineTo(0.30, 0.46)
      ..lineTo(0.36, 0.24)
      ..lineTo(0.43, 0.44)
      ..lineTo(0.50, 0.19)
      ..lineTo(0.57, 0.44)
      ..lineTo(0.64, 0.24)
      ..lineTo(0.70, 0.46)
      ..lineTo(0.80, 0.30)
      ..lineTo(0.74, 0.68)
      ..close(),
    Offset.zero,
  );

Path _king() => _base()
  ..addPath(_collar(0.68, 0.78, 0.29), Offset.zero)
  ..addPath(
    Path()
      ..moveTo(0.31, 0.68)
      ..lineTo(0.35, 0.52)
      ..quadraticBezierTo(0.50, 0.40, 0.65, 0.52)
      ..lineTo(0.69, 0.68)
      ..close(),
    Offset.zero,
  )
  ..addPath(
    Path()
      ..moveTo(0.455, 0.10)
      ..lineTo(0.545, 0.10)
      ..lineTo(0.545, 0.20)
      ..lineTo(0.635, 0.20)
      ..lineTo(0.635, 0.29)
      ..lineTo(0.545, 0.29)
      ..lineTo(0.545, 0.46)
      ..lineTo(0.455, 0.46)
      ..lineTo(0.455, 0.29)
      ..lineTo(0.365, 0.29)
      ..lineTo(0.365, 0.20)
      ..lineTo(0.455, 0.20)
      ..close(),
    Offset.zero,
  );

/// The marks drawn in the outline colour on top of a filled piece: the
/// knight's eye, the bishop's cut, and the beads on the queen's crown.
///
/// Kept apart from the outlines because they are filled, not stroked, and
/// because a shape that is only decoration should not be part of the
/// silhouette that decides whether the piece is recognisable.
void _paintDetail(Canvas canvas, PieceKind kind, Color color) {
  final ink = Paint()..color = color;
  switch (kind) {
    case PieceKind.knight:
      canvas.drawCircle(const Offset(0.45, 0.40), 0.033, ink);
    case PieceKind.bishop:
      canvas.drawLine(
        const Offset(0.50, 0.34),
        const Offset(0.59, 0.46),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = kPieceLine
          ..strokeCap = StrokeCap.round,
      );
    case PieceKind.queen:
      for (final tip in const <Offset>[
        Offset(0.20, 0.28),
        Offset(0.36, 0.22),
        Offset(0.50, 0.17),
        Offset(0.64, 0.22),
        Offset(0.80, 0.28),
      ]) {
        canvas.drawCircle(tip, 0.035, ink);
      }
    case PieceKind.pawn || PieceKind.rook || PieceKind.king:
      break;
  }
}

/// One piece on its own, for a promotion chooser or a row of captured men.
///
/// The same drawing as on the board, which is the point: a player picking a
/// knight out of four shapes should be picking the shape they will then be
/// looking at.
class PieceGlyph extends StatelessWidget {
  /// Draws [piece] at [size] across.
  const PieceGlyph({
    required this.piece,
    required this.body,
    required this.outline,
    this.size = 32,
    super.key,
  });

  /// What to draw.
  final ChessPiece piece;

  /// The piece's fill.
  final Color body;

  /// The line around it.
  final Color outline;

  /// How wide the drawing is.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: describePiece(piece),
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(piece: piece, body: body, outline: outline),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.piece,
    required this.body,
    required this.outline,
  });

  final ChessPiece piece;
  final Color body;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    paintPiece(
      canvas,
      Offset.zero & size,
      piece,
      body: body,
      outline: outline,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.piece != piece || old.body != body || old.outline != outline;
}
