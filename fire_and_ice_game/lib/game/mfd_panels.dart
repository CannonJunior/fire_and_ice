import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'loadout_page.dart';
import 'mfd_pages.dart';

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

Widget _header(String title, String mode, Color fg, Color dim) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    color: dim.withValues(alpha: 0.4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: fg, fontSize: 18, letterSpacing: 1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          color: fg.withValues(alpha: 0.2),
          child: Text(mode, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.bold)),
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
      Text('SYS:WIND', style: TextStyle(color: _kLDim, fontSize: 8)),
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

// Deterministic terrain dot positions, computed once at module load.
final List<Offset> _terrainDots = List.generate(28, (i) {
  final r = math.Random(i * 31 + 7);
  return Offset(r.nextDouble(), r.nextDouble());
});

Widget buildRightMFD(
  GameState state, {
  int page = 0,
  Function(double, double)? onMapTap,
  Function(int)? onDeleteWaypoint,
}) {
  // Compute world offset to locked waypoint (for NAV map overlay)
  (double, double)? wpData;
  if (state.lockedWaypoint >= 0) {
    final (_, wx, wz) = GameState.kWaypoints[state.lockedWaypoint];
    wpData = (wx - state.playerPosition.x, wz - state.playerPosition.z);
  }

  final Widget body = switch (page) {
    1 => buildTerrPage(state),
    2 => buildFirePage(state),
    3 => buildMarkPage(state, onDeleteWaypoint: onDeleteWaypoint),
    _ => Column(children: [
        _header('TERRAIN NAV', 'NAV', _kRFg, _kRDim),
        Expanded(child: LayoutBuilder(
          builder: (context, constraints) {
            final mapW = constraints.maxWidth;
            final mapH = constraints.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onMapTap == null ? null : (details) {
                final zoom     = state.mapZoom;
                final ringBase = zoom == 1 ? 18.0 : zoom == 2 ? 42.0 : 28.0;
                const upr      = 30.0; // world units per ring
                final scale    = ringBase / upr;
                final cx       = mapW / 2;
                final cy       = mapH / 2;
                final sdx      = details.localPosition.dx - cx;
                final sdy      = details.localPosition.dy - cy;
                final headRad  = state.playerRotation.y * math.pi / 180.0;
                final relAngle = math.atan2(sdx, -sdy);
                final dist     = math.sqrt(sdx * sdx + sdy * sdy) / scale;
                final bearing  = relAngle + headRad;
                onMapTap(
                  state.playerPosition.x + math.sin(bearing) * dist,
                  state.playerPosition.z + math.cos(bearing) * dist,
                );
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
  final (double, double)? wpData;
  final List<(String, double, double)> flightPlan;
  final int flightPlanIndex;

  const _TerrainMap({
    required this.px, required this.pz, required this.heading,
    this.zoom = 0, this.wpData,
    this.flightPlan = const [],
    this.flightPlanIndex = 0,
  });

  Offset _toScreen(double wx, double wz, double cx, double cy,
      double scale, double headRad) {
    final dx = wx - px;
    final dz = wz - pz;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist <= 0) return Offset(cx, cy);
    final relAngle = math.atan2(dx, dz) - headRad;
    return Offset(
      cx + math.sin(relAngle) * dist * scale,
      cy - math.cos(relAngle) * dist * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx       = size.width / 2;
    final cy       = size.height / 2;
    final ringBase = zoom == 1 ? 18.0 : zoom == 2 ? 42.0 : 28.0;
    final headRad  = heading * math.pi / 180;
    const upr      = 30.0; // units per ring
    final scale    = ringBase / upr;

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

    // Range rings
    final rp = Paint()
      ..color = const Color(0xFF005577)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (final mult in [1.0, 2.0, 3.0]) {
      canvas.drawCircle(Offset(cx, cy), ringBase * mult, rp);
    }

    // Flight plan: connecting lines
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

    // Flight plan: dots + labels
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

    // Locked waypoint diamond overlay
    if (wpData != null) {
      final (dx, dz) = wpData!;
      final dist = math.sqrt(dx * dx + dz * dz);
      if (dist > 0) {
        final bearing  = math.atan2(dx, dz);
        final relAngle = bearing - headRad;
        final sdx = math.sin(relAngle) * dist * scale;
        final sdy = -math.cos(relAngle) * dist * scale;
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

    // Heading vector
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
      o.px != px || o.pz != pz || o.heading != heading || o.zoom != zoom ||
      o.wpData != wpData || o.flightPlan.length != flightPlan.length ||
      o.flightPlanIndex != flightPlanIndex;
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
