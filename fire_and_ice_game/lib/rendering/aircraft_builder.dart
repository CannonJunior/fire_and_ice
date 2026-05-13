import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'mesh.dart';
import 'scene_node.dart';
import '../game/aircraft_config.dart';

/// Record returned by [AircraftBuilder.build].
///
/// [root] is the scene graph root — set its [SceneNode.position] and
/// [SceneNode.rotation] from game state each frame, then call
/// [SceneNode.updateWorldMatrix].
///
/// [parts] is a name-keyed map of the moving nodes so the game loop can
/// directly update their [SceneNode.rotation] for control-surface animation.
typedef AircraftScene = ({SceneNode root, Map<String, SceneNode> parts});

/// AircraftBuilder — constructs a multi-part scene graph for a given aircraft.
///
/// Each aircraft type produces a root SceneNode whose children represent the
/// fuselage and every animated part.  Parts are authored so that their LOCAL
/// ORIGIN sits exactly on their hinge line; rotating around that origin
/// correctly deflects the surface around its real-world hinge.
///
/// Animated parts (update [SceneNode.rotation] each frame):
///   'aileron_l'  — left aileron,  rotates X  (roll input, inverted on left)
///   'aileron_r'  — right aileron, rotates X  (roll input)
///   'elevator'   — elevator,      rotates X  (pitch input)
///   'rudder'     — rudder,        rotates Z  (yaw rate; rotated 90° so span=Y)
///   'flap_l'     — left flap,     rotates X  (extends in landing mode)
///   'flap_r'     — right flap,    rotates X
///   'gear_nose'  — nose strut,    position.y (gearProgress)
///   'gear_left'  — left strut,    position.y
///   'gear_right' — right strut,   position.y
///   'prop'       — propeller,     rotates Z  (continuous at throttle RPM)
///   'bay_l'      — left bay door, rotates Z  (suppression armed)
///   'bay_r'      — right bay door,rotates Z

class AircraftBuilder {
  AircraftBuilder._();

  /// Build and return the full scene graph for the given [config].
  static AircraftScene build(AircraftConfig config) {
    return switch (config.id) {
      'icefighter' => _buildIceFighter(),
      'skytanker'  => _buildSkyTanker(),
      'seabird'    => _buildSeaBird(),
      'stormrider' => _buildStormRider(),
      _            => _buildFireHawk(),  // 'firefighter' and fallback
    };
  }

  // ── IceFighter — ice-elemental interceptor ─────────────────────────────────

  static AircraftScene _buildIceFighter() {
    const len  = 4.0;
    final hl   = len / 2;
    final bw   = len * 0.14;       // slim interceptor fuselage
    final bh   = len * 0.11;
    final ws   = len * 0.85;       // long agile wings
    final pri  = Vector3(0.20, 0.50, 0.90);
    final sec  = Vector3(0.12, 0.28, 0.55);
    final ctrl = Vector3(0.30, 0.60, 1.00);
    final gC   = Vector3(0.12, 0.12, 0.14);

    final root = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};

    root.addChild(SceneNode(id: 'body', mesh: Mesh.aircraft(length: len,
        primaryColor: pri, secondaryColor: sec)));

    void add(String id, SceneNode n) { root.addChild(n); parts[id] = n; }

