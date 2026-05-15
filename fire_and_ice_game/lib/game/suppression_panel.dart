import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── F-35-style suppression control panel ─────────────────────────────────────
//
// Inspired by the F-35 simulator center console: a row of ARM/SAFE/AUTO/MAN
// toggle switches (each with an indicator LED) above three rotary knobs.
//
//  ARM  | SAFE  ||  AUTO | MAN       ← guarded toggle switches
//  ⊙RETR  ⊙RNG   ⊙SENS              ← rotary detent knobs (4 positions each)
//
// ARM/SAFE control the suppression-system arm state (mutually exclusive).
// AUTO/MAN control the drop mode (mutually exclusive).
// RETR = retardant concentration, RNG = drop-zone radius, SENS = thermal gain.

Widget buildSuppressionPanel(GameState state, {
  VoidCallback? onSuppArm,
  VoidCallback? onSuppAuto,
  VoidCallback? onRetardantKnob,
  VoidCallback? onRangeKnob,
  VoidCallback? onSensorKnob,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
    decoration: BoxDecoration(
      color: const Color(0xFF080810),
      border: Border.all(color: const Color(0xFF1E1E2E), width: 1),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Mode switches: ARM | SAFE   AUTO | MAN ──
      Row(mainAxisSize: MainAxisSize.min, children: [
        _panelSwitch('ARM',  state.suppressionArmed,  const Color(0xFF00EE44), onTap: onSuppArm),
        const SizedBox(width: 2),
        _panelSwitch('SAFE', !state.suppressionArmed, const Color(0xFFFF3333), onTap: onSuppArm),
        const SizedBox(width: 5),
        _panelSwitch('AUTO', state.suppressionAuto,   const Color(0xFFFFAA00), onTap: onSuppAuto),
        const SizedBox(width: 2),
        _panelSwitch('MAN',  !state.suppressionAuto,  const Color(0xFF4499FF), onTap: onSuppAuto),
      ]),
      const SizedBox(height: 5),
      // ── Rotary knobs: RETR · RNG · SENS ──
      Row(mainAxisSize: MainAxisSize.min, children: [
        _knobControl('RETR', state.retardantLevel, onTap: onRetardantKnob),
        const SizedBox(width: 5),
        _knobControl('RNG',  state.dropRange,       onTap: onRangeKnob),
        const SizedBox(width: 5),
        _knobControl('SENS', state.sensorGain,      onTap: onSensorKnob),
      ]),
    ]),
  );
}

// ── Toggle switch with indicator LED ─────────────────────────────────────────

Widget _panelSwitch(String label, bool active, Color activeCol, {VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 6,
        color: active ? activeCol : const Color(0xFF181820),
      ),
      const SizedBox(height: 1),
      Container(
        width: 52, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF111118),
          border: Border.all(
            color: active ? activeCol.withValues(alpha: 0.55) : const Color(0xFF252535),
            width: 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: activeCol.withValues(alpha: 0.20), blurRadius: 4)]
              : null,
        ),
        child: Center(child: Text(
          label,
          style: TextStyle(
            color: active ? activeCol : const Color(0xFF3A3A55),
            fontSize: 11, fontWeight: FontWeight.bold,
          ),
        )),
      ),
    ]),
  );
}

// ── Rotary knob (4-position detent) ──────────────────────────────────────────

Widget _knobControl(String label, int position, {VoidCallback? onTap}) {
  const posLabel = ['25%', '50%', '75%', 'MAX'];
  return GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 60, height: 60,
        child: CustomPaint(painter: _KnobPainter(position: position)),
      ),
      const SizedBox(height: 1),
      Text(label, style: const TextStyle(
          color: Color(0xFF445566), fontSize: 11, fontWeight: FontWeight.bold)),
      Text(posLabel[position], style: const TextStyle(
          color: Color(0xFF5577AA), fontSize: 10)),
    ]),
  );
}

class _KnobPainter extends CustomPainter {
  final int position; // 0–3
  const _KnobPainter({required this.position});

  // Detent angles: 7-o'clock → 5-o'clock arc (standard control knob range)
  static const _angles = [-135.0, -45.0, 45.0, 135.0];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 1;

    // Body fill
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF0C0C18));
    // Chrome outer ring
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = const Color(0xFF383858)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    // Inner knob face
    canvas.drawCircle(Offset(cx, cy), r - 4,
        Paint()..color = const Color(0xFF161622));

    // Detent tick marks (4 positions)
    for (int i = 0; i < 4; i++) {
      final a      = _angles[i] * math.pi / 180.0;
      final active = i == position;
      canvas.drawLine(
        Offset(cx + math.cos(a) * (r - 1), cy + math.sin(a) * (r - 1)),
        Offset(cx + math.cos(a) * (r - 5), cy + math.sin(a) * (r - 5)),
        Paint()
          ..color = active ? const Color(0xFF0099DD) : const Color(0xFF2A2A42)
          ..strokeWidth = active ? 2.0 : 1.0,
      );
    }

    // Pointer line to active detent
    final rad = _angles[position] * math.pi / 180.0;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(rad) * (r - 7), cy + math.sin(rad) * (r - 7)),
      Paint()
        ..color = const Color(0xFF00AAFF)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    // Hub dot
    canvas.drawCircle(Offset(cx, cy), 2.5,
        Paint()..color = const Color(0xFF3366AA));
  }

  @override
  bool shouldRepaint(_KnobPainter o) => o.position != position;
}
