import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
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

// ── Zoom level tables (7 levels: 0 = farthest out, 6 = closest in) ────────────

/// Ring-base pixel radius for each zoom level; also sets map scale via /30.
const _kZoomRingBases = [6.0, 10.0, 18.0, 28.0, 42.0, 66.0, 105.0];

/// Footer label for each zoom level.
const _kZoomLabels = ['¼×', '⅓×', '½×', '1×', '1½×', '2×', '3½×'];

const _kZoomCount = 7;

// ── Right MFD – Terrain Navigation ───────────────────────────────────────────

Widget buildRightMFD(
  GameState state, {
  int page = 0,
  Function(double, double)? onMapTap,
  Function(int)? onDeleteWaypoint,
  VoidCallback? onOrientToggle,
  VoidCallback? onToggleSidebar,
  VoidCallback? onToggleFireHeatmap,
  VoidCallback? onToggleTreeHeatmap,
  VoidCallback? onToggleLabels,
  void Function(int delta)? onZoomDelta,
  List<(double, double, int)> treeSnapshot = const [],
}) {
  // Compute world offset to locked waypoint (for NAV map overlay)
  (double, double)? wpData;
  if (state.lockedWaypoint >= 0) {
    final (_, wx, wz) = GameState.kWaypoints[state.lockedWaypoint];
    wpData = (wx - state.playerPosition.x, wz - state.playerPosition.z);
  }
  final wyvernPositions = [
    for (final w in state.wyverns) if (!w.isDying) (w.id, w.position.x, w.position.z),
  ];
  final fireMarkers = [
    for (int i = 0; i < GameState.firePositions.length; i++)
      if (!state.fireExtinguished[i])
        ('fire_$i', GameState.firePositions[i].$1, GameState.firePositions[i].$2),
  ];

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
            return Stack(children: [
              GestureDetector(
                onTapDown: onMapTap == null ? null : (details) {
                  final lx = details.localPosition.dx, ly = details.localPosition.dy;
                  if (lx < 0 || lx > mapW || ly < 0 || ly > mapH) return;
                  final scale = _kZoomRingBases[state.mapZoom.clamp(0, _kZoomCount - 1)] / 30.0;
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
                  size: Size(mapW, mapH),
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
                    fireMarkers: fireMarkers,
                    selectedTargetId: state.selectedTargetId,
                    treeSnapshot: treeSnapshot,
                    showFireHeatmap: state.navFireHeatmap,
                    showTreeHeatmap: state.navTreeHeatmap,
                    showLabels: state.navLabels,
                  ),
                  child: Container(),
                ),
              ),
              Positioned(
                right: 0, top: 0, bottom: 0,
                child: _NavSidebar(
                  open: state.navSidebarOpen,
                  fireOn: state.navFireHeatmap,
                  treeOn: state.navTreeHeatmap,
                  labelsOn: state.navLabels,
                  onToggle: onToggleSidebar ?? () {},
                  onToggleFire: onToggleFireHeatmap ?? () {},
                  onToggleTree: onToggleTreeHeatmap ?? () {},
                  onToggleLabels: onToggleLabels ?? () {},
                ),
              ),
            ]);
          },
        )),
        _navFooter(state),
      ]),
  };
  final mfd = Container(
    width: 560, height: 400,
    decoration: BoxDecoration(color: _kRBg, border: Border.all(color: _kBevel, width: 2)),
    child: body,
  );
  if (onZoomDelta == null) return mfd;
  return Listener(
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
        onZoomDelta(event.scrollDelta.dy < 0 ? 1 : -1);
      }
    },
    child: mfd,
  );
}

