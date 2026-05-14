import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _kBg        = Color(0xFF101018);
const _kBevel     = Color(0xFF2A3040);
const _kGreen     = Color(0xFF00CC44);   // gear down / safe
const _kRed       = Color(0xFFDD2222);   // gear up / unsafe
const _kAmber     = Color(0xFFFFAA00);   // in transit
const _kDim       = Color(0xFF334455);
const _kLeverBg   = Color(0xFF1A1A28);
const _kLeverBody = Color(0xFF505060);

/// Landing gear lever widget — clickable, animated, with indicator lights.
///
/// The lever visually moves between UP (retracted) and DOWN (deployed)
/// over [GameState.gearProgress]. Tapping calls [onTap].
Widget buildGearLever(GameState state, {VoidCallback? onTap}) {
  final Color leverColor;
  final String statusLabel;
  if (state.gearMoving) {
    leverColor  = _kAmber;
    statusLabel = 'TRANS';
  } else if (state.gearDeployed) {
    leverColor  = _kGreen;
    statusLabel = 'DOWN';
  } else {
    leverColor  = _kRed;
    statusLabel = 'UP';
  }

  // Lever knob Y: 0 = top (UP), 1 = bottom (DOWN)
  // gearProgress 0 = up, 1 = down → knob moves from top to bottom
  final knobFrac = state.gearProgress;

  return GestureDetector(
    onTap: state.gameMode == GameMode.taxi ? null : onTap,
    child: Container(
      width: 46,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: _kBevel, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          height: 14,
          color: _kDim.withValues(alpha: 0.4),
          child: Center(child: Text('GEAR',
              style: TextStyle(color: _kDim, fontSize: 6.5, fontWeight: FontWeight.bold, letterSpacing: 1))),
        ),
        // Lever slot + knob
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CustomPaint(
              painter: _LeverPainter(progress: knobFrac, color: leverColor),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Status / indicator lights
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Column(children: [
            _light('DN', state.gearDeployed && !state.gearMoving, _kGreen),
            const SizedBox(height: 2),
            _light(statusLabel, state.gearMoving, _kAmber),
          ]),
        ),
      ]),
    ),
  );
}

Widget _light(String label, bool active, Color color) {
  return Container(
    height: 12,
    decoration: BoxDecoration(
      color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
      border: Border.all(color: active ? color : _kDim, width: 1),
    ),
    child: Center(child: Text(label,
        style: TextStyle(
          color: active ? color : _kDim,
          fontSize: 6.5, fontWeight: FontWeight.bold,
        ))),
  );
}

class _LeverPainter extends CustomPainter {
  final double progress; // 0 = up, 1 = down
  final Color color;
  const _LeverPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx      = size.width / 2;
    final trackH  = size.height - 14;
    const trackW  = 4.0;
    const knobR   = 7.0;

    // Pivot point (top centre)
    final pivotY  = knobR;
    // Knob bottom stop
    final stopY   = pivotY + trackH;
    // Current knob Y
    final knobY   = pivotY + trackH * progress;

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - trackW / 2, pivotY, cx + trackW / 2, stopY),
        const Radius.circular(2),
      ),
      Paint()..color = _kLeverBg,
    );

    // Lever arm line from pivot to knob
    canvas.drawLine(
      Offset(cx, pivotY),
      Offset(cx, knobY),
      Paint()..color = _kLeverBody..strokeWidth = 3,
    );

    // Knob (T-handle circle)
    canvas.drawCircle(Offset(cx, knobY), knobR,
        Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, knobY), knobR,
        Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 2);

    // UP / DN labels
    const lblStyle = TextStyle(color: _kDim, fontSize: 7);
    void drawLbl(String txt, double y) {
      final tp = TextPainter(text: TextSpan(text: txt, style: lblStyle), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, y));
    }
    drawLbl('UP', 0);
    drawLbl('DN', size.height - 10);
  }

  @override
  bool shouldRepaint(_LeverPainter o) => o.progress != progress || o.color != color;
}

// ── Flaps lever ───────────────────────────────────────────────────────────────

