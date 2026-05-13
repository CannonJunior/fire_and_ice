import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'annunciator_panel.dart';
import 'attitude_gyro.dart';
import 'cockpit_drag.dart';
import 'game_state.dart';
import 'gear_lever.dart';
import 'hud_gauges.dart';
import 'hud_tutorial.dart';
import 'hud_widgets.dart' as hud;
import 'mfd_panels.dart';
import 'suppression_panel.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _kOsbBg    = Color(0xFF1A1A22);
const _kOsbBrd   = Color(0xFF3C3C4C);
const _kOsbTxt   = Color(0xFF6A6A8A);
const _kOsbActBrd = Color(0xFFAAAAAA);
const _kOsbActTxt = Color(0xFFCCCCFF);
const _kWarn     = Color(0xFFFF6600);
const _kHudGreen = Color(0xFF00FF88);
const _kHudDim   = Color(0xFF006644);

// ── Public entry ──────────────────────────────────────────────────────────────

/// Build the active HUD, switching between cockpit and third-person modes.
Widget buildCockpitHud(
  GameState state, {
  void Function(int index)? onAbilityActivate,
  void Function(int page)?  onLeftPage,
  void Function(int page)?  onRightPage,
  VoidCallback?             onMapZoom,
  VoidCallback?             onGearToggle,
  VoidCallback?             onFlapsToggle,
  VoidCallback?             onAutopilot,
  VoidCallback?             onWaypointLock,
  VoidCallback?             onClear,
  bool showAnnunciator  = true,
  bool showTelemetry    = true,
  bool showActionBar    = true,
  bool showTutorial     = false,
  bool cockpitDraggable = false,
  bool showCockpitInfo  = false,
  VoidCallback?             onSuppArm,
  VoidCallback?             onSuppAuto,
  VoidCallback?             onRetardantKnob,
  VoidCallback?             onRangeKnob,
  VoidCallback?             onSensorKnob,
  void Function(double, double)? onNavMapTap,
  void Function(int)?            onDeleteWaypoint,
}) {
  if (state.viewMode == ViewMode.thirdPerson) {
    return Stack(children: [
      hud.buildHud(state,
          showTelemetry: showTelemetry,
          showActionBar: showActionBar,
          showTutorial:  showTutorial),
      Positioned(top: 12, right: 115, child: Row(mainAxisSize: MainAxisSize.min, children: [
        _modeBadge(state.gameMode),
        const SizedBox(width: 6),
        _viewBadge('🎮 3RD PERSON'),
      ])),
    ]);
  }

  // Cockpit view — persistent corner gauges overlay the windshield so they
  // remain visible even though the cockpit panel occupies centre-bottom.
  return Stack(children: [
    IgnorePointer(child: _windshieldHud(state)),
    Align(
      alignment: Alignment.bottomCenter,
      child: _cockpitPanel(state,
          onAbilityActivate: onAbilityActivate,
          onLeftPage: onLeftPage,
          onRightPage: onRightPage,
          onMapZoom: onMapZoom,
          onGearToggle: onGearToggle,
          onFlapsToggle: onFlapsToggle,
          onAutopilot: onAutopilot,
          onWaypointLock: onWaypointLock,
          onClear: onClear,
          showAnnunciator:  showAnnunciator,
          cockpitDraggable: cockpitDraggable,
          showCockpitInfo:  showCockpitInfo,
          onSuppArm: onSuppArm,
          onSuppAuto: onSuppAuto,
          onRetardantKnob: onRetardantKnob,
          onRangeKnob: onRangeKnob,
          onSensorKnob: onSensorKnob,
          onNavMapTap: onNavMapTap,
          onDeleteWaypoint: onDeleteWaypoint),
    ),
    // Persistent gauges — spec §7: these survive the cockpit ↔ third-person
    // transition. Corner positions clear the centred cockpit panel.
    IgnorePointer(child: Stack(children: [
      WarningTextZone(state: state),
      Positioned(bottom: 12, left: 12,
          child: FireProximitySensor(state: state)),
      Positioned(bottom: 12, right: 12,
          child: HullIntegrityArc(state: state)),
      if (showTutorial) buildTutorialOverlay(state),
    ])),
    Positioned(top: 12, right: 115, child: Row(mainAxisSize: MainAxisSize.min, children: [
      _modeBadge(state.gameMode),
      const SizedBox(width: 6),
      _viewBadge('👁 COCKPIT'),
    ])),
  ]);
}

