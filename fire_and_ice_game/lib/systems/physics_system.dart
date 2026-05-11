import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../game/game_state.dart';

/// PhysicsSystem - Full Windwalker flight physics for Fire & Ice.
///
/// The character is always in flight; there is no ground movement mode.
/// All tunable constants come from [GameState]'s loaded JSON config.
///
/// Control scheme:
///  W  = pitch down (dive)      S  = pitch up (climb)
///  A  = yaw left + bank-turn   D  = yaw right + bank-turn
///  Q  = bank left only         E  = bank right only
///  Q+A = barrel roll left      E+D = barrel roll right
///  Alt = 1.5× speed boost      Space = air brake + upward bump
///
/// Called once per frame from the game loop with the current input flags.
class PhysicsSystem {
  PhysicsSystem._(); // Static-only class

  // ── Public API ────────────────────────────────────────────────────────────

  /// Update all flight state in [state] for one frame of [dt] seconds.
  ///
  /// Parameters mirror the active input flags each frame:
  ///  [forward]    = W held       [backward]   = S held
  ///  [strafeLeft] = Q held       [strafeRight] = E held
  ///  [bankLeft]   = A held       [bankRight]   = D held
  ///  [sprint]     = Alt held     [brake]       = Space held
  static void updateFlight(
    GameState state,
    bool forward,
    bool backward,
    bool strafeLeft,
    bool strafeRight,
    bool bankLeft,
    bool bankRight,
    bool sprint,
    bool brake,
    double dt,
  ) {
    _updatePitch(state, forward, backward, dt);
    _updateSpeed(state, sprint, brake, dt);
    _updateBanking(state, strafeLeft, strafeRight, bankLeft, bankRight, dt);
    _updateYaw(state, strafeLeft, strafeRight, bankLeft, bankRight, dt);
    _updatePosition(state, dt);
    _updateMana(state, dt);
    _clampAltitude(state);
  }

  // ── Pitch ────────────────────────────────────────────────────────────────

  static void _updatePitch(
    GameState state,
    bool forward,   // W = dive (pitch down)
    bool backward,  // S = climb (pitch up)
    double dt,
  ) {
    final rate = state.cfgPitchRate;

    if (backward) {
      state.flightPitchAngle += rate * dt;
    } else if (forward) {
      state.flightPitchAngle -= rate * dt;
    }
    // No pitch clamp — full 360° pitch allows loops.
    // No auto-level — pitch is stable when input stops (like a trimmed aircraft).
    // Reason: clamping to ±maxPitch prevents the continuous pitch increase
    // required to complete a loop. Auto-level would fight the player mid-loop.

    // Normalise to (-180, 180] so the HUD readout stays human-readable
    // without changing the actual aircraft attitude.
    state.flightPitchAngle = ((state.flightPitchAngle + 180) % 360) - 180;

    // Mirror into visual rotation
    state.playerRotation.x = state.flightPitchAngle;
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  static void _updateSpeed(
    GameState state,
    bool sprint,
    bool brake,
    double dt,
  ) {
    double speed = state.cfgFlightSpeed;

    if (sprint) {
      speed *= state.cfgBoostMultiplier; // Alt = 1.5× speed
    }

    if (brake) {
      // Space = air brake: slow down + upward bump
      speed *= state.cfgBrakeMultiplier;
      state.playerPosition.y += state.cfgBrakeJumpForce * dt;
    }

    // Low mana forces a gentle descent
    if (state.mana < state.cfgLowManaThreshold) {
      state.playerPosition.y -= state.cfgLowManaDescentRate * dt;
    }

    state.flightSpeed = speed;
  }

  // ── Banking ──────────────────────────────────────────────────────────────

  static void _updateBanking(
    GameState state,
    bool qHeld, // bank left
    bool eHeld, // bank right
    bool aHeld, // yaw left
    bool dHeld, // yaw right
    double dt,
  ) {
    final bankRate    = state.cfgBankRate;
    final maxBank     = state.cfgMaxBankAngle;
    final autoLevel   = state.cfgAutoLevelRate;
    final threshold   = state.cfgAutoLevelThreshold;
    final barrelRate  = state.cfgBarrelRollRate;

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
      // Q alone: bank left without yaw
      state.flightBankAngle =
          (state.flightBankAngle - bankRate * dt).clamp(-maxBank, maxBank);
    } else if (eHeld) {
      // E alone: bank right without yaw
      state.flightBankAngle =
          (state.flightBankAngle + bankRate * dt).clamp(-maxBank, maxBank);
    } else {
      // Auto-level when bank angle is within threshold
      if (state.flightBankAngle.abs() < threshold) {
        if (state.flightBankAngle > 0) {
          state.flightBankAngle =
              (state.flightBankAngle - autoLevel * dt).clamp(0.0, double.infinity);
        } else if (state.flightBankAngle < 0) {
          state.flightBankAngle =
              (state.flightBankAngle + autoLevel * dt)
                  .clamp(double.negativeInfinity, 0.0);
        }
      }
    }

    // Apply bank to visual rotation (negative so right-bank tilts right)
    state.playerRotation.z = -state.flightBankAngle;
  }

