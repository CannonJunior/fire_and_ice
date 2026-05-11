import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'mfd_pages.dart';

// ── Color palette ─────────────────────────────────────────────────────────────

const _kBevel = Color(0xFF2A3040);

// Left MFD — green phosphor
const _kLBg  = Color(0xFF001600);
const _kLFg  = Color(0xFF00FF41);
const _kLDim = Color(0xFF005519);

// Right MFD — navigation blue
const _kRBg  = Color(0xFF000E1A);
const _kRFg  = Color(0xFF00AAFF);
const _kRDim = Color(0xFF003366);

// Center MFD — amber data
const _kCBg    = Color(0xFF050510);
const _kCAmber = Color(0xFFFFB300);
const _kCDim   = Color(0xFF554400);

// ── Left MFD – Elemental Tactical ────────────────────────────────────────────

Widget buildLeftMFD(GameState state, {int page = 0}) {
  final Widget body = switch (page) {
    1 => buildAbltPage(state),
    2 => buildStatPage(state),
    3 => buildModePage(state),
    _ => Column(children: [
        _header('ELEMENTAL TACTICAL', 'ENRGY', _kLFg, _kLDim),
        Expanded(child: Row(children: [
          SizedBox(width: 90, child: _manaGauge(state)),
          Container(width: 1, color: _kLDim),
          Expanded(child: _abilityList(state)),
        ])),
        _leftFooter(state),
      ]),
  };
  return Container(
    width: 280, height: 220,
    decoration: BoxDecoration(color: _kLBg, border: Border.all(color: _kBevel, width: 2)),
    child: body,
  );
}

Widget _header(String title, String mode, Color fg, Color dim) {
  return Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: dim.withValues(alpha: 0.4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: fg, fontSize: 9, letterSpacing: 1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          color: fg.withValues(alpha: 0.2),
          child: Text(mode, style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Widget _manaGauge(GameState state) {
  final mf = state.mana / GameState.maxMana;
  final hf = state.health / GameState.maxHealth;
  return Padding(
    padding: const EdgeInsets.all(6),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 56, height: 56,
        child: CustomPaint(painter: _ArcGauge(fraction: mf, fg: _kLFg, dim: _kLDim)),
      ),
      const SizedBox(height: 3),
      Text('ENRGY', style: TextStyle(color: _kLDim, fontSize: 7)),
      Text('${(mf * 100).toInt()}%',
          style: TextStyle(color: _kLFg, fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      _miniBar('HP', hf),
    ]),
  );
}

Widget _miniBar(String label, double f) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: _kLDim, fontSize: 7)),
    Container(
      height: 5,
      decoration: BoxDecoration(
        color: _kLDim.withValues(alpha: 0.2),
        border: Border.all(color: _kLDim, width: 0.5),
      ),
      child: FractionallySizedBox(
        widthFactor: f.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(color: _kLFg),
      ),
    ),
  ]);
}

Widget _abilityList(GameState state) {
  return Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(state.abilities.length, (i) {
        final ab    = state.abilities[i];
        final cd    = state.abilityCooldowns[ab.name] ?? 0.0;
        final ready = cd <= 0.0;
        final col   = ready ? _kLFg : _kLDim;
        return Row(children: [
          Text(ab.icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Expanded(child: Text(
            ab.name.split(' ').last.toUpperCase(),
            style: TextStyle(color: col, fontSize: 8),
          )),
          if (!ready)
            Text('${cd.toStringAsFixed(1)}s',
                style: const TextStyle(color: Color(0xFFFFB300), fontSize: 7)),
          if (ready)
            Text('RDY', style: TextStyle(color: _kLFg, fontSize: 7, fontWeight: FontWeight.bold)),
        ]);
      }),
    ),
  );
}

Widget _leftFooter(GameState state) {
  final rolling = state.isBarrelRolling;
  return Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: _kLDim.withValues(alpha: 0.3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('SYS:WIND', style: TextStyle(color: _kLDim, fontSize: 8)),
      Text('ALT:${state.flightAltitude.toStringAsFixed(0)}m',
          style: TextStyle(color: _kLFg, fontSize: 8)),
      Text(
        rolling ? '!ROLL!' : 'FLT',
        style: TextStyle(
          color: rolling ? const Color(0xFFFF6600) : _kLDim,
          fontSize: 8, fontWeight: FontWeight.bold,
        ),
      ),
    ]),
  );
}

class _ArcGauge extends CustomPainter {
  final double fraction;
  final Color  fg, dim;
  const _ArcGauge({required this.fraction, required this.fg, required this.dim});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 3;
    final p = Paint()..strokeWidth = 3.5..style = PaintingStyle.stroke;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;
    p.color = dim;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), startAngle, sweepTotal, false, p);
    p.color = fg;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), startAngle, sweepTotal * fraction, false, p);
    p.color = dim; p.strokeWidth = 0.5;
    canvas.drawLine(Offset(c.dx - 7, c.dy), Offset(c.dx + 7, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 7), Offset(c.dx, c.dy + 7), p);
  }

  @override
  bool shouldRepaint(_ArcGauge o) => o.fraction != fraction;
}

// ── Right MFD – Terrain Navigation ───────────────────────────────────────────

// Deterministic terrain dot positions, computed once at module load.
final List<Offset> _terrainDots = List.generate(28, (i) {
  final r = math.Random(i * 31 + 7);
  return Offset(r.nextDouble(), r.nextDouble());
});

