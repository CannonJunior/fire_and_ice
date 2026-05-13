import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Design tokens (HUD_DESIGN_RESEARCH.md §8) ─────────────────────────────────
const Color kGlacierBlue = Color(0xFF00CFFF);
const Color kArcticCyan  = Color(0xFF00EEFF);
const Color kAbyssNavy   = Color(0xFF050A14);
const Color kPolarNight  = Color(0xFF0A1F3A);
const Color kIceShelf    = Color(0xFF1C3D5A);
const Color kFrostWhite  = Color(0xFFE8F4FF);
const Color kManaFill    = Color(0xFF3AB7FF);
const Color kXpPurple    = Color(0xFF7C4DFF);
const Color kEmber       = Color(0xFFFF6420);
const Color kDanger      = Color(0xFFFF2200);
const Color kHeatAmber   = Color(0xFFFFA020);
const Color kHullWarn    = Color(0xFF9966FF);
const Color kHullCrit    = Color(0xFFFF6644);
const Color kColdViolet  = Color(0xFFCC44FF);

// ── Fire Proximity Sensor ─────────────────────────────────────────────────────

/// Circular elemental-threat display — replaces traditional radar.
///
/// [threatLevel] 0–1 drives the outer heat arc and danger ring brightness.
/// [contacts] are normalised positions in -1..1 sensor space (fire elementals).
/// When no enemies exist, threat derives from [GameState.flightAltitude].
class FireProximitySensor extends StatelessWidget {
  final GameState state;
  const FireProximitySensor({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Derive threat from altitude proxy: alt < 10 = danger, > 30 = safe.
    final threat = (1.0 - (state.flightAltitude / 30.0)).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FpsLabel(),
        SizedBox(
          width: 120, height: 120,
          child: CustomPaint(
            painter: _FpsPainter(threat: threat),
          ),
        ),
      ],
    );
  }
}

class _FpsLabel extends StatelessWidget {
  const _FpsLabel();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 4, bottom: 2),
    child: Text('FIRE PROX', style: TextStyle(color: kIceShelf, fontSize: 8, letterSpacing: 1.5)),
  );
}

class _FpsPainter extends CustomPainter {
  final double threat; // 0–1
  const _FpsPainter({required this.threat});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 5;

    // Background
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [const Color(0xFF0D1F35), kAbyssNavy],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Subtle range rings
    final ringPaint = Paint()..color = kIceShelf.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (final frac in [0.33, 0.66]) {
      canvas.drawCircle(Offset(cx, cy), r * frac, ringPaint);
    }

    // Danger proximity ring at 30 %
    final dangerAlpha = 0.25 + threat * 0.5;
    canvas.drawCircle(Offset(cx, cy), r * 0.30,
      Paint()..color = kDanger.withValues(alpha: dangerAlpha)
            ..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Ambient fire signatures — simulated until enemies exist
    if (threat > 0.15) {
      final rng = math.Random(42);
      final count = (threat * 5).ceil().clamp(1, 6);
      for (int i = 0; i < count; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final dist  = 0.35 + rng.nextDouble() * (1.0 - threat) * 0.55;
        final ex    = cx + math.cos(angle) * r * dist;
        final ey    = cy + math.sin(angle) * r * dist;
        final sz    = 2.5 + (1.0 - dist) * 4.0;
        canvas.drawCircle(Offset(ex, ey), sz,
          Paint()..color = kEmber.withValues(alpha: 0.55 + (1 - dist) * 0.35));
        canvas.drawCircle(Offset(ex, ey), sz * 2.2,
          Paint()..color = kEmber.withValues(alpha: 0.12));
      }
    }

    // Player marker — white diamond at centre
    final mp = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, cy - 5)
      ..lineTo(cx + 3, cy)
      ..lineTo(cx, cy + 5)
      ..lineTo(cx - 3, cy)
      ..close();
    canvas.drawPath(path, mp);

