import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../data/abilities.dart';
import 'aircraft_config.dart';

/// Camera perspective mode — toggled with Tab.
enum ViewMode { thirdPerson, cockpit }

/// Operational flight mode. Drives physics dispatch and UI context.
enum GameMode {
  taxi,     // On the ground: taxiing, takeoff roll
  flight,   // Airborne with gear up
  landing,  // Airborne with gear down — approach / rollout
}

/// GameState - Single source of truth for all mutable game data.
class GameState {
  // ── Player spatial state ─────────────────────────────────────────────────

  Vector3 playerPosition = Vector3(0, 0.5, 78);
  Vector3 playerRotation = Vector3(0, 0, 0);

  // ── View / game mode ─────────────────────────────────────────────────────

  ViewMode viewMode = ViewMode.thirdPerson;
  void toggleViewMode() {
    viewMode = viewMode == ViewMode.thirdPerson ? ViewMode.cockpit : ViewMode.thirdPerson;
  }

  GameMode gameMode = GameMode.taxi;

  // ── MFD page selection ────────────────────────────────────────────────────

  int leftMfdPage  = 0;
  int rightMfdPage = 0;
  int mapZoom      = 0;
  int auxDisplayPage = 0; // 0=CHAT 1=VID 2=MAP 3=MIRROR
  int auxMirrorIndex = 0; // 0..7 → ELMT/LOAD/STAT/MODE/NAV/TERR/FIRE/MARK
  int auxVideoIndex  = 0; // 0=LISA HAYES  1=LIN MINMEI
  void scrollAuxMirror(int d) => auxMirrorIndex = (auxMirrorIndex + d + 8) % 8;
  void scrollAuxVideo(int d)  => auxVideoIndex  = (auxVideoIndex  + d + 2) % 2;

  // ── Aircraft + Upgrade economy ────────────────────────────────────────────

  List<AircraftConfig> aircraftConfigs = AircraftConfig.defaults;
  String aircraftId = 'firefighter';

  AircraftConfig get currentAircraft =>
      aircraftConfigs.firstWhere((a) => a.id == aircraftId,
          orElse: () => aircraftConfigs.first);

  bool get gearLeverOnLeft =>
      currentAircraft.gearLeverPosition == GearLeverPosition.leftOfLeft;

  /// Total research points accumulated across all missions.
  int totalResearchPoints = 0;

  /// Upgrade IDs currently equipped per aircraft (aircraft id → set of upgrade ids).
  Map<String, Set<String>> equippedUpgrades = {};

  /// Aircraft IDs the player has unlocked.
  /// All aircraft with unlockRp == 0 are available from the start.
  Set<String> unlockedAircraft = {
    for (final ac in AircraftConfig.defaults)
      if (ac.unlockRp == 0) ac.id
  };

  void earnResearchPoints(int amount) {
    totalResearchPoints += amount;
    // Unlock aircraft that hit their RP threshold
    for (final ac in aircraftConfigs) {
      if (ac.unlockRp > 0 && totalResearchPoints >= ac.unlockRp) {
        unlockedAircraft.add(ac.id);
      }
    }
  }

  bool isAircraftUnlocked(String id) => unlockedAircraft.contains(id);

  Set<String> equippedFor(String id) => equippedUpgrades[id] ?? {};

  void equipUpgrade(String aircraftId_, String upgradeId) {
    equippedUpgrades.putIfAbsent(aircraftId_, () => {}).add(upgradeId);
  }

  void unequipUpgrade(String aircraftId_, String upgradeId) {
    equippedUpgrades[aircraftId_]?.remove(upgradeId);
  }

  // ── Navigation / autopilot ────────────────────────────────────────────────

  /// Named navigation waypoints: (display name, world-X, world-Z).
  static const List<(String, double, double)> kWaypoints = [
    ('ORIGIN',      0.0,    0.0),
    ('VALLEY PEAK', 32.0,  32.0),
    ('NORTH RIDGE', 10.0,  80.0),
    ('FIRE SHRINE',-80.0,  20.0),
    ('ICE CAVERN',  50.0, -90.0),
  ];

  bool autopilotEnabled = false;
  /// -1 = no lock; 0–4 indexes kWaypoints.
  int  lockedWaypoint   = -1;

  void toggleAutopilot()   { autopilotEnabled = !autopilotEnabled; }
  void cycleWaypointLock() { lockedWaypoint = lockedWaypoint >= 4 ? -1 : lockedWaypoint + 1; }
  void clearNav()          { autopilotEnabled = false; lockedWaypoint = -1; clearFlightPlan(); }

  // ── Flight plan (user-placed waypoints) ──────────────────────────────────

  List<(String, double, double)> flightPlan = [];
  int flightPlanIndex = 0;

