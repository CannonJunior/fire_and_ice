import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import '../systems/ability_system.dart';
import 'game_state.dart';

// ── FireEmitter ───────────────────────────────────────────────────────────────
// Manages a single fire source: continuously emits fire and smoke particles.
// Used for static terrain fire zones and dynamic wyvern-breath ground fires.

class FireEmitter {
  /// World-space XZ centre (Y is sampled from terrain via terrainHeight).
  final double worldX, worldZ;

  /// Horizontal spread radius for particle birth positions.
  final double radius;

  /// Intensity 0..1 (0 = extinguished, stops emitting).
  double intensity;

  double _emitAccum = 0.0;
  final math.Random _rng;

  // Config (injected from FireEmitterSystem after JSON load)
  double emitRate      = 60.0;
  double fireLifeMin   = 1.2;
  double fireLifeMax   = 2.8;
  double fireSizeMin   = 0.4;
  double fireSizeMax   = 1.8;
  double smokeSizeMin  = 1.2;
  double smokeSizeMax  = 4.5;

  FireEmitter({
    required this.worldX,
    required this.worldZ,
    this.radius    = 10.0,
    this.intensity = 1.0,
    math.Random? rng,
  }) : _rng = rng ?? math.Random();

  /// Emit particles into [system] for this frame.
  void tick(ParticleSystem system, double dt, double terrainY) {
    if (intensity <= 0.0) return;

    _emitAccum += emitRate * intensity * dt;
    final count = _emitAccum.floor();
    _emitAccum -= count;

    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final r     = _rng.nextDouble() * radius;
      final px    = worldX + math.cos(angle) * r;
      final pz    = worldZ + math.sin(angle) * r;
      final py    = terrainY + _rng.nextDouble() * 1.5;

      final life = fireLifeMin + _rng.nextDouble() * (fireLifeMax - fireLifeMin);
      final size = fireSizeMin + _rng.nextDouble() * (fireSizeMax - fireSizeMin);

      final vx = (_rng.nextDouble() - 0.5) * 0.4;
      final vz = (_rng.nextDouble() - 0.5) * 0.4;
      final vy = 1.5 + _rng.nextDouble() * 2.0;

      system.emit(Particle(
        position: Vector3(px, py, pz),
        velocity: Vector3(vx, vy, vz),
        lifetime: life,
        size:     size,
        isFire:   true,
      ));
    }
  }
}

// ── WyvernBreathEmitter ───────────────────────────────────────────────────────
// A directed cone emitter representing wyvern fire breath.
// Spawns fast-moving fire particles in a cone from the wyvern's mouth.

class WyvernBreathEmitter {
  Vector3 origin;     // Wyvern mouth world position (updated each frame)
  Vector3 direction;  // Normalised forward direction of breath
  double halfAngle;   // Cone half-angle in radians
  double range;       // Maximum particle travel distance
  bool active = false;
  double _timer = 0.0;
  double duration = 2.5;

  double emitRate    = 200.0;
  double _emitAccum  = 0.0;
  final math.Random _rng = math.Random();

  WyvernBreathEmitter({
    required this.origin,
    required this.direction,
    this.halfAngle = 0.49, // ~28 degrees
    this.range     = 45.0,
  });

  void startBreath() { active = true; _timer = 0.0; }
  void stopBreath()  { active = false; }

  void tick(ParticleSystem system, double dt, Vector3 wind) {
    if (!active) return;
    _timer += dt;
    if (_timer >= duration) { active = false; return; }

    _emitAccum += emitRate * dt;
    final count = _emitAccum.floor();
    _emitAccum -= count;

    for (int i = 0; i < count; i++) {
      // Random direction within cone
      final theta = _rng.nextDouble() * halfAngle;
      final phi   = _rng.nextDouble() * math.pi * 2;
      final sT    = math.sin(theta);
      final cT    = math.cos(theta);

      // Perturb around the main direction
      final right = _perpendicular(direction);
      final up    = direction.cross(right).normalized();
      final conDir = (direction.scaled(cT) +
                      right.scaled(sT * math.cos(phi)) +
                      up.scaled(sT * math.sin(phi))).normalized();

      final speed = 18.0 + _rng.nextDouble() * 6.0;
      final vel   = conDir.scaled(speed) + wind.scaled(0.2);
      final life  = range / speed * (0.8 + _rng.nextDouble() * 0.4);

      system.emit(Particle(
        position: Vector3.copy(origin),
        velocity: vel,
        lifetime: life,
        size:     0.5 + _rng.nextDouble() * 0.8,
        isFire:   true,
      ));
    }
  }