    // Outer border
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = kIceShelf..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Heat-intensity arc (270°, clockwise from 135°)
    if (threat > 0.02) {
      final arcRect  = Rect.fromCircle(center: Offset(cx, cy), radius: r + 5);
      final sweep    = math.pi * 1.5 * threat;
      final arcColor = Color.lerp(const Color(0xFF1A6FFF), kDanger, threat)!;
      canvas.drawArc(arcRect, math.pi * 0.75, sweep, false,
        Paint()..color = arcColor..style = PaintingStyle.stroke
              ..strokeWidth = 3..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_FpsPainter o) => o.threat != threat;
}

// ── Hull Integrity Arc ────────────────────────────────────────────────────────

/// 10-segment 270° arc gauge — the ice hull's health display.
///
/// Segments shatter individually; colour shifts blue→purple→orange as health
/// drops.  Specification: HUD_DESIGN_RESEARCH.md §6.
class HullIntegrityArc extends StatelessWidget {
  final GameState state;
  const HullIntegrityArc({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100, height: 88,
      child: CustomPaint(
        painter: _HullPainter(fraction: state.health / GameState.maxHealth),
      ),
    );
  }
}

class _HullPainter extends CustomPainter {
  final double fraction; // 0–1
  static const int    _segs  = 10;
  static const double _start = math.pi * 0.75;      // 135° (7:30 position)
  static const double _total = math.pi * 1.5;        // 270°
  static const double _gap   = 0.05;                 // radians between segments
  static const double _sweep = (_total - _gap * _segs) / _segs;

  const _HullPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final r  = math.min(size.width, size.height) / 2 - 4;

    final filled = (fraction * _segs).ceil().clamp(0, _segs);

    for (int i = 0; i < _segs; i++) {
      final angle = _start + i * (_sweep + _gap);
      final Color col;
      if (i >= filled) {
        col = kPolarNight;
      } else if (fraction > 0.6) {
        col = kGlacierBlue;
      } else if (fraction > 0.3) {
        col = kHullWarn;
      } else {
        col = kHullCrit;
      }

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle, _sweep, false,
        Paint()..color = col..style = PaintingStyle.stroke
              ..strokeWidth = 7..strokeCap = StrokeCap.butt,
      );
    }

    // Centre label
    _drawCentredText(canvas, '${(fraction * 100).toInt()}%', Offset(cx, cy - 6),
        fraction > 0.3 ? kGlacierBlue : kHullCrit, 11, bold: true);
    _drawCentredText(canvas, 'HULL', Offset(cx, cy + 8), kIceShelf, 8);
  }

  void _drawCentredText(Canvas canvas, String text, Offset pos,
      Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HullPainter o) => o.fraction != fraction;
}

// ── Flight Data Cluster ───────────────────────────────────────────────────────

/// Top-left readout: altitude, speed, heading.  Always visible.
class FlightDataCluster extends StatelessWidget {
  final GameState state;
  const FlightDataCluster({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hdg = ((state.playerRotation.y % 360) + 360) % 360;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kAbyssNavy.withValues(alpha: 0.80),
        border: Border.all(color: kIceShelf, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('ALT', '${state.flightAltitude.toStringAsFixed(1)} m'),
          _row('SPD', '${state.flightSpeed.toStringAsFixed(1)} u/s'),
          _row('HDG', '${hdg.toStringAsFixed(0)}°'),
          if (state.flightPitchAngle.abs() > 0.5)
            _row('PCH', '${state.flightPitchAngle.toStringAsFixed(1)}°'),
          if (state.isBarrelRolling)
            const Text('BARREL ROLL',
              style: TextStyle(color: kHeatAmber, fontSize: 9,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 28,
        child: Text(label, style: const TextStyle(color: kIceShelf, fontSize: 9, letterSpacing: 1))),
      Text(value, style: const TextStyle(color: kFrostWhite, fontSize: 10,
          fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    ]),
  );
}

// ── Warning Text Zone ─────────────────────────────────────────────────────────

/// Top-centre flashing warnings — stall, low mana, overheat.
class WarningTextZone extends StatelessWidget {
  final GameState state;
  const WarningTextZone({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final warnings = <String>[];
    if (state.mana < 15)                      warnings.add('LOW MANA');
    if (state.health < 20)                    warnings.add('HULL CRITICAL');
    if (state.flightSpeed < 1.0 && state.flightAltitude > 2) warnings.add('STALL');
    if (state.flightAltitude < 3)             warnings.add('PULL UP');
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: const Alignment(0, -0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: warnings.map((w) => _WarningChip(text: w)).toList(),
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  final String text;
  const _WarningChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: kDanger.withValues(alpha: 0.18),
      border: Border.all(color: kDanger.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text,
      style: const TextStyle(color: kDanger, fontSize: 12,
          fontWeight: FontWeight.bold, letterSpacing: 2)),
  );
}
