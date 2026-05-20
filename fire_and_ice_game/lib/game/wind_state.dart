import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

class _Streak {
  double x, y;
  double age, maxAge;
  _Streak(this.x, this.y, this.maxAge) : age = 0.0;
}

/// Ambient wind simulation for Fire & Ice.
///
/// Drives aircraft position drift, the apparentWind vector used by the fire
/// particle system, and screen-space streak particles on the cockpit windshield.
///
/// Direction and strength drift via layered sine waves — same approach as the
/// Warchief wind system, adapted for 3-D flight (no derecho, XZ plane only).
class WindState {
  // ── Config (overwritten from flight_config.json §wind after load) ─────────
  double cfgBaseStrength    = 0.15;
  double cfgMaxStrength     = 0.60;
  double cfgGustFrequency   = 0.04;
  double cfgGustAmplitude   = 0.30;
  double cfgDirDriftSpeed   = 0.06;
  double cfgCrosswindFactor = 0.04;
  int    cfgParticleCount   = 60;
  double cfgParticleSpeed   = 280.0;   // pixels / sec at full strength
  double cfgParticleLifetime = 0.9;    // seconds
  double cfgParticleLength  = 20.0;    // pixels (streak length)

  // ── Simulation state ──────────────────────────────────────────────────────
  double windAngle    = 0.0;   // radians; 0 = +X world axis
  double windStrength = 0.15;
  double _noiseTime   = 0.0;

  // ── Screen-space particle pool ────────────────────────────────────────────
  final List<_Streak> _streaks = [];
  final math.Random   _rng     = math.Random();
  bool _poolReady = false;
  double _screenW = 1600, _screenH = 900;

  // ── Simulation ────────────────────────────────────────────────────────────

  void update(double dt) {
    _noiseTime += dt;

    // Direction: three sine layers at different frequencies / phases.
    final d = cfgDirDriftSpeed;
    windAngle += (math.sin(_noiseTime * d)              * 0.5
               +  math.sin(_noiseTime * d * 2.3 + 1.7)  * 0.3
               +  math.cos(_noiseTime * d * 0.7 + 3.1)  * 0.2) * dt;
    windAngle = windAngle % (2 * math.pi);
    if (windAngle < 0) windAngle += 2 * math.pi;

    // Strength: base + layered gusts.
    final gf = cfgGustFrequency;
    final ga = cfgGustAmplitude;
    windStrength = (cfgBaseStrength
        + math.sin(_noiseTime * gf)              * ga * 0.6
        + math.sin(_noiseTime * gf * 2.7 + 0.8) * ga * 0.3
        + math.cos(_noiseTime * gf * 0.4 + 2.5) * ga * 0.1)
        .clamp(0.0, cfgMaxStrength);
  }

  // ── Derived properties ────────────────────────────────────────────────────

  /// Wind as a world-space XZ vector (Y always 0 — no updraft model yet).
  Vector3 get windVector3 => Vector3(
    math.cos(windAngle) * windStrength,
    0.0,
    math.sin(windAngle) * windStrength,
  );

  double get windAngleDegrees => windAngle * (180.0 / math.pi);

  /// Wind strength as 0–100 integer for HUD display.
  int get windStrengthPct =>
      (windStrength / cfgMaxStrength * 100).round().clamp(0, 100);

  /// Compass heading the wind is blowing FROM (0–360, North = 0).
  int get windFromDeg => ((windAngleDegrees + 180) % 360).round();

  // ── Physics integration ───────────────────────────────────────────────────

  /// Push the aircraft slowly in the wind direction (crosswind drift).
  void applyDrift(Vector3 position, double dt) {
    final v = windVector3;
    position.x += v.x * cfgCrosswindFactor * dt;
    position.z += v.z * cfgCrosswindFactor * dt;
  }

  // ── Screen-space streaks (cockpit windshield effect) ──────────────────────

  /// Update streak positions.
  /// [yawDeg]: aircraft heading (degrees); used to project wind onto screen.
  void updateStreaks(double dt, double screenW, double screenH, double yawDeg) {
    _screenW = screenW;
    _screenH = screenH;

    if (!_poolReady) {
      for (int i = 0; i < cfgParticleCount; i++) {
        final s = _Streak(_rng.nextDouble() * screenW,
                          _rng.nextDouble() * screenH,
                          cfgParticleLifetime * (0.5 + _rng.nextDouble() * 0.5));
        // Stagger initial ages so they don't all spawn at the same moment.
        s.age = _rng.nextDouble() * s.maxAge;
        _streaks.add(s);
      }
      _poolReady = true;
    }

    // How many streaks are active scales with strength.
    final active = (cfgParticleCount * (windStrength / cfgMaxStrength))
        .round().clamp(4, cfgParticleCount);

    // Screen direction: project wind angle relative to aircraft heading.
    final relAngle = windAngle - yawDeg * (math.pi / 180.0);
    final sdx = math.sin(relAngle);
    final sdy = -math.cos(relAngle);  // +y = downward on screen
    final speed = cfgParticleSpeed * (windStrength / cfgMaxStrength);

    for (int i = 0; i < _streaks.length; i++) {
      final s = _streaks[i];
      if (i >= active) { s.age = s.maxAge; continue; }

      s.x += sdx * speed * dt;
      s.y += sdy * speed * dt;
      s.age += dt;

      final offScreen = s.x < -40 || s.x > screenW + 40 ||
                        s.y < -40 || s.y > screenH + 40;
      if (s.age >= s.maxAge || offScreen) _respawnStreak(s, sdx, sdy);
    }
  }

  void _respawnStreak(_Streak s, double sdx, double sdy) {
    // Spawn at the upwind edge (opposite travel direction).
    if (sdx.abs() >= sdy.abs()) {
      s.x = sdx > 0 ? -10 : _screenW + 10;
      s.y = _rng.nextDouble() * _screenH;
    } else {
      s.x = _rng.nextDouble() * _screenW;
      s.y = sdy > 0 ? -10 : _screenH + 10;
    }
    s.age = 0;
    s.maxAge = cfgParticleLifetime * (0.5 + _rng.nextDouble() * 0.5);
  }

  List<_Streak> get streaks => _streaks;
}
