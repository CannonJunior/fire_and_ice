import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF080C14);
const _kBorder  = Color(0xFF2A3050);
const _kHeader  = Color(0xFF0C1020);
const _kDimTxt  = Color(0xFF445566);
const _kAirTxt  = Color(0xFF88AACC);
const _kBrown   = Color(0xFF5C3A1E);  // solid terrain fill
const _kBrownL  = Color(0xFFAA7744);  // terrain surface edge line
const _kBlue    = Color(0xFF0D2D55);  // AGL air-gap fill
const _kBlueL   = Color(0xFF1A5599);  // AGL top edge line
const _kChevron = Color(0xFFFFDD00);  // aircraft altitude marker

/// Combined radar / barometric altimeter — stacked vertical bar chart.
///
/// Layout (bottom → top):
///   Brown  — terrain elevation above MSL (the solid earth).
///   Blue   — AGL clearance (air column from terrain to aircraft).
///   Empty  — headroom to the auto-scaled ceiling.
///   ◄ chevron on the right edge marks the aircraft's current MSL altitude.
///   🔥 flame  — rendered at the terrain surface when [GameState.isFireBelow]
///              is true (aircraft is inside a world-space fire zone).
///
/// AGL = MSL altitude − terrain elevation.
Widget buildAltIndicator(GameState state) {
  final msl       = state.flightAltitude.clamp(0.0, double.infinity);
  final terrain   = state.terrainHeight.clamp(0.0, msl);
  final agl       = msl - terrain;
  final scale     = _scaleFor(msl);
  final fireBelow = state.isFireBelow;
  final ms        = fireBelow ? DateTime.now().millisecondsSinceEpoch : 0;

  return Container(
    width: 44,
    decoration: BoxDecoration(
      color: _kBg, border: Border.all(color: _kBorder, width: 2)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Header — turns amber when fire detected below
      Container(height: 14, color: _kHeader,
        child: Center(child: Text('ALT',
          style: TextStyle(
            color: fireBelow ? const Color(0xFFFF8800) : _kDimTxt,
            fontSize: 6.5, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
      // Scale ceiling
      Padding(padding: const EdgeInsets.only(top: 2, bottom: 1),
        child: Text(_fmt(scale), textAlign: TextAlign.center,
          style: const TextStyle(color: _kDimTxt, fontSize: 5.5))),
      // Bar
      SizedBox(height: 80, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: CustomPaint(
          painter: _AltBarPainter(
              msl: msl, terrain: terrain, scale: scale,
              fireBelow: fireBelow, ms: ms),
          child: const SizedBox.expand()))),
      // Scale floor
      const Padding(padding: EdgeInsets.only(bottom: 2),
        child: Text('0', textAlign: TextAlign.center,
          style: TextStyle(color: _kDimTxt, fontSize: 5.5))),
      _readout('MSL', msl),
      _readout('AGL', agl),
      // Fire zone label — only shown when fire is detected
      if (fireBelow)
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text('▲ FIRE', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF6600),
                fontSize: 5.5, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
        )
      else
        const SizedBox(height: 2),
    ]),
  );
}

/// Auto-scale: aircraft sits in lower ~75% of the visible range.
double _scaleFor(double alt) {
  for (final s in const [5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0]) {
    if (alt < s * 0.75) return s;
  }
  return (alt * 1.6).roundToDouble();
}

String _fmt(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);

Widget _readout(String label, double v) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: _kDimTxt, fontSize: 6.5)),
    Flexible(child: Text(_fmt(v), textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: _kAirTxt, fontSize: 6.5, fontWeight: FontWeight.bold))),
  ]),
);

// ── Painter ───────────────────────────────────────────────────────────────────

class _AltBarPainter extends CustomPainter {
  final double msl;
  final double terrain;
  final double scale;
  final bool   fireBelow;
  final int    ms; // milliseconds — drives flame flicker

