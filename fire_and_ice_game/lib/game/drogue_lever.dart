import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Shared colors (mirror probe_lever palette) ────────────────────────────────

const _kBg        = Color(0xFF101018);
const _kBevel     = Color(0xFF2A3040);
const _kGreen     = Color(0xFF00CC44);
const _kAmber     = Color(0xFFFFAA00);
const _kDim       = Color(0xFF334455);
const _kLeverBg   = Color(0xFF1A1A28);
const _kLeverBody = Color(0xFF505060);

// ── Indicator light ────────────────────────────────────────────────────────────

Widget _light(String label, bool active, Color color) {
  return Container(
    height: 24,
    decoration: BoxDecoration(
      color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
      border: Border.all(color: active ? color : _kDim, width: 1),
    ),
    child: Center(child: Text(label,
        style: TextStyle(
          color: active ? color : _kDim,
          fontSize: 13, fontWeight: FontWeight.bold,
        ))),
  );
}

// ── Drogue lever ──────────────────────────────────────────────────────────────

/// SkyTanker drogue-basket lever.
///
/// Uses a diamond handle to distinguish it from the probe (oval) and gear (circle).
/// States: RET (teal) → MOVE (amber) → OUT (orange) → CONN (green).
Widget buildDrogueLever(GameState state, {VoidCallback? onTap}) {
  final Color color;
  final String status;

  if (state.drogueConnected) {
    color  = _kGreen;
    status = 'CONN';
  } else if (state.drogueMoving) {
    color  = _kAmber;
    status = 'MOVE';
  } else if (state.drogueProgress > 0.90) {
    color  = const Color(0xFFFF8800);
    status = 'OUT';
  } else {
    color  = const Color(0xFF00BBCC);
    status = 'RET';
  }

  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 92,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: _kBevel, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 28,
          color: _kDim.withValues(alpha: 0.4),
          child: Center(child: Text('DROG',
              style: TextStyle(color: _kDim, fontSize: 13,
                  fontWeight: FontWeight.bold, letterSpacing: 1))),
        ),
        SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CustomPaint(
              painter: _DrogueLeverPainter(
                  progress: state.drogueProgress, color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Column(children: [
            _light('OUT', state.drogueProgress > 0.90 && !state.drogueMoving,
                const Color(0xFFFF8800)),
            const SizedBox(height: 2),
            _light(status, state.drogueConnected || state.drogueMoving, color),
          ]),
        ),
      ]),
    ),
  );
}

class _DrogueLeverPainter extends CustomPainter {
  final double progress;  // 0 = retracted (up), 1 = extended (down)
  final Color  color;
  const _DrogueLeverPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final trackH = size.height - 16;
    const trackW = 4.0;
    const diamondW = 22.0;
    const diamondH = 22.0;

    final pivotY = diamondH / 2;
    final stopY  = pivotY + trackH;
    final knobY  = pivotY + trackH * progress;

    // Track slot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - trackW / 2, pivotY, cx + trackW / 2, stopY),
        const Radius.circular(2),
      ),
      Paint()..color = _kLeverBg,
    );

    // Arm line
    canvas.drawLine(
      Offset(cx, pivotY), Offset(cx, knobY),
      Paint()..color = _kLeverBody..strokeWidth = 3,
    );

    // Diamond handle — distinguishes drogue from probe (oval) and gear (circle)
    final path = Path()
      ..moveTo(cx, knobY - diamondH / 2)
      ..lineTo(cx + diamondW / 2, knobY)
      ..lineTo(cx, knobY + diamondH / 2)
      ..lineTo(cx - diamondW / 2, knobY)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(path,
        Paint()
          ..color      = color.withValues(alpha: 0.45)
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 2);

    // RET / OUT labels
    const lblStyle = TextStyle(color: _kDim, fontSize: 14);
    void drawLbl(String txt, double y) {
      final tp = TextPainter(
          text: TextSpan(text: txt, style: lblStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, y));
    }
    drawLbl('RET', 0);
    drawLbl('OUT', size.height - 20);
  }

  @override
  bool shouldRepaint(_DrogueLeverPainter o) =>
      o.progress != progress || o.color != color;
}
