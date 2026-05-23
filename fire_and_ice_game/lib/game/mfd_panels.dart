import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'loadout_page.dart';
import 'mfd_pages.dart';
import '../terrain/terrain_generator.dart';

// ── Color palette ─────────────────────────────────────────────────────────────

const _kBevel = Color(0xFF2A3040);

// Left MFD — green phosphor
const _kLBg    = Color(0xFF001600);
const _kLFg    = Color(0xFF00FF41);
const _kLDim   = Color(0xFF005519);
const _kLAmber = Color(0xFFFFB300);
const _kLWarn  = Color(0xFFFF4400);

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
    1 => buildLoadoutPage(state),
    2 => buildStatPage(state),
    3 => buildModePage(state),
    _ => Column(children: [
        _header('ELEMENTAL TACTICAL', 'ENRGY', _kLFg, _kLDim),
        Expanded(child: Row(children: [
          SizedBox(width: 180, child: _manaGauge(state)),
          Container(width: 1, color: _kLDim),
          Expanded(child: _abilityList(state)),
        ])),
        _leftFooter(state),
      ]),
  };
  return Container(
    width: 560, height: 400,
    decoration: BoxDecoration(color: _kLBg, border: Border.all(color: _kBevel, width: 2)),
    child: body,
  );
}

Widget _header(String title, String mode, Color fg, Color dim, {Widget? action}) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: dim.withValues(alpha: 0.4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: fg, fontSize: 18, letterSpacing: 1)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (action != null) ...[action, const SizedBox(width: 6)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: fg.withValues(alpha: 0.2),
            child: Text(mode, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
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
        width: 112, height: 112,
        child: CustomPaint(painter: _ArcGauge(fraction: mf, fg: _kLFg, dim: _kLDim)),
      ),
      const SizedBox(height: 3),
      Text('ENRGY', style: TextStyle(color: _kLDim, fontSize: 14)),
      Text('${(mf * 100).toInt()}%',
          style: TextStyle(color: _kLFg, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      _miniBar('HP', hf),
    ]),
  );
}

Widget _miniBar(String label, double f) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: _kLDim, fontSize: 14)),
    Container(
      height: 10,
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
    padding: const EdgeInsets.all(5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: state.abilities.map((ab) {
        final cd       = state.abilityCooldowns[ab.name] ?? 0.0;
        final charges  = ab.isExpendable ? (state.abilityCharges[ab.name] ?? ab.maxCharges) : null;
        final depleted = charges != null && charges <= 0;
        final onCD     = cd > 0.0;
        final ready    = !depleted && !onCD;

        final nameCol   = depleted ? _kLWarn : (ready ? _kLFg : _kLDim);
        final statusCol = depleted ? _kLWarn : (ready ? _kLFg : _kLAmber);

        // Status label: charge fraction for expendable, cooldown or RDY for rechargeable
        final String status;
        if (depleted)       status = 'EXPD';
        else if (onCD)      status = '${cd.toStringAsFixed(1)}s';
        else if (charges != null) status = '$charges/${ab.maxCharges}';
        else                status = 'RDY';

        return Row(children: [
          Text(ab.icon, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Expanded(child: Text(
            ab.name.split(' ').last.toUpperCase(),
            style: TextStyle(color: nameCol, fontSize: 14.5),
          )),
          Text(status, style: TextStyle(
            color: statusCol, fontSize: 14,
            fontWeight: ready || depleted ? FontWeight.bold : FontWeight.normal,
          )),
        ]);
      }).toList(),
    ),
  );
}

