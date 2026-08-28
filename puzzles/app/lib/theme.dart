import 'package:chess_engine/chess_engine.dart';
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
    pieces: kOkabeItoPieces,
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
    pieces: kOkabeItoPieces,
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

}


/// Colours the chess board needs.
///
/// Two square colours, two piece colours with an outline each, and the marks
/// the board draws over them. A chess board carries no information in colour
/// at all — the pieces are told apart by shape and the squares by position —
/// so unlike Block Blast this palette has nothing riding on being
/// distinguishable by hue. What it does need is contrast: a piece has to read
/// against both square colours, and the marks have to read over the pieces.
///
/// Hence the outline on both sets of men. A light piece on a light square and
/// a dark piece on a dark square are the two cases that would otherwise go
/// soft, and an outline in the opposite colour fixes both without tinting the
/// board.
@immutable
class ChessPalette extends ThemeExtension<ChessPalette> {
  /// Creates a palette.
  const ChessPalette({
    required this.lightSquare,
    required this.darkSquare,
    required this.whitePiece,
    required this.whitePieceLine,
    required this.blackPiece,
    required this.blackPieceLine,
    required this.selected,
    required this.legalMark,
    required this.lastMove,
    required this.check,
    required this.coordinate,
  });

  /// The light-mode palette.
  static const ChessPalette light = ChessPalette(
    lightSquare: Color(0xFFEDE6D6),
    darkSquare: Color(0xFF8CA789),
    whitePiece: Color(0xFFFCFAF4),
    whitePieceLine: Color(0xFF2A2E33),
    blackPiece: Color(0xFF2B3138),
    blackPieceLine: Color(0xFFF1EEE6),
    selected: Color(0xFF0072B2),
    legalMark: Color(0xFF344049),
    lastMove: Color(0xFFE69F00),
    check: Color(0xFFD55E00),
    coordinate: Color(0xFF4C5A50),
  );

  /// The dark-mode palette.
  ///
  /// The squares come down, but only to the middle. A chess board in the dark
  /// cannot go as dark as the rest of the app does: the men have to read
  /// against it in both colours, so the squares have to sit between them
  /// rather than beside the black ones. Taken any further down, the black
  /// pieces stop being pieces on a board and become outlines on a wall.
  ///
  /// What also has to survive the trip is the gap between the two squares — a
  /// board whose colours have drifted close enough to argue about is a board
  /// nobody can read a diagonal on.
  static const ChessPalette dark = ChessPalette(
    lightSquare: Color(0xFF6B7A70),
    darkSquare: Color(0xFF40504A),
    whitePiece: Color(0xFFF2EFE7),
    whitePieceLine: Color(0xFF14181B),
    blackPiece: Color(0xFF14181C),
    blackPieceLine: Color(0xFFCED6DB),
    selected: Color(0xFF56B4E9),
    legalMark: Color(0xFFDCE3E8),
    lastMove: Color(0xFFE69F00),
    check: Color(0xFFE8703A),
    coordinate: Color(0xFFB6C1BA),
  );

  /// The squares a1 is not.
  final Color lightSquare;

  /// The squares a1 is.
  final Color darkSquare;

  /// The body of a white piece.
  final Color whitePiece;

  /// The line drawn around a white piece.
  final Color whitePieceLine;

  /// The body of a black piece.
  final Color blackPiece;

  /// The line drawn around a black piece.
  final Color blackPieceLine;

  /// The square a player has picked a piece up from.
  final Color selected;

  /// The dot on a square that piece may go to, and the ring around one it may
  /// take on.
  final Color legalMark;

  /// The two squares of the move just played.
  final Color lastMove;

  /// The square of a king in check.
  final Color check;

  /// The file letters and rank numbers along the edge.
  final Color coordinate;

  /// The body colour for a piece of [color].
  Color body(PieceColor color) =>
      color == PieceColor.white ? whitePiece : blackPiece;

  /// The outline colour for a piece of [color].
  Color outline(PieceColor color) =>
      color == PieceColor.white ? whitePieceLine : blackPieceLine;

  @override
  ChessPalette copyWith({
    Color? lightSquare,
    Color? darkSquare,
    Color? whitePiece,
    Color? whitePieceLine,
    Color? blackPiece,
    Color? blackPieceLine,
    Color? selected,
    Color? legalMark,
    Color? lastMove,
    Color? check,
    Color? coordinate,
  }) {
    return ChessPalette(
      lightSquare: lightSquare ?? this.lightSquare,
      darkSquare: darkSquare ?? this.darkSquare,
      whitePiece: whitePiece ?? this.whitePiece,
      whitePieceLine: whitePieceLine ?? this.whitePieceLine,
      blackPiece: blackPiece ?? this.blackPiece,
      blackPieceLine: blackPieceLine ?? this.blackPieceLine,
      selected: selected ?? this.selected,
      legalMark: legalMark ?? this.legalMark,
      lastMove: lastMove ?? this.lastMove,
      check: check ?? this.check,
      coordinate: coordinate ?? this.coordinate,
    );
  }

