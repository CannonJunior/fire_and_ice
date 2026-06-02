import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

// Colour stratification: ground soot → cream top (5 layers, index 0..4).
const List<List<double>> _kColorLayers = [
  [0.15, 0.12, 0.10], // 0: near-black soot
  [0.40, 0.38, 0.35], // 1: dark warm grey
  [0.65, 0.63, 0.60], // 2: mid grey
  [0.85, 0.83, 0.80], // 3: light grey
  [0.95, 0.95, 0.95], // 4: cream
];
const List<double> _kOpacity = [1.0, 0.80, 0.60, 0.30, 0.10];

/// One stacked-billboard segment of an atmospheric plume.
class SmokeColumnBillboard {
  final Vector3 position; // world-space centre of this quad
  final double  width;
  final double  height;
  final Vector4 color;    // rgb + alpha (already includes intensity × opacity)
  final double  layerIndex; // 0..4 passed to fragment shader for altitude fade

  const SmokeColumnBillboard({
    required this.position,
    required this.width,
    required this.height,
    required this.color,
    required this.layerIndex,
  });
}

/// A single fire zone's long-range smoke column.
///
/// Grows toward [maxHeight] while burning, shrinks when extinguished.
/// Segments are spaced evenly from ground to [currentHeight]; width expands
/// linearly from [baseWidth] to [topWidth].
class AtmosphericSmokePlume {
  final int    zoneIndex;
  final double sourceX, sourceZ;

  double intensity     = 0.0;
  double currentHeight = 0.0;

  final double maxHeight, baseWidth, topWidth;
  final double billowFrequency, windDriftScale;
  final int    segmentCount;

  double _noisePhase;
  final Vector2 _drift = Vector2.zero(); // accumulated XZ wind drift

  AtmosphericSmokePlume({
    required this.zoneIndex,
    required this.sourceX,
    required this.sourceZ,
    required this.maxHeight,
    required this.baseWidth,
    required this.topWidth,
    required this.billowFrequency,
    required this.windDriftScale,
    required this.segmentCount,
  }) : _noisePhase = math.Random().nextDouble() * math.pi * 2;

  void tick(double intensity, Vector3 wind, double dt) {
    this.intensity = intensity;
    if (intensity <= 0.0) {
      currentHeight = (currentHeight - dt * 4.0).clamp(0.0, maxHeight);
      return;
    }
    currentHeight = (currentHeight + dt * 7.0).clamp(0.0, maxHeight);
    _drift.x     += wind.x * windDriftScale * dt;
    _drift.y     += wind.z * windDriftScale * dt; // world-Z stored in .y
    _noisePhase  += billowFrequency * dt;
  }

  List<SmokeColumnBillboard> buildBillboards({int? count}) {
    if (currentHeight < 0.5) return const [];
    final n    = count ?? segmentCount;
    final segH = currentHeight / n;
    final out  = <SmokeColumnBillboard>[];

    for (int i = 0; i < n; i++) {
      final t = n > 1 ? i / (n - 1) : 0.0; // 0 = base, 1 = top
      final layerF  = (t * 4.0).clamp(0.0, 4.0);
      final layerI  = layerF.floor().clamp(0, 3);
      final blend   = layerF - layerI;

      final c0  = _kColorLayers[layerI];
      final c1  = _kColorLayers[(layerI + 1).clamp(0, 4)];
      final op0 = _kOpacity[layerI];
      final op1 = _kOpacity[(layerI + 1).clamp(0, 4)];

      final r   = c0[0] + (c1[0] - c0[0]) * blend;
      final g   = c0[1] + (c1[1] - c0[1]) * blend;
      final b   = c0[2] + (c1[2] - c0[2]) * blend;
      final op  = (op0 + (op1 - op0) * blend) * intensity;

      final width = baseWidth + (topWidth - baseWidth) * t;
      // Slow swirl: each segment displaced slightly in XZ for organic feel.
      final swirl = math.sin(_noisePhase + i * 0.55) * width * 0.06;

      out.add(SmokeColumnBillboard(
        position:   Vector3(
          sourceX + _drift.x + swirl,
          i * segH + segH * 0.5,
          sourceZ + _drift.y,
        ),
        width:      width,
        height:     segH * 1.12, // slight overlap hides seams
        color:      Vector4(r, g, b, op),
        layerIndex: layerF,
      ));
    }
    return out;
  }
}

/// Manages one [AtmosphericSmokePlume] per fire zone and applies LOD.
class AtmosphericSmokeSystem {
  final List<AtmosphericSmokePlume> _plumes = [];

  // Tunable defaults (overridden by fire_config.json atmosphericSmoke section).
  int    segmentsPerPlume   = 12;
  double baseWidth          = 14.0;
  double topWidth           = 28.0;
  double maxHeight          = 100.0;
  double billowingFrequency = 0.05;
  double windDriftScale     = 0.50;

  List<AtmosphericSmokePlume> get plumes => _plumes;

  void addPlume(int zoneIdx, double x, double z) {
    _plumes.add(AtmosphericSmokePlume(
      zoneIndex:        zoneIdx,
      sourceX:          x,
      sourceZ:          z,
      maxHeight:        maxHeight,
      baseWidth:        baseWidth,
      topWidth:         topWidth,
      billowFrequency:  billowingFrequency,
      windDriftScale:   windDriftScale,
      segmentCount:     segmentsPerPlume,
    ));
  }

  void tickPlume(int idx, double intensity, Vector3 wind, double dt) {
    if (idx < _plumes.length) _plumes[idx].tick(intensity, wind, dt);
  }

  /// Minimum horizontal distance (world units) before atmospheric plumes are
  /// rendered.  Below this the close-range CPU particle system covers the zone;
  /// far-field quads that close would fill or dominate the viewport.
  static const double nearCutoff = 150.0;

  // Pre-allocated billboard buffer — rebuilt each call but avoids repeated list growth.
  final List<SmokeColumnBillboard> _billboardBuf = [];

  /// Returns all billboard segments sorted back-to-front for correct blending.
  List<SmokeColumnBillboard> getAllBillboards(Vector3 cameraPos) {
    _billboardBuf.clear();
    for (final p in _plumes) {
      final dx   = cameraPos.x - p.sourceX;
      final dz   = cameraPos.z - p.sourceZ;
      final dist = math.sqrt(dx * dx + dz * dz);
      if (dist < nearCutoff) continue;
      final lod = dist < 150 ? 15 : 7;
      _billboardBuf.addAll(p.buildBillboards(count: lod));
    }
    // Inline distance squared — avoids per-comparison Vector3 allocation.
    _billboardBuf.sort((a, b) {
      final dax = a.position.x - cameraPos.x;
      final day = a.position.y - cameraPos.y;
      final daz = a.position.z - cameraPos.z;
      final dbx = b.position.x - cameraPos.x;
      final dby = b.position.y - cameraPos.y;
      final dbz = b.position.z - cameraPos.z;
      return (dbx*dbx + dby*dby + dbz*dbz).compareTo(dax*dax + day*day + daz*daz);
    });
    return _billboardBuf;
  }
}
