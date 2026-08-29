import 'dart:math';

import 'package:flutter/material.dart';

/// How fast thrown colour falls, in heights per second squared.
const double _gravity = 1.1;

/// What fraction of its speed a particle keeps each second.
///
/// Light. Heavier air reads as confetti thrown into treacle: it never gets
/// above the bottom of the screen, which for a celebration that is supposed to
/// belong to the whole screen looks less like cheering and more like a spill.
const double _drag = 0.72;

/// A single piece of thrown colour.
///
/// Lives in a unit space — `(0, 0)` top left, `(1, 1)` bottom right — so the
/// field knows nothing about how big the screen is and a rotation looks the
/// same on a phone and a tablet.
class CelebrationParticle {
  /// Creates a particle.
  CelebrationParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.angle,
    required this.spin,
    required this.life,
  });

  /// Where it is now.
  Offset position;

  /// Where it is going, in units per second.
  Offset velocity;

  /// What colour it is.
  final Color color;

  /// How big, as a fraction of the shorter side.
  final double size;

  /// Which way up it is.
  double angle;

  /// How fast it is turning, in turns per second.
  final double spin;

  /// How long it lives, in seconds.
  final double life;

  /// How long it has lived.
  double age = 0;

  /// Whether it is still worth drawing.
  bool get isAlive => age < life;

  /// How solid to draw it: full until the last third, then out.
  double get opacity {
    final left = 1 - age / life;
    return left > 0.35 ? 1 : (left / 0.35).clamp(0, 1).toDouble();
  }
}

/// A shell on its way up, waiting to go off.
///
/// Drawn as a single bright dot while it climbs, which is what makes a
/// firework read as a firework: the eye follows something up, and then it
/// bursts. A ring that simply appeared would be a burst in a different place.
class CelebrationShell {
  /// Creates a shell.
  CelebrationShell({
    required this.position,
    required this.velocity,
    required this.color,
    required this.delay,
    required this.fuse,
  });

  /// Where it is now, in unit coordinates.
  Offset position;

  /// Where it is going.
  Offset velocity;

  /// What colour it will go off in.
  final Color color;

  /// How long until it is launched. Staggers a volley so the shells go up one
  /// after another rather than as a single row.
  double delay;

  /// How long after launching until it goes off.
  double fuse;

  /// Whether it has left the ground.
  bool get isFlying => delay <= 0;
}

