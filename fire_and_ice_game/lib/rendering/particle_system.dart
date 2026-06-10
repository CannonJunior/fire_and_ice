import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

// ── Particle data ─────────────────────────────────────────────────────────────

class Particle {
  Vector3 position;
  Vector3 velocity;
  double lifetime;
  double age;
  double size;
  bool isFire;

  /// Embers shoot up out of the fire but never convert to smoke.
  bool isEmber;

  /// World-space XZ position of the emitter that spawned this particle.
  /// Used for source-based wind attenuation and updraft column.
  double sourceX;
  double sourceZ;

  /// Normalised temperature [0..1] — drives GPU blackbody coloring.
  double temperature;

  /// Billboard rotation angle (radians) — smoke rotates slowly after spawn.
  double rotation;

  /// Fuel remaining [0..1] — dims fire colour as the particle ages.
  double fuelFraction;

  /// Ice-breath particle — crystal sparks (isEmber=true) or frost mist (!isEmber).
  /// writeColor() outputs blue-white; crystals go additive, mist goes alpha-blend.
  bool isIce;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifetime,
    required this.size,
    required this.isFire,
    this.isEmber      = false,
    this.isIce        = false,
    this.sourceX      = 0.0,
    this.sourceZ      = 0.0,
    this.temperature  = 0.8,
    this.rotation     = 0.0,
    this.fuelFraction = 1.0,
  }) : age = 0.0;

  Particle.blank()
    : position    = Vector3.zero(),
      velocity    = Vector3.zero(),
      lifetime    = 0.0,
      size        = 1.0,
      isFire      = false,
      isEmber     = false,
      isIce       = false,
      sourceX     = 0.0,
      sourceZ     = 0.0,
      temperature = 0.8,
      rotation    = 0.0,
      fuelFraction= 1.0,
      age         = 0.0;

  bool get isDead => age >= lifetime;
  double get t => (age / lifetime).clamp(0.0, 1.0);

  Vector4 get color {
    final out = Vector4.zero();
    writeColor(out);
    return out;
  }

  /// Fire/ember: GPU owns RGB via blackbody; we pass (temperature, 0, 0, fade).
  /// Ice crystal (isEmber+isIce): bright blue-white → additive sparks.
  /// Ice mist (!isEmber, isIce): pale electric blue → alpha-blend fog.
  /// Smoke: dark charcoal at birth (near fire), ages to cream/tan as it rises.
  void writeColor(Vector4 out) {
    final t_ = t;
    if (isIce) {
      if (isEmber) {
        // Crystal shard: blue-white, fade out over lifetime.
        final fade = (1.0 - t_ * 0.55).clamp(0.0, 1.0);
        out.setValues(0.68, 0.91, 1.0, fade * 0.95);
      } else {
        // Frost mist: electric blue, brief fade-in then slow fade-out.
        final fade = t_ < 0.14
            ? t_ / 0.14
            : (1.0 - (t_ - 0.14) / 0.86).clamp(0.0, 1.0);
        out.setValues(0.28, 0.70, 1.0, fade * 0.52);
      }
      return;
    }
    if (isFire || isEmber) {
      out.setValues(temperature, 0.0, 0.0, 1.0 - t_ * 0.4);
    } else {
      // Color: near-black at birth → medium gray mid-life → cream/tan at top.
      // This matches wildfire reference: dark base column, lighter billowing top.
      final r = t_ < 0.4
          ? 0.06 + t_ * 0.60        // 0.06 → 0.30 (dark soot → gray)
          : 0.30 + (t_ - 0.4) * 0.90; // 0.30 → 0.84 (gray → cream)
      final g = t_ < 0.4
          ? 0.05 + t_ * 0.50
          : 0.25 + (t_ - 0.4) * 0.85;
      final b = t_ < 0.4
          ? 0.04 + t_ * 0.38
          : 0.19 + (t_ - 0.4) * 0.70;
      // Hold at near-full opacity for 70% of life, then fade out sharply.
      final alpha = t_ < 0.70
          ? 0.92
          : 0.92 * (1.0 - (t_ - 0.70) / 0.30);
      out.setValues(r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0), alpha);
    }
  }
}

// ── CPU particle system ───────────────────────────────────────────────────────

class ParticleSystem {
  final int maxParticles;
  final List<Particle> _particles = [];
  final List<Particle> _pool      = [];
  final math.Random _rng = math.Random();

  double buoyancy          = 5.2;
  double turbulenceStr     = 0.8;
  double windInfluence     = 0.55;
  double smokeWindInfluence = 0.88; // smoke drifts much more strongly with wind
  double windRadius        = 60.0;
  double smokeTransition   = 0.6;
  double smokeFadeAlt      = 200.0;
  double updraftStrength   = 3.0;
  double updraftSigma      = 3.0;
  double smokeBuoyancy     = 12.0;
  double smokeLifeMin      = 22.0;
  double smokeLifeMax      = 40.0;
  double smokeSizeGrowth   =  0.9;  // world-units/sec billboard expansion
  double smokeInitSizeMult =  5.0;  // size scale-up when fire converts to smoke

