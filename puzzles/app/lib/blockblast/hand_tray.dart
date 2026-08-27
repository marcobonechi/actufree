import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'block_game.dart';
import 'piece_view.dart';

/// How far above the finger a carried piece rides, in board cells.
///
/// Without this the piece sits under the hand holding it, which is fine with a
/// mouse and useless on a phone. The pointer ends up outside the piece
/// entirely, which is why the screen puts its drag target around the whole
/// play area rather than around the board: hit-testing the board would make
/// the bottom rows unreachable.
const double kCarryLift = 0.9;

/// The three pieces on offer.
///
/// A piece is drawn small here and at full board size once picked up, which is
/// the same trick the commercial game uses: the tray stays compact, and what
/// you are carrying is exactly the size of the hole you are looking for.
class HandTray extends StatelessWidget {
  /// Draws [game]'s hand, sized against a board of [boardCellSize] cells.
  const HandTray({required this.game, required this.boardCellSize, super.key});

  /// The game being played.
  final BlockBlastGame game;

  /// How big one cell of the board is.
  final double boardCellSize;

  /// How big one block of a piece is while it sits in the tray.
  double get trayCellSize => boardCellSize / 2;

  /// The side of one slot: five blocks, the longest piece in the catalogue.
  double get slotSide => trayCellSize * 5;

  @override
  Widget build(BuildContext context) {
    final palette = blockPaletteOf(context);
    return SizedBox(
      height: slotSide,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (var index = 0; index < handSize; index++)
            SizedBox(
              width: slotSide,
              height: slotSide,
              child: _Slot(
                key: ValueKey<String>('hand-slot-$index'),
                game: game,
                index: index,
                palette: palette,
                boardCellSize: boardCellSize,
                trayCellSize: trayCellSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.game,
    required this.index,
    required this.palette,
    required this.boardCellSize,
    required this.trayCellSize,
    super.key,
  });

  final BlockBlastGame game;
  final int index;
  final BlockPalette palette;
  final double boardCellSize;
  final double trayCellSize;

  @override
  Widget build(BuildContext context) {
    final piece = game.pieceAt(index);
    if (piece == null) return const SizedBox.expand();

    // A piece with nowhere to go is drawn grey and faded. It stays draggable:
    // being told a piece is dead is useful, being stopped from picking it up
    // and seeing why is not.
    final playable = game.fitsSomewhere(index);
    final color = playable
        ? palette.pieceColor(piece.paint)
        : palette.deadPiece;

    return Center(
      child: Semantics(
        label: _describe(piece.shape),
        hint: playable
            ? 'Drag onto the board'
            : 'No longer fits anywhere on the board',
        child: Draggable<int>(
          data: index,
          dragAnchorStrategy: (_, _, _) => Offset(
            piece.shape.width * boardCellSize / 2,
            piece.shape.height * boardCellSize + kCarryLift * boardCellSize,
          ),
          feedback: PieceView(
            shape: piece.shape,
            color: palette.pieceColor(piece.paint),
            cellSize: boardCellSize,
          ),
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () => game.startDrag(index),
          onDragEnd: (DraggableDetails details) {
            if (!details.wasAccepted) game.endDrag();
          },
          child: PieceView(
            shape: piece.shape,
            color: color,
            cellSize: trayCellSize,
            opacity: playable ? 1 : 0.55,
          ),
        ),
      ),
    );
  }

  /// A shape in words, for a screen reader.
  ///
  /// Its size and footprint, which is what a player needs in order to know
  /// whether it will go where they are thinking of putting it. Naming the
  /// pieces — "the S", "the big L" — would be shorter but assumes a
  /// vocabulary the game never teaches.
  static String _describe(BlockShape shape) {
    if (shape.size == 1) return 'Single block';
    if (shape.width == 1) return 'Bar, ${shape.height} blocks tall';
    if (shape.height == 1) return 'Bar, ${shape.width} blocks wide';
    return '${shape.size}-block piece, '
        '${shape.width} wide and ${shape.height} tall';
  }
}
