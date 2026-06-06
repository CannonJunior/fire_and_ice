import 'dart:math' as math;

/// Defines one end of a runway (approach direction + threshold position).
class RunwayEnd {
  final String id;
  final double headingDeg;
  final double threshX, threshZ;
  final double centerX, centerZ;

  const RunwayEnd({
    required this.id,
    required this.headingDeg,
    required this.threshX, required this.threshZ,
    required this.centerX, required this.centerZ,
  });

  // Unit fly-direction in XZ plane (heading 0°= −Z, 90°= −X, 180°= +Z, 270°= +X)
  double get flyDx => -math.sin(headingDeg * math.pi / 180);
  double get flyDz => -math.cos(headingDeg * math.pi / 180);

  // Left-of-track perpendicular (90° CCW from flyDir)
  double get leftDx => -flyDz;
  double get leftDz =>  flyDx;
}

/// Real-time approach data computed from player position.
class ApproachData {
  final RunwayEnd runway;
  final double locDots;       // ±1.0 = full scale; positive = needle right (fly right)
  final double gsDots;        // ±1.0 = full scale; positive = needle low (you're above GS)
  final double downrangeM;    // distance from threshold; negative = past runway
  final double glideAngleDeg; // current glidepath angle above horizon
  final List<bool> papiWhite; // 4 PAPI lights (left→right): true=white, false=red

  const ApproachData({
    required this.runway,
    required this.locDots,
    required this.gsDots,
    required this.downrangeM,
    required this.glideAngleDeg,
    required this.papiWhite,
  });
}

class LandingSystem {
  LandingSystem._();

  static const List<RunwayEnd> runways = [
    // N-S runway — threshold at north end, fly south (heading 0°)
    RunwayEnd(id:'RW36', headingDeg:0,   threshX:-150, threshZ: 88, centerX:-150, centerZ:0),
    // N-S runway — threshold at south end, fly north (heading 180°)
    RunwayEnd(id:'RW18', headingDeg:180, threshX:-150, threshZ:-88, centerX:-150, centerZ:0),
    // E-W runway — threshold at east end, fly west (heading 90°)
    RunwayEnd(id:'RW09', headingDeg:90,  threshX: -85, threshZ:  0, centerX:-150, centerZ:0),
    // E-W runway — threshold at west end, fly east (heading 270°)
    RunwayEnd(id:'RW27', headingDeg:270, threshX:-215, threshZ:  0, centerX:-150, centerZ:0),
  ];

  /// Finds the runway end that best matches the player's current heading.
  /// Returns null if no runway is within ±70° of player heading.
  static RunwayEnd? bestRunway(double px, double pz, double headingDeg) {
    RunwayEnd? best;
    double bestScore = double.infinity;
    for (final rw in runways) {
      double diff = (headingDeg - rw.headingDeg + 360) % 360;
      if (diff > 180) diff = 360 - diff;
      if (diff > 70) continue;
      final dtx = rw.threshX - px;
      final dtz = rw.threshZ - pz;
      // Must be approaching from the correct side (or very close to threshold)
      final dot = dtx * rw.flyDx + dtz * rw.flyDz;
      if (dot < -10) continue;
      final score = diff * 2 + math.sqrt(dtx * dtx + dtz * dtz);
      if (score < bestScore) { bestScore = score; best = rw; }
    }
    return best;
  }

  static const double _gsRads = 3.0 * math.pi / 180; // 3° glideslope

  /// Computes real-time ILS approach data for the given runway end.
  static ApproachData computeApproach(
      double px, double py, double pz, RunwayEnd rw) {
    final dx = px - rw.threshX;
    final dz = pz - rw.threshZ;

    // Downrange: positive = player is on approach side of threshold
    final downrange = dx * rw.flyDx + dz * rw.flyDz;

    // Lateral deviation: positive = player is to the LEFT of centerline (pilot perspective)
    final latDev = dx * rw.leftDx + dz * rw.leftDz;

    // LOC: needle deflects toward centerline — positive = needle right (fly right)
    final locDots = (latDev / 4.0).clamp(-2.5, 2.5);

    // GS: positive = above glidepath (needle low — you need to descend)
    final altAGL    = math.max(py - 0.5, 0.0);
    final expected  = math.max(downrange, 0) * math.tan(_gsRads);
    final gsDots    = ((altAGL - expected) / 3.0).clamp(-2.5, 2.5);

    // Glidepath angle in degrees
    final glideAng = downrange > 1
        ? math.atan2(altAGL, downrange) * 180 / math.pi
        : 0.0;

    // PAPI: 4 lights. Light[0] (leftmost) goes white above 3.5°, light[3] above 2.0°.
    // At exactly 3° you see lights[0,1] red and lights[2,3] white → 2 red + 2 white = on slope.
    final papiWhite = [
      for (int i = 0; i < 4; i++) glideAng >= (3.5 - i * 0.5),
    ];

    return ApproachData(
      runway: rw, locDots: locDots, gsDots: gsDots,
      downrangeM: downrange, glideAngleDeg: glideAng, papiWhite: papiWhite,
    );
  }

  /// World positions of the 4 PAPI lights for 3D rendering / projection.
  static List<(double x, double y, double z)> papiWorldPositions(RunwayEnd rw) {
    const spacing = 3.0;
    final bx = rw.threshX - rw.flyDx * 8 + rw.leftDx * 20;
    final bz = rw.threshZ - rw.flyDz * 8 + rw.leftDz * 20;
    return [
      for (int i = 0; i < 4; i++)
        (bx + rw.leftDx * i * spacing, 1.0, bz + rw.leftDz * i * spacing),
    ];
  }
}
