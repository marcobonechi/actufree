import 'package:flutter/material.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import '../theme.dart';
import 'sudoku_game.dart';

/// Digit entry and the tools that go with it.
class NumberPad extends StatelessWidget {
  /// Creates the pad for [game].
  const NumberPad({required this.game, required this.onHint, super.key});

  /// The game being played.
  final SudokuGame game;

  /// Called when the player asks for a hint.
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Tool(
                  icon: Icons.undo,
                  label: 'Undo',
                  onPressed: game.canUndo ? game.undo : null,
                ),
              ),
              Expanded(
                child: _Tool(
                  icon: Icons.redo,
                  label: 'Redo',
                  onPressed: game.canRedo ? game.redo : null,
                ),
              ),
              Expanded(
                child: _Tool(
                  icon: Icons.backspace_outlined,
                  label: 'Erase',
                  onPressed: game.selected == null ? null : game.erase,
                ),
              ),
              Expanded(
                child: _Tool(
                  icon: game.noteMode ? Icons.edit : Icons.edit_outlined,
                  label: 'Notes',
                  active: game.noteMode,
                  onPressed: game.toggleNoteMode,
                ),
              ),
              Expanded(
                child: _Tool(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint',
                  onPressed: game.isSolved ? null : onHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final digit in digits)
                Expanded(
                  child: _DigitKey(
                    digit: digit,
                    remaining: game.remaining(digit),
                    palette: palette,
                    noteMode: game.noteMode,
                    onPressed: () => game.enter(digit),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = active ? scheme.primary : null;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      child: InkWell(
        key: ValueKey<String>('tool-$label'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: onPressed == null ? scheme.outline : tint),
              const SizedBox(height: 2),
              // Narrow phones leave little room per tool, so the label scales
              // down rather than overflowing the row.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onPressed == null ? scheme.outline : tint,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.remaining,
    required this.palette,
    required this.noteMode,
    required this.onPressed,
  });

  final int digit;
  final int remaining;
  final SudokuPalette palette;
  final bool noteMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A digit that is already placed nine times has nowhere left to go.
    final exhausted = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        label: '$digit, $remaining left',
        child: InkWell(
          key: ValueKey<String>('digit-$digit'),
          onTap: exhausted ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: exhausted
                  ? Colors.transparent
                  : scheme.surfaceContainerHighest,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$digit',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: exhausted
                        ? scheme.outline
                        : noteMode
                            ? palette.note
                            : palette.entry,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exhausted ? '' : '$remaining',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
