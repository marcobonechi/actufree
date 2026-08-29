import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'celebration.dart';

/// Asks a [CelebrationLayer] to throw some colour.
///
/// The layer holds the particles and the ticker; this only carries requests,
/// so a screen can say "celebrate" from wherever the moment happens without
/// owning any of the machinery.
class CelebrationCue extends ChangeNotifier {
  final List<void Function(CelebrationField field)> _pending =
      <void Function(CelebrationField)>[];

  /// Throws colour outwards from [origin], given in fractions of the layer.
  void burst({
    required Offset origin,
    required List<Color> colors,
    int count = 26,
  }) {
    _pending.add(
      (CelebrationField field) =>
          field.burst(origin: origin, colors: colors, count: count),
    );
    notifyListeners();
  }

  /// Sends up shells that climb and burst into rings.
  void fireworks({required List<Color> colors, int count = 3}) {
    _pending.add(
      (CelebrationField field) => field.fireworks(colors: colors, count: count),
    );
    notifyListeners();
  }

  /// Throws colour up from the bottom of the whole layer.
  void fountain({required List<Color> colors, int count = 90}) {
    _pending.add(
      (CelebrationField field) => field.fountain(colors: colors, count: count),
    );
    notifyListeners();
  }

  /// Hands over what has been asked for since the last time.
  List<void Function(CelebrationField)> take() {
    final taken = List<void Function(CelebrationField)>.of(_pending);
    _pending.clear();
    return taken;
  }
}

/// Identifies the layer's own painting, which is otherwise indistinguishable
/// from the several [CustomPaint]s Material puts on every screen.
const Key celebrationPaintKey = ValueKey<String>('celebration');

/// Draws thrown colour over [child].
///
/// Ignores pointers entirely: a celebration that swallowed a tap would cost
/// the player the move they were about to make.
///
/// Respects the system's "remove animations" setting, where it draws nothing
/// at all. Someone who has asked their phone to stop things flying about did
/// not mean everything except this.
class CelebrationLayer extends StatefulWidget {
  /// Draws whatever [cue] asks for, over [child].
  const CelebrationLayer({
    required this.cue,
    required this.child,
    super.key,
  });

  /// Where requests come from.
  final CelebrationCue cue;

  /// What the colour is thrown over.
  final Widget child;

  @override
  State<CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<CelebrationLayer>
    with SingleTickerProviderStateMixin {
  final CelebrationField _field = CelebrationField();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.cue.addListener(_onCue);
  }

  @override
  void didUpdateWidget(covariant CelebrationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cue == widget.cue) return;
    oldWidget.cue.removeListener(_onCue);
    widget.cue.addListener(_onCue);
  }

  @override
  void dispose() {
    widget.cue.removeListener(_onCue);
    _ticker.dispose();
    super.dispose();
  }

  void _onCue() {
    final requests = widget.cue.take();
    if (requests.isEmpty) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    for (final request in requests) {
      request(_field);
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // The first tick has nothing to measure from, so it only sets the mark.
    final seconds = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    _field.advance(seconds);
    if (!_field.isActive) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        if (_field.isActive)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: celebrationPaintKey,
                painter: _CelebrationPainter(
                  _field.particles,
                  _field.shells,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hands a [CelebrationCue] to everything below it.
///
/// The layer is wrapped around the whole app, once, beside the backdrop — so a
/// screen that wants to celebrate asks for the cue rather than carrying a
/// layer of its own, and the colour is drawn over app bars and dialogs instead
/// of being trapped inside one screen's body.
class CelebrationScope extends InheritedWidget {
  /// Offers [cue] to [child] and everything under it.
  const CelebrationScope({
    required this.cue,
    required super.child,
    super.key,
  });

  /// What to ask for a celebration.
  final CelebrationCue cue;

  /// The cue in scope, or `null` when there is none.
  ///
  /// Nullable on purpose. A test that builds one screen on its own has no app
  /// around it, and a missing celebration should cost that test nothing.
  static CelebrationCue? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<CelebrationScope>()
      ?.cue;

  @override
  bool updateShouldNotify(CelebrationScope oldWidget) => oldWidget.cue != cue;
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter(this.particles, this.shells);

  final List<CelebrationParticle> particles;
  final List<CelebrationShell> shells;

  @override
  void paint(Canvas canvas, Size size) {
    _paintShells(canvas, size);
    // Little rounded squares rather than circles or streamers: the games are
    // made of blocks and squares, and the celebration should look like it
    // came from the same place.
    final unit = size.shortestSide;
    for (final particle in particles) {
      final side = particle.size * unit;
      canvas
        ..save()
        ..translate(particle.position.dx * size.width,
            particle.position.dy * size.height)
        ..rotate(particle.angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: side,
            // Squashed a little as it turns, which is what sells it as a flat
            // thing tumbling rather than a dot sliding about.
            height: side * 0.62,
          ),
          Radius.circular(side * 0.2),
        ),
        Paint()..color = particle.color.withValues(alpha: particle.opacity),
      );
      canvas.restore();
    }
  }

  /// Draws each climbing shell as a bright dot with a short tail.
  ///
  /// The tail is what makes it read as travelling rather than hovering, and it
  /// costs one more rounded rectangle behind the dot.
  void _paintShells(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    for (final shell in shells) {
      if (!shell.isFlying) continue;
      final at = Offset(
        shell.position.dx * size.width,
        shell.position.dy * size.height,
      );
      final tail = at - Offset(0, shell.velocity.dy * 0.075 * size.height);
      canvas
        ..drawLine(
          at,
          tail,
          Paint()
            ..color = shell.color.withValues(alpha: 0.35)
            ..strokeWidth = unit * 0.009
            ..strokeCap = StrokeCap.round,
        )
        ..drawCircle(at, unit * 0.011, Paint()..color = shell.color);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => true;
}
