import 'game_state.dart';
import 'mission_state.dart';

/// Injects automatic radio calls into chatHistory from the Squadron Duty Officer
/// and the tanker pilot (LEVIATHAN) based on real-time game conditions.
///
/// Call [reset] on game init and [tick] every frame.
class RadioSystem {
  RadioSystem._();

  static bool   _inited       = false;
  static double _startupTimer = 0.0;
  static bool   _startupDone  = false;
  static double _statusTimer  = 0.0;

  // Previous-state snapshots for edge detection
  static List<bool>     _prevFires        = [];
  static MissionStatus  _prevMsnStatus    = MissionStatus.available;
  static String?        _prevMsnId;
  static bool           _prevProbe        = false;
  static bool           _prevLowMana      = false;
  static bool           _prevCritMana     = false;
  static bool           _prevHighThreat   = false;
  static bool           _prevAllOut       = false;

  static const double _statusInterval = 300.0; // SDO periodic check every 5 min

  static void reset() {
    _inited       = false;
    _startupTimer = 0.0;
    _startupDone  = false;
    _statusTimer  = 0.0;
    _prevFires        = [];
    _prevMsnStatus    = MissionStatus.available;
    _prevMsnId        = null;
    _prevProbe        = false;
    _prevLowMana      = false;
    _prevCritMana     = false;
    _prevHighThreat   = false;
    _prevAllOut       = false;
  }

  static void tick(
    GameState state,
    bool tankerCrossed,
    bool tankerNorthbound,
    double dt,
    void Function(String msg) emit,
  ) {
    if (!_inited) {
      _inited = true;
      _prevFires     = List<bool>.from(state.fireExtinguished);
      _prevMsnStatus = state.missions.status;
      _prevMsnId     = state.missions.activeId;
      _prevProbe     = state.probeConnected;
      _prevLowMana   = state.mana < 40;
      _prevCritMana  = state.mana < 15;
      _prevHighThreat= state.airbaseThreatLevel > 0.6;
      _prevAllOut    = state.allFiresOut;
      return;
    }

    // ── Startup call ───────────────────────────────────────────────────────────
    if (!_startupDone) {
      _startupTimer += dt;
      if (_startupTimer >= 3.0) {
        _startupDone = true;
        emit('[SDO] HAWK 1, OPS NORMAL — area clear, you are cleared for operations, WILCO');
      }
    }

    // ── Tanker waypoint crossing ───────────────────────────────────────────────
    if (tankerCrossed) {
      if (tankerNorthbound) {
        emit('[TNKR] LEVIATHAN passing YANKEE northbound — basket deployed, ready for contact');
      } else {
        emit('[TNKR] LEVIATHAN passing YANKEE southbound — on orbit, contact available');
      }
    }

    // ── Fire zones suppressed ──────────────────────────────────────────────────
    for (int i = 0; i < state.fireExtinguished.length && i < _prevFires.length; i++) {
      if (state.fireExtinguished[i] && !_prevFires[i]) {
        emit('[SDO] HAWK 1, ZONE $i SUPPRESSED — AFFIRM, WILCO');
      }
    }
    _prevFires = List<bool>.from(state.fireExtinguished);

    if (state.allFiresOut && !_prevAllOut) {
      emit('[SDO] HAWK 1, ALL ZONES CLEAR — outstanding suppression, RTB when ready, WILCO');
    }
    _prevAllOut = state.allFiresOut;

    // ── Mission status ─────────────────────────────────────────────────────────
    final msnStatus = state.missions.status;
    final msnId     = state.missions.activeId;
    if (msnStatus == MissionStatus.active && _prevMsnStatus != MissionStatus.active) {
      final name = state.missions.active?.name ?? 'MISSION';
      emit('[SDO] HAWK 1, $name ACTIVE — WILCO, good hunting');
    } else if (msnStatus == MissionStatus.complete && _prevMsnStatus != MissionStatus.complete) {
      final name = state.missions.active?.name ?? 'MISSION';
      emit('[SDO] HAWK 1, $name COMPLETE — RTB when ready, WILCO');
    }
    _prevMsnStatus = msnStatus;
    _prevMsnId     = msnId;

    // ── Retardant (mana) levels ────────────────────────────────────────────────
    final lowMana  = state.mana < 40;
    final critMana = state.mana < 15;
    final manaOk   = state.mana > 75;

    if (critMana && !_prevCritMana) {
      emit('[SDO] HAWK 1, CRITICAL — retardant depleted, RTB for probe contact immediately, OVER');
    } else if (lowMana && !_prevLowMana) {
      emit('[SDO] HAWK 1, retardant running low — recommend probe contact, STANDBY');
    } else if (manaOk && !(_prevLowMana == false && _prevCritMana == false)) {
      // Recovered from low
      if (_prevLowMana || _prevCritMana) {
        emit('[SDO] HAWK 1, retardant nominal — cleared for area operations, WILCO');
      }
    }
    _prevLowMana  = lowMana;
    _prevCritMana = critMana;

    // ── Probe connection ───────────────────────────────────────────────────────
    if (state.probeConnected && !_prevProbe) {
      emit('[SDO] HAWK 1, probe contact confirmed — mana transfer nominal, WILCO');
    } else if (!state.probeConnected && _prevProbe) {
      emit('[SDO] HAWK 1, probe released — WILCO');
    }
    _prevProbe = state.probeConnected;

    // ── Base threat level ──────────────────────────────────────────────────────
    final highThreat = state.airbaseThreatLevel > 0.6;
    if (highThreat && !_prevHighThreat) {
      emit('[SDO] HAWK 1, BASE THREAT HIGH — defend the base, STANDBY');
    } else if (!highThreat && _prevHighThreat && state.airbaseThreatLevel < 0.2) {
      emit('[SDO] HAWK 1, BASE THREAT CLEARED — AFFIRM, WILCO');
    }
    _prevHighThreat = highThreat;

    // ── Periodic status ────────────────────────────────────────────────────────
    _statusTimer += dt;
    if (_statusTimer >= _statusInterval) {
      _statusTimer = 0.0;
      final fires    = state.activeFires;
      final threat   = state.airbaseThreatLevel > 0.6 ? 'HIGH'
                     : state.airbaseThreatLevel > 0.3 ? 'MEDIUM' : 'LOW';
      emit('[SDO] HAWK 1, STATUS — $fires zone${fires == 1 ? '' : 's'} active, base threat $threat, WILCO');
    }
  }
}
