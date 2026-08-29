import 'dart:async';

import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'blockblast/block_screen.dart';
import 'chess/chess_start_screen.dart';
import 'sudoku/difficulty_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await PreferencesStore.open();
  runApp(
    ActufreeApp(
      store: GameStore(storage),
      scores: BestScores(storage),
      settings: await SettingsController.load(storage),
      cheers: CelebrationCue(),
    ),
  );
}

/// Actufree: a collection of free puzzle games.
class ActufreeApp extends StatelessWidget {
  /// Creates the app.
  const ActufreeApp({
    required this.store,
    required this.scores,
    required this.settings,
    required this.cheers,
    super.key,
  });

  /// Where games in progress are kept.
  final GameStore store;

  /// Where best scores are kept.
  final BestScores scores;

  /// The player's preferences.
  final SettingsController settings;

  /// Where a game asks for a celebration.
  final CelebrationCue cheers;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) => MaterialApp(
        title: 'Actufree',
        debugShowCheckedModeBanner: false,
        // One backdrop behind the whole app rather than one per screen: it
        // stays put across route transitions, which is what makes it read as
        // the app's surface rather than as decoration on a particular page.
        builder: (BuildContext context, Widget? child) => PuzzleBackdrop(
          // The celebration wraps everything the navigator draws, so colour
          // thrown at a win lands over the app bar and the dialog announcing
          // it rather than being trapped inside one screen's body.
          child: CelebrationScope(
            cue: cheers,
            child: CelebrationLayer(
              cue: cheers,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        theme: actufreeTheme(Brightness.light),
        darkTheme: actufreeTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: HomeMenu(
          title: 'Actufree',
          tagline: 'Free puzzles. No ads, no accounts, nothing collected.',
          settings: settings,
          games: <GameEntry>[
            GameEntry(
              title: 'Sudoku',
              subtitle: 'Fill the grid, one to nine',
              icon: Icons.grid_3x3,
              onOpen: (BuildContext context) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      DifficultyScreen(store: store),
                ),
              ),
            ),
            GameEntry(
              title: 'Block Blast',
              subtitle: 'Drop shapes, clear lines, last as long as you can',
              icon: Icons.grid_view,
              onOpen: (BuildContext context) => unawaited(
                openBlockBlast(context, store: store, scores: scores),
              ),
            ),
            GameEntry(
              title: 'Chess',
              subtitle: 'Two players on one board, or take on the computer',
              icon: Icons.castle,
              onOpen: (BuildContext context) =>
                  unawaited(openChess(context, store: store)),
            ),
          ],
        ),
      ),
    );
  }
}
