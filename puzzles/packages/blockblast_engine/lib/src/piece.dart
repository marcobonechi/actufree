import 'shape.dart';

/// A shape as dealt to the player: what it looks like, and its colour.
///
/// [paint] is an opaque number in `1..paintCount`. The engine assigns it and
/// never interprets it; the board keeps it so a cleared line can be told apart
/// from its neighbours, and the drawing code decides what colour it is.
final class BlockPiece {
  /// A piece of [shape] painted [paint].
  const BlockPiece(this.shape, this.paint);

  /// Restores a piece previously written by [toJson].
  factory BlockPiece.fromJson(Map<String, Object?> json) {
    final shape = json['shape'];
    final paint = json['paint'];
    if (shape is! List<Object?> || paint is! int) {
      throw const FormatException('malformed piece');
    }
    return BlockPiece(BlockShape.fromJson(shape), paint);
  }

  /// The shape to place.
  final BlockShape shape;

  /// Which colour it was dealt in.
  final int paint;

  /// The piece as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'shape': shape.toJson(),
        'paint': paint,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockPiece && other.shape == shape && other.paint == paint;

  @override
  int get hashCode => Object.hash(shape, paint);

  @override
  String toString() => 'BlockPiece($shape, paint: $paint)';
}
