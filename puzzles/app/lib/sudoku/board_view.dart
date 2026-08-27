import 'package:flutter/material.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import '../theme.dart';
import 'sudoku_game.dart';

/// The 9x9 board.
///
/// Written directly rather than on top of a shared grid widget: the region
/// borders, peer highlighting and pencil marks are specific enough to Sudoku
/// that an abstraction would fight them.
class SudokuBoardView extends StatefulWidget {
  /// Draws [game]'s board.
  const SudokuBoardView({required this.game, super.key});

  /// The game being played.
  final SudokuGame game;

  @override
  State<SudokuBoardView> createState() => _SudokuBoardViewState();
}

class _SudokuBoardViewState extends State<SudokuBoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  )..addStatusListener(_onCelebrationDone);
  late int _seenTick = widget.game.completionTick;
  Set<Cell> _celebrating = const <Cell>{};

  @override
  void didUpdateWidget(covariant SudokuBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The game notifies on every move, so the tick is what distinguishes a
    // fresh completion from an ordinary rebuild.
    final tick = widget.game.completionTick;
    if (tick == _seenTick) return;
    _seenTick = tick;
    _celebrating = widget.game.justCompleted;
    _celebration.forward(from: 0);
  }

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  void _onCelebrationDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _celebrating = const <Cell>{});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final palette = paletteOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final cellSize = constraints.maxWidth / boardSize;
          return Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  for (var row = 0; row < boardSize; row++)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          for (var col = 0; col < boardSize; col++)
                            Expanded(
                              child: _CellView(
                                game: game,
                                cell: Cell(row, col),
                                palette: palette,
                                size: cellSize,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_celebrating.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _celebration,
                      builder: (BuildContext context, _) => CustomPaint(
                        painter: _CompletionPainter(
                          cells: _celebrating,
                          progress: _celebration.value,
                          colour: palette.completed,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GridLinePainter(palette)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({
    required this.game,
    required this.cell,
    required this.palette,
    required this.size,
  });

  final SudokuGame game;
  final Cell cell;
  final SudokuPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final board = game.board;
    final value = board.valueAt(cell);
    final isGiven = board.isGiven(cell);
    final selected = game.selected;
    final isSelected = selected == cell;
    final isPeer = selected != null && selected.peers.contains(cell);
    final selectedValue = selected == null ? null : board.valueAt(selected);
    final isMatch = !isSelected && value != null && value == selectedValue;
    final isWrong = game.isWrong(cell);
    final isFlagged = game.highlighted.contains(cell);

    final Color? background;
    if (isSelected) {
      background = palette.selectedSurface;
    } else if (isWrong) {
      background = palette.conflictSurface;
    } else if (isFlagged || isMatch) {
      background = palette.matchSurface;
    } else if (isPeer) {
      background = palette.peerSurface;
    } else {
      background = null;
    }

    final Widget content;
    if (value != null) {
      content = Text(
        '$value',
        style: TextStyle(
          fontSize: size * 0.58,
          height: 1,
          fontWeight: isGiven ? FontWeight.w600 : FontWeight.w400,
          color: isWrong
              ? palette.conflict
              : isGiven
                  ? palette.given
                  : palette.entry,
        ),
      );
    } else {
      content = _Notes(
        digits: board.notesAt(cell),
        palette: palette,
        size: size,
      );
    }

    return GestureDetector(
      key: ValueKey<String>('cell-${cell.index}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => game.select(cell),
      child: Semantics(
        label: 'Row ${cell.row + 1} column ${cell.col + 1}',
        value: value == null ? 'empty' : '$value',
        selected: isSelected,
        child: ColoredBox(
          color: background ?? Colors.transparent,
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({
    required this.digits,
    required this.palette,
    required this.size,
  });

  final Set<int> digits;
  final SudokuPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (digits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        children: <Widget>[
          for (var band = 0; band < boxSize; band++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (var slot = 0; slot < boxSize; slot++)
                    Expanded(
                      child: Center(
                        child: Text(
                          digits.contains(band * boxSize + slot + 1)
                              ? '${band * boxSize + slot + 1}'
                              : '',
                          style: TextStyle(
                            fontSize: size * 0.22,
                            height: 1,
                            color: palette.note,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Flashes over a row, column or box that has just been completed.
///
/// Painted above the cells but below the grid lines, so the board's structure
/// stays legible while the flash passes over it.
class _CompletionPainter extends CustomPainter {
  const _CompletionPainter({
    required this.cells,
    required this.progress,
    required this.colour,
  });

  final Set<Cell> cells;
  final double progress;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final step = size.width / boardSize;
    for (final cell in cells) {
      // Staggering along the diagonal makes the flash sweep along a row, down
      // a column, or across a box, rather than blinking all at once.
      final delay = ((cell.row + cell.col) % boardSize) * 0.045;
      final local = (progress - delay) / 0.6;
      final strength = _envelope(local);
      if (strength <= 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(cell.col * step, cell.row * step, step, step),
        Paint()..color = colour.withValues(alpha: strength * 0.5),
      );
    }
  }

  /// Rises quickly, falls away slowly.
  static double _envelope(double t) {
    if (t <= 0 || t >= 1) return 0;
    return t < 0.3 ? t / 0.3 : (1 - t) / 0.7;
  }

  @override
  bool shouldRepaint(_CompletionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colour != colour ||
      oldDelegate.cells != cells;
}

class _GridLinePainter extends CustomPainter {
  const _GridLinePainter(this.palette);

  final SudokuPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Every line is drawn here, the outer frame included. Painting the frame
    // with a DecoratedBox instead puts it behind the cells, where a
    // highlighted cell's background paints straight over it.
    final step = size.width / boardSize;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..color = palette.boxLine
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var line = 1; line < boardSize; line++) {
      final isBoxEdge = line % boxSize == 0;
      final paint = Paint()
        ..color = isBoxEdge ? palette.boxLine : palette.gridLine
        ..strokeWidth = isBoxEdge ? 2 : 1;
      final offset = step * line;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), paint);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinePainter oldDelegate) =>
      oldDelegate.palette != palette;
}
