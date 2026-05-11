import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:vector_math/vector_math.dart' hide Colors;

import '../rendering/camera3d.dart';
import '../rendering/mesh.dart';
import '../rendering/transform3d.dart';
import '../rendering/webgl_renderer.dart';
import '../systems/ability_system.dart';
import '../systems/input_system.dart';
import '../systems/physics_system.dart';
import '../terrain/terrain_generator.dart';
import '../models/game_action.dart';
import 'game_state.dart' show GameState, ViewMode;
import 'cockpit_hud.dart' as cockpit;

/// FireAndIceGame - Main game widget.
///
/// Manages the full game lifecycle:
///  1. Creates a dart:html CanvasElement positioned fixed behind Flutter (z-index -1).
///  2. Runs a requestAnimationFrame game loop for 60 fps rendering.
///  3. Composites a transparent Flutter HUD overlay on top of the WebGL canvas.
///
/// The canvas sits behind Flutter's widget tree (same pattern as Warchief).
/// The Scaffold/Container background is transparent so the WebGL canvas shows through.
/// HUD rendering is delegated to hud_widgets.dart to stay under 500 lines.
class FireAndIceGame extends StatefulWidget {
  const FireAndIceGame({super.key});

  @override
  State<FireAndIceGame> createState() => _FireAndIceGameState();
}

class _FireAndIceGameState extends State<FireAndIceGame> {
  // ── Core objects ──────────────────────────────────────────────────────────

  final GameState _state = GameState();
  WebGLRenderer?  _renderer;
  Camera3D?       _camera;

  // ── Scene meshes ──────────────────────────────────────────────────────────

  Mesh?        _terrainMesh;
  Transform3d? _terrainTransform;
  Mesh?        _playerMesh;
  Transform3d? _playerTransform;

  // ── Canvas ────────────────────────────────────────────────────────────────

  html.CanvasElement? _canvas;

  // ── Timing ────────────────────────────────────────────────────────────────

  double _lastTimestamp = 0.0;
  bool   _running       = false;

  // ── Ability one-shot tracking ─────────────────────────────────────────────

  /// Previous-frame state for each ability slot key (for edge detection).
  final List<bool> _prevAbilityKeys = List.filled(10, false);

  /// Previous-frame state for view-toggle key (Tab).
  bool _prevToggleView = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _running = false;
    _renderer?.dispose();
    _canvas?.remove(); // Remove from DOM to prevent leaks
    super.dispose();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Full async init sequence: config → canvas → scene → loop.
  Future<void> _bootstrap() async {
    await _state.initialize();
    _setupCanvas();
    _registerKeyListeners();
    _buildScene();
    _startLoop();
    if (mounted) setState(() {});
  }

  /// Create the WebGL canvas positioned fixed behind the Flutter widget tree.
  ///
  /// Reason: same pattern as Warchief — canvas at z-index -1 lets Flutter's
  /// transparent Scaffold composite the HUD on top without platform views.
  void _setupCanvas() {
    _canvas = html.CanvasElement(width: 1600, height: 900)
      ..id = 'fire-and-ice-canvas'
      ..style.position     = 'fixed'
      ..style.top          = '0'
      ..style.left         = '0'
      ..style.width        = '100%'
      ..style.height       = '100%'
      ..style.display      = 'block'
      ..style.zIndex       = '-1'       // Behind Flutter UI
      ..style.pointerEvents = 'none';   // Flutter handles pointer events

    html.document.body?.append(_canvas!);

    try {
      _renderer = WebGLRenderer(_canvas!);
    } catch (e) {
      debugPrint('[FireAndIceGame] WebGL unavailable: $e');
    }

    _camera = Camera3D(aspectRatio: 1600 / 900, fov: 90.0);
  }

  /// Attach keyboard listeners on the document for game input.
  void _registerKeyListeners() {
    html.document.onKeyDown.listen(InputSystem.handleKeyDown);
    html.document.onKeyUp.listen(InputSystem.handleKeyUp);
    // Clear pressed keys on window blur to prevent stuck keys
    html.window.onBlur.listen((_) => InputSystem.clearAll());
  }

  /// Generate terrain mesh and create player aircraft mesh.
  void _buildScene() {
    final terrain = TerrainGenerator.generate(
      gridSize: 64, tileSize: 2.0, maxHeight: 12.0, seed: 1337,
    );
    _terrainMesh      = terrain.mesh;
    _terrainTransform = terrain.transform;

    _playerMesh = Mesh.aircraft(length: 4.0);
    _playerTransform = Transform3d(
      position: Vector3.copy(_state.playerPosition),
    );
  }

  // ── Game loop ─────────────────────────────────────────────────────────────

  void _startLoop() {
    _running = true;
    html.window.requestAnimationFrame(_onFrame);
  }