  void addWaypoint(double wx, double wz) {
    final n = flightPlan.length + 1;
    flightPlan.add(('WP${n.toString().padLeft(2, '0')}', wx, wz));
  }

  void removeWaypoint(int i) {
    if (i < 0 || i >= flightPlan.length) return;
    flightPlan.removeAt(i);
    if (flightPlanIndex >= flightPlan.length && flightPlanIndex > 0) {
      flightPlanIndex--;
    }
  }

  void clearFlightPlan() {
    flightPlan.clear();
    flightPlanIndex = 0;
  }

  // ── Suppression control panel (F-35 style: ARM/SAFE/AUTO/MAN + 3 knobs) ──

  /// True when the fire suppression system is armed (ARM switch active).
  bool suppressionArmed = false;
  /// True when auto-drop mode is engaged (AUTO switch active).
  bool suppressionAuto  = false;
  /// Retardant concentration knob: 0=25% 1=50% 2=75% 3=MAX.
  int  retardantLevel   = 1;
  /// Drop-zone radius knob: 0=NEAR 1=MED 2=FAR 3=MAX.
  int  dropRange        = 1;
  /// Thermal sensor gain knob: 0=LOW 1=MED 2=HIGH 3=MAX.
  int  sensorGain       = 1;

  void toggleSuppArm()  { suppressionArmed = !suppressionArmed; }
  void toggleSuppAuto() { suppressionAuto  = !suppressionAuto;  }
  void stepRetardant()  { retardantLevel = (retardantLevel + 1) % 4; }
  void stepDropRange()  { dropRange      = (dropRange      + 1) % 4; }
  void stepSensorGain() { sensorGain     = (sensorGain     + 1) % 4; }

  // ── Throttle & engine instruments ────────────────────────────────────────

  /// Engine throttle 0.0 (idle) → 1.0 (full).
  double throttle = 0.0;

  /// Animated N1 fan RPM (0–1).  Lags throttle by ~2.5 s.
  double engineN1  = 0.0;
  /// Animated N2 core RPM (0–1).  Lags throttle by ~2.0 s.
  double engineN2  = 0.0;
  /// Animated EGT exhaust temperature (0–1).  Lags throttle by ~4.0 s.
  double engineEgt = 0.0;

  /// Throttle gauge display mode: 0=bar  1=bar+engine  2=big-number.
  int throttleDisplayMode = 0;
  void stepThrottleMode() { throttleDisplayMode = (throttleDisplayMode + 1) % 3; }

  // ── Landing gear ─────────────────────────────────────────────────────────

  /// True when gear is fully deployed and locked.
  bool   gearDeployed   = true;
  /// True while gear is in transit between up and down.
  bool   gearMoving     = false;
  /// Commanded position: true = down, false = up.
  bool   gearTargetDown = true;
  /// Animation progress: 0.0 = fully retracted, 1.0 = fully deployed.
  double gearProgress   = 1.0;

  // ── Flaps ─────────────────────────────────────────────────────────────────

  /// Flap detent position: 0=UP  1=T/O  2=APPR  3=FULL.
  int flapsLevel = 3;

  /// Cycle flaps through the four detents (UP → T/O → APPR → FULL → UP).
  void cycleFlaps() { flapsLevel = (flapsLevel + 1) % 4; }

  /// Toggle gear and update game mode. No-op in taxi (gear cannot retract on ground).
  void triggerGear() {
    if (gameMode == GameMode.taxi) return;
    gearTargetDown = !gearTargetDown;
    gearMoving     = true;
    if (gearTargetDown && gameMode == GameMode.flight) {
      gameMode = GameMode.landing;
    } else if (!gearTargetDown && gameMode == GameMode.landing) {
      gameMode = GameMode.flight;
    }
  }

  // ── Flight parameters ─────────────────────────────────────────────────────

  double flightPitchAngle = 0.0;
  double flightBankAngle  = 0.0;
  double flightSpeed      = 0.0;
  double flightAltitude   = 0.0;
  double groundSpeed      = 0.0;
  bool   isBarrelRolling  = false;

  // ── Terrain / hazard state (updated each frame by PhysicsSystem) ──────────

  /// Height of the terrain directly below the aircraft.
  double terrainHeight  = 0.0;
  /// True when terrain clearance is below the GPWS warning threshold.
  bool   isGpwsActive   = false;
  /// True when the aircraft is in an aerodynamic stall.
  bool   isStalling     = false;

  // ── Fire zones ────────────────────────────────────────────────────────────

  /// World-space (X, Z) centres of active fire zones.
  ///
  /// Positions are placed across the terrain away from the runway (Z ≈ 78)
  /// so the player has to fly to find them.  Shared by the MFD fire page,
  /// the proximity sensor, and the altimeter fire indicator.
  static const List<(double, double)> firePositions = [
    (-45.0,  28.0),
    ( 22.0, -60.0),
    ( 55.0,  42.0),
    (-72.0, -18.0),
    (  8.0,  95.0),
  ];

