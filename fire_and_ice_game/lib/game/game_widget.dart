import 'dart:html' as html;
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../rendering/aircraft_animator.dart';
import '../rendering/aircraft_builder.dart';
import '../rendering/camera3d.dart';
import '../rendering/mesh.dart';
import '../rendering/scene_node.dart';
import '../rendering/transform3d.dart';
import '../rendering/webgl_renderer.dart';
import '../systems/ability_system.dart';
import '../systems/input_system.dart';
import '../systems/physics_system.dart';
import '../terrain/airfield_generator.dart';
import '../terrain/infinite_terrain_manager.dart';
import '../models/game_action.dart';
import 'game_state.dart';
import 'hangar_screen.dart';
import 'settings_panel.dart';
import 'settings_state.dart';
import 'cockpit_hud.dart' as cockpit;

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

  // ── Scene ─────────────────────────────────────────────────────────────────

  InfiniteTerrainManager? _terrain;
  Mesh?        _airfieldMesh;
  Transform3d? _airfieldTransform;

  // Multi-part animated aircraft scene graph (replaces single _playerMesh)
  SceneNode?             _aircraftRoot;
  Map<String, SceneNode> _aircraftParts = {};
  final AircraftAnimator _animator = AircraftAnimator();

  // ── Canvas ────────────────────────────────────────────────────────────────

  html.CanvasElement? _canvas;

  // ── Timing ────────────────────────────────────────────────────────────────

  double _lastTimestamp = 0.0;
  bool   _running       = false;

  // ── Settings ─────────────────────────────────────────────────────────────

  final SettingsState _settings = SettingsState();
  bool _showSettings = false, _showHangar = false;

  // ── Input listener subscriptions (cancelled on dispose) ──────────────────

  StreamSubscription<html.KeyboardEvent>? _keyDownSub;
  StreamSubscription<html.KeyboardEvent>? _keyUpSub;
  StreamSubscription<html.Event>?         _blurSub;

  // ── Effect rendering pool (avoids per-frame mesh allocation) ─────────────

  /// One reusable cube mesh per unique ability colour, keyed as 'r,g,b'.
  final Map<String, Mesh> _effectMeshCache = {};

  /// Single reusable transform for effect rendering; reset each draw call.
  final Transform3d _effectTransform = Transform3d();

  // ── Edge detection ────────────────────────────────────────────────────────

  final List<bool> _prevAbilityKeys = List.filled(10, false);
  bool _prevToggleView = false;
  bool _prevToggleGear = false;

  // ── Gear animation ────────────────────────────────────────────────────────

  static const double _gearTransitTime = 3.0; // seconds

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() { super.initState(); _bootstrap(); }

  @override
  void dispose() {
    _running = false;
    _renderer?.dispose();
    _canvas?.remove();
    _keyDownSub?.cancel();
    _keyUpSub?.cancel();
    _blurSub?.cancel();
    super.dispose();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _state.initialize();
    await _settings.load();
    _settings.aircraftConfigs = _state.aircraftConfigs;
    _settings.applyFlight(_state);
    _settings.applyAircraftStats(_state);
    if (_settings.defaultCockpit) _state.viewMode = ViewMode.cockpit;
    _setupCanvas();
    _registerKeyListeners();
    _buildScene();
    _startLoop();
    if (mounted) setState(() {});
  }

  /// Called by the settings panel on every value change.
  void _onSettingChanged() {
    final prevId = _state.aircraftId;
    _settings.save();
    _settings.applyFlight(_state);
    _settings.applyAircraftStats(_state);
    if (_camera != null) _settings.applyCamera(_camera!);
    if (_state.aircraftId != prevId) {
      if (_state.isAircraftUnlocked(_state.aircraftId)) {
        _rebuildAircraftScene();
      } else {
        _state.aircraftId          = prevId;
        _settings.selectedAircraft = prevId;
      }
    }
    setState(() {});
  }

  void _rebuildAircraftScene() {
    final scene   = AircraftBuilder.build(_state.currentAircraft);
    _aircraftRoot  = scene.root;
    _aircraftParts = scene.parts;
    _state.loadAbilitiesFor(_state.aircraftId);
  }

  void _setupCanvas() {
    _canvas = html.CanvasElement(width: 1600, height: 900)
      ..id = 'fire-and-ice-canvas'
      ..style.position      = 'fixed'
      ..style.top           = '0'
      ..style.left          = '0'
      ..style.width         = '100%'
      ..style.height        = '100%'
      ..style.display       = 'block'
      ..style.zIndex        = '-1'
      ..style.pointerEvents = 'none';

    html.document.body?.append(_canvas!);

    try { _renderer = WebGLRenderer(_canvas!); } catch (e) {
      debugPrint('[FireAndIceGame] WebGL unavailable: $e');
    }

    _camera = Camera3D(aspectRatio: 1600 / 900, fov: 90.0);
  }

  void _registerKeyListeners() {
    _keyDownSub = html.document.onKeyDown.listen(InputSystem.handleKeyDown);
    _keyUpSub   = html.document.onKeyUp.listen(InputSystem.handleKeyUp);
    _blurSub    = html.window.onBlur.listen((_) => InputSystem.clearAll());
  }

  void _buildScene() {
    _terrain = InfiniteTerrainManager()..preload(_state.playerPosition);
    final airfield = AirfieldGenerator.generate();
    _airfieldMesh      = airfield.mesh;
    _airfieldTransform = airfield.transform;
    _rebuildAircraftScene(); // also loads per-aircraft abilities
    for (final ab in _state.abilities) {
      final key = '${ab.color.x},${ab.color.y},${ab.color.z}';
      _effectMeshCache[key] ??= Mesh.cube(size: 1.0, color: ab.color);
    }
  }

  // ── Game loop ─────────────────────────────────────────────────────────────

  void _startLoop() { _running = true; html.window.requestAnimationFrame(_onFrame); }

  void _onFrame(num timestamp) {
    if (!_running) return;
    final now = timestamp.toDouble();
    final dt  = math.min((now - _lastTimestamp) / 1000.0, 0.05);
    _lastTimestamp = now;

    final prevMode = _state.gameMode;
    _processInput(dt);
    _tickGearAnimation(dt);
    _checkModeTransitions();
    _state.tickMissionEconomy(dt, prevMode);
    _terrain?.update(_state.playerPosition);
    AbilitySystem.update(_state, dt);
    _syncAircraftSceneGraph(dt);
    _renderFrame();
    _scheduleHudRebuild();

    html.window.requestAnimationFrame(_onFrame);
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void _processInput(double dt) {
    // Throttle: continuous while held
    if (InputSystem.isActionActive(GameAction.throttleUp)) {
      _state.throttle = (_state.throttle + _state.cfgThrottleRate * dt).clamp(0.0, 1.0);
    }
    if (InputSystem.isActionActive(GameAction.throttleDown)) {
      _state.throttle = (_state.throttle - _state.cfgThrottleRate * dt).clamp(0.0, 1.0);
    }

    final fwd = InputSystem.isActionActive(GameAction.moveForward);
    final bk  = InputSystem.isActionActive(GameAction.moveBackward);
    final sl  = InputSystem.isActionActive(GameAction.strafeLeft);
    final sr  = InputSystem.isActionActive(GameAction.strafeRight);
    final rl  = InputSystem.isActionActive(GameAction.rotateLeft);
    final rr  = InputSystem.isActionActive(GameAction.rotateRight);

    // Any manual flight input disengages autopilot
    if (_state.autopilotEnabled && (fwd || bk || sl || sr || rl || rr)) {
      _state.autopilotEnabled = false;
    }
    final ap = _state.autopilotEnabled;

    PhysicsSystem.updateAutopilot(_state, dt);

    PhysicsSystem.updateFlight(
      _state,
      ap ? false : (_settings.invertedPitch ? bk  : fwd),
      ap ? false : (_settings.invertedPitch ? fwd : bk),
      ap ? false : sl,
      ap ? false : sr,
      ap ? false : rl,
      ap ? false : rr,
      InputSystem.isActionActive(GameAction.sprint),
      InputSystem.isActionActive(GameAction.brake),
      dt,
    );

    // Edge-detect ability slots
    const slotActions = [
      GameAction.actionBar1, GameAction.actionBar2, GameAction.actionBar3,
      GameAction.actionBar4, GameAction.actionBar5, GameAction.actionBar6,
      GameAction.actionBar7, GameAction.actionBar8, GameAction.actionBar9,
      GameAction.actionBar10,
    ];
    for (int i = 0; i < slotActions.length; i++) {
      final pressed = InputSystem.isActionActive(slotActions[i]);
      if (pressed && !_prevAbilityKeys[i]) AbilitySystem.activateAbility(_state, i);
      _prevAbilityKeys[i] = pressed;
    }

    // Edge-detect Tab
    final toggleNow = InputSystem.isActionActive(GameAction.toggleView);
    if (toggleNow && !_prevToggleView) _state.toggleViewMode();
    _prevToggleView = toggleNow;

    // Edge-detect G (gear)
    final gearNow = InputSystem.isActionActive(GameAction.toggleGear);
    if (gearNow && !_prevToggleGear) _state.triggerGear();
    _prevToggleGear = gearNow;
  }

  // ── Gear animation tick ───────────────────────────────────────────────────

  void _tickGearAnimation(double dt) {
    if (!_state.gearMoving) return;
    final rate = 1.0 / _gearTransitTime;
    if (_state.gearTargetDown) {
      _state.gearProgress = (_state.gearProgress + rate * dt).clamp(0.0, 1.0);
      if (_state.gearProgress >= 1.0) {
        _state.gearMoving   = false;
        _state.gearDeployed = true;
      }
    } else {
      _state.gearProgress = (_state.gearProgress - rate * dt).clamp(0.0, 1.0);
      if (_state.gearProgress <= 0.0) {
        _state.gearMoving   = false;
        _state.gearDeployed = false;
      }
    }
    // Update deployed flag mid-transit for annunciator
    _state.gearDeployed = _state.gearProgress >= 1.0;
  }

  // ── Mode transitions ──────────────────────────────────────────────────────

  void _checkModeTransitions() {
    switch (_state.gameMode) {
      case GameMode.taxi:
        // Liftoff: speed reaches threshold
        if (_state.groundSpeed >= _state.cfgLiftoffSpeed) {
          _state.gameMode   = GameMode.flight;
          _state.flightSpeed = _state.groundSpeed;
          debugPrint('[Game] Liftoff → FLIGHT');
        }
      case GameMode.landing:
        // Touchdown: aircraft descends to runway surface
        if (_state.playerPosition.y <= 0.55) {
          _state.playerPosition.y = 0.5;
          _state.gameMode          = GameMode.taxi;
          _state.groundSpeed       = _state.flightSpeed;
          _state.throttle          = 0.0;
          _state.flightPitchAngle  = 0.0;
          _state.flightBankAngle   = 0.0;
          _state.gearTargetDown    = true;
          _state.gearDeployed      = true;
          _state.gearProgress      = 1.0;
          _state.gearMoving        = false;
          debugPrint('[Game] Touchdown → TAXI');
        }
      case GameMode.flight:
        break;
    }
  }

  // ── Aircraft scene graph sync ──────────────────────────────────────────────

  void _syncAircraftSceneGraph(double dt) {
    final root = _aircraftRoot;
    if (root == null) return;
    _animator.update(root, _aircraftParts, _state, dt);
  }

  // ── WebGL rendering ───────────────────────────────────────────────────────

  void _renderFrame() {
    final renderer = _renderer;
    final camera   = _camera;
    if (renderer == null || camera == null) return;

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

    final cw = _canvas?.clientWidth  ?? 1600;
    final ch = _canvas?.clientHeight ?? 900;
    if (ch > 0) camera.aspectRatio = cw / ch;

    renderer.clear();

    // Render all loaded terrain chunks
    final chunks = _terrain?.loadedChunks;
    if (chunks != null) {
      for (final chunk in chunks) {
        renderer.render(chunk.mesh, chunk.transform, camera);
      }
    }

    if (_airfieldMesh != null && _airfieldTransform != null) {
      renderer.render(_airfieldMesh!, _airfieldTransform!, camera);
    }

    // Render multi-part aircraft scene graph (not visible from cockpit view)
    if (_state.viewMode != ViewMode.cockpit && _aircraftRoot != null) {
      renderer.renderSceneGraph(_aircraftRoot!, camera);
    }

    // Render effects using pre-allocated meshes and a single reusable transform.
    // No allocations inside this loop — colour is baked into the cached mesh,
    // size is applied via the transform scale.
    for (final effect in AbilitySystem.activeEffects) {
      final sz  = 0.5 * effect.scale.clamp(0.2, 4.0);
      final key = '${effect.color.x},${effect.color.y},${effect.color.z}';
      final em  = _effectMeshCache[key]
          ?? (_effectMeshCache[key] = Mesh.cube(size: 1.0, color: effect.color));
      _effectTransform.position.setFrom(effect.position);
      _effectTransform.scale.setValues(sz, sz, sz);
      renderer.render(em, _effectTransform, camera);
    }
  }

  // ── HUD rebuild ───────────────────────────────────────────────────────────

  int _hudSkip = 0;

  void _scheduleHudRebuild() {
    if (++_hudSkip >= 2) {
      _hudSkip = 0;
      if (mounted) setState(() {});
    }
  }

  // ── Widget tree ───────────────────────────────────────────────────────────

  Widget _menuButton(String label, bool active, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF003366) : Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? const Color(0xFF00AAFF) : const Color(0xFF334455)),
        ),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFF00AAFF) : const Color(0xFF80DDFF),
          fontSize: 9, letterSpacing: 1)),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Main HUD ──────────────────────────────────────────────────────
          cockpit.buildCockpitHud(
            _state,
            showAnnunciator: _settings.showAnnunciator,
            showTelemetry:    _settings.showTelemetry,
            showActionBar:    _settings.showActionBar,
            showTutorial:     _settings.showTutorial,
            cockpitDraggable: _settings.cockpitDraggable,
            showCockpitInfo:  _settings.showCockpitInfo,
            onAbilityActivate: (i) => AbilitySystem.activateAbility(_state, i),
            onLeftPage:   (p) => setState(() => _state.leftMfdPage  = p),
            onRightPage:  (p) => setState(() => _state.rightMfdPage = p),
            onMapZoom:      ()  => setState(() => _state.mapZoom = (_state.mapZoom + 1) % 3),
            onGearToggle:   ()  => setState(() => _state.triggerGear()),
            onFlapsToggle:  ()  => setState(() => _state.cycleFlaps()),
            onAutopilot:    ()  => setState(() => _state.toggleAutopilot()),
            onWaypointLock: ()  => setState(() => _state.cycleWaypointLock()),
            onClear:        ()  => setState(() => _state.clearNav()),
            onSuppArm:      ()  => setState(() => _state.toggleSuppArm()),
            onSuppAuto:     ()  => setState(() => _state.toggleSuppAuto()),
            onRetardantKnob:()  => setState(() => _state.stepRetardant()),
            onRangeKnob:    ()  => setState(() => _state.stepDropRange()),
            onSensorKnob:   ()  => setState(() => _state.stepSensorGain()),
            onNavMapTap:    (wx, wz) => setState(() => _state.addWaypoint(wx, wz)),
            onDeleteWaypoint: (i) => setState(() => _state.removeWaypoint(i)),
          ),

          // ── Top-right menu buttons ─────────────────────────────────────────
          Positioned(
            top: 12, right: 12,
            child: Row(children: [
              _menuButton('⊞ HANGAR',   _showHangar,   () { setState(() { _showHangar   = !_showHangar;  _showSettings = false; }); }),
              _menuButton('⚙ SETTINGS', _showSettings, () { setState(() { _showSettings = !_showSettings; _showHangar  = false;  }); }),
            ]),
          ),

          // ── Settings panel overlay ─────────────────────────────────────────
          if (_showSettings)
            Positioned(
              top: 44, right: 12,
              child: SettingsPanel(
                settings: _settings,
                onClose:   () => setState(() => _showSettings = false),
                onChanged: _onSettingChanged,
              ),
            ),

          // ── Hangar overlay ─────────────────────────────────────────────────
          if (_showHangar)
            Positioned.fill(child: buildHangarScreen(
              _state,
              onClose: () => setState(() => _showHangar = false),
              onSelectAircraft: (id) {
                _settings.selectedAircraft = id;
                _showHangar = false;
                _onSettingChanged();
              },
              onEquipUpgrade:   (ac, up) => setState(() => _state.equipUpgrade(ac, up)),
              onUnequipUpgrade: (ac, up) => setState(() => _state.unequipUpgrade(ac, up)),
            )),
        ],
      ),
    );
  }
}
