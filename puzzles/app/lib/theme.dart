import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

/// Colours the Sudoku board needs that a [ColorScheme] has no name for.
///
/// Hues are taken from the Okabe-Ito palette, which stays distinguishable
/// under the common forms of colour blindness — so a conflict never reads as
/// "the red one" and a player entry never reads as "the green one".
///
/// This stays in the app: the colours a Sudoku board needs — a clue, a player
/// entry, a conflict — are not the colours Block Blast will need, so the
/// shared layer supplies the theme and each game supplies its own palette.
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
    required this.completed,
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
    completed: Color(0xFF009E73),
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
    completed: Color(0xFF4FD1A5),
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

  /// The flash over a row, column or box that has just been completed.
  ///
  /// A bluish green from the same colourblind-safe family as the rest: it
  /// reads as distinct from both the blue of a player entry and the vermillion
  /// of a mistake under the common forms of colour blindness.
  final Color completed;

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
    Color? completed,
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
      completed: completed ?? this.completed,
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
      completed: Color.lerp(completed, other.completed, t)!,
    );
  }
}

/// Colours the Block Blast board needs.
///
/// Six piece colours, plus the surfaces around them. The six are the same
/// Okabe-Ito hues Sudoku draws from, chosen so two pieces sitting side by side
/// stay distinguishable under the common forms of colour blindness — which
/// matters more here than it does in Sudoku, where colour never carries a
/// rule. Here it is the only thing separating one block from its neighbour.
///
/// The engine paints a cell with a number in `1..paintCount` and knows nothing
/// more about it. [pieceColor] is where that number becomes a colour.
@immutable
class BlockPalette extends ThemeExtension<BlockPalette> {
  /// Creates a palette.
  const BlockPalette({
    required this.pieces,
    required this.emptyCell,
    required this.boardSurface,
    required this.ghost,
    required this.clearFlash,
    required this.deadPiece,
  });

  /// The light-mode palette.
  static const BlockPalette light = BlockPalette(
    pieces: _okabeIto,
    emptyCell: Color(0xFFE7EDF3),
    boardSurface: Color(0xFFF4F7FA),
    ghost: Color(0xFF44505C),
    clearFlash: Color(0xFFF0E442),
    deadPiece: Color(0xFF9AA6B2),
  );

  /// The dark-mode palette.
  ///
  /// The pieces keep their hues: they are the game's vocabulary, and a player
  /// who learns that the long bar is usually blue should not have to relearn
  /// it after sunset. Only what sits behind them changes.
  static const BlockPalette dark = BlockPalette(
    pieces: _okabeIto,
    emptyCell: Color(0xFF20272E),
    boardSurface: Color(0xFF161C22),
    ghost: Color(0xFFB9C4CF),
    clearFlash: Color(0xFFF0E442),
    deadPiece: Color(0xFF5A6672),
  );

  /// The colour of each paint value, from `1` upwards.
  final List<Color> pieces;

  /// A square with nothing on it.
  final Color emptyCell;

  /// Behind the whole board.
  final Color boardSurface;

  /// The outline drawn around where a dragged piece would land.
  ///
  /// Neutral rather than the piece's own colour: the landing is filled in
  /// that colour already, and an outline of the same hue would disappear
  /// into it.
  final Color ghost;

  /// The flash over a row or column on its way out.
  final Color clearFlash;

  /// A piece in the tray that no longer fits anywhere.
  final Color deadPiece;

  /// The colour for [paint], the number the engine put in a cell.
  ///
  /// Wraps rather than throwing on a value from outside the palette: a save
  /// written by a future version with more colours should look odd, not crash.
  Color pieceColor(int paint) => pieces[(paint - 1) % pieces.length];

  @override
  BlockPalette copyWith({
    List<Color>? pieces,
    Color? emptyCell,
    Color? boardSurface,
    Color? ghost,
    Color? clearFlash,
    Color? deadPiece,
  }) {
    return BlockPalette(
      pieces: pieces ?? this.pieces,
      emptyCell: emptyCell ?? this.emptyCell,
      boardSurface: boardSurface ?? this.boardSurface,
      ghost: ghost ?? this.ghost,
      clearFlash: clearFlash ?? this.clearFlash,
      deadPiece: deadPiece ?? this.deadPiece,
    );
  }

  @override
  BlockPalette lerp(ThemeExtension<BlockPalette>? other, double t) {
    if (other is! BlockPalette) return this;
    return BlockPalette(
      pieces: <Color>[
        for (var i = 0; i < pieces.length; i++)
          Color.lerp(pieces[i], other.pieces[i], t)!,
      ],
      emptyCell: Color.lerp(emptyCell, other.emptyCell, t)!,
      boardSurface: Color.lerp(boardSurface, other.boardSurface, t)!,
      ghost: Color.lerp(ghost, other.ghost, t)!,
      clearFlash: Color.lerp(clearFlash, other.clearFlash, t)!,
      deadPiece: Color.lerp(deadPiece, other.deadPiece, t)!,
    );
  }

  /// Six of the eight Okabe-Ito hues. The palette's yellow and black are left
  /// out: yellow is spoken for by [clearFlash], and black is not a block.
  static const List<Color> _okabeIto = <Color>[
    Color(0xFF0072B2), // blue
    Color(0xFFE69F00), // orange
    Color(0xFF009E73), // bluish green
    Color(0xFFCC79A7), // reddish purple
    Color(0xFF56B4E9), // sky blue
    Color(0xFFD55E00), // vermillion
  ];
}

/// The Block Blast palette for the current theme.
BlockPalette blockPaletteOf(BuildContext context) =>
    Theme.of(context).extension<BlockPalette>() ?? BlockPalette.light;

/// The palette for the current theme.
SudokuPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<SudokuPalette>() ?? SudokuPalette.light;

/// The Actufree theme for [brightness]: the shared scaffolding plus each
/// game's board colours.
ThemeData actufreeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return buildTheme(
    brightness: brightness,
    extensions: <ThemeExtension<dynamic>>[
      dark ? SudokuPalette.dark : SudokuPalette.light,
      dark ? BlockPalette.dark : BlockPalette.light,
    ],
  );
}
