import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../game/game_state.dart';
import '../terrain/terrain_generator.dart';

/// PhysicsSystem - Windwalker flight + ground physics for Fire & Ice.
///
/// Dispatches to ground or flight physics based on [GameState.gameMode].
///
/// Controls (flight):
///  W/S = pitch down/up   A/D = yaw + bank-turn   Q/E = bank only
///  Q+A / E+D = barrel roll   Alt = boost   Space = air brake
///
/// Controls (taxi):
///  ] / [ = throttle up/down   A/D = steer   Space = brake
class PhysicsSystem {
  PhysicsSystem._();

  // ── Public entry point ────────────────────────────────────────────────────

  static void updateFlight(
    GameState state,
    bool forward, bool backward,
    bool strafeLeft, bool strafeRight,
    bool bankLeft, bool bankRight,
    bool sprint, bool brake,
    double dt,
  ) {
    if (state.gameMode == GameMode.taxi) {
      _updateGround(state, bankLeft, bankRight, brake, dt);
    } else {
      _updatePitch(state, forward, backward, dt);
      _updateSpeed(state, sprint, brake, dt);
      _updateBanking(state, strafeLeft, strafeRight, bankLeft, bankRight, dt);
      _updateYaw(state, strafeLeft, strafeRight, bankLeft, bankRight, dt);
      _updatePosition(state, dt);
      _updateMana(state, dt);
      _updateTerrainAndAltitude(state, dt);
      _updateFireProximity(state, dt);
    }
    _updateEngines(state, dt);
  }

  // ── Engine instrument simulation ──────────────────────────────────────────

  /// Animate N1/N2/EGT with first-order lag matching real turbofan spool times.
  ///
  /// N1 (fan) and N2 (core) settle to idle (~20–25%) when throttle = 0.
  /// EGT rises more slowly and stays elevated briefly after throttle reduction.
  static void _updateEngines(GameState s, double dt) {
    final idle = s.throttle > 0 ? 0.20 : 0.0;
    final n1t  = idle + s.throttle * 0.80;   // 20–100 % fan RPM
    final n2t  = idle + s.throttle * 0.75;   // 20–95 % core RPM
    final egtt = idle + s.throttle * 0.80;   // proportional EGT
    s.engineN1  += (n1t  - s.engineN1)  * math.min(dt / 2.5, 1.0);
    s.engineN2  += (n2t  - s.engineN2)  * math.min(dt / 2.0, 1.0);
    s.engineEgt += (egtt - s.engineEgt) * math.min(dt / 4.0, 1.0);
  }

  // ── Ground / taxi physics ─────────────────────────────────────────────────

  static void _updateGround(
    GameState state,
    bool aHeld, bool dHeld, bool brake, double dt,
  ) {
    final targetSpeed = state.cfgMaxGroundSpeed * state.throttle;

    if (brake) {
      state.groundSpeed =
          (state.groundSpeed - state.cfgGroundBrake * dt).clamp(0.0, double.infinity);
    } else if (state.groundSpeed < targetSpeed) {
      state.groundSpeed =
          (state.groundSpeed + state.cfgGroundAccel * dt).clamp(0.0, targetSpeed);
    } else if (state.groundSpeed > targetSpeed) {
      state.groundSpeed =
          (state.groundSpeed - state.cfgGroundAccel * dt).clamp(targetSpeed, double.infinity);
    }

    // Steering rate scales with speed so slow taxi is nimble, fast is stable
    final speedFrac  = (state.groundSpeed / state.cfgMaxGroundSpeed).clamp(0.0, 1.0);
    final turnRate   = state.cfgGroundTurnRate * (0.4 + 0.6 * speedFrac);
    if (aHeld) state.playerRotation.y += turnRate * dt;
    if (dHeld) state.playerRotation.y -= turnRate * dt;

    // Move along ground heading (no pitch/bank on ground)
    final yawRad = state.playerRotation.y * math.pi / 180.0;
    state.playerPosition.x -= math.sin(yawRad) * state.groundSpeed * dt;
    state.playerPosition.z -= math.cos(yawRad) * state.groundSpeed * dt;

    // Pin to terrain surface so the aircraft follows hills after a crash-land.
    final gndH = TerrainGenerator.heightAt(
        state.playerPosition.x, state.playerPosition.z);
    state.terrainHeight    = gndH;
    state.playerPosition.y = math.max(gndH, 0.5);
    state.flightAltitude   = state.playerPosition.y;
    state.flightSpeed      = state.groundSpeed;
    state.flightPitchAngle = 0.0;
    state.flightBankAngle  = 0.0;
    state.playerRotation.x = 0.0;
    state.playerRotation.z = 0.0;

    // Mana regenerates on the ground (no drain while taxiing)
    state.restoreMana(5.0 * dt);
  }

  // ── Pitch ────────────────────────────────────────────────────────────────

