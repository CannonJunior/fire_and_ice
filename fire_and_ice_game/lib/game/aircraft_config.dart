/// Where the landing gear lever appears in the cockpit layout.
enum GearLeverPosition { center, leftOfLeft }

/// Role drives which ability loadout is used and which stat bars to highlight.
enum AircraftRole { fighter, tanker, amphibious, elemental }

/// Physics-based aerodynamics parameters per aircraft.
class AeroConfig {
  final double maxThrust;        // peak engine force (game units)
  final double kLift;            // ½ρS — lift/drag area scale
  final double cd0;              // parasitic drag coefficient
  final double kInduced;         // induced drag polar constant
  final double clZero;           // CL at zero AoA
  final double clPerDeg;         // lift curve slope (per degree)
  final List<double> flapsClDelta;  // CL increment per flap detent [UP,T/O,APPR,FULL]
  final List<double> flapsCdDelta;  // CD increment per flap detent
  final List<double> stallAoaDeg;   // critical AoA per flap detent (degrees)
  final double gearCdDelta;      // CD penalty when gear is deployed
  final double mass;             // aircraft mass (game units)
  final double pitchFollowRate;  // arcade-assist pitch-following rate

  const AeroConfig({
    required this.maxThrust,
    required this.kLift,
    required this.cd0,
    required this.kInduced,
    required this.clZero,
    required this.clPerDeg,
    required this.flapsClDelta,
    required this.flapsCdDelta,
    required this.stallAoaDeg,
    required this.gearCdDelta,
    required this.mass,
    required this.pitchFollowRate,
  });
}

/// Normalised (0–1) performance stats for HUD display and upgrade comparison.
class AircraftStats {
  final double speed;           // relative to fastest
  final double maneuverability;
  final double payload;         // retardant capacity
  final double durability;      // health relative to tankiest
  final double climbRate;
  final double scoopRate;       // amphibious water-scoop speed (0 for non-amphibious)

  const AircraftStats({
    required this.speed,
    required this.maneuverability,
    required this.payload,
    required this.durability,
    required this.climbRate,
    this.scoopRate = 0.0,
  });

  AircraftStats operator+(AircraftStats o) => AircraftStats(
    speed:           (speed           + o.speed).clamp(0.0, 1.0),
    maneuverability: (maneuverability + o.maneuverability).clamp(0.0, 1.0),
    payload:         (payload         + o.payload).clamp(0.0, 1.0),
    durability:      (durability      + o.durability).clamp(0.0, 1.0),
    climbRate:       (climbRate       + o.climbRate).clamp(0.0, 1.0),
    scoopRate:       scoopRate,
  );
}

/// Upgrade slot budgets — the "build budget" (Ace Combat 7 style).
/// Total slots available per category; each upgrade consumes slots.
class UpgradeSlots {
  final int airframe; // engine / structural upgrades
  final int systems;  // avionics / suppression upgrades
  final int payload;  // stores / tank upgrades
  const UpgradeSlots({required this.airframe, required this.systems, required this.payload});
}

/// Full configuration for one playable aircraft type.
class AircraftConfig {
  final String            id;
  final String            displayName;
  final String            icon;
  final String            description;
  final AircraftRole      role;
  final AircraftStats     baseStats;
  final UpgradeSlots      upgradeSlots;
  final GearLeverPosition gearLeverPosition;
  final AeroConfig        aero;

  /// Research points required to unlock (0 = available from start).
  final int unlockRp;

  /// Per-ability maximum charge overrides for this airframe.
  /// Abilities not listed fall back to [AbilityData.maxCharges].
  final Map<String, int> storeCharges;

  const AircraftConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.description,
    required this.role,
    required this.baseStats,
    required this.upgradeSlots,
    required this.aero,
    this.gearLeverPosition = GearLeverPosition.center,
    this.unlockRp = 0,
    this.storeCharges = const {},
  });

  factory AircraftConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    // Inherit aero config, stats, and slots from hardcoded defaults by aircraft id.
    final def = AircraftConfig.defaults
        .firstWhere((a) => a.id == id,
            orElse: () => AircraftConfig.defaults.first);
    return AircraftConfig(
      id:          id,
      displayName: json['displayName'] as String,
      icon:        json['icon']        as String,
      description: json['description'] as String,
      role:        def.role,
      baseStats:   def.baseStats,
      upgradeSlots: def.upgradeSlots,
      gearLeverPosition: (json['gearLeverPosition'] as String?) == 'leftOfLeft'
          ? GearLeverPosition.leftOfLeft : GearLeverPosition.center,
      unlockRp: (json['unlockRp'] as int?) ?? 0,
      aero: def.aero,
    );
  }

  static List<AircraftConfig> get defaults => const [
    _iceFighter, _fireHawk, _skyTanker, _seaBird, _stormRider,
  ];
}

// ── Aircraft catalogue ─────────────────────────────────────────────────────────

