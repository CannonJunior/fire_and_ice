import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import 'ice_breath_base.dart';

/// Standard ice breath — random-cone crystal shards + frost mist + arc discharge.
class IceBreathEmitter extends IceBreathEmitterBase {

  // ── Config ────────────────────────────────────────────────────────────────

  double crystalRate      = 260.0;   // sparks/sec at emission scale 1×
  double mistRate         = 38.0;    // mist blobs/sec at emission scale 1×
  double crystalBaseSpeed = 27.0;    // world units/sec at range scale 1×
  double mistBaseSpeed    = 9.5;
  double crystalBaseRange = 33.0;    // world units at range scale 1×
  double mistBaseRange    = 20.0;
  double crystalHalfAngle = 0.11;    // radians (~6°) — tight beam
  double mistHalfAngle    = 0.24;    // radians (~14°) — wider envelope

  // ── State ─────────────────────────────────────────────────────────────────

  double _cAccum       = 0.0;
  double _mAccum       = 0.0;
  double _arcTimer     = 0.0;
  bool   _shockEmitted = false;

  final math.Random _rng = math.Random();

  final Vector3 _rightScratch = Vector3.zero();
  final Vector3 _upScratch    = Vector3.zero();
  final Vector3 _dirScratch   = Vector3.zero();
  final Vector3 _velScratch   = Vector3.zero();

  IceBreathEmitter({required super.origin, required super.direction});

  // Range scale 1× → 10× over 3 s of hold.
  // Both particle speed and base range multiply by this so travel time (and
  // therefore visible particle density) stays constant at any charge level.
  double get rangeScale => (1.0 + chargeTime * 3.0).clamp(1.0, 10.0);

  void startBreath() {
    active        = true;
    chargeTime    = 0.0;
    _shockEmitted = false;
    _arcTimer     = 0.0;
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

    final rs            = rangeScale;
    // Emission rate scales over 2 s (unchanged from original).
    final emissionScale = (1.0 + math.min(chargeTime, 2.0)).clamp(1.0, 3.0);
    // Sine pulse gives the beam a breathing, crackling feel.
    final pulse = 1.0 + 0.30 * math.sin(chargeTime * 13.5);

    // ── Crystal shards ────────────────────────────────────────────────────
    _cAccum += crystalRate * emissionScale * pulse * dt;
    final nc = _cAccum.floor();
    _cAccum -= nc;
    for (int i = 0; i < nc; i++) _emitCrystal(system, wind, rs);

    // ── Frost mist ────────────────────────────────────────────────────────
    _mAccum += mistRate * emissionScale * dt;
    final nm = _mAccum.floor();
    _mAccum -= nm;
    for (int i = 0; i < nm; i++) _emitMist(system, wind, emissionScale, rs);

    // ── Arc discharge — periodic electric burst ───────────────────────────
    _arcTimer -= dt;
    if (_arcTimer <= 0) {
      _arcTimer = 0.10 + _rng.nextDouble() * 0.22;
      final burstN = 5 + (emissionScale * 2.5).round();
      for (int i = 0; i < burstN; i++) _emitArc(system, wind, rs);
    }

    // ── Shockwave ring — fired once at beam start ─────────────────────────
    if (!_shockEmitted) {
      _shockEmitted = true;
      _emitRing(system, 20);
    }
  }

  // ── Crystal shards ────────────────────────────────────────────────────────

  void _emitCrystal(ParticleSystem system, Vector3 wind, double rs) {
    final halfA = (crystalHalfAngle + chargeTime * 0.012).clamp(0.0, 0.30);
    _coneDir(direction, halfA, _dirScratch);

    final speed = (crystalBaseSpeed + _rng.nextDouble() * 11.0) * rs;
    _velScratch.setFrom(_dirScratch);
    _velScratch.scale(speed);
    _velScratch.x += wind.x * 0.06;
    _velScratch.y += wind.y * 0.06;
    _velScratch.z += wind.z * 0.06;
    final range = crystalBaseRange * rs;
    final life  = range / speed * (0.65 + _rng.nextDouble() * 0.60);

    final p = system.acquire();
    if (p == null) return;
    p.position.setFrom(origin);
    p.velocity.setFrom(_velScratch);
    p.lifetime    = life;
    p.size        = 0.09 + _rng.nextDouble() * 0.21;
    p.isEmber     = true;
    p.isIce       = true;
    p.sourceX     = origin.x;
    p.sourceZ     = origin.z;
    p.temperature = 0.15;
  }

  // ── Frost mist (size halved vs original) ─────────────────────────────────

