import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Shared colors (mirrored from mfd_panels.dart) ─────────────────────────────

const _kLFg   = Color(0xFF00FF41);
const _kLDim  = Color(0xFF005519);
const _kRFg   = Color(0xFF00AAFF);
const _kRDim  = Color(0xFF003366);
const _kAmber = Color(0xFFFFB300);
const _kWarn  = Color(0xFFFF6600);

// ── Shared header (matches mfd_panels.dart style) ─────────────────────────────

Widget _hdr(String title, String mode, Color fg, Color dim) {
  return Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: dim.withValues(alpha: 0.4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(color: fg, fontSize: 9, letterSpacing: 1)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        color: fg.withValues(alpha: 0.2),
        child: Text(mode, style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT MFD pages 1–3
// ═══════════════════════════════════════════════════════════════════════════════


// ── STAT – Systems Status ─────────────────────────────────────────────────────

Widget buildStatPage(GameState state) {
  final hpF = state.health / GameState.maxHealth;
  final mpF = state.mana   / GameState.maxMana;
  final hpPct = (hpF * 100).round();
  final mpPct = (mpF * 100).round();
  final hpStatus = hpPct > 60 ? 'NRML' : hpPct > 30 ? 'CAUT' : 'CRIT';
  final mpStatus = mpPct > 25 ? 'NRML' : 'LOW ';
  final hpCol = hpPct > 60 ? _kLFg : hpPct > 30 ? _kAmber : _kWarn;
  final mpCol = mpPct > 25 ? _kLFg : _kAmber;
  final cds   = state.abilityCooldowns.values.where((v) => v > 0).length;

  return Column(children: [
    _hdr('SYSTEMS STATUS', 'STAT', _kLFg, _kLDim),
    Expanded(child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('VITALS', style: TextStyle(color: _kLDim, fontSize: 7, letterSpacing: 2)),
        const SizedBox(height: 4),
        _vitalRow('HEALTH', '$hpPct%', hpStatus, hpCol, hpF),
        _vitalRow('MANA  ', '$mpPct%', mpStatus, mpCol, mpF),
        const SizedBox(height: 8),
        Text('FLIGHT', style: TextStyle(color: _kLDim, fontSize: 7, letterSpacing: 2)),
        const SizedBox(height: 4),
        _dataLine('ALTITUDE', '${state.flightAltitude.toStringAsFixed(1)} m'),
        _dataLine('SPEED   ', '${state.flightSpeed.toStringAsFixed(1)} u/s'),
        _dataLine('PITCH   ', '${state.flightPitchAngle.toStringAsFixed(1)}°'),
        _dataLine('BANK    ', '${state.flightBankAngle.toStringAsFixed(1)}°'),
      ]),
    )),
    Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: _kLDim.withValues(alpha: 0.3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('SYS:OK', style: TextStyle(color: _kLFg, fontSize: 8)),  // using const here - wait, _kLFg is const
        Text('CDS:$cds', style: TextStyle(color: _kLDim, fontSize: 8)),
        const Text('FLT:NRML', style: TextStyle(color: _kLDim, fontSize: 8)),
      ]),
    ),
  ]);
}

Widget _vitalRow(String label, String pct, String status, Color col, double f) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      SizedBox(width: 48,
          child: Text(label, style: TextStyle(color: _kLDim, fontSize: 7))),
      Expanded(child: Stack(children: [
        Container(height: 5, color: _kLDim.withValues(alpha: 0.2)),
        FractionallySizedBox(
          widthFactor: f.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(height: 5, color: col),
        ),
      ])),
      const SizedBox(width: 4),
      SizedBox(width: 26, child: Text(pct, style: TextStyle(color: col, fontSize: 7))),
      SizedBox(width: 28, child: Text(status,
          style: TextStyle(color: col, fontSize: 7, fontWeight: FontWeight.bold))),
    ]),
  );
}

Widget _dataLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: _kLDim, fontSize: 8)),
      Text(value,  style: TextStyle(color: _kLFg,  fontSize: 8)),
    ]),
  );
}

// ── MODE – Flight Parameters (DED-style) ──────────────────────────────────────

