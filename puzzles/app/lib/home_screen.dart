import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

import 'sudoku/puzzle_loader.dart';
import 'sudoku/sudoku_screen.dart';

/// The menu. Sudoku is the only game so far.
class HomeScreen extends StatefulWidget {
  /// Creates the menu.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Random _seeds = Random();
  Difficulty? _loading;

  Future<void> _start(Difficulty difficulty) async {
    if (_loading != null) return;
    setState(() => _loading = difficulty);
    final puzzle = await generatePuzzle(difficulty, _seeds.nextInt(1 << 31));
    if (!mounted) return;
    setState(() => _loading = null);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SudokuScreen(puzzle: puzzle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Sudoku',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 32),
                  for (final difficulty in Difficulty.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: FilledButton.tonal(
                        onPressed: _loading == null
                            ? () => _start(difficulty)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: _loading == difficulty
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  difficulty.label,
                                  style: theme.textTheme.titleMedium,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
