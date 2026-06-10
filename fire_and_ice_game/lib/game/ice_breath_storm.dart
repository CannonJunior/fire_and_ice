import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import 'ice_breath_base.dart';

/// Alt 3 — Cryo Laser.
///
/// A coherent laser beam that visibly GROWS from the aircraft to the target
/// over 0.35 s, then locks on and unleashes cascading impact effects.
///
/// ── Extension phase (0–0.35 s) ─────────────────────────────────────────────
///
///   Beam core particles have their lifetime capped to `currentReach / speed`
///   so the visible beam tip advances from origin to max range.
///
///   A bright TRAVELING TIP SPHERE (35-particle radial burst at the advancing
///   front, fired every 0.045 s) marks the leading edge — a visible drilling
///   flare moving forward until impact.
///
/// ── Steady phase (0.35 s+) ─────────────────────────────────────────────────
///
///   Laser core  — 480/sec at ≤1° half-angle, 82 wu/s, tiny size (0.03–0.07
///                 wu).  Additive blending stacks hundreds of overlapping
///                 crystals into a solid luminous rod.  At 82 wu/s the
///                 −7.2 wu/s² gravity causes only ~0.8 wu drop over 45 wu —
///                 the beam appears perfectly straight.
///
///   Beam glow   — 70/sec at ≤2.4° half-angle, larger (0.11–0.20 wu).
///                 Additive stacking creates a wide bloom halo around the core,
///                 making the beam look thick and radiant.
///
/// ── Cascading impact effects (fire in sequence after lock-on) ──────────────
///
///   Initial blast — one-time 100-particle eruption at first contact:
///                   30 particles as a perpendicular ring, 40 particles
///                   shooting straight up (ice spire burst), 30 omnidirectional.
///
///   Secondary    — Perpendicular ring every 0.25 s.  Large fast crystals
///                  (0.08–0.20 wu, 18–32 wu/s).
///
///   Tertiary     — Ground creep: crystals spread horizontally in the XZ plane
///                  at 10–26 wu/s, Y velocity near zero — frost advancing along
///                  the ground surface.
///
///   Quaternary   — Ice spire: shards launch straight up at 16–30 wu/s,
///                  forming a continuously erupting vertical pillar.
///
///   Frost mist   — Large alpha-blend cloud accumulating at impact zone.
///
///   Contact glow — Persistent large mist particles right at the impact point
///                  that linger for 3–5 s, creating a glowing scar.
class IceBreathStormEmitter extends IceBreathEmitterBase {

  // ── Config ─────────────────────────────────────────────────────────────────

  static const double kExtendDuration = 0.35;

  double coreRate     = 480.0;
  double glowRate     = 70.0;
  double creepRate    = 55.0;
  double spireRate    = 40.0;
  double mistRate     = 14.0;
  double contactRate  = 8.0;
  double baseRange    = 45.0;
  double laserSpeed   = 82.0;

  // ── State ──────────────────────────────────────────────────────────────────

  double _coreAccum    = 0.0;
  double _glowAccum    = 0.0;
  double _creepAccum   = 0.0;
  double _spireAccum   = 0.0;
  double _mistAccum    = 0.0;
  double _contactAccum = 0.0;
  double _ringTimer    = 0.0;
  double _tipTimer     = 0.0;
  bool   _flareEmitted  = false;
  bool   _impactEmitted = false;

  final math.Random _rng   = math.Random();
  final Vector3 _right     = Vector3.zero();
  final Vector3 _up        = Vector3.zero();
  final Vector3 _dir       = Vector3.zero();
  final Vector3 _coneRight = Vector3.zero();
  final Vector3 _coneUp    = Vector3.zero();

  IceBreathStormEmitter({required super.origin, required super.direction});

  // ── Charge helpers ─────────────────────────────────────────────────────────

  @override
  double get rangeScale => (1.0 + chargeTime * 2.0).clamp(1.0, 6.0);

  bool get _extended => chargeTime >= kExtendDuration;

