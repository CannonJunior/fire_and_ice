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

Widget buildLoadoutPage(GameState state) {
  final expendable = state.abilities.where((a) => a.isExpendable).toList();
  final recharge   = state.abilities.where((a) => !a.isExpendable).toList();

  final overrides = state.currentAircraft.storeCharges;
  final totalLeft = expendable.fold(0, (s, a) =>
      s + (state.abilityCharges[a.name] ?? (overrides[a.name] ?? a.maxCharges)));
  final totalMax  = expendable.fold(0, (s, a) =>
      s + (overrides[a.name] ?? a.maxCharges));
  final armed     = state.suppressionArmed;

  return Column(children: [
    _header(state.currentAircraft.displayName),
    Expanded(child: CustomPaint(
      painter: _LoadoutPainter(state: state, expendable: expendable, recharge: recharge),
      child: Container(),
    )),
    _footer(totalLeft, totalMax, armed, state),
  ]);
}

Widget _header(String aircraftName) {
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

  // Station fill order: inner-left (1), inner-right (2), outer-left (0), outer-right (3).
  static const _stationOrder = [1, 2, 0, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final top = 6.0;
    final ws  = size.width * 0.40;
    final id  = state.currentAircraft.id;

    _drawAircraft(canvas, cx, top, ws, id);
    _drawInternalBay(canvas, cx, top);
    _drawCryoBombColumns(canvas, cx, top);
    _drawPylonStations(canvas, cx, top, ws, id);
  }

  // ── Aircraft silhouette dispatcher ────────────────────────────────────────

  void _drawAircraft(Canvas canvas, double cx, double top, double ws, String id) {
    switch (id) {
      case 'icefighter': _drawIceFighterSil(canvas, cx, top, ws);
      case 'skytanker':  _drawSkyTankerSil(canvas, cx, top, ws);
      default:           _drawFireHawkSil(canvas, cx, top, ws);
    }
  }

  void _sil(Canvas canvas, Path path) {
    canvas.drawPath(path, Paint()
      ..color = _kDim.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = _kDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  // ── IceFighter — slim delta-wing twin-engine interceptor ──────────────────
  //
  // Matches 3-unit fuselage (0.30×0.24 cross-section), 2.10-span delta wing,
  // twin engine nacelles at ±0.42 X, single vertical fin, nose probe.

  void _drawIceFighterSil(Canvas canvas, double cx, double top, double ws) {
    // Main body + delta wing (swept leading edge, blunt trailing)
    final body = Path()
      ..moveTo(cx,           top +   4)   // nose tip
      ..lineTo(cx +  6,      top +  28)   // fuselage right
      ..lineTo(cx + ws*0.88, top +  90)   // delta tip right
      ..lineTo(cx + ws*0.42, top + 104)   // delta trailing right
      ..lineTo(cx + 10,      top + 116)   // rear fuse right
      ..lineTo(cx + 13,      top + 128)   // tail fin right
      ..lineTo(cx +  6,      top + 140)   // tail tip right
      ..lineTo(cx,           top + 144)   // tail center
      ..lineTo(cx -  6,      top + 140)
      ..lineTo(cx - 13,      top + 128)
      ..lineTo(cx - 10,      top + 116)
      ..lineTo(cx - ws*0.42, top + 104)
      ..lineTo(cx - ws*0.88, top +  90)
      ..lineTo(cx -  6,      top +  28)
      ..close();
    _sil(canvas, body);

    // Twin engine nacelles — rectangular bumps flanking fuselage at wing root
    final nacPaint = Paint()
      ..color = _kDim.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final nacStroke = Paint()
      ..color = _kDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final nx in [cx - 16.0, cx + 16.0]) {
      final r = Rect.fromCenter(center: Offset(nx, top + 60), width: 8, height: 24);
      canvas.drawRect(r, nacPaint);
      canvas.drawRect(r, nacStroke);
    }

    // Cockpit canopy
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, top + 22), width: 8, height: 14),
        Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Refueling probe — stub at nose
    canvas.drawLine(Offset(cx, top + 4), Offset(cx, top - 3),
        Paint()..color = _kDim..strokeWidth = 1.2);
  }

  // ── FireHawk — conventional single-engine fighter-bomber ─────────────────
  //
  // Matches 4-unit fuselage (wider 0.68×0.52 belly for retardant tank),
  // swept wings at 0.78 span, single prop at tail.

  void _drawFireHawkSil(Canvas canvas, double cx, double top, double ws) {
    final body = Path()
      ..moveTo(cx,           top +   6)   // nose tip
      ..lineTo(cx + 10,      top +  22)   // fuselage right front
      ..lineTo(cx + ws*0.82, top +  75)   // wing tip right
      ..lineTo(cx + ws*0.55, top +  94)   // wing root right
      ..lineTo(cx + 18,      top + 108)   // belly right (wider for tank)
      ..lineTo(cx + 20,      top + 122)   // tail right
      ..lineTo(cx + 10,      top + 136)   // tail tip right
      ..lineTo(cx,           top + 142)   // tail center
      ..lineTo(cx - 10,      top + 136)
      ..lineTo(cx - 20,      top + 122)
      ..lineTo(cx - 18,      top + 108)
      ..lineTo(cx - ws*0.55, top +  94)
      ..lineTo(cx - ws*0.82, top +  75)
      ..lineTo(cx - 10,      top +  22)
      ..close();
    _sil(canvas, body);

    // Retardant belly pod (distinctive wide belly of FireHawk)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, top + 80), width: 22, height: 48),
      Paint()..color = _kDim.withValues(alpha: 0.20)..style = PaintingStyle.fill);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, top + 80), width: 22, height: 48),
      Paint()..color = _kDim.withValues(alpha: 0.60)..style = PaintingStyle.stroke..strokeWidth = 0.6);

    // Cockpit
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, top + 28), width: 11, height: 20),
        Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Single prop circle at tail
    canvas.drawCircle(Offset(cx, top + 136), 9,
        Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawLine(Offset(cx - 9, top + 136), Offset(cx + 9, top + 136),
        Paint()..color = _kDim..strokeWidth = 0.6);
    canvas.drawLine(Offset(cx, top + 127), Offset(cx, top + 145),
        Paint()..color = _kDim..strokeWidth = 0.6);
  }

  // ── SkyTanker — Leviathan ART-9 four-engine heavy tanker ─────────────────
  //
  // Matches the ART-9 body: 14-unit fuselage (1.8 wide), high-mounted straight
  // wings (±10.5 span), four engine nacelles in pairs, twin vertical fins,
  // drogue hose at tail.

  void _drawSkyTankerSil(Canvas canvas, double cx, double top, double ws) {
    // Wide rectangular fuselage (ART-9 cross-section 1.8×1.4)
    final fuse = Path()
      ..moveTo(cx,      top +   6)   // nose tip
      ..lineTo(cx + 14, top +  20)   // right nose shoulder
      ..lineTo(cx + 14, top + 118)   // right side to tail
      ..lineTo(cx + 18, top + 126)   // right tail fin root
      ..lineTo(cx + 12, top + 138)   // right tail tip
      ..lineTo(cx +  6, top + 143)
      ..lineTo(cx -  6, top + 143)
      ..lineTo(cx - 12, top + 138)
      ..lineTo(cx - 18, top + 126)
      ..lineTo(cx - 14, top + 118)
      ..lineTo(cx - 14, top +  20)
      ..close();
    _sil(canvas, fuse);

    // High-mounted straight wings — thin slab across full span
    final wingY = top + 62.0;
    canvas.drawRect(Rect.fromLTWH(cx - ws, wingY, ws * 2, 12),
        Paint()..color = _kDim.withValues(alpha: 0.22)..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(cx - ws, wingY, ws * 2, 12),
        Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // Four engine nacelles — two pairs flanking fuselage under wings
    // Inner pair at ±ws*0.30, outer pair at ±ws*0.65 (matches ART-9 box positions)
    final nacFill = Paint()..color = _kDim.withValues(alpha: 0.55)..style = PaintingStyle.fill;
    final nacLine = Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.7;
    for (final nx in [cx - ws*0.65, cx - ws*0.30, cx + ws*0.30, cx + ws*0.65]) {
      final r = Rect.fromCenter(center: Offset(nx, wingY + 6), width: 7, height: 20);
      canvas.drawRect(r, nacFill);
      canvas.drawRect(r, nacLine);
    }

    // Twin vertical tail fins
    for (final fx in [cx - 10.0, cx + 10.0]) {
      final r = Rect.fromCenter(center: Offset(fx, top + 130), width: 5, height: 16);
      canvas.drawRect(r, Paint()..color = _kDim.withValues(alpha: 0.5)..style = PaintingStyle.fill);
      canvas.drawRect(r, Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.7);
    }

    // Cockpit glazing — small strip on nose
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, top + 24), width: 18, height: 8),
        Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Drogue hose trailing from tail
    canvas.drawLine(Offset(cx, top + 143), Offset(cx, top + 158),
        Paint()..color = _kDim.withValues(alpha: 0.7)..strokeWidth = 1.5);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, top + 162), width: 6, height: 6),
      Paint()..color = _kDim..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  // ── Internal rechargeable bay ─────────────────────────────────────────────

  void _drawInternalBay(Canvas canvas, double cx, double top) {
    final bayRect = Rect.fromCenter(center: Offset(cx, top + 72), width: 13, height: 42);
    canvas.drawRect(bayRect, Paint()
      ..color = _kDim.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill);

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

  // ── Cryo Bomb centerline columns ──────────────────────────────────────────

  void _drawCryoBombColumns(Canvas canvas, double cx, double top) {
    final abIdx = expendable.indexWhere((a) => a.name == 'Cryo Bomb');
    if (abIdx < 0) return;

    final ab        = expendable[abIdx];
    final overrides = state.currentAircraft.storeCharges;
    final maxChrg   = overrides[ab.name] ?? ab.maxCharges;
    final charges   = state.abilityCharges[ab.name] ?? maxChrg;
    if (maxChrg == 0) return;

    final leftCount  = (maxChrg + 1) ~/ 2;
    final rightCount = maxChrg ~/ 2;

    final leftX  = cx - 11.0;
    final rightX = cx + 11.0;
    const startY = 50.0;
    const stepY  = 11.5;

    for (int li = 0; li < leftCount; li++) {
      _drawBomb(canvas, leftX, top + startY + li * stepY, li * 2 < charges);
    }
    for (int ri = 0; ri < rightCount; ri++) {
      _drawBomb(canvas, rightX, top + startY + ri * stepY, ri * 2 + 1 < charges);
    }

    _tp(canvas, 'CB', cx, top + startY - 9, _kDim, 5.5, center: true);

    final rows   = math.max(leftCount, rightCount);
    final countY = top + startY + rows * stepY + 2;
    _tp(canvas, '$charges/$maxChrg', cx, countY, charges == 0 ? _kWarn : _kFg, 7.5, center: true);
  }

  void _drawBomb(Canvas canvas, double x, double y, bool live) {
    final col = live ? _kFg : _kDim.withValues(alpha: 0.25);
    final nose = Path()
      ..moveTo(x,       y - 5.5)
      ..lineTo(x - 2.5, y - 2.5)
      ..lineTo(x + 2.5, y - 2.5)
      ..close();
    canvas.drawPath(nose, Paint()..color = col..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(x - 2.5, y - 2.5, 5.0, 6.5),
        Paint()..color = live ? col.withValues(alpha: 0.28) : col..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(x - 2.5, y - 2.5, 5.0, 6.5),
        Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawLine(Offset(x - 4, y + 2.5), Offset(x - 2.5, y + 4),
        Paint()..color = col..strokeWidth = 0.8);
    canvas.drawLine(Offset(x + 4, y + 2.5), Offset(x + 2.5, y + 4),
        Paint()..color = col..strokeWidth = 0.8);
  }

  // ── Wing pylon stations ───────────────────────────────────────────────────

  // Station XY positions differ per aircraft to align with each silhouette's wings.
  List<(double, double)> _stationXY(double cx, double top, double ws, String id) {
    return switch (id) {
      'icefighter' => [
        (cx - ws*0.82, top + 86.0),   // L-outer — delta tip
        (cx - ws*0.46, top + 74.0),   // L-inner — delta mid
        (cx + ws*0.46, top + 74.0),   // R-inner
        (cx + ws*0.82, top + 86.0),   // R-outer
      ],
      'skytanker' => [
        (cx - ws*0.88, top + 66.0),   // L-outer — beyond outer nacelle
        (cx - ws*0.48, top + 66.0),   // L-inner — between nacelles
        (cx + ws*0.48, top + 66.0),   // R-inner
        (cx + ws*0.88, top + 66.0),   // R-outer
      ],
      _ => [                           // FireHawk — conventional swept wing
        (cx - ws*0.76, top + 66.0),
        (cx - ws*0.46, top + 58.0),
        (cx + ws*0.46, top + 58.0),
        (cx + ws*0.76, top + 66.0),
      ],
    };
  }

  void _drawPylonStations(Canvas canvas, double cx, double top, double ws, String id) {
    final pylonAbs = expendable.where((a) => a.name != 'Cryo Bomb').toList();
    final positions = _stationXY(cx, top, ws, id);

    final assigned = <int, AbilityData>{};
    for (int i = 0; i < pylonAbs.length && i < _stationOrder.length; i++) {
      assigned[_stationOrder[i]] = pylonAbs[i];
    }

    for (int si = 0; si < 4; si++) {
      final (sx, sy) = positions[si];
      final ab = assigned[si];
      if (ab == null) {
        _drawEmptyStation(canvas, sx, sy);
      } else {
        final charges = state.abilityCharges[ab.name] ?? ab.maxCharges;
        final cd      = state.abilityCooldowns[ab.name] ?? 0.0;
        _drawStore(canvas, sx, sy, ab, charges, charges > 0 && cd <= 0.0);
      }
    }
  }

  void _drawStore(Canvas canvas, double sx, double sy, AbilityData ab, int charges, bool rdy) {
    final col = charges <= 0 ? _kWarn : (rdy ? _kFg : _kAmber);

    canvas.drawLine(Offset(sx - 3, sy), Offset(sx + 3, sy),
        Paint()..color = _kDim..strokeWidth = 0.5);

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

    canvas.drawLine(Offset(sx - 4, sy + 19), Offset(sx + 4, sy + 19),
        Paint()..color = col..strokeWidth = 0.8);

    final label = charges <= 0 ? 'X' : '$charges';
    _tp(canvas, label, sx, sy - 3, col, 7.5, center: true, bold: true);

    final abbr = ab.name.split(' ').map((w) => w[0]).join();
    _tp(canvas, abbr, sx, sy + 26, _kDim, 5.5, center: true);
  }

  void _drawEmptyStation(Canvas canvas, double sx, double sy) {
    canvas.drawLine(Offset(sx - 3, sy), Offset(sx + 3, sy),
        Paint()..color = _kDim.withValues(alpha: 0.4)..strokeWidth = 0.5);
    _tp(canvas, '──', sx, sy + 12, _kDim.withValues(alpha: 0.4), 7.0, center: true);
  }

  // ── Text helper ───────────────────────────────────────────────────────────

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
