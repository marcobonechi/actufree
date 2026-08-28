import 'piece.dart';
import 'search.dart';

/// Who the second player is.
///
/// Either the person holding the other side of the phone, or the computer at
/// one of its levels. This is not part of the rules — the board plays the same
/// either way — but it is part of the game as far as the player is concerned,
/// which is why it is saved alongside it rather than left in the screen that
/// happened to start it.
final class Opponent {
  /// Two people at one board.
  const Opponent.twoPlayers()
      : level = null,
        plays = null;

  /// The computer at [level], playing [plays].
  const Opponent.computer({required BotLevel this.level, required PieceColor this.plays});

  /// Restores an opponent previously written by [toJson].
  factory Opponent.fromJson(Map<String, Object?> json) {
    final level = json['level'];
    final plays = json['plays'];
    if (level is! String || plays is! String) {
      throw const FormatException('malformed opponent');
    }
    return Opponent.computer(
      level: BotLevel.values.firstWhere(
        (BotLevel candidate) => candidate.name == level,
        orElse: () => throw FormatException('unknown level', level),
      ),
      plays: plays == PieceColor.white.name ? PieceColor.white : PieceColor.black,
    );
  }

  /// How hard the computer plays, or `null` when there is no computer.
  final BotLevel? level;

  /// Which side the computer takes, or `null` when there is no computer.
  final PieceColor? plays;

  /// Whether one of the two sides is being played by the computer.
  bool get isComputer => level != null;

  /// Whether the computer is playing [color].
  bool controls(PieceColor color) => plays == color;

  /// The side the person is playing, or `null` in a game between two people.
  PieceColor? get human => plays?.opponent;

  /// What to call this opponent.
  String get label => isComputer ? 'Computer (${level!.label})' : 'Two players';

  /// The opponent as JSON, or `null` for two players — the absence of the
  /// field is what a game between two people looks like, which is also what
  /// every save written before there was a computer looks like.
  Map<String, Object?>? toJson() => isComputer
      ? <String, Object?>{'level': level!.name, 'plays': plays!.name}
      : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Opponent && other.level == level && other.plays == plays;

  @override
  int get hashCode => Object.hash(level, plays);

  @override
  String toString() => label;
}
