import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Design tokens (HUD_DESIGN_RESEARCH.md §8) ─────────────────────────────────
const Color kGlacierBlue = Color(0xFF00CFFF);
const Color kArcticCyan  = Color(0xFF00EEFF);
const Color kAbyssNavy   = Color(0xFF050A14);
const Color kPolarNight  = Color(0xFF0A1F3A);
const Color kIceShelf    = Color(0xFF1C3D5A);
const Color kFrostWhite  = Color(0xFFE8F4FF);
const Color kManaFill    = Color(0xFF3AB7FF);
const Color kXpPurple    = Color(0xFF7C4DFF);
const Color kEmber       = Color(0xFFFF6420);
const Color kDanger      = Color(0xFFFF2200);
const Color kHeatAmber   = Color(0xFFFFA020);
const Color kHullWarn    = Color(0xFF9966FF);
const Color kHullCrit    = Color(0xFFFF6644);
const Color kColdViolet  = Color(0xFFCC44FF);

// ── Fire Proximity Sensor ─────────────────────────────────────────────────────

/// Circular elemental-threat display — replaces traditional radar.
///
/// [threatLevel] 0–1 drives the outer heat arc and danger ring brightness.
/// [contacts] are normalised positions in -1..1 sensor space (fire elementals).
/// When no enemies exist, threat derives from [GameState.flightAltitude].
class FireProximitySensor extends StatelessWidget {
  final GameState state;
  const FireProximitySensor({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Derive threat from altitude proxy: alt < 10 = danger, > 30 = safe.
    final threat = (1.0 - (state.flightAltitude / 30.0)).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FpsLabel(),
        SizedBox(
          width: 120, height: 120,
          child: CustomPaint(
            painter: _FpsPainter(threat: threat),
          ),
        ),
      ],
    );
  }
}

class _FpsLabel extends StatelessWidget {
  const _FpsLabel();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 4, bottom: 2),
    child: Text('FIRE PROX', style: TextStyle(color: kIceShelf, fontSize: 8, letterSpacing: 1.5)),
  );
}

// Pre-computed ember contact data (seed 42, 6 slots).
// Avoids allocating math.Random and calling nextDouble() inside paint().
final _kEmberAngles = List.unmodifiable(() {
  final rng = math.Random(42);
  return [for (int i = 0; i < 6; i++) rng.nextDouble() * math.pi * 2];
}());
final _kEmberDists = List.unmodifiable(() {
  final rng = math.Random(42);
  for (int i = 0; i < 6; i++) rng.nextDouble(); // consume angle slots
  return [for (int i = 0; i < 6; i++) 0.35 + rng.nextDouble() * 0.55];
}());

class _FpsPainter extends CustomPainter {
  final double threat; // 0–1
  const _FpsPainter({required this.threat});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 5;

    // Background
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [const Color(0xFF0D1F35), kAbyssNavy],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Subtle range rings
    final ringPaint = Paint()..color = kIceShelf.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (final frac in [0.33, 0.66]) {
      canvas.drawCircle(Offset(cx, cy), r * frac, ringPaint);
    }

    // Danger proximity ring at 30 %
    final dangerAlpha = 0.25 + threat * 0.5;
    canvas.drawCircle(Offset(cx, cy), r * 0.30,
      Paint()..color = kDanger.withValues(alpha: dangerAlpha)
            ..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Ambient fire signatures — use pre-computed positions; no allocation.
    if (threat > 0.15) {
      final count = (threat * 5).ceil().clamp(1, 6);
      for (int i = 0; i < count; i++) {
        final angle = _kEmberAngles[i];
        final dist  = _kEmberDists[i] * (1.0 - threat);
        final ex    = cx + math.cos(angle) * r * dist;
        final ey    = cy + math.sin(angle) * r * dist;
        final sz    = 2.5 + (1.0 - dist) * 4.0;
        canvas.drawCircle(Offset(ex, ey), sz,
          Paint()..color = kEmber.withValues(alpha: 0.55 + (1 - dist) * 0.35));
        canvas.drawCircle(Offset(ex, ey), sz * 2.2,
          Paint()..color = kEmber.withValues(alpha: 0.12));
      }
    }

    // Player marker — white diamond at centre
    final mp = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, cy - 5)
      ..lineTo(cx + 3, cy)
      ..lineTo(cx, cy + 5)
      ..lineTo(cx - 3, cy)
      ..close();
    canvas.drawPath(path, mp);

