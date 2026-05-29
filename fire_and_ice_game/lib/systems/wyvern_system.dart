import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math.dart';
import '../enemies/wyvern.dart';
import '../game/game_state.dart';
import 'ability_system.dart';

/// Manages fire wyvern AI, ability hit-detection, and combat economy.
///
/// Wyverns patrol fire zones in three AI states:
///   patrol  → circles the fire zone at altitude
///   chase   → pursues the player on detection
///   attack  → breathes fire (deals damage every attackCooldown seconds)
///
/// The player damages wyverns by firing abilities within range.
/// Ice abilities deal bonus damage to fire wyverns.
class WyvernSystem {
  WyvernSystem._();

  // ── Config (overridden from flight_config.json §wyvern) ───────────────────

  static double cfgSpeed          =  4.5;
  static double cfgChaseSpeed     =  7.0;
  static double cfgChaseRange     = 80.0;
  static double cfgAttackRange    = 18.0;
  static double cfgAttackDmg      = 10.0;
  static double cfgAttackCooldown =  3.0;
  static double cfgHitboxRadius   = 22.0;  // rechargeable ability range
  static double cfgMissileRadius  = 55.0;  // expendable missile range
  static double cfgDmgBase        = 25.0;
  static double cfgDmgIceBonus    =  2.0;  // multiplier for ice vs fire wyvern
  static double cfgDeathTimer     =  2.5;  // seconds before dead wyvern removed
  static double cfgHealth         = 100.0;
  static double cfgRpReward       = 50.0;
  static double cfgRadarRange     = 120.0; // world units mapped to radar edge