    // Larger ailerons — interceptor agility
    add('aileron_l', SceneNode(id: 'aileron_l',
        position: Vector3(-ws * 0.42, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.62, chord: 0.44, thickness: 0.04, color: ctrl)));
    add('aileron_r', SceneNode(id: 'aileron_r',
        position: Vector3( ws * 0.42, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.62, chord: 0.44, thickness: 0.04, color: ctrl)));
    add('elevator', SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, hl * 0.70),
        mesh: Mesh.flatPanel(halfSpan: 0.60, chord: 0.40, thickness: 0.04, color: ctrl)));
    add('rudder', SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, hl * 0.68),
        rotation: Vector3(-math.pi / 2, 0, 0),
        mesh: Mesh.flatPanel(halfSpan: 0.44, chord: 0.36, thickness: 0.04, color: ctrl)));
    // Smaller flaps — interceptor, not a hauler
    add('flap_l', SceneNode(id: 'flap_l',
        position: Vector3(-bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.26, thickness: 0.04, color: ctrl)));
    add('flap_r', SceneNode(id: 'flap_r',
        position: Vector3( bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.26, thickness: 0.04, color: ctrl)));
    add('gear_nose',  SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.5, -hl * 0.40),
        mesh: Mesh.strut(length: 0.68, radius: 0.06, color: gC)));
    add('gear_left',  SceneNode(id: 'gear_left',
        position: Vector3(-bw * 0.60, -bh * 0.5, hl * 0.10),
        mesh: Mesh.strut(length: 0.72, radius: 0.07, color: gC)));
    add('gear_right', SceneNode(id: 'gear_right',
        position: Vector3( bw * 0.60, -bh * 0.5, hl * 0.10),
        mesh: Mesh.strut(length: 0.72, radius: 0.07, color: gC)));
    // Compact bay — less retardant capacity
    final bC = Vector3(0.25, 0.50, 0.90);
    add('bay_l', SceneNode(id: 'bay_l',
        position: Vector3(-bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.13, chord: 0.26, thickness: 0.03, color: bC)));
    add('bay_r', SceneNode(id: 'bay_r',
        position: Vector3( bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.13, chord: 0.26, thickness: 0.03, color: bC)));
    add('prop', SceneNode(id: 'prop',
        position: Vector3(0, -bh * 0.10, hl * 0.90),
        mesh: Mesh.flatPanel(halfSpan: bw * 0.50, chord: 0.06, thickness: 0.02,
            color: Vector3(0.6, 0.8, 1.0))));
    return (root: root, parts: parts);
  }

  // ── FireHawk — balanced fighter-bomber ─────────────────────────────────────

  static AircraftScene _buildFireHawk() {
    const len  = 4.0;
    final hl   = len / 2;          // half-length  = 2.0
    final bw   = len * 0.17;       // wide belly houses retardant tank
    final bh   = len * 0.13;       // deep fuselage
    final ws   = len * 0.78;       // shorter span — heavier airframe
    final pri  = Vector3(0.82, 0.10, 0.06);  // firetruck red
    final sec  = Vector3(0.52, 0.05, 0.03);  // darker red wings
    final ctrl = Vector3(1.00, 0.42, 0.08);  // orange-red control surfaces

    final root = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};

    // Static fuselage + wings (existing Mesh.aircraft geometry)
    root.addChild(SceneNode(id: 'body', mesh: Mesh.aircraft(length: len,
        primaryColor: pri, secondaryColor: sec)));

    // ── Ailerons ─────────────────────────────────────────────────────────────
    // Left aileron hinge: at 55% of half-span, 55% of hl along Z (trailing area)
    // halfSpan = 0.55, chord = 0.38 (extends to wing trailing edge)
    final ailL = SceneNode(id: 'aileron_l',
        position: Vector3(-ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.55, chord: 0.38, thickness: 0.04, color: ctrl));
    final ailR = SceneNode(id: 'aileron_r',
        position: Vector3(ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.55, chord: 0.38, thickness: 0.04, color: ctrl));
    root.addChild(ailL);
    root.addChild(ailR);
    parts['aileron_l'] = ailL;
    parts['aileron_r'] = ailR;

    // ── Elevator ─────────────────────────────────────────────────────────────
    // Horizontal stabilizer leading edge at ~70% of hl
    final elev = SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, hl * 0.70),
        mesh: Mesh.flatPanel(halfSpan: 0.65, chord: 0.42, thickness: 0.04, color: ctrl));
    root.addChild(elev);
    parts['elevator'] = elev;

    // ── Rudder ───────────────────────────────────────────────────────────────
    // Vertical surface: span is height (Y), so rotate flatPanel 90° around X.
    // After rotation: Z=chord direction stays the same, Y=span becomes the height axis.
    final rud = SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, hl * 0.68),
        rotation: Vector3(-math.pi / 2, 0, 0), // rotate so span is Y
        mesh: Mesh.flatPanel(halfSpan: 0.38, chord: 0.32, thickness: 0.04, color: ctrl));
    root.addChild(rud);
    parts['rudder'] = rud;

    // ── Flaps (inboard of ailerons) ──────────────────────────────────────────
    final flapL = SceneNode(id: 'flap_l',
        position: Vector3(-bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.30, chord: 0.32, thickness: 0.04, color: ctrl));
    final flapR = SceneNode(id: 'flap_r',
        position: Vector3(bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.30, chord: 0.32, thickness: 0.04, color: ctrl));
    root.addChild(flapL);
    root.addChild(flapR);
    parts['flap_l'] = flapL;
    parts['flap_r'] = flapR;

    // ── Landing gear ─────────────────────────────────────────────────────────
    final gearColor = Vector3(0.12, 0.12, 0.14);
    final gearN = SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.50, -hl * 0.40),
        mesh: Mesh.strut(length: 0.75, radius: 0.06, color: gearColor));
    final gearL = SceneNode(id: 'gear_left',
        position: Vector3(-bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.07, color: gearColor));
    final gearR = SceneNode(id: 'gear_right',
        position: Vector3(bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.07, color: gearColor));
    root.addChild(gearN);
    root.addChild(gearL);
    root.addChild(gearR);
    parts['gear_nose']  = gearN;
    parts['gear_left']  = gearL;
    parts['gear_right'] = gearR;

    // ── Suppression bay doors (larger on FireHawk — bigger retardant bay) ──────
    final bayColor = Vector3(0.65, 0.08, 0.04);  // dark red bay doors
    final bayL = SceneNode(id: 'bay_l',
        position: Vector3(-bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.24, chord: 0.40, thickness: 0.03, color: bayColor));
    final bayR = SceneNode(id: 'bay_r',
        position: Vector3(bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.24, chord: 0.40, thickness: 0.03, color: bayColor));
    root.addChild(bayL);
    root.addChild(bayR);
    parts['bay_l'] = bayL;
    parts['bay_r'] = bayR;

    // ── Exhaust bloom (orange-red for fire-themed engine) ─────────────────────
    final prop = SceneNode(id: 'prop',
        position: Vector3(0, -bh * 0.10, hl * 0.90),
        mesh: Mesh.flatPanel(halfSpan: bw * 0.55, chord: 0.06, thickness: 0.02,
            color: Vector3(1.0, 0.35, 0.05)));
    root.addChild(prop);
    parts['prop'] = prop;

    return (root: root, parts: parts);
  }

  // ── SkyTanker — heavy retardant bomber ─────────────────────────────────────

  static AircraftScene _buildSkyTanker() {
    const len = 5.5;
    final hl  = len / 2;
    final bw  = len * 0.18;
    final bh  = len * 0.14;

    // Reuse FireHawk geometry but with different scale/colors
    final root = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};

    root.addChild(SceneNode(id: 'body', mesh: Mesh.aircraft(length: len,
        primaryColor:   Vector3(0.70, 0.50, 0.20),  // tan/sand heavy bomber
        secondaryColor: Vector3(0.45, 0.30, 0.12))));

    _addSharedSurfaces(root, parts, hl, bw, bh, len,
        ctrl: Vector3(0.85, 0.65, 0.25));
    return (root: root, parts: parts);
  }

  // ── SeaBird — amphibious scooper ────────────────────────────────────────────

  static AircraftScene _buildSeaBird() {
    const len = 4.5;
    final hl  = len / 2;
    final bw  = len * 0.14;
    final bh  = len * 0.11;

    final root = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};

    root.addChild(SceneNode(id: 'body', mesh: Mesh.aircraft(length: len,
        primaryColor:   Vector3(0.15, 0.60, 0.55),  // teal amphibious
        secondaryColor: Vector3(0.08, 0.40, 0.38))));

    _addSharedSurfaces(root, parts, hl, bw, bh, len,
        ctrl: Vector3(0.20, 0.80, 0.75));
    return (root: root, parts: parts);
  }

  // ── StormRider — elemental specialist ──────────────────────────────────────

  static AircraftScene _buildStormRider() {
    const len = 3.8;
    final hl  = len / 2;
    final bw  = len * 0.12;
    final bh  = len * 0.10;

    final root = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};

    root.addChild(SceneNode(id: 'body', mesh: Mesh.aircraft(length: len,
        primaryColor:   Vector3(0.45, 0.10, 0.80),  // elemental violet
        secondaryColor: Vector3(0.25, 0.05, 0.50))));

    _addSharedSurfaces(root, parts, hl, bw, bh, len,
        ctrl: Vector3(0.70, 0.30, 1.00));
    return (root: root, parts: parts);
  }

  // ── Shared surface builder (reused by non-FireHawk types) ──────────────────

  static void _addSharedSurfaces(
    SceneNode root,
    Map<String, SceneNode> parts,
    double hl, double bw, double bh, double len, {
    required Vector3 ctrl,
  }) {
    final ws = len * 0.80;
    final gC = Vector3(0.12, 0.12, 0.14);

    void add(String id, SceneNode n) { root.addChild(n); parts[id] = n; }

    add('aileron_l', SceneNode(id: 'aileron_l',
        position: Vector3(-ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.50, chord: 0.36, thickness: 0.04, color: ctrl)));
    add('aileron_r', SceneNode(id: 'aileron_r',
        position: Vector3(ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.50, chord: 0.36, thickness: 0.04, color: ctrl)));
    add('elevator', SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, hl * 0.70),
        mesh: Mesh.flatPanel(halfSpan: 0.60, chord: 0.38, thickness: 0.04, color: ctrl)));
    add('rudder', SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, hl * 0.68),
        rotation: Vector3(-math.pi / 2, 0, 0),
        mesh: Mesh.flatPanel(halfSpan: 0.35, chord: 0.28, thickness: 0.04, color: ctrl)));
    add('flap_l', SceneNode(id: 'flap_l',
        position: Vector3(-bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.28, chord: 0.30, thickness: 0.04, color: ctrl)));
    add('flap_r', SceneNode(id: 'flap_r',
        position: Vector3(bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.28, chord: 0.30, thickness: 0.04, color: ctrl)));
    add('gear_nose',  SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.5, -hl * 0.40),
        mesh: Mesh.strut(length: 0.75, radius: 0.07, color: gC)));
    add('gear_left',  SceneNode(id: 'gear_left',
        position: Vector3(-bw * 0.60, -bh * 0.5, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.08, color: gC)));
    add('gear_right', SceneNode(id: 'gear_right',
        position: Vector3(bw * 0.60, -bh * 0.5, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.08, color: gC)));
    final bC = Vector3(ctrl.x * 0.6, ctrl.y * 0.6, ctrl.z * 0.6);
    add('bay_l', SceneNode(id: 'bay_l',
        position: Vector3(-bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.38, thickness: 0.03, color: bC)));
    add('bay_r', SceneNode(id: 'bay_r',
        position: Vector3(bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.38, thickness: 0.03, color: bC)));
    add('prop', SceneNode(id: 'prop',
        position: Vector3(0, -bh * 0.10, hl * 0.90),
        mesh: Mesh.flatPanel(halfSpan: bw * 0.55, chord: 0.06, thickness: 0.02,
            color: Vector3(0.8, 0.4, 0.1))));
  }
}
