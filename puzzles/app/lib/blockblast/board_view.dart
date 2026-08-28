import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'block_game.dart';
import 'block_paint.dart';

/// How long a cleared line takes to go.
///
/// Short: the line is already gone as far as the game is concerned, and the
/// animation is only there so the player sees which one went. Every
/// millisecond past that is a millisecond of not being able to play. This and
/// [kClearCurve] are the knobs worth turning if the clear feels wrong.
const Duration kClearDuration = Duration(milliseconds: 200);

/// How a cleared cell shrinks away.
///
/// Eases in, so the blocks hold their size for an instant before collapsing.
/// That pause is what makes the line readable at this speed — going
/// immediately would be over before the eye found it.
const Curve kClearCurve = Curves.easeIn;

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
    duration: kClearDuration,
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
            hint: widget.game.hintSteps,
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
    required this.hint,
    required this.wouldFill,
    required this.wouldClear,
    required this.carriedPaint,
    required this.clearing,
    required this.clearProgress,
  });

  final BlockBoard board;
  final BlockPalette palette;
  final List<HintStep> hint;
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

    // The hint, under the drag: a player who picks a piece up has stopped
    // reading it. Drawn before the ghost so a drag always wins the square.
    if (hint.isNotEmpty) _paintHint(canvas, cell);

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
      final shrink = 1 - kClearCurve.transform(clearProgress);
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

  /// Draws each step of the plan where it goes, numbered in playing order.
  ///
  /// Numbered rather than shown one at a time because the order is the whole
  /// point: a plan usually works only because an earlier piece took a line
  /// out and made room for a later one. A step can therefore sit on squares
  /// that are still filled — they will not be by the time it is played.
  void _paintHint(Canvas canvas, double cell) {
    for (final step in hint) {
      final color = palette.pieceColor(step.paint);
      for (final coord in step.cells) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect(coord, cell).deflate(cell * kBlockInset),
            Radius.circular(cell * kBlockRadius),
          ),
          Paint()..color = color.withValues(alpha: 0.55),
        );
      }
      paintFootprintOutline(canvas, step.cells, cell, palette.ghost, cell * 0.1);

      // The number goes on the step's own top-left square, which is always
      // part of the shape and never wanders off into a hole in a concave one.
      final head = step.cells.reduce(
        (Coord a, Coord b) =>
            b.row < a.row || (b.row == a.row && b.col < a.col) ? b : a,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${step.order}',
          style: TextStyle(
            color: palette.boardSurface,
            fontSize: cell * 0.44,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centre = cellRect(head, cell).center;
      canvas.drawCircle(
        centre,
        cell * 0.30,
        Paint()..color = palette.ghost,
      );
      label.paint(
        canvas,
        centre - Offset(label.width / 2, label.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.board != board ||
      old.palette != palette ||
      old.hint != hint ||
      old.wouldFill != wouldFill ||
      old.wouldClear != wouldClear ||
      old.carriedPaint != carriedPaint ||
      old.clearing != clearing ||
      old.clearProgress != clearProgress;
}
