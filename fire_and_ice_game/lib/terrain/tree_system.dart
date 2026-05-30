import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'terrain_generator.dart';

enum TreeState { alive, burning, charred }

class TreeInstance {
  final int    id;
  final double wx, wy, wz;
  final double height;
  final double canopyRadius;
  final double trunkRadius;
  final int    type; // 0=pine, 1=deciduous, 2=snag
  TreeState state      = TreeState.alive;
  double    stateTimer = 0.0;

  TreeInstance({
    required this.id,
    required this.wx, required this.wy, required this.wz,
    required this.height, required this.canopyRadius,
    required this.trunkRadius, required this.type,
  });
}

/// Manages all tree instances: placement, fire spread, aircraft collision.
class TreeSystem {
  final List<TreeInstance> trees = [];

  // Spatial grid: gridKey → list of tree indices (for fast neighbor queries).
  final Map<String, List<int>> _grid = {};

  // Set whenever any tree changes state; TreeRenderer rebuilds meshes when true.
  bool dirty = true;

  // Drained by game_widget each frame to spawn/remove fire emitters.
  final List<int> newlyBurningIds = [];
  final List<int> newlyCharredIds = [];

  final math.Random _rng;

  static const double _kGridCell   = 16.0; // world units per spatial grid cell
  static const double _kSpreadR    = 14.0; // fire spread radius (world units)
  static const double _kSpreadRate = 0.10; // base spread probability per second
  static const double _kBurnTime   = 8.0;  // seconds burning→charred (height-scaled)
  static const double _kAircraftR  = 1.5;  // aircraft bounding sphere radius

  TreeSystem({int rngSeed = 777}) : _rng = math.Random(rngSeed);

  // ── Generation ─────────────────────────────────────────────────────────────

