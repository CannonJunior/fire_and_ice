import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import '../rendering/mesh.dart';
import '../rendering/transform3d.dart';

/// TerrainGenerator - Procedural heightmap terrain as a single mesh.
///
/// Generates a 64×64 grid using sin/cos-based pseudo-noise (no external
/// Perlin library needed). Height-based vertex coloring produces a visually
/// rich landscape: deep blue valleys, green mid-lands, grey peaks, white snow.
///
/// Returns a (mesh, transform) record so callers can position the terrain
/// independently of generation. The mesh itself is centered on the origin.
///
/// Usage:
/// ```dart
/// final (:mesh, :transform) = TerrainGenerator.generate();
/// renderer.render(mesh, transform, camera);
/// ```
class TerrainGenerator {
  TerrainGenerator._(); // Static-only class

  // ── Public API ───────────────────────────────────────────────────────────

  /// Generate a single centred terrain mesh (original single-tile API).
  static ({Mesh mesh, Transform3d transform}) generate({
    int gridSize    = 64,
    double tileSize = 2.0,
    double maxHeight = 12.0,
    int seed        = 42,
  }) {
    final heights = _generateHeightmap(gridSize, maxHeight, seed);
    final mesh    = _buildMesh(gridSize, tileSize, maxHeight, heights, center: true);
    return (mesh: mesh, transform: Transform3d());
  }

  /// Return the terrain height at world position (wx, wz).
  ///
  /// Uses the same noise formula and parameters as the default [generate] call
  /// (gridSize=64, tileSize=2.0, maxHeight=12.0, seed=1337, centered) so the
  /// physics system can query ground elevation without storing the heightmap.
  static double heightAt(double wx, double wz) {
    const seedOff = 1337 * 0.123; // = 164.451
    // World → normalized grid coordinates (same transform as _generateHeightmap)
    final nx = wx / 128.0 + 0.5 + seedOff;
    final nz = wz / 128.0 + 0.5 + seedOff;
    double h = 0.5    * _noise(nx * 2.1,  nz * 2.1);
    h       += 0.25   * _noise(nx * 4.3,  nz * 4.3);
    h       += 0.125  * _noise(nx * 8.7,  nz * 8.7);
    h       += 0.0625 * _noise(nx * 17.1, nz * 17.1);
    h = (h + 0.9375) / 1.875;
    h = h.clamp(0.0, 1.0) * 12.0;
    if (h < 1.8) h *= 0.4; // flatten valley bottoms (12.0 × 0.15 = 1.8)
    return h;
  }

  /// Generate one chunk of an infinite terrain grid.
  ///
  /// Uses world-space coordinates for the noise function so heights are
  /// perfectly continuous at every chunk boundary.  Vertex (0, ?, 0) in
  /// local space corresponds to world position
  /// (chunkX × gridSize × tileSize, ?, chunkZ × gridSize × tileSize).
  static Mesh generateChunk({
    required int chunkX,
    required int chunkZ,
    int gridSize     = 32,
    double tileSize  = 2.0,
    double maxHeight = 12.0,
    int seed         = 1337,
  }) {
    final heights = _generateChunkHeightmap(
        chunkX, chunkZ, gridSize, tileSize, maxHeight, seed);
    return _buildMesh(gridSize, tileSize, maxHeight, heights, center: false);
  }

  // ── Heightmap generation ─────────────────────────────────────────────────

  /// Build a 2D heightmap using layered sin/cos noise as a Perlin substitute.
  ///
  /// Multiple frequency octaves are summed to create natural-looking terrain.
  /// Reason: dart:math sin/cos avoids external dependencies and runs fast
  /// in the browser, while still producing visually convincing landscapes.
  static List<List<double>> _generateHeightmap(
    int size,
    double maxHeight,
    int seed,
  ) {
    // Reason: offset by seed so different seeds produce different maps
    final seedOff = seed.toDouble() * 0.123;

    final heights = List.generate(
      size + 1,
      (_) => List<double>.filled(size + 1, 0.0),
    );

    for (int z = 0; z <= size; z++) {
      for (int x = 0; x <= size; x++) {
        final nx = x / size.toDouble() + seedOff;
        final nz = z / size.toDouble() + seedOff;

        // Octave 1: large hills
        double h = 0.5  * _noise(nx * 2.1,  nz * 2.1);
        // Octave 2: medium features
        h       += 0.25 * _noise(nx * 4.3,  nz * 4.3);
        // Octave 3: small bumps
        h       += 0.125 * _noise(nx * 8.7, nz * 8.7);
        // Octave 4: micro detail
        h       += 0.0625 * _noise(nx * 17.1, nz * 17.1);

        // Normalise to [0, 1] then scale to maxHeight
        // Sum amplitude = 0.9375; bias to positive
        h = (h + 0.9375) / 1.875;
        h = h.clamp(0.0, 1.0) * maxHeight;

        // Flatten valley bottoms slightly for visual interest
        if (h < maxHeight * 0.15) h *= 0.4;

        heights[z][x] = h;
      }
    }

    return heights;
  }

