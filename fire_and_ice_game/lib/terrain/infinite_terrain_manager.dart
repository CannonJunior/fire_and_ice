import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../rendering/transform3d.dart';
import 'terrain_chunk.dart';
import 'terrain_generator.dart';

/// InfiniteTerrainManager - Streams terrain chunks in and out as the player moves.
///
/// Maintains a square window of [renderDistance] chunks around the player.
/// New chunks are generated at most [_maxPerFrame] per frame to avoid stutter.
/// All chunks for the same seed produce seamless height boundaries because
/// the noise is sampled in global world coordinates.
class InfiniteTerrainManager {
  // ── Configuration ─────────────────────────────────────────────────────────

  /// Tiles per chunk side.
  static const int    chunkGridSize  = 32;

  /// World units per tile — matches the airfield generator.
  static const double chunkTileSize  = 2.0;

  /// Side length of one chunk in world units.
  static const double chunkWorldSize = chunkGridSize * chunkTileSize; // 64.0

  /// How many chunks in each cardinal direction from the player are kept loaded.
  /// 3 → 7×7 = 49 chunks visible, covering ±192 world units.
  static const int renderDistance = 3;

  /// Half-resolution grid size for outermost LOD ring (distance == renderDistance).
  static const int chunkLODGridSize = 16;

  static const double _maxHeight  = 12.0;
  static const int    _seed       = 1337;

  /// Maximum new chunks generated per game-loop frame to limit CPU spikes.
  static const int _maxPerFrame = 2;

  // ── State ─────────────────────────────────────────────────────────────────

  // Integer key: packs (cx, cz) into one int — avoids string allocation per lookup.
  // Supports chunk coords in ±524287 range (>> sufficient for any playable world).
  static int _key(int cx, int cz) => (cx & 0xFFFFF) << 20 | (cz & 0xFFFFF);

  final Map<int, TerrainChunk> _chunks = {};

  int _lastCX = 0x7fffffff;
  int _lastCZ = 0x7fffffff;

  // ── Coordinate helpers ────────────────────────────────────────────────────

  /// World coordinate → chunk index along one axis.
  static int worldToChunk(double w) => (w / chunkWorldSize).floor();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generate all chunks in render distance synchronously.
  ///
  /// Call once during scene initialisation.  Subsequent frame-by-frame
  /// expansion is handled by [update].
  void preload(Vector3 playerPos) {
    final cx = worldToChunk(playerPos.x);
    final cz = worldToChunk(playerPos.z);
    for (int dx = -renderDistance; dx <= renderDistance; dx++) {
      for (int dz = -renderDistance; dz <= renderDistance; dz++) {
        _generate(cx + dx, cz + dz, _lodGridSize(dx, dz));
      }
    }
    _lastCX = cx;
    _lastCZ = cz;
  }

  /// Call every frame.  Generates up to [_maxPerFrame] new chunks and
  /// discards any chunk that has drifted outside render distance + 1.
  void update(Vector3 playerPos) {
    final cx = worldToChunk(playerPos.x);
    final cz = worldToChunk(playerPos.z);
    if (cx == _lastCX && cz == _lastCZ) return;
    _lastCX = cx;
    _lastCZ = cz;

    _unloadDistant(cx, cz);
    _loadAround(cx, cz);
  }

  /// All currently loaded chunks — pass each to the renderer every frame.
  ///
  /// Returns the map values view directly (no copy) so the render loop iterates
  /// in-place without allocating a new List on every frame.
  Iterable<TerrainChunk> get loadedChunks => _chunks.values;

  /// Diagnostic: number of loaded chunks.
  int get loadedCount => _chunks.length;

  // ── Private ───────────────────────────────────────────────────────────────

  void _loadAround(int cx, int cz) {
    final needed = <(int, int, int)>[]; // (dist², dx, dz)
    for (int dx = -renderDistance; dx <= renderDistance; dx++) {
      for (int dz = -renderDistance; dz <= renderDistance; dz++) {
        final key           = _key(cx + dx, cz + dz);
        final targetGrid    = _lodGridSize(dx, dz);
        final existing      = _chunks[key];
        // Evict if LOD level changed (e.g. player moved toward an outer chunk).
        if (existing != null && existing.gridSize != targetGrid) {
          _chunks.remove(key);
        }
        if (!_chunks.containsKey(key)) {
          needed.add((dx * dx + dz * dz, dx, dz));
        }
      }
    }

    // Generate closest chunks first so the area around the player fills in fast
    needed.sort((a, b) => a.$1.compareTo(b.$1));

    final limit = math.min(_maxPerFrame, needed.length);
    for (int i = 0; i < limit; i++) {
      final (_, dx, dz) = needed[i];
      _generate(cx + dx, cz + dz, _lodGridSize(dx, dz));
    }
  }

  /// Returns the grid resolution for a chunk at offset (dx, dz) from the player.
  ///
  /// Only the outermost ring (Chebyshev distance == renderDistance) is
  /// downsampled — this limits the LOD transition zone to the far edge of the
  /// visible area, minimising pop when the player crosses a chunk boundary.
  int _lodGridSize(int dx, int dz) {
    final dist = math.max(dx.abs(), dz.abs());
    return dist < renderDistance ? chunkGridSize : chunkLODGridSize;
  }

  void _unloadDistant(int cx, int cz) {
    // Keep one extra ring as a buffer so we don't thrash at boundaries
    const buffer = renderDistance + 1;
    _chunks.removeWhere((_, chunk) =>
        (chunk.chunkX - cx).abs() > buffer ||
        (chunk.chunkZ - cz).abs() > buffer);
  }

  void _generate(int cx, int cz, int gridSize) {
    final key = _key(cx, cz);
    if (_chunks.containsKey(key)) return;

    final mesh = TerrainGenerator.generateChunk(
      chunkX:    cx,    chunkZ:    cz,
      gridSize:  gridSize,
      tileSize:  chunkTileSize,
      maxHeight: _maxHeight,
      seed:      _seed,
    );

    _chunks[key] = TerrainChunk(
      chunkX:    cx,
      chunkZ:    cz,
      mesh:      mesh,
      gridSize:  gridSize,
      transform: Transform3d(
          position: Vector3(cx * chunkWorldSize, 0, cz * chunkWorldSize)),
    );
  }
}