/// Four-position flaps lever: UP · T/O · APPR · FULL.
///
/// Tapping advances to the next detent. Color codes from clean (cyan) to
/// full extension (red) so the pilot can read flap state at a glance.
Widget buildFlapsLever(GameState state, {VoidCallback? onTap}) {
  const labels  = ['UP', 'T/O', 'APR', 'FUL'];
  const colors  = [
    Color(0xFF00CFFF), // UP   — glacier blue
    Color(0xFF00CC44), // T/O  — green
    Color(0xFFFFAA00), // APPR — amber
    Color(0xFFDD2222), // FULL — red
  ];

  final level  = state.flapsLevel.clamp(0, 3);
  final color  = colors[level];
  final label  = labels[level];

  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: _kBevel, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          height: 14,
          color: _kDim.withValues(alpha: 0.4),
          child: Center(child: Text('FLAP',
              style: TextStyle(color: _kDim, fontSize: 6.5,
                  fontWeight: FontWeight.bold, letterSpacing: 1))),
        ),
        // Lever slot with 4 detent notches
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CustomPaint(
              painter: _FlapsLeverPainter(level: level, color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Status label
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: _light(label, true, color),
        ),
      ]),
    ),
  );
}

class _FlapsLeverPainter extends CustomPainter {
  final int   level; // 0–3
  final Color color;
  const _FlapsLeverPainter({required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    const trackW = 4.0;
    const knobR  = 7.0;
    final trackH = size.height - knobR * 2;

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - trackW / 2, knobR, cx + trackW / 2, knobR + trackH),
        const Radius.circular(2),
      ),
      Paint()..color = _kLeverBg,
    );

    // Detent tick marks (3 internal ticks for 4 positions)
    final tp = Paint()..color = _kDim..strokeWidth = 1.5;
    for (int i = 0; i <= 3; i++) {
      final y = knobR + trackH * (i / 3);
      canvas.drawLine(Offset(cx - 6, y), Offset(cx + 6, y), tp);
    }

    // Knob at current detent
    final knobY = knobR + trackH * (level / 3);
    canvas.drawCircle(Offset(cx, knobY), knobR,
        Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, knobY), knobR,
        Paint()..color = color.withValues(alpha: 0.4)
              ..style = PaintingStyle.stroke..strokeWidth = 2);

    // Labels
    const lblStyle = TextStyle(color: _kDim, fontSize: 7);
    void drawLbl(String txt, double y) {
      final painter = TextPainter(
          text: TextSpan(text: txt, style: lblStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas, Offset(cx - painter.width / 2, y));
    }
    drawLbl('UP',  0);
    drawLbl('FUL', size.height - 10);
  }

  @override
  bool shouldRepaint(_FlapsLeverPainter o) =>
      o.level != level || o.color != color;
}

// ── Throttle gauge (3 display modes) ─────────────────────────────────────────