  // ── Yaw ──────────────────────────────────────────────────────────────────

  static void _updateYaw(
    GameState state,
    bool qHeld,
    bool eHeld,
    bool aHeld,
    bool dHeld,
    double dt,
  ) {
    final bankToTurn = state.cfgBankToTurnMult;

    final barrelLeft  = qHeld && aHeld;
    final barrelRight = eHeld && dHeld;

    // Suppress yaw input during barrel rolls (keys are used for the combo)
    if (barrelLeft || barrelRight) return;

    // Bank-induced yaw: banking produces a coordinated turn
    // Reason: sinusoidal coupling matches real aircraft aerodynamics
    if (state.flightBankAngle.abs() > 1.0) {
      final bankRad    = state.flightBankAngle * (math.pi / 180.0);
      final bankTurnRate = math.sin(bankRad) * bankToTurn * 60.0;
      state.playerRotation.y -= bankTurnRate * dt;
    }

    // A/D direct yaw with bank-enhanced rate
    final bankRad    = (state.flightBankAngle.abs().clamp(0.0, 90.0)) * (math.pi / 180.0);
    final turnMult   = 1.0 + math.sin(bankRad) * bankToTurn;
    final turnRate   = 180.0 * turnMult;

    if (aHeld) {
      state.playerRotation.y += turnRate * dt; // Yaw left
    }
    if (dHeld) {
      state.playerRotation.y -= turnRate * dt; // Yaw right
    }
  }

  // ── Position update ──────────────────────────────────────────────────────

  /// Move the aircraft along its full 3D heading vector.
  ///
  /// Uses the combined pitch + yaw forward vector so that at any pitch angle
  /// (including beyond ±90° during a loop) the aircraft moves in the correct
  /// direction.  This is mathematically equivalent to the old hSpeed/vSpeed
  /// split for small angles but remains correct through a complete 360° loop.
  static void _updatePosition(GameState state, double dt) {
    final yawRad   = state.playerRotation.y * (math.pi / 180.0);
    final pitchRad = state.flightPitchAngle * (math.pi / 180.0);
    final speed    = state.flightSpeed;

    // Full 3D forward vector: -Z (forward) rotated by yaw then pitch.
    final forward = Vector3(
      -math.sin(yawRad) * math.cos(pitchRad),
       math.sin(pitchRad),
      -math.cos(yawRad) * math.cos(pitchRad),
    );

    state.playerPosition += forward * speed * dt;
    state.flightAltitude  = state.playerPosition.y;
  }

  // ── Mana ─────────────────────────────────────────────────────────────────

  static void _updateMana(GameState state, double dt) {
    // Drain mana continuously while flying
    state.spendMana(state.cfgManaDrainRate * dt);

    // Regen mana at 5/sec (net drain = 3-5 = -2 when flying, net = +5 idle)
    // Reason: the spec says drain 3/sec but regen 5/sec when not using abilities.
    // Since flight always drains 3/sec, we always also regen 5/sec giving
    // a net gain of +2/sec in normal flight (abilities add additional drain).
    // This prevents mana starvation while still making abilities costly.
    state.restoreMana(5.0 * dt);
  }

  // ── Altitude / bounds ────────────────────────────────────────────────────

  /// Keep the aircraft above y=0.5 (terrain surface proxy).
  ///
  /// Reason: a full terrain-height query each frame would be expensive and
  /// the terrain is visual-only; a flat floor at y=0.5 is sufficient.
  /// Keep the aircraft above y = 0.5 (terrain proxy).
  ///
  /// Pitch is intentionally NOT reset here so a loop started near the ground
  /// can still complete: the aircraft bounces off the floor and continues.
  static void _clampAltitude(GameState state) {
    if (state.playerPosition.y < 0.5) {
      state.playerPosition.y = 0.5;
    }
    state.flightAltitude = state.playerPosition.y;
  }
}
