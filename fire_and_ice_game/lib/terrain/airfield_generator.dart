import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import '../rendering/mesh.dart';
import '../rendering/transform3d.dart';

/// AirfieldGenerator - Generates the runway and starter position.
///
/// Runway runs along the Z-axis: aircraft starts near the +Z threshold,
/// facing −Z (heading 0° = forward in physics convention).
class AirfieldGenerator {
  AirfieldGenerator._();

  // Runway dimensions (world units)
  static const double _length = 180.0;
  static const double _width  = 16.0;
  static const double _y      = 0.5; // surface height

  // Derived extents
  static const double _zMin = -_length / 2;
  static const double _zMax =  _length / 2;
  static const double _xMin = -_width  / 2;
  static const double _xMax =  _width  / 2;

  // ── Colors ────────────────────────────────────────────────────────────────

  // Asphalt
  static const _kAsphalt = [0.18, 0.18, 0.20, 1.0];
  // Centerline dash
  static const _kCenter  = [0.82, 0.82, 0.82, 1.0];
  // Threshold bar
  static const _kThresh  = [0.90, 0.90, 0.90, 1.0];
  // Runway edge
  static const _kEdge    = [0.50, 0.50, 0.50, 1.0];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the runway mesh + an identity transform.
  static ({Mesh mesh, Transform3d transform}) generate() {
    final verts = <double>[];
    final norms = <double>[];
    final cols  = <double>[];
    final idxs  = <int>[];

    void quad(
      double x0, double z0, double x1, double z1,
      double x2, double z2, double x3, double z3,
      List<double> color,
    ) {
      final base = verts.length ~/ 3;
      for (final v in [
        [x0, _y, z0], [x1, _y, z1], [x2, _y, z2], [x3, _y, z3],
      ]) {
        verts.addAll(v);
        norms.addAll([0.0, 1.0, 0.0]);
        cols.addAll(color);
      }
      idxs.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    // Main asphalt surface
    quad(_xMin, _zMin, _xMax, _zMin, _xMax, _zMax, _xMin, _zMax, _kAsphalt);

    // Edge stripes (white, 1-unit wide each side)
    quad(_xMin,      _zMin, _xMin + 1, _zMin, _xMin + 1, _zMax, _xMin,      _zMax, _kEdge);
    quad(_xMax - 1,  _zMin, _xMax,     _zMin, _xMax,     _zMax, _xMax - 1,  _zMax, _kEdge);

    // Centerline dashes (every 18 units, 8 long, 1 wide)
    for (int i = 0; i < 9; i++) {
      final zc = _zMin + 18 + i * 18.0;
      quad(-0.5, zc - 4, 0.5, zc - 4, 0.5, zc + 4, -0.5, zc + 4, _kCenter);
    }

    // Threshold markings — 6 bars, 2.0 wide, 3.0 long, at each end
    for (final zBase in [_zMin + 2.0, _zMax - 5.0]) {
      for (int j = -3; j <= 2; j++) {
        final xc = (j + 0.5) * 2.4;
        quad(xc - 0.9, zBase, xc + 0.9, zBase,
             xc + 0.9, zBase + 3, xc - 0.9, zBase + 3, _kThresh);
      }
    }

    final mesh = Mesh(
      vertices: Float32List.fromList(verts),
      indices:  Uint16List.fromList(idxs),
      normals:  Float32List.fromList(norms),
      colors:   Float32List.fromList(cols),
    );

    return (mesh: mesh, transform: Transform3d());
  }

  /// World position of the start of the runway (+Z threshold, facing −Z).
  static Vector3 get startPosition => Vector3(0.0, _y, _zMax - 5.0);
}
