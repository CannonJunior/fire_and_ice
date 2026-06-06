import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'mesh.dart';
import 'scene_node.dart';
import 'tanker_aircraft.dart';
import '../game/aircraft_config.dart';

typedef AircraftScene = ({SceneNode root, Map<String, SceneNode> parts});

/// Builds a multi-part scene graph for each player aircraft.
///
/// Animated part keys (driven by AircraftAnimator each frame):
///   aileron_l/r, elevator, rudder, flap_l/r — control surfaces
///   gear_nose/left/right — landing struts (position.y)
///   gear_door_n/l/r     — gear bay doors  (rotation.x)
///   bay_l/r             — suppression bay doors (rotation.z)
///   prop / prop_l/r / prop_1..4 — propeller(s) (rotation.z)
///   probe               — refueling probe (position.z, IceFighter)
///   drogue              — drogue basket   (position.z, SkyTanker)
class AircraftBuilder {
  AircraftBuilder._();

  static AircraftScene build(AircraftConfig config) {
    return switch (config.id) {
      'icefighter' => _buildIceFighter(),
      'skytanker'  => _buildSkyTanker(),
      _            => _buildFireHawk(),
    };
  }

  // ── IceFighter — sleek twin-engine ice interceptor ─────────────────────────

  static Mesh _buildIceFighterBody() {
    final v = <double>[], n = <double>[], c = <double>[], ix = <int>[];
    const fuse  = [0.10, 0.22, 0.48, 1.0];
    const wing  = [0.08, 0.18, 0.38, 1.0];
    const eng   = [0.15, 0.20, 0.32, 1.0];
    const glass = [0.28, 0.60, 0.95, 1.0];
    const fin   = [0.08, 0.16, 0.30, 1.0];

    void face(List<List<double>> pts, List<double> nm, List<double> col) {
      final b = v.length ~/ 3;
      for (final p in pts) { v.addAll(p); n.addAll(nm); c.addAll(col); }
      ix.addAll([b, b + 1, b + 2, b, b + 2, b + 3]);
    }
    void box(double cx, double cy, double cz,
             double sx, double sy, double sz, List<double> col) {
      final hx = sx/2, hy = sy/2, hz = sz/2;
      final x0=cx-hx, x1=cx+hx, y0=cy-hy, y1=cy+hy, z0=cz-hz, z1=cz+hz;
      face([[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]],[ 0, 1, 0],col);
      face([[x0,y0,z1],[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]],[ 0,-1, 0],col);
      face([[x1,y0,z0],[x1,y0,z1],[x1,y1,z1],[x1,y1,z0]],[ 1, 0, 0],col);
      face([[x0,y0,z1],[x0,y0,z0],[x0,y1,z0],[x0,y1,z1]],[-1, 0, 0],col);
      face([[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0]],[ 0, 0,-1],col);
      face([[x1,y0,z1],[x0,y0,z1],[x0,y1,z1],[x1,y1,z1]],[ 0, 0, 1],col);
    }
    // nose Z=-1.5, tail Z=+1.5 (len=3.0)
    box( 0,     0,      0,    0.30, 0.24, 3.00, fuse);
    box( 0,     0.18, -0.80,  0.26, 0.12, 0.70, glass);
    box( 0,    -0.02,  0.15,  2.10, 0.05, 0.90, wing);
    box(-0.42, -0.05,  0,     0.16, 0.13, 1.80, eng);
    box( 0.42, -0.05,  0,     0.16, 0.13, 1.80, eng);
    box( 0,     0.24,  1.10,  0.05, 0.42, 0.55, fin);
    box( 0,     0.08,  1.10,  0.80, 0.04, 0.28, wing);
    return Mesh(
      vertices: Float32List.fromList(v), indices: Uint16List.fromList(ix),
      normals:  Float32List.fromList(n), colors:  Float32List.fromList(c),
    );
  }

  static AircraftScene _buildIceFighter() {
    const bh = 0.24;
    final ctrl = Vector3(0.35, 0.65, 1.00);
    final gC   = Vector3(0.12, 0.12, 0.14);
    final bC   = Vector3(0.25, 0.50, 0.90);

    final root  = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};
    root.addChild(SceneNode(id: 'body', mesh: _buildIceFighterBody()));

    void add(String id, SceneNode n) { root.addChild(n); parts[id] = n; }

