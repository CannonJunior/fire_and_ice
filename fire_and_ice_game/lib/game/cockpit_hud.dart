import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'annunciator_panel.dart';
import 'aoa_indicator.dart';
import 'attitude_gyro.dart';
import 'cockpit_drag.dart';
import 'game_state.dart';
import 'settings_state.dart';
import 'drogue_lever.dart';
import 'gear_lever.dart';
import 'probe_lever.dart';
import 'hud_gauges.dart';
import 'hud_tutorial.dart';
import 'mana_arc.dart';
import 'hud_widgets.dart' as hud;
import 'mfd_panels.dart';
import 'suppression_panel.dart';
import 'throttle_quadrant.dart';
import 'alt_indicator.dart';
import 'aux_display.dart';
import 'lvr_lever.dart';

// Colors

const _kOsbBg    = Color(0xFF1A1A22);
const _kOsbBrd   = Color(0xFF3C3C4C);
const _kOsbTxt   = Color(0xFF6A6A8A);
const _kOsbActBrd = Color(0xFFAAAAAA);
const _kOsbActTxt = Color(0xFFCCCCFF);
const _kWarn     = Color(0xFFFF6600);

const _kImcAmber  = Color(0xFFFF8800);
const _kSmkYellow = Color(0xFFFFCC00);

/// Row of mode/view/smoke badges for placement alongside the top-right menu buttons.
Widget buildStatusBadgeRow(GameState state, {bool disableHaze = false}) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    _modeBadge(state.gameMode),
    const SizedBox(width: 6),
    _viewBadge(state.viewMode == ViewMode.thirdPerson ? '🎮 3RD PERSON' : '👁 COCKPIT'),
    if (!disableHaze && state.smokeOpacity > 0.40) ...[const SizedBox(width: 6), _smokeLevelBadge(state.smokeOpacity)],
  ],
);

/// Build the active HUD, switching between cockpit and third-person modes.
Widget buildCockpitHud(
  GameState state, {
  void Function(int index)? onAbilityActivate,
  void Function(int page)?  onLeftPage,
  void Function(int page)?  onRightPage,
  VoidCallback?             onMapZoom,
  VoidCallback?             onGearToggle,
  VoidCallback?             onFlapsToggle,
  VoidCallback?             onProbeToggle,
  VoidCallback?             onDrogueToggle,
  VoidCallback?             onAutopilot,
  VoidCallback?             onWaypointLock,
  VoidCallback?             onClear,
  bool showAnnunciator = true,
  bool showTelemetry   = true,
  bool showActionBar   = true,
  bool showTutorial    = false,
  SettingsState? settings,
  VoidCallback?  onLayoutChanged,
  VoidCallback?             onSuppArm,
  VoidCallback?             onSuppAuto,
  VoidCallback?             onRetardantKnob,
  VoidCallback?             onRangeKnob,
  VoidCallback?             onSensorKnob,
  void Function(double, double)? onNavMapTap,
  void Function(int)?            onDeleteWaypoint,
  VoidCallback?                  onAnnunciatorChange,
  VoidCallback?                  onThrottleModeToggle,
  void Function(double)?         onThrottleChange,
  void Function(int)? onAuxPage, void Function(int)? onAuxMirrorScroll, void Function(int)? onAuxVideoScroll,
  void Function(int)? onManeuverScroll, void Function()? onManeuverExecute, void Function()? onManeuverStop,
  VoidCallback? onOrientToggle,
  VoidCallback? onLvrToggle,
  VoidCallback? onToggleNavSidebar,
  VoidCallback? onToggleFireHeatmap,
  VoidCallback? onToggleTreeHeatmap,
  List<(double, double, int)> treeSnapshot = const [],
}) {
  if (state.viewMode == ViewMode.thirdPerson) {
    return Stack(children: [
      hud.buildHud(state,
          showTelemetry: showTelemetry,
          showActionBar: showActionBar,
          showTutorial:  showTutorial),
      IgnorePointer(child: Stack(children: [
        Positioned(bottom: 12, right: 12, child: HullIntegrityArc(state: state)),
      ])),
      Positioned(top: 0, left: 0, right: 0, child: _portBanner()),
    ]);
  }

  return Stack(children: [
    IgnorePointer(child: _windshieldHud(state, disableHaze: settings?.disableHaze ?? false)),
    Align(
      alignment: Alignment.bottomCenter,
      child: _cockpitPanel(state,
          onAbilityActivate: onAbilityActivate,
          onLeftPage: onLeftPage,
          onRightPage: onRightPage,
          onMapZoom: onMapZoom,
          onGearToggle: onGearToggle,
          onFlapsToggle: onFlapsToggle,
          onProbeToggle: onProbeToggle,
          onDrogueToggle: onDrogueToggle,
          onAutopilot: onAutopilot,
          onWaypointLock: onWaypointLock,
          onClear: onClear,
          showAnnunciator: showAnnunciator,
          settings:        settings,
          onLayoutChanged: onLayoutChanged,
          onSuppArm: onSuppArm,
          onSuppAuto: onSuppAuto,
          onRetardantKnob: onRetardantKnob,
          onRangeKnob: onRangeKnob,
          onSensorKnob: onSensorKnob,
          onNavMapTap: onNavMapTap,
          onDeleteWaypoint: onDeleteWaypoint,
          onAnnunciatorChange: onAnnunciatorChange,
          onThrottleModeToggle: onThrottleModeToggle,
          onThrottleChange: onThrottleChange,
          onAuxPage: onAuxPage, onAuxMirrorScroll: onAuxMirrorScroll, onAuxVideoScroll: onAuxVideoScroll,
          onManeuverScroll: onManeuverScroll, onManeuverExecute: onManeuverExecute, onManeuverStop: onManeuverStop,
          onOrientToggle: onOrientToggle,
          onLvrToggle: onLvrToggle,
          onToggleNavSidebar: onToggleNavSidebar,
          onToggleFireHeatmap: onToggleFireHeatmap,
          onToggleTreeHeatmap: onToggleTreeHeatmap,
          treeSnapshot: treeSnapshot),
    ),
    IgnorePointer(child: Stack(children: [
      WarningTextZone(state: state),
      Positioned(bottom: 12, right: 12,
          child: HullIntegrityArc(state: state)),
      if (showTutorial) buildTutorialOverlay(state),
    ])),
    Positioned(top: 0, left: 0, right: 0, child: _portBanner()),
  ]);
}

