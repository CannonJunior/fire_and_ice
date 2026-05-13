import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

const _kBevel = Color(0xFF30303C);

Widget buildAttitudeGyro(GameState state) {
  return Container(
    width: 180,
    decoration: BoxDecoration(
      color: const Color(0xFF000810),
      border: Border.all(color: _kBevel, width: 2),
    ),
    child: Column(children: [
      Container(
        height: 16,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFF0D1F33).withValues(alpha: 0.7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('ATTITUDE GYR',
              style: TextStyle(color: Color(0xFF4477AA), fontSize: 7, letterSpacing: 1)),
          Text(
            'P:${state.flightPitchAngle.toStringAsFixed(0)}°'
            '  B:${state.flightBankAngle.toStringAsFixed(0)}°',
            style: const TextStyle(color: Color(0xFF335566), fontSize: 7),
          ),
        ]),
      ),
      SizedBox(
        height: 86,
        child: ClipRect(child: CustomPaint(
          painter: _AttitudeGyroPainter(
            pitch: state.flightPitchAngle,
            bank:  state.flightBankAngle,
          ),
          child: const SizedBox.expand(),
        )),
      ),
    ]),
  );
}

class _AttitudeGyroPainter extends CustomPainter {
  final double pitch, bank;
  const _AttitudeGyroPainter({required this.pitch, required this.bank});

  static const _kSky    = Color(0xFF060F1C);
  static const _kGround = Color(0xFF1B0C00);
  static const _kHzLine = Color(0xFFDDDDDD);
  static const _kLadder = Color(0xFF5577AA);
  static const _kWings  = Color(0xFFFFAA00);
  static const _kArc    = Color(0xFF3A4A58);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    const pixPerDeg = 1.7;
    final pitchPx = pitch * pixPerDeg;
    final bankRad = bank * math.pi / 180;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.save();
    canvas.translate(cx, cy + pitchPx);
    canvas.rotate(-bankRad);

    final fill = size.width * 4;
    canvas.drawRect(Rect.fromLTRB(-fill, -fill, fill, 0), Paint()..color = _kSky);
    canvas.drawRect(Rect.fromLTRB(-fill, 0, fill, fill), Paint()..color = _kGround);
    canvas.drawLine(Offset(-fill, 0), Offset(fill, 0),
        Paint()..color = _kHzLine..strokeWidth = 1.5);

    final lp = Paint()..color = _kLadder..strokeWidth = 1;
    for (int d = -30; d <= 30; d += 10) {
      if (d == 0) continue;
      final y  = -d * pixPerDeg;
      final hw = d.abs() == 20 ? 26.0 : 17.0;
      canvas.drawLine(Offset(-hw, y), Offset(-5, y), lp);
      canvas.drawLine(Offset(  5, y), Offset(hw, y), lp);
      final tick = d > 0 ? 4.0 : -4.0;
      canvas.drawLine(Offset(-hw, y), Offset(-hw, y + tick), lp);
      canvas.drawLine(Offset( hw, y), Offset( hw, y + tick), lp);
    }

    canvas.restore();

    final wp = Paint()..color = _kWings..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx - 7, cy), wp);
    canvas.drawLine(Offset(cx -  7, cy), Offset(cx - 7, cy + 5), wp);
    canvas.drawLine(Offset(cx +  7, cy), Offset(cx + 30, cy), wp);
    canvas.drawLine(Offset(cx +  7, cy), Offset(cx + 7, cy + 5), wp);
    canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = _kWings..style = PaintingStyle.fill);

    const arcR = 42.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
      -math.pi * 0.85, math.pi * 0.7, false,
      Paint()..color = _kArc..strokeWidth = 0.75..style = PaintingStyle.stroke,
    );

    for (final d in [-60, -45, -30, -20, -10, 10, 20, 30, 45, 60]) {
      final a     = -math.pi / 2 + d * math.pi / 180;
      final major = d.abs() % 30 == 0;
      final inner = arcR - (major ? 7.0 : 4.0);
      canvas.drawLine(
        Offset(cx + math.cos(a) * inner, cy + math.sin(a) * inner),
        Offset(cx + math.cos(a) * arcR,  cy + math.sin(a) * arcR),
        Paint()..color = _kArc..strokeWidth = major ? 1.0 : 0.5,
      );
    }

    final pa   = -math.pi / 2 + bankRad;
    final tip  = Offset(cx + math.cos(pa) * (arcR - 2), cy + math.sin(pa) * (arcR - 2));
    final perp = pa + math.pi / 2;
    final back = pa + math.pi;
    final tri  = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + math.cos(perp) * 3.5 + math.cos(back) * 7,
               tip.dy + math.sin(perp) * 3.5 + math.sin(back) * 7)
      ..lineTo(tip.dx - math.cos(perp) * 3.5 + math.cos(back) * 7,
               tip.dy - math.sin(perp) * 3.5 + math.sin(back) * 7)
      ..close();
    canvas.drawPath(tri, Paint()..color = _kWings..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_AttitudeGyroPainter o) => o.pitch != pitch || o.bank != bank;
}