  const _AltBarPainter({
    required this.msl,
    required this.terrain,
    required this.scale,
    this.fireBelow = false,
    this.ms = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final terrainFrac = (terrain / scale).clamp(0.0, 1.0);
    final mslFrac     = (msl     / scale).clamp(0.0, 1.0);
    final terrainY    = size.height * (1.0 - terrainFrac);
    final mslY        = size.height * (1.0 - mslFrac);

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);

    // Brown: solid terrain elevation
    if (terrainFrac > 0.001) {
      canvas.drawRect(
        Rect.fromLTWH(0, terrainY, size.width, size.height - terrainY),
        Paint()..color = _kBrown);
      canvas.drawLine(Offset(0, terrainY), Offset(size.width, terrainY),
          Paint()..color = _kBrownL..strokeWidth = 1.0);
    }

    // Blue: AGL air gap
    if (mslFrac > terrainFrac + 0.001) {
      canvas.drawRect(
        Rect.fromLTWH(0, mslY, size.width, terrainY - mslY),
        Paint()..color = _kBlue);
      canvas.drawLine(Offset(0, mslY), Offset(size.width * 0.55, mslY),
          Paint()..color = _kBlueL..strokeWidth = 0.8);
    }

    // Scale ticks at 25 / 50 / 75%
    final tPaint = Paint()..color = const Color(0xFF1A2A3A)..strokeWidth = 0.5;
    for (final f in const [0.25, 0.50, 0.75]) {
      canvas.drawLine(Offset(0, size.height * (1 - f)),
          Offset(size.width * 0.25, size.height * (1 - f)), tPaint);
    }

    // Fire zone: animated flame at terrain surface when aircraft is over a fire
    if (fireBelow) _drawFlame(canvas, size, terrainY.clamp(0.0, size.height));

    // ◄ chevron at MSL altitude
    final cx   = size.width;
    const half = 5.0;
    final path = Path()
      ..moveTo(cx, mslY - half)
      ..lineTo(cx - half, mslY)
      ..lineTo(cx, mslY + half);
    canvas.drawPath(path, Paint()..color = _kChevron..style = PaintingStyle.fill);
    canvas.drawLine(Offset(0, mslY), Offset(cx - half, mslY),
        Paint()..color = _kChevron.withValues(alpha: 0.35)..strokeWidth = 0.6);
  }

  /// Animated flame shape centred on the bar at [baseY] (the terrain surface).
  ///
  /// Two overlapping teardrop paths (outer = orange, inner = yellow) flicker
  /// using a sin oscillator driven by [ms].  The flame extends upward into the
  /// AGL clearance zone, correctly depicting fire rising from the ground.
  void _drawFlame(Canvas canvas, Size size, double baseY) {
    final pulse = 0.72 + 0.28 * math.sin(ms / 260.0);
    final sway  = 1.0 + 0.5 * math.sin(ms / 190.0); // slight lean
    final cx    = size.width / 2 + sway;
    const fw    = 5.5;  // half-width at flame base
    const fh    = 13.0; // height above terrain surface

    // Outer flame — orange
    final outer = Path()
      ..moveTo(cx - fw, baseY)
      ..quadraticBezierTo(cx - fw * 0.6, baseY - fh * 0.45, cx, baseY - fh)
      ..quadraticBezierTo(cx + fw * 0.6, baseY - fh * 0.45, cx + fw, baseY)
      ..close();
    canvas.drawPath(outer,
        Paint()
          ..color = Color.fromRGBO(255, 105, 0, pulse)
          ..style = PaintingStyle.fill);

    // Inner flame — yellow core
    final inner = Path()
      ..moveTo(cx - fw * 0.45, baseY)
      ..quadraticBezierTo(cx, baseY - fh * 0.38, cx, baseY - fh * 0.68)
      ..quadraticBezierTo(cx, baseY - fh * 0.38, cx + fw * 0.45, baseY)
      ..close();
    canvas.drawPath(inner,
        Paint()
          ..color = Color.fromRGBO(255, 228, 0, pulse * 0.88)
          ..style = PaintingStyle.fill);

    // Glow halo at base — faint wide circle
    canvas.drawCircle(Offset(cx, baseY), fw * 1.5,
        Paint()
          ..color = Color.fromRGBO(255, 80, 0, 0.18 * pulse)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_AltBarPainter o) =>
      o.msl != msl || o.terrain != terrain || o.scale != scale ||
      o.fireBelow != fireBelow || (fireBelow && o.ms != ms);
}
