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

  Particle({
    required this.position,
    required this.velocity,
    required this.lifetime,
    required this.size,
    required this.isFire,
    this.isEmber      = false,
    this.sourceX      = 0.0,
    this.sourceZ      = 0.0,
    this.temperature  = 0.8,
    this.rotation     = 0.0,
    this.fuelFraction = 1.0,
  }) : age = 0.0;

  bool get isDead => age >= lifetime;
  double get t => (age / lifetime).clamp(0.0, 1.0);

  Vector4 get color {
    final out = Vector4.zero();
    writeColor(out);
    return out;
  }

  /// Fire/ember: GPU owns RGB via blackbody; we pass (temperature, 0, 0, fade).
  /// Smoke: dark charcoal at birth (near fire), ages to cream/tan as it rises.
  void writeColor(Vector4 out) {
    final t_ = t;
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
  double smokeBuoyancy     =  9.0;
  double smokeLifeMin      = 22.0;
  double smokeLifeMax      = 40.0;
  double smokeSizeGrowth   =  0.9;  // world-units/sec billboard expansion
  double smokeInitSizeMult =  5.0;  // size scale-up when fire converts to smoke

  ParticleSystem({this.maxParticles = 5000});

  List<Particle> get particles => _particles;

  void tick(double dt, Vector3 wind, Vector3 playerPos) {
    for (final p in _particles) {
      if (p.isDead) continue;

      // Wind attenuation: fire/ember attenuate by distance from source;
      // smoke uses player distance but a much higher influence factor so it
      // visibly drifts in wind direction matching real wildfire plume behaviour.
      final double windDist;
      if (p.isFire || p.isEmber) {
        final dx = p.position.x - p.sourceX;
        final dz = p.position.z - p.sourceZ;
        windDist = math.sqrt(dx * dx + dz * dz);
      } else {
        windDist = (p.position - playerPos).length;
      }
      final wFactor = (1.0 - windDist / windRadius).clamp(0.0, 1.0);
      final wInfluence = (p.isFire || p.isEmber) ? windInfluence : smokeWindInfluence;
      final windForce = wind.scaled(wInfluence * wFactor);

      // Turbulence: lightweight hash noise on XZ position.
      final hx  = _hash(p.position.x * 3.7 + p.age * 0.8);
      final hz  = _hash(p.position.z * 5.1 + p.age * 0.6);
      final turb = Vector3(hx * 2 - 1, 0, hz * 2 - 1)..scale(turbulenceStr);

      // Buoyancy: fire and embers use fire buoyancy; smoke uses its own
      // higher value so it actually rises (fire's 0.3 fraction < gravity).
      const gravity = -9.8;
      final double netUp;
      if (p.isEmber)      { netUp = buoyancy * 0.5 + gravity; }
      else if (p.isFire)  { netUp = buoyancy + gravity; }
      else                { netUp = smokeBuoyancy + gravity; }

      // Updraft column (Gaussian plume from birth source; skip if > 3σ).
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

      final accel = Vector3(0, netUp + updraftY, 0) + windForce + turb;
      p.velocity.add(accel.scaled(dt));
      p.position.add(p.velocity.scaled(dt));
      p.age += dt;

      // Decay fuel fraction with age for fire particles.
      if (p.isFire) p.fuelFraction = (1.0 - p.t).clamp(0.0, 1.0);

      // Smoke: rotate slowly and expand size (billowing growth).
      if (!p.isFire && !p.isEmber) {
        p.rotation += dt * 0.28;
        p.size     += smokeSizeGrowth * dt;
      }

      // Convert fire → smoke at transition age.
      if (p.isFire && p.t >= smokeTransition && !p.isDead) {
        _maybeTurnToSmoke(p);
      }
    }
    _particles.removeWhere((p) => p.isDead);
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

  void clear() => _particles.clear();

  static double _hash(double v) =>
      (math.sin(v * 127.1) * 43758.5453).abs() % 1.0;
}
