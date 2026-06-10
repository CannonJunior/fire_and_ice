import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import 'ice_breath_base.dart';

/// Alt 1 — Ice Lava Stream with Icicle Drips.
///
/// Particles spawn in a CYLINDER around the beam axis (not a cone), so the
/// stream keeps a constant diameter along its length — like a rope of viscous
/// lava, not a spray.  Three concentric layers:
///
///   Core        — on-axis tiny crystals (r ≈ 0), 38–48 wu/s.  The bright
///                 glowing spine running through the centre of the stream.
///
///   Stream body — particles spawned in a filled circle of radius 0–0.40 wu
///                 around the beam axis.  All travel at the same speed along
///                 the beam (no radial velocity).  Large size (0.20–0.46 wu)
///                 and slow (18–24 wu/s).  The particle system's −7.2 wu/s²
///                 net gravity arcs the whole stream gently downward — exactly
///                 like heavy molten material flowing forward under gravity.
///
///   Ice crust   — wide alpha-blend fog (~28° half-angle).  Rises slowly due
///                 to smokeBuoyancy (+2.2 wu/s²), forming a cold haze around
///                 the core.
///
/// Dripping icicles:
///   Particles spawn at random positions along the beam vector but BELOW the
///   beam axis (−0.15 to −0.55 wu in world Y).  They are given near-zero
///   forward velocity so they don't travel with the stream; the −7.2 wu/s²
///   gravity then accelerates them rapidly downward.  They look like drops
///   hanging from the underside of the stream and then falling away.
///
/// Opening splash on key-press: 55 large slow blobs in a 55° cone.
class IceBreathDragonEmitter extends IceBreathEmitterBase {

  // ── Config ─────────────────────────────────────────────────────────────────

  double coreRate   = 85.0;
  double streamRate = 280.0;
  double crustRate  = 42.0;
  double dripRate   = 24.0;
  double baseRange  = 38.0;
  double streamSpeed = 20.0;

  // ── State ──────────────────────────────────────────────────────────────────

  double _coreAccum   = 0.0;
  double _streamAccum = 0.0;
  double _crustAccum  = 0.0;
  double _dripAccum   = 0.0;
  bool   _splashEmitted = false;

  final math.Random _rng   = math.Random();
  final Vector3 _right     = Vector3.zero();
  final Vector3 _up        = Vector3.zero();
  final Vector3 _dir       = Vector3.zero();
  final Vector3 _coneRight = Vector3.zero();
  final Vector3 _coneUp    = Vector3.zero();

  IceBreathDragonEmitter({required super.origin, required super.direction});

  // ── Charge helpers ─────────────────────────────────────────────────────────

