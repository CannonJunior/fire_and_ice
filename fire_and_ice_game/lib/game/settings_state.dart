import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../rendering/camera3d.dart';
import 'aircraft_config.dart';
import 'game_state.dart';

/// SettingsState — persistent player-configurable game settings.
///
/// Mirrors the Green dashboard pattern: a lightweight data object backed
/// by SharedPreferences.  Call [load] once at startup, [save] after each
/// change, and [applyFlight] / [applyCamera] to push values into the live
/// game systems without restarting.
class SettingsState {
  // ── Aircraft ───────────────────────────────────────────────────────────────

  /// The currently selected aircraft id (e.g. 'firefighter' / 'icefighter').
  String selectedAircraft = 'icefighter';

  /// Populated from [GameState.aircraftConfigs] after both are initialized.
  List<AircraftConfig> aircraftConfigs = AircraftConfig.defaults;

  // ── Flight ─────────────────────────────────────────────────────────────────
  /// Cruise speed (world units / sec).
  double flightSpeed = 7.0;

  /// Nose pitch rate in degrees / sec.
  double pitchRate = 60.0;

  /// Wing bank rate in degrees / sec.
  double bankRate = 120.0;

  /// Speed multiplier while boost (Alt) is held.
  double boostMultiplier = 1.5;

  /// Barrel-roll angular rate in degrees / sec.
  double barrelRollRate = 360.0;

  /// When true, W climbs and S dives (standard RC / sim convention).
  /// Default false = W dives, S climbs (Windwalker convention).
  bool invertedPitch = false;

  // ── Camera ─────────────────────────────────────────────────────────────────
  /// Start in cockpit view instead of third-person.
  bool defaultCockpit = false;

  /// Third-person distance behind the aircraft.
  double cameraDistance = 10.0;

  /// Third-person height above the aircraft.
  double cameraHeight = 4.0;

  // ── HUD visibility ─────────────────────────────────────────────────────────
  bool showAnnunciator  = true;
  bool showTelemetry    = true;
  bool showActionBar    = true;
  bool showTutorial     = false;
  bool cockpitDraggable = false;
  bool showCockpitInfo  = false;

  // ── Per-aircraft cockpit element positions ──────────────────────────────────
  // Layout: aircraftId → elementId → [dx, dy]
  Map<String, Map<String, List<double>>> cockpitLayouts = {};

  /// Offset for one element, or (0, 0) if unset.
  (double, double) cockpitOffset(String aircraftId, String elementId) {
    final pos = cockpitLayouts[aircraftId]?[elementId];
    return (pos != null && pos.length >= 2) ? (pos[0], pos[1]) : (0.0, 0.0);
  }

  void setCockpitOffset(String aircraftId, String elementId, double dx, double dy) =>
      cockpitLayouts.putIfAbsent(aircraftId, () => {})[elementId] = [dx, dy];

  /// Clear all element positions for [aircraftId] (Restore Defaults).
  void resetCockpitLayout(String aircraftId) => cockpitLayouts.remove(aircraftId);

