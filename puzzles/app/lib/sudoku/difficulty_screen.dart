import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import 'puzzle_loader.dart';
import 'sudoku_screen.dart';

/// Difficulty picker for Sudoku, and the way back into an unfinished game.
class DifficultyScreen extends StatefulWidget {
  /// Creates the picker.
  const DifficultyScreen({required this.store, super.key});

  /// Where games in progress are kept.
  final GameStore store;

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  final Random _seeds = Random();
  Difficulty? _busy;
  Map<Difficulty, bool> _resumable = <Difficulty, bool>{};

  static const Map<Difficulty, String> _blurbs = <Difficulty, String>{
    Difficulty.easy: 'Singles only',
    Difficulty.medium: 'Pairs, triples and locked candidates',
    Difficulty.hard: 'Wings and fish',
    Difficulty.expert: 'Colouring chains',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final found = <Difficulty, bool>{};
    for (final difficulty in Difficulty.values) {
      found[difficulty] =
          await widget.store.has('sudoku', slot: difficulty.name);
    }
    if (mounted) setState(() => _resumable = found);
  }

  Future<void> _open(Difficulty difficulty, {required bool fresh}) async {
    if (_busy != null) return;
    setState(() => _busy = difficulty);
    SudokuSave? save;
    if (!fresh) {
      save = await widget.store
          .load('sudoku', SudokuSave.fromJson, slot: difficulty.name);
    }
    final puzzle = save?.puzzle ??
        await generatePuzzle(difficulty, _seeds.nextInt(1 << 31));
    if (!mounted) return;
    setState(() => _busy = null);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SudokuScreen(
          puzzle: puzzle,
          store: widget.store,
          resumeFrom: save?.board,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                for (final difficulty in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonal(
                            key: ValueKey<String>(
                              'difficulty-${difficulty.name}',
                            ),
                            onPressed: _busy != null
                                ? null
                                : () => _open(difficulty, fresh: false),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _busy == difficulty
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Column(
                                      children: <Widget>[
                                        Text(
                                          difficulty.label,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        Text(
                                          _resumable[difficulty] ?? false
                                              ? 'Continue'
                                              : _blurbs[difficulty]!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        // Only offered when there is a game to throw away, so
                        // "New" never sits next to a button that already
                        // starts a new one.
                        if (_resumable[difficulty] ?? false)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton.outlined(
                              key: ValueKey<String>('new-${difficulty.name}'),
                              tooltip: 'New ${difficulty.label} puzzle',
                              icon: const Icon(Icons.add),
                              onPressed: _busy != null
                                  ? null
                                  : () => _open(difficulty, fresh: true),
                            ),
                          ),
                      ],
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