  @override
  double get rangeScale => (1.0 + chargeTime * 2.5).clamp(1.0, 8.0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void startBreath() {
    active = true; chargeTime = 0.0; _splashEmitted = false;
    _coreAccum = 0.0; _streamAccum = 0.0; _crustAccum = 0.0; _dripAccum = 0.0;
  }

  @override
  void stopBreath() {
    active = false; chargeTime = 0.0;
    _coreAccum = 0.0; _streamAccum = 0.0; _crustAccum = 0.0; _dripAccum = 0.0;
  }

  // ── Main tick ──────────────────────────────────────────────────────────────

  @override
  void tick(ParticleSystem system, double dt, Vector3 wind) {
    if (!active) return;
    chargeTime += dt;

    final rs = rangeScale;
    final es = (1.0 + math.min(chargeTime, 2.0)).clamp(1.0, 3.0);

    // Orthonormal beam basis — used for cylinder spawn and drip offsets.
    _perpInto(direction, _right);
    direction.crossInto(_right, _up); _up.normalize();

    if (!_splashEmitted) { _splashEmitted = true; _emitOpeningSplash(system); }

    // ── Core spine ─────────────────────────────────────────────────────────
    _coreAccum += coreRate * es * dt;
    final nc = _coreAccum.floor().toInt(); _coreAccum -= nc;
    for (int i = 0; i < nc; i++) _emitCore(system, wind, rs);

    // ── Lava stream body ───────────────────────────────────────────────────
    _streamAccum += streamRate * es * dt;
    final ns = _streamAccum.floor().toInt(); _streamAccum -= ns;
    for (int i = 0; i < ns; i++) _emitStream(system, wind, rs);

    // ── Ice crust fog ──────────────────────────────────────────────────────
    _crustAccum += crustRate * dt;
    final ncr = _crustAccum.floor().toInt(); _crustAccum -= ncr;
    for (int i = 0; i < ncr; i++) _emitCrust(system, wind, rs);

    // ── Icicle drips ───────────────────────────────────────────────────────
    _dripAccum += dripRate * es * dt;
    final nd = _dripAccum.floor().toInt(); _dripAccum -= nd;
    for (int i = 0; i < nd; i++) _emitDrip(system, wind, rs);
  }

  // ── Core spine: on-axis bright crystals ────────────────────────────────────

  void _emitCore(ParticleSystem system, Vector3 wind, double rs) {
    _coneDir(direction, 0.025, _dir);
    final speed = (40.0 + _rng.nextDouble() * 10.0) * rs;
    final life  = baseRange * rs / speed * (0.28 + _rng.nextDouble() * 0.30);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.02,
        _dir.y * speed + wind.y * 0.02,
        _dir.z * speed + wind.z * 0.02,
      ),
      lifetime: life, size: 0.03 + _rng.nextDouble() * 0.05,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Stream body: CYLINDER spawn — constant-diameter rope of lava ───────────
  //
  // Particles start in a filled circle (radius 0–0.40 wu) around the beam
  // axis and travel straight along the beam.  No cone spread — the stream
  // keeps the same width from muzzle to range, like flowing liquid.
  // Gravity (-7.2 wu/s²) arcs the whole stream downward, matching lava flow.

  void _emitStream(ParticleSystem system, Vector3 wind, double rs) {
    final r   = _rng.nextDouble() * 0.40;   // radial distance from axis
    final phi = _rng.nextDouble() * math.pi * 2;
    final ox  = _right.x * math.cos(phi) * r + _up.x * math.sin(phi) * r;
    final oy  = _right.y * math.cos(phi) * r + _up.y * math.sin(phi) * r;
    final oz  = _right.z * math.cos(phi) * r + _up.z * math.sin(phi) * r;

    final speed = (streamSpeed + _rng.nextDouble() * 5.0) * rs;
    final life  = baseRange * rs / speed * (0.48 + _rng.nextDouble() * 0.60);

    system.emit(Particle(
      position: Vector3(origin.x + ox, origin.y + oy, origin.z + oz),
      velocity: Vector3(
        direction.x * speed + wind.x * 0.04,
        direction.y * speed + wind.y * 0.04,
        direction.z * speed + wind.z * 0.04,
      ),
      lifetime: life,
      size: 0.20 + _rng.nextDouble() * 0.26,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Ice crust: wide alpha-blend haze rising around the stream ─────────────

  void _emitCrust(ParticleSystem system, Vector3 wind, double rs) {
    _coneDir(direction, 0.28, _dir);
    final speed = (7.0 + _rng.nextDouble() * 5.0) * rs;
    final life  = baseRange * rs / speed * (0.55 + _rng.nextDouble() * 0.55);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.10,
        _dir.y * speed + wind.y * 0.10,
        _dir.z * speed + wind.z * 0.10,
      ),
      lifetime: life, size: 0.55 + _rng.nextDouble() * 1.30,
      isFire: false, isEmber: false, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Icicle drips: hang below beam axis, then fall ─────────────────────────
  //
  // Each drip spawns at a random point along the beam and is offset BELOW the
  // beam axis in world Y (negative).  Near-zero forward velocity means it
  // does not travel with the stream.  The −7.2 wu/s² net gravity then
  // accelerates it steeply downward, producing a crystal curtain of icicle-
  // drops falling away beneath the stream.

  void _emitDrip(ParticleSystem system, Vector3 wind, double rs) {
    final t     = 0.05 + _rng.nextDouble() * 0.84;
    final range = baseRange * rs;

    // Along-beam position.
    final px = origin.x + direction.x * range * t;
    final py = origin.y + direction.y * range * t;
    final pz = origin.z + direction.z * range * t;

    // Below-axis offset: world-Y drop + small XZ scatter so drops don't
    // stack on a single vertical line.
    final dropY = 0.15 + _rng.nextDouble() * 0.40;
    final jx    = (_rng.nextDouble() - 0.5) * 0.30;
    final jz    = (_rng.nextDouble() - 0.5) * 0.30;

    // Velocity: tiny forward drift so drops don't float backward, but mostly
    // zero — gravity (-7.2 wu/s²) does the falling work.
    final fwd = 0.5 + _rng.nextDouble() * 1.5;

    system.emit(Particle(
      position: Vector3(px + jx, py - dropY, pz + jz),
      velocity: Vector3(
        direction.x * fwd + wind.x * 0.08,
        direction.y * fwd - (0.8 + _rng.nextDouble() * 1.4),
        direction.z * fwd + wind.z * 0.08,
      ),
      lifetime: 0.40 + _rng.nextDouble() * 0.55,
      size:     0.05 + _rng.nextDouble() * 0.11,
      isFire: false, isEmber: true, isIce: true,
      sourceX: px, sourceZ: pz,
    ));
  }

  // ── Opening splash: heavy blobs gush outward ──────────────────────────────

  void _emitOpeningSplash(ParticleSystem system) {
    for (int i = 0; i < 55; i++) {
      _coneDir(direction, 0.55, _dir);
      final spd = 6.0 + _rng.nextDouble() * 14.0;
      system.emit(Particle(
        position: Vector3.copy(origin),
        velocity: _dir.scaled(spd),
        lifetime: 0.42 + _rng.nextDouble() * 0.55,
        size: 0.22 + _rng.nextDouble() * 0.40,
        isFire: false, isEmber: true, isIce: true,
        sourceX: origin.x, sourceZ: origin.z,
      ));
    }
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  void _coneDir(Vector3 axis, double halfAngle, Vector3 out) {
    final theta = _rng.nextDouble() * halfAngle;
    final phi   = _rng.nextDouble() * math.pi * 2;
    final sT = math.sin(theta), cT = math.cos(theta);
    _perpInto(axis, _coneRight);
    axis.crossInto(_coneRight, _coneUp); _coneUp.normalize();
    out.setFrom(axis); out.scale(cT);
    _coneRight.scale(sT * math.cos(phi)); out.add(_coneRight);
    _coneUp.scale(sT * math.sin(phi));    out.add(_coneUp);
    out.normalize();
  }

  static void _perpInto(Vector3 v, Vector3 out) {
    final a = v.x.abs(), b = v.y.abs(), c = v.z.abs();
    if (a <= b && a <= c)  { out.setValues(0.0, -v.z,  v.y); }
    else if (b <= c)       { out.setValues(-v.z, 0.0,  v.x); }
    else                   { out.setValues(-v.y,  v.x, 0.0); }
    out.normalize();
  }
}