    // Outer border
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = kIceShelf..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Heat-intensity arc (270°, clockwise from 135°)
    if (threat > 0.02) {
      final arcRect  = Rect.fromCircle(center: Offset(cx, cy), radius: r + 5);
      final sweep    = math.pi * 1.5 * threat;
      final arcColor = Color.lerp(const Color(0xFF1A6FFF), kDanger, threat)!;
      canvas.drawArc(arcRect, math.pi * 0.75, sweep, false,
        Paint()..color = arcColor..style = PaintingStyle.stroke
              ..strokeWidth = 3..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_FpsPainter o) => o.threat != threat;
}

// ── Hull Integrity Arc ────────────────────────────────────────────────────────

/// 10-segment 270° arc gauge — the ice hull's health display.
///
/// Segments shatter individually; colour shifts blue→purple→orange as health
/// drops.  Specification: HUD_DESIGN_RESEARCH.md §6.
class HullIntegrityArc extends StatelessWidget {
  final GameState state;
  const HullIntegrityArc({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100, height: 88,
      child: CustomPaint(
        painter: _HullPainter(fraction: state.health / GameState.maxHealth),
      ),
    );
  }
}

class _HullPainter extends CustomPainter {
  final double fraction; // 0–1
  static const int    _segs  = 10;
  static const double _start = math.pi * 0.75;      // 135° (7:30 position)
  static const double _total = math.pi * 1.5;        // 270°
  static const double _gap   = 0.05;                 // radians between segments
  static const double _sweep = (_total - _gap * _segs) / _segs;

  const _HullPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final r  = math.min(size.width, size.height) / 2 - 4;

    final filled = (fraction * _segs).ceil().clamp(0, _segs);

    for (int i = 0; i < _segs; i++) {
      final angle = _start + i * (_sweep + _gap);
      final Color col;
      if (i >= filled) {
        col = kPolarNight;
      } else if (fraction > 0.6) {
        col = kGlacierBlue;
      } else if (fraction > 0.3) {
        col = kHullWarn;
      } else {
        col = kHullCrit;
      }

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle, _sweep, false,
        Paint()..color = col..style = PaintingStyle.stroke
              ..strokeWidth = 7..strokeCap = StrokeCap.butt,
      );
    }

    // Centre label
    _drawCentredText(canvas, '${(fraction * 100).toInt()}%', Offset(cx, cy - 6),
        fraction > 0.3 ? kGlacierBlue : kHullCrit, 11, bold: true);
    _drawCentredText(canvas, 'HULL', Offset(cx, cy + 8), kIceShelf, 8);
  }

  void _drawCentredText(Canvas canvas, String text, Offset pos,
      Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HullPainter o) => o.fraction != fraction;
}

// ── Flight Data Cluster ───────────────────────────────────────────────────────