  /// Deterministically place trees across the initial 240×240 playable area.
  void generate({int seed = 42}) {
    trees.clear();
    _grid.clear();
    newlyBurningIds.clear();
    newlyCharredIds.clear();
    dirty = true;

    const double worldMin = -120.0, worldMax = 120.0, spacing = 7.0;
    int id = 0;

    for (double gx = worldMin; gx <= worldMax; gx += spacing) {
      for (double gz = worldMin; gz <= worldMax; gz += spacing) {
        // Deterministic jitter so the grid doesn't look artificial.
        final jx = math.sin(gx * 0.37 + gz * 0.71 + seed) * 2.8;
        final jz = math.cos(gx * 0.59 + gz * 0.43 + seed) * 2.8;
        final wx = gx + jx;
        final wz = gz + jz;

        final wy = TerrainGenerator.heightAt(wx, wz);
        if (wy < 0.8 || wy > 10.0) continue;

        // Density varies by elevation: densest on mid-slopes.
        final targetDensity = wy < 2.0 ? 0.12 : (wy < 6.0 ? 0.35 : 0.18);
        final densityNoise  = (math.sin(wx * 0.23 + wz * 0.47 + seed * 0.01) + 1.0) * 0.5;
        if (densityNoise > targetDensity) continue;

        // Type: 70% pine, 20% deciduous, 10% dead snag.
        final typeNoise = (math.sin(wx * 0.99 + wz * 1.31) + 1.0) * 0.5;
        final type = typeNoise < 0.70 ? 0 : (typeNoise < 0.90 ? 1 : 2);

        final sizeNoise  = (math.sin(wx * 2.1 + wz * 1.7) + 1.0) * 0.5;
        final height     = type == 2 ? 4.0 + sizeNoise * 3.0 : 6.0 + sizeNoise * 6.0;
        final canopyR    = height * (type == 0 ? 0.22 : 0.28);
        final trunkR     = 0.22 + sizeNoise * 0.14;

        trees.add(TreeInstance(
          id: id++, wx: wx, wy: wy, wz: wz,
          height: height, canopyRadius: canopyR, trunkRadius: trunkR, type: type,
        ));
      }
    }

    _rebuildGrid();
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Advance fire spread and burnout. [windVec] is the XZ wind vector (Y=0).
  void update(double dt, Vector3 windVec) {
    for (final t in trees) {
      if (t.state == TreeState.alive) continue;
      t.stateTimer += dt;

      if (t.state == TreeState.burning) {
        final burnDuration = _kBurnTime * (0.7 + t.height / 18.0);
        if (t.stateTimer >= burnDuration) {
          t.state = TreeState.charred;
          t.stateTimer = 0.0;
          dirty = true;
          newlyCharredIds.add(t.id);
        } else if (t.stateTimer > 1.0) {
          _trySpread(t, dt, windVec);
        }
      }
    }
  }

  // ── Ignition ───────────────────────────────────────────────────────────────

  void igniteInRadius(Vector3 origin, double radius) {
    final r2 = radius * radius;
    for (final t in trees) {
      if (t.state != TreeState.alive) continue;
      final dx = t.wx - origin.x;
      final dz = t.wz - origin.z;
      if (dx * dx + dz * dz <= r2) _ignite(t);
    }
  }

  /// Ice/cryo suppression: burning trees within radius become charred instantly.
  void suppressInRadius(Vector3 origin, double radius) {
    final r2 = radius * radius;
    for (final t in trees) {
      if (t.state != TreeState.burning) continue;
      final dx = t.wx - origin.x;
      final dz = t.wz - origin.z;
      if (dx * dx + dz * dz <= r2) {
        t.state = TreeState.charred;
        t.stateTimer = 0.0;
        dirty = true;
        newlyCharredIds.add(t.id);
      }
    }
  }

  /// Check aircraft against alive/burning trees. Returns hit tree, or null.
  /// Does NOT mutate state — caller is responsible for igniting the hit tree.
  TreeInstance? checkAircraftCollision(double px, double py, double pz) {
    final cx = (px / _kGridCell).floor();
    final cz = (pz / _kGridCell).floor();
    final r2 = (_kAircraftR + 0.8) * (_kAircraftR + 0.8);

    for (int gx = cx - 1; gx <= cx + 1; gx++) {
      for (int gz = cz - 1; gz <= cz + 1; gz++) {
        final list = _grid['${gx}_${gz}'];
        if (list == null) continue;
        for (final i in list) {
          final t = trees[i];
          if (t.state == TreeState.charred) continue;
          final dx = t.wx - px;
          final dz = t.wz - pz;
          if (dx * dx + dz * dz > r2) continue;
          if (py < t.wy || py > t.wy + t.height) continue;
          return t;
        }
      }
    }
    return null;
  }

  /// Ignite a specific tree (called by aircraft collision or from igniteInRadius).
  void igniteTree(TreeInstance t) {
    if (t.state != TreeState.alive) return;
    t.state = TreeState.burning;
    t.stateTimer = 0.0;
    dirty = true;
    newlyBurningIds.add(t.id);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _ignite(TreeInstance t) {
    t.state = TreeState.burning;
    t.stateTimer = 0.0;
    dirty = true;
    newlyBurningIds.add(t.id);
  }

  void _trySpread(TreeInstance src, double dt, Vector3 windVec) {
    final windLen = windVec.length;
    final cx = (src.wx / _kGridCell).floor();
    final cz = (src.wz / _kGridCell).floor();

    for (int gx = cx - 1; gx <= cx + 1; gx++) {
      for (int gz = cz - 1; gz <= cz + 1; gz++) {
        final list = _grid['${gx}_${gz}'];
        if (list == null) continue;
        for (final idx in list) {
          final n = trees[idx];
          if (n.state != TreeState.alive) continue;
          final dx = n.wx - src.wx;
          final dz = n.wz - src.wz;
          final dist2 = dx * dx + dz * dz;
          if (dist2 > _kSpreadR * _kSpreadR || dist2 < 0.5) continue;

          // Wind alignment: spread faster downwind, barely upwind.
          double windAlign = 0.3;
          if (windLen > 0.01) {
            final dist = math.sqrt(dist2);
            final dot = (dx / dist) * windVec.x / windLen +
                        (dz / dist) * windVec.z / windLen;
            windAlign = 0.1 + 0.9 * ((dot + 1.0) * 0.5);
          }
          final windMult = 1.0 + windLen * 2.5;
          if (_rng.nextDouble() < _kSpreadRate * dt * windAlign * windMult) {
            _ignite(n);
          }
        }
      }
    }
  }

  void _rebuildGrid() {
    _grid.clear();
    for (int i = 0; i < trees.length; i++) {
      _grid
          .putIfAbsent(_gridKey(trees[i].wx, trees[i].wz), () => [])
          .add(i);
    }
  }

  /// Lightweight snapshot of all trees for NAV map rendering.
  /// Returns list of (worldX, worldZ, stateIndex) — stateIndex: 0=alive, 1=burning, 2=charred.
  List<(double, double, int)> treeSnapshot() =>
      trees.map((t) => (t.wx, t.wz, t.state.index)).toList();

  static String _gridKey(double x, double z) =>
      '${(x / _kGridCell).floor()}_${(z / _kGridCell).floor()}';
}