const _iceFighter = AircraftConfig(
  id: 'icefighter', displayName: 'IceFighter', icon: '❄️', unlockRp: 0,
  description: 'Ice-elemental interceptor. Heightened ability amplification and exceptional agility — the premier anti-fire platform.',
  role: AircraftRole.elemental,
  storeCharges: const {'Cryo Bomb': 6},
  baseStats: AircraftStats(speed: 0.80, maneuverability: 0.90,
      payload: 0.40, durability: 0.70, climbRate: 0.85),
  upgradeSlots: UpgradeSlots(airframe: 22, systems: 32, payload: 16),
  aero: AeroConfig(
    maxThrust: 12.0, kLift: 0.45, cd0: 0.020, kInduced: 0.042,
    clZero: 0.25, clPerDeg: 0.09,
    flapsClDelta: [0.0, 0.25, 0.45, 0.65], flapsCdDelta: [0.0, 0.018, 0.055, 0.110],
    stallAoaDeg: [16.0, 17.5, 18.5, 20.0],
    gearCdDelta: 0.055, mass: 1.0, pitchFollowRate: 3.0,
  ),
);

const _fireHawk = AircraftConfig(
  id: 'firefighter', displayName: 'FireHawk', icon: '🔥', unlockRp: 0,
  description: 'Balanced fighter-bomber. Responsive and forgiving — ideal starter.',
  role: AircraftRole.fighter,
  storeCharges: const {'Cryo Bomb': 2},
  baseStats: AircraftStats(speed: 0.65, maneuverability: 0.80,
      payload: 0.45, durability: 0.65, climbRate: 0.75),
  upgradeSlots: UpgradeSlots(airframe: 28, systems: 20, payload: 18),
  aero: AeroConfig(
    maxThrust: 10.0, kLift: 0.42, cd0: 0.024, kInduced: 0.048,
    clZero: 0.28, clPerDeg: 0.088,
    flapsClDelta: [0.0, 0.28, 0.50, 0.72], flapsCdDelta: [0.0, 0.020, 0.060, 0.120],
    stallAoaDeg: [15.0, 16.5, 18.0, 19.5],
    gearCdDelta: 0.060, mass: 1.1, pitchFollowRate: 2.8,
  ),
);

const _skyTanker = AircraftConfig(
  id: 'skytanker', displayName: 'SkyTanker', icon: '🛢️', unlockRp: 0,
  description: 'Massive tanker. Triple payload, but handles like a barn door.',
  role: AircraftRole.tanker,
  storeCharges: const {'Cryo Bomb': 12},
  baseStats: AircraftStats(speed: 0.35, maneuverability: 0.30,
      payload: 0.95, durability: 0.90, climbRate: 0.40),
  upgradeSlots: UpgradeSlots(airframe: 32, systems: 18, payload: 36),
  aero: AeroConfig(
    maxThrust: 8.0, kLift: 0.55, cd0: 0.038, kInduced: 0.065,
    clZero: 0.22, clPerDeg: 0.075,
    flapsClDelta: [0.0, 0.30, 0.55, 0.80], flapsCdDelta: [0.0, 0.025, 0.080, 0.160],
    stallAoaDeg: [13.0, 14.5, 16.0, 17.5],
    gearCdDelta: 0.070, mass: 1.8, pitchFollowRate: 2.0,
  ),
);

const _seaBird = AircraftConfig(
  id: 'seabird', displayName: 'SeaBird', icon: '🌊', unlockRp: 3500,
  gearLeverPosition: GearLeverPosition.leftOfLeft,
  description: 'Amphibious scooper. Refills retardant by skimming lakes mid-flight.',
  role: AircraftRole.amphibious,
  baseStats: AircraftStats(speed: 0.55, maneuverability: 0.60,
      payload: 0.65, durability: 0.75, climbRate: 0.60, scoopRate: 0.90),
  upgradeSlots: UpgradeSlots(airframe: 24, systems: 26, payload: 28),
  aero: AeroConfig(
    maxThrust: 9.0, kLift: 0.48, cd0: 0.030, kInduced: 0.052,
    clZero: 0.30, clPerDeg: 0.085,
    flapsClDelta: [0.0, 0.32, 0.55, 0.75], flapsCdDelta: [0.0, 0.022, 0.065, 0.130],
    stallAoaDeg: [14.0, 15.5, 17.0, 18.5],
    gearCdDelta: 0.065, mass: 1.3, pitchFollowRate: 2.4,
  ),
);

const _stormRider = AircraftConfig(
  id: 'stormrider', displayName: 'StormRider', icon: '⚡', unlockRp: 6000,
  description: 'Elemental specialist. Blistering speed, amplified abilities, fragile.',
  role: AircraftRole.elemental,
  baseStats: AircraftStats(speed: 0.95, maneuverability: 0.95,
      payload: 0.25, durability: 0.40, climbRate: 0.90),
  upgradeSlots: UpgradeSlots(airframe: 18, systems: 30, payload: 14),
  aero: AeroConfig(
    maxThrust: 15.0, kLift: 0.40, cd0: 0.018, kInduced: 0.038,
    clZero: 0.22, clPerDeg: 0.092,
    flapsClDelta: [0.0, 0.22, 0.40, 0.60], flapsCdDelta: [0.0, 0.015, 0.048, 0.095],
    stallAoaDeg: [17.0, 18.0, 19.0, 20.5],
    gearCdDelta: 0.050, mass: 0.8, pitchFollowRate: 3.5,
  ),
);