  static void _updatePitch(
    GameState state, bool forward, bool backward, double dt,
  ) {
    if (backward) state.flightPitchAngle += state.cfgPitchRate * dt;
    else if (forward) state.flightPitchAngle -= state.cfgPitchRate * dt;
    state.flightPitchAngle = ((state.flightPitchAngle + 180) % 360) - 180;
    state.playerRotation.x  = state.flightPitchAngle;
  }

  // ── Speed (throttle-based in flight) ─────────────────────────────────────

  static void _updateSpeed(GameState state, bool sprint, bool brake, double dt) {
    // Throttle sets the target cruise speed
    final target = state.cfgFlightSpeed * state.throttle;
    final accel  = state.cfgFlightSpeedAccel;

    if (state.flightSpeed < target) {
      state.flightSpeed = math.min(state.flightSpeed + accel * dt, target);
    } else if (state.flightSpeed > target) {
      state.flightSpeed = math.max(state.flightSpeed - accel * dt, target);
    }

    if (sprint) state.flightSpeed *= state.cfgBoostMultiplier;

    if (brake) {
      state.flightSpeed *= state.cfgBrakeMultiplier;
      state.playerPosition.y += state.cfgBrakeJumpForce * dt;
    }

    if (state.mana < state.cfgLowManaThreshold) {
      state.playerPosition.y -= state.cfgLowManaDescentRate * dt;
    }
  }

  // ── Banking ──────────────────────────────────────────────────────────────

  static void _updateBanking(
    GameState state,
    bool qHeld, bool eHeld, bool aHeld, bool dHeld, double dt,
  ) {
    final bankRate   = state.cfgBankRate;
    final maxBank    = state.cfgMaxBankAngle;
    final autoLevel  = state.cfgAutoLevelRate;
    final threshold  = state.cfgAutoLevelThreshold;
    final barrelRate = state.cfgBarrelRollRate;

    final barrelLeft  = qHeld && aHeld;
    final barrelRight = eHeld && dHeld;
    state.isBarrelRolling = barrelLeft || barrelRight;

    if (barrelLeft) {
      state.flightBankAngle -= barrelRate * dt;
      if (state.flightBankAngle < -360) state.flightBankAngle += 360;
    } else if (barrelRight) {
      state.flightBankAngle += barrelRate * dt;
      if (state.flightBankAngle > 360) state.flightBankAngle -= 360;
    } else if (qHeld) {
      state.flightBankAngle = (state.flightBankAngle - bankRate * dt).clamp(-maxBank, maxBank);
    } else if (eHeld) {
      state.flightBankAngle = (state.flightBankAngle + bankRate * dt).clamp(-maxBank, maxBank);
    } else if (state.flightBankAngle.abs() < threshold) {
      if (state.flightBankAngle > 0) {
        state.flightBankAngle =
            (state.flightBankAngle - autoLevel * dt).clamp(0.0, double.infinity);
      } else if (state.flightBankAngle < 0) {
        state.flightBankAngle =
            (state.flightBankAngle + autoLevel * dt).clamp(double.negativeInfinity, 0.0);
      }
    }
    state.playerRotation.z = -state.flightBankAngle;
  }

  // ── Yaw ──────────────────────────────────────────────────────────────────

  static void _updateYaw(
    GameState state,
    bool qHeld, bool eHeld, bool aHeld, bool dHeld, double dt,
  ) {
    final bankToTurn  = state.cfgBankToTurnMult;
    final barrelLeft  = qHeld && aHeld;
    final barrelRight = eHeld && dHeld;
    if (barrelLeft || barrelRight) return;

    // Compute bank magnitude once; avoids two separate .abs() calls and
    // reduces the number of sin() evaluations from 2 to 1 for the common case.
    final bankAbs = state.flightBankAngle.abs();

    if (bankAbs > 1.0) {
      final bankSin = math.sin(state.flightBankAngle * (math.pi / 180.0));
      state.playerRotation.y -= bankSin * bankToTurn * 60.0 * dt;
    }

    final bankRad  = bankAbs.clamp(0.0, 90.0) * (math.pi / 180.0);
    final turnMult = 1.0 + math.sin(bankRad) * bankToTurn;
    final turnRate = 180.0 * turnMult;
    if (aHeld) state.playerRotation.y += turnRate * dt;
    if (dHeld) state.playerRotation.y -= turnRate * dt;
  }

  // ── Position update ──────────────────────────────────────────────────────

  // Pre-allocated scratch vector — avoids one Vector3 heap allocation per frame.
  static final Vector3 _fwd = Vector3.zero();

  static void _updatePosition(GameState state, double dt) {
    final yawRad   = state.playerRotation.y * (math.pi / 180.0);
    final pitchRad = state.flightPitchAngle  * (math.pi / 180.0);
    final cosP     = math.cos(pitchRad);

    _fwd.setValues(
      -math.sin(yawRad) * cosP,
       math.sin(pitchRad),
      -math.cos(yawRad) * cosP,
    );

    state.playerPosition.addScaled(_fwd, state.flightSpeed * dt);
    state.flightAltitude = state.playerPosition.y;
  }