  // ── Persistence ────────────────────────────────────────────────────────────
  static const _p = 'fai_';

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      flightSpeed      = sp.getDouble('${_p}flightSpeed')      ?? flightSpeed;
      pitchRate        = sp.getDouble('${_p}pitchRate')        ?? pitchRate;
      bankRate         = sp.getDouble('${_p}bankRate')         ?? bankRate;
      boostMultiplier  = sp.getDouble('${_p}boostMultiplier')  ?? boostMultiplier;
      barrelRollRate   = sp.getDouble('${_p}barrelRollRate')   ?? barrelRollRate;
      invertedPitch    = sp.getBool('${_p}invertedPitch')      ?? invertedPitch;
      defaultCockpit   = sp.getBool('${_p}defaultCockpit')     ?? defaultCockpit;
      cameraDistance   = sp.getDouble('${_p}cameraDistance')   ?? cameraDistance;
      cameraHeight     = sp.getDouble('${_p}cameraHeight')     ?? cameraHeight;
      showAnnunciator  = sp.getBool('${_p}showAnnunciator')    ?? showAnnunciator;
      showTelemetry    = sp.getBool('${_p}showTelemetry')      ?? showTelemetry;
      showActionBar    = sp.getBool('${_p}showActionBar')      ?? showActionBar;
      showTutorial      = sp.getBool('${_p}showTutorial')       ?? showTutorial;
      cockpitDraggable  = sp.getBool('${_p}cockpitDraggable')  ?? cockpitDraggable;
      showCockpitInfo   = sp.getBool('${_p}showCockpitInfo')   ?? showCockpitInfo;
      selectedAircraft  = sp.getString('${_p}aircraft')        ?? selectedAircraft;
      final layoutJson  = sp.getString('${_p}cockpitLayouts');
      if (layoutJson != null) {
        final raw = jsonDecode(layoutJson) as Map<String, dynamic>;
        cockpitLayouts = {
          for (final e in raw.entries)
            e.key: {
              for (final p in (e.value as Map<String, dynamic>).entries)
                p.key: (p.value as List).map((v) => (v as num).toDouble()).toList()
            }
        };
      }
      debugPrint('[Settings] Loaded from SharedPreferences');
    } catch (e) {
      debugPrint('[Settings] Load failed ($e) — using defaults');
    }
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble('${_p}flightSpeed',     flightSpeed);
      await sp.setDouble('${_p}pitchRate',       pitchRate);
      await sp.setDouble('${_p}bankRate',        bankRate);
      await sp.setDouble('${_p}boostMultiplier', boostMultiplier);
      await sp.setDouble('${_p}barrelRollRate',  barrelRollRate);
      await sp.setBool('${_p}invertedPitch',     invertedPitch);
      await sp.setBool('${_p}defaultCockpit',    defaultCockpit);
      await sp.setDouble('${_p}cameraDistance',  cameraDistance);
      await sp.setDouble('${_p}cameraHeight',    cameraHeight);
      await sp.setBool('${_p}showAnnunciator',   showAnnunciator);
      await sp.setBool('${_p}showTelemetry',     showTelemetry);
      await sp.setBool('${_p}showActionBar',     showActionBar);
      await sp.setBool('${_p}showTutorial',      showTutorial);
      await sp.setBool('${_p}cockpitDraggable', cockpitDraggable);
      await sp.setBool('${_p}showCockpitInfo',  showCockpitInfo);
      await sp.setString('${_p}aircraft',       selectedAircraft);
      await sp.setString('${_p}cockpitLayouts', jsonEncode(cockpitLayouts));
    } catch (e) {
      debugPrint('[Settings] Save failed: $e');
    }
  }

  // ── Apply helpers ──────────────────────────────────────────────────────────

  /// Push flight-physics settings into a live [GameState].
  void applyFlight(GameState state) {
    state.cfgFlightSpeed     = flightSpeed;
    state.cfgPitchRate       = pitchRate;
    state.cfgBankRate        = bankRate;
    state.cfgBoostMultiplier = boostMultiplier;
    state.cfgBarrelRollRate  = barrelRollRate;
    state.aircraftId         = selectedAircraft;
  }

  // FireHawk baseline stats — per-aircraft values are scaled relative to these.
  static const _baseSpeed      = 0.65;
  static const _baseMnvr       = 0.80;
  static const _baseDurability = 0.65;
  static const _baseClimb      = 0.75;

  /// Scale flight-physics cfg fields by the selected aircraft's stats.
  ///
  /// Must be called AFTER [applyFlight] so that [state.aircraftId] is current.
  void applyAircraftStats(GameState state) {
    final stats = state.currentAircraft.baseStats;
    state.cfgFlightSpeed      = flightSpeed * (stats.speed / _baseSpeed);
    state.cfgPitchRate        = pitchRate   * (stats.maneuverability / _baseMnvr);
    state.cfgBankRate         = bankRate    * (stats.maneuverability / _baseMnvr);
    state.cfgCrashDamageRate  = 80.0 * (_baseDurability / stats.durability.clamp(0.1, 1.0));
    state.cfgStallSpeed       = 2.5  * (_baseMnvr / stats.maneuverability.clamp(0.1, 1.0));
    state.cfgFlightSpeedAccel = 2.5  * (stats.climbRate / _baseClimb);
  }

  /// Push camera settings into a live [Camera3D].
  void applyCamera(Camera3D camera) {
    camera.thirdPersonDistance = cameraDistance;
    camera.thirdPersonHeight   = cameraHeight;
  }
}
