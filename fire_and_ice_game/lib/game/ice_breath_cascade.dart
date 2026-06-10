import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import 'ice_breath_base.dart';

/// Alt 2 — Ice Firehose.
///
/// Four simultaneous layers that together produce an overwhelming, dense,
/// turbulent stream — like a high-pressure fire hose but frozen.
///
///   Dense stream  — 700/sec at 7° half-angle, 50–65 wu/s.  Additive
///                   blending stacks hundreds of overlapping tiny crystals
///                   into a bright solid core.  Pure MASS — no gaps.
///
///   Water volume  — 120/sec large alpha-blend particles at 12° half-angle,
///                   14–22 wu/s.  smokeSizeGrowth (+0.9 wu/s²) expands them
///                   from 0.9 to 2.5+ wu as they travel, rapidly filling the
///                   surrounding volume with a dense blue-white water-mist
///                   body.  This is what makes the stream look THICK.
///
///   Outer blast   — 160/sec at 22° half-angle, 36–52 wu/s.  The chaotic
///                   outer spray that erupts from a real pressurised hose.
///
///   Thunder       — Every 80–140 ms: 5–10 particles spawn ALONG THE BEAM
///                   VECTOR at random positions and shoot SIDEWAYS at 30–55
///                   wu/s for 0.05–0.12 s.  They look like brief electrical
///                   crackle-arcs discharging from the stream.
///
///   Beam frost    — Large alpha-blend fog spawned along the full beam length
///                   (the frozen-air cylinder unique to this variant).
///
///   Impact        — Radial splatter + accumulating frost mist at the target.
class IceBreathFlamethrowerEmitter extends IceBreathEmitterBase {

  // ── Config ─────────────────────────────────────────────────────────────────

  double streamRate     = 700.0;
  double volumeRate     = 120.0;
  double blastRate      = 160.0;
  double fogRate        = 28.0;
  double impactRate     = 110.0;
  double impactMistRate = 24.0;
  double baseRange      = 40.0;
  double baseSpeed      = 55.0;

  // ── State ──────────────────────────────────────────────────────────────────

  double _streamAccum     = 0.0;
  double _volumeAccum     = 0.0;
  double _blastAccum      = 0.0;
  double _fogAccum        = 0.0;
  double _impactAccum     = 0.0;
  double _impactMistAccum = 0.0;
  double _thunderTimer    = 0.0;

  final math.Random _rng   = math.Random();
  final Vector3 _right     = Vector3.zero();
  final Vector3 _up        = Vector3.zero();
  final Vector3 _dir       = Vector3.zero();
  final Vector3 _coneRight = Vector3.zero();
  final Vector3 _coneUp    = Vector3.zero();

  IceBreathFlamethrowerEmitter({required super.origin, required super.direction});

  // ── Charge helpers ─────────────────────────────────────────────────────────

