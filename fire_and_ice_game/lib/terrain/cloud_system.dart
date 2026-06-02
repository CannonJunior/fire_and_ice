import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';

enum CloudType { cumulus, cumulonimbus, stratus, cirrus, pyrocumulus }
enum WeatherState { clear, scattered, broken, overcast }

/// One camera-facing billboard quad inside a [CloudChunk].
class CloudBillboard {
  final Vector3 offset;   // from chunk centre (world units)
  final Vector3 color;    // rgb 0..1
  final double  size;     // billboard half-extent
  final double  opacity;  // 0..1
  final double  rotation; // radians

  const CloudBillboard({
    required this.offset,
    required this.color,
    required this.size,
    required this.opacity,
    required this.rotation,
  });
}

/// A cluster of billboard quads forming one cloud.
class CloudChunk {
  final CloudType type;
  Vector3 center;           // drifts each tick()
  final double radiusH;     // horizontal bounding ellipsoid semi-axis
  final double radiusV;     // vertical bounding ellipsoid semi-axis
  final List<CloudBillboard> quads;

  CloudChunk({
    required this.type,
    required this.center,
    required this.radiusH,
    required this.radiusV,
    required this.quads,
  });

  bool containsPoint(Vector3 p) {
    final dx = (p.x - center.x) / radiusH;
    final dy = (p.y - center.y) / radiusV;
    final dz = (p.z - center.z) / radiusH;
    return (dx * dx + dy * dy + dz * dz) < 1.0;
  }
}

/// Manages cloud chunk generation, drift, and fly-through detection.
class CloudSystem {
  WeatherState weather = WeatherState.scattered;
  final List<CloudChunk> chunks = [];

  // Fly-through state
  double flyThroughOpacity  = 0.0;
  double flyThroughAlpha    = 0.65;
  double flyThroughFadeTime = 1.5;
  bool   _inCloud           = false;

  // Cumulus config
  int    cumulusCount     = 15;
  double cumulusAltMin    = 60.0;
  double cumulusAltMax    = 120.0;
  double cumulusRadiusMin = 15.0;
  double cumulusRadiusMax = 40.0;
  int    cumulusBillsMin  = 20;
  int    cumulusBillsMax  = 40;
  double cumulusDriftSpeed = 0.8;

  // CB config
  double cbAltMin     = 40.0;
  double cbAltMax     = 80.0;
  double cbRadiusMin  = 20.0;
  double cbRadiusMax  = 50.0;
  int    cbBillsMin   = 50;
  int    cbBillsMax   = 80;

  bool _configLoaded = false;
  bool get configLoaded => _configLoaded;

  final math.Random _rng = math.Random(0xC10D5EED);

