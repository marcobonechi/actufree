import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GameStore(await PreferencesStore.open());
  runApp(ActufreeApp(store: store));
}

/// Actufree: a collection of free puzzle games.
class ActufreeApp extends StatelessWidget {
  /// Creates the app.
  const ActufreeApp({required this.store, super.key});

  /// Where games in progress are kept.
  final GameStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Actufree',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(store: store),
    );
  }
}
