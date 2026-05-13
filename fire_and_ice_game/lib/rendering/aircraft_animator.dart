import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'scene_node.dart';
import '../game/game_state.dart';

/// AircraftAnimator — drives control-surface deflections each frame.
///
/// Owns the continuous animation accumulators (propeller angle, bay-door lerp)
/// so game_widget.dart does not need to hold them as separate fields.
///
/// Deflection rules (research references: DCS, FlightGear, Tiny Combat Arena):
///
///  Aileron L:  rotation.x = +bankRad × 0.40   (UP when banking left)
///  Aileron R:  rotation.x = -bankRad × 0.40   (DOWN when banking left)
///  Elevator:   rotation.x = -pitchRad × 0.35  (trailing edge UP when pitching nose up)
///  Rudder:     rotation.y = -bankRad × 0.18   (coordinated turn proxy)
///  Flaps:      rotation.x → 35° in landing mode, 0° otherwise (lerped)
///  Gear:       position.y offset based on gearProgress; hidden when fully up
///  Propeller:  rotation.z += throttle × 18 rad/s
///  Bay doors:  rotation.z ± lerped to 1.15 rad when armed, 0 when safe
class AircraftAnimator {
  double _propAngle = 0.0;
  double _bayAngle  = 0.0;

  // Gear base Y positions (in aircraft-local space, below centre of fuselage)
  static const double _gearBaseY = -(4.0 * 0.12 * 0.50); // -bh/2

  /// Update all animated nodes from [state] then call root.updateWorldMatrix().
  ///
  /// Must be called AFTER [PhysicsSystem.updateFlight] so flight-state values
  /// are current.
  void update(
    SceneNode root,
    Map<String, SceneNode> parts,
    GameState state,
    double dt,
  ) {
    final toRad = math.pi / 180.0;

    // ── Root: world position + orientation ───────────────────────────────────
    root.position.setFrom(state.playerPosition);
    root.rotation.setValues(
      state.flightPitchAngle * toRad,
      state.playerRotation.y * toRad,
      -state.flightBankAngle * toRad,
    );

    // ── Control surfaces ─────────────────────────────────────────────────────
    final pitchRad = state.flightPitchAngle * toRad;
    final bankRad  = state.flightBankAngle  * toRad;

    _set(parts, 'aileron_l', (n) => n.rotation.x =  bankRad * 0.40);
    _set(parts, 'aileron_r', (n) => n.rotation.x = -bankRad * 0.40);
    _set(parts, 'elevator',  (n) => n.rotation.x = -pitchRad * 0.35);
    // Rudder base is RotateZ=π/2 (span vertical); RotateY deflects trailing edge.
    _set(parts, 'rudder',    (n) => n.rotation.y = -bankRad * 0.18);

    // ── Flaps: deploy in landing mode ────────────────────────────────────────
    final flapTarget = (state.gameMode == GameMode.landing) ? 0.61 : 0.0;
    _set(parts, 'flap_l', (n) {
      n.rotation.x += (flapTarget - n.rotation.x) * math.min(dt * 2.0, 1.0);
    });
    _set(parts, 'flap_r', (n) {
      n.rotation.x = parts['flap_l']?.rotation.x ?? 0.0;
    });

    // ── Landing gear: retract into fuselage ──────────────────────────────────
    final gearOffset = (1.0 - state.gearProgress) * 0.90;
    void syncGear(String id) {
      final node = parts[id];
      if (node == null) return;
      node.visible   = state.gearProgress > 0.02;
      node.position.y = _gearBaseY + gearOffset;
    }
    syncGear('gear_nose');
    syncGear('gear_left');
    syncGear('gear_right');

    // ── Propeller / exhaust bloom ─────────────────────────────────────────────
    _propAngle += state.throttle * 18.0 * dt;
    _set(parts, 'prop', (n) => n.rotation.z = _propAngle);

    // ── Bay doors ─────────────────────────────────────────────────────────────
    final bayTarget = state.suppressionArmed ? 1.15 : 0.0;
    _bayAngle += (bayTarget - _bayAngle) * math.min(dt * 3.5, 1.0);
    _set(parts, 'bay_l', (n) => n.rotation.z = -_bayAngle);
    _set(parts, 'bay_r', (n) => n.rotation.z =  _bayAngle);

    // ── Cascade world matrices ───────────────────────────────────────────────
    root.updateWorldMatrix();
  }

  static void _set(Map<String, SceneNode> parts, String id, void Function(SceneNode) fn) {
    final node = parts[id];
    if (node != null) fn(node);
  }
}