  Future<void> loadConfig() async {
    try {
      final raw  = await rootBundle.loadString('assets/data/cloud_config.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final c    = data['clouds'] as Map<String, dynamic>;
      double n(String k, double fb) => (c[k] as num?)?.toDouble() ?? fb;
      int    i(String k, int fb)    => (c[k] as num?)?.toInt()    ?? fb;

      final wi = i('weatherIndex', 1);
      weather          = WeatherState.values[wi.clamp(0, WeatherState.values.length - 1)];
      cumulusCount     = i('cumulusCount',     cumulusCount);
      cumulusAltMin    = n('cumulusAltMin',    cumulusAltMin);
      cumulusAltMax    = n('cumulusAltMax',    cumulusAltMax);
      cumulusRadiusMin = n('cumulusRadiusMin', cumulusRadiusMin);
      cumulusRadiusMax = n('cumulusRadiusMax', cumulusRadiusMax);
      cumulusBillsMin  = i('cumulusBillsMin',  cumulusBillsMin);
      cumulusBillsMax  = i('cumulusBillsMax',  cumulusBillsMax);
      cumulusDriftSpeed = n('cumulusDriftSpeed', cumulusDriftSpeed);
      flyThroughAlpha   = n('flyThroughAlpha',   flyThroughAlpha);
      flyThroughFadeTime = n('flyThroughFadeTime', flyThroughFadeTime);
      _configLoaded = true;
      debugPrint('[CloudSystem] config loaded, weather=$weather');
    } catch (e) {
      debugPrint('[CloudSystem] config load failed: $e — using defaults');
      _configLoaded = true;
    }
  }

  void generate(double worldExtent) {
    chunks.clear();
    if (weather == WeatherState.clear) return;

    final base = cumulusCount;
    final count = weather == WeatherState.scattered ? base
                : weather == WeatherState.broken    ? (base * 1.8).round()
                :                                     (base * 2.5).round();

    for (int i = 0; i < count; i++) {
      final x   = (_rng.nextDouble() - 0.5) * worldExtent * 2.0;
      final z   = (_rng.nextDouble() - 0.5) * worldExtent * 2.0;
      final alt = cumulusAltMin + _rng.nextDouble() * (cumulusAltMax - cumulusAltMin);
      final r   = cumulusRadiusMin + _rng.nextDouble() * (cumulusRadiusMax - cumulusRadiusMin);
      final n   = cumulusBillsMin  + _rng.nextInt(math.max(1, cumulusBillsMax - cumulusBillsMin));
      chunks.add(_buildCumulus(Vector3(x, alt, z), r, n));
    }

    if (weather == WeatherState.broken || weather == WeatherState.overcast) {
      final cbCount = weather == WeatherState.broken ? 2 : 4;
      for (int i = 0; i < cbCount; i++) {
        final x = (_rng.nextDouble() - 0.5) * worldExtent * 1.5;
        final z = (_rng.nextDouble() - 0.5) * worldExtent * 1.5;
        chunks.add(_buildCumulonimbus(Vector3(x, cbAltMin, z)));
      }
    }

    _addCirrusBand(worldExtent);
    debugPrint('[CloudSystem] generated ${chunks.length} chunks');
  }

  CloudChunk _buildCumulus(Vector3 center, double radius, int n) {
    final quads = <CloudBillboard>[];
    for (int i = 0; i < n; i++) {
      final phi   = math.acos(2.0 * _rng.nextDouble() - 1.0);
      final theta = _rng.nextDouble() * math.pi * 2;
      final r     = _rng.nextDouble();
      final ox = math.sin(phi) * math.cos(theta) * radius * r;
      final oy = math.cos(phi) * radius * 0.55 * r;
      final oz = math.sin(phi) * math.sin(theta) * radius * r;
      // Lit top: bright white. Shadowed underside: cool blue-grey.
      final lit  = (oy / (radius * 0.55) + 1.0) * 0.5; // 0 = bottom, 1 = top
      final cr   = 0.72 + lit * 0.23;
      final cg   = 0.76 + lit * 0.19;
      final cb   = 0.82 + lit * 0.13;
      quads.add(CloudBillboard(
        offset:   Vector3(ox, oy, oz),
        color:    Vector3(cr, cg, cb),
        size:     radius * (0.30 + (1.0 - r) * 0.45),
        opacity:  0.38 + _rng.nextDouble() * 0.22,
        rotation: _rng.nextDouble() * math.pi * 2,
      ));
    }
    return CloudChunk(type: CloudType.cumulus, center: center,
        radiusH: radius, radiusV: radius * 0.55, quads: quads);
  }

  CloudChunk _buildCumulonimbus(Vector3 baseCenter) {
    final r      = cbRadiusMin + _rng.nextDouble() * (cbRadiusMax - cbRadiusMin);
    final totalH = (cbAltMax - cbAltMin) + r * 1.8;
    final n      = cbBillsMin + _rng.nextInt(math.max(1, cbBillsMax - cbBillsMin));
    final quads  = <CloudBillboard>[];

    for (int i = 0; i < n; i++) {
      final t  = _rng.nextDouble(); // 0=base, 1=top anvil
      final oy = t * totalH;
      // Anvil: spread widens sharply above 70% height
      final spread = t < 0.70 ? r * (0.5 + t * 0.7) : r * (1.0 + (t - 0.7) * 1.8);
      final phi    = _rng.nextDouble() * math.pi * 2;
      final ri     = _rng.nextDouble() * spread;
      final ox     = math.cos(phi) * ri;
      final oz     = math.sin(phi) * ri;
      // Colour: dark charcoal at base → white anvil
      final gray = 0.25 + t * 0.70;
      quads.add(CloudBillboard(
        offset:   Vector3(ox, oy, oz),
        color:    Vector3(gray, gray * 1.02, gray * 1.05),
        size:     r * (0.35 + t * 0.40),
        opacity:  0.40 + _rng.nextDouble() * 0.22,
        rotation: _rng.nextDouble() * math.pi * 2,
      ));
    }
    final midCenter = Vector3(baseCenter.x, baseCenter.y + totalH * 0.5, baseCenter.z);
    return CloudChunk(type: CloudType.cumulonimbus, center: midCenter,
        radiusH: r * 2.2, radiusV: totalH * 0.5, quads: quads);
  }

  void _addCirrusBand(double worldExtent) {
    for (int i = 0; i < 12; i++) {
      final x   = (_rng.nextDouble() - 0.5) * worldExtent * 3;
      final z   = (_rng.nextDouble() - 0.5) * worldExtent * 3;
      final alt = 250.0 + _rng.nextDouble() * 150.0;
      final len = 40.0  + _rng.nextDouble() * 80.0;
      final quads = <CloudBillboard>[];
      for (int j = 0; j < 8; j++) {
        quads.add(CloudBillboard(
          offset:   Vector3((_rng.nextDouble() - 0.5) * len, (_rng.nextDouble() - 0.5) * 4, (_rng.nextDouble() - 0.5) * 10),
          color:    Vector3(1.0, 1.0, 1.0),
          size:     20.0 + _rng.nextDouble() * 30.0,
          opacity:  0.07 + _rng.nextDouble() * 0.11,
          rotation: _rng.nextDouble() * math.pi * 2,
        ));
      }
      chunks.add(CloudChunk(type: CloudType.cirrus, center: Vector3(x, alt, z),
          radiusH: len * 0.55, radiusV: 6.0, quads: quads));
    }
  }

  void tick(double dt, Vector3 wind, Vector3 playerPos) {
    final dx = wind.x * cumulusDriftSpeed * dt;
    final dz = wind.z * cumulusDriftSpeed * dt;
    for (final c in chunks) {
      c.center.x += dx;
      c.center.z += dz;
    }

    // Fly-through overlay fade
    final nowIn  = chunks.any((c) => c.containsPoint(playerPos));
    final target = nowIn ? flyThroughAlpha : 0.0;
    final rate   = (target > flyThroughOpacity ? 1.0 : 1.5) / flyThroughFadeTime;
    flyThroughOpacity = (flyThroughOpacity + (target - flyThroughOpacity) * rate * dt)
        .clamp(0.0, 1.0);
    _inCloud = nowIn;
  }

  bool get isInCloud => _inCloud;

  bool isInCB(Vector3 p) =>
      chunks.any((c) => c.type == CloudType.cumulonimbus && c.containsPoint(p));
}