/// Throttle gauge with mode toggle and optional engine instrument bars.
///
/// Mode 0 (BAR): amber bar + % label.
/// Mode 1 (ENG): amber bar + N1/EGT/N2 instrument bars.
/// Mode 2 (NUM): large percentage number only.
Widget buildThrottleGauge(GameState state, {VoidCallback? onModeToggle}) {
  final mode = state.throttleDisplayMode;
  final pct  = (state.throttle * 100).round();
  const bg   = Color(0xFF0A0A10);
  const bev  = Color(0xFF2A3040);

  if (mode == 2) {
    return GestureDetector(
      onTap: onModeToggle,
      child: Container(
        width: 52,
        decoration: BoxDecoration(color: bg, border: Border.all(color: bev, width: 2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(height: 14, color: const Color(0xFF1A1200).withValues(alpha: 0.5),
            child: const Center(child: Text('THR',
              style: TextStyle(color: Color(0xFF554400), fontSize: 6.5,
                  fontWeight: FontWeight.bold, letterSpacing: 1)))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('$pct',
              style: const TextStyle(color: Color(0xFFFFAA00),
                  fontSize: 26, fontWeight: FontWeight.bold))),
          const Padding(padding: EdgeInsets.only(bottom: 4),
            child: Text('%', style: TextStyle(color: Color(0xFF554400), fontSize: 8))),
        ]),
      ),
    );
  }

  final showEng = mode == 1;
  return Container(
    width: showEng ? 86 : 48,
    decoration: BoxDecoration(color: bg, border: Border.all(color: bev, width: 2)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Header — mode toggle button on left
      Row(children: [
        GestureDetector(
          onTap: onModeToggle,
          child: Container(width: 18, height: 14,
            color: const Color(0xFF111120),
            child: Center(child: Text(showEng ? '≡+' : '≡',
              style: const TextStyle(color: Color(0xFF6688AA), fontSize: 7)))),
        ),
        Expanded(child: Container(height: 14,
          color: const Color(0xFF1A1200).withValues(alpha: 0.5),
          child: const Center(child: Text('THR',
            style: TextStyle(color: Color(0xFF554400), fontSize: 6.5,
                fontWeight: FontWeight.bold, letterSpacing: 1))))),
      ]),
      SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(children: [
            Expanded(child: CustomPaint(
                painter: _ThrottleBarPainter(state.throttle),
                child: const SizedBox.expand())),
            if (showEng) ...[
              const SizedBox(width: 3),
              SizedBox(width: 38, child: CustomPaint(
                  painter: _EngineBarsPainter(
                      n1: state.engineN1, egt: state.engineEgt, n2: state.engineN2),
                  child: const SizedBox.expand())),
            ],
          ]),
        ),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Text('$pct%',
          style: const TextStyle(color: Color(0xFFFFAA00),
              fontSize: 7, fontWeight: FontWeight.bold))),
    ]),
  );
}

class _ThrottleBarPainter extends CustomPainter {
  final double value;
  const _ThrottleBarPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const bg = Color(0xFF1A1200);
    const fg = Color(0xFFFFAA00);
    final fillH = size.height * value;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = bg);
    canvas.drawRect(Rect.fromLTWH(0, size.height - fillH, size.width, fillH), Paint()..color = fg);
    final tp = Paint()..color = const Color(0xFF554400)..strokeWidth = 0.5;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = size.height * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.5, y), tp);
    }
  }

  @override
  bool shouldRepaint(_ThrottleBarPainter o) => o.value != value;
}

/// Three side-by-side vertical bars: N1 (green), EGT (amber), N2 (cyan).
///
/// Each bar changes colour as it enters caution/limit territory.
class _EngineBarsPainter extends CustomPainter {
  final double n1, egt, n2;
  const _EngineBarsPainter({required this.n1, required this.egt, required this.n2});

  static Color _col(double v, double warn, double red) {
    if (v >= red)  return const Color(0xFFFF2222);
    if (v >= warn) return const Color(0xFFFFAA00);
    return const Color(0xFF00CC44);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const labels = ['N1', 'GT', 'N2'];
    final values = [n1, egt, n2];
    final warns  = [0.90, 0.80, 0.95];
    final reds   = [0.97, 0.92, 0.98];
    final bw     = size.width / 3;
    const bg     = Color(0xFF0A100A);
    const lblSt  = TextStyle(color: Color(0xFF446644), fontSize: 6);

    for (int i = 0; i < 3; i++) {
      final x    = bw * i;
      final v    = values[i];
      final fill = size.height * v;
      canvas.drawRect(Rect.fromLTWH(x + 1, 0, bw - 2, size.height), Paint()..color = bg);
      canvas.drawRect(
        Rect.fromLTWH(x + 1, size.height - fill, bw - 2, fill),
        Paint()..color = _col(v, warns[i], reds[i]),
      );
      // Limit line
      final limitY = size.height * (1 - reds[i]);
      canvas.drawLine(Offset(x + 1, limitY), Offset(x + bw - 1, limitY),
          Paint()..color = const Color(0xFF882222)..strokeWidth = 0.8);
      // Label
      final tp = TextPainter(
          text: TextSpan(text: labels[i], style: lblSt), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x + (bw - tp.width) / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_EngineBarsPainter o) =>
      o.n1 != n1 || o.egt != egt || o.n2 != n2;
}
