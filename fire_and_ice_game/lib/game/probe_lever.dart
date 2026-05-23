import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Shared colors (mirror gear_lever palette) ─────────────────────────────────

const _kBg       = Color(0xFF101018);
const _kBevel    = Color(0xFF2A3040);
const _kGreen    = Color(0xFF00CC44);
const _kAmber    = Color(0xFFFFAA00);
const _kDim      = Color(0xFF334455);
const _kLeverBg  = Color(0xFF1A1A28);
const _kLeverBody = Color(0xFF505060);

// ── Indicator light (mirrors gear_lever._light) ────────────────────────────────

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

// ── Probe lever ───────────────────────────────────────────────────────────────

/// IceFighter refueling probe lever.
///
/// Uses an oval handle to distinguish it from the circular gear-lever knob.
/// States: RET (cyan) → MOVE (amber) → OUT (pale blue) → CONN (green).
Widget buildProbeLever(GameState state, {VoidCallback? onTap}) {
  final Color color;
  final String status;

  if (state.probeConnected) {
    color  = _kGreen;
    status = 'CONN';
  } else if (state.probeMoving) {
    color  = _kAmber;
    status = 'MOVE';
  } else if (state.probeProgress > 0.90) {
    color  = const Color(0xFFAADDFF);
    status = 'OUT';
  } else {
    color  = const Color(0xFF00CFFF);
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
          child: Center(child: Text('PROB',
              style: TextStyle(color: _kDim, fontSize: 13,
                  fontWeight: FontWeight.bold, letterSpacing: 1))),
        ),
        SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CustomPaint(
              painter: _ProbeLeverPainter(
                  progress: state.probeProgress, color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Column(children: [
            _light('OUT', state.probeProgress > 0.90 && !state.probeMoving,
                const Color(0xFFAADDFF)),
            const SizedBox(height: 2),
            _light(status, state.probeConnected || state.probeMoving, color),
          ]),
        ),
      ]),
    ),
  );
}

class _ProbeLeverPainter extends CustomPainter {
  final double progress;  // 0 = retracted (up), 1 = extended (down)
  final Color  color;
  const _ProbeLeverPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final trackH = size.height - 16;
    const trackW = 4.0;
    const ovalW  = 30.0;  // wider than the gear circle (r=14 → d=28)
    const ovalH  = 16.0;  // shorter → clearly oval

    final pivotY = ovalH / 2;
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

    // Oval handle — distinguishes probe from gear's circular knob
    final ovalRect = Rect.fromCenter(
        center: Offset(cx, knobY), width: ovalW, height: ovalH);
    const ovalRadius = Radius.circular(7);
    canvas.drawRRect(RRect.fromRectAndRadius(ovalRect, ovalRadius),
        Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawRRect(RRect.fromRectAndRadius(ovalRect, ovalRadius),
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
  bool shouldRepaint(_ProbeLeverPainter o) =>
      o.progress != progress || o.color != color;
}