  /// Horizontal radius of each fire zone in world units.
  static const double fireRadius = 20.0;

  /// True when the aircraft's X/Z position is inside any fire zone.
  bool get isFireBelow {
    final px = playerPosition.x, pz = playerPosition.z;
    for (final (fx, fz) in firePositions) {
      final dx = px - fx, dz = pz - fz;
      if (dx * dx + dz * dz < fireRadius * fireRadius) return true;
    }
    return false;
  }

  // ── Dual-engine fire suppression ─────────────────────────────────────────

  /// Left engine fire: triggered below 40 HP unless halon has been deployed.
  bool get engineFireL => health < 40 && !halonFiredL;
  /// Right engine fire: triggered below 20 HP unless halon has been deployed.
  bool get engineFireR => health < 20 && !halonFiredR;

  /// Glass guard lifted for left / right fire-suppression button.
  bool halonShieldL = false;
  bool halonShieldR = false;

  /// Halon deployed in left / right engine (suppresses fire).
  bool halonFiredL = false;
  bool halonFiredR = false;

  /// Tap the engine-fire button.
  /// First tap lifts the guard; second tap (guard open) fires halon.
  void tapEngineFire(bool left) {
    if (left) {
      if (!halonShieldL) { halonShieldL = true; }
      else               { halonFiredL = true; halonShieldL = false; }
    } else {
      if (!halonShieldR) { halonShieldR = true; }
      else               { halonFiredR = true; halonShieldR = false; }
    }
  }

  /// Lower the guard without firing halon.
  void lowerShield(bool left) {
    if (left) halonShieldL = false;
    else      halonShieldR = false;
  }

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
  double cfgStartAltitude      = 0.5;
  double cfgStallSpeed         = 2.5;
  double cfgStallPitchAngle    = 35.0;
  double cfgGpwsAltitude       = 10.0;
  double cfgCrashDamageRate    = 80.0;
  double cfgLandingMaxSpeed    = 9.0;
  double cfgLandingMaxPitchDeg = 10.0;

  // ── Taxi config (loaded from JSON) ───────────────────────────────────────

  double cfgMaxGroundSpeed  = 10.0;
  double cfgGroundAccel     = 3.0;
  double cfgGroundBrake     = 8.0;
  double cfgLiftoffSpeed    = 8.0;
  double cfgGroundTurnRate  = 55.0;
  double cfgRunwayStartZ    = 78.0;
  double cfgThrottleRate    = 0.45;
  double cfgFlightSpeedAccel = 2.5;

  // ── Vitals ────────────────────────────────────────────────────────────────

  double mana   = 100.0;
  double health = 100.0;
  static const double maxMana   = 100.0;
  static const double maxHealth = 100.0;

  // ── Abilities ─────────────────────────────────────────────────────────────

  List<AbilityData> abilities = List.from(windwalkerAbilities);
  Map<String, double> abilityCooldowns = {};
  Map<String, int> abilityCharges = {};
  List<String> actionBarSlots = List.generate(10, (i) => '');

  /// Swap to the ability loadout for [id] and reset bar / charges / cooldowns.
  void loadAbilitiesFor(String id) {
    abilities = List.from(abilitiesFor(id));
    actionBarSlots = List.generate(10, (_) => '');
    abilityCooldowns.clear();
    abilityCharges.clear();
    _setupDefaultActionBar();
    _resetCharges();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _loadFlightConfig();
    _setupDefaultActionBar();
    _resetCharges();
    playerPosition = Vector3(0.0, 0.5, cfgRunwayStartZ);
    flightAltitude = 0.0;
    flightSpeed    = 0.0;
    groundSpeed    = 0.0;
    throttle       = 0.0;
    gameMode       = GameMode.taxi;
    gearProgress   = 1.0;
    gearDeployed   = true;
    gearTargetDown = true;
    gearMoving     = false;
  }

