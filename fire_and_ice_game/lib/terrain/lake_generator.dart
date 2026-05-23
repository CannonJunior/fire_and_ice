import 'dart:math' as math;
import 'dart:typed_data';
import '../rendering/mesh.dart';
import '../rendering/transform3d.dart';

/// LakeGenerator — flat elliptical lake mesh east of the airfield runway.
///
/// World position: center (50, 0.25, −10) — alongside the east runway edge,
/// clear of all fire zones and airbase buildings. Semi-axes: 28 (X) × 20 (Z).
/// Rendered as a triangle fan so the vertex count stays small.
class LakeGenerator {
  LakeGenerator._();

  static const double _cx = 50.0;
  static const double _cz = -10.0;
  static const double _y  = 0.25;  // slightly below runway (0.5) for depth illusion
  static const double _rx = 28.0;  // east-west semi-axis
  static const double _rz = 20.0;  // north-south semi-axis
  static const int    _n  = 32;    // perimeter segments

  // Deep water centre → bright shallow edge
  static const _kDeep = [0.02, 0.16, 0.38, 1.0];
  static const _kEdge = [0.04, 0.30, 0.55, 1.0];

  static ({Mesh mesh, Transform3d transform}) generate() {
    // 1 centre + _n perimeter vertices
    final verts = Float32List((_n + 1) * 3);
    final norms = Float32List((_n + 1) * 3);
    final cols  = Float32List((_n + 1) * 4);
    final idxs  = Uint16List(_n * 3);

    // Centre vertex (index 0)
    verts[0] = _cx; verts[1] = _y; verts[2] = _cz;
    norms[1] = 1.0;
    cols[0] = _kDeep[0]; cols[1] = _kDeep[1]; cols[2] = _kDeep[2]; cols[3] = 1.0;

    // Perimeter vertices with slight radius jitter for a natural shore
    for (int i = 0; i < _n; i++) {
      final a = i * 2 * math.pi / _n;
      final jitter = 1.0 + 0.10 * math.sin(a * 3.1) + 0.07 * math.cos(a * 5.7);
      final px = _cx + _rx * jitter * math.cos(a);
      final pz = _cz + _rz * jitter * math.sin(a);

      final vi = (i + 1) * 3;
      verts[vi + 0] = px; verts[vi + 1] = _y; verts[vi + 2] = pz;
      norms[vi + 1] = 1.0;

      final ci = (i + 1) * 4;
      cols[ci + 0] = _kEdge[0]; cols[ci + 1] = _kEdge[1];
      cols[ci + 2] = _kEdge[2]; cols[ci + 3] = 1.0;
    }

    // Fan indices: centre=0, perimeter i+1 → i+2 (wraps)
    for (int i = 0; i < _n; i++) {
      idxs[i * 3 + 0] = 0;
      idxs[i * 3 + 1] = i + 1;
      idxs[i * 3 + 2] = (i + 1) % _n + 1;
    }

    return (
      mesh: Mesh(vertices: verts, indices: idxs, normals: norms, colors: cols),
      transform: Transform3d(),
    );
  }
}
