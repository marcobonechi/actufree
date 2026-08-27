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

/// Draws the outline of a block filling [cell], in [color].
///
/// Used for the ghost that follows a dragged piece, where a filled block would
/// be mistaken for one already placed.
void paintBlockOutline(Canvas canvas, Rect cell, Color color, double width) {
  final side = cell.width;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      cell.deflate(side * kBlockInset + width / 2),
      Radius.circular(side * kBlockRadius),
    ),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
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
