import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';

import 'block_paint.dart';

/// One shape, drawn on its own.
///
/// Sized exactly to the shape's bounding box, so a 1x5 bar in the tray is as
/// wide as five blocks and nothing more — which is what lets the tray lay
/// three pieces of very different shapes out without them fighting.
class PieceView extends StatelessWidget {
  /// Draws [shape] in [color] at [cellSize] per block.
  const PieceView({
    required this.shape,
    required this.color,
    required this.cellSize,
    this.opacity = 1,
    super.key,
  });

  /// The shape to draw.
  final BlockShape shape;

  /// The colour to draw it in.
  final Color color;

  /// How big one block is.
  final double cellSize;

  /// How solid to draw it. Below one for a piece that can no longer be played.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: shape.width * cellSize,
      height: shape.height * cellSize,
      child: CustomPaint(
        painter: _PiecePainter(
          shape: shape,
          color: color,
          cellSize: cellSize,
          opacity: opacity,
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  const _PiecePainter({
    required this.shape,
    required this.color,
    required this.cellSize,
    required this.opacity,
  });

  final BlockShape shape;
  final Color color;
  final double cellSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    // A layer rather than a translucent colour: the highlight on each block is
    // painted white over the fill, so fading the fill alone would leave the
    // highlights at full strength and the piece would look chalky.
    if (opacity < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }
    paintShape(canvas, shape, color, cellSize);
    if (opacity < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.cellSize != cellSize ||
      old.opacity != opacity;
}
