import 'dart:async';

import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import '../theme.dart';
import 'board_view.dart';
import 'number_pad.dart';
import 'sudoku_game.dart';

/// Whether to offer the Fill button, which completes the grid bar one cell.
///
/// A testing affordance so a puzzle can be taken to its end state in a tap,
/// rather than a feature anyone would want in a Sudoku app. Flip this to false
/// to remove it.
const bool kShowAutocomplete = true;

/// The playing screen for one puzzle.
class SudokuScreen extends StatefulWidget {
  /// Plays [puzzle], resuming from [resumeFrom] when there is a saved board.
  const SudokuScreen({
    required this.puzzle,
    this.store,
    this.resumeFrom,
    super.key,
  });

  /// The puzzle to play.
  final SudokuPuzzle puzzle;

  /// Where the game in progress is kept. Omitted in tests.
  final GameStore? store;

  /// A board to carry on from, if the player left one behind.
  final SudokuBoard? resumeFrom;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuGame _game =
      SudokuGame(widget.puzzle, board: widget.resumeFrom)
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
    unawaited(_persist());
    if (!_game.isSolved || _announcedWin) return;
    _announcedWin = true;
    // The board finishes mid-build, so the dialog waits for the frame that
    // shows the winning digit before covering it up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showWin();
    });
  }

  /// Writes the game to its difficulty's slot, or clears the slot once the
  /// puzzle is finished — a solved board is not something to resume into.
  Future<void> _persist() async {
    final store = widget.store;
    if (store == null) return;
    final slot = widget.puzzle.difficulty.name;
    if (_game.isSolved) {
      await store.clear('sudoku', slot: slot);
      return;
    }
    await store.save(
      SudokuSave(puzzle: widget.puzzle, board: _game.board),
      slot: slot,
    );
  }

  Future<void> _showWin() async {
    // Thrown before the dialog goes up, so the colour is already in the air
    // behind it rather than arriving after the player has read the news.
    CelebrationScope.maybeOf(context)?.fountain(colors: kOkabeItoPieces);
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
              final pad = NumberPad(
                game: _game,
                onHint: _onHint,
                onAutocomplete: kShowAutocomplete ? _game.autocomplete : null,
              );
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