/// Mode badge — shows TAXI / FLIGHT / LANDING in a colour-coded chip.
Widget _modeBadge(GameMode mode) {
  final (String label, Color color) = switch (mode) {
    GameMode.taxi    => ('TAXI',    const Color(0xFF00CC44)),
    GameMode.flight  => ('FLIGHT',  const Color(0xFF4499FF)),
    GameMode.landing => ('LANDING', const Color(0xFFFFAA00)),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

/// Small top-right badge showing the active view mode (Tab to toggle).
Widget _viewBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFF334455)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Color(0xFF80DDFF), fontSize: 9, letterSpacing: 1),
    ),
  );
}

// ── Windshield HUD (glass overlay) ────────────────────────────────────────────

Widget _windshieldHud(GameState state) {
  return Stack(children: [
    // Speed readout — left edge, vertically centred in windshield area
    Positioned(left: 24, top: 0, bottom: 300,
        child: Center(child: _hudReadout('SPD',
            state.flightSpeed.toStringAsFixed(1), 'u/s'))),
    // Altitude readout — right edge
    Positioned(right: 24, top: 0, bottom: 300,
        child: Center(child: _hudReadout('ALT',
            state.flightAltitude.toStringAsFixed(1), 'm'))),
    // Heading / pitch strip — top centre
    Align(
      alignment: const Alignment(0, -0.80),
      child: _headingStrip(state),
    ),
    // Autopilot engaged banner
    if (state.autopilotEnabled)
      Align(
        alignment: const Alignment(0, -0.68),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          color: const Color(0xFF003300),
          child: Text(
            state.flightPlan.isEmpty
              ? '◆  A/P  ENGAGED  —  NO WAYPOINTS'
              : () {
                  final idx = state.flightPlanIndex.clamp(0, state.flightPlan.length - 1);
                  return '◆  A/P  ENGAGED  —  ${state.flightPlan[idx].$1}';
                }(),
            style: const TextStyle(
              color: Color(0xFF00FF88), fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 2,
            ),
          ),
        ),
      ),
    // Waypoint bearing readout (bottom-left of glass)
    if (state.lockedWaypoint >= 0)
      Positioned(left: 24, bottom: 310, child: _waypointHudReadout(state)),
    // Centre reticle
    Align(
      alignment: const Alignment(0, -0.10),
      child: CustomPaint(painter: _ReticlePainter(), size: const Size(60, 60)),
    ),
    // Barrel-roll warning
    if (state.isBarrelRolling)
      Align(
        alignment: const Alignment(0, -0.30),
        child: const Text('◀  BARREL ROLL  ▶',
            style: TextStyle(
              color: _kWarn, fontSize: 18,
              fontWeight: FontWeight.bold, letterSpacing: 4,
            )),
      ),
  ]);
}

Widget _waypointHudReadout(GameState state) {
  final (name, wx, wz) = GameState.kWaypoints[state.lockedWaypoint];
  final dx  = wx - state.playerPosition.x;
  final dz  = wz - state.playerPosition.z;
  final dist = math.sqrt(dx * dx + dz * dz);
  final brg  = ((math.atan2(dx, dz) * 180 / math.pi) + 360) % 360;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.4), width: 1),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('◆ $name', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 8, letterSpacing: 1)),
      Text('BRG ${brg.toStringAsFixed(0)}°  DIST ${dist.toStringAsFixed(0)}',
          style: const TextStyle(color: Color(0xFF00CC66), fontSize: 8)),
    ]),
  );
}

Widget _hudReadout(String label, String value, String unit) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: _kHudGreen.withValues(alpha: 0.4), width: 1),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: _kHudGreen.withValues(alpha: 0.6), fontSize: 8)),
      Text(value,  style: const TextStyle(color: _kHudGreen, fontSize: 14, fontWeight: FontWeight.bold)),
      Text(unit,   style: const TextStyle(color: _kHudDim, fontSize: 8)),
    ]),
  );
}