  static Vector3 _perpendicular(Vector3 v) {
    final abs = Vector3(v.x.abs(), v.y.abs(), v.z.abs());
    if (abs.x <= abs.y && abs.x <= abs.z) return Vector3(0, -v.z, v.y).normalized();
    if (abs.y <= abs.z) return Vector3(-v.z, 0, v.x).normalized();
    return Vector3(-v.y, v.x, 0).normalized();
  }
}

// ── FireEmitterSystem ─────────────────────────────────────────────────────────
// Owns all active FireEmitters and the ParticleSystem.
// Loaded and ticked by game_widget.dart once per frame.

class FireEmitterSystem {
  final ParticleSystem particles;
  final List<FireEmitter> _zoneEmitters = [];
  final List<FireEmitter> _dynamicEmitters = [];
  WyvernBreathEmitter? wyvernBreath;

  // Wyvern cone damage parameters (from config)
  double wyvernDirectDmg  = 15.0;
  double wyvernEdgeDmg    = 6.0;
  double directConeRadius = 5.0;
  double edgeConeRadius   = 15.0;
  double breathRange      = 45.0;
  double breathHalfAngle  = 0.49;

  bool _configLoaded = false;

  FireEmitterSystem({required this.particles});

  bool get configLoaded => _configLoaded;

