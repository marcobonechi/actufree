import 'package:flutter/material.dart';

/// Builds an app theme for [brightness].
///
/// Games layer their own colours on top through [extensions]: the board
/// colours Sudoku needs have no name in a [ColorScheme], and the ones Block
/// Blast will need are different again, so the shared layer supplies the
/// scaffolding and each game supplies its own palette.
ThemeData buildTheme({
  required Brightness brightness,
  Color seedColor = const Color(0xFF0072B2),
  List<ThemeExtension<dynamic>> extensions =
      const <ThemeExtension<dynamic>>[],
}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    useMaterial3: true,
    extensions: extensions,
    // The backdrop is painted once behind the whole app by [PuzzleBackdrop],
    // so the scaffold and the app bar get out of its way rather than each
    // laying a flat panel over the top of it.
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

/// The wash that sits behind every screen.
///
/// Diagonal rather than straight down, and only a few levels of lightness from
/// end to end. The point is to stop a screen reading as a flat sheet of one
/// colour, not to be noticed: a board is a grid of coloured squares and a
/// background with opinions would be competing with it all game.
///
/// Derived from [scheme] rather than written out, so it follows the seed
/// colour and both brightnesses without a second set of constants to keep in
/// step.
Gradient backdropGradient(ColorScheme scheme) {
  final surface = scheme.surface;
  final dark = scheme.brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const <double>[0, 0.45, 1],
    colors: <Color>[
      // Light lifts towards white at the top and settles into a hint of the
      // seed at the bottom. Dark does the opposite, since a dark screen that
      // gets lighter towards the bottom looks upside down.
      Color.lerp(surface, dark ? scheme.primary : Colors.white, dark ? 0.09 : 0.7)!,
      surface,
      Color.lerp(surface, dark ? Colors.black : scheme.primary, dark ? 0.4 : 0.09)!,
    ],
  );
}

/// Paints [backdropGradient] behind [child].
///
/// Meant to wrap the whole app through `MaterialApp.builder`, so every screen
/// and every game sits on the same backdrop and none of them has to remember
/// to ask for it.
class PuzzleBackdrop extends StatelessWidget {
  /// Puts the backdrop behind [child].
  const PuzzleBackdrop({required this.child, super.key});

  /// What sits on the backdrop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: backdropGradient(Theme.of(context).colorScheme),
      ),
      child: child,
    );
  }
}