Widget _headingStrip(GameState state) {
  final hdg = ((state.playerRotation.y % 360) + 360) % 360;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: _kHudGreen.withValues(alpha: 0.4), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('HDG ', style: const TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${hdg.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      const Text('   PCH ', style: TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${state.flightPitchAngle.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      const Text('   BNK ', style: TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${state.flightBankAngle.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()..style = PaintingStyle.stroke;
    // Dim outer ring
    canvas.drawCircle(c, 24, stroke..color = _kHudDim..strokeWidth = 1);
    // Inner dot
    canvas.drawCircle(c, 2.5,
        Paint()..color = _kHudGreen..style = PaintingStyle.fill);
    // Cross hairs
    stroke.color = _kHudGreen; stroke.strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx - 30, c.dy), Offset(c.dx - 10, c.dy), stroke);
    canvas.drawLine(Offset(c.dx + 10, c.dy), Offset(c.dx + 30, c.dy), stroke);
    canvas.drawLine(Offset(c.dx, c.dy - 30), Offset(c.dx, c.dy - 10), stroke);
    canvas.drawLine(Offset(c.dx, c.dy + 10), Offset(c.dx, c.dy + 30), stroke);
  }

  @override
  bool shouldRepaint(_ReticlePainter _) => false;
}

// ── Cockpit Panel ─────────────────────────────────────────────────────────────

Widget _cockpitPanel(GameState state, {
  void Function(int)? onAbilityActivate,
  void Function(int)? onLeftPage,
  void Function(int)? onRightPage,
  VoidCallback?       onMapZoom,
  VoidCallback?       onGearToggle,
  VoidCallback?       onFlapsToggle,
  VoidCallback?       onAutopilot,
  VoidCallback?       onWaypointLock,
  VoidCallback?       onClear,
  bool showAnnunciator  = true,
  bool cockpitDraggable = false,
  bool showCockpitInfo  = false,
  VoidCallback?       onSuppArm,
  VoidCallback?       onSuppAuto,
  VoidCallback?       onRetardantKnob,
  VoidCallback?       onRangeKnob,
  VoidCallback?       onSensorKnob,
  void Function(double, double)? onNavMapTap,
  void Function(int)?            onDeleteWaypoint,
}) {
  final lp = state.leftMfdPage;
  final rp = state.rightMfdPage;
  final gearLeft = state.gearLeverOnLeft;
  // No solid panel background — each instrument carries its own colour.
  // Transparent gaps let the WebGL scene show through between components.
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // SeaBird: gear lever sits flush left of the left console
        if (gearLeft) ...[
          CockpitDragGroup(label: 'Gear (Ext)', draggable: cockpitDraggable, showInfo: showCockpitInfo,
            child: buildGearLever(state, onTap: onGearToggle)),
          const SizedBox(width: 8),
        ],
        // Left MFD column
        CockpitDragGroup(label: 'Left MFD', draggable: cockpitDraggable, showInfo: showCockpitInfo,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: _osbRow([
              _Osb('ELMT', active: lp == 0, onTap: () => onLeftPage?.call(0)),
              _Osb('LOAD', active: lp == 1, onTap: () => onLeftPage?.call(1)),
              _Osb('STAT', active: lp == 2, onTap: () => onLeftPage?.call(2)),
              _Osb('MODE', active: lp == 3, onTap: () => onLeftPage?.call(3)),
            ])),
            const SizedBox(height: 4),
            buildLeftMFD(state, page: lp),
            const SizedBox(height: 4),
            Center(child: _abilityOsbRow(state, onAbilityActivate)),
          ])),
        const SizedBox(width: 20),
        // Centre console
        CockpitDragGroup(label: 'Centre Console', draggable: cockpitDraggable, showInfo: showCockpitInfo,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showAnnunciator) buildAnnunciatorPanel(state),
            if (showAnnunciator) const SizedBox(height: 4),
            buildCenterMFD(state),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              buildSuppressionPanel(state,
                  onSuppArm: onSuppArm, onSuppAuto: onSuppAuto,
                  onRetardantKnob: onRetardantKnob,
                  onRangeKnob: onRangeKnob, onSensorKnob: onSensorKnob),
              const SizedBox(width: 8),
              buildFlapsLever(state, onTap: onFlapsToggle),
              if (!gearLeft) ...[
                const SizedBox(width: 4),
                buildGearLever(state, onTap: onGearToggle),
              ],
              const SizedBox(width: 4),
              buildThrottleGauge(state),
            ]),
            const SizedBox(height: 4),
            buildAttitudeGyro(state),
          ])),
        const SizedBox(width: 20),
        // Right MFD column
        CockpitDragGroup(label: 'Right MFD', draggable: cockpitDraggable, showInfo: showCockpitInfo,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: _osbRow([
              _Osb('NAV',  active: rp == 0, onTap: () => onRightPage?.call(0)),
              _Osb('TERR', active: rp == 1, onTap: () => onRightPage?.call(1)),
              _Osb('FIRE', active: rp == 2, onTap: () => onRightPage?.call(2)),
              _Osb('MARK', active: rp == 3, onTap: () => onRightPage?.call(3)),
            ])),
            const SizedBox(height: 4),
            buildRightMFD(state, page: rp,
                onMapTap: onNavMapTap, onDeleteWaypoint: onDeleteWaypoint),
            const SizedBox(height: 4),
            Center(child: _osbRow([
              _Osb('ZOOM', onTap: onMapZoom),
              _Osb('AUTO', active: state.autopilotEnabled,    onTap: onAutopilot),
              _Osb('LOCK', active: state.lockedWaypoint >= 0, onTap: onWaypointLock),
              _Osb('CLR',  onTap: onClear),
            ])),
          ])),
      ]),
  );
}

