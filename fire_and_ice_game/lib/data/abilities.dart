import 'package:vector_math/vector_math.dart';

/// AbilityData - Defines a single elemental ability.
///
/// All tunable values (cooldown, manaCost) should be sourced from
/// this data class rather than hardcoded in game logic.
///
/// Usage:
/// ```dart
/// final ability = windwalkerAbilities[0]; // Fire Blast
/// if (mana >= ability.manaCost && cooldown <= 0) {
///   activateAbility(ability);
/// }
/// ```
class AbilityData {
  /// Display name shown in the action bar
  final String name;

  /// Tooltip description for the ability
  final String description;

  /// Cooldown in seconds before ability can be used again
  final double cooldown;

  /// Mana cost to activate this ability
  final double manaCost;

  /// RGB color for visual effects (0.0 - 1.0 range)
  final Vector3 color;

  /// Emoji icon displayed in the action bar slot
  final String icon;

  const AbilityData({
    required this.name,
    required this.description,
    required this.cooldown,
    required this.manaCost,
    required this.color,
    required this.icon,
  });
}

// ── Ability definitions ────────────────────────────────────────────────────

/// Fire Blast - Rapid-fire projectile ability.
///
/// Quick cooldown makes this the bread-and-butter offensive ability.
/// Orange-red visual effect matches elemental fire theme.
final _fireBlast = AbilityData(
  name: 'Fire Blast',
  description: 'Launch a rapid blast of fire energy at your target.',
  cooldown: 2.0,
  manaCost: 15.0,
  color: Vector3(1.0, 0.45, 0.0), // Orange
  icon: '🔥',
);

/// Ice Nova - AoE freeze burst centered on the player.
///
/// Long cooldown reflects high-impact area denial effect.
/// Cyan color distinguishes ice abilities from fire.
final _iceNova = AbilityData(
  name: 'Ice Nova',
  description: 'Unleash a burst of freezing energy in all directions.',
  cooldown: 8.0,
  manaCost: 40.0,
  color: Vector3(0.0, 0.9, 1.0), // Cyan
  icon: '❄️',
);

/// Heat Wave - Forward cone of superheated air.
///
/// Medium cooldown, directional effect rewards positional play.
/// Red-orange blend between fire and heat themes.
final _heatWave = AbilityData(
  name: 'Heat Wave',
  description: 'Project a scorching cone of heat energy forward.',
  cooldown: 5.0,
  manaCost: 25.0,
  color: Vector3(1.0, 0.2, 0.05), // Red-orange
  icon: '🌊',
);

/// Frost Bolt - Targeted slowing projectile.
///
/// Short cooldown utility ability. Light blue keeps it visually
/// distinct from the deeper cyan of Ice Nova.
final _frostBolt = AbilityData(
  name: 'Frost Bolt',
  description: 'Hurl a bolt of ice that slows and chills the target.',
  cooldown: 3.0,
  manaCost: 20.0,
  color: Vector3(0.5, 0.8, 1.0), // Light blue
  icon: '🧊',
);

/// All Windwalker abilities in default action bar order.
///
/// Index corresponds to action bar slot (0 = slot 1, etc.).
/// Slots 5-9 are empty by default.
final List<AbilityData> windwalkerAbilities = [
  _fireBlast,  // Slot 1
  _iceNova,    // Slot 2
  _heatWave,   // Slot 3
  _frostBolt,  // Slot 4
];