  double _effectiveRange(double range) => _extended
      ? range
      : range * (chargeTime / kExtendDuration).clamp(0.0, 1.0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void startBreath() {
    active = true; chargeTime = 0.0;
    _flareEmitted = false; _impactEmitted = false;
    _coreAccum = 0.0; _glowAccum = 0.0; _creepAccum = 0.0;
    _spireAccum = 0.0; _mistAccum = 0.0; _contactAccum = 0.0;
    _ringTimer = 0.0; _tipTimer = 0.0;
  }

  @override
  void stopBreath() {
    active = false; chargeTime = 0.0;
    _coreAccum = 0.0; _glowAccum = 0.0; _creepAccum = 0.0;
    _spireAccum = 0.0; _mistAccum = 0.0; _contactAccum = 0.0;
  }

  // ── Main tick ──────────────────────────────────────────────────────────────

  @override
  void tick(ParticleSystem system, double dt, Vector3 wind) {
    if (!active) return;
    chargeTime += dt;

    final rs    = rangeScale;
    final range = baseRange * rs;

    _perpInto(direction, _right);
    direction.crossInto(_right, _up); _up.normalize();

    final ip = origin + direction.scaled(range);

    // ── Muzzle flare: one-shot radial burst on key-press ─────────────────
    if (!_flareEmitted) { _flareEmitted = true; _emitMuzzleFlare(system); }

    // ── Extension: traveling tip sphere ──────────────────────────────────
    if (!_extended) {
      _tipTimer -= dt;
      if (_tipTimer <= 0) {
        _tipTimer = 0.045;
        final frac   = (chargeTime / kExtendDuration).clamp(0.0, 1.0);
        final tipPos = origin + direction.scaled(range * frac);
        _emitTipSphere(system, tipPos);
      }
    }

    // ── Laser core ────────────────────────────────────────────────────────
    _coreAccum += coreRate * dt;
    final nc = _coreAccum.floor().toInt(); _coreAccum -= nc;
    for (int i = 0; i < nc; i++) _emitBeamCore(system, wind, range);

    // ── Beam glow ─────────────────────────────────────────────────────────
    _glowAccum += glowRate * dt;
    final ng = _glowAccum.floor().toInt(); _glowAccum -= ng;
    for (int i = 0; i < ng; i++) _emitBeamGlow(system, wind, range);

    if (!_extended) return;

    // ── One-time first-contact blast ──────────────────────────────────────
    if (!_impactEmitted) { _impactEmitted = true; _emitInitialBlast(system, ip); }

    // ── Secondary: perpendicular ring ─────────────────────────────────────
    _ringTimer -= dt;
    if (_ringTimer <= 0) { _ringTimer = 0.25; _emitImpactRing(system, ip, 28); }

    // ── Tertiary: ground creep ─────────────────────────────────────────────
    _creepAccum += creepRate * dt;
    final ncr = _creepAccum.floor().toInt(); _creepAccum -= ncr;
    for (int i = 0; i < ncr; i++) _emitGroundCreep(system, ip, wind);

    // ── Quaternary: ice spire ──────────────────────────────────────────────
    _spireAccum += spireRate * dt;
    final ns = _spireAccum.floor().toInt(); _spireAccum -= ns;
    for (int i = 0; i < ns; i++) _emitIceSpire(system, ip, wind);

    // ── Frost mist buildup ─────────────────────────────────────────────────
    _mistAccum += mistRate * dt;
    final nm = _mistAccum.floor().toInt(); _mistAccum -= nm;
    for (int i = 0; i < nm; i++) _emitImpactMist(system, ip, wind);

    // ── Contact glow: persistent scar at impact ────────────────────────────
    _contactAccum += contactRate * dt;
    final ncg = _contactAccum.floor().toInt(); _contactAccum -= ncg;
    for (int i = 0; i < ncg; i++) _emitContactGlow(system, ip);
  }

  // ── Muzzle flare: instant ring on key-press ───────────────────────────────

  void _emitMuzzleFlare(ParticleSystem system) {
    for (int i = 0; i < 32; i++) {
      final phi = i / 32 * math.pi * 2;
      final cr  = math.cos(phi), sr2 = math.sin(phi);
      final spd = 22.0 + _rng.nextDouble() * 16.0;
      system.emit(Particle(
        position: Vector3.copy(origin),
        velocity: Vector3(
          (_right.x * cr + _up.x * sr2) * spd,
          (_right.y * cr + _up.y * sr2) * spd + 1.0,
          (_right.z * cr + _up.z * sr2) * spd,
        ),
        lifetime: 0.14 + _rng.nextDouble() * 0.14,
        size:     0.07 + _rng.nextDouble() * 0.15,
        isFire: false, isEmber: true, isIce: true,
        sourceX: origin.x, sourceZ: origin.z,
      ));
    }
  }

  // ── Traveling tip sphere: bright radial burst at advancing beam front ─────
  //
  // The sphere moves with the extension progress, visually marking the leading
  // edge of the beam as it draws itself across space.

  void _emitTipSphere(ParticleSystem system, Vector3 tip) {
    for (int i = 0; i < 35; i++) {
      // Random direction in a sphere.
      final theta = _rng.nextDouble() * math.pi;
      final phi   = _rng.nextDouble() * math.pi * 2;
      final spd   = 12.0 + _rng.nextDouble() * 18.0;
      system.emit(Particle(
        position: Vector3.copy(tip),
        velocity: Vector3(
          math.sin(theta) * math.cos(phi) * spd,
          math.sin(theta) * math.sin(phi) * spd,
          math.cos(theta)                 * spd,
        ),
        lifetime: 0.10 + _rng.nextDouble() * 0.10,
        size:     0.18 + _rng.nextDouble() * 0.22,
        isFire: false, isEmber: true, isIce: true,
        sourceX: tip.x, sourceZ: tip.z,
      ));
    }
  }

  // ── Laser core: ultra-tight solid luminous rod ────────────────────────────
  //
  // 480/sec at 0.017 rad and 82 wu/s fills the beam with ~330 particles at
  // any moment.  Additive blending stacks them into a solid glowing cylinder.
  // Lifetime is capped to effectiveRange during the extension phase so the
  // beam tip tracks the advancing front.

  void _emitBeamCore(ParticleSystem system, Vector3 wind, double range) {
    _coneDir(direction, 0.017, _dir);
    final speed = laserSpeed + _rng.nextDouble() * 14.0;
    final er    = _effectiveRange(range);
    final life  = (er / speed * (0.55 + _rng.nextDouble() * 0.35)).clamp(0.01, 2.0);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.01,
        _dir.y * speed + wind.y * 0.01,
        _dir.z * speed + wind.z * 0.01,
      ),
      lifetime: life, size: 0.03 + _rng.nextDouble() * 0.04,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Beam glow: wider bloom halo around core ───────────────────────────────
  //
  // Larger particles at a slightly wider angle.  Additive stacking creates
  // the glowing aura that makes the beam look radiant and thick.

  void _emitBeamGlow(ParticleSystem system, Vector3 wind, double range) {
    _coneDir(direction, 0.042, _dir);
    final speed = (laserSpeed * 0.88) + _rng.nextDouble() * 12.0;
    final er    = _effectiveRange(range);
    final life  = (er / speed * (0.45 + _rng.nextDouble() * 0.30)).clamp(0.01, 2.0);
    system.emit(Particle(
      position: Vector3.copy(origin),
      velocity: Vector3(
        _dir.x * speed + wind.x * 0.01,
        _dir.y * speed + wind.y * 0.01,
        _dir.z * speed + wind.z * 0.01,
      ),
      lifetime: life, size: 0.11 + _rng.nextDouble() * 0.10,
      isFire: false, isEmber: true, isIce: true,
      sourceX: origin.x, sourceZ: origin.z,
    ));
  }

  // ── Initial blast: 100-particle eruption on first contact ─────────────────

  void _emitInitialBlast(ParticleSystem system, Vector3 ip) {
    // 30 ring particles
    for (int i = 0; i < 30; i++) {
      final phi = i / 30 * math.pi * 2;
      final cr  = math.cos(phi), sr2 = math.sin(phi);
      final spd = 16.0 + _rng.nextDouble() * 18.0;
      system.emit(Particle(
        position: Vector3.copy(ip),
        velocity: Vector3(
          (_right.x * cr + _up.x * sr2) * spd,
          (_right.y * cr + _up.y * sr2) * spd + 2.0,
          (_right.z * cr + _up.z * sr2) * spd,
        ),
        lifetime: 0.35 + _rng.nextDouble() * 0.35,
        size: 0.12 + _rng.nextDouble() * 0.18,
        isFire: false, isEmber: true, isIce: true,
        sourceX: ip.x, sourceZ: ip.z,
      ));
    }
    // 40 upward spire burst
    for (int i = 0; i < 40; i++) {
      system.emit(Particle(
        position: Vector3(ip.x + (_rng.nextDouble() - 0.5) * 1.5,
                          ip.y,
                          ip.z + (_rng.nextDouble() - 0.5) * 1.5),
        velocity: Vector3(
          (_rng.nextDouble() - 0.5) * 4.0,
          18.0 + _rng.nextDouble() * 16.0,
          (_rng.nextDouble() - 0.5) * 4.0,
        ),
        lifetime: 0.50 + _rng.nextDouble() * 0.40,
        size: 0.10 + _rng.nextDouble() * 0.22,
        isFire: false, isEmber: true, isIce: true,
        sourceX: ip.x, sourceZ: ip.z,
      ));
    }
    // 30 omnidirectional
    for (int i = 0; i < 30; i++) {
      final theta = _rng.nextDouble() * math.pi;
      final phi   = _rng.nextDouble() * math.pi * 2;
      final spd   = 10.0 + _rng.nextDouble() * 20.0;
      system.emit(Particle(
        position: Vector3.copy(ip),
        velocity: Vector3(
          math.sin(theta) * math.cos(phi) * spd,
          math.sin(theta) * math.sin(phi) * spd,
          math.cos(theta)                 * spd,
        ),
        lifetime: 0.30 + _rng.nextDouble() * 0.50,
        size: 0.08 + _rng.nextDouble() * 0.18,
        isFire: false, isEmber: true, isIce: true,
        sourceX: ip.x, sourceZ: ip.z,
      ));
    }
  }

  // ── Secondary: perpendicular ring ─────────────────────────────────────────

  void _emitImpactRing(ParticleSystem system, Vector3 ip, int count) {
    for (int i = 0; i < count; i++) {
      final phi = i / count * math.pi * 2;
      final cr  = math.cos(phi), sr2 = math.sin(phi);
      final spd = 18.0 + _rng.nextDouble() * 14.0;
      system.emit(Particle(
        position: Vector3.copy(ip),
        velocity: Vector3(
          (_right.x * cr + _up.x * sr2) * spd,
          (_right.y * cr + _up.y * sr2) * spd + 1.5,
          (_right.z * cr + _up.z * sr2) * spd,
        ),
        lifetime: 0.32 + _rng.nextDouble() * 0.28,
        size:     0.08 + _rng.nextDouble() * 0.12,
        isFire: false, isEmber: true, isIce: true,
        sourceX: ip.x, sourceZ: ip.z,
      ));
    }
  }

  // ── Tertiary: ground creep — frost spreading horizontally ─────────────────
  //
  // Particles spread in the XZ plane with very low Y velocity, simulating
  // frost advancing outward along the ground surface.

  void _emitGroundCreep(ParticleSystem system, Vector3 ip, Vector3 wind) {
    final phi = _rng.nextDouble() * math.pi * 2;
    final spd = 10.0 + _rng.nextDouble() * 16.0;
    system.emit(Particle(
      position: Vector3(
        ip.x + (_rng.nextDouble() - 0.5) * 0.5,
        ip.y,
        ip.z + (_rng.nextDouble() - 0.5) * 0.5,
      ),
      velocity: Vector3(
        math.cos(phi) * spd + wind.x * 0.08,
        0.25 + _rng.nextDouble() * 0.70,
        math.sin(phi) * spd + wind.z * 0.08,
      ),
      lifetime: 0.40 + _rng.nextDouble() * 0.50,
      size:     0.05 + _rng.nextDouble() * 0.13,
      isFire: false, isEmber: true, isIce: true,
      sourceX: ip.x, sourceZ: ip.z,
    ));
  }

  // ── Quaternary: ice spire — continuous upward eruption ────────────────────

  void _emitIceSpire(ParticleSystem system, Vector3 ip, Vector3 wind) {
    final lr = _rng.nextDouble() * 1.0;
    final lp = _rng.nextDouble() * math.pi * 2;
    system.emit(Particle(
      position: Vector3(
        ip.x + math.cos(lp) * lr,
        ip.y,
        ip.z + math.sin(lp) * lr,
      ),
      velocity: Vector3(
        (_rng.nextDouble() - 0.5) * 3.0 + wind.x * 0.05,
        16.0 + _rng.nextDouble() * 14.0,
        (_rng.nextDouble() - 0.5) * 3.0 + wind.z * 0.05,
      ),
      lifetime: 0.52 + _rng.nextDouble() * 0.50,
      size:     0.06 + _rng.nextDouble() * 0.14,
      isFire: false, isEmber: true, isIce: true,
      sourceX: ip.x, sourceZ: ip.z,
    ));
  }

  // ── Frost mist: alpha-blend fog accumulating at impact ────────────────────

  void _emitImpactMist(ParticleSystem system, Vector3 ip, Vector3 wind) {
    final r   = _rng.nextDouble() * 2.8;
    final phi = _rng.nextDouble() * math.pi * 2;
    system.emit(Particle(
      position: Vector3(
        ip.x + math.cos(phi) * r,
        ip.y + (_rng.nextDouble() - 0.5) * 1.0,
        ip.z + math.sin(phi) * r,
      ),
      velocity: Vector3(wind.x * 0.14, 0.15 + _rng.nextDouble() * 0.25, wind.z * 0.14),
      lifetime: 2.0 + _rng.nextDouble() * 1.5,
      size:     0.80 + _rng.nextDouble() * 1.60,
      isFire: false, isEmber: false, isIce: true,
      sourceX: ip.x, sourceZ: ip.z,
    ));
  }

  // ── Contact glow: persistent luminous scar at the impact point ────────────
  //
  // Large, long-lived alpha-blend particles right at the impact point create
  // a glowing ground scar that outlasts the beam's secondary effects.

  void _emitContactGlow(ParticleSystem system, Vector3 ip) {
    final r   = _rng.nextDouble() * 1.0;
    final phi = _rng.nextDouble() * math.pi * 2;
    system.emit(Particle(
      position: Vector3(ip.x + math.cos(phi) * r, ip.y, ip.z + math.sin(phi) * r),
      velocity: Vector3(0, 0.08 + _rng.nextDouble() * 0.12, 0),
      lifetime: 3.0 + _rng.nextDouble() * 2.0,
      size:     1.20 + _rng.nextDouble() * 1.40,
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