  /// Heightmap for one chunk using global world coordinates.
  ///
  /// The noise is sampled at the same frequency as the single-mesh variant
  /// but at absolute world positions, guaranteeing seamless edges between
  /// adjacent chunks regardless of render distance or generation order.
  static List<List<double>> _generateChunkHeightmap(
    int chunkX, int chunkZ,
    int size, double tileSize, double maxHeight, int seed,
  ) {
    // Seed-derived world offset so different seeds look different
    final so = seed * 8.37;

    final heights = List.generate(size + 1, (_) => List<double>.filled(size + 1, 0.0));

    for (int iz = 0; iz <= size; iz++) {
      for (int ix = 0; ix <= size; ix++) {
        // Absolute world-space coordinates — same values at shared edges
        final wx = (chunkX * size + ix) * tileSize + so;
        final wz = (chunkZ * size + iz) * tileSize + so;

        // Same octave structure as the single-mesh generator, expressed in
        // world-unit frequencies (derived by dividing the original per-mesh
        // frequencies by the original mesh world size of 128 units).
        double h = 0.5000 * _noise(wx * 0.01641, wz * 0.01641);
        h       += 0.2500 * _noise(wx * 0.03359, wz * 0.03359);
        h       += 0.1250 * _noise(wx * 0.06797, wz * 0.06797);
        h       += 0.0625 * _noise(wx * 0.13359, wz * 0.13359);

        h = (h + 0.9375) / 1.875;          // normalise to [0, 1]
        h = h.clamp(0.0, 1.0) * maxHeight;
        if (h < maxHeight * 0.15) h *= 0.4; // flatten valleys

        heights[iz][ix] = h;
      }
    }
    return heights;
  }

  /// Smooth, continuous noise function using sine products.
  ///
  /// Not true Perlin noise but produces similar visual results without
  /// requiring gradient tables or a lattice structure.
  static double _noise(double x, double z) {
    return math.sin(x * 1.7 + z * 0.3) *
           math.cos(z * 1.4 - x * 0.7) *
           math.sin((x + z) * 0.9);
  }

  // ── Mesh construction ────────────────────────────────────────────────────