// ── OSB helpers ───────────────────────────────────────────────────────────────

class _Osb {
  final String label;
  final bool active;
  final bool alert;
  final VoidCallback? onTap;
  _Osb(this.label, {this.active = false, this.alert = false, this.onTap});
}

Widget _osbRow(List<_Osb> buttons) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: buttons.map((b) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _osbButton(b),
    )).toList(),
  );
}

Widget _osbButton(_Osb b) {
  final borderColor = b.alert ? _kWarn : (b.active ? _kOsbActBrd : _kOsbBrd);
  final textColor   = b.alert ? _kWarn : (b.active ? _kOsbActTxt : _kOsbTxt);
  return GestureDetector(
    onTap: b.onTap,
    child: Container(
      width: 38, height: 28,
      decoration: BoxDecoration(
        color: _kOsbBg,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(child: Text(
        b.label,
        style: TextStyle(
          color: textColor, fontSize: 7.5,
          fontWeight: FontWeight.bold, letterSpacing: 0.5,
        ),
      )),
    ),
  );
}

/// Bottom OSB row for the left MFD, wired to ability slot activation.
Widget _abilityOsbRow(GameState state, void Function(int)? onActivate) {
  final osbs = List.generate(math.min(state.abilities.length, 4), (i) {
    final ab    = state.abilities[i];
    final cd    = state.abilityCooldowns[ab.name] ?? 0.0;
    final ready = cd <= 0.0;
    final label = _abilityOsbLabel(ab.name);
    return _Osb(
      label,
      active: ready,
      alert: !ready,
      onTap: ready ? () => onActivate?.call(i) : null,
    );
  });
  while (osbs.length < 4) osbs.add(_Osb('----'));
  return _osbRow(osbs);
}

/// Derive a ≤4-char OSB label from an ability name.
///
/// Prefers the first word when it is 4+ characters (e.g. "Fire" → "FIRE"),
/// otherwise falls back to the last word (e.g. "Ice" → "NOVA").
String _abilityOsbLabel(String name) {
  final parts = name.split(' ');
  final word  = (parts.first.length >= 4) ? parts.first : parts.last;
  return word.substring(0, math.min(4, word.length)).toUpperCase();
}

