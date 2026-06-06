import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'scene_node.dart';
import '../game/game_state.dart';

/// Drives control-surface deflections and animated parts each frame.
///
/// Gear Y and probe/drogue Z offsets are cached from the SceneNode's initial
/// position on the first frame so they work regardless of aircraft scale.
class AircraftAnimator {
  double _propAngle = 0.0;
  double _bayAngle  = 0.0;
  double? _probeBaseZ;
  double? _drogueBaseZ;
  final Map<String, double> _gearDeployedY = {};

  void update(
    SceneNode root,
    Map<String, SceneNode> parts,
    GameState state,
    double dt,
  ) {
    final toRad = math.pi / 180.0;

    root.position.setFrom(state.playerPosition);
    root.rotation.setValues(
      state.flightPitchAngle * toRad,
      state.playerRotation.y * toRad,
      -state.flightBankAngle * toRad,
    );

    final pitchRad = state.flightPitchAngle * toRad;
    final bankRad  = state.flightBankAngle  * toRad;

    _set(parts, 'aileron_l', (n) => n.rotation.x =  bankRad * 0.40);
    _set(parts, 'aileron_r', (n) => n.rotation.x = -bankRad * 0.40);
    _set(parts, 'elevator',  (n) => n.rotation.x = -pitchRad * 0.35);
    _set(parts, 'rudder',    (n) => n.rotation.y = -bankRad * 0.18);

    final flapTarget = (state.gameMode == GameMode.landing) ? 0.61 : 0.0;
    _set(parts, 'flap_l', (n) {
      n.rotation.x += (flapTarget - n.rotation.x) * math.min(dt * 2.0, 1.0);
    });
    _set(parts, 'flap_r', (n) {
      n.rotation.x = parts['flap_l']?.rotation.x ?? 0.0;
    });

    // Gear struts — cache deployed Y on first call so any aircraft scale works
    void syncGear(String id) {
      final node = parts[id];
      if (node == null) return;
      final baseY = _gearDeployedY.putIfAbsent(id, () => node.position.y);
      node.visible    = state.gearProgress > 0.02;
      node.position.y = baseY + (1.0 - state.gearProgress) * 0.90;
    }
    syncGear('gear_nose');
    syncGear('gear_left');
    syncGear('gear_right');

    // Gear doors — open (−π/2) when gear down, closed when gear up
    final doorAngle = -state.gearProgress * math.pi / 2;
    _set(parts, 'gear_door_n', (n) => n.rotation.x = doorAngle);
    _set(parts, 'gear_door_l', (n) => n.rotation.x = doorAngle);
    _set(parts, 'gear_door_r', (n) => n.rotation.x = doorAngle);

    // Propellers — single, twin, or quad configs all spin at throttle RPM
    _propAngle += state.throttle * 18.0 * dt;
    _set(parts, 'prop',   (n) => n.rotation.z =  _propAngle);
    _set(parts, 'prop_l', (n) => n.rotation.z =  _propAngle);
    _set(parts, 'prop_r', (n) => n.rotation.z =  _propAngle);
    _set(parts, 'prop_1', (n) => n.rotation.z =  _propAngle);
    _set(parts, 'prop_2', (n) => n.rotation.z = -_propAngle);
    _set(parts, 'prop_3', (n) => n.rotation.z =  _propAngle);
    _set(parts, 'prop_4', (n) => n.rotation.z = -_propAngle);

    // Suppression bay doors
    final bayTarget = state.suppressionArmed ? 1.15 : 0.0;
    _bayAngle += (bayTarget - _bayAngle) * math.min(dt * 3.5, 1.0);
    _set(parts, 'bay_l', (n) => n.rotation.z = -_bayAngle);
    _set(parts, 'bay_r', (n) => n.rotation.z =  _bayAngle);

    // Probe — slides forward (−Z) from nose; cache initial Z on first frame
    _set(parts, 'probe', (n) {
      _probeBaseZ ??= n.position.z;
      n.visible    = state.probeProgress > 0.04;
      n.position.z = _probeBaseZ! - state.probeProgress * 1.5;
    });

    // Drogue — slides backward (+Z) from tail; cache initial Z on first frame
    _set(parts, 'drogue', (n) {
      _drogueBaseZ ??= n.position.z;
      n.visible    = state.drogueProgress > 0.04;
      n.position.z = _drogueBaseZ! + state.drogueProgress * 5.0;
    });

    root.updateWorldMatrix();
  }

  static void _set(Map<String, SceneNode> parts, String id, void Function(SceneNode) fn) {
    final node = parts[id];
    if (node != null) fn(node);
  }
}
