import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'hud_gauges.dart';

// ── Mana Arc ──────────────────────────────────────────────────────────────────

/// 270° segmented arc gauge for the player's primary resource (default: "MANA").
///
/// Layout matches buildAoaIndicator: small header label + 120×120 circular dial.
/// Status lights (IceFighter only) are drawn vertically in the arc centre.
class ManaArc extends StatelessWidget {
  final GameState state;
  final String    resourceLabel;

  const ManaArc({super.key, required this.state, this.resourceLabel = 'MANA'});

  @override
  Widget build(BuildContext context) {
    final frac       = (state.mana / GameState.maxMana).clamp(0.0, 1.0);
    final probeAvail = state.aircraftId == 'icefighter';
    final tanking    = probeAvail && state.probeConnected;
    final ready      = probeAvail && state.probeProgress > 0.90
                       && !state.probeMoving && !tanking;
    final full       = state.mana >= GameState.maxMana - 0.5;
    final nowMs      = DateTime.now().millisecondsSinceEpoch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(resourceLabel,
            style: const TextStyle(
              color: kIceShelf, fontSize: 8, letterSpacing: 1.5)),
        ),
        SizedBox(
          width: 120, height: 120,
          child: CustomPaint(
            painter: _ManaArcPainter(
              fraction:   frac,
              tanking:    tanking,
              ready:      ready,
              full:       full,
              probeAvail: probeAvail,
              nowMs:      nowMs,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

const _kAnnRed = Color(0xFFFF2222); // annunciator red (≤25% mana)
const _kDimLt  = Color(0xFF1C3D5A); // dim label colour for inactive lights

class _ManaArcPainter extends CustomPainter {
  final double fraction;
  final bool   tanking;
  final bool   ready;
  final bool   full;
  final bool   probeAvail;
  final int    nowMs;

  static const int    _segs  = 10;
  static const double _start = math.pi * 0.75;  // 135° — same as HullIntegrityArc
  static const double _total = math.pi * 1.5;   // 270° sweep
  static const double _gap   = 0.05;
  static const double _sweep = (_total - _gap * _segs) / _segs;

  const _ManaArcPainter({
    required this.fraction,
    required this.tanking,
    required this.ready,
    required this.full,
    required this.probeAvail,
    required this.nowMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 5.0; // 55 px — matches AoA / FPS radius

    // Dark background fill — makes the arc segments read as a circular face
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFF0D1F35), const Color(0xFF080C14)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Pulsing outer glow ring during active tanking
    if (tanking) {
      final pulse = (math.sin(nowMs / 400.0) + 1) / 2;
      canvas.drawCircle(Offset(cx, cy), r + 5,
        Paint()
          ..color       = const Color(0xFF00CC44).withValues(alpha: 0.30 + pulse * 0.45)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap   = StrokeCap.round);
    }

    // Segmented arc — colour by mana tier (tanking overrides to glacier blue)
    final filled = (fraction * _segs).ceil().clamp(0, _segs);
    for (int i = 0; i < _segs; i++) {
      final angle = _start + i * (_sweep + _gap);
      final Color col;
      if (i >= filled) {
        col = kPolarNight;
      } else if (tanking) {
        col = kGlacierBlue;        // active flow — always bright blue
      } else if (fraction <= 0.25) {
        col = _kAnnRed;            // ≤25% — critical
      } else if (fraction <= 0.50) {
        col = kHeatAmber;          // >25–50% — caution
      } else {
        col = kManaFill;           // >50% — nominal
      }
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle, _sweep, false,
        Paint()
          ..color       = col
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap   = StrokeCap.butt,
      );
    }

    // Vertical status-light stack in arc centre (IceFighter only)
    if (probeAvail) {
      _drawLight(canvas, cx, cy - 12, 'RDY',  ready,   const Color(0xFF0099FF));
      _drawLight(canvas, cx, cy,      'FLOW',  tanking, const Color(0xFF00CC44));
      _drawLight(canvas, cx, cy + 12, 'FULL',  full,    const Color(0xFFFFAA00));
    }

    // Outer border — kIceShelf 1.5 px stroke, matches AoA / FPS
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = kIceShelf..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawLight(Canvas canvas, double cx, double y,
      String label, bool active, Color color) {
    const w = 28.0, h = 12.0;
    final rect = Rect.fromCenter(center: Offset(cx, y), width: w, height: h);
    if (active) {
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.25));
    }
    canvas.drawRect(rect, Paint()
      ..color      = active ? color : _kDimLt
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(
        color:      active ? color : _kDimLt,
        fontSize:   7,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ManaArcPainter o) =>
      o.fraction   != fraction  ||
      o.tanking    != tanking   ||
      o.ready      != ready     ||
      o.full       != full      ||
      o.probeAvail != probeAvail ||
      o.nowMs      != nowMs;
}
