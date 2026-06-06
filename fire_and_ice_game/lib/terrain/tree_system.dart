import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  // Subset of trees that are currently burning — avoids iterating all trees
  // every frame. Maintained by _ignite(), igniteTree(), suppressInRadius().
  final List<TreeInstance> _burning = [];

  final math.Random _rng;

  static const double _kGridCell   = 16.0;
  static const double _kSpreadR    = 14.0;
  static const double _kSpreadRate = 0.10;
  static const double _kBurnTime   = 8.0;
  static const double _kAircraftR  = 1.5;

  // ── Generation config (loaded from game_config.json) ──────────────────────
  double _scatterMinGap              = 10.0;
  double _scatterDensityThreshold    = 0.62;
  double _clusterSeedSpacing         = 28.0;
  double _clusterSeedDensityThreshold = 0.45;
  int    _clusterCountMin            = 2;
  int    _clusterCountMax            = 5;

  TreeSystem({int rngSeed = 777}) : _rng = math.Random(rngSeed);

  Future<void> loadConfig() async {
    try {
      final raw = await rootBundle.loadString('config/game_config.json');
      final cfg = (jsonDecode(raw) as Map<String, dynamic>)['trees'] as Map<String, dynamic>?;
      if (cfg == null) return;
      _scatterMinGap               = (cfg['scatterMinGap']               as num?)?.toDouble() ?? _scatterMinGap;
      _scatterDensityThreshold     = (cfg['scatterDensityThreshold']     as num?)?.toDouble() ?? _scatterDensityThreshold;
      _clusterSeedSpacing          = (cfg['clusterSeedSpacing']          as num?)?.toDouble() ?? _clusterSeedSpacing;
      _clusterSeedDensityThreshold = (cfg['clusterSeedDensityThreshold'] as num?)?.toDouble() ?? _clusterSeedDensityThreshold;
      _clusterCountMin             = (cfg['clusterCountMin']             as int?) ?? _clusterCountMin;
      _clusterCountMax             = (cfg['clusterCountMax']             as int?) ?? _clusterCountMax;
      debugPrint('[TreeSystem] config loaded — scatter gap: $_scatterMinGap, cluster max: $_clusterCountMax');
    } catch (e) {
      debugPrint('[TreeSystem] config load failed ($e) — using defaults');
    }
  }

  // ── Generation ─────────────────────────────────────────────────────────────

  /// Deterministically place trees across the 240×240 playable area.
  /// Uses two-layer placement: Poisson-disk scattered background + clustered
  /// groupings, which produces the organic density variation seen in real forests.
  void generate({int seed = 42}) {
    trees.clear();
    _burning.clear();
    _grid.clear();
    newlyBurningIds.clear();
    newlyCharredIds.clear();
    dirty = true;

    const double worldMin = -120.0, worldMax = 120.0;
    final rng = math.Random(seed);
    int id = 0;

    // Multi-octave density field: combines three sine octaves for natural variation.
    double densityAt(double x, double z) =>
        ((math.sin(x * 0.17 + z * 0.29 + seed) * 0.50 +
          math.sin(x * 0.09 - z * 0.11 + seed * 1.7) * 0.35 +
          math.sin(x * 0.31 + z * 0.13 + seed * 0.5) * 0.15) + 1.0) * 0.5;

    // Layer 1 — scattered background via Poisson disk sampling.
    final scatter = _poissonDisk(_scatterMinGap, worldMin, worldMax, worldMin, worldMax,
        20, math.Random(seed));
    for (final (wx, wz) in scatter) {
      if (densityAt(wx, wz) < _scatterDensityThreshold) continue;
      final wy = TerrainGenerator.heightAt(wx, wz);
      if (wy < 0.6 || wy > 45.0) continue;
      trees.add(_makeTree(id++, wx, wy, wz, seed));
    }

    // Layer 2 — cluster fills: coarse PDS seeds each expanded into a tight group.
    final seeds = _poissonDisk(_clusterSeedSpacing, worldMin, worldMax, worldMin, worldMax,
        20, math.Random(seed + 99));
    for (final (sx, sz) in seeds) {
      if (densityAt(sx, sz) < _clusterSeedDensityThreshold) continue;
      final sy = TerrainGenerator.heightAt(sx, sz);
      if (sy < 0.6 || sy > 45.0) continue;
      final countRange = _clusterCountMax - _clusterCountMin;
      final count = _clusterCountMin + (densityAt(sx, sz) * countRange).round();
      for (int c = 0; c < count; c++) {
        final angle = rng.nextDouble() * math.pi * 2;
        // Two-uniform sum approximates Gaussian falloff, sigma ≈ 4 units.
        final r  = (rng.nextDouble() + rng.nextDouble()) * 5.0;
        final wx = (sx + math.cos(angle) * r).clamp(worldMin, worldMax);
        final wz = (sz + math.sin(angle) * r).clamp(worldMin, worldMax);
        final wy = TerrainGenerator.heightAt(wx, wz);
        if (wy < 0.6 || wy > 45.0) continue;
        trees.add(_makeTree(id++, wx, wy, wz, seed));
      }
    }

    _rebuildGrid();
  }

  /// Poisson disk sampling — guarantees minimum separation [minDist] between
  /// all returned points, producing blue-noise spatial distribution.
  List<(double, double)> _poissonDisk(
      double minDist, double xMin, double xMax, double zMin, double zMax,
      int maxAttempts, math.Random rng) {
    final result = <(double, double)>[];
    final active  = <int>[];
    final cell    = minDist / math.sqrt(2.0);
    final cols    = ((xMax - xMin) / cell).ceil() + 1;
    final rows    = ((zMax - zMin) / cell).ceil() + 1;
    final grid    = List<int>.filled(cols * rows, -1);

    int gIdx(double x, double z) =>
        ((z - zMin) / cell).floor().clamp(0, rows - 1) * cols +
        ((x - xMin) / cell).floor().clamp(0, cols - 1);

    bool valid(double x, double z) {
      final col = ((x - xMin) / cell).floor();
      final row = ((z - zMin) / cell).floor();
      final md2 = minDist * minDist;
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          final r = row + dr, c = col + dc;
          if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
          final idx = grid[r * cols + c];
          if (idx < 0) continue;
          final dx = result[idx].$1 - x;
          final dz = result[idx].$2 - z;
          if (dx * dx + dz * dz < md2) return false;
        }
      }
      return true;
    }

    void add(double x, double z) {
      final i = result.length;
      result.add((x, z));
      active.add(i);
      grid[gIdx(x, z)] = i;
    }

    add(xMin + rng.nextDouble() * (xMax - xMin),
        zMin + rng.nextDouble() * (zMax - zMin));

    while (active.isNotEmpty) {
      final ri  = rng.nextInt(active.length);
      final src = result[active[ri]];
      bool found = false;
      for (int k = 0; k < maxAttempts; k++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final dist  = minDist * (1.0 + rng.nextDouble());
        final nx    = src.$1 + math.cos(angle) * dist;
        final nz    = src.$2 + math.sin(angle) * dist;
        if (nx < xMin || nx > xMax || nz < zMin || nz > zMax) continue;
        if (!valid(nx, nz)) continue;
        add(nx, nz);
        found = true;
        break;
      }
      if (!found) active.removeAt(ri);
    }
    return result;
  }

  /// Build a single tree instance from world position.
  /// Species assigned by elevation: pines on ridges, deciduous in valleys.
  TreeInstance _makeTree(int id, double wx, double wy, double wz, int seed) {
    final elevNorm  = ((wy - 0.6) / 44.4).clamp(0.0, 1.0);
    final typeNoise = (math.sin(wx * 0.99 + wz * 1.31) + 1.0) * 0.5;
    final type = elevNorm > 0.58
        ? 0 // pine on ridges
        : typeNoise < 0.11
            ? 2 // snag (~10%)
            : typeNoise < 0.56
                ? 0 // pine
                : 1; // deciduous

    final sizeNoise   = (math.sin(wx * 2.1 + wz * 1.7) + 1.0) * 0.5;
    final scaleFactor = 0.72 + sizeNoise * 0.58; // 0.72×–1.30× scale variation
    final baseH       = type == 2 ? 3.5 + sizeNoise * 3.5 : 5.5 + sizeNoise * 6.5;
    final height      = baseH * scaleFactor;
    // ±12% canopy radius jitter breaks "army of clones" silhouette.
    final canopyJitter = 0.90 + (math.sin(wx * 3.7 + wz * 2.9) + 1.0) * 0.10;
    final canopyR      = height * (type == 0 ? 0.22 : 0.28) * canopyJitter;
    final trunkR       = (0.20 + sizeNoise * 0.16) * math.sqrt(scaleFactor);

    return TreeInstance(
      id: id, wx: wx, wy: wy, wz: wz,
      height: height, canopyRadius: canopyR, trunkRadius: trunkR, type: type,
    );
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Advance fire spread and burnout. [windVec] is the XZ wind vector (Y=0).
  /// Iterates only burning trees — O(burning) not O(total).
  void update(double dt, Vector3 windVec) {
    int i = 0;
    while (i < _burning.length) {
      final t = _burning[i];
      t.stateTimer += dt;
      final burnDuration = _kBurnTime * (0.7 + t.height / 18.0);
      if (t.stateTimer >= burnDuration) {
        t.state = TreeState.charred;
        t.stateTimer = 0.0;
        dirty = true;
        newlyCharredIds.add(t.id);
        // Swap-remove: O(1), order doesn't matter.
        _burning[i] = _burning.last;
        _burning.removeLast();
      } else {
        if (t.stateTimer > 1.0) _trySpread(t, dt, windVec);
        i++;
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
    int i = 0;
    while (i < _burning.length) {
      final t = _burning[i];
      final dx = t.wx - origin.x;
      final dz = t.wz - origin.z;
      if (dx * dx + dz * dz <= r2) {
        t.state = TreeState.charred;
        t.stateTimer = 0.0;
        dirty = true;
        newlyCharredIds.add(t.id);
        _burning[i] = _burning.last;
        _burning.removeLast();
      } else {
        i++;
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
    _burning.add(t);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _ignite(TreeInstance t) {
    t.state = TreeState.burning;
    t.stateTimer = 0.0;
    dirty = true;
    newlyBurningIds.add(t.id);
    _burning.add(t);
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

  // Pre-allocated snapshot buffer — updated in-place to avoid per-update list alloc.
  final List<(double, double, int)> _snapshotBuf = [];
  // Parallel state tracker: avoids re-allocating a tuple when the state hasn't changed.
  final List<int> _snapshotStateBuf = [];

  /// Updates the cached tree snapshot and returns it.
  /// stateIndex: 0=alive, 1=burning, 2=charred.
  List<(double, double, int)> treeSnapshot() {
    if (_snapshotBuf.length != trees.length) {
      _snapshotBuf.clear();
      _snapshotStateBuf.clear();
      for (final t in trees) {
        _snapshotBuf.add((t.wx, t.wz, t.state.index));
        _snapshotStateBuf.add(t.state.index);
      }
    } else {
      for (int i = 0; i < trees.length; i++) {
        final si = trees[i].state.index;
        if (_snapshotStateBuf[i] != si) {
          _snapshotStateBuf[i] = si;
          _snapshotBuf[i] = (trees[i].wx, trees[i].wz, si);
        }
      }
    }
    return _snapshotBuf;
  }

  static String _gridKey(double x, double z) =>
      '${(x / _kGridCell).floor()}_${(z / _kGridCell).floor()}';
}
