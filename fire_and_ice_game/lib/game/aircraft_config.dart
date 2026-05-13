/// Where the landing gear lever appears in the cockpit layout.
enum GearLeverPosition { center, leftOfLeft }

/// Role drives which ability loadout is used and which stat bars to highlight.
enum AircraftRole { fighter, tanker, amphibious, elemental }

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

  /// Research points required to unlock (0 = available from start).
  final int unlockRp;

  const AircraftConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.description,
    required this.role,
    required this.baseStats,
    required this.upgradeSlots,
    this.gearLeverPosition = GearLeverPosition.center,
    this.unlockRp = 0,
  });

  factory AircraftConfig.fromJson(Map<String, dynamic> json) => AircraftConfig(
    id:          json['id']          as String,
    displayName: json['displayName'] as String,
    icon:        json['icon']        as String,
    description: json['description'] as String,
    role:        AircraftRole.values.firstWhere(
                   (r) => r.name == (json['role'] as String? ?? 'fighter'),
                   orElse: () => AircraftRole.fighter),
    baseStats:   const AircraftStats(speed: 0.6, maneuverability: 0.7,
                     payload: 0.5, durability: 0.7, climbRate: 0.7),
    upgradeSlots: const UpgradeSlots(airframe: 28, systems: 20, payload: 22),
    gearLeverPosition: (json['gearLeverPosition'] as String?) == 'leftOfLeft'
        ? GearLeverPosition.leftOfLeft : GearLeverPosition.center,
    unlockRp: (json['unlockRp'] as int?) ?? 0,
  );

  static List<AircraftConfig> get defaults => const [
    _iceFighter, _fireHawk, _skyTanker, _seaBird, _stormRider,
  ];
}

// ── Aircraft catalogue ─────────────────────────────────────────────────────────

const _iceFighter = AircraftConfig(
  id: 'icefighter', displayName: 'IceFighter', icon: '❄️', unlockRp: 0,
  description: 'Ice-elemental interceptor. Heightened ability amplification and exceptional agility — the premier anti-fire platform.',
  role: AircraftRole.elemental,
  baseStats: AircraftStats(speed: 0.80, maneuverability: 0.90,
      payload: 0.40, durability: 0.70, climbRate: 0.85),
  upgradeSlots: UpgradeSlots(airframe: 22, systems: 32, payload: 16),
);

const _fireHawk = AircraftConfig(
  id: 'firefighter', displayName: 'FireHawk', icon: '🔥', unlockRp: 0,
  description: 'Balanced fighter-bomber. Responsive and forgiving — ideal starter.',
  role: AircraftRole.fighter,
  baseStats: AircraftStats(speed: 0.65, maneuverability: 0.80,
      payload: 0.45, durability: 0.65, climbRate: 0.75),
  upgradeSlots: UpgradeSlots(airframe: 28, systems: 20, payload: 18),
);

const _skyTanker = AircraftConfig(
  id: 'skytanker', displayName: 'SkyTanker', icon: '🛢️', unlockRp: 2000,
  description: 'Massive tanker. Triple payload, but handles like a barn door.',
  role: AircraftRole.tanker,
  baseStats: AircraftStats(speed: 0.35, maneuverability: 0.30,
      payload: 0.95, durability: 0.90, climbRate: 0.40),
  upgradeSlots: UpgradeSlots(airframe: 32, systems: 18, payload: 36),
);

const _seaBird = AircraftConfig(
  id: 'seabird', displayName: 'SeaBird', icon: '🌊', unlockRp: 3500,
  gearLeverPosition: GearLeverPosition.leftOfLeft,
  description: 'Amphibious scooper. Refills retardant by skimming lakes mid-flight.',
  role: AircraftRole.amphibious,
  baseStats: AircraftStats(speed: 0.55, maneuverability: 0.60,
      payload: 0.65, durability: 0.75, climbRate: 0.60, scoopRate: 0.90),
  upgradeSlots: UpgradeSlots(airframe: 24, systems: 26, payload: 28),
);

const _stormRider = AircraftConfig(
  id: 'stormrider', displayName: 'StormRider', icon: '⚡', unlockRp: 6000,
  description: 'Elemental specialist. Blistering speed, amplified abilities, fragile.',
  role: AircraftRole.elemental,
  baseStats: AircraftStats(speed: 0.95, maneuverability: 0.95,
      payload: 0.25, durability: 0.40, climbRate: 0.90),
  upgradeSlots: UpgradeSlots(airframe: 18, systems: 30, payload: 14),
);
