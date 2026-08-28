import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';

/// How round a block's corners are, as a fraction of its side.
const double kBlockRadius = 0.20;

/// How much smaller a block is than the cell it sits in, as a fraction of the
/// cell. The gap is what makes a 2x2 read as four blocks rather than a square.
const double kBlockInset = 0.06;

/// Draws one block filling [cell], in [color].
///
/// The highlight across the top is the whole reason blocks look like blocks
/// rather than coloured squares, and it costs one rounded rectangle.
void paintBlock(Canvas canvas, Rect cell, Color color) {
  final side = cell.width;
  final rect = cell.deflate(side * kBlockInset);
  final radius = Radius.circular(side * kBlockRadius);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = color,
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + rect.width * 0.16,
          rect.top + rect.height * 0.14,
          rect.width * 0.68,
          rect.height * 0.26,
        ),
        Radius.circular(side * kBlockRadius * 0.6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.20),
    );
}

/// Draws an empty square filling [cell], in [color].
void paintEmptyCell(Canvas canvas, Rect cell, Color color) {
  final side = cell.width;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      cell.deflate(side * kBlockInset),
      Radius.circular(side * kBlockRadius),
    ),
    Paint()..color = color,
  );
}

/// Outlines the outside edge of [cells] in [color].
///
/// Only the edges on the boundary are drawn: an edge shared with another cell
/// in the set is inside the shape, and drawing it would turn the outline into
/// a grid.
///
/// The line runs along the cell boundary rather than the block's own edge.
/// Blocks are inset inside their cells, so this sits just outside the piece's
/// silhouette — which is the whole point. A piece dropped on the board is
/// drawn at the pointer's exact position while the landing it snaps to is
/// rounded to a cell, so the two overlap almost entirely, and an outline
/// tucked inside the cell would be hidden underneath the piece exactly when
/// the player has lined it up.
void paintFootprintOutline(
  Canvas canvas,
  Set<Coord> cells,
  double cellSize,
  Color color,
  double width,
) {
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  for (final cell in cells) {
    final rect = cellRect(cell, cellSize);
    if (!cells.contains(cell.translate(-1, 0))) {
      canvas.drawLine(rect.topLeft, rect.topRight, stroke);
    }
    if (!cells.contains(cell.translate(1, 0))) {
      canvas.drawLine(rect.bottomLeft, rect.bottomRight, stroke);
    }
    if (!cells.contains(cell.translate(0, -1))) {
      canvas.drawLine(rect.topLeft, rect.bottomLeft, stroke);
    }
    if (!cells.contains(cell.translate(0, 1))) {
      canvas.drawLine(rect.topRight, rect.bottomRight, stroke);
    }
  }
}

/// The rectangle [coord] occupies on a board whose cells are [cellSize].
Rect cellRect(Coord coord, double cellSize) => Rect.fromLTWH(
      coord.col * cellSize,
      coord.row * cellSize,
      cellSize,
      cellSize,
    );

/// Draws [shape] in [color] with its top-left corner at the origin, at
/// [cellSize] per block.
void paintShape(
  Canvas canvas,
  BlockShape shape,
  Color color,
  double cellSize,
) {
  for (final cell in shape.cells) {
    paintBlock(canvas, cellRect(cell, cellSize), color);
  }
}
