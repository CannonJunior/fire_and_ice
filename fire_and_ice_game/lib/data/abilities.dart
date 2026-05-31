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

  /// World-unit radius within which this ability extinguishes fires (null = no suppression).
  final double? suppressRadius;

  AbilityData({
    required this.name,
    required this.description,
    required this.cooldown,
    required this.manaCost,
    required this.color,
    required this.icon,
    this.isExpendable  = false,
    this.maxCharges    = 0,
    this.suppressRadius,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Primary weapon — hold key "1" for sustained ice-breath beam
// ══════════════════════════════════════════════════════════════════════════════

/// Hold key "1" to sustain.  No cooldown or one-shot mana cost — mana drains
/// continuously at 18/sec while firing.  Longer holds widen and intensify the
/// beam.  Game-widget handles this ability specially; AbilitySystem is bypassed.
final _iceBreath = AbilityData(
  name: 'Ice Breath',
  description: 'Hold to sustain — dragon ice beam suppresses fire in a forward cone.',
  cooldown: 0.0, manaCost: 0.0, icon: '❄',
  color: Vector3(0.2, 0.82, 1.0),
  suppressRadius: 28.0,
);

// ══════════════════════════════════════════════════════════════════════════════
// Expendable stores  — wing pylons, finite charges, long recharge cooldown
// ══════════════════════════════════════════════════════════════════════════════

final _cryoBomb = AbilityData(
  name: 'Cryo Bomb',
  description: 'Drop from aircraft — flash-freezes a fire zone. No mana cost; charges vary by airframe.',
  cooldown: 5.0, manaCost: 0.0, icon: '💥',
  color: Vector3(0.0, 0.8, 1.0),
  isExpendable: true, maxCharges: 4, suppressRadius: 25.0,
);

final _heatSeeker = AbilityData(
  name: 'Heat Seeker',
  description: 'Heat-guided fire burst — creates controlled firebreaks.',
  cooldown: 25.0, manaCost: 25.0, icon: '🔥',
  color: Vector3(1.0, 0.2, 0.0),
  isExpendable: true, maxCharges: 3, suppressRadius: 15.0,
);

final _frostMissile = AbilityData(
  name: 'Frost Missile',
  description: 'Targeted cryo burst — suppresses concentrated fire columns.',
  cooldown: 25.0, manaCost: 25.0, icon: '❄️',
  color: Vector3(0.3, 0.7, 1.0),
  isExpendable: true, maxCharges: 3, suppressRadius: 18.0,
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
  color: Vector3(0.5, 0.9, 1.0), suppressRadius: 10.0,
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
  _iceBreath, _cryoBomb, _heatSeeker, _frostMissile, // slot 1 = ice breath + pylons
  _fireBolt, _iceShard, _windGust, _flameWard,        // internal
];

/// FireHawk loadout — 7 slots (fire-focused airframe; ice breath in slot 1).
final List<AbilityData> fireHawkAbilities = [
  _iceBreath, _cryoBomb, _heatSeeker,          // slot 1 = ice breath + pylons
  _fireBolt, _iceShard, _windGust, _flameWard, // internal systems
];

/// Returns the ability loadout for the given aircraft id.
List<AbilityData> abilitiesFor(String aircraftId) =>
    aircraftId == 'firefighter' ? fireHawkAbilities : windwalkerAbilities;
