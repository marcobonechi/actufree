import 'dart:typed_data';

import 'cell.dart';
import 'tables.dart';

/// The state of one Sudoku grid: the clues, the player's entries, and the
/// player's pencil marks.
///
/// Boards are immutable. Every mutating method returns a new board and leaves
/// the receiver untouched, which is what makes the undo stack in `puzzle_kit`
/// a matter of holding onto old values.
final class SudokuBoard {
  /// The given flags are never mutated after construction, so boards derived
  /// from one another share the same array.
  const SudokuBoard._(this._values, this._notes, this._given);

  /// An entirely empty board with no givens.
  factory SudokuBoard.empty() => SudokuBoard._(
        Int8List(cellCount),
        Uint16List(cellCount),
        Uint8List(cellCount),
      );

  /// A board whose clues are [givens], with no entries and no pencil marks.
  ///
  /// [givens] must have [cellCount] elements; `null` marks an empty cell.
  factory SudokuBoard.fromGivens(List<int?> givens) {
    if (givens.length != cellCount) {
      throw ArgumentError.value(
        givens.length,
        'givens',
        'expected $cellCount entries',
      );
    }
    final values = Int8List(cellCount);
    final given = Uint8List(cellCount);
    for (var index = 0; index < cellCount; index++) {
      final digit = givens[index];
      if (digit == null) continue;
      RangeError.checkValueInInterval(digit, 1, boardSize, 'givens[$index]');
      values[index] = digit;
      given[index] = 1;
    }
    return SudokuBoard._(values, Uint16List(cellCount), given);
  }