  @override
  ChessPalette lerp(ThemeExtension<ChessPalette>? other, double t) {
    if (other is! ChessPalette) return this;
    return ChessPalette(
      lightSquare: Color.lerp(lightSquare, other.lightSquare, t)!,
      darkSquare: Color.lerp(darkSquare, other.darkSquare, t)!,
      whitePiece: Color.lerp(whitePiece, other.whitePiece, t)!,
      whitePieceLine: Color.lerp(whitePieceLine, other.whitePieceLine, t)!,
      blackPiece: Color.lerp(blackPiece, other.blackPiece, t)!,
      blackPieceLine: Color.lerp(blackPieceLine, other.blackPieceLine, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      legalMark: Color.lerp(legalMark, other.legalMark, t)!,
      lastMove: Color.lerp(lastMove, other.lastMove, t)!,
      check: Color.lerp(check, other.check, t)!,
      coordinate: Color.lerp(coordinate, other.coordinate, t)!,
    );
  }
}

/// The block colours a board wears until the score moves it on.
///
/// Hoisted out of [BlockColours] because a const field cannot be read from
/// another const expression, and [BlockPalette]'s own defaults want it too.
const List<Color> kOkabeItoPieces = <Color>[
  Color(0xFF0072B2), // blue
  Color(0xFFE69F00), // orange
  Color(0xFF009E73), // bluish green
  Color(0xFFCC79A7), // reddish purple
  Color(0xFF56B4E9), // sky blue
  Color(0xFFD55E00), // vermillion
];

/// One set of block colours.
///
/// A long run spent staring at the same six hues goes stale, so the game moves
/// between sets as the score climbs. What it does *not* move is the board
/// underneath them: the surfaces are what a player's eyes are actually
/// resting on for half an hour, and changing their contrast is how you make a
/// game tiring rather than less so.
///
/// Every set here is a published qualitative scheme designed to stay
/// distinguishable under the common forms of colour blindness. That is the
/// reason these are curated rather than generated: six random hues would look
/// varied and would, sooner or later, deal two pieces nobody could tell apart.
/// Adding a set means finding another scheme with the same property, not
/// inventing one.
///
/// None of them contain a yellow. [BlockPalette.clearFlash] is yellow in every
/// set on purpose — a line going out should mean the same thing whichever
/// colours the board happens to be wearing — and a yellow block would muddy
/// that.
@immutable
class BlockColours {
  /// Names a set of six block colours.
  const BlockColours({required this.name, required this.pieces});

  /// What the set is called. For debugging and tests; never shown.
  final String name;

  /// The six colours, in paint order.
  final List<Color> pieces;

  /// Okabe and Ito's colourblind-safe palette, less its yellow and black.
  static const BlockColours okabeIto = BlockColours(
    name: 'Okabe-Ito',
    pieces: kOkabeItoPieces,
  );

  /// Paul Tol's vibrant scheme: the punchiest of the three.
  static const BlockColours tolVibrant = BlockColours(
    name: 'Tol vibrant',
    pieces: <Color>[
      Color(0xFF0077BB), // blue
      Color(0xFF33BBEE), // cyan
      Color(0xFF009988), // teal
      Color(0xFFEE7733), // orange
      Color(0xFFCC3311), // red
      Color(0xFFEE3377), // magenta
    ],
  );

  /// Paul Tol's muted scheme: the gentlest, and the one a tired pair of eyes
  /// is most glad to arrive at.
  ///
  /// Its indigo is not here. At a luminance of 0.036 it sits within 0.02 of
  /// the dark board's empty cells, where every other colour in every set
  /// clears 0.11 — so on a dark board it was legible by hue alone, which is
  /// precisely the crutch these palettes exist to avoid needing. The blue
  /// comes from Tol's light scheme instead, which is bright enough to survive
  /// being seen in black and white.
  static const BlockColours tolMuted = BlockColours(
    name: 'Tol muted',
    pieces: <Color>[
      Color(0xFF77AADD), // blue
      Color(0xFF88CCEE), // cyan
      Color(0xFF117733), // green
      Color(0xFFCC6677), // rose
      Color(0xFFAA4499), // purple
      Color(0xFF44AA99), // teal
    ],
  );

  /// Every set, in the order the game moves through them.
  static const List<BlockColours> all = <BlockColours>[
    okabeIto,
    tolVibrant,
    tolMuted,
  ];
}

/// How many points between one set of block colours and the next.
///
/// A placement scores about four and a cleared line ten, so this lands
/// somewhere around twenty moves — close enough together that a run of any
/// length sees the board change more than once, which is the whole point of
/// it.
const int kColourInterval = 150;

/// How long the board takes to change its colours.
///
/// Slow enough to read as the light changing rather than as a glitch. Every
/// block on the board changes at once — the board remembers which piece filled
/// a square, not what colour it was — so this wants to be a drift, not a cut.
const Duration kColourDrift = Duration(milliseconds: 1400);

/// The set of block colours a game on [score] is wearing.
///
/// Derived from the score rather than stored, which means a resumed run comes
/// back in the colours it was left in without the save having to carry them.
///
/// The sets rotate rather than being drawn at random. Random would sometimes
/// draw the set already on screen, and a colour change that changes nothing is
/// the one outcome this is meant to avoid.
BlockColours coloursFor(int score) =>
    BlockColours.all[(score ~/ kColourInterval) % BlockColours.all.length];

/// The chess palette for the current theme.
ChessPalette chessPaletteOf(BuildContext context) =>
    Theme.of(context).extension<ChessPalette>() ?? ChessPalette.light;

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
      dark ? ChessPalette.dark : ChessPalette.light,
    ],
  );
}
