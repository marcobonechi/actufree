import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'block_game.dart';
import 'block_paint.dart';

/// The 8x8 board.
///
/// Written directly rather than on a shared grid widget, for the reason the
/// brief gives: Sudoku's board wants a selected cell, peers and pencil marks,
/// and this one wants a ghost that follows a finger and lines that flash on
/// the way out. There is nothing in the middle worth abstracting.
///
/// Painted rather than built from widgets. Sixty-four cells that all redraw on
/// every frame of a drag is the case a [CustomPaint] is for.
class BlockBoardView extends StatefulWidget {
  /// Draws [game]'s board.
  const BlockBoardView({required this.game, super.key});

  /// The game being played.
  final BlockBlastGame game;

  @override
  State<BlockBoardView> createState() => _BlockBoardViewState();
}

class _BlockBoardViewState extends State<BlockBoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addStatusListener(_onClearDone);
  late int _seenTick = widget.game.clearTick;
  Set<Coord> _clearing = const <Coord>{};

  @override
  void didUpdateWidget(covariant BlockBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The game notifies on every move, so the tick is what distinguishes a
    // fresh clear from an ordinary rebuild.
    final tick = widget.game.clearTick;
    if (tick == _seenTick) return;
    _seenTick = tick;
    _clearing = widget.game.clearing;
    _clear.forward(from: 0);
  }

  @override
  void dispose() {
    _clear.dispose();
    super.dispose();
  }

  void _onClearDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _clearing = const <Coord>{});
  }

  @override
  Widget build(BuildContext context) {
    final palette = blockPaletteOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _clear,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _BoardPainter(
            board: widget.game.state.board,
            palette: palette,
            wouldFill: widget.game.wouldFill,
            wouldClear: widget.game.wouldClear,
            carriedPaint: _carriedPaint,
            clearing: _clearing,
            clearProgress: _clear.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  /// The colour of the piece being carried, for the ghost.
  int? get _carriedPaint {
    final index = widget.game.carrying;
    return index == null ? null : widget.game.pieceAt(index)?.paint;
  }
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.board,
    required this.palette,
    required this.wouldFill,
    required this.wouldClear,
    required this.carriedPaint,
    required this.clearing,
    required this.clearProgress,
  });

  final BlockBoard board;
  final BlockPalette palette;
  final Set<Coord> wouldFill;
  final Set<Coord> wouldClear;
  final int? carriedPaint;
  final Set<Coord> clearing;
  final double clearProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / boardSize;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(cell * 0.24),
      ),
      Paint()..color = palette.boardSurface,
    );

    for (final coord in Coord.all) {
      final rect = cellRect(coord, cell);
      final paint = board.paintAt(coord);
      if (paint == 0) {
        paintEmptyCell(canvas, rect, palette.emptyCell);
      } else {
        paintBlock(canvas, rect, palette.pieceColor(paint));
      }
    }

    // Lines the carried piece would complete, lit up underneath everything the
    // drag draws on top. This is the difference between finding a double and
    // being surprised by one.
    if (wouldClear.isNotEmpty) {
      final glow = Paint()..color = palette.clearFlash.withValues(alpha: 0.45);
      for (final coord in wouldClear) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect(coord, cell).deflate(cell * kBlockInset),
            Radius.circular(cell * kBlockRadius),
          ),
          glow,
        );
      }
    }

    // Where the carried piece would land: its own colour, faint, under an
    // outline. Solid would be indistinguishable from a block already down.
    final carried = carriedPaint;
    if (wouldFill.isNotEmpty && carried != null) {
      final color = palette.pieceColor(carried);
      for (final coord in wouldFill) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect(coord, cell).deflate(cell * kBlockInset),
            Radius.circular(cell * kBlockRadius),
          ),
          Paint()..color = color.withValues(alpha: 0.42),
        );
      }
      paintFootprintOutline(canvas, wouldFill, cell, palette.ghost, cell * 0.1);
    }

    // The cells on their way out. The engine has already emptied them, so this
    // draws over the gap they left: a flash that shrinks and fades, which
    // reads as the line being taken away rather than simply vanishing.
    if (clearing.isNotEmpty && clearProgress < 1) {
      final shrink = 1 - Curves.easeIn.transform(clearProgress);
      final flash = Paint()
        ..color = palette.clearFlash.withValues(alpha: 0.85 * shrink);
      for (final coord in clearing) {
        final rect = cellRect(coord, cell);
        final inset = cell * kBlockInset + (cell * 0.5 - cell * kBlockInset) * (1 - shrink);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(inset),
            Radius.circular(cell * kBlockRadius * shrink),
          ),
          flash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.board != board ||
      old.palette != palette ||
      old.wouldFill != wouldFill ||
      old.wouldClear != wouldClear ||
      old.carriedPaint != carriedPaint ||
      old.clearing != clearing ||
      old.clearProgress != clearProgress;
}
