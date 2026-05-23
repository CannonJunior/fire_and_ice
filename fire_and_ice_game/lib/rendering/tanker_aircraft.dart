import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'mesh.dart';
import 'transform3d.dart';

/// Leviathan ART-9 — sci-fi endurance tanker orbiting at 100 AGL over the airbase.
///
/// Inspired by the C-130 but redesigned for anime aesthetic: longer slender fuselage,
/// high-mounted straight wings, four engine nacelles in pairs, twin vertical tail fins,
/// a glowing cyan belly retardant pod, and a drogue trailing 8 units aft.
///
/// Flies a left-hand racetrack orbit over the airbase complex (Z ≈ -15 to -95).
/// [drogueWorldPos] gives the basket world position for IceFighter probe connection.
class TankerAircraft {
  // ── Racetrack orbit ──────────────────────────────────────────────────────────

  /// Waypoints (X, Z) traversed counter-clockwise (left-hand turns).
  static const List<(double, double)> _wps = [
    ( 35.0, -15.0),   // NE — start of south leg
    ( 35.0, -95.0),   // SE — left turn to west
    (-45.0, -95.0),   // SW — left turn to north
    (-45.0, -15.0),   // NW — left turn to east
  ];

  static const double _orbitY    = 100.0;  // AGL (terrain ≈ 0)
  static const double _speed     = 2.8;    // world units/sec — slow endurance pace
  static const double _wayptDist = 5.0;    // advance to next wp within this radius

  int    _wpIdx      = 0;
  double _headingDeg = 0.0;   // yaw in degrees, matching Transform3d convention

  /// World-space position of the tanker.
  final Vector3 position = Vector3(35.0, _orbitY, -15.0);

  // ── Meshes ───────────────────────────────────────────────────────────────────

  late final Mesh bodyMesh;
  late final Mesh basketMesh;

  // ── Transforms (updated every tick, reused for rendering) ────────────────────

  final Transform3d transform       = Transform3d();
  final Transform3d basketTransform = Transform3d();

  // ── Constructor ──────────────────────────────────────────────────────────────

  TankerAircraft() {
    bodyMesh   = _buildBody();
    basketMesh = Mesh.cube(size: 0.55, color: Vector3(0.95, 0.50, 0.08));
    transform.position.setFrom(position);
  }

  // ── Orbit tick ───────────────────────────────────────────────────────────────

  void tick(double dt) {
    final (tx, tz) = _wps[_wpIdx];
    final dx   = tx - position.x;
    final dz   = tz - position.z;
    final dist = math.sqrt(dx * dx + dz * dz);

    if (dist < _wayptDist) {
      _wpIdx = (_wpIdx + 1) % _wps.length;
    } else {
      final nx = dx / dist;
      final nz = dz / dist;
      position.x += nx * _speed * dt;
      position.z += nz * _speed * dt;
      // Convert movement direction to Transform3d yaw convention.
      // forward = (-sin(yaw), 0, -cos(yaw)) → yaw = atan2(-nx, -nz)
      _headingDeg = math.atan2(-nx, -nz) * 180.0 / math.pi;
    }

    transform.position.setFrom(position);
    transform.rotation.setValues(0.0, _headingDeg, 0.0);

    // Basket in tanker local space at (0, -1.2, 15.5).
    // World transform for yaw-only rotation: RotY maps local Z to world via sin/cos.
    final yawR = _headingDeg * math.pi / 180.0;
    basketTransform.position.setValues(
      position.x + math.sin(yawR) * 15.5,
      position.y - 1.2,
      position.z + math.cos(yawR) * 15.5,
    );
    basketTransform.rotation.setValues(0.0, _headingDeg, 0.0);
  }

  /// World position of the drogue basket — used for probe connection detection.
  Vector3 get drogueWorldPos => basketTransform.position.clone();

  // ── Mesh construction ─────────────────────────────────────────────────────────