  /// Build the terrain Mesh from a heightmap.
  ///
  /// Computes smooth normals by averaging cross-products of adjacent triangles
  /// so the terrain lights convincingly under directional illumination.
  /// Build the terrain Mesh from a heightmap.
  ///
  /// [center] = true  → vertices span (−half, 0, −half) to (+half, ?, +half),
  ///            suitable for a single mesh centred at world origin.
  /// [center] = false → vertices span (0, 0, 0) to (size×tileSize, ?, size×tileSize),
  ///            suitable for chunks positioned by a world-space Transform3d.
  static Mesh _buildMesh(
    int size,
    double tileSize,
    double maxHeight,
    List<List<double>> heights, {
    bool center = true,
  }) {
    final vertexCount  = (size + 1) * (size + 1);
    final indexCount   = size * size * 6;

    final vertices = Float32List(vertexCount * 3);
    final normals  = Float32List(vertexCount * 3);
    final colors   = Float32List(vertexCount * 4);
    final indices  = Uint16List(indexCount);

    // ── Vertices + colors ────────────────────────────────────────────────
    for (int z = 0; z <= size; z++) {
      for (int x = 0; x <= size; x++) {
        final vi = (z * (size + 1) + x);
        final h  = heights[z][x];

        final ox = center ? x - size / 2.0 : x.toDouble();
        final oz = center ? z - size / 2.0 : z.toDouble();
        vertices[vi * 3 + 0] = ox * tileSize;
        vertices[vi * 3 + 1] = h;
        vertices[vi * 3 + 2] = oz * tileSize;

        // Height-based coloring
        final t = h / maxHeight; // 0 = valley, 1 = peak
        final c = _heightColor(t);

        colors[vi * 4 + 0] = c.x;
        colors[vi * 4 + 1] = c.y;
        colors[vi * 4 + 2] = c.z;
        colors[vi * 4 + 3] = 1.0;
      }
    }

    // ── Indices ──────────────────────────────────────────────────────────
    int idx = 0;
    for (int z = 0; z < size; z++) {
      for (int x = 0; x < size; x++) {
        final tl = z * (size + 1) + x;
        final tr = tl + 1;
        final bl = (z + 1) * (size + 1) + x;
        final br = bl + 1;

        indices[idx++] = tl;
        indices[idx++] = bl;
        indices[idx++] = br;

        indices[idx++] = tl;
        indices[idx++] = br;
        indices[idx++] = tr;
      }
    }

    // ── Normals (accumulate then normalise) ───────────────────────────────
    // Reason: accumulating face normals per-vertex then normalising gives
    // smooth shading similar to vertex-normal averaging in DCC tools.
    for (int z = 0; z < size; z++) {
      for (int x = 0; x < size; x++) {
        final tl = z * (size + 1) + x;
        final tr = tl + 1;
        final bl = (z + 1) * (size + 1) + x;
        final br = bl + 1;

        _accumulateFaceNormal(vertices, normals, tl, bl, br);
        _accumulateFaceNormal(vertices, normals, tl, br, tr);
      }
    }

    // Normalise accumulated normals
    for (int vi = 0; vi < vertexCount; vi++) {
      final nx = normals[vi * 3 + 0];
      final ny = normals[vi * 3 + 1];
      final nz = normals[vi * 3 + 2];
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 0.0001) {
        normals[vi * 3 + 0] = nx / len;
        normals[vi * 3 + 1] = ny / len;
        normals[vi * 3 + 2] = nz / len;
      } else {
        normals[vi * 3 + 1] = 1.0; // Fallback to world up
      }
    }

    return Mesh(
      vertices: vertices,
      indices:  indices,
      normals:  normals,
      colors:   colors,
    );
  }

  /// Accumulate face normal for vertices a, b, c into the normals buffer.
  static void _accumulateFaceNormal(
    Float32List verts,
    Float32List norms,
    int a,
    int b,
    int c,
  ) {
    final ax = verts[a*3], ay = verts[a*3+1], az = verts[a*3+2];
    final bx = verts[b*3], by = verts[b*3+1], bz = verts[b*3+2];
    final cx = verts[c*3], cy = verts[c*3+1], cz = verts[c*3+2];

    // Edge vectors
    final ux = bx - ax, uy = by - ay, uz = bz - az;
    final vx = cx - ax, vy = cy - ay, vz = cz - az;

    // Cross product
    final nx = uy * vz - uz * vy;
    final ny = uz * vx - ux * vz;
    final nz = ux * vy - uy * vx;

    for (final vi in [a, b, c]) {
      norms[vi*3+0] += nx;
      norms[vi*3+1] += ny;
      norms[vi*3+2] += nz;
    }
  }

  /// Map a normalized height value (0-1) to a landscape color.
  ///
  /// Biome thresholds (approximate):
  ///  - 0.00–0.12: deep blue water/valleys
  ///  - 0.12–0.35: sandy/earthy lowlands
  ///  - 0.35–0.65: green mid-terrain
  ///  - 0.65–0.82: grey rocky highlands
  ///  - 0.82–1.00: white snow peaks
  static Vector3 _heightColor(double t) {
    if (t < 0.12) {
      // Deep blue valleys
      return Vector3(0.05, 0.15, 0.55) * (0.5 + t * 4.0);
    } else if (t < 0.35) {
      // Sandy/earthy transition
      final f = (t - 0.12) / 0.23;
      return Vector3(
        0.55 + f * 0.1,
        0.42 + f * 0.18,
        0.15 + f * 0.05,
      );
    } else if (t < 0.65) {
      // Grassy mid-terrain
      final f = (t - 0.35) / 0.30;
      return Vector3(
        0.2  + f * 0.15,
        0.52 - f * 0.1,
        0.12 - f * 0.04,
      );
    } else if (t < 0.82) {
      // Rocky grey highlands
      final f = (t - 0.65) / 0.17;
      return Vector3(
        0.42 + f * 0.25,
        0.42 + f * 0.25,
        0.40 + f * 0.28,
      );
    } else {
      // Snow-capped peaks
      final f = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
      return Vector3(
        0.75 + f * 0.25,
        0.80 + f * 0.20,
        0.88 + f * 0.12,
      );
    }
  }
}
