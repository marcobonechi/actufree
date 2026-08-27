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
  );
}