  // ── Mana ─────────────────────────────────────────────────────────────────

  static void _updateMana(GameState state, double dt) {
    state.spendMana(state.cfgManaDrainRate * dt);
    state.restoreMana(5.0 * dt);
  }

  // ── Autopilot ─────────────────────────────────────────────────────────────

  /// Steer toward the active flight-plan waypoint when autopilot is engaged.
  static void updateAutopilot(GameState state, double dt) {
    if (!state.autopilotEnabled || state.flightPlan.isEmpty ||
        state.gameMode == GameMode.taxi) return;
    if (state.flightPlanIndex >= state.flightPlan.length) {
      state.autopilotEnabled = false; return;
    }
    final (_, targetX, targetZ) = state.flightPlan[state.flightPlanIndex];
    final dx   = targetX - state.playerPosition.x;
    final dz   = targetZ - state.playerPosition.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist < 20.0) {
      state.flightPlanIndex++;
      if (state.flightPlanIndex >= state.flightPlan.length) {
        state.autopilotEnabled = false;
      }
      return;
    }
    final targetYaw = math.atan2(-dx, -dz) * 180.0 / math.pi;
    var diff = (targetYaw - state.playerRotation.y) % 360;
    if (diff > 180) diff -= 360; else if (diff < -180) diff += 360;
    state.playerRotation.y += diff.clamp(-60.0 * dt, 60.0 * dt);
  }

  // ── Terrain, stall, and altitude ─────────────────────────────────────────

  /// Check terrain height, GPWS, stall, and terrain collision each frame.
  ///
  /// Design references:
  ///  - Tiny Combat Arena: terrain = crash, safe landing needs gear+speed+angle
  ///  - Crimson Skies: terrain hit = proportional damage, survivable at low speed
  ///  - Ace Combat 7: GPWS terrain-relative, stall nose-over at low speed
  static void _updateTerrainAndAltitude(GameState state, double dt) {
    final gndH = TerrainGenerator.heightAt(
        state.playerPosition.x, state.playerPosition.z);
    state.terrainHeight = gndH;

    // GPWS: warn when clearance below threshold
    final clearance = state.playerPosition.y - gndH;
    state.isGpwsActive = clearance < state.cfgGpwsAltitude;

    // Stall: nose-up at low speed → force nose over (Tiny Combat Arena / AC7 behaviour)
    final stalling = state.flightSpeed < state.cfgStallSpeed &&
        state.flightPitchAngle > state.cfgStallPitchAngle;
    state.isStalling = stalling;
    if (stalling) {
      state.flightPitchAngle =
          (state.flightPitchAngle - state.cfgPitchRate * 1.5 * dt)
              .clamp(-state.cfgMaxPitchAngle, 0.0);
      state.playerRotation.x = state.flightPitchAngle;
    }

    // ── Hard terrain floor ───────────────────────────────────────────────────
    // Aircraft cannot penetrate terrain regardless of approach speed or angle.
    // max(gndH, 0.5) preserves the runway floor so the existing landing →
    // taxi transition in game_widget fires normally at y ≤ touchFloor + 0.1.
    final floor = math.max(gndH, 0.5);
    if (state.playerPosition.y < floor) {
      state.playerPosition.y = floor;

      // Terrain impact: skip on runway surface (gndH ≈ 0) to allow smooth
      // touchdown; apply crash physics only on elevated terrain.
      if (gndH > 0.6 && state.flightSpeed > 0.5) {
        // Severity scales with speed and dive angle, clamped to avoid
        // insta-kill at the bottom of a steep descent.
        final severity = ((state.flightSpeed +
                state.flightPitchAngle.abs() * 0.05) /
            state.cfgFlightSpeed).clamp(0.1, 3.0);
        state.takeDamage(state.cfgCrashDamageRate * severity * dt);
        // Bleed speed aggressively — aircraft grinds to a stop on hillside.
        state.flightSpeed      = (state.flightSpeed * 0.35).clamp(0.0, double.infinity);
        state.flightPitchAngle = state.flightPitchAngle.clamp(-15.0, 5.0);
        state.playerRotation.x = state.flightPitchAngle;
      }
    }

    state.flightAltitude = state.playerPosition.y;
  }

  // Fire danger applies only when flying BETWEEN 10 m and 35 m above the
  // terrain surface inside an active fire zone — the low-altitude overflight
  // band.  Below 10 m clearance the aircraft is in GPWS/takeoff territory;
  // above 35 m it is safely above the smoke column.
  static void _updateFireProximity(GameState state, double dt) {
    final clearance = state.flightAltitude - state.terrainHeight;
    if (state.isFireBelow && clearance >= 10.0 && clearance < 35.0) {
      state.takeDamage(state.cfgFireDamageRate * dt);
      state.spendMana(state.cfgFireDamageRate * 0.3 * dt);
    }
  }
}