// Mode badge
Widget _modeBadge(GameMode mode) {
  final (String label, Color color) = switch (mode) {
    GameMode.taxi         => ('TAXI',         const Color(0xFF00CC44)),
    GameMode.flight       => ('FLIGHT',       const Color(0xFF4499FF)),
    GameMode.landing      => ('LANDING',      const Color(0xFFFFAA00)),
    GameMode.manaTanking  => ('MANA TANKING', const Color(0xFF00EEFF)),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

// View badge
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
      style: const TextStyle(color: Color(0xFF80DDFF), fontSize: 18, letterSpacing: 1),
    ),
  );
}

Widget _portBanner() {
  return IgnorePointer(
    child: Center(
      child: Text('8011',
        style: const TextStyle(
          color: Color(0xFFFFDD44), fontSize: 64,
          fontWeight: FontWeight.bold, letterSpacing: 8,
          shadows: [Shadow(color: Colors.black, blurRadius: 12)],
        )),
    ),
  );
}

// ── Smoke / IMC badge helper ──────────────────────────────────────────────────

Widget _smokeLevelBadge(double smoke) {
  final imc    = smoke >= 0.85;
  final label  = imc ? 'IMC' : (smoke > 0.65 ? 'HEAVY SMOKE' : 'SMOKE');
  final color  = imc ? _kImcAmber : _kSmkYellow;
  final width  = imc ? 1.5 : 1.0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: imc ? 0.20 : 0.12),
      borderRadius: BorderRadius.circular(4),
      border:       Border.all(color: color.withValues(alpha: imc ? 1.0 : 0.70), width: width),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: imc ? 18 : 14,
            fontWeight: FontWeight.bold, letterSpacing: imc ? 2 : 1)),
  );
}

// ── Smoke advisory on windshield ─────────────────────────────────────────────

Widget _smokeAdvisory(GameState state) {
  final imc   = state.isIMC;
  final color = imc ? _kImcAmber : _kSmkYellow;
  final label = imc ? 'IMC — FLY INSTRUMENTS'
      : state.smokeOpacity > 0.65 ? 'HEAVY SMOKE — VISIBILITY REDUCED'
      : 'SMOKE — REDUCED VISIBILITY';
  return Positioned(
    top: 72, left: 0, right: 0,
    child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 15,
          fontWeight: FontWeight.bold, letterSpacing: 2)),
    )),
  );
}

// Windshield HUD — delegates to hud_cockpit.dart