  /// Parses 81 characters of `1`-`9`, treating `.`, `0` and `-` as empty.
  ///
  /// Whitespace is ignored, so multi-line grids parse as written. Every filled
  /// cell becomes a given.
  factory SudokuBoard.parse(String source) {
    final cleaned = source.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length != cellCount) {
      throw FormatException(
        'expected $cellCount cells, found ${cleaned.length}',
        source,
      );
    }
    final givens = List<int?>.filled(cellCount, null);
    for (var index = 0; index < cellCount; index++) {
      final char = cleaned[index];
      if (char == '.' || char == '0' || char == '-') continue;
      final digit = int.tryParse(char);
      if (digit == null || digit < 1 || digit > boardSize) {
        throw FormatException('unexpected character "$char"', source, index);
      }
      givens[index] = digit;
    }
    return SudokuBoard.fromGivens(givens);
  }

  /// Restores a board previously written by [toJson].
  factory SudokuBoard.fromJson(Map<String, Object?> json) {
    final givens = _requireGrid(json, 'givens');
    final entries = _requireGrid(json, 'entries');
    final values = Int8List(cellCount);
    final given = Uint8List(cellCount);
    for (var index = 0; index < cellCount; index++) {
      final clue = _digitOrZero(givens[index]);
      if (clue != 0) {
        values[index] = clue;
        given[index] = 1;
        continue;
      }
      values[index] = _digitOrZero(entries[index]);
    }
    final notes = Uint16List(cellCount);
    final raw = json['notes'];
    if (raw != null) {
      if (raw is! Map<String, Object?>) {
        throw const FormatException('"notes" must be an object');
      }
      raw.forEach((key, value) {
        final index = int.tryParse(key);
        if (index == null || index < 0 || index >= cellCount) {
          throw FormatException('bad note index "$key"');
        }
        if (value is! List<Object?>) {
          throw FormatException('notes for "$key" must be a list');
        }
        var mask = 0;
        for (final entry in value) {
          if (entry is! int || entry < 1 || entry > boardSize) {
            throw FormatException('bad note digit in "$key"');
          }
          mask |= maskOf(entry);
        }
        notes[index] = mask;
      });
    }
    return SudokuBoard._(values, notes, given);
  }

  final Int8List _values;
  final Uint16List _notes;
  final Uint8List _given;

  /// The digit in [cell], whether it is a given or a player entry.
  int? valueAt(Cell cell) {
    final digit = _values[cell.index];
    return digit == 0 ? null : digit;
  }

  /// Whether [cell] holds a clue, which the player may not change.
  bool isGiven(Cell cell) => _given[cell.index] == 1;

  /// The player's pencil marks for [cell].
  ///
  /// These are notes the player has written, not a deduction — see
  /// [legalDigitsAt] for what the rules currently allow.
  Set<int> notesAt(Cell cell) => digitsOf(_notes[cell.index]).toSet();

  /// The digits that could legally go in [cell] given the digits already on
  /// the board.
  ///
  /// Returns an empty set for a filled cell.
  Set<int> legalDigitsAt(Cell cell) {
    if (_values[cell.index] != 0) return const <int>{};
    var mask = allDigitsMask;
    for (final peer in cellPeers[cell.index]) {
      final digit = _values[peer];
      if (digit != 0) mask &= ~maskOf(digit);
    }
    return digitsOf(mask).toSet();
  }

  /// Whether writing [digit] into [cell] would leave the board consistent.
  bool isLegal(Cell cell, int digit) {
    if (digit < 1 || digit > boardSize) return false;
    for (final peer in cellPeers[cell.index]) {
      if (_values[peer] == digit) return false;
    }
    return true;
  }

  /// Every cell whose digit duplicates another digit in its row, column or
  /// box.
  ///
  /// Empty on a consistent board. Both members of a clashing pair appear.
  Set<Cell> get conflicts {
    final result = <Cell>{};
    for (var index = 0; index < cellCount; index++) {
      final digit = _values[index];
      if (digit == 0) continue;
      for (final peer in cellPeers[index]) {
        if (_values[peer] != digit) continue;
        result.add(Cell.fromIndex(index));
        result.add(Cell.fromIndex(peer));
      }
    }
    return result;
  }

  /// Whether every cell holds a digit, regardless of correctness.
  bool get isComplete {
    for (var index = 0; index < cellCount; index++) {
      if (_values[index] == 0) return false;
    }
    return true;
  }

  /// Whether every cell holds a digit and no cell conflicts.
  bool get isSolved => isComplete && conflicts.isEmpty;

  /// The cells that are still empty, in index order.
  List<Cell> get emptyCells {
    final result = <Cell>[];
    for (var index = 0; index < cellCount; index++) {
      if (_values[index] == 0) result.add(Cell.fromIndex(index));
    }
    return result;
  }

  /// This board with [digit] written into [cell], or cleared when [digit] is
  /// `null`.
  ///
  /// Clears the cell's pencil marks. Throws [StateError] if [cell] is a given.
  /// Performs no legality check: use [MoveValidator] to decide whether the
  /// move should be offered, and this to apply it.
  SudokuBoard withValue(Cell cell, int? digit) {
    _refuseGiven(cell, 'change');
    if (digit != null) {
      RangeError.checkValueInInterval(digit, 1, boardSize, 'digit');
    }
    final values = Int8List.fromList(_values);
    values[cell.index] = digit ?? 0;
    final notes = Uint16List.fromList(_notes);
    notes[cell.index] = 0;
    return SudokuBoard._(values, notes, _given);
  }

  /// This board with [digit] added to or removed from [cell]'s pencil marks.
  ///
  /// Throws [StateError] if [cell] is a given or already holds a digit.
  SudokuBoard withNoteToggled(Cell cell, int digit) {
    _refuseGiven(cell, 'annotate');
    RangeError.checkValueInInterval(digit, 1, boardSize, 'digit');
    if (_values[cell.index] != 0) {
      throw StateError('$cell already holds a digit');
    }
    final notes = Uint16List.fromList(_notes);
    notes[cell.index] ^= maskOf(digit);
    return SudokuBoard._(_values, notes, _given);
  }

  /// This board with [cell]'s pencil marks removed.
  SudokuBoard withNotesCleared(Cell cell) {
    if (_notes[cell.index] == 0) return this;
    final notes = Uint16List.fromList(_notes);
    notes[cell.index] = 0;
    return SudokuBoard._(_values, notes, _given);
  }

  /// This board with every player entry and pencil mark removed, keeping the
  /// givens.
  SudokuBoard reset() {
    final values = Int8List(cellCount);
    for (var index = 0; index < cellCount; index++) {
      if (_given[index] == 1) values[index] = _values[index];
    }
    return SudokuBoard._(values, Uint16List(cellCount), _given);
  }

  /// The 81 digits as characters, using `.` for empty cells.
  ///
  /// Drops the given/entry distinction and the pencil marks; round-trips
  /// through [SudokuBoard.parse] only for boards that are all givens.
  String toCompactString() {
    final buffer = StringBuffer();
    for (var index = 0; index < cellCount; index++) {
      final digit = _values[index];
      buffer.write(digit == 0 ? '.' : digit);
    }
    return buffer.toString();
  }

  /// A lossless representation, including entries and pencil marks.
  Map<String, Object?> toJson() {
    final givens = StringBuffer();
    final entries = StringBuffer();
    final notes = <String, List<int>>{};
    for (var index = 0; index < cellCount; index++) {
      final isClue = _given[index] == 1;
      final digit = _values[index];
      givens.write(isClue ? digit : '.');
      entries.write(!isClue && digit != 0 ? digit : '.');
      if (_notes[index] != 0) notes['$index'] = digitsOf(_notes[index]);
    }
    return <String, Object?>{
      'version': 1,
      'givens': givens.toString(),
      'entries': entries.toString(),
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SudokuBoard) return false;
    for (var index = 0; index < cellCount; index++) {
      if (_values[index] != other._values[index]) return false;
      if (_notes[index] != other._notes[index]) return false;
      if (_given[index] != other._given[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(_values),
        Object.hashAll(_notes),
        Object.hashAll(_given),
      );

  @override
  String toString() => toCompactString();

  void _refuseGiven(Cell cell, String verb) {
    if (_given[cell.index] == 1) {
      throw StateError('cannot $verb $cell: it is a given');
    }
  }

  static String _requireGrid(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.length != cellCount) {
      throw FormatException('"$key" must be $cellCount characters');
    }
    return value;
  }

  static int _digitOrZero(String char) {
    if (char == '.') return 0;
    final digit = int.tryParse(char);
    if (digit == null || digit < 1 || digit > boardSize) {
      throw FormatException('unexpected character "$char"');
    }
    return digit;
  }
}