/// Top-left readout: altitude, speed, heading.  Always visible.
class FlightDataCluster extends StatelessWidget {
  final GameState state;
  const FlightDataCluster({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hdg = ((state.playerRotation.y % 360) + 360) % 360;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kAbyssNavy.withValues(alpha: 0.80),
        border: Border.all(color: kIceShelf, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('ALT', '${state.flightAltitude.toStringAsFixed(1)} m'),
          _row('SPD', '${state.flightSpeed.toStringAsFixed(1)} u/s'),
          _row('HDG', '${hdg.toStringAsFixed(0)}°'),
          if (state.flightPitchAngle.abs() > 0.5)
            _row('PCH', '${state.flightPitchAngle.toStringAsFixed(1)}°'),
          if (state.isBarrelRolling)
            const Text('BARREL ROLL',
              style: TextStyle(color: kHeatAmber, fontSize: 9,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 28,
        child: Text(label, style: const TextStyle(color: kIceShelf, fontSize: 9, letterSpacing: 1))),
      Text(value, style: const TextStyle(color: kFrostWhite, fontSize: 10,
          fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    ]),
  );
}

// ── Warning Text Zone ─────────────────────────────────────────────────────────

/// Top-centre flashing warnings — stall, low mana, overheat.
class WarningTextZone extends StatelessWidget {
  final GameState state;
  const WarningTextZone({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final warnings = <String>[];
    if (state.mana < 15)                      warnings.add('LOW MANA');
    if (state.health < 20)                    warnings.add('HULL CRITICAL');
    if (state.flightSpeed < 1.0 && state.flightAltitude > 2) warnings.add('STALL');
    if (state.flightAltitude < 3)             warnings.add('PULL UP');
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: const Alignment(0, -0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: warnings.map((w) => _WarningChip(text: w)).toList(),
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  final String text;
  const _WarningChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: kDanger.withValues(alpha: 0.18),
      border: Border.all(color: kDanger.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text,
      style: const TextStyle(color: kDanger, fontSize: 12,
          fontWeight: FontWeight.bold, letterSpacing: 2)),
  );
}

// ── Cockpit Windshield HUD ────────────────────────────────────────────────────
// F-22-style glass HUD: pitch ladder, FPM, heading tape, speed/alt chevron
// boxes, status strip, glide-slope reference.

const _hG   = Color(0xFF00FF55); // HUD green
const _hM   = Color(0xFFFF3399); // magenta — compass direction
const _hDim = Color(0xFF008833); // secondary labels
const _tsN  = TextStyle(color: _hG, fontSize: 17, fontWeight: FontWeight.bold, height: 1.0);
const _tsS  = TextStyle(color: _hG, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.18);
const _tsD  = TextStyle(color: _hDim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.18);

Widget buildCockpitWindshieldHud(GameState state) {
  final hdg   = ((state.playerRotation.y % 360) + 360) % 360;
  final pitch = state.flightPitchAngle;
  final bank  = state.flightBankAngle;
  final spd   = state.flightSpeed;
  final alt   = state.flightAltitude;
  final thr   = (state.throttle * 100).round();
  final aoa   = (pitch * 0.72).clamp(-20.0, 30.0);
  final radar = (alt - state.terrainHeight).clamp(0.0, 9999.0);
  final vs    = (spd * math.sin(pitch * math.pi / 180) * 60).round();
  final gearLbl = state.gearMoving ? 'TRANS' : (state.gearDeployed ? 'DN' : 'UP');
  final flapLbl = ['UP', 'T/O', 'APR', 'FUL'][state.flapsLevel.clamp(0, 3)];
  final vsStr   = '${vs >= 0 ? '+' : ''}$vs';

  Widget wayptBox() {
    final (name, wx, wz) = GameState.kWaypoints[state.lockedWaypoint];
    final dx = wx - state.playerPosition.x, dz = wz - state.playerPosition.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    final brg  = ((math.atan2(dx, dz) * 180 / math.pi) + 360) % 360;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('${dist.toStringAsFixed(2)} NM', style: _tsS),
      Text('ILOS  $name', style: _tsD),
      Text('BRG   ${brg.toStringAsFixed(0)}°', style: _tsD),
    ]);
  }

  return Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _HwPainter(pitch: pitch, bank: bank, heading: hdg))),
    Positioned(left: 210, top: 258, child: _chevBox(spd.toStringAsFixed(0), true)),
    Positioned(left: 210, top: 303, child: Text('α   ${aoa.toStringAsFixed(0)}', style: _tsS)),
    Positioned(right: 210, top: 258, child: _chevBox(alt.toStringAsFixed(0), false)),
    Positioned(right: 210, top: 303, child: Text(vsStr, style: _tsS)),
    Positioned(left: 150, top: 368,
      child: DefaultTextStyle(style: _tsS, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('GS   ${state.groundSpeed.toStringAsFixed(0)}'),
        Text('FP   $flapLbl'),
        Text('LG   $gearLbl'),
      ]))),
    Positioned(left: 150, top: 456, child: Text('$thr %', style: _tsN.copyWith(fontSize: 19))),
    Positioned(right: 150, top: 368,
      child: DefaultTextStyle(style: _tsS, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('APC  ${(state.engineN1 * 1000).round()}'),
        Text('R    ${radar.toStringAsFixed(0)}'),
      ]))),
    if (state.lockedWaypoint >= 0) Positioned(left: 44, top: 95, child: wayptBox()),
    if (state.autopilotEnabled)
      Align(alignment: const Alignment(0, -0.56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          color: const Color(0x99003300),
          child: Text(
            state.flightPlan.isEmpty ? '◆  A/P  ENGAGED'
                : '◆  A/P  →  ${state.flightPlan[state.flightPlanIndex.clamp(0, state.flightPlan.length-1)].$1}',
            style: const TextStyle(color: _hG, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)))),
    if (state.isBarrelRolling)
      Align(alignment: const Alignment(0, -0.32),
        child: const Text('◀  BARREL ROLL  ▶',
          style: TextStyle(color: Color(0xFFFF6600), fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4))),
  ]);
}

Widget _chevBox(String v, bool left) => CustomPaint(
  painter: _ChevP(left),
  child: Padding(padding: EdgeInsets.fromLTRB(left?16:8, 5, left?8:16, 5),
    child: Text(v, style: _tsN)));

class _ChevP extends CustomPainter {
  final bool l;
  const _ChevP(this.l);
  @override void paint(Canvas c, Size s) {
    final p = Paint()..color = _hG..strokeWidth = 1.5..style = PaintingStyle.stroke;
    const d = 10.0; final w = s.width, h = s.height;
    c.drawPath(l
      ? (Path()..moveTo(w,0)..lineTo(0,0)..lineTo(-d,h/2)..lineTo(0,h)..lineTo(w,h))
      : (Path()..moveTo(0,0)..lineTo(w,0)..lineTo(w+d,h/2)..lineTo(w,h)..lineTo(0,h)), p);
  }
  @override bool shouldRepaint(_ChevP o) => o.l != l;
}

