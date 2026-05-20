import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import '../rendering/mesh.dart';
import '../rendering/transform3d.dart';

/// AirbaseGenerator — procedural 3D buildings for the home airbase complex.
///
/// World layout (all Y=ground):
///   Apron            : covers X∈[-76,65], Z∈[-10,-92] flanking the runway
///   Main Hangar      : center X=-55, Z=-65  SW apron  (40×22×12)
///   Secondary Hangar : center X=-48, Z=-35  W apron   (28×16×10)
///   TOC              : center X=40,  Z=-55  E apron   (18×12×7 + mast + dish)
///   Control Tower    : center X=-18, Z=-20  W-midfield (5×5 shaft h=20, 8.5×8.5 cab h=5.5)
class AirbaseGenerator {
  AirbaseGenerator._();

  static const double _g = 0.5; // ground / floor level

  // ── Color palette ─────────────────────────────────────────────────────────
  static const List<double> _steel  = [0.32, 0.33, 0.38, 1.0];
  static const List<double> _roofDk = [0.20, 0.21, 0.24, 1.0];
  static const List<double> _green  = [0.22, 0.28, 0.20, 1.0];
  static const List<double> _greenD = [0.14, 0.20, 0.14, 1.0];
  static const List<double> _tower  = [0.38, 0.40, 0.42, 1.0];
  static const List<double> _glass  = [0.30, 0.55, 0.60, 1.0];
  static const List<double> _apron  = [0.28, 0.28, 0.30, 1.0];
  static const List<double> _stripe = [0.70, 0.65, 0.20, 1.0];

  // ── Geometry helpers ──────────────────────────────────────────────────────

  static (List<double>, List<double>, List<double>, List<int>) _bufs() =>
      (<double>[], <double>[], <double>[], <int>[]);

  static void _quad(
    List<double> v, List<double> n, List<double> c, List<int> ix,
    List<double> p0, List<double> p1, List<double> p2, List<double> p3,
    List<double> norm, List<double> col,
  ) {
    final b = v.length ~/ 3;
    for (final p in [p0, p1, p2, p3]) {
      v.addAll(p); n.addAll(norm); c.addAll(col);
    }
    ix.addAll([b, b+1, b+2, b, b+2, b+3]);
  }

  // Flat horizontal quad at height [y].
  static void _hq(
    List<double> v, List<double> n, List<double> c, List<int> ix,
    double x0, double z0, double x1, double z1,
    double x2, double z2, double x3, double z3,
    double y, List<double> col,
  ) => _quad(v, n, c, ix,
        [x0,y,z0], [x1,y,z1], [x2,y,z2], [x3,y,z3], [0,1,0], col);

  // Box (walls + roof only). [yb]=bottom Y, [h]=height.
  static void _box(
    List<double> v, List<double> n, List<double> c, List<int> ix,
    double cx, double cz, double w, double d, double yb, double h,
    List<double> wc, List<double> rc,
  ) {
    final x0 = cx-w/2, x1 = cx+w/2;
    final z0 = cz-d/2, z1 = cz+d/2;
    final yt = yb + h;
    _hq(v,n,c,ix, x0,z0, x1,z0, x1,z1, x0,z1, yt, rc);                          // roof
    _quad(v,n,c,ix, [x0,yb,z1],[x1,yb,z1],[x1,yt,z1],[x0,yt,z1], [0,0,1],  wc); // N
    _quad(v,n,c,ix, [x1,yb,z0],[x0,yb,z0],[x0,yt,z0],[x1,yt,z0], [0,0,-1], wc); // S
    _quad(v,n,c,ix, [x1,yb,z1],[x1,yb,z0],[x1,yt,z0],[x1,yt,z1], [1,0,0],  wc); // E
    _quad(v,n,c,ix, [x0,yb,z0],[x0,yb,z1],[x0,yt,z1],[x0,yt,z0], [-1,0,0], wc); // W
  }

  static Mesh _mesh(List<double> v, List<double> n, List<double> c, List<int> ix) =>
      Mesh(
        vertices: Float32List.fromList(v),
        indices:  Uint16List.fromList(ix),
        normals:  Float32List.fromList(n),
        colors:   Float32List.fromList(c),
      );

  // ── Public generators ─────────────────────────────────────────────────────

  /// Concrete apron flanking the runway (west + east slabs with hazard stripes).
  static ({Mesh mesh, Transform3d transform}) generateApron() {
    final (v, n, c, ix) = _bufs();
    _hq(v,n,c,ix, -76.0,-10.0, -8.0,-10.0,  -8.0,-92.0, -76.0,-92.0, _g,      _apron);
    _hq(v,n,c,ix,   8.0,-10.0, 65.0,-10.0,  65.0,-80.0,   8.0,-80.0, _g,      _apron);
    _hq(v,n,c,ix, -76.0,-10.0,-74.0,-10.0, -74.0,-92.0, -76.0,-92.0, _g+0.02, _stripe);
    _hq(v,n,c,ix, -76.0,-90.0, -8.0,-90.0,  -8.0,-92.0, -76.0,-92.0, _g+0.02, _stripe);
    return (mesh: _mesh(v, n, c, ix), transform: Transform3d());
  }

  /// Main aircraft hangar — large steel structure, SW apron.
  static ({Mesh mesh, Transform3d transform}) generateMainHangar() {
    final (v, n, c, ix) = _bufs();
    _box(v,n,c,ix, -55.0,-65.0, 40.0,22.0, _g, 12.0, _steel, _roofDk);
    // Hazard stripe at the door threshold (north face).
    _hq(v,n,c,ix, -64.0,-54.0,-46.0,-54.0,-46.0,-53.8,-64.0,-53.8, _g+0.3, _stripe);
    return (mesh: _mesh(v, n, c, ix), transform: Transform3d());
  }

  /// Secondary hangar — medium steel structure, W apron.
  static ({Mesh mesh, Transform3d transform}) generateSecondaryHangar() {
    final (v, n, c, ix) = _bufs();
    _box(v,n,c,ix, -48.0,-35.0, 28.0,16.0, _g, 10.0, _steel, _roofDk);
    return (mesh: _mesh(v, n, c, ix), transform: Transform3d());
  }

  /// Tactical Operations Center — mil-green building with comms mast + radar dish.
  static ({Mesh mesh, Transform3d transform}) generateTOC() {
    final (v, n, c, ix) = _bufs();
    _box(v,n,c,ix,  40.0,-55.0, 18.0,12.0, _g,      7.0, _green,  _greenD); // main structure
    _box(v,n,c,ix,  41.5,-52.0,  1.2, 1.2, _g+7.0, 14.0, _tower,  _tower);  // comms mast
    _hq(v,n,c,ix, 36.0,-59.0, 44.0,-59.0, 44.0,-52.0, 36.0,-52.0, _g+7.3, _glass); // radar dish
    return (mesh: _mesh(v, n, c, ix), transform: Transform3d());
  }

  /// Control tower — concrete shaft with glass observation cab on top.
  static ({Mesh mesh, Transform3d transform}) generateControlTower() {
    final (v, n, c, ix) = _bufs();
    _box(v,n,c,ix, -18.0,-20.0, 5.0, 5.0, _g,       20.0, _tower, _roofDk); // shaft
    _box(v,n,c,ix, -18.0,-20.0, 8.5, 8.5, _g+20.0,   5.5, _glass, _roofDk); // cab
    return (mesh: _mesh(v, n, c, ix), transform: Transform3d());
  }
}
