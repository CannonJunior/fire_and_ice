import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/abilities.dart';
import 'game_state.dart';

// ── Colors (green phosphor — matches left MFD) ────────────────────────────────

const _kFg    = Color(0xFF00FF41);
const _kDim   = Color(0xFF005519);
const _kAmber = Color(0xFFFFB300);
const _kWarn  = Color(0xFFFF4400);

// ── Public entry ──────────────────────────────────────────────────────────────

/// Aircraft stores-management display.
///
/// Top view of the aircraft silhouette with expendable stores on wing pylons
/// and rechargeable systems indicated inside the fuselage bay.
/// Inspired by the F-35 SMS (Stores Management System) display.
Widget buildLoadoutPage(GameState state) {
  final expendable = state.abilities.where((a) => a.isExpendable).toList();
  final recharge   = state.abilities.where((a) => !a.isExpendable).toList();
  final totalLeft  = expendable.fold(0, (s, a) => s + (state.abilityCharges[a.name] ?? a.maxCharges));
  final totalMax   = expendable.fold(0, (s, a) => s + a.maxCharges);
  final armed      = state.suppressionArmed;

  return Column(children: [
    _header(),
    Expanded(child: CustomPaint(
      painter: _LoadoutPainter(state: state, expendable: expendable, recharge: recharge),
      child: Container(),
    )),
    _footer(totalLeft, totalMax, armed, state),
  ]);
}