  @override
  double get rangeScale => (1.0 + chargeTime * 2.5).clamp(1.0, 8.0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void startBreath() {
    active = true; chargeTime = 0.0;
    _streamAccum = 0.0; _volumeAccum  = 0.0; _blastAccum      = 0.0;
    _fogAccum    = 0.0; _impactAccum  = 0.0; _impactMistAccum = 0.0;
    _thunderTimer = 0.0;
  }

  @override
  void stopBreath() {
    active = false; chargeTime = 0.0;
    _streamAccum = 0.0; _volumeAccum = 0.0; _blastAccum = 0.0; _fogAccum = 0.0;
  }

  // ── Main tick ──────────────────────────────────────────────────────────────

  @override
  void tick(ParticleSystem system, double dt, Vector3 wind) {
    if (!active) return;
    chargeTime += dt;

    final rs = rangeScale;
    final es = (1.0 + math.min(chargeTime, 2.0)).clamp(1.0, 3.0);

    _perpInto(direction, _right);
    direction.crossInto(_right, _up); _up.normalize();

    final ip = origin + direction.scaled(baseRange * rs);

    // ── Dense stream core ─────────────────────────────────────────────────
    _streamAccum += streamRate * (1.0 + chargeTime * 0.12) * dt;
    final ns = _streamAccum.floor().toInt(); _streamAccum -= ns;
    for (int i = 0; i < ns; i++) _emitStream(system, wind, rs);

    // ── Water volume: large alpha-blend that grows as it travels ──────────
    _volumeAccum += volumeRate * es * dt;
    final nv = _volumeAccum.floor().toInt(); _volumeAccum -= nv;
    for (int i = 0; i < nv; i++) _emitVolume(system, wind, rs);

    // ── Outer blast: wide chaotic spray ───────────────────────────────────
    _blastAccum += blastRate * dt;
    final nb = _blastAccum.floor().toInt(); _blastAccum -= nb;
    for (int i = 0; i < nb; i++) _emitBlast(system, wind, rs);

    // ── Thunder: electrical discharge arcs off the stream ─────────────────
    _thunderTimer -= dt;
    if (_thunderTimer <= 0) {
      _thunderTimer = 0.08 + _rng.nextDouble() * 0.06;
      final n = 5 + _rng.nextInt(6);
      for (int i = 0; i < n; i++) _emitThunder(system, rs);
    }

    // ── Beam frost fog ────────────────────────────────────────────────────
    _fogAccum += fogRate * es * dt;
    final nf = _fogAccum.floor().toInt(); _fogAccum -= nf;
    for (int i = 0; i < nf; i++) _emitBeamFog(system, wind, rs);

    // ── Impact splatter ───────────────────────────────────────────────────
    _impactAccum += impactRate * es * dt;
    final ni = _impactAccum.floor().toInt(); _impactAccum -= ni;
    for (int i = 0; i < ni; i++) _emitImpactSplatter(system, ip, wind);

    // ── Impact frost mist ─────────────────────────────────────────────────
    _impactMistAccum += impactMistRate * es * dt;
    final nim = _impactMistAccum.floor().toInt(); _impactMistAccum -= nim;
    for (int i = 0; i < nim; i++) _emitImpactMist(system, ip, wind, es);
  }

  // ── Dense stream: 700/sec tiny additive crystals ──────────────────────────

  void _emitStream(ParticleSystem system, Vector3 wind, double rs) {
    _coneDir(direction, 0.07, _dir);
    final speed = (baseSpeed + _rng.nextDouble() * 15.0) * rs;
    final life  = baseRange * rs / speed * (0.30 + _rng.nextDouble() * 0.35);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.02,
        _dir.y * speed + wind.y * 0.02,
        _dir.z * speed + wind.z * 0.02,
      ),
      lifetime: life, size: 0.03 + _rng.nextDouble() * 0.06,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Water volume: large alpha-blend grows in-flight ───────────────────────
  //
  // smokeSizeGrowth (+0.9 wu/s) expands these from 0.9 wu at birth to
  // 2.5+ wu by the time they reach range — rapidly filling the surrounding
  // volume with dense blue-white mist.  This creates the heavy body of the
  // stream that makes it read as a thick firehose, not a beam.

  void _emitVolume(ParticleSystem system, Vector3 wind, double rs) {
    _coneDir(direction, 0.12, _dir);
    final speed = (16.0 + _rng.nextDouble() * 8.0) * rs;
    final life  = baseRange * rs / speed * (0.72 + _rng.nextDouble() * 0.45);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.10,
        _dir.y * speed + wind.y * 0.10,
        _dir.z * speed + wind.z * 0.10,
      ),
      lifetime: life, size: 0.90 + _rng.nextDouble() * 0.90,
      isFire: false, isEmber: false, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Outer blast: wide chaotic spray ──────────────────────────────────────

  void _emitBlast(ParticleSystem system, Vector3 wind, double rs) {
    _coneDir(direction, 0.22, _dir);
    final speed = (36.0 + _rng.nextDouble() * 16.0) * rs;
    final life  = baseRange * rs / speed * (0.22 + _rng.nextDouble() * 0.28);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.05,
        _dir.y * speed + wind.y * 0.05,
        _dir.z * speed + wind.z * 0.05,
      ),
      lifetime: life, size: 0.04 + _rng.nextDouble() * 0.09,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Thunder: electrical arcs shooting sideways off the stream ─────────────
  //
  // Each particle spawns at a random position along the beam vector and fires
  // perpendicular to the beam (lateral fraction 0.60–0.90).  The brief
  // lifetime (0.05–0.12 s) makes them appear as instantaneous bright crackling
  // discharges — electrical arcs from a frozen thunderstorm.

  void _emitThunder(ParticleSystem system, double rs) {
    final phi     = _rng.nextDouble() * math.pi * 2;
    final latFrac = 0.60 + _rng.nextDouble() * 0.30;   // mostly sideways
    final fwdFrac = math.sqrt(1.0 - latFrac * latFrac);

    final lx = _right.x * math.cos(phi) + _up.x * math.sin(phi);
    final ly = _right.y * math.cos(phi) + _up.y * math.sin(phi);
    final lz = _right.z * math.cos(phi) + _up.z * math.sin(phi);

    final spd = 30.0 + _rng.nextDouble() * 25.0;

    // Spawn along beam at random t.
    final t     = _rng.nextDouble() * 0.72;
    final range = baseRange * rs;
    final px    = origin.x + direction.x * range * t;
    final py    = origin.y + direction.y * range * t;
    final pz    = origin.z + direction.z * range * t;

    system.emit(Particle(
      position: Vector3(px, py, pz),
      velocity: Vector3(
        (direction.x * fwdFrac + lx * latFrac) * spd,
        (direction.y * fwdFrac + ly * latFrac) * spd,
        (direction.z * fwdFrac + lz * latFrac) * spd,
      ),
      lifetime: 0.05 + _rng.nextDouble() * 0.07,
      size:     0.08 + _rng.nextDouble() * 0.10,
      isFire: false, isEmber: true, isIce: true,
      sourceX: px, sourceZ: pz,
    ));
  }

  // ── Beam frost: alpha-blend fog along full beam length ────────────────────

  void _emitBeamFog(ParticleSystem system, Vector3 wind, double rs) {
    final t     = 0.10 + _rng.nextDouble() * 0.75;
    final range = baseRange * rs;
    final px    = origin.x + direction.x * range * t;
    final py    = origin.y + direction.y * range * t;
    final pz    = origin.z + direction.z * range * t;

    final r   = _rng.nextDouble() * 1.60;
    final phi = _rng.nextDouble() * math.pi * 2;
    final ox  = _right.x * math.cos(phi) * r + _up.x * math.sin(phi) * r;
    final oy  = _right.y * math.cos(phi) * r + _up.y * math.sin(phi) * r;
    final oz  = _right.z * math.cos(phi) * r + _up.z * math.sin(phi) * r;

    system.emit(Particle(
      position: Vector3(px + ox, py + oy, pz + oz),
      velocity: Vector3(wind.x * 0.18, 0.10 + _rng.nextDouble() * 0.20, wind.z * 0.18),
      lifetime: 1.50 + _rng.nextDouble() * 1.30,
      size:     0.80 + _rng.nextDouble() * 1.40,
      isFire: false, isEmber: false, isIce: true,
      sourceX: px, sourceZ: pz,
    ));
  }

  // ── Impact splatter: radial ejection at target ────────────────────────────

  void _emitImpactSplatter(ParticleSystem system, Vector3 ip, Vector3 wind) {
    final phi = _rng.nextDouble() * math.pi * 2;
    final cr  = math.cos(phi), sr2 = math.sin(phi);
    final rx  = _right.x * cr + _up.x * sr2;
    final ry  = _right.y * cr + _up.y * sr2;
    final rz  = _right.z * cr + _up.z * sr2;
    final spd = 9.0 + _rng.nextDouble() * 20.0;
    system.emit(Particle(
      position: Vector3(ip.x + rx * 0.3, ip.y + ry * 0.3, ip.z + rz * 0.3),
      velocity: Vector3(
        rx * spd + wind.x * 0.04,
        ry * spd + wind.y * 0.04 + _rng.nextDouble() * 2.5 - 0.5,
        rz * spd + wind.z * 0.04,
      ),
      lifetime: 0.22 + _rng.nextDouble() * 0.28,
      size:     0.04 + _rng.nextDouble() * 0.10,
      isFire: false, isEmber: true, isIce: true,
      sourceX: ip.x, sourceZ: ip.z,
    ));
  }

  // ── Impact frost mist ──────────────────────────────────────────────────────

  void _emitImpactMist(
      ParticleSystem system, Vector3 ip, Vector3 wind, double es) {
    final r   = _rng.nextDouble() * 2.80;
    final phi = _rng.nextDouble() * math.pi * 2;
    final ox  = _right.x * math.cos(phi) * r + _up.x * math.sin(phi) * r;
    final oy  = _right.y * math.cos(phi) * r + _up.y * math.sin(phi) * r;
    final oz  = _right.z * math.cos(phi) * r + _up.z * math.sin(phi) * r;
    system.emit(Particle(
      position: Vector3(ip.x + ox, ip.y + oy, ip.z + oz),
      velocity: Vector3(
        (ox / (r + 0.01)) * 0.6 + wind.x * 0.08,
        0.25 + _rng.nextDouble() * 0.35,
        (oz / (r + 0.01)) * 0.6 + wind.z * 0.08,
      ),
      lifetime: 2.0 + _rng.nextDouble() * 1.5,
      size: (0.90 + _rng.nextDouble() * 1.80) *
            math.min(es * 0.55, 2.0).clamp(0.5, 2.0),
      isFire: false, isEmber: false, isIce: true,
      sourceX: ip.x, sourceZ: ip.z,
    ));
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