Widget _windshieldHud(GameState state, {bool disableHaze = false}) => Stack(children: [
  buildCockpitWindshieldHud(state),
  if (!disableHaze && state.smokeOpacity > 0.40) _smokeAdvisory(state),
]);

// Cockpit Panel

Widget _cockpitPanel(GameState state, {
  void Function(int)? onAbilityActivate,
  void Function(int)? onLeftPage,
  void Function(int)? onRightPage,
  VoidCallback?       onMapZoom,
  VoidCallback?       onGearToggle,
  VoidCallback?       onFlapsToggle,
  VoidCallback?       onProbeToggle,
  VoidCallback?       onDrogueToggle,
  VoidCallback?       onAutopilot,
  VoidCallback?       onWaypointLock,
  VoidCallback?       onClear,
  bool showAnnunciator = true,
  SettingsState? settings,
  VoidCallback?  onLayoutChanged,
  VoidCallback?       onSuppArm,
  VoidCallback?       onSuppAuto,
  VoidCallback?       onRetardantKnob,
  VoidCallback?       onRangeKnob,
  VoidCallback?       onSensorKnob,
  void Function(double, double)? onNavMapTap,
  void Function(int)?            onDeleteWaypoint,
  VoidCallback?                  onAnnunciatorChange,
  VoidCallback?                  onThrottleModeToggle,
  void Function(double)?         onThrottleChange,
  void Function(int)? onAuxPage, void Function(int)? onAuxMirrorScroll, void Function(int)? onAuxVideoScroll,
  void Function(int)? onManeuverScroll, void Function()? onManeuverExecute, void Function()? onManeuverStop,
  VoidCallback? onOrientToggle,
  VoidCallback? onLvrToggle,
  VoidCallback? onToggleNavSidebar,
  VoidCallback? onToggleFireHeatmap,
  VoidCallback? onToggleTreeHeatmap,
  List<(double, double, int)> treeSnapshot = const [],
}) {
  final lp       = state.leftMfdPage;
  final rp       = state.rightMfdPage;
  final gearLeft = state.gearLeverOnLeft;
  final aid      = state.aircraftId;

  // Visibility shorthand — returns true when not explicitly hidden.
  bool vis(String key) => settings?.elementVisible(key) ?? true;

  // Shorthand: builds a CockpitDragGroup with per-aircraft persistent offset.
  Widget drag(String id, String label, Widget child) {
    final bool isDraggable = settings?.cockpitDraggable ?? false;
    // Only restore saved offsets when drag mode is active. In non-draggable
    // mode a stale non-zero offset causes Transform.translate to misplace the
    // hit-test area, so clicks at the visual position silently fail.
    final (dx, dy) = isDraggable
        ? (settings?.cockpitOffset(aid, id) ?? (0.0, 0.0))
        : (0.0, 0.0);
    return CockpitDragGroup(
      key:           ValueKey('${aid}_$id'),
      label:         label,
      elementId:     id,
      initialOffset: Offset(dx, dy),
      draggable:     isDraggable,
      showInfo:      settings?.showCockpitInfo  ?? false,
      onOffsetChanged: (o) {
        settings?.setCockpitOffset(aid, id, o.dx, o.dy);
        onLayoutChanged?.call();
      },
      child: child,
    );
  }

  // When hidden, return an empty zero-size box so the CockpitDragGroup is
  // removed from the tree — this triggers dispose() which tears down any
  // OverlayEntry, ensuring the visible overlay actually disappears.
  Widget keep(bool show, Widget child) => show ? child : const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (gearLeft)
          keep(vis('gear'), Row(mainAxisSize: MainAxisSize.min, children: [
            drag('gearExt', 'Gear (Ext)', buildGearLever(state, onTap: onGearToggle)),
            const SizedBox(width: 8),
          ])),
        keep(vis('leftMfd'), drag('leftMfd', 'Left MFD', Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]))),
        const SizedBox(width: 20),
        Column(mainAxisSize: MainAxisSize.min, children: [
          keep(showAnnunciator && vis('annunciator'), Column(mainAxisSize: MainAxisSize.min, children: [
            drag('annunciator', 'Annunciator',
                buildAnnunciatorPanel(state, onChanged: onAnnunciatorChange)),
            const SizedBox(height: 4),
          ])),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            keep(vis('centerMfd'), drag('centerMfd', 'Centre MFD', buildCenterMFD(state))),
            keep(vis('centerMfd') && vis('suppression'), const SizedBox(width: 8)),
            keep(vis('suppression'), drag('suppression', 'Suppression', buildSuppressionPanel(state,
                onSuppArm: onSuppArm, onSuppAuto: onSuppAuto,
                onRetardantKnob: onRetardantKnob,
                onRangeKnob: onRangeKnob, onSensorKnob: onSensorKnob))),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            keep(vis('flaps'), drag('flaps', 'Flaps', buildFlapsLever(state, onTap: onFlapsToggle))),
            if (!gearLeft)
              keep(vis('gear'), Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 4),
                drag('gear', 'Gear', buildGearLever(state, onTap: onGearToggle)),
              ])),
            keep(vis('probe'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('probe', 'Refuel Probe', buildProbeLever(state, onTap: onProbeToggle)),
            ])),
            keep(vis('drogue'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('drogue', 'Drogue Basket', buildDrogueLever(state, onTap: onDrogueToggle)),
            ])),
            keep(vis('throttle'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('throttle', 'Throttle', buildThrottleGauge(state, onModeToggle: onThrottleModeToggle)),
            ])),
            keep(vis('tq'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('tq', 'Throttle Quad', buildThrottleQuadrant(state,
                  onThrottle: onThrottleChange ?? (_) {})),
            ])),
            keep(vis('alt'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('alt', 'Altimeter', buildAltIndicator(state)),
            ])),
            keep(vis('lvr'), Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 4),
              drag('lvr', 'LVR', buildLvrLever(state, onTap: onLvrToggle)),
            ])),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            keep(vis('aoa'), Row(mainAxisSize: MainAxisSize.min, children: [
              drag('aoa', 'AoA Indicator', buildAoaIndicator(state)),
              const SizedBox(width: 8),
            ])),
            keep(vis('attitudeGyro'), Row(mainAxisSize: MainAxisSize.min, children: [                                    
              drag('attitudeGyro', 'Attitude Gyro', buildAttitudeGyro(state)),                                    
              const SizedBox(width: 8),
            ])),
            keep(vis('fireProx'), Row(mainAxisSize: MainAxisSize.min, children: [
              drag('fireProx', 'Fire Proximity', FireProximitySensor(state: state)),
              const SizedBox(width: 8),
            ])),
            keep(vis('manaArc'), drag('manaArc', 'Mana Arc', ManaArc(state: state))),
          ]),
        ]),
        const SizedBox(width: 20),
        keep(vis('rightMfd'), drag('rightMfd', 'Right MFD', Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: _osbRow([
            _Osb('NAV',  active: rp == 0, onTap: () => onRightPage?.call(0)),
            _Osb('TERR', active: rp == 1, onTap: () => onRightPage?.call(1)),
            _Osb('FIRE', active: rp == 2, onTap: () => onRightPage?.call(2)),
            _Osb('MARK', active: rp == 3, onTap: () => onRightPage?.call(3)),
          ])),
          const SizedBox(height: 4),
          buildRightMFD(state, page: rp,
              onMapTap: onNavMapTap, onDeleteWaypoint: onDeleteWaypoint,
              onOrientToggle: onOrientToggle, treeSnapshot: treeSnapshot,
              onToggleSidebar: onToggleNavSidebar,
              onToggleFireHeatmap: onToggleFireHeatmap,
              onToggleTreeHeatmap: onToggleTreeHeatmap),
          const SizedBox(height: 4),
          Center(child: _osbRow([
            _Osb('ZOOM', onTap: onMapZoom),
            _Osb('AUTO', active: state.autopilotEnabled,    onTap: onAutopilot),
            _Osb('LOCK', active: state.lockedWaypoint >= 0, onTap: onWaypointLock),
            _Osb('CLR',  onTap: onClear),
          ])),
        ]))),
        const SizedBox(width: 20),
        keep(vis('auxDisp'), drag('auxDisp', 'Aux Display', buildAuxDisplay(state,
            onPage: onAuxPage, onMirrorScroll: onAuxMirrorScroll, onVideoScroll: onAuxVideoScroll,
            onManeuverScroll: onManeuverScroll, onManeuverExecute: onManeuverExecute, onManeuverStop: onManeuverStop))),
      ]),
  );
}

// OSB helpers

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
      width: 76, height: 56,
      decoration: BoxDecoration(
        color: _kOsbBg,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(child: Text(
        b.label,
        style: TextStyle(
          color: textColor, fontSize: 15,
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
/// Prefers the first word (4+ chars), otherwise falls back to the last word.
String _abilityOsbLabel(String name) {
  final parts = name.split(' ');
  final word  = (parts.first.length >= 4) ? parts.first : parts.last;
  return word.substring(0, math.min(4, word.length)).toUpperCase();
}