// ── Main HUD CustomPainter ────────────────────────────────────────────────────

class _HwPainter extends CustomPainter {
  final double pitch, bank, heading;
  const _HwPainter({required this.pitch, required this.bank, required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height * 0.335;
    _hdgTape(canvas, cx, heading);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-bank * math.pi / 180);
    _ladder(canvas, pitch);
    _fpm(canvas);
    canvas.restore();
    _gsRef(canvas, cx, cy);
  }

  void _ladder(Canvas canvas, double pitch) {
    final p = Paint()..color = _hG..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int lp = -30; lp <= 30; lp += 5) {
      final dy = (lp - pitch) * 18.0;
      if (dy.abs() > 230) continue;
      final hw = lp % 10 == 0 ? 80.0 : 50.0;
      const g = 32.0;
      if (lp > 0) {
        canvas.drawLine(Offset(-hw, dy), Offset(-g, dy), p);
        canvas.drawLine(Offset(g, dy), Offset(hw, dy), p);
      } else if (lp < 0) {
        _dash(canvas, Offset(-hw, dy), Offset(-g, dy), p);
        _dash(canvas, Offset(g, dy), Offset(hw, dy), p);
        canvas.drawLine(Offset(-hw, dy), Offset(-hw, dy+9), p);
        canvas.drawLine(Offset(hw, dy), Offset(hw, dy+9), p);
      } else {
        p.strokeWidth = 2; canvas.drawLine(Offset(-hw,dy),Offset(-g,dy),p);
        canvas.drawLine(Offset(g,dy),Offset(hw,dy),p); p.strokeWidth = 1.5;
      }
      if (lp % 10 == 0 && lp != 0) {
        _lbl(canvas, '${lp.abs()}', Offset(-hw-20, dy));
        _lbl(canvas, '${lp.abs()}', Offset(hw+5, dy));
      }
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p) {
    final dx = b.dx-a.dx, dy = b.dy-a.dy, len = math.sqrt(dx*dx+dy*dy);
    final ux = dx/len, uy = dy/len; var t = 0.0; var on = true;
    while (t < len) { final s = on?7.0:4.0; final t2=(t+s).clamp(0.0,len);
      if (on) canvas.drawLine(Offset(a.dx+ux*t,a.dy+uy*t),Offset(a.dx+ux*t2,a.dy+uy*t2),p);
      t+=s; on=!on; }
  }

  void _fpm(Canvas canvas) {
    final p = Paint()..color = _hG..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 12, p);
    canvas.drawLine(const Offset(-12,0), const Offset(-32,0), p);
    canvas.drawLine(const Offset(12,0), const Offset(32,0), p);
    canvas.drawLine(const Offset(0,-12), const Offset(0,-24), p);
  }

  void _hdgTape(Canvas canvas, double cx, double hdg) {
    final p = Paint()..color = _hG..strokeWidth = 1.5;
    for (int dh = -18; dh <= 18; dh++) {
      final th = ((hdg+dh)%360+360)%360; final x = cx+dh*9.0;
      if (th%10==0) { canvas.drawLine(Offset(x,48),Offset(x,58),p); _lbl(canvas,'${(th/10).round()%36}',Offset(x,64)); }
      else if (th%5==0) canvas.drawLine(Offset(x,48),Offset(x,54),p);
    }
    final hs = hdg.round().toString().padLeft(3,'0');
    canvas.drawRect(Rect.fromLTWH(cx-28,74,56,24),Paint()..color=_hG..style=PaintingStyle.stroke..strokeWidth=1.5);
    _lbl(canvas,hs,Offset(cx,86),sz:15,bold:true);
    _lbl(canvas,_cdir(hdg),Offset(cx,30),sz:13,bold:true,col:_hM);
  }

  void _gsRef(Canvas canvas, double cx, double cy) {
    canvas.drawLine(Offset(cx+175,cy-20),Offset(cx+175,cy+20),Paint()..color=_hDim..strokeWidth=1);
    canvas.drawCircle(Offset(cx+179,cy),3,Paint()..color=_hDim);
    _lbl(canvas,'GS',Offset(cx+165,cy),sz:10,col:_hDim);
  }

  void _lbl(Canvas canvas, String t, Offset c, {double sz=11, bool bold=false, Color? col}) {
    final tp = TextPainter(text: TextSpan(text:t,style:TextStyle(color:col??_hG,fontSize:sz,height:1.0,fontWeight:bold?FontWeight.bold:FontWeight.normal)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas, c - Offset(tp.width/2, tp.height/2));
  }

  static String _cdir(double h) => const ['N','NE','E','SE','S','SW','W','NW'][((h+22.5)/45).floor()%8];

  @override bool shouldRepaint(_HwPainter o) => o.pitch!=pitch||o.bank!=bank||o.heading!=heading;
}
