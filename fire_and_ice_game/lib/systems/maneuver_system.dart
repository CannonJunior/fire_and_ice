import '../game/game_state.dart';

// ── Virtual control input produced by the maneuver computer ──────────────────

/// Maps 1:1 to the boolean parameters of PhysicsSystem.updateFlight.
/// fwd/bk = pitch; bl/br = bank (Q/E); yl/yr = yaw (A/D).
/// bl+yl together triggers barrel-roll left; br+yr triggers barrel-roll right.
class ManeuverInput {
  final bool fwd, bk, bl, br, yl, yr, sprint, brake;
  const ManeuverInput({
    this.fwd = false, this.bk  = false,
    this.bl  = false, this.br  = false,
    this.yl  = false, this.yr  = false,
    this.sprint = false, this.brake = false,
  });

  static const none      = ManeuverInput();
  static const pullUp    = ManeuverInput(bk: true);
  static const pushDn    = ManeuverInput(fwd: true);
  static const bankL     = ManeuverInput(bl: true);
  static const bankR     = ManeuverInput(br: true);
  static const rollL     = ManeuverInput(bl: true, yl: true);
  static const rollR     = ManeuverInput(br: true, yr: true);
  static const pullL     = ManeuverInput(bk: true, bl: true, yl: true);
  static const pullR     = ManeuverInput(bk: true, br: true, yr: true);
  static const yawL      = ManeuverInput(yl: true);
  static const yawR      = ManeuverInput(yr: true);
  static const boost     = ManeuverInput(sprint: true);
  static const hover     = ManeuverInput(brake: true);
  static const spiralDnL = ManeuverInput(fwd: true, bl: true, yl: true);
}

// ── Phase ─────────────────────────────────────────────────────────────────────

/// One scripted phase: hold [inp] for [dur] seconds.
/// [dropWindow] = true signals the suppression computer to release payload.
class MPhase {
  final double        dur;
  final ManeuverInput inp;
  final bool          dropWindow;
  const MPhase(this.dur, this.inp, {this.dropWindow = false});
}

// ── Maneuver type + category ──────────────────────────────────────────────────

enum ManeuverCategory { aerobatic, firefighting }

enum ManeuverType {
  // ── Aerobatic (13) ───────────────────────────────────────────────────────
  loop, barrelRoll, immelmann, splitS, cubanEight, wingOver,
  hammerhead, snapRoll, chandelle, tacticalTurn, breakTurn, jink, cloverleaf,
  // ── Fire-fighting (10) ───────────────────────────────────────────────────
  diveBomb, lowPass, scoopingPass, retardantSpiral, phoenixRoll,
  cryoLance, vortexSmash, iceCurtain, firebreakRun, thermalLance,
}

class ManeuverDef {
  final ManeuverType     type;
  final ManeuverCategory category;
  final String           name;
  final String           desc;
  final List<MPhase>     phases;
  const ManeuverDef({
    required this.type, required this.category,
    required this.name, required this.desc, required this.phases,
  });
  double get totalDur => phases.fold(0.0, (s, p) => s + p.dur);
}

// ── Output ────────────────────────────────────────────────────────────────────

class ManeuverOutput {
  final ManeuverInput? input;
  final bool           dropWindowActive;
  final bool           dropTriggered; // true only on the rising edge of dropWindow
  const ManeuverOutput({this.input, this.dropWindowActive = false, this.dropTriggered = false});
  static const idle = ManeuverOutput();
}

// ── Catalogue ─────────────────────────────────────────────────────────────────

class ManeuverSystem {
  ManeuverSystem._();

  static bool _prevDropWin = false;