Widget buildModePage(GameState state) {
  return Column(children: [
    _hdr('FLIGHT PARAMS', 'MODE', _kLFg, _kLDim),
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _modeRow('*FLT SPD', '${state.cfgFlightSpeed.toStringAsFixed(1)} U/S'),
        _modeRow(' PCH RT ', '${state.cfgPitchRate.toStringAsFixed(0)} °/S'),
        _modeRow(' MAX PCH', '${state.cfgMaxPitchAngle.toStringAsFixed(0)} °'),
        _modeRow('*BOOST  ', '${state.cfgBoostMultiplier.toStringAsFixed(1)} X'),
        _modeRow(' BRAKE  ', '${state.cfgBrakeMultiplier.toStringAsFixed(1)} X'),
        _modeRow(' BNK RT ', '${state.cfgBankRate.toStringAsFixed(0)} °/S'),
        _modeRow(' MAX BNK', '${state.cfgMaxBankAngle.toStringAsFixed(0)} °'),
        _modeRow(' ROLL RT', '${state.cfgBarrelRollRate.toStringAsFixed(0)} °/S'),
        _modeRow(' MNA DRN', '${state.cfgManaDrainRate.toStringAsFixed(1)} /S'),
      ]),
    )),
    Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: _kLDim.withValues(alpha: 0.3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('SYS:WINDWALKER', style: TextStyle(color: _kLFg, fontSize: 8)),
        Text('ACTIVE', style: TextStyle(color: _kLFg, fontSize: 8)),
      ]),
    ),
  ]);
}

Widget _modeRow(String label, String value) {
  final starred = label.startsWith('*');
  final fg = starred ? _kLFg : _kLDim;
  return Row(children: [
    Expanded(child: Text(
      starred ? label.substring(1).trim() : label.trim(),
      style: TextStyle(color: fg, fontSize: 8),
    )),
    Text(value, style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.bold)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIGHT MFD pages 1–3
// ═══════════════════════════════════════════════════════════════════════════════

// ── TERR – Terrain Proximity / Compass Rose ───────────────────────────────────

Widget buildTerrPage(GameState state) {
  final clearance = state.flightAltitude - state.terrainHeight;
  final gpws    = clearance < 3.0 ? 'WARNING' : clearance < state.cfgGpwsAltitude ? 'CAUTION' : 'CLEAR';
  final gpwsCol = clearance < 3.0 ? _kWarn    : clearance < state.cfgGpwsAltitude ? _kAmber  : _kRFg;
  return Column(children: [
    _hdr('TERRAIN PROX', 'TERR', _kRFg, _kRDim),
    Expanded(child: CustomPaint(
      painter: _CompassPainter(heading: state.playerRotation.y),
      child: Container(),
    )),
    Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: _kRDim.withValues(alpha: 0.3),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ALT:${state.flightAltitude.toStringAsFixed(1)}m',
              style: const TextStyle(color: _kRFg, fontSize: 8)),
          Text('CLR:${clearance.toStringAsFixed(1)}m',
              style: TextStyle(color: gpwsCol, fontSize: 8)),
          Text(gpws, style: TextStyle(color: gpwsCol, fontSize: 8, fontWeight: FontWeight.bold)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('GND:${state.terrainHeight.toStringAsFixed(1)}m',
              style: const TextStyle(color: _kRFg, fontSize: 8)),
          Text('GPWS:${state.isGpwsActive ? "ACTIVE" : "OFF"}',
              style: TextStyle(color: gpwsCol, fontSize: 8)),
        ]),
      ]),
    ),
  ]);
}

class _CompassPainter extends CustomPainter {
  final double heading;
  const _CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 16;

