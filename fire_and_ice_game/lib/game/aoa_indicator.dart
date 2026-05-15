import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF080C14);
const _kShelf  = Color(0xFF1C3D5A); // kIceShelf — matches FIRE PROX border/label
const _kDim    = Color(0xFF445566);
const _kNeedle = Color(0xFFDDEEFF);
const _kGreen  = Color(0xFF00BB55);
const _kAmber  = Color(0xFFFFAA00);
const _kRed    = Color(0xFFEE2222);

// ── Arc geometry ──────────────────────────────────────────────────────────────
// 270° sweep, 7:30 → 4:30 clockwise (same as standard AoA instruments).
// Flutter canvas: clockwise from 3-o'clock.  7:30 = 135° from 3-o'clock.
const _kArcStart = math.pi * 0.75; // 135°
const _kArcSweep = math.pi * 1.5;  // 270°

// ── Scale ─────────────────────────────────────────────────────────────────────
const _kAoaMin   = -15.0;
const _kAoaMax   =  30.0;
const _kAoaRange =  45.0;
const _kCaution  =  12.0; // amber starts
const _kDanger   =  22.0; // red starts

/// Circular angle-of-attack indicator — same 120×120 footprint as FIRE PROX.
///
/// Effective AoA = pitch × (stallSpeed / speed), so low-speed flight reads
/// higher AoA for the same nose attitude, matching real aerodynamics.
///
/// Zones:  green −15°→+12°  normal
///         amber  12°→+22°  caution
///         red    22°→+30°  near-stall / stall
Widget buildAoaIndicator(GameState state) {
  final double displayAoa;
  if (state.gameMode == GameMode.taxi) {
    displayAoa = 0.0;
  } else {
    final ratio = (state.cfgStallSpeed /
        state.flightSpeed.clamp(0.5, double.infinity)).clamp(0.5, 3.0);
    displayAoa = (state.flightPitchAngle * ratio).clamp(_kAoaMin, _kAoaMax);
  }

  final stalling = state.isStalling;
  final ms       = stalling ? DateTime.now().millisecondsSinceEpoch : 0;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Label row — matches _FpsLabel style exactly
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text('AOA',
          style: TextStyle(
            color: stalling ? _kRed : _kShelf,
            fontSize: 8, letterSpacing: 1.5)),
      ),
      // Dial — same 120×120 SizedBox as FireProximitySensor
      SizedBox(
        width: 120, height: 120,
        child: CustomPaint(
          painter: _AoaPainter(aoa: displayAoa, stalling: stalling, ms: ms),
        ),
      ),
    ],
  );
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AoaPainter extends CustomPainter {
  final double aoa;
  final bool   stalling;
  final int    ms;

  const _AoaPainter({required this.aoa, required this.stalling, required this.ms});

  double _toAngle(double a) =>
      _kArcStart + ((a - _kAoaMin) / _kAoaRange).clamp(0.0, 1.0) * _kArcSweep;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 5.0; // = 55 — matches _FpsPainter radius

    // Background gradient (same as FPS)
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFF0D1F35), _kBg],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Range rings (same fraction/style as FPS)
    final ringPaint = Paint()
        ..color = _kShelf.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
    for (final frac in const [0.33, 0.66]) {
      canvas.drawCircle(Offset(cx, cy), r * frac, ringPaint);
    }

    // Zone arcs — green / amber / red
    final arcRect    = Rect.fromCircle(center: Offset(cx, cy), radius: r - 3.0);
    const aw         = 10.0;
    final greenSweep = ((_kCaution - _kAoaMin) / _kAoaRange) * _kArcSweep;
    final amberSweep = ((_kDanger  - _kCaution) / _kAoaRange) * _kArcSweep;
    final redSweep   = ((_kAoaMax  - _kDanger)  / _kAoaRange) * _kArcSweep;

    canvas.drawArc(arcRect, _kArcStart,          greenSweep, false,
        Paint()..color = _kGreen.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke..strokeWidth = aw);
    canvas.drawArc(arcRect, _toAngle(_kCaution), amberSweep, false,
        Paint()..color = _kAmber.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke..strokeWidth = aw);
    canvas.drawArc(arcRect, _toAngle(_kDanger),  redSweep,   false,
        Paint()..color = _kRed.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke..strokeWidth = aw);

    // Tick marks at keypoints
    final tickPaint = Paint()..color = _kDim..strokeWidth = 1.5;
    for (final t in const [-15.0, 0.0, _kCaution, _kDanger, _kAoaMax]) {
      final a = _toAngle(t);
      canvas.drawLine(
        Offset(cx + math.cos(a) * (r - 20), cy + math.sin(a) * (r - 20)),
        Offset(cx + math.cos(a) * (r -  8), cy + math.sin(a) * (r -  8)),
        tickPaint,
      );
    }

    // Zero-crossing marker — brighter, slightly longer
    final za = _toAngle(0.0);
    canvas.drawLine(
      Offset(cx + math.cos(za) * (r - 22), cy + math.sin(za) * (r - 22)),
      Offset(cx + math.cos(za) * (r -  6), cy + math.sin(za) * (r -  6)),
      Paint()..color = _kNeedle.withValues(alpha: 0.45)..strokeWidth = 2.0,
    );

    // Needle — pulses red when stalling
    final na   = _toAngle(aoa);
    final puls = stalling ? 0.7 + 0.3 * math.sin(ms / 200.0) : 1.0;
    final nc   = stalling ? _kRed.withValues(alpha: puls) : _kNeedle;
    canvas.drawLine(
      Offset(cx - math.cos(na) * 9.0,       cy - math.sin(na) * 9.0),
      Offset(cx + math.cos(na) * (r - 16),  cy + math.sin(na) * (r - 16)),
      Paint()..color = nc..strokeWidth = 3.0..strokeCap = StrokeCap.round,
    );

    // Centre pivot hub
    canvas.drawCircle(Offset(cx, cy), 6.0,
        Paint()..color = const Color(0xFF334455));
    canvas.drawCircle(Offset(cx, cy), 6.0,
        Paint()..color = _kNeedle.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Centre readout (AoA value inside the dial, like HullIntegrityArc)
    final zoneColor = aoa >= _kDanger ? _kRed
        : aoa >= _kCaution ? _kAmber
        : _kGreen;
    _text(canvas,
        '${aoa >= 0 ? '+' : ''}${aoa.toStringAsFixed(1)}°',
        Offset(cx, cy - 9), zoneColor, 13, bold: true);
    _text(canvas, 'AOA', Offset(cx, cy + 10), _kShelf, 9);

    // Outer border — kIceShelf 1.5 px stroke, same as FPS
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = _kShelf..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _text(Canvas canvas, String s, Offset pos, Color color, double sz,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(
        color: color, fontSize: sz,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_AoaPainter o) =>
      o.aoa != aoa || o.stalling != stalling || (stalling && o.ms != ms);
}