Widget _navFooter(GameState state) {
  final hdg  = ((state.playerRotation.y % 360) + 360) % 360;
  final zoom = _kZoomLabels[state.mapZoom.clamp(0, _kZoomCount - 1)];
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

// ── NAV overlay sidebar ───────────────────────────────────────────────────────

class _NavSidebar extends StatelessWidget {
  final bool open;
  final bool fireOn;
  final bool treeOn;
  final bool labelsOn;
  final VoidCallback onToggle;
  final VoidCallback onToggleFire;
  final VoidCallback onToggleTree;
  final VoidCallback onToggleLabels;

  const _NavSidebar({
    required this.open,
    required this.fireOn,
    required this.treeOn,
    required this.labelsOn,
    required this.onToggle,
    required this.onToggleFire,
    required this.onToggleTree,
    required this.onToggleLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (!open) {
      // Collapsed: narrow vertical tab on the right edge
      return GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 16,
          decoration: BoxDecoration(
            color: _kRDim.withValues(alpha: 0.85),
            border: Border(left: BorderSide(color: _kRDim, width: 1)),
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text('HM ◀',
                  style: TextStyle(color: _kRFg, fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: _kRBg.withValues(alpha: 0.94),
        border: Border(left: BorderSide(color: _kRDim, width: 1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header row with collapse button
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 22,
            color: _kRDim.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(child: Text('OVLY',
                  style: TextStyle(color: _kRFg, fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8))),
              Text('▶', style: TextStyle(color: _kRFg, fontSize: 9)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _toggle('FIRE', fireOn, onToggleFire),
        const SizedBox(height: 6),
        _toggle('TREE', treeOn, onToggleTree),
        const SizedBox(height: 6),
        _toggle('LBL',  labelsOn, onToggleLabels),
      ]),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    final fg = active ? _kRFg : _kRDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kRFg.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: fg, width: 1),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(color: fg, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(active ? 'ON' : 'OFF',
              style: TextStyle(color: fg, fontSize: 9)),
        ]),
      ),
    );
  }
}

// ── Terrain map painter ───────────────────────────────────────────────────────

class _TerrainMap extends CustomPainter {
  final double px, pz, heading;
  final int zoom;
  final (double, double)? wpData;
  final List<(String, double, double)> flightPlan;
  final int flightPlanIndex;
  final bool northUp;
  final List<(String, double, double)> wyvernPositions;
  final List<(String, double, double)> fireMarkers;  // (id, wx, wz) active fires
  final String? selectedTargetId;
  final List<(double, double, int)> treeSnapshot;    // (wx, wz, stateIndex)
  final bool showFireHeatmap;
  final bool showTreeHeatmap;
  final bool showLabels;

  const _TerrainMap({
    required this.px, required this.pz, required this.heading,
    this.zoom = 0, this.wpData,
    this.flightPlan = const [],
    this.flightPlanIndex = 0,
    this.northUp = true,
    this.wyvernPositions = const [],
    this.fireMarkers = const [],
    this.selectedTargetId,
    this.treeSnapshot = const [],
    this.showFireHeatmap = true,
    this.showTreeHeatmap = true,
    this.showLabels = true,
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
    final ringBase = _kZoomRingBases[zoom.clamp(0, _kZoomCount - 1)];
    final headRad  = heading * math.pi / 180;
    final scale    = ringBase / 30.0;

    // Grid
    final gp = Paint()..color = const Color(0xFF003355)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }

    if (showFireHeatmap) _drawFireHeat(canvas, cx, cy, scale, headRad);
    _drawContours(canvas, size, cx, cy, scale, headRad);
    if (showTreeHeatmap) _drawTreeDots(canvas, cx, cy, scale, headRad);

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

    // Fire zone markers — small orange triangles
    final fmP = Paint()..color = const Color(0xFFFF6600)..style = PaintingStyle.fill;
    for (final (fid, fx, fz) in fireMarkers) {
      final fs = _toScreen(fx, fz, cx, cy, scale, headRad);
      final path = Path()
        ..moveTo(fs.dx, fs.dy - 6)
        ..lineTo(fs.dx + 5, fs.dy + 4)
        ..lineTo(fs.dx - 5, fs.dy + 4)
        ..close();
      canvas.drawPath(path, fmP);
      if (fid == selectedTargetId) {
        canvas.drawCircle(fs, 10, Paint()..color = const Color(0xFFFFAA00)..strokeWidth = 1.5..style = PaintingStyle.stroke);
      }
    }

    // Wyvern markers — orange X; ring around selected target
    final wyP = Paint()..color = const Color(0xFFFF5500)..strokeWidth = 2..style = PaintingStyle.stroke;
    for (final (wid, wx, wz) in wyvernPositions) {
      final ws = _toScreen(wx, wz, cx, cy, scale, headRad);
      canvas.drawLine(Offset(ws.dx-5,ws.dy-5),Offset(ws.dx+5,ws.dy+5),wyP);
      canvas.drawLine(Offset(ws.dx+5,ws.dy-5),Offset(ws.dx-5,ws.dy+5),wyP);
      if (wid == selectedTargetId) {
        canvas.drawCircle(ws, 10, Paint()..color = const Color(0xFFFF8800)..strokeWidth = 1.5..style = PaintingStyle.stroke);
      }
    }

    final abP = Paint()..color = const Color(0xFF4488FF)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final abS = _toScreen(0.0, -55.0, cx, cy, scale, headRad);
    canvas.drawCircle(abS, 5, abP);
    canvas.drawLine(Offset(abS.dx - 9, abS.dy), Offset(abS.dx + 9, abS.dy), abP);
    canvas.drawLine(Offset(abS.dx, abS.dy - 9), Offset(abS.dx, abS.dy + 9), abP);

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

    if (showLabels) _drawDeclutteredLabels(canvas, size, cx, cy, scale, headRad, abS);
  }

  // Greedy label declutter — collects all icon labels, then places each at the
  // first candidate offset that doesn't overlap any already-placed label rect.
  // Candidate offsets are tried upper-right first, falling back clockwise.
  // A thin leader line is drawn when the label is displaced from its default slot.
  void _drawDeclutteredLabels(Canvas canvas, Size size, double cx, double cy,
      double scale, double headRad, Offset abS) {
    // Accumulate (screen pos, text, color, bold) for every labeled icon.
    final entries = <({Offset pos, String text, Color color, bool bold})>[];

    // Waypoints
    for (int i = 0; i < flightPlan.length; i++) {
      final (name, wx, wz) = flightPlan[i];
      final pos   = _toScreen(wx, wz, cx, cy, scale, headRad);
      final isTgt = i == flightPlanIndex;
      entries.add((
        pos: pos,
        text: name,
        color: isTgt ? const Color(0xFF00FF88) : const Color(0xFF00AAFF),
        bold: isTgt,
      ));
    }

    // Fire markers — 'fire_0' → 'F1'
    for (final (fid, fx, fz) in fireMarkers) {
      final fs  = _toScreen(fx, fz, cx, cy, scale, headRad);
      final num = int.tryParse(fid.replaceAll('fire_', '')) ?? 0;
      entries.add((pos: fs, text: 'F${num + 1}',
          color: const Color(0xFFFF8833), bold: false));
    }

    // Wyverns — 'wyvern_alpha' → 'ALPH'
    for (final (wid, wx, wz) in wyvernPositions) {
      final ws     = _toScreen(wx, wz, cx, cy, scale, headRad);
      final suffix = wid.contains('_') ? wid.split('_').last.toUpperCase() : wid.toUpperCase();
      entries.add((
        pos: ws,
        text: suffix.length > 4 ? suffix.substring(0, 4) : suffix,
        color: const Color(0xFFFF7744),
        bold: false,
      ));
    }

    // Airbase
    entries.add((pos: abS, text: 'BASE', color: const Color(0xFF4488FF), bold: false));

    const fontSize = 10.0;
    final leaderP = Paint()..strokeWidth = 0.5;
    final placed  = <Rect>[];

    for (final e in entries) {
      final tp = TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(color: e.color, fontSize: fontSize,
              fontWeight: e.bold ? FontWeight.bold : FontWeight.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width, h = tp.height;

      // Candidate offsets from icon center, tried in preference order.
      final candidates = [
        Offset(7, -h - 2),       // upper-right (default)
        Offset(7, 3),             // lower-right
        Offset(-w - 7, -h - 2),  // upper-left
        Offset(-w - 7, 3),        // lower-left
        Offset(-w / 2, -h - 9),  // above center
        Offset(-w / 2, 9),        // below center
        Offset(7, -h / 2),        // right center
        Offset(-w - 7, -h / 2),  // left center
      ];

      Offset chosen = candidates[0]; // default — placed even if it overlaps
      bool isDefault = true;
      bool didPlace  = false;
      for (final off in candidates) {
        final r = Rect.fromLTWH(e.pos.dx + off.dx, e.pos.dy + off.dy, w, h);
        if (r.left < 0 || r.right > size.width || r.top < 0 || r.bottom > size.height) continue;
        if (placed.every((p) => !p.overlaps(r))) {
          chosen = off;
          isDefault = off == candidates[0];
          placed.add(r);
          didPlace = true;
          break;
        }
      }
      if (!didPlace) {
        // All candidates overlapped — use default and register it so
        // subsequent labels still see it as occupied.
        placed.add(Rect.fromLTWH(e.pos.dx + chosen.dx, e.pos.dy + chosen.dy, w, h));
      }

      // Leader line when displaced from the default upper-right slot.
      if (!isDefault) {
        leaderP.color = e.color.withValues(alpha: 0.45);
        final labelCenter = Offset(
          e.pos.dx + chosen.dx + w / 2,
          e.pos.dy + chosen.dy + h / 2,
        );
        canvas.drawLine(e.pos, labelCenter, leaderP);
      }

      tp.paint(canvas, Offset(e.pos.dx + chosen.dx, e.pos.dy + chosen.dy));
    }
  }

  // Fire heat layer: wide semi-transparent glow circles drawn under contours.
  // Overlapping circles accumulate into a heat-density map for burning areas.
  void _drawFireHeat(Canvas canvas, double cx, double cy, double scale, double headRad) {
    if (treeSnapshot.isEmpty) return;
    final heatP = Paint()..color = const Color(0x1AFF3300)..style = PaintingStyle.fill;
    final glowP = Paint()..color = const Color(0x33FF5500)..style = PaintingStyle.fill;
    for (final (tx, tz, state) in treeSnapshot) {
      if (state != 1) continue;
      final s = _toScreen(tx, tz, cx, cy, scale, headRad);
      canvas.drawCircle(s, 16.0, heatP); // wide density accumulator
      canvas.drawCircle(s,  6.0, glowP); // tighter core glow
    }
  }

  // Tree dot layer: individual position markers drawn above contours.
  // Alive/charred trees are sampled (every 3rd) to keep draw count low; all
  // burning trees are always drawn since there are typically very few.
  void _drawTreeDots(Canvas canvas, double cx, double cy, double scale, double headRad) {
    if (treeSnapshot.isEmpty) return;
    final aliveP   = Paint()..color = const Color(0x6622AA44)..style = PaintingStyle.fill;
    final burningP = Paint()..color = const Color(0xFFFF7722)..style = PaintingStyle.fill;
    final charredP = Paint()..color = const Color(0x55443322)..style = PaintingStyle.fill;
    int i = 0;
    for (final (tx, tz, state) in treeSnapshot) {
      i++;
      if (state == 0 && i % 3 != 0) continue; // thin alive/charred to ~1/3 density
      if (state == 2 && i % 3 != 0) continue;
      final s = _toScreen(tx, tz, cx, cy, scale, headRad);
      switch (state) {
        case 0: canvas.drawCircle(s, 1.5, aliveP);
        case 1: canvas.drawCircle(s, 2.0, burningP);
        case 2: canvas.drawCircle(s, 1.5, charredP);
      }
    }
  }

  // Marching-squares contour lines at 2/4/6/8/10 m elevation.
  void _drawContours(Canvas c, Size sz, double cx, double cy, double sc, double hr) {
    const step = 8.0;
    final hw = sz.width/(2*sc)+16, hh = sz.height/(2*sc)+16;
    final cols = (hw*2/step).ceil(), rows = (hh*2/step).ceil();
    // Sample height grid once; reused across all levels.
    final hg = List.generate(rows+1, (r) => List.generate(cols+1,
        (k) => TerrainGenerator.heightAt(px-hw+k*step, pz-hh+r*step)));
    for (int li = 0; li < 5; li++) {
      final lv = 2.0 + li*2;
      final cp = Paint()
        ..color = Color.fromRGBO(0, 120+li*20, 80+li*8, 0.25+li*0.08)
        ..strokeWidth = li < 2 ? 0.5 : 0.7;
      for (int r = 0; r < rows; r++) for (int k = 0; k < cols; k++) {
        final h00=hg[r][k], h10=hg[r][k+1], h01=hg[r+1][k], h11=hg[r+1][k+1];
        final x0=px-hw+k*step, z0=pz-hh+r*step;
        final pts=<Offset>[];
        if((h00>lv)!=(h10>lv)){final t=(lv-h00)/(h10-h00);pts.add(_toScreen(x0+t*step,z0,cx,cy,sc,hr));}
        if((h10>lv)!=(h11>lv)){final t=(lv-h10)/(h11-h10);pts.add(_toScreen(x0+step,z0+t*step,cx,cy,sc,hr));}
        if((h01>lv)!=(h11>lv)){final t=(lv-h01)/(h11-h01);pts.add(_toScreen(x0+t*step,z0+step,cx,cy,sc,hr));}
        if((h00>lv)!=(h01>lv)){final t=(lv-h00)/(h01-h00);pts.add(_toScreen(x0,z0+t*step,cx,cy,sc,hr));}
        if(pts.length==2) c.drawLine(pts[0],pts[1],cp);
        else if(pts.length==4){c.drawLine(pts[0],pts[3],cp);c.drawLine(pts[1],pts[2],cp);}
      }
    }
  }

  @override
  bool shouldRepaint(_TerrainMap o) =>
      // Only repaint for meaningful position change (> 1.0 world units) to
      // reduce 2D canvas work — the tree overlay makes every-frame repaint expensive.
      (o.px - px).abs() > 1.0 || (o.pz - pz).abs() > 1.0 ||
      o.heading != heading || o.zoom != zoom ||
      o.wpData != wpData || o.flightPlan.length != flightPlan.length ||
      o.flightPlanIndex != flightPlanIndex || o.northUp != northUp ||
      o.wyvernPositions.length != wyvernPositions.length ||
      o.fireMarkers.length != fireMarkers.length ||
      o.selectedTargetId != selectedTargetId ||
      o.treeSnapshot.length != treeSnapshot.length ||
      o.showFireHeatmap != showFireHeatmap ||
      o.showTreeHeatmap != showTreeHeatmap ||
      o.showLabels != showLabels;
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
