import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';

/// Aircraft-mounted ice breath weapon — models the blue dragon ice-breath from
/// reference footage (tight conical core beam, wider frost mist envelope).
///
/// Two particle layers:
///   • Crystal shards  — isEmber+isIce, small, fast, bright blue-white (additive).
///   • Frost mist      — isIce only,    large, slow, pale electric blue (alpha-blend).
///
/// Call [startBreath()] on key-down, [stopBreath()] on key-up.  Update [origin]
/// and [direction] each frame from the aircraft nose before calling [tick].
/// [chargeTime] accumulates while held and scales the blast width/rate up to 3×.
class IceBreathEmitter {
  Vector3 origin;
  Vector3 direction;

  bool   active     = false;
  double chargeTime = 0.0;

  // ── Config ────────────────────────────────────────────────────────────────

  double crystalRate      = 260.0;  // sparks/sec at base charge
  double mistRate         = 38.0;   // mist blobs/sec at base charge
  double crystalSpeed     = 27.0;   // m/s
  double mistSpeed        = 9.5;    // m/s
  double crystalRange     = 33.0;   // world units
  double mistRange        = 20.0;
  double crystalHalfAngle = 0.11;   // radians (~6°) — tight beam
  double mistHalfAngle    = 0.24;   // radians (~14°) — wider mist envelope

  double _cAccum = 0.0;
  double _mAccum = 0.0;
  final math.Random _rng = math.Random();

  IceBreathEmitter({required this.origin, required this.direction});

  void startBreath() {
    active     = true;
    chargeTime = 0.0;
  }

  void stopBreath() {
    active     = false;
    chargeTime = 0.0;
    _cAccum    = 0.0;
    _mAccum    = 0.0;
  }

  void tick(ParticleSystem system, double dt, Vector3 wind) {
    if (!active) return;
    chargeTime += dt;
    // Blast grows over the first 2 s of hold, maxing at 3×.
    final scale = (1.0 + math.min(chargeTime, 2.0)).clamp(1.0, 3.0);

    _cAccum += crystalRate * scale * dt;
    final nc = _cAccum.floor();
    _cAccum -= nc;
    for (int i = 0; i < nc; i++) {
      _emitCrystal(system, wind);
    }

    _mAccum += mistRate * scale * dt;
    final nm = _mAccum.floor();
    _mAccum -= nm;
    for (int i = 0; i < nm; i++) {
      _emitMist(system, wind, scale);
    }
  }

  void _emitCrystal(ParticleSystem system, Vector3 wind) {
    // Cone widens slightly as the weapon charges.
    final halfA = (crystalHalfAngle + chargeTime * 0.012).clamp(0.0, 0.30);
    final conDir = _coneDir(direction, halfA);

    final speed = crystalSpeed + _rng.nextDouble() * 11.0;
    final vel   = conDir.scaled(speed) + wind.scaled(0.06);
    final life  = crystalRange / speed * (0.65 + _rng.nextDouble() * 0.60);

    system.emit(Particle(
      position:    Vector3.copy(origin),
      velocity:    vel,
      lifetime:    life,
      size:        0.09 + _rng.nextDouble() * 0.21,
      isFire:      false,
      isEmber:     true,
      isIce:       true,
      sourceX:     origin.x,
      sourceZ:     origin.z,
      temperature: 0.15,
    ));
  }

  void _emitMist(ParticleSystem system, Vector3 wind, double scale) {
    final halfA  = (mistHalfAngle + chargeTime * 0.08).clamp(0.0, 0.52);
    final conDir = _coneDir(direction, halfA);

    final speed  = mistSpeed + _rng.nextDouble() * 5.0;
    final vel    = conDir.scaled(speed) + wind.scaled(0.12);
    final life   = mistRange / speed * (0.80 + _rng.nextDouble() * 0.40);
    // Mist blobs grow larger as the weapon charges.
    final sz = 1.3 + _rng.nextDouble() * 2.5 * math.min(scale * 0.7, 2.0);

    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: vel,
      lifetime: life,
      size:     sz,
      isFire:   false,
      isEmber:  false,
      isIce:    true,
      sourceX:  origin.x,
      sourceZ:  origin.z,
    ));
  }

  /// Returns a unit vector within [halfAngle] radians of [axis], uniformly
  /// distributed across the cone surface (not area-weighted).
  Vector3 _coneDir(Vector3 axis, double halfAngle) {
    final theta = _rng.nextDouble() * halfAngle;
    final phi   = _rng.nextDouble() * math.pi * 2;
    final sT    = math.sin(theta);
    final cT    = math.cos(theta);
    final right = _perp(axis);
    final up    = axis.cross(right).normalized();
    return (axis.scaled(cT)
          + right.scaled(sT * math.cos(phi))
          + up.scaled(sT * math.sin(phi))).normalized();
  }

  static Vector3 _perp(Vector3 v) {
    final a = v.x.abs(), b = v.y.abs(), c = v.z.abs();
    if (a <= b && a <= c) return Vector3(0.0, -v.z, v.y).normalized();
    if (b <= c)           return Vector3(-v.z, 0.0, v.x).normalized();
    return Vector3(-v.y, v.x, 0.0).normalized();
  }
}
