import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'piece_view.dart';

/// How long the piece takes to reach the cell it has snapped to.
///
/// Short enough that it never feels like it is being dragged through
/// treacle, long enough that the movement between cells reads as movement
/// rather than as a jump. This and [kSettleCurve] are the two knobs worth
/// turning if the carry feels wrong.
const Duration kSettleDuration = Duration(milliseconds: 110);

/// How the piece covers the distance: winding up, then easing in.
///
/// An accelerating curve rather than a linear one is the whole difference
/// between a piece that teleports between cells and one that travels.
const Curve kSettleCurve = Curves.easeInOutCubic;

/// The piece while the player is carrying it.
///
/// Flutter pins a [Draggable]'s feedback rigidly to the pointer, which would
/// make the piece track the finger to the last sub-pixel and sit at an
/// arbitrary offset from the grid it is about to join. Instead the screen
/// hands down the distance to the square the piece has snapped to, and this
/// closes that distance under its own steam — so the piece rides the grid
/// while the finger moves freely underneath it.
///
/// When there is no legal landing the correction is [Offset.zero] and the
/// piece follows the pointer exactly, which is the honest thing to show: it
/// is not going to snap anywhere, so it should not pretend to.
class CarriedPiece extends StatefulWidget {
  /// Draws [shape] in [color], offset by [correction] from the pointer.
  const CarriedPiece({
    required this.shape,
    required this.color,
    required this.cellSize,
    required this.correction,
    super.key,
  });

  /// The shape being carried.
  final BlockShape shape;

  /// Its colour.
  final Color color;

  /// One block, at board size.
  final double cellSize;

  /// How far the snapped square is from where the pointer has the piece.
  final ValueListenable<Offset> correction;

  @override
  State<CarriedPiece> createState() => _CarriedPieceState();
}

class _CarriedPieceState extends State<CarriedPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: kSettleDuration,
  );
  late Offset _from = widget.correction.value;
  late Offset _to = widget.correction.value;

  @override
  void initState() {
    super.initState();
    widget.correction.addListener(_retarget);
  }

  @override
  void dispose() {
    widget.correction.removeListener(_retarget);
    _settle.dispose();
    super.dispose();
  }

  /// Where the piece is right now, part-way between the last two targets.
  Offset get _offset =>
      Offset.lerp(_from, _to, kSettleCurve.transform(_settle.value))!;

  /// Aims at a new square.
  ///
  /// The run starts from wherever the piece has actually got to, not from the
  /// last target: retargeting mid-flight is the normal case — a finger crosses
  /// several cells without pausing — and starting from the old target would
  /// snap the piece backwards before sending it on.
  void _retarget() {
    final target = widget.correction.value;
    if (target == _to) return;
    _from = _offset;
    _to = target;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settle,
      child: PieceView(
        shape: widget.shape,
        color: widget.color,
        cellSize: widget.cellSize,
      ),
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: _offset,
        child: child,
      ),
    );
  }
}
