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

  /// What is currently in the air.
  List<CelebrationParticle> get particles =>
      List<CelebrationParticle>.unmodifiable(_particles);

  /// Whether anything is still in the air.
  bool get isActive => _particles.isNotEmpty;

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
  void clear() => _particles.clear();
}