/// A field of thrown colour, with no opinion about how it is drawn.
///
/// Kept apart from the widget so the physics can be stepped by hand in a test
/// rather than only by a ticker: whether a burst dies out, whether it throws
/// the colours it was given, and whether it settles are all things worth
/// knowing without looking at a screen.
class CelebrationField {
  /// Creates an empty field. Pass [random] to make a burst repeatable.
  CelebrationField({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<CelebrationParticle> _particles = <CelebrationParticle>[];
  final List<CelebrationShell> _shells = <CelebrationShell>[];

  /// What is currently in the air.
  List<CelebrationParticle> get particles =>
      List<CelebrationParticle>.unmodifiable(_particles);

  /// Shells still climbing.
  List<CelebrationShell> get shells =>
      List<CelebrationShell>.unmodifiable(_shells);

  /// Whether anything is still in the air.
  bool get isActive => _particles.isNotEmpty || _shells.isNotEmpty;

  /// Throws [count] particles outwards from [origin] in unit coordinates.
  ///
  /// For a moment that happens somewhere in particular — a line going out —
  /// where colour arriving from the wrong part of the screen would read as
  /// unrelated to what just happened.
  void burst({
    required Offset origin,
    required List<Color> colors,
    int count = 26,
    double speed = 0.62,
  }) {
    if (colors.isEmpty) return;
    for (var i = 0; i < count; i++) {
      final direction = _random.nextDouble() * 2 * pi;
      // Biased upwards: thrown colour that only ever falls looks like a leak.
      final lift = 0.35 + _random.nextDouble() * 0.5;
      final force = speed * (0.45 + _random.nextDouble() * 0.55);
      _spawn(
        origin,
        Offset(cos(direction) * force, sin(direction) * force - lift),
        colors,
      );
    }
  }

  /// Throws [count] particles up from below the bottom edge, across the width.
  ///
  /// For a moment that belongs to the whole screen rather than a corner of it
  /// — a puzzle finished, a game won.
  void fountain({
    required List<Color> colors,
    int count = 90,
    double speed = 1.6,
  }) {
    if (colors.isEmpty) return;
    for (var i = 0; i < count; i++) {
      final from = Offset(_random.nextDouble(), 1.05 + _random.nextDouble() * 0.1);
      // Leant inwards, barely. Enough that the edges of the screen do not get
      // all of it, not so much that the whole fountain converges into one
      // plume up the middle — which is what a stronger pull does once the air
      // is light enough for anything to travel.
      final inwards = (0.5 - from.dx) * (0.08 + _random.nextDouble() * 0.22);
      final force = speed * (0.7 + _random.nextDouble() * 0.5);
      _spawn(from, Offset(inwards, -force), colors);
    }
  }

  /// Sends up [count] shells, one after another, each bursting into a ring.
  ///
  /// A shape of its own, and deliberately not either of the others: the
  /// fountain sprays from the bottom edge and a burst goes off where it is
  /// put, while this climbs first and goes off somewhere up the screen. Each
  /// shell keeps a single colour so it reads as one firework rather than as
  /// confetti that happens to be round.
  void fireworks({required List<Color> colors, int count = 3}) {
    if (colors.isEmpty) return;
    for (var i = 0; i < count; i++) {
      // Away from the very edges, where half the ring would be off-screen.
      final from = Offset(0.2 + _random.nextDouble() * 0.6, 1.05);
      _shells.add(
        CelebrationShell(
          position: from,
          velocity: Offset(
            (_random.nextDouble() - 0.5) * 0.1,
            -(1.15 + _random.nextDouble() * 0.35),
          ),
          color: colors[_random.nextInt(colors.length)],
          delay: i * (0.22 + _random.nextDouble() * 0.16),
          fuse: 0.5 + _random.nextDouble() * 0.22,
        ),
      );
    }
  }

  /// Bursts [shell] into an even ring.
  ///
  /// Even, unlike [burst], which scatters. The ring is the whole reason a
  /// firework looks like one.
  void _detonate(CelebrationShell shell) {
    const int sparks = 38;
    for (var i = 0; i < sparks; i++) {
      final angle = i / sparks * 2 * pi + _random.nextDouble() * 0.08;
      final force = 0.62 + _random.nextDouble() * 0.16;
      _particles.add(
        CelebrationParticle(
          position: shell.position,
          velocity: Offset(cos(angle) * force, sin(angle) * force),
          color: shell.color,
          size: 0.011 + _random.nextDouble() * 0.010,
          angle: _random.nextDouble() * 2 * pi,
          spin: (_random.nextDouble() - 0.5) * 3,
          life: 1.1 + _random.nextDouble() * 0.7,
        ),
      );
    }
  }

  void _spawn(Offset at, Offset velocity, List<Color> colors) {
    _particles.add(
      CelebrationParticle(
        position: at,
        velocity: velocity,
        color: colors[_random.nextInt(colors.length)],
        size: 0.012 + _random.nextDouble() * 0.014,
        angle: _random.nextDouble() * 2 * pi,
        spin: (_random.nextDouble() - 0.5) * 4,
        life: 1.9 + _random.nextDouble() * 1.2,
      ),
    );
  }

  /// Moves everything on by [seconds] and forgets what has finished.
  void advance(double seconds) {
    if (seconds <= 0) return;

    final flying = <CelebrationShell>[];
    for (final shell in _shells) {
      if (!shell.isFlying) {
        shell.delay -= seconds;
        flying.add(shell);
        continue;
      }
      shell.fuse -= seconds;
      if (shell.fuse <= 0) {
        _detonate(shell);
        continue;
      }
      shell.velocity =
          shell.velocity + Offset(0, _gravity * seconds);
      shell.position += shell.velocity * seconds;
      flying.add(shell);
    }
    _shells
      ..clear()
      ..addAll(flying);

    final kept = <CelebrationParticle>[];
    for (final particle in _particles) {
      particle.age += seconds;
      // Anything well past the bottom is gone whatever its age says.
      if (!particle.isAlive || particle.position.dy > 1.4) continue;
      particle.velocity = particle.velocity * pow(_drag, seconds).toDouble() +
          Offset(0, _gravity * seconds);
      particle.position += particle.velocity * seconds;
      particle.angle += particle.spin * seconds;
      kept.add(particle);
    }
    _particles
      ..clear()
      ..addAll(kept);
  }

  /// Clears the field.
  void clear() {
    _particles.clear();
    _shells.clear();
  }
}
