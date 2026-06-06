import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'landing_system.dart';

const _kRFg   = Color(0xFF00AAFF);
const _kRDim  = Color(0xFF003366);
const _kAmber = Color(0xFFFFB300);
const _kGreen = Color(0xFF00FF88);

Widget buildIlsPage(GameState state) {
  final rw = LandingSystem.bestRunway(
      state.playerPosition.x, state.playerPosition.z, state.playerRotation.y);
  final approach = rw == null
      ? null
      : LandingSystem.computeApproach(
          state.playerPosition.x, state.playerPosition.y,
          state.playerPosition.z, rw);

  return Column(children: [
    _hdr(),
    Expanded(child: approach == null ? _noSignal() : _ilsDisplay(approach)),
    _footer(approach, state),
  ]);
}

Widget _hdr() => Container(
  height: 40,
  padding: const EdgeInsets.symmetric(horizontal: 6),
  color: _kRDim.withValues(alpha: 0.4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    const Text('ILS APPROACH', style: TextStyle(color: _kRFg, fontSize: 18, letterSpacing: 1)),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      color: _kRFg.withValues(alpha: 0.2),
      child: const Text('ILS', style: TextStyle(color: _kRFg, fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  ]),
);

Widget _noSignal() => Center(
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('NO ILS SIGNAL', style: TextStyle(color: Color(0xFF003366), fontSize: 20, letterSpacing: 2)),
    const SizedBox(height: 6),
    Text('ALIGN HEADING TO RUNWAY (±70°)',
        style: TextStyle(color: _kRDim.withValues(alpha: 0.5), fontSize: 8)),
  ]),
);

Widget _ilsDisplay(ApproachData a) {
  return LayoutBuilder(builder: (ctx, c) {
    return Stack(children: [
      CustomPaint(
        size: Size(c.maxWidth, c.maxHeight),
        painter: _IlsCrossPainter(locDots: a.locDots, gsDots: a.gsDots),
      ),
      Positioned(top: 8, left: 8,
          child: Text(a.runway.id,
              style: const TextStyle(color: _kRFg, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1))),
      Positioned(top: 8, right: 8, child: _papiLights(a.papiWhite)),
    ]);
  });
}

Widget _papiLights(List<bool> lights) => Row(
  mainAxisSize: MainAxisSize.min,
  children: List.generate(4, (i) => Container(
    width: 16, height: 16,
    margin: const EdgeInsets.only(left: 4),
    decoration: BoxDecoration(
      color: lights[i] ? Colors.white : const Color(0xFFCC2200),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black45, width: 0.5),
      boxShadow: [BoxShadow(
        color: lights[i] ? Colors.white54 : const Color(0xFFFF2200).withValues(alpha: 0.4),
        blurRadius: 4,
      )],
    ),
  )),
);

Widget _footer(ApproachData? a, GameState state) {
  if (a == null) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: _kRDim.withValues(alpha: 0.3),
      child: const Center(child: Text('DEPLOY GEAR AND ALIGN TO RUNWAY',
          style: TextStyle(color: Color(0xFF003366), fontSize: 8, letterSpacing: 1))),
    );
  }
  final locDir = a.locDots > 0.1 ? 'R' : a.locDots < -0.1 ? 'L' : 'CTR';
  final gsDir  = a.gsDots  > 0.1 ? 'HI' : a.gsDots  < -0.1 ? 'LO' : 'ON';
  final locCol = a.locDots.abs() < 0.3 ? _kGreen : _kAmber;
  final gsCol  = a.gsDots.abs()  < 0.3 ? _kGreen : _kAmber;
  final rngStr = a.downrangeM > 0 ? '${a.downrangeM.toStringAsFixed(0)} u' : 'PAST THR';
  final wCount = a.papiWhite.where((b) => b).length;
  final papiLabel = switch (wCount) {
    4 => 'HI  HI',
    3 => 'HI',
    2 => 'ON GS',
    1 => 'LO',
    _ => 'LO  LO',
  };

  return Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: _kRDim.withValues(alpha: 0.3),
    child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('LOC  $locDir  ${a.locDots.abs().toStringAsFixed(2)}',
            style: TextStyle(color: locCol, fontSize: 14, fontWeight: FontWeight.bold)),
        Text('G/S  $gsDir  ${a.gsDots.abs().toStringAsFixed(2)}',
            style: TextStyle(color: gsCol,  fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('RNG:$rngStr',           style: const TextStyle(color: _kRFg, fontSize: 8)),
        Text('ANG:${a.glideAngleDeg.toStringAsFixed(1)}°',
                                       style: const TextStyle(color: _kRFg, fontSize: 8)),
        Text('PAPI:$papiLabel',
            style: TextStyle(color: wCount == 2 ? _kGreen : _kAmber, fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}

class _IlsCrossPainter extends CustomPainter {
  final double locDots; // ±2.5 full scale; positive = right of center
  final double gsDots;  // ±2.5 full scale; positive = above glidepath (needle below center)

  const _IlsCrossPainter({required this.locDots, required this.gsDots});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    // Dot spacing: 1 dot = 1/5 of the shorter dimension
    final ds = math.min(size.width, size.height) / 5;

    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF000A14));

    final dimP = Paint()
      ..color = _kRDim
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Reference axes
    canvas.drawLine(Offset(cx, 4), Offset(cx, size.height - 4), dimP);
    canvas.drawLine(Offset(4, cy), Offset(size.width - 4, cy), dimP);

    // Reference dots at ±1 and ±2 dots
    final dotP = Paint()..color = _kRDim..style = PaintingStyle.fill;
    for (final d in [-2.0, -1.0, 1.0, 2.0]) {
      canvas.drawCircle(Offset(cx + d * ds, cy), 3, dotP);
      canvas.drawCircle(Offset(cx, cy + d * ds), 3, dotP);
    }

    // Localizer needle (vertical bar, moves left/right)
    final locX  = cx + locDots * ds;
    final locCol = locDots.abs() < 0.3 ? _kGreen : _kAmber;
    final locP  = Paint()..color = locCol..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(locX, cy - 36), Offset(locX, cy + 36), locP);

    // Glideslope needle (horizontal bar, moves up/down)
    // Aviation convention: above glidepath (gsDots > 0) → needle below center → fly down
    final gsY   = cy + gsDots * ds;
    final gsCol  = gsDots.abs() < 0.3 ? _kGreen : _kAmber;
    final gsP   = Paint()..color = gsCol..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 36, gsY), Offset(cx + 36, gsY), gsP);

    // Aircraft reference symbol at center (fixed)
    final acP = Paint()..color = _kRFg..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 10, cy), acP);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 5), acP);
    canvas.drawLine(Offset(cx - 5, cy + 5), Offset(cx + 5, cy + 5), acP);
    canvas.drawCircle(Offset(cx, cy), 3,
        Paint()..color = _kRFg..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_IlsCrossPainter o) =>
      o.locDots != locDots || o.gsDots != gsDots;
}