  static const catalog = <ManeuverDef>[
    // ── Aerobatic ────────────────────────────────────────────────────────────
    ManeuverDef(type: ManeuverType.loop, category: ManeuverCategory.aerobatic,
      name: 'LOOP', desc: 'Vertical 360° loop — continuous pull maintains G through the top',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(6.0, ManeuverInput.pullUp), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.barrelRoll, category: ManeuverCategory.aerobatic,
      name: 'BARREL ROLL', desc: '360° axial roll along the flight path with altitude preserved',
      phases: [MPhase(1.0, ManeuverInput.rollL), MPhase(0.2, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.immelmann, category: ManeuverCategory.aerobatic,
      name: 'IMMELMANN', desc: 'Half-loop up then half-roll — 180° reversal with altitude gain',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(3.0, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.bankL), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.splitS, category: ManeuverCategory.aerobatic,
      name: 'SPLIT-S', desc: 'Half-roll inverted then half-loop — 180° reversal descending',
      phases: [MPhase(1.5, ManeuverInput.bankL), MPhase(0.2, ManeuverInput.none), MPhase(3.0, ManeuverInput.pullUp), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.cubanEight, category: ManeuverCategory.aerobatic,
      name: 'CUBAN EIGHT', desc: '5/8 loop + half-roll × 2 — vertical figure-eight pattern',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(3.8, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.bankL), MPhase(3.8, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.bankL), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.wingOver, category: ManeuverCategory.aerobatic,
      name: 'WING-OVER', desc: 'Climbing banked arc — 180° heading reversal preserving energy',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(1.5, ManeuverInput.pullUp), MPhase(2.5, ManeuverInput.pullL), MPhase(0.8, ManeuverInput.pushDn), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.hammerhead, category: ManeuverCategory.aerobatic,
      name: 'HAMMERHEAD', desc: 'Vertical climb, pivot on wingtip, vertical dive — stall turn',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(1.5, ManeuverInput.pullUp), MPhase(0.7, ManeuverInput.none), MPhase(0.5, ManeuverInput.yawL), MPhase(1.8, ManeuverInput.pushDn), MPhase(1.0, ManeuverInput.pullUp), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.snapRoll, category: ManeuverCategory.aerobatic,
      name: 'SNAP ROLL', desc: 'Pro-spin rapid 360° rotation — autorotation on the longitudinal axis',
      phases: [MPhase(1.0, ManeuverInput.rollR), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.chandelle, category: ManeuverCategory.aerobatic,
      name: 'CHANDELLE', desc: '180° climbing turn — maximum performance altitude + direction change',
      phases: [MPhase(0.8, ManeuverInput.bankL), MPhase(4.0, ManeuverInput.pullL), MPhase(0.5, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.tacticalTurn, category: ManeuverCategory.aerobatic,
      name: 'TACTICAL TURN', desc: 'Sustained max-G level 180° turn — tightest possible radius',
      phases: [MPhase(3.0, ManeuverInput.pullL), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.breakTurn, category: ManeuverCategory.aerobatic,
      name: 'BREAK TURN', desc: 'Snap high-G defensive turn — immediate threat-break maneuver',
      phases: [MPhase(2.0, ManeuverInput.pullR), MPhase(0.3, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.jink, category: ManeuverCategory.aerobatic,
      name: 'JINK', desc: 'Rapid random bank reversals — breaks radar / visual tracking',
      phases: [MPhase(0.35, ManeuverInput.bankL), MPhase(0.35, ManeuverInput.bankR), MPhase(0.35, ManeuverInput.bankL), MPhase(0.35, ManeuverInput.bankR), MPhase(0.35, const ManeuverInput(bl: true, bk: true)), MPhase(0.35, const ManeuverInput(br: true, fwd: true)), MPhase(0.35, ManeuverInput.bankL), MPhase(0.35, ManeuverInput.bankR), MPhase(0.30, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.cloverleaf, category: ManeuverCategory.aerobatic,
      name: 'CLOVERLEAF', desc: 'Four climbing arcs at 90° intervals — four-leaf overhead pattern',
      phases: [MPhase(1.5, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.pullL), MPhase(0.8, ManeuverInput.pushDn), MPhase(1.5, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.pullL), MPhase(0.8, ManeuverInput.pushDn), MPhase(1.5, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.pullL), MPhase(0.8, ManeuverInput.pushDn), MPhase(1.5, ManeuverInput.pullUp), MPhase(1.5, ManeuverInput.pullL), MPhase(0.4, ManeuverInput.none)]),

    // ── Fire-fighting ─────────────────────────────────────────────────────────
    ManeuverDef(type: ManeuverType.diveBomb, category: ManeuverCategory.firefighting,
      name: 'DIVE BOMB', desc: 'Steep power dive — drop at the pull-out for maximum penetration depth',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(1.8, ManeuverInput.pushDn), MPhase(1.5, ManeuverInput.none, dropWindow: true), MPhase(2.5, ManeuverInput.pullUp), MPhase(0.5, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.lowPass, category: ManeuverCategory.firefighting,
      name: 'LOW PASS', desc: 'High-speed low-altitude run — retardant line across the fire perimeter',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(0.8, ManeuverInput.pushDn), MPhase(0.4, ManeuverInput.none), MPhase(2.5, ManeuverInput.none, dropWindow: true), MPhase(1.5, ManeuverInput.pullUp)]),
    ManeuverDef(type: ManeuverType.scoopingPass, category: ManeuverCategory.firefighting,
      name: 'SCOOPING PASS', desc: 'Slow ultra-low dwell — maximum coverage; fire heat WILL damage the aircraft',
      phases: [MPhase(0.5, ManeuverInput.pushDn), MPhase(0.5, ManeuverInput.hover), MPhase(3.5, ManeuverInput.hover, dropWindow: true), MPhase(0.5, ManeuverInput.boost), MPhase(0.8, ManeuverInput.pullUp)]),
    ManeuverDef(type: ManeuverType.retardantSpiral, category: ManeuverCategory.firefighting,
      name: 'RETARDANT SPIRAL', desc: 'Tight descending spiral — coats the full fire zone in a retardant corkscrew',
      phases: [MPhase(0.8, ManeuverInput.bankL), MPhase(5.0, ManeuverInput.spiralDnL, dropWindow: true), MPhase(1.5, ManeuverInput.pullUp), MPhase(0.5, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.phoenixRoll, category: ManeuverCategory.firefighting,
      name: 'PHOENIX ROLL', desc: 'Barrel-roll descent into smoke — centrifugal vortex fans retardant outward',
      phases: [MPhase(0.4, ManeuverInput.boost), MPhase(0.4, ManeuverInput.pushDn), MPhase(2.0, ManeuverInput.rollL, dropWindow: true), MPhase(2.2, ManeuverInput.pullUp), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.cryoLance, category: ManeuverCategory.firefighting,
      name: 'CRYO LANCE', desc: 'Precision dive + cryo-beam on target — flash-freezes the fire core',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(0.7, ManeuverInput.pullUp), MPhase(1.8, ManeuverInput.pushDn), MPhase(0.5, ManeuverInput.none, dropWindow: true), MPhase(2.3, ManeuverInput.pullUp), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.vortexSmash, category: ManeuverCategory.firefighting,
      name: 'VORTEX SMASH', desc: 'Vertical dive + violent pullout — aerodynamic shockwave smothers fire',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(1.8, ManeuverInput.pushDn), MPhase(0.4, ManeuverInput.pullUp, dropWindow: true), MPhase(2.5, ManeuverInput.pullUp), MPhase(0.5, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.iceCurtain, category: ManeuverCategory.firefighting,
      name: 'ICE CURTAIN', desc: 'Three inverted passes — electrostatically-charged ice crystals form a fire barrier',
      phases: [
        MPhase(0.5, ManeuverInput.rollL), MPhase(1.5, ManeuverInput.none, dropWindow: true), MPhase(0.5, ManeuverInput.rollL), MPhase(0.3, ManeuverInput.none),
        MPhase(0.5, ManeuverInput.rollL), MPhase(1.5, ManeuverInput.none, dropWindow: true), MPhase(0.5, ManeuverInput.rollL), MPhase(0.3, ManeuverInput.none),
        MPhase(0.5, ManeuverInput.rollL), MPhase(1.5, ManeuverInput.none, dropWindow: true), MPhase(0.5, ManeuverInput.rollL), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.firebreakRun, category: ManeuverCategory.firefighting,
      name: 'FIREBREAK RUN', desc: 'Two parallel retardant lines — suppression corridor starves the fire of fuel',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(2.5, ManeuverInput.none, dropWindow: true), MPhase(1.5, ManeuverInput.pullL), MPhase(2.5, ManeuverInput.none, dropWindow: true), MPhase(1.2, ManeuverInput.pullR), MPhase(0.4, ManeuverInput.none)]),
    ManeuverDef(type: ManeuverType.thermalLance, category: ManeuverCategory.firefighting,
      name: 'THERMAL LANCE', desc: 'Angled dive + counter-fire bolt — controlled back-burn consumes the fire\'s fuel',
      phases: [MPhase(0.3, ManeuverInput.boost), MPhase(0.5, ManeuverInput.bankR), MPhase(2.0, ManeuverInput.pullR), MPhase(0.8, ManeuverInput.pushDn), MPhase(0.5, ManeuverInput.none, dropWindow: true), MPhase(2.5, ManeuverInput.pullUp), MPhase(0.4, ManeuverInput.none)]),
  ];

  // ── Runtime tick ──────────────────────────────────────────────────────────

  /// Call every frame. Advances the active maneuver and returns override inputs.
  /// Returns [ManeuverOutput.idle] when no maneuver is running.
  static ManeuverOutput tick(GameState s, double dt) {
    final idx = s.activeManeuverIdx;
    if (idx == null || idx >= catalog.length) {
      _prevDropWin = false;
      return ManeuverOutput.idle;
    }
    s.maneuverTimer += dt;
    double elapsed = 0;
    for (final phase in catalog[idx].phases) {
      if (s.maneuverTimer < elapsed + phase.dur) {
        final drop      = phase.dropWindow;
        final triggered = drop && !_prevDropWin;
        _prevDropWin    = drop;
        return ManeuverOutput(input: phase.inp, dropWindowActive: drop, dropTriggered: triggered);
      }
      elapsed += phase.dur;
    }
    s.stopManeuver();
    _prevDropWin = false;
    return ManeuverOutput.idle;
  }
}
