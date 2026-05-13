import 'package:vector_math/vector_math.dart';

/// AbilityData - Defines a single elemental ability.
class AbilityData {
  final String  name;
  final String  description;
  final double  cooldown;
  final double  manaCost;
  final Vector3 color;
  final String  icon;

  /// True → finite charges displayed on wing pylons in the loadout screen.
  /// False → unlimited uses gated only by cooldown (internal systems).
  final bool isExpendable;

  /// Maximum charges for expendable stores (0 = rechargeable).
  final int maxCharges;

  AbilityData({
    required this.name,
    required this.description,
    required this.cooldown,
    required this.manaCost,
    required this.color,
    required this.icon,
    this.isExpendable = false,
    this.maxCharges   = 0,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Expendable stores  — wing pylons, finite charges, long recharge cooldown
// ══════════════════════════════════════════════════════════════════════════════

final _infernoStrike = AbilityData(
  name: 'Inferno Strike',
  description: 'Precision fire-suppression bomb — drops retardant on target.',
  cooldown: 20.0, manaCost: 30.0, icon: '🚀',
  color: Vector3(1.0, 0.35, 0.0),
  isExpendable: true, maxCharges: 4,
);

final _cryoBomb = AbilityData(
  name: 'Cryo Bomb',
  description: 'Cryo-suppression pod — flash-freezes a fire zone.',
  cooldown: 20.0, manaCost: 30.0, icon: '💥',
  color: Vector3(0.0, 0.8, 1.0),
  isExpendable: true, maxCharges: 4,
);

final _heatSeeker = AbilityData(
  name: 'Heat Seeker',
  description: 'Heat-guided fire burst — creates controlled firebreaks.',
  cooldown: 25.0, manaCost: 25.0, icon: '🔥',
  color: Vector3(1.0, 0.2, 0.0),
  isExpendable: true, maxCharges: 3,
);

final _frostMissile = AbilityData(
  name: 'Frost Missile',
  description: 'Targeted cryo burst — suppresses concentrated fire columns.',
  cooldown: 25.0, manaCost: 25.0, icon: '❄️',
  color: Vector3(0.3, 0.7, 1.0),
  isExpendable: true, maxCharges: 3,
);

// ══════════════════════════════════════════════════════════════════════════════
// Rechargeable systems — internal bay, unlimited uses, short cooldown
// ══════════════════════════════════════════════════════════════════════════════

final _fireBolt = AbilityData(
  name: 'Fire Bolt',
  description: 'Rapid fire pulse from the elemental drive.',
  cooldown: 2.0, manaCost: 15.0, icon: '⚡',
  color: Vector3(1.0, 0.5, 0.0),
);

final _iceShard = AbilityData(
  name: 'Ice Shard',
  description: 'Quick ice projectile — punctures fire curtains.',
  cooldown: 2.5, manaCost: 15.0, icon: '🌀',
  color: Vector3(0.5, 0.9, 1.0),
);

final _windGust = AbilityData(
  name: 'Wind Gust',
  description: 'Pressure wave — redirects smoke columns and embers.',
  cooldown: 5.0, manaCost: 20.0, icon: '💨',
  color: Vector3(0.7, 0.9, 0.7),
);

final _flameWard = AbilityData(
  name: 'Flame Ward',
  description: 'Protective heat aura — shields airframe from fire damage.',
  cooldown: 10.0, manaCost: 35.0, icon: '🛡️',
  color: Vector3(1.0, 0.7, 0.0),
);

// ── Per-aircraft loadouts ──────────────────────────────────────────────────────

/// Full 8-slot loadout for IceFighter and all other aircraft.
final List<AbilityData> windwalkerAbilities = [
  _infernoStrike, _cryoBomb, _heatSeeker, _frostMissile, // pylons
  _fireBolt, _iceShard, _windGust, _flameWard,            // internal
];

/// FireHawk loadout — 7 slots (no Frost Missile; fire-focused airframe).
final List<AbilityData> fireHawkAbilities = [
  _infernoStrike, _cryoBomb, _heatSeeker,      // 3 pylon stores
  _fireBolt, _iceShard, _windGust, _flameWard, // internal systems
];

/// Returns the ability loadout for the given aircraft id.
List<AbilityData> abilitiesFor(String aircraftId) =>
    aircraftId == 'firefighter' ? fireHawkAbilities : windwalkerAbilities;