  static Mesh _buildBody() {
    final v  = <double>[];
    final n  = <double>[];
    final c  = <double>[];
    final ix = <int>[];

    // Color palette
    const fuse  = [0.08, 0.14, 0.28, 1.0];  // midnight blue fuselage
    const wing  = [0.12, 0.22, 0.38, 1.0];  // lighter wing panels
    const eng   = [0.20, 0.22, 0.30, 1.0];  // gunmetal engine nacelles
    const belly = [0.00, 0.55, 0.85, 1.0];  // glowing cyan retardant pod
    const fin   = [0.10, 0.18, 0.32, 1.0];  // deep blue tail fins
    const glass = [0.30, 0.65, 1.00, 1.0];  // cockpit glass blue
    const spine = [0.10, 0.20, 0.35, 1.0];  // dorsal spine
    const exhaust = [0.04, 0.06, 0.14, 1.0]; // dark engine nozzles
    const hose  = [0.28, 0.20, 0.12, 1.0];  // drogue hose — dark rust

    void box(double cx, double cy, double cz,
             double sx, double sy, double sz, List<double> col) {
      final hx = sx / 2, hy = sy / 2, hz = sz / 2;
      void face(List<List<double>> pts, List<double> nm) {
        final b = v.length ~/ 3;
        for (final p in pts) { v.addAll(p); n.addAll(nm); c.addAll(col); }
        ix.addAll([b, b + 1, b + 2, b, b + 2, b + 3]);
      }
      final x0 = cx-hx, x1 = cx+hx;
      final y0 = cy-hy, y1 = cy+hy;
      final z0 = cz-hz, z1 = cz+hz;
      face([[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]], [0, 1, 0]);
      face([[x0,y0,z1],[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]], [0,-1, 0]);
      face([[x1,y0,z0],[x1,y0,z1],[x1,y1,z1],[x1,y1,z0]], [1, 0, 0]);
      face([[x0,y0,z1],[x0,y0,z0],[x0,y1,z0],[x0,y1,z1]], [-1, 0, 0]);
      face([[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0]], [0, 0,-1]);
      face([[x1,y0,z1],[x0,y0,z1],[x0,y1,z1],[x1,y1,z1]], [0, 0, 1]);
    }

    // ── 1. Main fuselage — long slender body ─────────────────────────────────
    box(0,    0,    0,    1.8, 1.4, 14.0, fuse);
    // ── 2. Nose fairing — slightly taller for anime character ────────────────
    box(0,    0.15, -7.5, 1.2, 1.1, 1.0,  fuse);
    // ── 3. Flight-deck glazing ───────────────────────────────────────────────
    box(0,    0.85, -6.0, 1.4, 0.55, 2.0, glass);
    // ── 4. Dorsal spine — sci-fi equipment blister ───────────────────────────
    box(0,    0.88,  0,   0.38, 0.28, 8.0, spine);
    // ── 5. High-mounted wings (straight, C-130 style) ────────────────────────
    box(-5.8, 0.7,   0,   9.4, 0.22, 4.0, wing);   // left
    box( 5.8, 0.7,   0,   9.4, 0.22, 4.0, wing);   // right
    // ── 6. Engine nacelles — 2 per wing, forward of leading edge ─────────────
    box(-2.5, 0.36, -2.0, 0.65, 0.60, 3.0, eng);   // left inner
    box(-6.2, 0.28, -2.0, 0.65, 0.55, 3.0, eng);   // left outer
    box( 2.5, 0.36, -2.0, 0.65, 0.60, 3.0, eng);   // right inner
    box( 6.2, 0.28, -2.0, 0.65, 0.55, 3.0, eng);   // right outer
    // ── 7. Engine exhaust nozzles — dark recessed rings at engine rear ────────
    box(-2.5, 0.36,  1.6, 0.42, 0.42, 0.30, exhaust);
    box(-6.2, 0.28,  1.6, 0.40, 0.38, 0.30, exhaust);
    box( 2.5, 0.36,  1.6, 0.42, 0.42, 0.30, exhaust);
    box( 6.2, 0.28,  1.6, 0.40, 0.38, 0.30, exhaust);
    // ── 8. Belly retardant pod — distinctive glowing cyan sci-fi element ──────
    box(0,   -0.92,  0,   0.92, 0.65, 7.2, belly);
    // ── 9. Horizontal stabilizer ─────────────────────────────────────────────
    box(0,    0.0,   6.5, 5.5, 0.18, 2.0,  wing);
    // ── 10. Twin vertical tail fins — anime design element ────────────────────
    box(-2.2, 0.92,  6.4, 0.18, 2.0, 1.8,  fin);
    box( 2.2, 0.92,  6.4, 0.18, 2.0, 1.8,  fin);
    // ── 11. Drogue hose — trailing from tail, angled slightly downward ────────
    //       Local Z=7 is tail; hose centre at Z=11, length 8 → Z=7 to Z=15.
    box(0,   -0.50,  11.0, 0.12, 0.12, 8.0, hose);

    return Mesh(
      vertices: Float32List.fromList(v),
      indices:  Uint16List.fromList(ix),
      normals:  Float32List.fromList(n),
      colors:   Float32List.fromList(c),
    );
  }
}