  void _onFrame(num timestamp) {
    if (!_running) return;

    final now = timestamp.toDouble();
    // Cap dt to 50ms to prevent large physics jumps after tab switch
    final dt  = math.min((now - _lastTimestamp) / 1000.0, 0.05);
    _lastTimestamp = now;

    _processInput(dt);
    AbilitySystem.update(_state, dt);
    _syncPlayerTransform();
    _renderFrame();
    _scheduleHudRebuild();

    html.window.requestAnimationFrame(_onFrame);
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void _processInput(double dt) {
    PhysicsSystem.updateFlight(
      _state,
      InputSystem.isActionActive(GameAction.moveForward),
      InputSystem.isActionActive(GameAction.moveBackward),
      InputSystem.isActionActive(GameAction.strafeLeft),
      InputSystem.isActionActive(GameAction.strafeRight),
      InputSystem.isActionActive(GameAction.rotateLeft),
      InputSystem.isActionActive(GameAction.rotateRight),
      InputSystem.isActionActive(GameAction.sprint),
      InputSystem.isActionActive(GameAction.brake),
      dt,
    );

    // Edge-detect slot keys so abilities fire once per press (not per frame)
    const slotActions = [
      GameAction.actionBar1, GameAction.actionBar2, GameAction.actionBar3,
      GameAction.actionBar4, GameAction.actionBar5, GameAction.actionBar6,
      GameAction.actionBar7, GameAction.actionBar8, GameAction.actionBar9,
      GameAction.actionBar10,
    ];

    for (int i = 0; i < slotActions.length; i++) {
      final pressed = InputSystem.isActionActive(slotActions[i]);
      if (pressed && !_prevAbilityKeys[i]) {
        AbilitySystem.activateAbility(_state, i);
      }
      _prevAbilityKeys[i] = pressed;
    }

    // Edge-detect Tab so each press toggles once, not continuously
    final toggleNow = InputSystem.isActionActive(GameAction.toggleView);
    if (toggleNow && !_prevToggleView) _state.toggleViewMode();
    _prevToggleView = toggleNow;
  }

  // ── Transform sync ────────────────────────────────────────────────────────

  /// Copy flight state into the player's rendering Transform3d.
  void _syncPlayerTransform() {
    if (_playerTransform == null) return;
    _playerTransform!.position = Vector3.copy(_state.playerPosition);
    _playerTransform!.rotation = Vector3(
      _state.flightPitchAngle,
      _state.playerRotation.y,
      -_state.flightBankAngle, // Negate: right-bank tilts right wing down
    );
  }

  // ── WebGL rendering ───────────────────────────────────────────────────────

  void _renderFrame() {
    final renderer = _renderer;
    final camera   = _camera;
    if (renderer == null || camera == null) return;

    // Position camera based on active view mode
    if (_state.viewMode == ViewMode.cockpit) {
      camera.positionAsCockpit(
        _state.playerPosition,
        _state.playerRotation.y,
        _state.flightPitchAngle,
        _state.flightBankAngle,
      );
    } else {
      camera.updateThirdPersonFollow(
        _state.playerPosition,
        _state.playerRotation.y,
        _state.flightBankAngle,
        0.016,
      );
    }

    // Keep aspect ratio in sync with actual canvas size
    final cw = _canvas?.clientWidth  ?? 1600;
    final ch = _canvas?.clientHeight ?? 900;
    if (ch > 0) camera.aspectRatio = cw / ch;

    renderer.clear();

    if (_terrainMesh != null && _terrainTransform != null) {
      renderer.render(_terrainMesh!, _terrainTransform!, camera);
    }

    // Skip rendering the aircraft in cockpit view — the camera is inside the
    // mesh so backface-culling exposes the interior.  Standard first-person
    // practice: hide the player model when the camera is the player's eye.
    if (_state.viewMode != ViewMode.cockpit &&
        _playerMesh != null && _playerTransform != null) {
      renderer.render(_playerMesh!, _playerTransform!, camera);
    }

    // Ability visual effects: small colored cubes expanding outward
    for (final effect in AbilitySystem.activeEffects) {
      final size = 0.5 * effect.scale.clamp(0.2, 4.0);
      final effectMesh = Mesh.cube(size: size, color: effect.color);
      final effectXform = Transform3d(position: Vector3.copy(effect.position));
      renderer.render(effectMesh, effectXform, camera);
    }
  }

  // ── HUD rebuild throttle ──────────────────────────────────────────────────

  int _hudSkip = 0;

  /// Rebuild Flutter HUD at ~30 Hz (every other 60fps frame).
  ///
  /// Reason: halving widget-tree rebuild rate saves CPU without any
  /// perceptible latency on text readouts like cooldowns and altitude.
  void _scheduleHudRebuild() {
    if (++_hudSkip >= 2) {
      _hudSkip = 0;
      if (mounted) setState(() {});
    }
  }

  // ── Widget tree ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Reason: the WebGL canvas renders behind this widget tree at z-index -1.
    // This transparent Container is a full-screen pass-through that lets the
    // HUD overlay sit above the canvas without any platform view overhead.
    return Container(
      color: Colors.transparent,
      child: cockpit.buildCockpitHud(
        _state,
        onAbilityActivate: (i) => AbilitySystem.activateAbility(_state, i),
        onLeftPage:  (p) => setState(() => _state.leftMfdPage  = p),
        onRightPage: (p) => setState(() => _state.rightMfdPage = p),
        onMapZoom:   ()  => setState(() => _state.mapZoom = (_state.mapZoom + 1) % 3),
      ),
    );
  }
}
