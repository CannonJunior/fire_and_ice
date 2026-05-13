import '../game/aircraft_config.dart';

/// Which of the three upgrade category budgets an upgrade draws from.
enum UpgradeCategory { airframe, systems, payload }

/// One purchasable upgrade for an aircraft.
///
/// Design: Ace Combat 7 parts system — each upgrade costs [slotCost] from its
/// category's budget.  Selecting an upgrade also requires spending [researchCost]
/// RP (research points earned in missions).  The [statDeltas] are additive
/// bonuses applied on top of [AircraftConfig.baseStats].
class AircraftUpgrade {
  final String          id;
  final String          displayName;
  final String          description;
  final UpgradeCategory category;
  final int             slotCost;
  final int             researchCost;

  /// Stat boosts (additive, clamped to 0–1 after application).
  final AircraftStats statDeltas;

  /// IDs of upgrades that must be equipped before this one becomes available.
  final List<String> prerequisites;

  /// Aircraft IDs this upgrade is compatible with (empty = all aircraft).
  final List<String> compatibleWith;

  const AircraftUpgrade({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.slotCost,
    required this.researchCost,
    required this.statDeltas,
    this.prerequisites = const [],
    this.compatibleWith = const [],
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Upgrade catalogue
// All aircraft: compatible unless [compatibleWith] is set.
// ═══════════════════════════════════════════════════════════════════════════════

// ── AIRFRAME ──────────────────────────────────────────────────────────────────

const upgradeEngineL1 = AircraftUpgrade(
  id: 'engine_l1', displayName: 'Enhanced Engine Lv.1',
  description: 'High-output turbofan replacement. +15% speed, +8% climb rate.',
  category: UpgradeCategory.airframe, slotCost: 7, researchCost: 600,
  statDeltas: AircraftStats(speed: 0.15, maneuverability: 0, payload: 0, durability: 0, climbRate: 0.08),
);

const upgradeEngineL2 = AircraftUpgrade(
  id: 'engine_l2', displayName: 'Enhanced Engine Lv.2',
  description: 'Full engine overhaul. +30% speed, +18% climb, afterburner enabled.',
  category: UpgradeCategory.airframe, slotCost: 10, researchCost: 1400,
  statDeltas: AircraftStats(speed: 0.30, maneuverability: 0, payload: 0, durability: 0, climbRate: 0.18),
  prerequisites: ['engine_l1'],
);

const upgradeCompositeWing = AircraftUpgrade(
  id: 'composite_wing', displayName: 'Composite Wing Panels',
  description: 'Carbon-fibre wing skins. +12% maneuverability, -5% drag.',
  category: UpgradeCategory.airframe, slotCost: 6, researchCost: 700,
  statDeltas: AircraftStats(speed: 0.05, maneuverability: 0.12, payload: 0, durability: 0, climbRate: 0.05),
);

const upgradeArmorL1 = AircraftUpgrade(
  id: 'armor_l1', displayName: 'Airframe Reinforcement Lv.1',
  description: 'Kevlar-layered fuselage. +20% durability against terrain impact.',
  category: UpgradeCategory.airframe, slotCost: 8, researchCost: 500,
  statDeltas: AircraftStats(speed: -0.03, maneuverability: 0, payload: 0, durability: 0.20, climbRate: 0),
);

const upgradeArmorL2 = AircraftUpgrade(
  id: 'armor_l2', displayName: 'Airframe Reinforcement Lv.2',
  description: 'Full composite armor shell. +40% durability, enables low-altitude runs.',
  category: UpgradeCategory.airframe, slotCost: 11, researchCost: 1200,
  statDeltas: AircraftStats(speed: -0.05, maneuverability: 0, payload: 0, durability: 0.40, climbRate: 0),
  prerequisites: ['armor_l1'],
);

// ── SYSTEMS ───────────────────────────────────────────────────────────────────

const upgradeThermalSensor = AircraftUpgrade(
  id: 'thermal_sensor', displayName: 'Advanced Thermal Sensor',
  description: 'Longer GPWS range and improved fire detection on the FIRE MFD page.',
  category: UpgradeCategory.systems, slotCost: 4, researchCost: 400,
  statDeltas: AircraftStats(speed: 0, maneuverability: 0, payload: 0, durability: 0, climbRate: 0),
);

const upgradeAutopilotPro = AircraftUpgrade(
  id: 'autopilot_pro', displayName: 'Autopilot Pro Package',
  description: 'Autopilot no longer disengages on minor pitch/roll input.',
  category: UpgradeCategory.systems, slotCost: 5, researchCost: 550,
  statDeltas: AircraftStats(speed: 0, maneuverability: 0, payload: 0, durability: 0, climbRate: 0),
);

const upgradeSuppressionL1 = AircraftUpgrade(
  id: 'suppression_l1', displayName: 'Suppression System Lv.1',
  description: 'Enlarged bay doors, faster open/close cycle. +15% retardant spread.',
  category: UpgradeCategory.systems, slotCost: 6, researchCost: 650,
  statDeltas: AircraftStats(speed: 0, maneuverability: 0, payload: 0.15, durability: 0, climbRate: 0),
);

const upgradeSuppressionL2 = AircraftUpgrade(
  id: 'suppression_l2', displayName: 'Suppression System Lv.2',
  description: 'Dual-feed retardant pumps. +30% spread, unlocks AUTO drop.',
  category: UpgradeCategory.systems, slotCost: 9, researchCost: 1500,
  statDeltas: AircraftStats(speed: 0, maneuverability: 0, payload: 0.30, durability: 0, climbRate: 0),
  prerequisites: ['suppression_l1'],
);

// ── PAYLOAD ───────────────────────────────────────────────────────────────────

const upgradeExtendedTankL1 = AircraftUpgrade(
  id: 'tank_l1', displayName: 'Extended Retardant Tank Lv.1',
  description: '+25% retardant capacity. Slightly increases aircraft weight.',
  category: UpgradeCategory.payload, slotCost: 8, researchCost: 700,
  statDeltas: AircraftStats(speed: -0.04, maneuverability: -0.03, payload: 0.25, durability: 0, climbRate: -0.03),
);

const upgradeExtendedTankL2 = AircraftUpgrade(
  id: 'tank_l2', displayName: 'Extended Retardant Tank Lv.2',
  description: '+50% retardant capacity.',
  category: UpgradeCategory.payload, slotCost: 12, researchCost: 1800,
  statDeltas: AircraftStats(speed: -0.07, maneuverability: -0.05, payload: 0.50, durability: 0, climbRate: -0.05),
  prerequisites: ['tank_l1'],
);

const upgradeExtraPylon = AircraftUpgrade(
  id: 'extra_pylon', displayName: 'Additional Wing Pylon',
  description: '+2 expendable store slots (adds outer wing hardpoints).',
  category: UpgradeCategory.payload, slotCost: 7, researchCost: 800,
  statDeltas: AircraftStats(speed: -0.03, maneuverability: -0.04, payload: 0.10, durability: 0, climbRate: 0),
);

const upgradeQuickReload = AircraftUpgrade(
  id: 'quick_reload', displayName: 'Rapid Store Recharge',
  description: 'High-pressure feed lines. -25% expendable store cooldown.',
  category: UpgradeCategory.payload, slotCost: 6, researchCost: 900,
  statDeltas: AircraftStats(speed: 0, maneuverability: 0, payload: 0.05, durability: 0, climbRate: 0),
);

// ── Master list ────────────────────────────────────────────────────────────────

final List<AircraftUpgrade> allUpgrades = [
  upgradeEngineL1, upgradeEngineL2,
  upgradeCompositeWing,
  upgradeArmorL1, upgradeArmorL2,
  upgradeThermalSensor,
  upgradeAutopilotPro,
  upgradeSuppressionL1, upgradeSuppressionL2,
  upgradeExtendedTankL1, upgradeExtendedTankL2,
  upgradeExtraPylon,
  upgradeQuickReload,
];