    final dim  = Paint()..color = _kRDim..strokeWidth = 1..style = PaintingStyle.stroke;
    final bright = Paint()..color = _kRFg..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), r, dim);
    // Inner ring
    canvas.drawCircle(Offset(cx, cy), r * 0.55, dim..strokeWidth = 0.5);

    // Cardinal tick marks and labels
    const cardinals = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final cos = math.cos(angle); final sin = math.sin(angle);
      final tickOuter = Offset(cx + cos * r, cy + sin * r);
      final tickInner = Offset(cx + cos * (r - (i.isEven ? 10 : 6)), cy + sin * (r - (i.isEven ? 10 : 6)));
      canvas.drawLine(tickOuter, tickInner, i.isEven ? bright : dim);
      if (i.isEven) {
        final lbl = cardinals[i ~/ 2];
        final tp = TextPainter(
          text: TextSpan(text: lbl,
              style: TextStyle(color: _kRFg, fontSize: 10, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx + cos * (r - 22) - tp.width / 2, cy + sin * (r - 22) - tp.height / 2));
      }
    }

    // Heading arrow (points toward current heading)
    final headRad = heading * math.pi / 180 - math.pi / 2;
    final arrowTip = Offset(cx + math.cos(headRad) * (r * 0.7), cy + math.sin(headRad) * (r * 0.7));
    canvas.drawLine(Offset(cx, cy), arrowTip, bright..color = const Color(0xFF00DDFF)..strokeWidth = 2);

    // Aircraft symbol at centre
    final ap = Paint()..color = _kRFg..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), 5, ap);
    canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 10, cy), ap);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 4), ap);
  }

  @override
  bool shouldRepaint(_CompassPainter o) => o.heading != heading;
}

// ── FIRE – Thermal Fire Detection ─────────────────────────────────────────────

// Deterministic fire hotspot positions (seeded, stable across frames)
final List<Offset> _fireHotspots = List.generate(5, (i) {
  final r = math.Random(i * 47 + 13);
  return Offset(r.nextDouble() * 0.7 + 0.15, r.nextDouble() * 0.7 + 0.15);
});

Widget buildFirePage(GameState state) {
  return Column(children: [
    _hdr('FIRE DETECTION', 'FIRE', _kRFg, _kRDim),
    Expanded(child: CustomPaint(
      painter: _FireDetectPainter(),
      child: Container(),
    )),
    Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: _kRDim.withValues(alpha: 0.3),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('MODE:THERM', style: TextStyle(color: _kRFg, fontSize: 8)),
          const Text('RNG:50km',   style: TextStyle(color: _kRFg, fontSize: 8)),
          Text('FIRES:${_fireHotspots.length}',
              style: const TextStyle(color: _kWarn, fontSize: 8, fontWeight: FontWeight.bold)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('SCAN:ACTIVE', style: TextStyle(color: _kRFg, fontSize: 8)),
          const Text('SUPRS:RDY',  style: TextStyle(color: _kRFg, fontSize: 8)),
          const Text('INTNS:HIGH', style: TextStyle(color: _kWarn, fontSize: 8)),
        ]),
      ]),
    ),
  ]);
}

