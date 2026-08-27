import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'sudoku/difficulty_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await PreferencesStore.open();
  runApp(
    ActufreeApp(
      store: GameStore(storage),
      settings: await SettingsController.load(storage),
    ),
  );
}

/// Actufree: a collection of free puzzle games.
class ActufreeApp extends StatelessWidget {
  /// Creates the app.
  const ActufreeApp({required this.store, required this.settings, super.key});

  /// Where games in progress are kept.
  final GameStore store;

  /// The player's preferences.
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) => MaterialApp(
        title: 'Actufree',
        debugShowCheckedModeBanner: false,
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
          ],
        ),
      ),
    );
  }
}
