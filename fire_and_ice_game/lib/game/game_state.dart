import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../data/abilities.dart';

/// Camera perspective mode — toggled with Tab.
enum ViewMode { thirdPerson, cockpit }

/// GameState - Single source of truth for all mutable game data.
///
/// Holds player position/rotation, flight parameters, ability state,
/// mana/health, and the action bar configuration. Loaded from JSON
/// configs so values can be tuned without recompiling.
///
/// Usage:
/// ```dart
/// final state = GameState();
/// await state.initialize();
/// // then pass to PhysicsSystem, AbilitySystem, etc.
/// ```
class GameState {
  // ── Player spatial state ─────────────────────────────────────────────────

  /// World-space position of the aircraft
  Vector3 playerPosition = Vector3(0, 15, 0);

  /// Euler rotation in degrees: x=pitch, y=yaw, z=roll
  /// Kept in sync with flightPitchAngle / flightBankAngle by PhysicsSystem.
  Vector3 playerRotation = Vector3(0, 0, 0);

  // ── View mode ─────────────────────────────────────────────────────────────

  /// Active camera perspective; toggled by Tab.
  ViewMode viewMode = ViewMode.thirdPerson;

  void toggleViewMode() {
    viewMode = viewMode == ViewMode.thirdPerson
        ? ViewMode.cockpit
        : ViewMode.thirdPerson;
  }

  // ── MFD page selection ────────────────────────────────────────────────────

  /// Active left MFD page (0=ELMT, 1=ABLT, 2=STAT, 3=MODE).
  int leftMfdPage  = 0;

  /// Active right MFD page (0=NAV, 1=TERR, 2=TGT, 3=MARK).
  int rightMfdPage = 0;

  /// Nav-map zoom index (0=1×, 1=2×, 2=0.5×).
  int mapZoom = 0;

  // ── Flight parameters ─────────────────────────────────────────────────────

  /// Current pitch angle in degrees (positive = nose up / climbing)
  double flightPitchAngle = 0.0;

  /// Current bank/roll angle in degrees (positive = right wing down)
  double flightBankAngle = 0.0;

  /// Current forward speed (world units per second)
  double flightSpeed = 7.0;

  /// Height above the terrain surface
  double flightAltitude = 15.0;

  /// Whether the player is in a barrel roll this frame
  bool isBarrelRolling = false;

  // ── Flight config (loaded from JSON) ─────────────────────────────────────

  double cfgFlightSpeed        = 7.0;
  double cfgPitchRate          = 60.0;
  double cfgMaxPitchAngle      = 45.0;
  double cfgBoostMultiplier    = 1.5;
  double cfgBrakeMultiplier    = 0.6;
  double cfgBrakeJumpForce     = 3.0;
  double cfgManaDrainRate      = 3.0;
  double cfgLowManaThreshold   = 10.0;
  double cfgLowManaDescentRate = 2.0;
  double cfgBankRate           = 120.0;
  double cfgMaxBankAngle       = 60.0;
  double cfgAutoLevelRate      = 90.0;
  double cfgAutoLevelThreshold = 90.0;
  double cfgBankToTurnMult     = 2.5;
  double cfgBarrelRollRate     = 360.0;
  double cfgStartAltitude      = 15.0;

  // ── Vitals ────────────────────────────────────────────────────────────────

  /// Current mana (0–100)
  double mana = 100.0;

  /// Maximum mana
  static const double maxMana = 100.0;

  /// Current health (0–100)
  double health = 100.0;

  /// Maximum health
  static const double maxHealth = 100.0;

  // ── Abilities ─────────────────────────────────────────────────────────────

  /// Available ability definitions
  List<AbilityData> abilities = List.from(windwalkerAbilities);

  /// Remaining cooldown per ability name (seconds)
  Map<String, double> abilityCooldowns = {};

  /// 10-slot action bar: each entry is an ability name or empty string.
  /// Reason: slots are named so future remapping is trivial.
  List<String> actionBarSlots = List.generate(10, (i) => '');

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Load config from assets and populate default action bar slots.
  Future<void> initialize() async {
    await _loadFlightConfig();
    _setupDefaultActionBar();
    playerPosition = Vector3(0, cfgStartAltitude, 0);
    flightAltitude = cfgStartAltitude;
    flightSpeed    = cfgFlightSpeed;
  }

  Future<void> _loadFlightConfig() async {
    try {
      final json = await rootBundle.loadString('assets/data/flight_config.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final f    = data['flight'] as Map<String, dynamic>;

      cfgFlightSpeed        = (f['flightSpeed']        as num).toDouble();
      cfgPitchRate          = (f['pitchRate']          as num).toDouble();
      cfgMaxPitchAngle      = (f['maxPitchAngle']      as num).toDouble();
      cfgBoostMultiplier    = (f['boostMultiplier']    as num).toDouble();
      cfgBrakeMultiplier    = (f['brakeMultiplier']    as num).toDouble();
      cfgBrakeJumpForce     = (f['brakeJumpForce']     as num).toDouble();
      cfgManaDrainRate      = (f['manaDrainRate']      as num).toDouble();
      cfgLowManaThreshold   = (f['lowManaThreshold']   as num).toDouble();
      cfgLowManaDescentRate = (f['lowManaDescentRate'] as num).toDouble();
      cfgBankRate           = (f['bankRate']           as num).toDouble();
      cfgMaxBankAngle       = (f['maxBankAngle']       as num).toDouble();
      cfgAutoLevelRate      = (f['autoLevelRate']      as num).toDouble();
      cfgAutoLevelThreshold = (f['autoLevelThreshold'] as num).toDouble();
      cfgBankToTurnMult     = (f['bankToTurnMultiplier'] as num).toDouble();
      cfgBarrelRollRate     = (f['barrelRollRate']     as num).toDouble();
      cfgStartAltitude      = (f['startAltitude']      as num).toDouble();

      debugPrint('[GameState] Flight config loaded from JSON');
    } catch (e) {
      debugPrint('[GameState] Could not load flight_config.json: $e — using defaults');
    }
  }

  void _setupDefaultActionBar() {
    // Map the first N abilities to the first N slots
    for (int i = 0; i < abilities.length && i < 10; i++) {
      actionBarSlots[i] = abilities[i].name;
    }
  }

  // ── Accessors / helpers ───────────────────────────────────────────────────

  /// Look up an ability by name, returning null if not found.
  AbilityData? abilityByName(String name) {
    try {
      return abilities.firstWhere((a) => a.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Whether the player has enough mana to cast [ability].
  bool hasManaFor(AbilityData ability) => mana >= ability.manaCost;

  /// Whether [ability] is off cooldown.
  bool isReady(AbilityData ability) =>
      (abilityCooldowns[ability.name] ?? 0.0) <= 0.0;

  /// Spend mana, clamped to 0.
  void spendMana(double amount) {
    mana = (mana - amount).clamp(0.0, maxMana);
  }

  /// Restore mana, clamped to maxMana.
  void restoreMana(double amount) {
    mana = (mana + amount).clamp(0.0, maxMana);
  }

  /// Start cooldown for [ability].
  void startCooldown(AbilityData ability) {
    abilityCooldowns[ability.name] = ability.cooldown;
  }

  /// Decrement all active cooldowns by [dt] seconds.
  void tickCooldowns(double dt) {
    for (final key in abilityCooldowns.keys.toList()) {
      final remaining = (abilityCooldowns[key]! - dt).clamp(0.0, double.infinity);
      abilityCooldowns[key] = remaining;
    }
  }
}