Widget _leftFooter(GameState state) {
  final rolling = state.isBarrelRolling;
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: _kLDim.withValues(alpha: 0.3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('W${state.windState.windFromDeg.toString().padLeft(3, '0')}°/${state.windState.windStrengthPct}%',
          style: TextStyle(color: _kLFg, fontSize: 8)),
      Text('ALT:${state.flightAltitude.toStringAsFixed(0)}m',
          style: TextStyle(color: _kLFg, fontSize: 8)),
      Text(
        rolling ? '!ROLL!' : 'FLT',
        style: TextStyle(
          color: rolling ? const Color(0xFFFF6600) : _kLDim,
          fontSize: 16, fontWeight: FontWeight.bold,
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

Widget buildRightMFD(
  GameState state, {
  int page = 0,
  Function(double, double)? onMapTap,
  Function(int)? onDeleteWaypoint,
  VoidCallback? onOrientToggle,
}) {
  // Compute world offset to locked waypoint (for NAV map overlay)
  (double, double)? wpData;
  if (state.lockedWaypoint >= 0) {
    final (_, wx, wz) = GameState.kWaypoints[state.lockedWaypoint];
    wpData = (wx - state.playerPosition.x, wz - state.playerPosition.z);
  }
  final wyvernPositions = [for (final w in state.wyverns) (w.position.x, w.position.z)];

  final Widget body = switch (page) {
    1 => buildTerrPage(state, onOrientToggle: onOrientToggle),
    2 => buildFirePage(state, onOrientToggle: onOrientToggle),
    3 => buildMarkPage(state, onDeleteWaypoint: onDeleteWaypoint),
    _ => Column(children: [
        _header('TERRAIN NAV', 'NAV', _kRFg, _kRDim, action: GestureDetector(
          onTap: onOrientToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: _kRDim.withValues(alpha: 0.5), border: Border.all(color: _kRFg.withValues(alpha: 0.7))),
            child: Text(state.mapNorthUp ? 'N↑' : 'HDG↑', style: const TextStyle(color: _kRFg, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        )),
        Expanded(child: LayoutBuilder(
          builder: (context, constraints) {
            final mapW = constraints.maxWidth;
            final mapH = constraints.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onMapTap == null ? null : (details) {
                final lx = details.localPosition.dx, ly = details.localPosition.dy;
                if (lx < 0 || lx > mapW || ly < 0 || ly > mapH) return;
                final scale = (state.mapZoom == 1 ? 18.0 : state.mapZoom == 2 ? 42.0 : 28.0) / 30.0;
                final sdx = lx - mapW / 2, sdy = ly - mapH / 2;
                if (state.mapNorthUp) {
                  onMapTap(state.playerPosition.x + sdx / scale, state.playerPosition.z + sdy / scale);
                } else {
                  final h = state.playerRotation.y * math.pi / 180;
                  onMapTap(state.playerPosition.x + (sdx * math.cos(h) + sdy * math.sin(h)) / scale,
                           state.playerPosition.z + (-sdx * math.sin(h) + sdy * math.cos(h)) / scale);
                }
              },
              child: CustomPaint(
                painter: _TerrainMap(
                  px: state.playerPosition.x,
                  pz: state.playerPosition.z,
                  heading: state.playerRotation.y,
                  zoom: state.mapZoom,
                  wpData: wpData,
                  flightPlan: state.flightPlan,
                  flightPlanIndex: state.flightPlanIndex,
                  northUp: state.mapNorthUp,
                  wyvernPositions: wyvernPositions,
                ),
                child: Container(),
              ),
            );
          },
        )),
        _navFooter(state),
      ]),
  };
  return Container(
    width: 560, height: 400,
    decoration: BoxDecoration(color: _kRBg, border: Border.all(color: _kBevel, width: 2)),
    child: body,
  );
}

Widget _navFooter(GameState state) {
  final hdg  = ((state.playerRotation.y % 360) + 360) % 360;
  final zoom = const ['1×', '2×', '½×'][state.mapZoom.clamp(0, 2)];
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: _kRDim.withValues(alpha: 0.3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('HDG:${hdg.toStringAsFixed(0)}°', style: const TextStyle(color: _kRFg, fontSize: 8)),
      Text('X:${state.playerPosition.x.toStringAsFixed(0)} Z:${state.playerPosition.z.toStringAsFixed(0)}',
          style: const TextStyle(color: _kRFg, fontSize: 8)),
      Text('ZOOM:$zoom', style: const TextStyle(color: _kRFg, fontSize: 8)),
    ]),
  );
}

class _TerrainMap extends CustomPainter {
  final double px, pz, heading;
  final int zoom;
  final (double, double)? wpData;
  final List<(String, double, double)> flightPlan;
  final int flightPlanIndex;
  final bool northUp;
  final List<(double, double)> wyvernPositions;

  const _TerrainMap({
    required this.px, required this.pz, required this.heading,
    this.zoom = 0, this.wpData,
    this.flightPlan = const [],
    this.flightPlanIndex = 0,
    this.northUp = true,
    this.wyvernPositions = const [],
  });

  Offset _toScreen(double wx, double wz, double cx, double cy,
      double scale, double headRad) {
    final dx = wx - px, dz = wz - pz;
    if (northUp) return Offset(cx + dx * scale, cy + dz * scale);
    return Offset(cx + (dx * math.cos(headRad) - dz * math.sin(headRad)) * scale,
                  cy + (dx * math.sin(headRad) + dz * math.cos(headRad)) * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final cx       = size.width / 2;
    final cy       = size.height / 2;
    final ringBase = zoom == 1 ? 18.0 : zoom == 2 ? 42.0 : 28.0;
    final headRad  = heading * math.pi / 180;
    final scale    = ringBase / 30.0;

    const step = 10;
    for (int sy = 0; sy < size.height.toInt(); sy += step) {
      for (int sx = 0; sx < size.width.toInt(); sx += step) {
        final sdx = sx - cx, sdy = sy - cy;
        final wx = px + (northUp ? sdx : sdx * math.cos(headRad) + sdy * math.sin(headRad)) / scale;
        final wz = pz + (northUp ? sdy : -sdx * math.sin(headRad) + sdy * math.cos(headRad)) / scale;
        final t = (TerrainGenerator.heightAt(wx, wz) / 12.0).clamp(0.0, 1.0);
        canvas.drawRect(Rect.fromLTWH(sx.toDouble(), sy.toDouble(), step.toDouble(), step.toDouble()),
            Paint()..color = Color.lerp(const Color(0xFF081A0C), const Color(0xFF2E5018), t)!);
      }
    }

    final rp = Paint()
      ..color = const Color(0xFF005577)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (final mult in [1.0, 2.0, 3.0]) {
      canvas.drawCircle(Offset(cx, cy), ringBase * mult, rp);
    }

    if (flightPlan.length > 1) {
      final lp = Paint()
        ..color = const Color(0xFF0088CC).withValues(alpha: 0.55)
        ..strokeWidth = 0.8;
      for (int i = 0; i < flightPlan.length - 1; i++) {
        final (_, wx1, wz1) = flightPlan[i];
        final (_, wx2, wz2) = flightPlan[i + 1];
        canvas.drawLine(
          _toScreen(wx1, wz1, cx, cy, scale, headRad),
          _toScreen(wx2, wz2, cx, cy, scale, headRad),
          lp,
        );
      }
    }

    for (int i = 0; i < flightPlan.length; i++) {
      final (name, wx, wz) = flightPlan[i];
      final pos    = _toScreen(wx, wz, cx, cy, scale, headRad);
      final isTgt  = i == flightPlanIndex;
      final color  = isTgt ? const Color(0xFF00FF88) : const Color(0xFF00AAFF);
      canvas.drawCircle(pos, isTgt ? 4.0 : 3.0,
          Paint()..color = color..style = PaintingStyle.fill);
      final tp = TextPainter(
        text: TextSpan(text: name,
            style: TextStyle(color: color, fontSize: 12,
                fontWeight: isTgt ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx + 5, pos.dy - 4));
    }

    if (wpData != null) {
      final (dx, dz) = wpData!;
      final dist = math.sqrt(dx * dx + dz * dz);
      if (dist > 0) {
        final sdx =  dx * scale;
        final sdy = -dz * scale;
        final maxR   = math.min(cx, cy) - 6;
        final sdist  = math.sqrt(sdx * sdx + sdy * sdy);
        final factor = sdist > maxR ? maxR / sdist : 1.0;
        final wpX = cx + sdx * factor;
        final wpY = cy + sdy * factor;
        canvas.drawLine(Offset(cx, cy), Offset(wpX, wpY),
            Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.55)
              ..strokeWidth = 0.8);
        final path = Path()
          ..moveTo(wpX,     wpY - 5)
          ..lineTo(wpX + 4, wpY)
          ..lineTo(wpX,     wpY + 5)
          ..lineTo(wpX - 4, wpY)
          ..close();
        canvas.drawPath(path,
            Paint()..color = const Color(0xFF00FF88)..style = PaintingStyle.fill);
      }
    }

    final abP = Paint()..color = const Color(0xFF4488FF)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final abS = _toScreen(0.0, -55.0, cx, cy, scale, headRad);
    canvas.drawCircle(abS, 5, abP);
    canvas.drawLine(Offset(abS.dx - 9, abS.dy), Offset(abS.dx + 9, abS.dy), abP);
    canvas.drawLine(Offset(abS.dx, abS.dy - 9), Offset(abS.dx, abS.dy + 9), abP);

    final wyP = Paint()..color = const Color(0xFFFF5500)..strokeWidth = 2..style = PaintingStyle.stroke;
    for (final (wx, wz) in wyvernPositions) {
      final ws = _toScreen(wx, wz, cx, cy, scale, headRad);
      canvas.drawLine(Offset(ws.dx - 5, ws.dy - 5), Offset(ws.dx + 5, ws.dy + 5), wyP);
      canvas.drawLine(Offset(ws.dx + 5, ws.dy - 5), Offset(ws.dx - 5, ws.dy + 5), wyP);
    }

    canvas.save();
    canvas.translate(cx, cy);
    if (northUp) canvas.rotate(-headRad); // negate: CCW game yaw vs CW canvas rotation
    final ap = Paint()..color = const Color(0xFF00DDFF)..strokeWidth = 1.5
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, -10), const Offset(-6, 6), ap);
    canvas.drawLine(const Offset(0, -10), const Offset( 6, 6), ap);
    canvas.drawLine(const Offset(-10, 1), const Offset(10, 1), ap);
    canvas.drawLine(const Offset(-4, 6), const Offset( 4, 6), ap);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TerrainMap o) =>
      o.px != px || o.pz != pz || o.heading != heading || o.zoom != zoom ||
      o.wpData != wpData || o.flightPlan.length != flightPlan.length ||
      o.flightPlanIndex != flightPlanIndex || o.northUp != northUp ||
      o.wyvernPositions.length != wyvernPositions.length;
}

// ── Center MFD – Flight Data ──────────────────────────────────────────────────

Widget buildCenterMFD(GameState state) {
  return Container(
    width: 400, height: 296,
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
            _dataRow('THR', '${(state.throttle * 100).round()}%'),
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
    Text(value,  style: const TextStyle(color: _kCAmber, fontSize: 18, fontWeight: FontWeight.bold)),
  ]);
}

Widget _centerBar(String label, double f, Color color) {
  return Row(children: [
    SizedBox(width: 32, child: Text(label, style: const TextStyle(color: _kCDim, fontSize: 14))),
    Expanded(child: Container(
      height: 12,
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
      width: 40,
      child: Text('${(f * 100).toInt()}', style: const TextStyle(color: _kCDim, fontSize: 14)),
    ),
  ]);
}