  Future<void> loadConfig() async {
    try {
      final raw  = await rootBundle.loadString('assets/data/fire_config.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final f    = data['fire'] as Map<String, dynamic>;

      particles.buoyancy        = (f['buoyancy']          as num).toDouble();
      particles.turbulenceStr   = (f['turbulenceStrength'] as num).toDouble();
      particles.windInfluence   = (f['windInfluence']      as num).toDouble();
      particles.windRadius      = (f['windRadius']         as num).toDouble();
      particles.smokeTransition = (f['smokeTransitionAge'] as num).toDouble();
      particles.smokeFadeAlt    = (f['smokeFadeAltitude']  as num).toDouble();

      final emitRate   = (f['emitRatePerSecond'] as num).toDouble();
      final fireLifeMin = (f['fireLifetimeMin']  as num).toDouble();
      final fireLifeMax = (f['fireLifetimeMax']  as num).toDouble();
      final fireSzMin  = (f['fireSizeMin']       as num).toDouble();
      final fireSzMax  = (f['fireSizeMax']       as num).toDouble();
      final smokeSzMin = (f['smokeSizeMin']      as num).toDouble();
      final smokeSzMax = (f['smokeSizeMax']      as num).toDouble();

      for (final e in [..._zoneEmitters, ..._dynamicEmitters]) {
        e.emitRate    = emitRate;
        e.fireLifeMin = fireLifeMin;  e.fireLifeMax = fireLifeMax;
        e.fireSizeMin = fireSzMin;    e.fireSizeMax = fireSzMax;
        e.smokeSizeMin = smokeSzMin;  e.smokeSizeMax = smokeSzMax;
      }

      final w = data['wyvern'] as Map<String, dynamic>;
      wyvernDirectDmg  = (w['directDamagePerSec'] as num).toDouble();
      wyvernEdgeDmg    = (w['edgeDamagePerSec']   as num).toDouble();
      directConeRadius = (w['directConeRadius']    as num).toDouble();
      edgeConeRadius   = (w['edgeConeRadius']      as num).toDouble();
      breathRange      = (w['breathRange']         as num).toDouble();
      breathHalfAngle  = (w['breathHalfAngle']     as num).toDouble() * math.pi / 180.0;

      _configLoaded = true;
      debugPrint('[FireEmitterSystem] config loaded');
    } catch (e) {
      debugPrint('[FireEmitterSystem] config load failed: $e — using defaults');
      _configLoaded = true;
    }
  }

  void initZones(GameState state) {
    _zoneEmitters.clear();
    for (int i = 0; i < GameState.firePositions.length; i++) {
      final (fx, fz) = GameState.firePositions[i];
      _zoneEmitters.add(FireEmitter(
        worldX: fx, worldZ: fz,
        radius: GameState.fireRadius * 0.7,
        intensity: state.fireExtinguished[i] ? 0.0 : 1.0,
      ));
    }
  }

  /// Spawn a transient ground fire at (wx, wz) lasting [duration] seconds.
  void spawnGroundFire(double wx, double wz, double duration) {
    final e = FireEmitter(worldX: wx, worldZ: wz, radius: 4.0, intensity: 1.0);
    _dynamicEmitters.add(e);
    // Schedule extinction after duration via a simple countdown stored in intensity
    // (intensity decays linearly to 0 over duration)
    _groundFireTimers[e] = duration;
  }

  final Map<FireEmitter, double> _groundFireTimers = {};

  void tick(GameState state, double dt, double Function(double, double) terrainHeightAt) {
    // Sync zone emitter intensities with extinguished flags
    for (int i = 0; i < _zoneEmitters.length; i++) {
      _zoneEmitters[i].intensity = state.fireExtinguished[i] ? 0.0 : 1.0;
    }

    final wind = state.apparentWind;
    final pp   = state.playerPosition;

    // Tick zone emitters
    for (final e in _zoneEmitters) {
      final y = terrainHeightAt(e.worldX, e.worldZ);
      e.tick(particles, dt, y);
    }

    // Tick dynamic ground fires + decay timers
    final toRemove = <FireEmitter>[];
    for (final e in _dynamicEmitters) {
      final remaining = (_groundFireTimers[e] ?? 0.0) - dt;
      if (remaining <= 0) { toRemove.add(e); continue; }
      _groundFireTimers[e] = remaining;
      e.intensity = (remaining / (_groundFireTimers[e]! + dt)).clamp(0.0, 1.0);
      e.tick(particles, dt, terrainHeightAt(e.worldX, e.worldZ));
    }
    for (final e in toRemove) { _dynamicEmitters.remove(e); _groundFireTimers.remove(e); }

    // Tick wyvern breath
    wyvernBreath?.tick(particles, dt, wind);

    // Apply wyvern breath damage to player
    _applyWyvernDamage(state, dt);

    // Advance particle physics
    particles.tick(dt, wind, pp);
  }

  void emitAbilityBurst(VisualEffect effect, int particleCount, double spread) {
    final rng = math.Random();
    for (int i = 0; i < particleCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final elev  = (rng.nextDouble() - 0.3) * math.pi;
      final r     = rng.nextDouble() * spread;
      final vel   = Vector3(
        math.cos(angle) * math.cos(elev) * r,
        math.sin(elev).abs() * r + 1.5,
        math.sin(angle) * math.cos(elev) * r,
      );
      final isFireAbility = effect.color.r > 0.5;
      particles.emit(Particle(
        position: Vector3.copy(effect.position),
        velocity: vel,
        lifetime: 0.6 + rng.nextDouble() * 0.8,
        size:     0.3 + rng.nextDouble() * 0.5,
        isFire:   isFireAbility,
      ));
    }
  }

  void _applyWyvernDamage(GameState state, double dt) {
    final breath = wyvernBreath;
    if (breath == null || !breath.active) return;

    final toPlayer = state.playerPosition - breath.origin;
    final dist     = toPlayer.length;
    if (dist > breathRange) return;

    final dot = toPlayer.normalized().dot(breath.direction);
    final angleDiff = math.acos(dot.clamp(-1.0, 1.0));

    if (angleDiff < directConeRadius / dist) {
      state.takeDamage(wyvernDirectDmg * dt);
    } else if (angleDiff < edgeConeRadius / dist) {
      state.takeDamage(wyvernEdgeDmg * dt);
    }
  }

  /// Returns the world-space Y-centre of each active fire zone for lighting.
  List<(double, double, double, double)> get fireLightPositions {
    final result = <(double, double, double, double)>[];
    for (int i = 0; i < _zoneEmitters.length; i++) {
      final e = _zoneEmitters[i];
      result.add((e.worldX, 2.0, e.worldZ, e.intensity));
    }
    return result;
  }
}
