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
/// Layout:
///   • Cryo Bombs — two vertical columns flanking the fuselage centerline.
///   • Other expendables (Heat Seeker, Frost Missile) — inner wing pylons.
///   • Rechargeable systems — internal bay slots.
Widget buildLoadoutPage(GameState state) {
  final expendable = state.abilities.where((a) => a.isExpendable).toList();
  final recharge   = state.abilities.where((a) => !a.isExpendable).toList();

  // Totals account for aircraft-specific store overrides (e.g. CB count).
  final overrides  = state.currentAircraft.storeCharges;
  final totalLeft  = expendable.fold(0, (s, a) =>
      s + (state.abilityCharges[a.name] ?? (overrides[a.name] ?? a.maxCharges)));
  final totalMax   = expendable.fold(0, (s, a) =>
      s + (overrides[a.name] ?? a.maxCharges));
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

  // Station fill order: inner-left (1), inner-right (2), outer-left (0), outer-right (3).
  // Maximises symmetry — 2 stores go on inner pylons, spread outward after that.
  static const _stationOrder = [1, 2, 0, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final top = 6.0;
    final ws  = size.width * 0.40;

    _drawAircraft(canvas, cx, top, ws);
    _drawInternalBay(canvas, cx, top);
    _drawCryoBombColumns(canvas, cx, top);
    _drawPylonStations(canvas, cx, top, ws);
  }

  // ── Aircraft silhouette ───────────────────────────────────────────────────

  void _drawAircraft(Canvas canvas, double cx, double top, double ws) {
    final path = Path()
      ..moveTo(cx,        top +   6)
      ..lineTo(cx + 10,   top +  22)
      ..lineTo(cx + ws,   top +  72)
      ..lineTo(cx + ws * 0.74, top + 96)
      ..lineTo(cx + 19,   top + 110)
      ..lineTo(cx + 22,   top + 126)
      ..lineTo(cx + 12,   top + 138)
      ..lineTo(cx,        top + 143)
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

  // ── Cryo Bomb centerline columns ─────────────────────────────────────────
  //
  // Bombs are laid out in two vertical columns flanking the fuselage (cx ± 11).
  // Slots are interleaved L/R (left=even indices, right=odd indices) so both
  // columns deplete in step.  Live slots are bright green; expended slots dim.

  void _drawCryoBombColumns(Canvas canvas, double cx, double top) {
    final abIdx = expendable.indexWhere((a) => a.name == 'Cryo Bomb');
    if (abIdx < 0) return;

    final ab       = expendable[abIdx];
    final overrides = state.currentAircraft.storeCharges;
    final maxChrg  = overrides[ab.name] ?? ab.maxCharges;
    final charges  = state.abilityCharges[ab.name] ?? maxChrg;
    if (maxChrg == 0) return;

    final leftCount  = (maxChrg + 1) ~/ 2;  // ceil — left column is one larger when odd
    final rightCount = maxChrg ~/ 2;

    final leftX  = cx - 11.0;
    final rightX = cx + 11.0;
    const startY = 50.0;
    const stepY  = 11.5;

    // Left column — even slot indices (0, 2, 4, …)
    for (int li = 0; li < leftCount; li++) {
      final slotIdx = li * 2;
      _drawBomb(canvas, leftX, top + startY + li * stepY, slotIdx < charges);
    }
    // Right column — odd slot indices (1, 3, 5, …)
    for (int ri = 0; ri < rightCount; ri++) {
      final slotIdx = ri * 2 + 1;
      _drawBomb(canvas, rightX, top + startY + ri * stepY, slotIdx < charges);
    }

    // Column header
    _tp(canvas, 'CB', cx, top + startY - 9, _kDim, 5.5, center: true);

    // Count below the tallest column
    final rows   = math.max(leftCount, rightCount);
    final countY = top + startY + rows * stepY + 2;
    final col    = charges == 0 ? _kWarn : _kFg;
    _tp(canvas, '$charges/$maxChrg', cx, countY, col, 7.5, center: true);
  }

  void _drawBomb(Canvas canvas, double x, double y, bool live) {
    final col = live ? _kFg : _kDim.withValues(alpha: 0.25);
    // Nose cone
    final nose = Path()
      ..moveTo(x,       y - 5.5)
      ..lineTo(x - 2.5, y - 2.5)
      ..lineTo(x + 2.5, y - 2.5)
      ..close();
    canvas.drawPath(nose, Paint()..color = col..style = PaintingStyle.fill);
    // Body
    canvas.drawRect(Rect.fromLTWH(x - 2.5, y - 2.5, 5.0, 6.5),
        Paint()..color = live ? col.withValues(alpha: 0.28) : col..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(x - 2.5, y - 2.5, 5.0, 6.5),
        Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 0.8);
    // Tail fins
    canvas.drawLine(Offset(x - 4, y + 2.5), Offset(x - 2.5, y + 4),
        Paint()..color = col..strokeWidth = 0.8);
    canvas.drawLine(Offset(x + 4, y + 2.5), Offset(x + 2.5, y + 4),
        Paint()..color = col..strokeWidth = 0.8);
  }

  // ── Wing pylon stations ──────────────────────────────────────────────────
  //
  // Shows all expendables except Cryo Bombs (those are in centerline columns).
  // Placed from inner pylons outward for visual symmetry.

  void _drawPylonStations(Canvas canvas, double cx, double top, double ws) {
    final pylonAbs = expendable.where((a) => a.name != 'Cryo Bomb').toList();

    // Station positions: [0]=L-outer, [1]=L-inner, [2]=R-inner, [3]=R-outer
    final stationXY = [
      (cx - ws * 0.74, top + 66.0),
      (cx - ws * 0.44, top + 58.0),
      (cx + ws * 0.44, top + 58.0),
      (cx + ws * 0.74, top + 66.0),
    ];

    // Map station index → ability (fill from inner outward)
    final assigned = <int, AbilityData>{};
    for (int i = 0; i < pylonAbs.length && i < _stationOrder.length; i++) {
      assigned[_stationOrder[i]] = pylonAbs[i];
    }

    for (int si = 0; si < 4; si++) {
      final (sx, sy) = stationXY[si];
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
