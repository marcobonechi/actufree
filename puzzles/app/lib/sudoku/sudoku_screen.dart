import 'package:flutter/material.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import 'board_view.dart';
import 'number_pad.dart';
import 'sudoku_game.dart';

/// The playing screen for one puzzle.
class SudokuScreen extends StatefulWidget {
  /// Plays [puzzle].
  const SudokuScreen({required this.puzzle, super.key});

  /// The puzzle to play.
  final SudokuPuzzle puzzle;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuGame _game = SudokuGame(widget.puzzle)
    ..addListener(_onGameChanged);
  bool _announcedWin = false;

  @override
  void dispose() {
    _game
      ..removeListener(_onGameChanged)
      ..dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!_game.isSolved || _announcedWin) return;
    _announcedWin = true;
    // The board finishes mid-build, so the dialog waits for the frame that
    // shows the winning digit before covering it up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showWin();
    });
  }

  Future<void> _showWin() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Solved'),
        content: Text(
          '${widget.puzzle.difficulty.label} puzzle, '
          '${widget.puzzle.clueCount} clues.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context)
                ..pop()
                ..pop();
            },
            child: const Text('Back to menu'),
          ),
        ],
      ),
    );
  }

  void _onHint() {
    final result = _game.requestHint();
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (result.label != null)
              Text(
                result.label!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            Text(result.message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.puzzle.difficulty.label),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart',
            onPressed: () {
              _announcedWin = false;
              _game.restart();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _game,
          builder: (BuildContext context, _) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final board = Padding(
                padding: const EdgeInsets.all(10),
                child: SudokuBoardView(game: _game),
              );
              final pad = NumberPad(game: _game, onHint: _onHint);
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  children: <Widget>[
                    Expanded(child: Center(child: board)),
                    Expanded(child: Center(child: pad)),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  Flexible(child: Center(child: board)),
                  pad,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
