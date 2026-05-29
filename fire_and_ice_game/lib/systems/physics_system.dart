import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../game/game_state.dart';
import '../terrain/terrain_generator.dart';

/// PhysicsSystem - Windwalker flight + ground physics for Fire & Ice.
///
/// Dispatches to ground or flight physics based on [GameState.gameMode].
///
/// Controls (flight):
///  W/S = pitch up/down   Q/E = bank only   A/D = rudder (yaw only, no bank)
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
      _updateAerodynamics(state, sprint, brake, dt);
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

  // ── Aerodynamics (replaces simple throttle-speed model) ──────────────────

  static void _updateAerodynamics(GameState s, bool sprint, bool brake, double dt) {
    final V = math.max(s.flightSpeed, 0.5);

    // True AoA: nose attitude minus actual flight-path angle
    final gammaRad = math.atan2(s.verticalSpeed, V);
    final gammaDeg = gammaRad * (180.0 / math.pi);
    s.flightPathAngleDeg = gammaDeg;
    s.aeroAoA = (s.flightPitchAngle - gammaDeg).clamp(-30.0, 30.0);

    final fl = s.flapsLevel.clamp(0, 3);
    double cl = s.cfgClZero + s.cfgClPerDeg * s.aeroAoA + s.cfgFlapsClDelta[fl];
    final clMax = 1.2 + s.cfgFlapsClDelta[fl];
    final isStalling = s.aeroAoA > s.cfgStallAoaDeg[fl];
    s.isStalling = isStalling;

    if (isStalling) {
      final depth = s.aeroAoA - s.cfgStallAoaDeg[fl];
      cl = math.max(0.0, clMax * (1.0 - depth / 20.0));
      // Stall: nose pitches over automatically
      s.flightPitchAngle -= s.cfgPitchRate * (1.5 + depth * 0.1) * dt;
      s.flightPitchAngle  = s.flightPitchAngle.clamp(-s.cfgMaxPitchAngle, s.cfgMaxPitchAngle);
      s.playerRotation.x  = s.flightPitchAngle;
    }

    final brakeCd = brake ? 0.20 : 0.0;
    final gearCd  = s.gearDeployed ? s.cfgGearCdDelta : 0.0;
    final cd = s.cfgCd0 + s.cfgKInduced * cl * cl + s.cfgFlapsCdDelta[fl] + gearCd + brakeCd;

    final qS     = s.cfgKLift * V * V;
    final boost  = sprint ? s.cfgBoostMultiplier : 1.0;
    final thrust = s.throttle * s.cfgMaxThrust * boost;
    final weight = s.cfgAeroMass * 9.8;
    final sinG   = math.sin(gammaRad);
    final cosG   = math.cos(gammaRad);

    // Along-path: thrust − drag − weight component
    s.flightSpeed = (s.flightSpeed +
            (thrust - qS * cd - weight * sinG) / s.cfgAeroMass * dt)
        .clamp(0.5, s.cfgFlightSpeed * 1.8);

    // Vertical: lift − weight perpendicular to path
    s.verticalSpeed += (qS * cl - weight * cosG) / s.cfgAeroMass * dt;

    // Arcade-assist: pitch attitude blends into vertical speed so the aircraft
    // still climbs/dives when the player points the nose (prevents the "slides
    // sideways" feel of pure physics at low speeds).
    final pitchImpliedVz =
        s.flightSpeed * math.sin(s.flightPitchAngle * math.pi / 180.0);
    s.verticalSpeed +=
        (pitchImpliedVz - s.verticalSpeed) * s.cfgPitchFollowRate * dt;
    s.verticalSpeed = s.verticalSpeed.clamp(-15.0, 15.0);

    // Low-mana: slow descent
    if (s.mana < s.cfgLowManaThreshold) {
      s.verticalSpeed -= s.cfgLowManaDescentRate * dt;
    }

    if (brake) s.playerPosition.y += s.cfgBrakeJumpForce * dt;
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
    final barrelLeft  = qHeld && aHeld;
    final barrelRight = eHeld && dHeld;
    if (barrelLeft || barrelRight) return;

    // Bank-induced yaw: rolling generates a coordinated turn automatically.
    final bankAbs = state.flightBankAngle.abs();
    if (bankAbs > 1.0) {
      final bankSin = math.sin(state.flightBankAngle * (math.pi / 180.0));
      state.playerRotation.y -= bankSin * state.cfgBankToTurnMult * 60.0 * dt;
    }

    // A/D = rudder: fixed yaw rate independent of bank angle.
    if (aHeld) state.playerRotation.y += state.cfgRudderYawRate * dt;
    if (dHeld) state.playerRotation.y -= state.cfgRudderYawRate * dt;
  }

  // ── Position update ──────────────────────────────────────────────────────

  static void _updatePosition(GameState state, double dt) {
    final yawRad = state.playerRotation.y * (math.pi / 180.0);
    // Horizontal speed is the non-vertical component of total airspeed.
    final vsSq   = state.verticalSpeed * state.verticalSpeed;
    final fsSq   = state.flightSpeed   * state.flightSpeed;
    final hSpeed = math.sqrt(math.max(0.0, fsSq - vsSq));

    state.playerPosition.x -= math.sin(yawRad) * hSpeed * dt;
    state.playerPosition.z -= math.cos(yawRad) * hSpeed * dt;
    state.playerPosition.y += state.verticalSpeed * dt;
    state.windState.applyDrift(state.playerPosition, dt);
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

    // ── Hard terrain floor ───────────────────────────────────────────────────
    // Aircraft cannot penetrate terrain regardless of approach speed or angle.
    // max(gndH, 0.5) preserves the runway floor so the existing landing →
    // taxi transition in game_widget fires normally at y ≤ touchFloor + 0.1.
    final floor = math.max(gndH, 0.5);
    if (state.playerPosition.y < floor) {
      state.playerPosition.y = floor;

      // Auto-recover pitch when hitting terrain — prevents sustained nose-down
      // crash state. Bleed negative pitch toward 0 at 2× normal pitch rate.
      if (state.flightPitchAngle < 0) {
        state.flightPitchAngle = math.min(
            state.flightPitchAngle + state.cfgPitchRate * 2.0 * dt, 0.0);
        state.playerRotation.x = state.flightPitchAngle;
      }

      // Terrain impact: skip on runway surface (gndH ≈ 0) to allow smooth
      // touchdown; apply crash physics only on elevated terrain.
      if (gndH > 0.6 && state.flightSpeed > 0.5) {
        final severity = ((state.flightSpeed +
                state.flightPitchAngle.abs() * 0.05) /
            state.cfgFlightSpeed).clamp(0.1, 3.0);
        state.takeDamage(state.cfgCrashDamageRate * severity * dt);
        state.flightSpeed      = (state.flightSpeed * 0.35).clamp(0.0, double.infinity);
        state.verticalSpeed    = math.max(0.0, state.verticalSpeed);
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
