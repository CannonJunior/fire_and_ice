import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';
import '../systems/ability_system.dart';
import 'game_state.dart';

// ── FireEmitter ───────────────────────────────────────────────────────────────
// Manages a single fire source: continuously emits fire particles and bursty embers.

class FireEmitter {
  final double worldX, worldZ;
  double radius;
  double intensity;

  double _emitAccum    = 0.0;
  double _emberAccum   = 0.0;
  double _nextBurstAt  = 0.5; // seconds until next ember burst
  final math.Random _rng;

  double emitRate      = 60.0;
  double fireLifeMin   = 1.2;
  double fireLifeMax   = 2.8;
  double fireSizeMin   = 0.4;
  double fireSizeMax   = 1.8;
  double smokeSizeMin  = 1.2;
  double smokeSizeMax  = 4.5;
  double leanFactor    = 0.12; // wind lean applied at particle birth

  FireEmitter({
    required this.worldX,
    required this.worldZ,
    this.radius    = 10.0,
    this.intensity = 1.0,
    math.Random? rng,
  }) : _rng = rng ?? math.Random();

  void tick(ParticleSystem system, double dt, double terrainY, Vector3 wind) {
    if (intensity <= 0.0) return;

    // Regular fire particles
    _emitAccum += emitRate * intensity * dt;
    final count = _emitAccum.floor();
    _emitAccum -= count;
    for (int i = 0; i < count; i++) {
      _emitFire(system, terrainY, wind);
    }

    // Bursty ember emission: random burst interval 0.3–1.0 s
    _emberAccum += dt;
    if (_emberAccum >= _nextBurstAt) {
      _emberAccum  = 0;
      _nextBurstAt = 0.3 + _rng.nextDouble() * 0.7;
      final n = 2 + _rng.nextInt(4); // 2–5 embers per burst
      for (int i = 0; i < n; i++) {
        _emitEmber(system, terrainY);
      }
    }
  }

  void _emitFire(ParticleSystem system, double terrainY, Vector3 wind) {
    final angle = _rng.nextDouble() * math.pi * 2;
    final r     = _rng.nextDouble() * radius;
    final px    = worldX + math.cos(angle) * r;
    final pz    = worldZ + math.sin(angle) * r;
    final py    = terrainY + _rng.nextDouble() * 1.5;

    final life  = fireLifeMin + _rng.nextDouble() * (fireLifeMax - fireLifeMin);
    final size  = fireSizeMin + _rng.nextDouble() * (fireSizeMax - fireSizeMin);

    // Wind lean at birth: slight horizontal offset in wind direction.
    final vx = (_rng.nextDouble() - 0.5) * 0.4 + wind.x * leanFactor;
    final vz = (_rng.nextDouble() - 0.5) * 0.4 + wind.z * leanFactor;
    final vy = 1.5 + _rng.nextDouble() * 2.0;

    system.emit(Particle(
      position:     Vector3(px, py, pz),
      velocity:     Vector3(vx, vy, vz),
      lifetime:     life,
      size:         size,
      isFire:       true,
      sourceX:      worldX,
      sourceZ:      worldZ,
      temperature:  0.7 + _rng.nextDouble() * 0.3,
      fuelFraction: 1.0,
    ));
  }

  void _emitEmber(ParticleSystem system, double terrainY) {
    final angle = _rng.nextDouble() * math.pi * 2;
    final r     = _rng.nextDouble() * radius * 0.5;
    final px    = worldX + math.cos(angle) * r;
    final pz    = worldZ + math.sin(angle) * r;
    final py    = terrainY + 0.5 + _rng.nextDouble() * 2.0;

    // Embers shoot upward with high initial velocity.
    final vx = (_rng.nextDouble() - 0.5) * 1.2;
    final vz = (_rng.nextDouble() - 0.5) * 1.2;
    final vy = 3.0 + _rng.nextDouble() * 4.0;

    system.emit(Particle(
      position:     Vector3(px, py, pz),
      velocity:     Vector3(vx, vy, vz),
      lifetime:     6.0 + _rng.nextDouble() * 12.0,
      size:         0.1 + _rng.nextDouble() * 0.2,
      isFire:       false,
      isEmber:      true,
      sourceX:      worldX,
      sourceZ:      worldZ,
      temperature:  0.4 + _rng.nextDouble() * 0.3,
      fuelFraction: 1.0,
    ));
  }
}

// ── WyvernBreathEmitter ───────────────────────────────────────────────────────

class WyvernBreathEmitter {
  Vector3 origin;
  Vector3 direction;
  double halfAngle;
  double range;
  bool active = false;
  double _timer = 0.0;
  double duration = 2.5;

  double emitRate   = 200.0;
  double _emitAccum = 0.0;
  final math.Random _rng = math.Random();

