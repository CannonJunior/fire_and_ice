import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../data/abilities.dart';
import '../game/game_state.dart';

/// VisualEffect - A transient particle / flash effect in world space.
///
/// Created when an ability fires and ticks down its [lifetime] each frame.
/// The [color] and [scale] drive HUD or WebGL overlay rendering.
class VisualEffect {
  /// World-space origin of the effect
  Vector3 position;

  /// Effect color (RGB 0-1), sourced from the ability definition
  Vector3 color;

  /// Total lifetime in seconds
  double lifetime;

  /// Remaining lifetime in seconds (counts down to 0)
  double remaining;

  /// Current scale (grows outward then fades)
  double scale;

  VisualEffect({
    required this.position,
    required this.color,
    required this.lifetime,
    double? scale,
  })  : remaining = lifetime,
        scale     = scale ?? 1.0;

  /// Normalized progress 0→1 (0 = just fired, 1 = expired)
  double get progress => 1.0 - (remaining / lifetime).clamp(0.0, 1.0);

  /// Whether this effect has expired
  bool get isExpired => remaining <= 0.0;
}

/// AbilitySystem - Manages ability cooldowns, activation, and visual effects.
///
/// Effects are purely visual (no actual damage or hit-detection system).
/// The HUD polls [activeEffects] each frame to render flash overlays.
///
/// Usage:
/// ```dart
/// // Once per frame:
/// AbilitySystem.update(state, dt);
///
/// // On slot key press:
/// AbilitySystem.activateAbility(state, slotIndex);
/// ```
class AbilitySystem {
  AbilitySystem._(); // Static-only class

  /// All currently active visual effects
  static final List<VisualEffect> activeEffects = [];

  // ── Frame update ─────────────────────────────────────────────────────────

  /// Tick cooldowns and advance visual effects by [dt] seconds.
  ///
  /// Call once per game loop frame before rendering.
  static void update(GameState state, double dt) {
    state.tickCooldowns(dt);
    _tickEffects(dt);
  }

  // ── Activation ───────────────────────────────────────────────────────────

  /// Attempt to activate the ability in action bar slot [slotIndex] (0-based).
  ///
  /// Fails silently (no effect) if:
  ///  - slot is empty
  ///  - ability is on cooldown
  ///  - player lacks mana
  ///
  /// On success: spends mana, starts cooldown, spawns a visual effect.
  static void activateAbility(GameState state, int slotIndex) {
    if (slotIndex < 0 || slotIndex >= state.actionBarSlots.length) return;

    final slotName = state.actionBarSlots[slotIndex];
    if (slotName.isEmpty) return;

    final ability = state.abilityByName(slotName);
    if (ability == null) return;

    if (!state.isReady(ability)) {
      debugPrint('[AbilitySystem] ${ability.name} on cooldown');
      return;
    }

    if (!state.hasManaFor(ability)) {
      debugPrint('[AbilitySystem] Not enough mana for ${ability.name}');
      return;
    }

    // Commit the cast
    state.spendMana(ability.manaCost);
    state.startCooldown(ability);

    _spawnEffect(ability, state.playerPosition);

    debugPrint('[AbilitySystem] Activated ${ability.name}');
  }

  // ── Visual effects ────────────────────────────────────────────────────────

  /// Spawn a visual effect appropriate to [ability] at [origin].
  static void _spawnEffect(AbilityData ability, Vector3 origin) {
    final lifetime = _effectLifetime(ability);
    activeEffects.add(VisualEffect(
      position: Vector3.copy(origin),
      color:    Vector3.copy(ability.color),
      lifetime: lifetime,
      scale:    _effectStartScale(ability),
    ));
  }

  /// Lifetime (seconds) per ability type.
  static double _effectLifetime(AbilityData ability) {
    switch (ability.name) {
      case 'Fire Blast':  return 0.4;
      case 'Ice Nova':    return 1.2;
      case 'Heat Wave':   return 0.8;
      case 'Frost Bolt':  return 0.6;
      default:            return 0.5;
    }
  }

  /// Initial visual scale per ability type.
  static double _effectStartScale(AbilityData ability) {
    switch (ability.name) {
      case 'Ice Nova':  return 2.5; // Larger AoE burst
      case 'Heat Wave': return 1.8;
      default:          return 1.0;
    }
  }

  /// Advance all effects and remove expired ones.
  static void _tickEffects(double dt) {
    for (final effect in activeEffects) {
      effect.remaining -= dt;
      // Scale grows outward as the effect ages
      effect.scale += dt * 3.0;
    }
    activeEffects.removeWhere((e) => e.isExpired);
  }

  /// Remove all active effects (e.g. on scene reset).
  static void clearEffects() => activeEffects.clear();
}
