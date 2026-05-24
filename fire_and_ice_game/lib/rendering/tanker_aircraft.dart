import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'mesh.dart';
import 'transform3d.dart';

enum _Phase { approach, northLeg, turnSouth, southLeg, turnNorth }

/// Leviathan ART-9 — aerial firefighting tanker flying a north-south racetrack.
///
/// Flies to waypoint YANKEE (0, 0), then alternates: north 2 min / south 2 min.
/// [crossedWaypoint] is true for one tick each time the tanker arrives at YANKEE.
/// [crossNorthbound] indicates the direction of that crossing.
class TankerAircraft {
  // ── YANKEE waypoint ───────────────────────────────────────────────────────────
  static const double yankeeX  =   0.0;
  static const double yankeeZ  =   0.0;
  static const double orbitY   = 100.0;

  static const double _legTime  = 120.0; // seconds per north leg (timer-based)
  static const double _speed    =   2.8; // world units/sec
  static const double _turnRate =  15.0; // deg/s
  static const double _maxBank  =  28.0;
  static const double _captureR =  15.0; // arrival capture radius

  // Heading 180° = north (+Z), heading 0° = south (-Z) in this coordinate system
  static const double _hdgNorth = 180.0;
  static const double _hdgSouth =   0.0;

  _Phase _phase    = _Phase.approach;
  double _legTimer = 0.0;
  double _headingDeg = 270.0; // start heading east-ish, approaching from X=80
  double _bankDeg    = 0.0;

  bool _crossedWaypoint = false;
  bool _crossNorthbound = true;

  final Vector3 position = Vector3(80.0, orbitY, 0.0);

  // ── Public state ──────────────────────────────────────────────────────────────
  bool get crossedWaypoint  => _crossedWaypoint;
  bool get crossNorthbound  => _crossNorthbound;

  // ── Meshes / transforms ───────────────────────────────────────────────────────
  late final Mesh bodyMesh;
  late final Mesh basketMesh;
  final Transform3d transform       = Transform3d();
  final Transform3d basketTransform = Transform3d();

  TankerAircraft() {
    bodyMesh   = _buildBody();
    basketMesh = Mesh.cube(size: 0.55, color: Vector3(0.95, 0.50, 0.08));
    transform.position.setFrom(position);
  }

  // ── Per-frame update ──────────────────────────────────────────────────────────

  void tick(double dt) {
    _crossedWaypoint = false;

    switch (_phase) {
      case _Phase.approach:
        _steerToward(yankeeX, yankeeZ, dt);
        if (_dist2D(position.x, position.z, yankeeX, yankeeZ) < _captureR) {
          _phase = _Phase.northLeg;
          _legTimer = 0.0;
          _crossedWaypoint = true;
          _crossNorthbound = true;
        }

      case _Phase.northLeg:
        _steerToHeading(_hdgNorth, dt);
        _legTimer += dt;
        if (_legTimer >= _legTime) _phase = _Phase.turnSouth;

      case _Phase.turnSouth:
        _turnLeft(dt);
        if (_headingNear(_hdgSouth)) {
          _phase = _Phase.southLeg;
        }

      case _Phase.southLeg:
        // Steer back to YANKEE — fires crossing when it arrives
        _steerToward(yankeeX, yankeeZ, dt);
        if (_dist2D(position.x, position.z, yankeeX, yankeeZ) < _captureR) {
          _phase = _Phase.turnNorth;
          _crossedWaypoint = true;
          _crossNorthbound = false;
        }

      case _Phase.turnNorth:
        _turnLeft(dt);
        if (_headingNear(_hdgNorth)) {
          _phase = _Phase.northLeg;
          _legTimer = 0.0;
          _crossedWaypoint = true;
          _crossNorthbound = true;
        }
    }

    final yawR = _headingDeg * math.pi / 180.0;
    position.x -= math.sin(yawR) * _speed * dt;
    position.z -= math.cos(yawR) * _speed * dt;

    transform.position.setFrom(position);
    transform.rotation.setValues(0.0, _headingDeg, _bankDeg);

    basketTransform.position.setValues(
      position.x + math.sin(yawR) * 15.5,
      position.y - 1.2,
      position.z + math.cos(yawR) * 15.5,
    );
    basketTransform.rotation.setValues(0.0, _headingDeg, 0.0);
  }

  // ── Heading helpers ───────────────────────────────────────────────────────────