Widget buildRightMFD(GameState state, {int page = 0}) {
  final Widget body = switch (page) {
    1 => buildTerrPage(state),
    2 => buildTgtPage(state),
    3 => buildMarkPage(state),
    _ => Column(children: [
        _header('TERRAIN NAV', 'NAV', _kRFg, _kRDim),
        Expanded(child: CustomPaint(
          painter: _TerrainMap(
            px: state.playerPosition.x,
            pz: state.playerPosition.z,
            heading: state.playerRotation.y,
            zoom: state.mapZoom,
          ),
          child: Container(),
        )),
        _navFooter(state),
      ]),
  };
  return Container(
    width: 280, height: 220,
    decoration: BoxDecoration(color: _kRBg, border: Border.all(color: _kBevel, width: 2)),
    child: body,
  );
}

Widget _navFooter(GameState state) {
  final hdg  = ((state.playerRotation.y % 360) + 360) % 360;
  final zoom = const ['1×', '2×', '½×'][state.mapZoom.clamp(0, 2)];
  return Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: _kRDim.withValues(alpha: 0.3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('HDG:${hdg.toStringAsFixed(0)}°', style: const TextStyle(color: _kRFg, fontSize: 8)),
      Text('X:${state.playerPosition.x.toStringAsFixed(0)} '
           'Z:${state.playerPosition.z.toStringAsFixed(0)}',
          style: const TextStyle(color: _kRFg, fontSize: 8)),
      Text('ZOOM:$zoom', style: const TextStyle(color: _kRFg, fontSize: 8)),
    ]),
  );
}

class _TerrainMap extends CustomPainter {
  final double px, pz, heading;
  final int zoom;
  const _TerrainMap({required this.px, required this.pz, required this.heading, this.zoom = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Grid
    final gp = Paint()..color = const Color(0xFF003355)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }

    // Terrain blobs
    final dp = Paint()..color = const Color(0xFF004466)..style = PaintingStyle.fill;
    for (final d in _terrainDots) {
      canvas.drawCircle(Offset(d.dx * size.width, d.dy * size.height), 4, dp);
    }

    // Range rings — size varies by zoom (0=1×, 1=2×, 2=0.5×)
    final ringBase = zoom == 1 ? 18.0 : zoom == 2 ? 42.0 : 28.0;
    final rp = Paint()
      ..color = const Color(0xFF005577)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (final mult in [1.0, 2.0, 3.0]) {
      canvas.drawCircle(Offset(cx, cy), ringBase * mult, rp);
    }

    // Heading vector
    final headRad = heading * math.pi / 180;
    final hx = cx + math.sin(headRad) * 22;
    final hy = cy - math.cos(headRad) * 22;
    canvas.drawLine(Offset(cx, cy), Offset(hx, hy),
        Paint()..color = const Color(0xFF00DDFF)..strokeWidth = 1.5);

    // Player crosshair
    final cp = Paint()..color = const Color(0xFF00CCFF)..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx - 9, cy), Offset(cx + 9, cy), cp);
    canvas.drawLine(Offset(cx, cy - 9), Offset(cx, cy + 9), cp);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 6),
      Paint()
        ..color = const Color(0xFF00CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TerrainMap o) =>
      o.px != px || o.pz != pz || o.heading != heading || o.zoom != zoom;
}

// ── Center MFD – Flight Data ──────────────────────────────────────────────────

Widget buildCenterMFD(GameState state) {
  return Container(
    width: 200, height: 160,
    decoration: BoxDecoration(
      color: _kCBg,
      border: Border.all(color: _kBevel, width: 2),
    ),
    child: Column(children: [
      _header('FLIGHT DATA', 'FLT', _kCAmber, _kCDim),
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dataRow('ALT', '${state.flightAltitude.toStringAsFixed(1)} m'),
            _dataRow('SPD', '${state.flightSpeed.toStringAsFixed(1)} u/s'),
            _dataRow('PCH', '${state.flightPitchAngle.toStringAsFixed(1)}°'),
            _dataRow('BNK', '${state.flightBankAngle.toStringAsFixed(1)}°'),
          ],
        ),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Column(children: [
          _centerBar('HP', state.health / GameState.maxHealth, const Color(0xFFCC3333)),
          const SizedBox(height: 3),
          _centerBar('MP', state.mana / GameState.maxMana, const Color(0xFF3366CC)),
        ]),
      ),
    ]),
  );
}

Widget _dataRow(String label, String value) {
  return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: _kCDim, fontSize: 9)),
    Text(value,  style: const TextStyle(color: _kCAmber, fontSize: 9, fontWeight: FontWeight.bold)),
  ]);
}

Widget _centerBar(String label, double f, Color color) {
  return Row(children: [
    SizedBox(width: 16, child: Text(label, style: const TextStyle(color: _kCDim, fontSize: 7))),
    Expanded(child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A15),
        border: Border.all(color: const Color(0xFF223344), width: 0.5),
      ),
      child: FractionallySizedBox(
        widthFactor: f.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(color: color),
      ),
    )),
    const SizedBox(width: 4),
    SizedBox(
      width: 20,
      child: Text('${(f * 100).toInt()}', style: const TextStyle(color: _kCDim, fontSize: 7)),
    ),
  ]);
}
