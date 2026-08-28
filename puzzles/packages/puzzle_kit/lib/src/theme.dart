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
  final base = ThemeData(
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
  // Tuned from the resolved theme rather than passed in, so it is applied on
  // top of whichever face the platform supplies.
  return base.copyWith(textTheme: tunedTextTheme(base.textTheme));
}

/// [base] with a hand set weight and tracking.
///
/// The app ships no font of its own — Android draws it in Roboto and iOS in
/// San Francisco, each of which is the right thing on its own platform. What
/// it can do is choose how that face is *set*, and that is most of what
/// separates typography somebody picked from typography nobody touched.
///
/// Two changes, both aimed at the same tell. Material's scale sets every
/// display and headline size at regular weight, so a screen's largest text
/// carries no more emphasis than its body text and the hierarchy has to be
/// done entirely with size. And it tracks those sizes at zero, where large
/// text wants tightening — letters set at 36pt sit further apart, optically,
/// than the same letters at 14pt.
///
/// Body sizes keep their weight and lose only a little of their tracking:
/// Material's positive tracking there is doing real work at small sizes, and
/// tightening it would cost legibility for a look.
TextTheme tunedTextTheme(TextTheme base) {
  TextStyle? weigh(TextStyle? style, FontWeight weight, double tracking) =>
      style?.copyWith(fontWeight: weight, letterSpacing: tracking);

  return base.copyWith(
    displayLarge: weigh(base.displayLarge, FontWeight.w700, -1),
    displayMedium: weigh(base.displayMedium, FontWeight.w700, -0.8),
    displaySmall: weigh(base.displaySmall, FontWeight.w700, -0.6),
    headlineLarge: weigh(base.headlineLarge, FontWeight.w600, -0.5),
    headlineMedium: weigh(base.headlineMedium, FontWeight.w600, -0.4),
    headlineSmall: weigh(base.headlineSmall, FontWeight.w600, -0.3),
    titleLarge: weigh(base.titleLarge, FontWeight.w600, -0.2),
    titleMedium: weigh(base.titleMedium, FontWeight.w600, 0),
    titleSmall: weigh(base.titleSmall, FontWeight.w600, 0),
    labelLarge: weigh(base.labelLarge, FontWeight.w600, 0),
    labelMedium: weigh(base.labelMedium, FontWeight.w600, 0.2),
    labelSmall: weigh(base.labelSmall, FontWeight.w600, 0.2),
    bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0.1),
    bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0.1),
    bodySmall: base.bodySmall?.copyWith(letterSpacing: 0.1),
  );
}

/// Digits that hold their width, whatever digits they are.
///
/// For a number that changes while the player is looking at it. Proportional
/// figures are drawn to their own widths — a 1 is narrower than a 0 — so a
/// score counting up shuffles sideways on every clear, and a column of counts
/// under a number pad fails to line up. Both Roboto and San Francisco carry
/// the tabular set; this asks for it.
TextStyle? tabularFigures(TextStyle? style) => style?.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

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