  void _steerToward(double tx, double tz, double dt) {
    final dx = tx - position.x, dz = tz - position.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist < 0.5) return;
    final targetH = math.atan2(-dx / dist, -dz / dist) * 180.0 / math.pi;
    final diff    = _normAngle(targetH - _headingDeg);
    final delta   = diff.clamp(-_turnRate * dt, _turnRate * dt);
    _headingDeg   = _normAngle(_headingDeg + delta);
    _updateBank(delta, dt);
  }

  void _steerToHeading(double target, double dt) {
    final diff  = _normAngle(target - _headingDeg);
    final delta = diff.clamp(-_turnRate * dt, _turnRate * dt);
    _headingDeg = _normAngle(_headingDeg + delta);
    _updateBank(delta, dt);
  }

  void _turnLeft(double dt) {
    // Left turn = increasing heading in this coordinate system
    final delta = _turnRate * dt;
    _headingDeg = _normAngle(_headingDeg + delta);
    _updateBank(delta, dt);
  }

  void _updateBank(double delta, double dt) {
    final target = dt > 0 ? (delta / dt * 1.8).clamp(-_maxBank, _maxBank) : 0.0;
    _bankDeg += (target - _bankDeg) * math.min(dt * 2.5, 1.0);
  }

  bool _headingNear(double target) =>
      _normAngle(target - _headingDeg).abs() < 3.0;

  static double _normAngle(double d) {
    while (d >  180) d -= 360;
    while (d < -180) d += 360;
    return d;
  }

  static double _dist2D(double x0, double z0, double x1, double z1) {
    final dx = x1 - x0, dz = z1 - z0;
    return math.sqrt(dx * dx + dz * dz);
  }

  Vector3 get drogueWorldPos => basketTransform.position.clone();

  // ── Mesh construction ─────────────────────────────────────────────────────────

  static Mesh _buildBody() {
    final v  = <double>[];
    final n  = <double>[];
    final c  = <double>[];
    final ix = <int>[];

    const fuse    = [0.08, 0.14, 0.28, 1.0];
    const wing    = [0.12, 0.22, 0.38, 1.0];
    const eng     = [0.20, 0.22, 0.30, 1.0];
    const belly   = [0.00, 0.55, 0.85, 1.0];
    const fin     = [0.10, 0.18, 0.32, 1.0];
    const glass   = [0.30, 0.65, 1.00, 1.0];
    const spine   = [0.10, 0.20, 0.35, 1.0];
    const exhaust = [0.04, 0.06, 0.14, 1.0];
    const hose    = [0.28, 0.20, 0.12, 1.0];

    void box(double cx, double cy, double cz,
             double sx, double sy, double sz, List<double> col) {
      final hx = sx / 2, hy = sy / 2, hz = sz / 2;
      void face(List<List<double>> pts, List<double> nm) {
        final b = v.length ~/ 3;
        for (final p in pts) { v.addAll(p); n.addAll(nm); c.addAll(col); }
        ix.addAll([b, b + 1, b + 2, b, b + 2, b + 3]);
      }
      final x0 = cx-hx, x1 = cx+hx, y0 = cy-hy, y1 = cy+hy, z0 = cz-hz, z1 = cz+hz;
      face([[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]], [ 0, 1, 0]);
      face([[x0,y0,z1],[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]], [ 0,-1, 0]);
      face([[x1,y0,z0],[x1,y0,z1],[x1,y1,z1],[x1,y1,z0]], [ 1, 0, 0]);
      face([[x0,y0,z1],[x0,y0,z0],[x0,y1,z0],[x0,y1,z1]], [-1, 0, 0]);
      face([[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0]], [ 0, 0,-1]);
      face([[x1,y0,z1],[x0,y0,z1],[x0,y1,z1],[x1,y1,z1]], [ 0, 0, 1]);
    }

    box( 0,     0,     0,    1.8, 1.4, 14.0, fuse);
    box( 0,     0.15, -7.5,  1.2, 1.1,  1.0, fuse);
    box( 0,     0.85, -6.0,  1.4, 0.55, 2.0, glass);
    box( 0,     0.88,  0,    0.38,0.28, 8.0, spine);
    box(-5.8,   0.7,   0,    9.4, 0.22, 4.0, wing);
    box( 5.8,   0.7,   0,    9.4, 0.22, 4.0, wing);
    box(-2.5,   0.36, -2.0,  0.65,0.60, 3.0, eng);
    box(-6.2,   0.28, -2.0,  0.65,0.55, 3.0, eng);
    box( 2.5,   0.36, -2.0,  0.65,0.60, 3.0, eng);
    box( 6.2,   0.28, -2.0,  0.65,0.55, 3.0, eng);
    box(-2.5,   0.36,  1.6,  0.42,0.42, 0.30, exhaust);
    box(-6.2,   0.28,  1.6,  0.40,0.38, 0.30, exhaust);
    box( 2.5,   0.36,  1.6,  0.42,0.42, 0.30, exhaust);
    box( 6.2,   0.28,  1.6,  0.40,0.38, 0.30, exhaust);
    box( 0,    -0.92,  0,    0.92,0.65, 7.2, belly);
    box( 0,     0.0,   6.5,  5.5, 0.18, 2.0, wing);
    box(-2.2,   0.92,  6.4,  0.18,2.0,  1.8, fin);
    box( 2.2,   0.92,  6.4,  0.18,2.0,  1.8, fin);
    box( 0,    -0.50,  11.0, 0.12,0.12, 8.0, hose);

    return Mesh(
      vertices: Float32List.fromList(v),
      indices:  Uint16List.fromList(ix),
      normals:  Float32List.fromList(n),
      colors:   Float32List.fromList(c),
    );
  }
}