  Future<void> _loadFlightConfig() async {
    try {
      final json = await rootBundle.loadString('assets/data/flight_config.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final f    = data['flight'] as Map<String, dynamic>;

      cfgFlightSpeed        = (f['flightSpeed']          as num).toDouble();
      cfgPitchRate          = (f['pitchRate']            as num).toDouble();
      cfgMaxPitchAngle      = (f['maxPitchAngle']        as num).toDouble();
      cfgBoostMultiplier    = (f['boostMultiplier']      as num).toDouble();
      cfgBrakeMultiplier    = (f['brakeMultiplier']      as num).toDouble();
      cfgBrakeJumpForce     = (f['brakeJumpForce']       as num).toDouble();
      cfgManaDrainRate      = (f['manaDrainRate']        as num).toDouble();
      cfgLowManaThreshold   = (f['lowManaThreshold']     as num).toDouble();
      cfgLowManaDescentRate = (f['lowManaDescentRate']   as num).toDouble();
      cfgBankRate           = (f['bankRate']             as num).toDouble();
      cfgMaxBankAngle       = (f['maxBankAngle']         as num).toDouble();
      cfgAutoLevelRate      = (f['autoLevelRate']        as num).toDouble();
      cfgAutoLevelThreshold = (f['autoLevelThreshold']  as num).toDouble();
      cfgBankToTurnMult     = (f['bankToTurnMultiplier'] as num).toDouble();
      cfgBarrelRollRate     = (f['barrelRollRate']       as num).toDouble();
      cfgStartAltitude      = (f['startAltitude']        as num).toDouble();
      cfgStallSpeed         = (f['stallSpeed']           as num).toDouble();
      cfgStallPitchAngle    = (f['stallPitchAngle']      as num).toDouble();
      cfgGpwsAltitude       = (f['gpwsAltitude']         as num).toDouble();
      cfgCrashDamageRate    = (f['crashDamageRate']      as num).toDouble();
      cfgLandingMaxSpeed    = (f['landingMaxSpeed']      as num).toDouble();
      cfgLandingMaxPitchDeg = (f['landingMaxPitchDeg']   as num).toDouble();

      final t = data['taxi'] as Map<String, dynamic>;
      cfgMaxGroundSpeed   = (t['maxGroundSpeed']  as num).toDouble();
      cfgGroundAccel      = (t['groundAccel']     as num).toDouble();
      cfgGroundBrake      = (t['groundBrake']     as num).toDouble();
      cfgLiftoffSpeed     = (t['liftoffSpeed']    as num).toDouble();
      cfgGroundTurnRate   = (t['groundTurnRate']  as num).toDouble();
      cfgRunwayStartZ     = (t['runwayStartZ']    as num).toDouble();
      cfgThrottleRate     = (t['throttleRate']    as num).toDouble();
      cfgFlightSpeedAccel = (t['flightSpeedAccel'] as num).toDouble();

      // Aircraft library
      final acList = data['aircraft'] as List<dynamic>?;
      if (acList != null && acList.isNotEmpty) {
        aircraftConfigs = acList
            .map((e) => AircraftConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      debugPrint('[GameState] Config loaded');
    } catch (e) {
      debugPrint('[GameState] Could not load flight_config.json: $e — using defaults');
    }
  }

  void _setupDefaultActionBar() {
    for (int i = 0; i < abilities.length && i < 10; i++) {
      actionBarSlots[i] = abilities[i].name;
    }
  }

  /// Reset all expendable stores to their full charge count (called on init/respawn).
  void _resetCharges() {
    for (final ab in abilities) {
      if (ab.isExpendable) abilityCharges[ab.name] = ab.maxCharges;
    }
  }

  /// Remaining charges for [ability], or null if it is rechargeable.
  int? chargesFor(AbilityData ability) =>
      ability.isExpendable ? (abilityCharges[ability.name] ?? ability.maxCharges) : null;

  // ── Mission economy ───────────────────────────────────────────────────────

  double _rpAccum = 0.0;

  /// Award RP for airborne time (2/sec) and a landing bonus (+50 on touchdown).
  void tickMissionEconomy(double dt, GameMode prevMode) {
    if (gameMode == GameMode.flight || gameMode == GameMode.landing) {
      _rpAccum += 2.0 * dt;
      if (_rpAccum >= 1.0) {
        final pts = _rpAccum.floor();
        earnResearchPoints(pts);
        _rpAccum -= pts;
      }
    }
    if (prevMode != GameMode.taxi && gameMode == GameMode.taxi) {
      earnResearchPoints(50);
      debugPrint('[Economy] Landing +50 RP — total: $totalResearchPoints RP');
    }
  }

  // ── Accessors / helpers ───────────────────────────────────────────────────

  AbilityData? abilityByName(String name) {
    try { return abilities.firstWhere((a) => a.name == name); } catch (_) { return null; }
  }

  bool hasManaFor(AbilityData ability) => mana >= ability.manaCost;
  bool isReady(AbilityData ability)    => (abilityCooldowns[ability.name] ?? 0.0) <= 0.0;

  void spendMana(double amount)   => mana   = (mana   - amount).clamp(0.0, maxMana);
  void restoreMana(double amount) => mana   = (mana   + amount).clamp(0.0, maxMana);
  void takeDamage(double amount)  => health = (health - amount).clamp(0.0, maxHealth);

  void startCooldown(AbilityData ability) {
    abilityCooldowns[ability.name] = ability.cooldown;
  }

  void tickCooldowns(double dt) {
    for (final key in abilityCooldowns.keys.toList()) {
      abilityCooldowns[key] = (abilityCooldowns[key]! - dt).clamp(0.0, double.infinity);
    }
  }
}
