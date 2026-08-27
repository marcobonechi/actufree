import 'package:flutter/material.dart';

/// Colours the Sudoku board needs that a [ColorScheme] has no name for.
///
/// Hues are taken from the Okabe-Ito palette, which stays distinguishable
/// under the common forms of colour blindness — so a conflict never reads as
/// "the red one" and a player entry never reads as "the green one".
///
/// This lives in the app for now. It moves to `puzzle_kit` once a second game
/// needs it.
@immutable
class SudokuPalette extends ThemeExtension<SudokuPalette> {
  /// Creates a palette.
  const SudokuPalette({
    required this.given,
    required this.entry,
    required this.conflict,
    required this.conflictSurface,
    required this.selectedSurface,
    required this.peerSurface,
    required this.matchSurface,
    required this.note,
    required this.gridLine,
    required this.boxLine,
  });

  /// The light-mode palette.
  static const SudokuPalette light = SudokuPalette(
    given: Color(0xFF1A1C1E),
    entry: Color(0xFF0072B2),
    conflict: Color(0xFFD55E00),
    conflictSurface: Color(0xFFFBE4D5),
    selectedSurface: Color(0xFFCFE3F5),
    peerSurface: Color(0xFFEDF2F7),
    matchSurface: Color(0xFFDCE9F5),
    note: Color(0xFF5F6B76),
    gridLine: Color(0xFFC9D1D9),
    boxLine: Color(0xFF44505C),
  );

  /// The dark-mode palette.
  static const SudokuPalette dark = SudokuPalette(
    given: Color(0xFFE3E6E9),
    entry: Color(0xFF56B4E9),
    conflict: Color(0xFFE69F00),
    conflictSurface: Color(0xFF4A3520),
    selectedSurface: Color(0xFF29465E),
    peerSurface: Color(0xFF1E262E),
    matchSurface: Color(0xFF24384A),
    note: Color(0xFF97A3AF),
    gridLine: Color(0xFF333C45),
    boxLine: Color(0xFF8A97A4),
  );

  /// A clue the player may not change.
  final Color given;

  /// A digit the player entered.
  final Color entry;

  /// A digit that duplicates one of its peers.
  final Color conflict;

  /// The background behind a conflicting cell.
  final Color conflictSurface;

  /// The background behind the selected cell.
  final Color selectedSurface;

  /// The background behind the selected cell's row, column and box.
  final Color peerSurface;

  /// The background behind cells holding the same digit as the selection.
  final Color matchSurface;

  /// Pencil marks.
  final Color note;

  /// The hairline between neighbouring cells.
  final Color gridLine;

  /// The heavier line between boxes.
  final Color boxLine;

  @override
  SudokuPalette copyWith({
    Color? given,
    Color? entry,
    Color? conflict,
    Color? conflictSurface,
    Color? selectedSurface,
    Color? peerSurface,
    Color? matchSurface,
    Color? note,
    Color? gridLine,
    Color? boxLine,
  }) {
    return SudokuPalette(
      given: given ?? this.given,
      entry: entry ?? this.entry,
      conflict: conflict ?? this.conflict,
      conflictSurface: conflictSurface ?? this.conflictSurface,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      peerSurface: peerSurface ?? this.peerSurface,
      matchSurface: matchSurface ?? this.matchSurface,
      note: note ?? this.note,
      gridLine: gridLine ?? this.gridLine,
      boxLine: boxLine ?? this.boxLine,
    );
  }

  @override
  SudokuPalette lerp(ThemeExtension<SudokuPalette>? other, double t) {
    if (other is! SudokuPalette) return this;
    return SudokuPalette(
      given: Color.lerp(given, other.given, t)!,
      entry: Color.lerp(entry, other.entry, t)!,
      conflict: Color.lerp(conflict, other.conflict, t)!,
      conflictSurface: Color.lerp(conflictSurface, other.conflictSurface, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      peerSurface: Color.lerp(peerSurface, other.peerSurface, t)!,
      matchSurface: Color.lerp(matchSurface, other.matchSurface, t)!,
      note: Color.lerp(note, other.note, t)!,
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      boxLine: Color.lerp(boxLine, other.boxLine, t)!,
    );
  }
}

/// The palette for the current theme.
SudokuPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<SudokuPalette>() ?? SudokuPalette.light;

/// Builds the app theme for [brightness].
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0072B2),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: <ThemeExtension<dynamic>>[
      brightness == Brightness.dark ? SudokuPalette.dark : SudokuPalette.light,
    ],
  );
}