  void _emitMist(ParticleSystem system, Vector3 wind, double scale, double rs) {
    final halfA = (mistHalfAngle + chargeTime * 0.08).clamp(0.0, 0.52);
    _coneDir(direction, halfA, _dirScratch);

    final speed = (mistBaseSpeed + _rng.nextDouble() * 5.0) * rs;
    _velScratch.setFrom(_dirScratch);
    _velScratch.scale(speed);
    _velScratch.x += wind.x * 0.12;
    _velScratch.y += wind.y * 0.12;
    _velScratch.z += wind.z * 0.12;
    final range = mistBaseRange * rs;
    final life  = range / speed * (0.80 + _rng.nextDouble() * 0.40);
    // Cloud size halved: base 0.65 (was 1.3), random 1.25× (was 2.5×).
    final sz = 0.65 + _rng.nextDouble() * 1.25 * math.min(scale * 0.7, 2.0);

    final p = system.acquire();
    if (p == null) return;
    p.position.setFrom(origin);
    p.velocity.setFrom(_velScratch);
    p.lifetime = life;
    p.size     = sz;
    p.isIce    = true;
    p.sourceX  = origin.x;
    p.sourceZ  = origin.z;
  }

  // ── Arc discharge — ultra-fast tiny sparks (cinematic electric crackle) ──

  void _emitArc(ParticleSystem system, Vector3 wind, double rs) {
    // Slightly wider cone than main beam — arcs spray unpredictably.
    final halfA = crystalHalfAngle * (1.3 + _rng.nextDouble() * 0.8);
    _coneDir(direction, halfA, _dirScratch);

    // 3–5× faster than crystal shards → travel the same range near-instantly,
    // appearing as bright streaks that flash and vanish.
    final speed = crystalBaseSpeed * rs * (3.0 + _rng.nextDouble() * 2.0);
    _velScratch.setFrom(_dirScratch);
    _velScratch.scale(speed);
    final range = crystalBaseRange * rs * 0.85;
    final life  = range / speed * (0.25 + _rng.nextDouble() * 0.35);

    final p = system.acquire();
    if (p == null) return;
    p.position.setFrom(origin);
    p.velocity.setFrom(_velScratch);
    p.lifetime    = life;
    p.size        = 0.04 + _rng.nextDouble() * 0.09;
    p.isEmber     = true;
    p.isIce       = true;
    p.sourceX     = origin.x;
    p.sourceZ     = origin.z;
    p.temperature = 0.05;
  }

  // ── Shockwave ring — crystals fired perpendicular to beam on key-press ────

  void _emitRing(ParticleSystem system, int count) {
    _perpInto(direction, _rightScratch);
    direction.crossInto(_rightScratch, _upScratch);
    _upScratch.normalize();

    for (int i = 0; i < count; i++) {
      final phi = i / count * math.pi * 2;
      final cr  = math.cos(phi), sr = math.sin(phi);
      // Radial direction perpendicular to beam axis.
      final rx = _rightScratch.x * cr + _upScratch.x * sr;
      final ry = _rightScratch.y * cr + _upScratch.y * sr;
      final rz = _rightScratch.z * cr + _upScratch.z * sr;
      final spd = 14.0 + _rng.nextDouble() * 9.0;

      final p = system.acquire();
      if (p == null) return;
      p.position.setFrom(origin);
      p.velocity.setValues(rx * spd, ry * spd + 2.5, rz * spd);
      p.lifetime    = 0.45 + _rng.nextDouble() * 0.40;
      p.size        = 0.10 + _rng.nextDouble() * 0.20;
      p.isEmber     = true;
      p.isIce       = true;
      p.sourceX     = origin.x;
      p.sourceZ     = origin.z;
      p.temperature = 0.15;
    }
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  void _coneDir(Vector3 axis, double halfAngle, Vector3 out) {
    final theta = _rng.nextDouble() * halfAngle;
    final phi   = _rng.nextDouble() * math.pi * 2;
    final sT    = math.sin(theta);
    final cT    = math.cos(theta);
    _perpInto(axis, _rightScratch);
    axis.crossInto(_rightScratch, _upScratch);
    _upScratch.normalize();
    out.setFrom(axis);
    out.scale(cT);
    _rightScratch.scale(sT * math.cos(phi));
    out.add(_rightScratch);
    _upScratch.scale(sT * math.sin(phi));
    out.add(_upScratch);
    out.normalize();
  }

  static void _perpInto(Vector3 v, Vector3 out) {
    final a = v.x.abs(), b = v.y.abs(), c = v.z.abs();
    if (a <= b && a <= c)  { out.setValues(0.0, -v.z, v.y); }
    else if (b <= c)       { out.setValues(-v.z, 0.0, v.x); }
    else                   { out.setValues(-v.y,  v.x, 0.0); }
    out.normalize();
  }
}