  static Future<void> loadConfig() async {
    try {
      final raw  = await rootBundle.loadString('assets/data/flight_config.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _applyConfig(data);
    } catch (e) {
      debugPrint('[WyvernSystem] Config load failed: $e — using defaults');
    }
  }

  static void _applyConfig(Map<String, dynamic> data) {
    final w = data['wyvern'] as Map<String, dynamic>?;
    if (w == null) return;
    cfgSpeed          = _d(w, 'speed',          cfgSpeed);
    cfgChaseSpeed     = _d(w, 'chaseSpeed',      cfgChaseSpeed);
    cfgChaseRange     = _d(w, 'chaseRange',      cfgChaseRange);
    cfgAttackRange    = _d(w, 'attackRange',     cfgAttackRange);
    cfgAttackDmg      = _d(w, 'attackDmg',       cfgAttackDmg);
    cfgAttackCooldown = _d(w, 'attackCooldown',  cfgAttackCooldown);
    cfgHitboxRadius   = _d(w, 'hitboxRadius',    cfgHitboxRadius);
    cfgMissileRadius  = _d(w, 'missileRadius',   cfgMissileRadius);
    cfgDmgBase        = _d(w, 'dmgBase',         cfgDmgBase);
    cfgDmgIceBonus    = _d(w, 'dmgIceBonus',     cfgDmgIceBonus);
    cfgDeathTimer     = _d(w, 'deathTimer',      cfgDeathTimer);
    cfgHealth         = _d(w, 'health',          cfgHealth);
    cfgRpReward       = _d(w, 'rpReward',        cfgRpReward);
    cfgRadarRange     = _d(w, 'radarRange',      cfgRadarRange);
  }

  static double _d(Map<String, dynamic> m, String k, double def) =>
      (m[k] as num?)?.toDouble() ?? def;

  // ── Frame update ───────────────────────────────────────────────────────────

  static void tick(GameState state, double dt) {
    if (state.wyverns.isEmpty) return;
    _applyAbilityDamage(state);
    state.wyverns.removeWhere((w) {
      _tickWyvern(w, state, dt);
      if (w.isDying && w.stateTimer > cfgDeathTimer) {
        state.earnResearchPoints(cfgRpReward.toInt());
        debugPrint('[WyvernSystem] ${w.id} destroyed — +${cfgRpReward.toInt()} RP');
        return true;
      }
      return false;
    });
  }

  // Scratch vectors — reused each tick to avoid per-frame allocation.
  static final Vector3 _toPlayer   = Vector3.zero();
  static final Vector3 _hitScratch = Vector3.zero();

  static void _tickWyvern(Wyvern w, GameState state, double dt) {
    w.stateTimer     += dt;
    w.attackCooldown  = math.max(0.0, w.attackCooldown - dt);
    _toPlayer.setFrom(state.playerPosition);
    _toPlayer.sub(w.position);
    final dist = _toPlayer.length;

    switch (w.state) {
      case WyvernState.patrol:
        _patrol(w, dt);
        if (dist < cfgChaseRange) {
          w.state = WyvernState.chase; w.stateTimer = 0.0;
          debugPrint('[WyvernSystem] ${w.id} PATROL→CHASE');
        }

      case WyvernState.chase:
        _chase(w, dist, dt);
        if (dist < cfgAttackRange) {
          w.state = WyvernState.attack; w.stateTimer = 0.0;
          debugPrint('[WyvernSystem] ${w.id} CHASE→ATTACK');
        } else if (dist > cfgChaseRange * 1.3) {
          w.state = WyvernState.patrol; w.stateTimer = 0.0;
          debugPrint('[WyvernSystem] ${w.id} CHASE→PATROL (fled)');
        }

      case WyvernState.attack:
        _attack(w, state, dist, dt);
        if (dist > cfgAttackRange * 1.6) {
          w.state = WyvernState.chase; w.stateTimer = 0.0;
        }

      case WyvernState.dying:
        w.velocity.y -= 5.0 * dt;
        w.velocity.scale((1.0 - 1.5 * dt).clamp(0.0, 1.0));
        w.position.addScaled(w.velocity, dt);
    }
  }

  static void _patrol(Wyvern w, double dt) {
    w.patrolAngle += (cfgSpeed / w.patrolRadius) * dt;
    // Set velocity toward the next patrol waypoint — no heap allocation.
    w.velocity.setValues(
      w.patrolCenter.x + math.cos(w.patrolAngle) * w.patrolRadius,
      w.patrolCenter.y,
      w.patrolCenter.z + math.sin(w.patrolAngle) * w.patrolRadius,
    );
    w.velocity.sub(w.position);
    if (w.velocity.length > 0.1) {
      w.velocity.normalize();
      w.velocity.scale(cfgSpeed);
    }
    w.position.addScaled(w.velocity, dt);
  }

  static void _chase(Wyvern w, double dist, double dt) {
    if (dist > 0.1) {
      w.velocity.setFrom(_toPlayer);
      w.velocity.normalize();
      w.velocity.scale(cfgChaseSpeed);
    }
    w.position.addScaled(w.velocity, dt);
  }

  static void _attack(Wyvern w, GameState state, double dist, double dt) {
    // Drift slowly toward player while attacking
    if (dist > 0.1) {
      w.velocity.setFrom(_toPlayer);
      w.velocity.normalize();
      w.velocity.scale(cfgChaseSpeed * 0.25);
    }
    w.position.addScaled(w.velocity, dt);

    if (w.attackCooldown > 0.0) return;
    w.attackCooldown = cfgAttackCooldown;
    state.takeDamage(cfgAttackDmg);

    // Spawn a fire breath visual effect at the wyvern's position
    final fx = VisualEffect(
      position: Vector3.copy(w.position),
      color:    Vector3(1.0, 0.3, 0.0),
      lifetime: 0.8,
      scale:    1.8,
    )..damageTick = true; // prevent self-damage loop
    AbilitySystem.activeEffects.add(fx);

    debugPrint('[WyvernSystem] ${w.id} fire breath — ${cfgAttackDmg} dmg');
  }

  // ── Ability hit-detection ──────────────────────────────────────────────────

  static void _applyAbilityDamage(GameState state) {
    for (final effect in AbilitySystem.activeEffects) {
      if (effect.damageTick) continue;
      effect.damageTick = true;

      final hitRadius  = effect.lifetime >= 0.9 ? cfgMissileRadius : cfgHitboxRadius;
      final hitRadius2 = hitRadius * hitRadius;

      for (final w in state.wyverns) {
        if (w.isDying) continue;
        _hitScratch.setFrom(effect.position);
        _hitScratch.sub(w.position);
        if (_hitScratch.length2 >= hitRadius2) continue;

        // Ice effects (dominant blue, low red) deal bonus damage to fire wyvern
        final isIce = effect.color.b > 0.5 && effect.color.r <= 0.5;
        final dmg   = cfgDmgBase * (isIce ? cfgDmgIceBonus : 1.0);
        w.takeDamage(dmg);
        debugPrint('[WyvernSystem] Hit ${w.id} for ${dmg.toStringAsFixed(1)} '
            '(${isIce ? "ICE×${cfgDmgIceBonus}" : "FIRE"}) '
            'HP: ${w.health.toStringAsFixed(1)}');
      }
    }
  }

  // ── Spawn helpers ──────────────────────────────────────────────────────────

  /// Populate [state.wyverns] with one wyvern per major fire zone.
  static void spawnDefault(GameState state) {
    state.wyverns = [
      Wyvern(
        id: 'wyvern_alpha',
        position:     Vector3(-45.0, 30.0,  28.0),
        maxHealth:    cfgHealth,
        patrolCenter: Vector3(-45.0, 30.0,  28.0),
        patrolRadius: 25.0,
      ),
      Wyvern(
        id: 'wyvern_beta',
        position:     Vector3( 22.0, 35.0, -60.0),
        maxHealth:    cfgHealth,
        patrolCenter: Vector3( 22.0, 35.0, -60.0),
        patrolRadius: 30.0,
      ),
      Wyvern(
        id: 'wyvern_gamma',
        position:     Vector3( 55.0, 28.0,  42.0),
        maxHealth:    cfgHealth,
        patrolCenter: Vector3( 55.0, 28.0,  42.0),
        patrolRadius: 20.0,
      ),
    ];
    debugPrint('[WyvernSystem] Spawned ${state.wyverns.length} fire wyverns');
  }
}