  // Pre-allocated scratch vectors — eliminates ~36k Vector3 allocs/frame at 6k particles.
  final Vector3 _windScratch  = Vector3.zero();
  final Vector3 _turbScratch  = Vector3.zero();
  final Vector3 _accelScratch = Vector3.zero();
  final Vector3 _dtmpScratch  = Vector3.zero();

  ParticleSystem({this.maxParticles = 5000});

  List<Particle> get particles => _particles;

  void tick(double dt, Vector3 wind, Vector3 playerPos) {
    for (final p in _particles) {
      if (p.isDead) continue;

      // Wind attenuation — no Vector3 allocation for distance.
      final double windDist;
      if (p.isFire || p.isEmber) {
        final dx = p.position.x - p.sourceX;
        final dz = p.position.z - p.sourceZ;
        windDist = math.sqrt(dx * dx + dz * dz);
      } else {
        final dx = p.position.x - playerPos.x;
        final dy = p.position.y - playerPos.y;
        final dz = p.position.z - playerPos.z;
        windDist = math.sqrt(dx * dx + dy * dy + dz * dz);
      }
      final wFactor    = (1.0 - windDist / windRadius).clamp(0.0, 1.0);
      final wInfluence = (p.isFire || p.isEmber) ? windInfluence : smokeWindInfluence;
      _windScratch.setFrom(wind);
      _windScratch.scale(wInfluence * wFactor);

      // Turbulence — reuse scratch, no alloc.
      final hx = _hash(p.position.x * 3.7 + p.age * 0.8);
      final hz = _hash(p.position.z * 5.1 + p.age * 0.6);
      _turbScratch.setValues(hx * 2 - 1, 0, hz * 2 - 1);
      _turbScratch.scale(turbulenceStr);

      const gravity = -9.8;
      final double netUp;
      if (p.isEmber)     { netUp = buoyancy * 0.5 + gravity; }
      else if (p.isFire) { netUp = buoyancy + gravity; }
      else               { netUp = smokeBuoyancy + gravity; }

      // Updraft column (Gaussian plume; skip if > 3σ).
      double updraftY = 0.0;
      if (p.isFire || p.isEmber) {
        final dx = p.position.x - p.sourceX;
        final dz = p.position.z - p.sourceZ;
        final r  = math.sqrt(dx * dx + dz * dz);
        if (r <= updraftSigma * 3.0) {
          updraftY = updraftStrength *
              math.exp(-r * r / (2.0 * updraftSigma * updraftSigma));
        }
      }

      // Compose acceleration in-place — no intermediate Vector3 allocs.
      _accelScratch.setValues(0, netUp + updraftY, 0);
      _accelScratch.add(_windScratch);
      _accelScratch.add(_turbScratch);

      _dtmpScratch.setFrom(_accelScratch);
      _dtmpScratch.scale(dt);
      p.velocity.add(_dtmpScratch);

      _dtmpScratch.setFrom(p.velocity);
      _dtmpScratch.scale(dt);
      p.position.add(_dtmpScratch);
      p.age += dt;

      if (p.isFire) p.fuelFraction = (1.0 - p.t).clamp(0.0, 1.0);

      if (!p.isFire && !p.isEmber) {
        p.rotation += dt * 0.28;
        p.size     += smokeSizeGrowth * dt;
      }

      if (p.isFire && p.t >= smokeTransition && !p.isDead) {
        _maybeTurnToSmoke(p);
      }
    }

    // Swap-remove dead particles, returning them to the pool for reuse.
    int i = 0;
    while (i < _particles.length) {
      if (_particles[i].isDead) {
        _pool.add(_particles[i]);
        _particles[i] = _particles.last;
        _particles.removeLast();
      } else {
        i++;
      }
    }
  }

  void _maybeTurnToSmoke(Particle p) {
    if (p.isEmber) return;
    if (p.isFire && p.t >= smokeTransition) {
      p.isFire      = false;
      p.lifetime    = p.age + smokeLifeMin +
                      _rng.nextDouble() * (smokeLifeMax - smokeLifeMin);
      p.size       *= smokeInitSizeMult;
      p.velocity.y *= 0.55; // retain upward momentum
      p.rotation    = _rng.nextDouble() * math.pi * 2;
    }
  }

  /// Acquire a particle from the pool (or create a new one) and add it to the
  /// active list.  Returns null when at capacity.  Fields are reset to safe
  /// defaults — caller must set position, velocity, lifetime, size, and isFire
  /// before the particle is first ticked.
  Particle? acquire() {
    if (_particles.length >= maxParticles) return null;
    final p = _pool.isNotEmpty ? _pool.removeLast() : Particle.blank();
    p.age         = 0.0;
    p.isFire      = false;
    p.isEmber     = false;
    p.isIce       = false;
    p.sourceX     = 0.0;
    p.sourceZ     = 0.0;
    p.temperature = 0.8;
    p.rotation    = 0.0;
    p.fuelFraction= 1.0;
    _particles.add(p);
    return p;
  }

  bool emit(Particle p) {
    if (_particles.length >= maxParticles) return false;
    _particles.add(p);
    return true;
  }

  void emitMany(List<Particle> ps) {
    for (final p in ps) {
      if (!emit(p)) break;
    }
  }

  void clear() {
    _pool.addAll(_particles);
    _particles.clear();
  }

  static double _hash(double v) =>
      (math.sin(v * 127.1) * 43758.5453).abs() % 1.0;
}