class _FireDetectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 8;
    final ms = DateTime.now().millisecondsSinceEpoch;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF000A14));

    // Range rings
    final rp = Paint()..color = const Color(0xFF330011)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (final frac in [0.33, 0.67, 1.0]) {
      canvas.drawCircle(Offset(cx, cy), r * frac, rp);
    }
    // Cross hairs
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy),
        Paint()..color = const Color(0xFF440022)..strokeWidth = 0.5);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height),
        Paint()..color = const Color(0xFF440022)..strokeWidth = 0.5);

    // Thermal sweep — orange, faster than a targeting radar
    final sweepAngle = (ms % 2000) / 2000 * 2 * math.pi - math.pi / 2;
    for (int i = 0; i < 25; i++) {
      final ta = sweepAngle - (i / 25) * (math.pi / 2);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(ta) * r, cy + math.sin(ta) * r),
        Paint()
          ..color = const Color(0xFFFF6600).withValues(alpha: (1 - i / 25) * 0.35)
          ..strokeWidth = 2..style = PaintingStyle.stroke,
      );
    }
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + math.cos(sweepAngle) * r, cy + math.sin(sweepAngle) * r),
        Paint()..color = const Color(0xFFFF8800)..strokeWidth = 1.5);

    // Fire hotspots — pulsing orange/red dots
    final pulse = (math.sin(ms / 400.0) + 1) / 2;
    for (final hot in _fireHotspots) {
      final hx = hot.dx * size.width;
      final hy = hot.dy * size.height;
      if (math.sqrt(math.pow(hx - cx, 2) + math.pow(hy - cy, 2)) > r) continue;
      final col = Color.lerp(
          const Color(0xFFFF2200), const Color(0xFFFFAA00), pulse)!;
      canvas.drawCircle(Offset(hx, hy), 3, Paint()..color = col..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(hx, hy), 6,
          Paint()..color = const Color(0xFFFF4400).withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // Aircraft dot
    canvas.drawCircle(Offset(cx, cy), 3,
        Paint()..color = const Color(0xFF00DDFF)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_FireDetectPainter _) => true;
}

// ── MARK – Flight Plan Waypoints ──────────────────────────────────────────────

Widget buildMarkPage(GameState state, {Function(int)? onDeleteWaypoint}) {
  final px   = state.playerPosition.x;
  final pz   = state.playerPosition.z;
  final plan = state.flightPlan;

  // Footer: active target info
  String footerWpt = '---', footerBrg = '---', footerDist = '---';
  if (plan.isNotEmpty && state.flightPlanIndex < plan.length) {
    final (name, wx, wz) = plan[state.flightPlanIndex];
    final dx  = wx - px; final dz = wz - pz;
    final rng = math.sqrt(dx * dx + dz * dz);
    final brg = ((math.atan2(dx, dz) * 180 / math.pi) + 360) % 360;
    footerWpt  = name;
    footerBrg  = '${brg.toStringAsFixed(0)}°';
    footerDist = rng.toStringAsFixed(0);
  }

  return Column(children: [
    _hdr('FLIGHT PLAN', 'MARK', _kRFg, _kRDim),
    // Column header
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: _kRDim.withValues(alpha: 0.15),
      child: Row(children: [
        SizedBox(width: 18, child: Text('#', style: TextStyle(color: _kRDim, fontSize: 7))),
        Expanded(child: Text('NAME', style: TextStyle(color: _kRDim, fontSize: 7))),
        SizedBox(width: 28, child: Text('RNG', style: TextStyle(color: _kRDim, fontSize: 7), textAlign: TextAlign.right)),
        SizedBox(width: 28, child: Text('BRG', style: TextStyle(color: _kRDim, fontSize: 7), textAlign: TextAlign.right)),
        const SizedBox(width: 22),
      ]),
    ),
    // Waypoint list
    Expanded(child: plan.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('NO WAYPOINTS', style: TextStyle(color: _kRDim, fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('TAP NAV MAP TO ADD', style: TextStyle(color: _kRDim.withValues(alpha: 0.5), fontSize: 7)),
        ]))
      : ListView(children: plan.indexed.map((entry) {
          final (i, wp) = entry;
          final (name, wx, wz) = wp;
          final dx   = wx - px; final dz = wz - pz;
          final rng  = math.sqrt(dx * dx + dz * dz);
          final brg  = ((math.atan2(dx, dz) * 180 / math.pi) + 360) % 360;
          final isTgt = i == state.flightPlanIndex && state.autopilotEnabled;
          final col  = isTgt ? _kAmber : _kRFg;
          final dim  = isTgt ? _kAmber : _kRDim;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(children: [
              SizedBox(width: 18, child: Text(
                isTgt ? '▶' : '${(i + 1).toString().padLeft(2, '0')}',
                style: TextStyle(color: dim, fontSize: 8),
              )),
              Expanded(child: Text(name, style: TextStyle(color: col, fontSize: 8))),
              SizedBox(width: 28, child: Text(rng.toStringAsFixed(0),
                  style: TextStyle(color: col, fontSize: 8), textAlign: TextAlign.right)),
              SizedBox(width: 28, child: Text('${brg.toStringAsFixed(0)}°',
                  style: TextStyle(color: dim, fontSize: 8), textAlign: TextAlign.right)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onDeleteWaypoint?.call(i),
                child: Container(
                  width: 18, height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0808),
                    border: Border.all(color: const Color(0xFF662222), width: 0.5),
                  ),
                  child: const Text('×', style: TextStyle(color: Color(0xFFCC4444), fontSize: 10)),
                ),
              ),
            ]),
          );
        }).toList()),
    ),
    // Footer: active target
    Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: _kRDim.withValues(alpha: 0.3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('TGT:$footerWpt',  style: TextStyle(color: plan.isNotEmpty ? _kRFg : _kRDim, fontSize: 8)),
        Text('BRG:$footerBrg',  style: TextStyle(color: plan.isNotEmpty ? _kAmber : _kRDim, fontSize: 8)),
        Text('DIST:$footerDist',style: TextStyle(color: plan.isNotEmpty ? _kAmber : _kRDim, fontSize: 8)),
      ]),
    ),
  ]);
}
