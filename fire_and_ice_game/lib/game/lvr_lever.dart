import 'package:flutter/material.dart';
import 'game_state.dart';

const _kBg        = Color(0xFF101018);
const _kBevel     = Color(0xFF2A3040);
const _kOn        = Color(0xFF00CC44);
const _kOff       = Color(0xFF334455);
const _kDim       = Color(0xFF334455);
const _kLeverBg   = Color(0xFF1A1A28);
const _kLeverBody = Color(0xFF505060);

/// LVR — generic two-position lever (OFF / ON). Tapping toggles state.
Widget buildLvrLever(GameState state, {VoidCallback? onTap}) {
  final bool on    = state.lvrOn;
  final Color color = on ? _kOn : _kOff;

  // Knob: 0.0 = top (OFF), 1.0 = bottom (ON)
  final double knobFrac = on ? 1.0 : 0.0;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
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
          child: Center(child: Text('LVR',
              style: TextStyle(color: _kDim, fontSize: 13,
                  fontWeight: FontWeight.bold, letterSpacing: 1))),
        ),
        SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CustomPaint(
              painter: _LvrPainter(progress: knobFrac, color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: _light(on ? 'ON' : 'OFF', on, _kOn),
        ),
      ]),
    ),
  );
}

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

class _LvrPainter extends CustomPainter {
  final double progress; // 0 = OFF (top), 1 = ON (bottom)
  final Color  color;
  const _LvrPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final trackH = size.height - 14;
    const trackW = 4.0;
    const knobR  = 14.0;

    final pivotY = knobR;
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

    // Detent notches at top and bottom
    final tickPaint = Paint()..color = _kDim..strokeWidth = 1.5;
    for (final y in [pivotY, stopY]) {
      canvas.drawLine(Offset(cx - 12, y), Offset(cx + 12, y), tickPaint);
    }

    // Arm line from pivot to knob
    canvas.drawLine(
      Offset(cx, pivotY), Offset(cx, knobY),
      Paint()..color = _kLeverBody..strokeWidth = 3,
    );

    // Diamond-shaped knob (distinguishes LVR from circular gear and oval probe)
    final path = Path()
      ..moveTo(cx, knobY - knobR)
      ..lineTo(cx + knobR * 0.75, knobY)
      ..lineTo(cx, knobY + knobR)
      ..lineTo(cx - knobR * 0.75, knobY)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(path,
        Paint()..color = color.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke..strokeWidth = 2);

    // OFF / ON labels
    const lblStyle = TextStyle(color: _kDim, fontSize: 14);
    void drawLbl(String txt, double y) {
      final tp = TextPainter(
          text: TextSpan(text: txt, style: lblStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, y));
    }
    drawLbl('OFF', 0);
    drawLbl('ON',  size.height - 20);
  }

  @override
  bool shouldRepaint(_LvrPainter o) => o.progress != progress || o.color != color;
}
