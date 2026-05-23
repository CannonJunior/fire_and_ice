import 'package:vector_math/vector_math.dart';

enum WyvernState { patrol, chase, attack, dying }

/// Fire wyvern — air-to-air combat opponent guarding fire zones.
class Wyvern {
  final String   id;
  Vector3        position;
  Vector3        velocity;
  double         health;
  final double   maxHealth;
  WyvernState    state;
  double         stateTimer;
  double         attackCooldown;
  double         patrolAngle;
  final Vector3  patrolCenter;
  final double   patrolRadius;

  Wyvern({
    required this.id,
    required this.position,
    required this.maxHealth,
    Vector3? patrolCenter,
    this.patrolRadius = 25.0,
  })  : velocity       = Vector3.zero(),
        health         = maxHealth,
        state          = WyvernState.patrol,
        stateTimer     = 0.0,
        attackCooldown = 0.0,
        patrolAngle    = 0.0,
        patrolCenter   = patrolCenter ?? Vector3.copy(position);

  bool   get isDying        => state == WyvernState.dying;
  double get healthFraction => (health / maxHealth).clamp(0.0, 1.0);

  void takeDamage(double amount) {
    health = (health - amount).clamp(0.0, maxHealth);
    if (health <= 0 && state != WyvernState.dying) {
      state      = WyvernState.dying;
      stateTimer = 0.0;
    }
  }
}