  WyvernBreathEmitter({
    required this.origin,
    required this.direction,
    this.halfAngle = 0.49,
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
      final theta = _rng.nextDouble() * halfAngle;
      final phi   = _rng.nextDouble() * math.pi * 2;
      final sT    = math.sin(theta);
      final cT    = math.cos(theta);

      final right = _perpendicular(direction);
      final up    = direction.cross(right).normalized();
      final conDir = (direction.scaled(cT) +
                      right.scaled(sT * math.cos(phi)) +
                      up.scaled(sT * math.sin(phi))).normalized();

      final speed = 18.0 + _rng.nextDouble() * 6.0;
      final vel   = conDir.scaled(speed) + wind.scaled(0.2);
      final life  = range / speed * (0.8 + _rng.nextDouble() * 0.4);

      system.emit(Particle(
        position:    Vector3.copy(origin),
        velocity:    vel,
        lifetime:    life,
        size:        0.5 + _rng.nextDouble() * 0.8,
        isFire:      true,
        sourceX:     origin.x,
        sourceZ:     origin.z,
        temperature: 0.8,
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

class FireEmitterSystem {
  final ParticleSystem particles;
  final List<FireEmitter> _zoneEmitters    = [];
  final List<FireEmitter> _dynamicEmitters = [];
  WyvernBreathEmitter? wyvernBreath;

  // Dynamic fire spread radius per zone (GameState.firePositions stays const).
  final Map<int, double> _zoneRadius = {};
  double _cfgSpreadRate = 0.5;

  double wyvernDirectDmg  = 15.0;
  double wyvernEdgeDmg    = 6.0;
  double directConeRadius = 5.0;
  double edgeConeRadius   = 15.0;
  double breathRange      = 45.0;
  double breathHalfAngle  = 0.49;

  // ── Smoke density config ──────────────────────────────────────────────────

  double smokeRadiusMult = 3.5;   // horizontal smoke influence = zoneRadius × this
  double smokePeakAlt    = 35.0;  // altitude (world units) of peak smoke density
  double smokeTopAlt     = 70.0;  // altitude above which smoke fully clears
  double smokeRiseRate   = 0.8;   // lerp rate toward higher smoke density
  double smokeClearRate  = 1.5;   // lerp rate toward lower smoke density
  double treeContrib     = 0.05;  // density added per burning tree
  double imcThreshold    = 0.85;  // smokeOpacity above which IMC is declared

  bool _configLoaded = false;

  FireEmitterSystem({required this.particles});

  bool get configLoaded => _configLoaded;

  /// Current emitter radius for zone [i] (grows with wind-driven spread).
  double zoneRadius(int i) => _zoneRadius[i] ?? GameState.fireRadius * 0.7;

  Future<void> loadConfig() async {
    try {
      final raw  = await rootBundle.loadString('assets/data/fire_config.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final f    = data['fire'] as Map<String, dynamic>;

      particles.buoyancy        = (f['buoyancy']          as num).toDouble();
      particles.turbulenceStr   = (f['turbulenceStrength'] as num).toDouble();
      particles.windInfluence   = (f['windInfluence']      as num).toDouble();
      particles.windRadius      = (f['windRadius']         as num).toDouble();
      particles.smokeTransition = (f['smokeTransitionAge']  as num).toDouble();
      particles.smokeFadeAlt    = (f['smokeFadeAltitude']   as num).toDouble();
      particles.updraftStrength = (f['updraftStrength']     as num).toDouble();
      particles.updraftSigma    = (f['updraftSigma']        as num).toDouble();
      double? nf(String k) => (f[k] as num?)?.toDouble();
      particles.smokeBuoyancy   = nf('smokeBuoyancy')   ?? particles.smokeBuoyancy;
      particles.smokeLifeMin    = nf('smokeLifetimeMin') ?? particles.smokeLifeMin;
      particles.smokeLifeMax    = nf('smokeLifetimeMax') ?? particles.smokeLifeMax;
      particles.smokeSizeGrowth = nf('smokeSizeGrowth')  ?? particles.smokeSizeGrowth;

      _cfgSpreadRate = (f['spreadRate'] as num).toDouble();

      final emitRate    = (f['emitRatePerSecond'] as num).toDouble();
      final fireLifeMin = (f['fireLifetimeMin']   as num).toDouble();
      final fireLifeMax = (f['fireLifetimeMax']   as num).toDouble();
      final fireSzMin   = (f['fireSizeMin']        as num).toDouble();
      final fireSzMax   = (f['fireSizeMax']        as num).toDouble();
      final smokeSzMin  = (f['smokeSizeMin']       as num).toDouble();
      final smokeSzMax  = (f['smokeSizeMax']       as num).toDouble();
      final leanFactor  = (f['leanFactor']         as num).toDouble();

      for (final e in [..._zoneEmitters, ..._dynamicEmitters]) {
        e.emitRate     = emitRate;
        e.fireLifeMin  = fireLifeMin;  e.fireLifeMax  = fireLifeMax;
        e.fireSizeMin  = fireSzMin;    e.fireSizeMax  = fireSzMax;
        e.smokeSizeMin = smokeSzMin;   e.smokeSizeMax = smokeSzMax;
        e.leanFactor   = leanFactor;
      }

      final w = data['wyvern'] as Map<String, dynamic>;
      wyvernDirectDmg  = (w['directDamagePerSec'] as num).toDouble();
      wyvernEdgeDmg    = (w['edgeDamagePerSec']   as num).toDouble();
      directConeRadius = (w['directConeRadius']    as num).toDouble();
      edgeConeRadius   = (w['edgeConeRadius']      as num).toDouble();
      breathRange      = (w['breathRange']         as num).toDouble();
      breathHalfAngle  = (w['breathHalfAngle']     as num).toDouble() * math.pi / 180.0;

      final sm = data['smoke'] as Map<String, dynamic>?;
      if (sm != null) {
        double n(String k, double fb) => (sm[k] as num?)?.toDouble() ?? fb;
        smokeRadiusMult = n('radiusMultiplier', smokeRadiusMult);
        smokePeakAlt    = n('peakAltitude',     smokePeakAlt);
        smokeTopAlt     = n('topAltitude',      smokeTopAlt);
        smokeRiseRate   = n('riseRate',          smokeRiseRate);
        smokeClearRate  = n('clearRate',         smokeClearRate);
        treeContrib     = n('treeContribution',  treeContrib);
        imcThreshold    = n('imcThreshold',      imcThreshold);
      }

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
        worldX:    fx,
        worldZ:    fz,
        radius:    GameState.fireRadius * 0.7,
        intensity: state.fireExtinguished[i] ? 0.0 : 1.0,
      ));
    }
  }

  void spawnGroundFire(double wx, double wz, double duration) {
    final e = FireEmitter(worldX: wx, worldZ: wz, radius: 4.0, intensity: 1.0);
    _dynamicEmitters.add(e);
    _groundFireTimers[e] = duration;
  }

  final Map<FireEmitter, double> _groundFireTimers = {};

  void tick(GameState state, double dt,
      double Function(double, double) terrainHeightAt) {
    for (int i = 0; i < _zoneEmitters.length; i++) {
      _zoneEmitters[i].intensity = state.fireExtinguished[i] ? 0.0 : 1.0;
    }

    final wind = state.apparentWind;
    final pp   = state.playerPosition;

    // CA fire spread: grow zone radii with wind influence.
    _updateSpread(state, dt, wind);

    for (final e in _zoneEmitters) {
      final y = terrainHeightAt(e.worldX, e.worldZ);
      e.tick(particles, dt, y, wind);
    }

    final toRemove = <FireEmitter>[];
    for (final e in _dynamicEmitters) {
      final remaining = (_groundFireTimers[e] ?? 0.0) - dt;
      if (remaining <= 0) { toRemove.add(e); continue; }
      _groundFireTimers[e] = remaining;
      e.intensity = (remaining / (_groundFireTimers[e]! + dt)).clamp(0.0, 1.0);
      e.tick(particles, dt, terrainHeightAt(e.worldX, e.worldZ), wind);
    }
    for (final e in toRemove) {
      _dynamicEmitters.remove(e);
      _groundFireTimers.remove(e);
    }

    wyvernBreath?.tick(particles, dt, wind);
    _applyWyvernDamage(state, dt);
    particles.tick(dt, wind, pp);
  }

  void _updateSpread(GameState state, double dt, Vector3 wind) {
    final windStr = math.sqrt(wind.x * wind.x + wind.z * wind.z);
    final spreadRate = _cfgSpreadRate * (1.0 + windStr * 0.5).clamp(0.5, 2.0);
    for (int i = 0; i < _zoneEmitters.length; i++) {
      if (state.fireExtinguished[i]) {
        _zoneRadius[i] = GameState.fireRadius * 0.7;
        _zoneEmitters[i].radius = GameState.fireRadius * 0.7;
        continue;
      }
      final newR = (zoneRadius(i) + dt * spreadRate)
          .clamp(GameState.fireRadius * 0.7, GameState.fireRadius * 2.0);
      _zoneRadius[i] = newR;
      _zoneEmitters[i].radius = newR;
    }
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
        position:    Vector3.copy(effect.position),
        velocity:    vel,
        lifetime:    0.6 + rng.nextDouble() * 0.8,
        size:        0.3 + rng.nextDouble() * 0.5,
        isFire:      isFireAbility,
        sourceX:     effect.position.x,
        sourceZ:     effect.position.z,
        temperature: 0.75,
      ));
    }
  }

  void _applyWyvernDamage(GameState state, double dt) {
    final breath = wyvernBreath;
    if (breath == null || !breath.active) return;

    final toPlayer = state.playerPosition - breath.origin;
    final dist     = toPlayer.length;
    if (dist > breathRange) return;

    final dot      = toPlayer.normalized().dot(breath.direction);
    final angleDiff = math.acos(dot.clamp(-1.0, 1.0));

    if (angleDiff < directConeRadius / dist) {
      state.takeDamage(wyvernDirectDmg * dt);
    } else if (angleDiff < edgeConeRadius / dist) {
      state.takeDamage(wyvernEdgeDmg * dt);
    }
  }

  List<(double, double, double, double)> get fireLightPositions {
    final result = <(double, double, double, double)>[];
    for (int i = 0; i < _zoneEmitters.length; i++) {
      final e = _zoneEmitters[i];
      result.add((e.worldX, 2.0, e.worldZ, e.intensity));
    }
    return result;
  }
}
