import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'annunciator_panel.dart';
import 'attitude_gyro.dart';
import 'cockpit_drag.dart';
import 'game_state.dart';
import 'settings_state.dart';
import 'gear_lever.dart';
import 'hud_gauges.dart';
import 'hud_tutorial.dart';
import 'hud_widgets.dart' as hud;
import 'mfd_panels.dart';
import 'suppression_panel.dart';
import 'throttle_quadrant.dart';
import 'alt_indicator.dart';
import 'aux_display.dart';

// Colors

const _kOsbBg    = Color(0xFF1A1A22);
const _kOsbBrd   = Color(0xFF3C3C4C);
const _kOsbTxt   = Color(0xFF6A6A8A);
const _kOsbActBrd = Color(0xFFAAAAAA);
const _kOsbActTxt = Color(0xFFCCCCFF);
const _kWarn     = Color(0xFFFF6600);

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
          onManeuverScroll: onManeuverScroll, onManeuverExecute: onManeuverExecute, onManeuverStop: onManeuverStop),
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

// Mode badge
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

// Windshield HUD — delegates to hud_cockpit.dart

Widget _windshieldHud(GameState state) => buildCockpitWindshieldHud(state);

// Cockpit Panel

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
}) {
  final lp       = state.leftMfdPage;
  final rp       = state.rightMfdPage;
  final gearLeft = state.gearLeverOnLeft;
  final aid      = state.aircraftId;

  // Shorthand: builds a CockpitDragGroup with per-aircraft persistent offset.
  Widget drag(String id, String label, Widget child) {
    final (dx, dy) = settings?.cockpitOffset(aid, id) ?? (0.0, 0.0);
    return CockpitDragGroup(
      key:           ValueKey('${aid}_$id'),
      label:         label,
      initialOffset: Offset(dx, dy),
      draggable:     settings?.cockpitDraggable ?? false,
      showInfo:      settings?.showCockpitInfo  ?? false,
      onOffsetChanged: (o) {
        settings?.setCockpitOffset(aid, id, o.dx, o.dy);
        onLayoutChanged?.call();
      },
      child: child,
    );
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // SeaBird: external gear lever left of the left console
        if (gearLeft) ...[
          drag('gearExt', 'Gear (Ext)', buildGearLever(state, onTap: onGearToggle)),
          const SizedBox(width: 8),
        ],
        // Left MFD column
        drag('leftMfd', 'Left MFD', Column(mainAxisSize: MainAxisSize.min, children: [
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
        // Centre column — each instrument is individually draggable
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (showAnnunciator)
            drag('annunciator', 'Annunciator',
                buildAnnunciatorPanel(state, onChanged: onAnnunciatorChange)),
          if (showAnnunciator) const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            drag('centerMfd', 'Centre MFD', buildCenterMFD(state)),
            const SizedBox(width: 8),
            drag('suppression', 'Suppression', buildSuppressionPanel(state,
                onSuppArm: onSuppArm, onSuppAuto: onSuppAuto,
                onRetardantKnob: onRetardantKnob,
                onRangeKnob: onRangeKnob, onSensorKnob: onSensorKnob)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            drag('flaps',    'Flaps',    buildFlapsLever(state, onTap: onFlapsToggle)),
            if (!gearLeft) ...[
              const SizedBox(width: 4),
              drag('gear',   'Gear',     buildGearLever(state, onTap: onGearToggle)),
            ],
            const SizedBox(width: 4),
            drag('throttle', 'Throttle', buildThrottleGauge(state, onModeToggle: onThrottleModeToggle)),
            const SizedBox(width: 4),
            drag('tq', 'Throttle Quad', buildThrottleQuadrant(state,
                onThrottle: onThrottleChange ?? (_) {})),
            const SizedBox(width: 4),
            drag('alt', 'Altimeter', buildAltIndicator(state)),
          ]),
          const SizedBox(height: 4),
          drag('attitudeGyro', 'Attitude Gyro', buildAttitudeGyro(state)),
        ]),
        const SizedBox(width: 20),
        // Right MFD column
        drag('rightMfd', 'Right MFD', Column(mainAxisSize: MainAxisSize.min, children: [
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
        const SizedBox(width: 20),
        // Aux display — CHAT / VID / MAP / MIRROR
        drag('auxDisp', 'Aux Display', buildAuxDisplay(state,
            onPage: onAuxPage, onMirrorScroll: onAuxMirrorScroll, onVideoScroll: onAuxVideoScroll,
            onManeuverScroll: onManeuverScroll, onManeuverExecute: onManeuverExecute, onManeuverStop: onManeuverStop)),
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