    add('aileron_l', SceneNode(id: 'aileron_l',
        position: Vector3(-0.80, 0, 0.60),
        mesh: Mesh.flatPanel(halfSpan: 0.42, chord: 0.36, thickness: 0.04, color: ctrl)));
    add('aileron_r', SceneNode(id: 'aileron_r',
        position: Vector3( 0.80, 0, 0.60),
        mesh: Mesh.flatPanel(halfSpan: 0.42, chord: 0.36, thickness: 0.04, color: ctrl)));
    add('elevator', SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, 1.20),
        mesh: Mesh.flatPanel(halfSpan: 0.44, chord: 0.30, thickness: 0.04, color: ctrl)));
    add('rudder', SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, 1.18),
        rotation: Vector3(-math.pi / 2, 0, 0),
        mesh: Mesh.flatPanel(halfSpan: 0.38, chord: 0.28, thickness: 0.04, color: ctrl)));
    add('flap_l', SceneNode(id: 'flap_l',
        position: Vector3(-0.38, 0, 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.20, chord: 0.24, thickness: 0.04, color: ctrl)));
    add('flap_r', SceneNode(id: 'flap_r',
        position: Vector3( 0.38, 0, 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.20, chord: 0.24, thickness: 0.04, color: ctrl)));
    add('gear_nose', SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.50, -0.60),
        mesh: Mesh.strut(length: 0.55, radius: 0.05, color: gC)));
    add('gear_left', SceneNode(id: 'gear_left',
        position: Vector3(-0.18, -bh * 0.50, 0.15),
        mesh: Mesh.strut(length: 0.60, radius: 0.06, color: gC)));
    add('gear_right', SceneNode(id: 'gear_right',
        position: Vector3( 0.18, -bh * 0.50, 0.15),
        mesh: Mesh.strut(length: 0.60, radius: 0.06, color: gC)));
    add('gear_door_n', SceneNode(id: 'gear_door_n',
        position: Vector3(0, -bh * 0.50, -0.60),
        mesh: Mesh.flatPanel(halfSpan: 0.12, chord: 0.20, thickness: 0.03, color: gC)));
    add('gear_door_l', SceneNode(id: 'gear_door_l',
        position: Vector3(-0.18, -bh * 0.50, 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.14, chord: 0.22, thickness: 0.03, color: gC)));
    add('gear_door_r', SceneNode(id: 'gear_door_r',
        position: Vector3( 0.18, -bh * 0.50, 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.14, chord: 0.22, thickness: 0.03, color: gC)));
    add('bay_l', SceneNode(id: 'bay_l',
        position: Vector3(-0.14, -bh * 0.50, 0.20),
        mesh: Mesh.flatPanel(halfSpan: 0.10, chord: 0.22, thickness: 0.03, color: bC)));
    add('bay_r', SceneNode(id: 'bay_r',
        position: Vector3( 0.14, -bh * 0.50, 0.20),
        mesh: Mesh.flatPanel(halfSpan: 0.10, chord: 0.22, thickness: 0.03, color: bC)));
    final pC = Vector3(0.55, 0.80, 1.00);
    add('prop_l', SceneNode(id: 'prop_l',
        position: Vector3(-0.42, -0.05, -0.95),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.06, thickness: 0.02, color: pC)));
    add('prop_r', SceneNode(id: 'prop_r',
        position: Vector3( 0.42, -0.05, -0.95),
        mesh: Mesh.flatPanel(halfSpan: 0.22, chord: 0.06, thickness: 0.02, color: pC)));
    add('probe', SceneNode(id: 'probe',
        position: Vector3(0, 0, -1.5),
        rotation: Vector3(math.pi / 2, 0, 0),
        mesh: Mesh.strut(length: 1.5, radius: 0.05, color: Vector3(0.65, 0.82, 1.0))));
    return (root: root, parts: parts);
  }

  // ── FireHawk — balanced fighter-bomber ─────────────────────────────────────

  static AircraftScene _buildFireHawk() {
    const len = 4.0;
    final hl  = len / 2;
    final bw  = len * 0.17;
    final bh  = len * 0.13;
    final ws  = len * 0.78;
    final pri  = Vector3(0.82, 0.10, 0.06);
    final sec  = Vector3(0.52, 0.05, 0.03);
    final ctrl = Vector3(1.00, 0.42, 0.08);
    final gC   = Vector3(0.12, 0.12, 0.14);

    final root  = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};
    root.addChild(SceneNode(id: 'body',
        mesh: Mesh.aircraft(length: len, primaryColor: pri, secondaryColor: sec)));

    void add(String id, SceneNode n) { root.addChild(n); parts[id] = n; }

    add('aileron_l', SceneNode(id: 'aileron_l',
        position: Vector3(-ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.55, chord: 0.38, thickness: 0.04, color: ctrl)));
    add('aileron_r', SceneNode(id: 'aileron_r',
        position: Vector3( ws * 0.40, 0, hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.55, chord: 0.38, thickness: 0.04, color: ctrl)));
    add('elevator', SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, hl * 0.70),
        mesh: Mesh.flatPanel(halfSpan: 0.65, chord: 0.42, thickness: 0.04, color: ctrl)));
    add('rudder', SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, hl * 0.68),
        rotation: Vector3(-math.pi / 2, 0, 0),
        mesh: Mesh.flatPanel(halfSpan: 0.38, chord: 0.32, thickness: 0.04, color: ctrl)));
    add('flap_l', SceneNode(id: 'flap_l',
        position: Vector3(-bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.30, chord: 0.32, thickness: 0.04, color: ctrl)));
    add('flap_r', SceneNode(id: 'flap_r',
        position: Vector3( bw * 0.80, 0, hl * 0.48),
        mesh: Mesh.flatPanel(halfSpan: 0.30, chord: 0.32, thickness: 0.04, color: ctrl)));
    add('gear_nose', SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.50, -hl * 0.40),
        mesh: Mesh.strut(length: 0.75, radius: 0.06, color: gC)));
    add('gear_left', SceneNode(id: 'gear_left',
        position: Vector3(-bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.07, color: gC)));
    add('gear_right', SceneNode(id: 'gear_right',
        position: Vector3( bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.strut(length: 0.80, radius: 0.07, color: gC)));
    add('gear_door_n', SceneNode(id: 'gear_door_n',
        position: Vector3(0, -bh * 0.50, -hl * 0.40),
        mesh: Mesh.flatPanel(halfSpan: 0.18, chord: 0.26, thickness: 0.04, color: gC)));
    add('gear_door_l', SceneNode(id: 'gear_door_l',
        position: Vector3(-bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.flatPanel(halfSpan: 0.20, chord: 0.30, thickness: 0.04, color: gC)));
    add('gear_door_r', SceneNode(id: 'gear_door_r',
        position: Vector3( bw * 0.60, -bh * 0.50, hl * 0.10),
        mesh: Mesh.flatPanel(halfSpan: 0.20, chord: 0.30, thickness: 0.04, color: gC)));
    final bayColor = Vector3(0.65, 0.08, 0.04);
    add('bay_l', SceneNode(id: 'bay_l',
        position: Vector3(-bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.24, chord: 0.40, thickness: 0.03, color: bayColor)));
    add('bay_r', SceneNode(id: 'bay_r',
        position: Vector3( bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.24, chord: 0.40, thickness: 0.03, color: bayColor)));
    add('prop', SceneNode(id: 'prop',
        position: Vector3(0, -bh * 0.10, hl * 0.90),
        mesh: Mesh.flatPanel(halfSpan: bw * 0.55, chord: 0.06, thickness: 0.02,
            color: Vector3(1.0, 0.35, 0.05))));
    return (root: root, parts: parts);
  }

  // ── SkyTanker — Leviathan ART-9 player aircraft ────────────────────────────

  static AircraftScene _buildSkyTanker() {
    // Body uses the same ART-9 mesh as the NPC tanker (14 units long, ±7 Z)
    const hl = 7.0;
    const bw = 1.8;
    const bh = 1.4;
    final ctrl = Vector3(0.65, 0.55, 0.30);
    final gC   = Vector3(0.12, 0.12, 0.14);

    final root  = SceneNode(id: 'aircraft_root');
    final parts = <String, SceneNode>{};
    root.addChild(SceneNode(id: 'body', mesh: TankerAircraft.buildBodyMesh()));

    void add(String id, SceneNode n) { root.addChild(n); parts[id] = n; }

    add('aileron_l', SceneNode(id: 'aileron_l',
        position: Vector3(-8.0, 0, hl * 0.20),
        mesh: Mesh.flatPanel(halfSpan: 1.8, chord: 0.90, thickness: 0.08, color: ctrl)));
    add('aileron_r', SceneNode(id: 'aileron_r',
        position: Vector3( 8.0, 0, hl * 0.20),
        mesh: Mesh.flatPanel(halfSpan: 1.8, chord: 0.90, thickness: 0.08, color: ctrl)));
    add('elevator', SceneNode(id: 'elevator',
        position: Vector3(0, bh * 0.1, hl * 0.80),
        mesh: Mesh.flatPanel(halfSpan: 2.8, chord: 1.20, thickness: 0.08, color: ctrl)));
    add('rudder', SceneNode(id: 'rudder',
        position: Vector3(0, bh * 0.55, hl * 0.78),
        rotation: Vector3(-math.pi / 2, 0, 0),
        mesh: Mesh.flatPanel(halfSpan: 1.4, chord: 1.00, thickness: 0.08, color: ctrl)));
    add('flap_l', SceneNode(id: 'flap_l',
        position: Vector3(-bw * 1.5, 0, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 1.4, chord: 1.10, thickness: 0.08, color: ctrl)));
    add('flap_r', SceneNode(id: 'flap_r',
        position: Vector3( bw * 1.5, 0, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 1.4, chord: 1.10, thickness: 0.08, color: ctrl)));
    add('gear_nose', SceneNode(id: 'gear_nose',
        position: Vector3(0, -bh * 0.50, -hl * 0.50),
        mesh: Mesh.strut(length: 2.0, radius: 0.18, color: gC)));
    add('gear_left', SceneNode(id: 'gear_left',
        position: Vector3(-bw * 0.60, -bh * 0.50, hl * 0.08),
        mesh: Mesh.strut(length: 2.5, radius: 0.22, color: gC)));
    add('gear_right', SceneNode(id: 'gear_right',
        position: Vector3( bw * 0.60, -bh * 0.50, hl * 0.08),
        mesh: Mesh.strut(length: 2.5, radius: 0.22, color: gC)));
    add('gear_door_n', SceneNode(id: 'gear_door_n',
        position: Vector3(0, -bh * 0.50, -hl * 0.50),
        mesh: Mesh.flatPanel(halfSpan: 0.50, chord: 0.90, thickness: 0.06, color: gC)));
    add('gear_door_l', SceneNode(id: 'gear_door_l',
        position: Vector3(-bw * 0.60, -bh * 0.50, hl * 0.08),
        mesh: Mesh.flatPanel(halfSpan: 0.60, chord: 1.00, thickness: 0.06, color: gC)));
    add('gear_door_r', SceneNode(id: 'gear_door_r',
        position: Vector3( bw * 0.60, -bh * 0.50, hl * 0.08),
        mesh: Mesh.flatPanel(halfSpan: 0.60, chord: 1.00, thickness: 0.06, color: gC)));
    final bC = Vector3(0.55, 0.38, 0.12);
    add('bay_l', SceneNode(id: 'bay_l',
        position: Vector3(-bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.70, chord: 1.20, thickness: 0.05, color: bC)));
    add('bay_r', SceneNode(id: 'bay_r',
        position: Vector3( bw * 0.45, -bh * 0.50, hl * 0.15),
        mesh: Mesh.flatPanel(halfSpan: 0.70, chord: 1.20, thickness: 0.05, color: bC)));
    // Four turboprops — one at front of each engine nacelle
    final pC = Vector3(0.60, 0.55, 0.45);
    add('prop_1', SceneNode(id: 'prop_1',
        position: Vector3(-2.5, 0.36, -3.65),
        mesh: Mesh.flatPanel(halfSpan: 1.40, chord: 0.12, thickness: 0.04, color: pC)));
    add('prop_2', SceneNode(id: 'prop_2',
        position: Vector3(-6.2, 0.28, -3.65),
        mesh: Mesh.flatPanel(halfSpan: 1.30, chord: 0.12, thickness: 0.04, color: pC)));
    add('prop_3', SceneNode(id: 'prop_3',
        position: Vector3( 2.5, 0.36, -3.65),
        mesh: Mesh.flatPanel(halfSpan: 1.40, chord: 0.12, thickness: 0.04, color: pC)));
    add('prop_4', SceneNode(id: 'prop_4',
        position: Vector3( 6.2, 0.28, -3.65),
        mesh: Mesh.flatPanel(halfSpan: 1.30, chord: 0.12, thickness: 0.04, color: pC)));
    // Drogue basket — starts at tail, extends backward when deployed
    add('drogue', SceneNode(id: 'drogue',
        position: Vector3(0, -0.50, 7.5),
        mesh: Mesh.cube(size: 0.55, color: Vector3(1.0, 0.55, 0.10))));
    return (root: root, parts: parts);
  }
}