Widget _header() {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: _kDim.withValues(alpha: 0.4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('STORES MANAGEMENT', style: const TextStyle(color: _kFg, fontSize: 18, letterSpacing: 1)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        color: _kFg.withValues(alpha: 0.2),
        child: const Text('LOAD', style: TextStyle(color: _kFg, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

Widget _footer(int totalLeft, int totalMax, bool armed, GameState state) {
  final armCol  = armed ? _kWarn : _kDim;
  final armText = armed ? 'ARMED' : 'SAFE ';
  final retrLbl = const ['25%', '50%', '75%', 'MAX'][state.retardantLevel];
  return Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: _kDim.withValues(alpha: 0.3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('SUPR:$armText', style: TextStyle(color: armCol, fontSize: 16, fontWeight: FontWeight.bold)),
      Text('STORES:$totalLeft/$totalMax', style: const TextStyle(color: _kFg, fontSize: 8)),
      Text('RETR:$retrLbl', style: const TextStyle(color: _kDim, fontSize: 8)),
    ]),
  );
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _LoadoutPainter extends CustomPainter {
  final GameState        state;
  final List<AbilityData> expendable;
  final List<AbilityData> recharge;
  const _LoadoutPainter({required this.state, required this.expendable, required this.recharge});

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final top = 6.0;
    final ws  = size.width * 0.40; // half-wingspan in pixels

    _drawAircraft(canvas, cx, top, ws);
    _drawInternalBay(canvas, cx, top);
    _drawPylonStations(canvas, cx, top, ws);
  }

  // ── Aircraft silhouette ───────────────────────────────────────────────────

  void _drawAircraft(Canvas canvas, double cx, double top, double ws) {
    final path = Path()
      ..moveTo(cx,        top +   6)   // nose tip
      ..lineTo(cx + 10,   top +  22)
      ..lineTo(cx + ws,   top +  72)   // right wing tip
      ..lineTo(cx + ws * 0.74, top + 96)
      ..lineTo(cx + 19,   top + 110)
      ..lineTo(cx + 22,   top + 126)   // right tail fin
      ..lineTo(cx + 12,   top + 138)
      ..lineTo(cx,        top + 143)   // tail centre
      ..lineTo(cx - 12,   top + 138)
      ..lineTo(cx - 22,   top + 126)
      ..lineTo(cx - 19,   top + 110)
      ..lineTo(cx - ws * 0.74, top + 96)
      ..lineTo(cx - ws,   top +  72)
      ..lineTo(cx - 10,   top +  22)
      ..close();

    canvas.drawPath(path, Paint()
      ..color = _kDim.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = _kDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    // Cockpit canopy outline
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, top + 28), width: 11, height: 20),
      Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.5,
    );
  }

  // ── Internal rechargeable bay ────────────────────────────────────────────

  void _drawInternalBay(Canvas canvas, double cx, double top) {
    final bayRect = Rect.fromCenter(center: Offset(cx, top + 72), width: 13, height: 42);
    canvas.drawRect(bayRect, Paint()
      ..color = _kDim.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill);

    // One slot per rechargeable ability
    for (int i = 0; i < math.min(recharge.length, 5); i++) {
      final ab  = recharge[i];
      final cd  = state.abilityCooldowns[ab.name] ?? 0.0;
      final rdy = cd <= 0.0;
      final slotY = top + 54 + i * 8.5;
      canvas.drawRect(
        Rect.fromLTWH(cx - 4.5, slotY, 9, 6),
        Paint()..color = (rdy ? _kFg : _kAmber).withValues(alpha: 0.35)..style = PaintingStyle.fill,
      );
    }

    _tp(canvas, 'SYS', cx, top + 46, _kDim, 5.5, center: true);
  }

  // ── Wing pylon stations ──────────────────────────────────────────────────

  void _drawPylonStations(Canvas canvas, double cx, double top, double ws) {
    // Four stations: left-outer, left-inner, right-inner, right-outer
    final stations = [
      (cx - ws * 0.74, top + 66.0, 0),
      (cx - ws * 0.44, top + 58.0, 1),
      (cx + ws * 0.44, top + 58.0, 2),
      (cx + ws * 0.74, top + 66.0, 3),
    ];

    for (final (sx, sy, si) in stations) {
      if (si >= expendable.length) {
        _drawEmptyStation(canvas, sx, sy);
      } else {
        final ab      = expendable[si];
        final charges = state.abilityCharges[ab.name] ?? ab.maxCharges;
        final cd      = state.abilityCooldowns[ab.name] ?? 0.0;
        final rdy     = charges > 0 && cd <= 0.0;
        _drawStore(canvas, sx, sy, ab, charges, rdy);
      }
    }
  }

  void _drawStore(Canvas canvas, double sx, double sy, AbilityData ab, int charges, bool rdy) {
    final col = charges <= 0 ? _kWarn : (rdy ? _kFg : _kAmber);

    // Pylon arm
    canvas.drawLine(Offset(sx - 3, sy), Offset(sx + 3, sy),
        Paint()..color = _kDim..strokeWidth = 0.5);

    // Store body (missile/pod shape)
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(sx, sy + 12), width: 7, height: 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()
      ..color = col.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill);
    canvas.drawRRect(body, Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);

    // Fin at rear
    canvas.drawLine(Offset(sx - 4, sy + 19), Offset(sx + 4, sy + 19),
        Paint()..color = col..strokeWidth = 0.8);

    // Charge count above store
    final label = charges <= 0 ? 'X' : '$charges';
    _tp(canvas, label, sx, sy - 3, col, 7.5, center: true, bold: true);

    // Abbreviated ability label below
    final abbr = ab.name.split(' ').map((w) => w[0]).join();
    _tp(canvas, abbr, sx, sy + 26, _kDim, 5.5, center: true);
  }

  void _drawEmptyStation(Canvas canvas, double sx, double sy) {
    canvas.drawLine(Offset(sx - 3, sy), Offset(sx + 3, sy),
        Paint()..color = _kDim.withValues(alpha: 0.4)..strokeWidth = 0.5);
    _tp(canvas, '──', sx, sy + 12, _kDim.withValues(alpha: 0.4), 7.0, center: true);
  }

  // ── Text helper ──────────────────────────────────────────────────────────

  void _tp(Canvas canvas, String text, double x, double y, Color color,
      double fontSize, {bool center = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? x - tp.width / 2 : x;
    tp.paint(canvas, Offset(dx, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_LoadoutPainter o) => true;
}
