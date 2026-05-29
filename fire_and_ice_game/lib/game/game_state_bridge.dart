import 'dart:html' as html;
import 'game_state.dart';

/// Writes key game state to a hidden DOM element every frame.
/// Tests read it with:
///   JSON.parse(document.getElementById('_gs').dataset.state)
void writeGameStateBridge(GameState s, int frame) {
  final cd = s.abilityCooldowns.entries
      .where((e) => e.value > 0)
      .map((e) => '"${e.key}":${e.value.toStringAsFixed(4)}')
      .join(',');
  final j = '{"frame":$frame'
      ',"throttle":${s.throttle.toStringAsFixed(4)}'
      ',"leftMfdPage":${s.leftMfdPage}'
      ',"rightMfdPage":${s.rightMfdPage}'
      ',"auxDisplayPage":${s.auxDisplayPage}'
      ',"autopilotEnabled":${s.autopilotEnabled}'
      ',"lockedWaypoint":${s.lockedWaypoint}'
      ',"gearTargetDown":${s.gearTargetDown}'
      ',"gearMoving":${s.gearMoving}'
      ',"gearDeployed":${s.gearDeployed}'
      ',"viewMode":"${s.viewMode.name}"'
      ',"gameMode":"${s.gameMode.name}"'
      ',"halonShieldL":${s.halonShieldL}'
      ',"halonShieldR":${s.halonShieldR}'
      ',"halonFiredL":${s.halonFiredL}'
      ',"halonFiredR":${s.halonFiredR}'
      ',"mapZoom":${s.mapZoom}'
      ',"mana":${s.mana.toStringAsFixed(2)}'
      ',"flightSpeed":${s.flightSpeed.toStringAsFixed(3)}'
      ',"groundSpeed":${s.groundSpeed.toStringAsFixed(3)}'
      ',"flightAltitude":${s.flightAltitude.toStringAsFixed(3)}'
      ',"flapsLevel":${s.flapsLevel}'
      ',"lvrOn":${s.lvrOn}'
      ',"verticalSpeed":${s.verticalSpeed.toStringAsFixed(3)}'
      ',"flightPathAngleDeg":${s.flightPathAngleDeg.toStringAsFixed(2)}'
      ',"aeroAoA":${s.aeroAoA.toStringAsFixed(2)}'
      ',"selectedTargetId":${s.selectedTargetId == null ? 'null' : '"${s.selectedTargetId}"'}'
      ',"abilityCooldowns":{$cd}}';
  var el = html.document.getElementById('_gs');
  if (el == null) {
    el = html.DivElement()
      ..id = '_gs'
      ..style.display = 'none';
    html.document.body?.append(el);
  }
  el.setAttribute('data-state', j);
}
