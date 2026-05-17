import 'dart:html' as html;
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../rendering/aircraft_animator.dart';
import '../rendering/aircraft_builder.dart';
import '../rendering/camera3d.dart';
import '../rendering/mesh.dart';
import '../rendering/particle_system.dart';
import '../rendering/scene_node.dart';
import '../rendering/transform3d.dart';
import '../rendering/webgl_renderer.dart';
import '../systems/ability_system.dart';
import '../systems/input_system.dart';
import '../systems/maneuver_system.dart';
import '../systems/physics_system.dart';
import '../terrain/airfield_generator.dart';
import '../terrain/infinite_terrain_manager.dart';
import '../terrain/terrain_generator.dart';
import '../models/game_action.dart';
import 'fire_emitter.dart';
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

  SceneNode?             _aircraftRoot;
  Map<String, SceneNode> _aircraftParts = {};
  final AircraftAnimator _animator = AircraftAnimator();

  // ── Canvas ────────────────────────────────────────────────────────────────

  html.CanvasElement? _canvas;

  // ── Timing ────────────────────────────────────────────────────────────────

  double _lastTimestamp = 0.0;
  bool   _running       = false;
  double _gameTime      = 0.0;

  // ── Settings ─────────────────────────────────────────────────────────────

  final SettingsState _settings = SettingsState();
  bool _showSettings = false, _showHangar = false;

  // ── Input listener subscriptions ─────────────────────────────────────────

  StreamSubscription<html.KeyboardEvent>? _keyDownSub;
  StreamSubscription<html.KeyboardEvent>? _keyUpSub;
  StreamSubscription<html.Event>?         _blurSub;

  // ── Effect rendering pool ─────────────────────────────────────────────────

  final Map<String, Mesh> _effectMeshCache = {};
  final Transform3d _effectTransform = Transform3d();

  // ── Fire / particle system ────────────────────────────────────────────────

  late FireEmitterSystem _fireSystem;
  double _heatIntensity     = 0.0;
  bool   _heatDistortEnabled = true;

  // ── Edge detection ────────────────────────────────────────────────────────

  final List<bool> _prevAbilityKeys = List.filled(10, false);
  bool _prevToggleView  = false;
  bool _prevToggleGear  = false;
  bool _prevToggleFlaps = false;

  // ── Gear animation ────────────────────────────────────────────────────────

  static const double _gearTransitTime = 3.0;

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
    _fireSystem.particles.clear();
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
    await _initFireSystem();
    _startLoop();
    if (mounted) setState(() {});
  }

  Future<void> _initFireSystem() async {
    final renderer = _renderer;
    final ps = ParticleSystem(maxParticles: renderer != null ? 5000 : 100);
    _fireSystem = FireEmitterSystem(particles: ps);
    await _fireSystem.loadConfig();
    _fireSystem.initZones(_state);

    if (renderer != null) {
      final cw = _canvas?.clientWidth  ?? 1600;
      final ch = _canvas?.clientHeight ?? 900;
      renderer.heatDistortion.init(cw, ch);
      _heatDistortEnabled = renderer.heatDistortion.isAvailable;
      debugPrint('[Game] GPU particles: ${renderer.gpuParticles?.isReady ?? false}');
    }
  }

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
    _blurSub = html.window.onBlur.listen((_) {
      InputSystem.clearAll();
      html.window.requestAnimationFrame((_) => html.document.body?.focus());
    });
  }

  void _buildScene() {
    _terrain = InfiniteTerrainManager()..preload(_state.playerPosition);
    final airfield = AirfieldGenerator.generate();
    _airfieldMesh      = airfield.mesh;
    _airfieldTransform = airfield.transform;
    _rebuildAircraftScene();
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
    _gameTime += dt;
    if (_renderer != null) _renderer!.time = _gameTime;

    final prevMode = _state.gameMode;
    _processInput(dt);
    _tickGearAnimation(dt);
    _checkModeTransitions();
    _state.tickMissionEconomy(dt, prevMode);
    _terrain?.update(_state.playerPosition);
    AbilitySystem.update(_state, dt);
    _tickFireSystem(dt);
    _syncAircraftSceneGraph(dt);
    _renderFrame();
    _scheduleHudRebuild();

    html.window.requestAnimationFrame(_onFrame);
  }

  void _tickFireSystem(double dt) {
    // Emit particle bursts for freshly-fired abilities (replace cube effects).
    for (final effect in AbilitySystem.activeEffects) {
      if (!effect.emitted) {
        final isExpendable = effect.lifetime >= 0.9;
        final count = isExpendable ? 120 : (effect.color.r > 0.5 ? 30 : 20);
        _fireSystem.emitAbilityBurst(effect, count, 2.0);
        effect.emitted = true;
      }
    }

    _fireSystem.tick(_state, dt, TerrainGenerator.heightAt);

    if (_renderer != null) {
      _renderer!.fireLights = _fireSystem.fireLightPositions;
    }

    // Lerp heat distortion intensity toward proximity target.
    final clearance = _state.flightAltitude - _state.terrainHeight;
    if (_state.isFireBelow && clearance >= 5.0 && clearance < 40.0) {
      final proximity = 1.0 - (clearance - 5.0) / 35.0;
      _heatIntensity = (_heatIntensity + (proximity - _heatIntensity) * dt * 3.0)
          .clamp(0.0, 1.0);
    } else {
      _heatIntensity = (_heatIntensity - dt * 2.0).clamp(0.0, 1.0);
    }
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void _processInput(double dt) {
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

    if (_state.autopilotEnabled && (fwd || bk || sl || sr || rl || rr)) {
      _state.autopilotEnabled = false;
    }
    if (_state.activeManeuverIdx != null && (fwd || bk || sl || sr || rl || rr)) {
      _state.stopManeuver();
    }
    final ap = _state.autopilotEnabled;

    PhysicsSystem.updateAutopilot(_state, dt);

    final mo = ManeuverSystem.tick(_state, dt);
    final mi = mo.input;
    _state.maneuverDropWindowActive = mo.dropWindowActive;
    if (mo.dropTriggered) _state.dropRetardant();

    PhysicsSystem.updateFlight(
      _state,
      mi != null ? mi.fwd    : (ap ? false : (_settings.invertedPitch ? bk  : fwd)),
      mi != null ? mi.bk     : (ap ? false : (_settings.invertedPitch ? fwd : bk)),
      mi != null ? mi.bl     : (ap ? false : sl),
      mi != null ? mi.br     : (ap ? false : sr),
      mi != null ? mi.yl     : (ap ? false : rl),
      mi != null ? mi.yr     : (ap ? false : rr),
      mi != null ? mi.sprint : InputSystem.isActionActive(GameAction.sprint),
      mi != null ? mi.brake  : InputSystem.isActionActive(GameAction.brake),
      dt,
    );

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

    final toggleNow = InputSystem.isActionActive(GameAction.toggleView);
    if (toggleNow && !_prevToggleView) _state.toggleViewMode();
    _prevToggleView = toggleNow;

    final gearNow = InputSystem.isActionActive(GameAction.toggleGear);
    if (gearNow && !_prevToggleGear) _state.triggerGear();
    _prevToggleGear = gearNow;

    final flapsNow = InputSystem.isActionActive(GameAction.toggleFlaps);
    if (flapsNow && !_prevToggleFlaps) setState(() => _state.cycleFlaps());
    _prevToggleFlaps = flapsNow;
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
    _state.gearDeployed = _state.gearProgress >= 1.0;
  }

  // ── Mode transitions ──────────────────────────────────────────────────────

  void _checkModeTransitions() {
    switch (_state.gameMode) {
      case GameMode.taxi:
        if (_state.groundSpeed >= _state.cfgLiftoffSpeed) {
          _state.gameMode   = GameMode.flight;
          _state.flightSpeed = _state.groundSpeed;
          debugPrint('[Game] Liftoff → FLIGHT');
        }
      case GameMode.landing:
        final touchFloor = math.max(_state.terrainHeight, 0.5);
        if (_state.playerPosition.y <= touchFloor + 0.1) {
          _state.playerPosition.y = touchFloor;
          _state.gameMode         = GameMode.taxi;
          _state.groundSpeed      = _state.flightSpeed;
          _state.throttle = _state.flightPitchAngle = _state.flightBankAngle = 0.0;
          _state.gearTargetDown = _state.gearDeployed = true;
          _state.gearProgress   = 1.0;
          _state.gearMoving     = false;
        }
      case GameMode.flight:
        final cf = math.max(_state.terrainHeight, 0.5);
        if (_state.playerPosition.y <= cf + 0.1 && _state.flightSpeed < 1.0) {
          _state.playerPosition.y = cf;
          _state.gameMode         = GameMode.taxi;
          _state.groundSpeed      = _state.flightSpeed;
          _state.throttle         = 0.0;
          _state.flightPitchAngle = 0.0;
          _state.flightBankAngle  = 0.0;
        }
    }
  }

  // ── Aircraft scene graph sync ─────────────────────────────────────────────

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
    renderer.heatDistortion.resize(cw, ch);

    // Pass 1: scene → FBO (or directly to screen when heat is off).
    final useHeat = _heatDistortEnabled && _heatIntensity > 0.005;
    if (useHeat) renderer.beginHeatPass();

    renderer.clear();

    final chunks = _terrain?.loadedChunks;
    if (chunks != null) {
      for (final chunk in chunks) {
        renderer.render(chunk.mesh, chunk.transform, camera);
      }
    }
    if (_airfieldMesh != null && _airfieldTransform != null) {
      renderer.render(_airfieldMesh!, _airfieldTransform!, camera);
    }
    if (_state.viewMode != ViewMode.cockpit && _aircraftRoot != null) {
      renderer.renderSceneGraph(_aircraftRoot!, camera);
    }

    // Cube ability effects (kept for HUD feedback; particles play on top).
    for (final effect in AbilitySystem.activeEffects) {
      final sz  = 0.5 * effect.scale.clamp(0.2, 4.0);
      final key = '${effect.color.x},${effect.color.y},${effect.color.z}';
      final em  = _effectMeshCache[key]
          ?? (_effectMeshCache[key] = Mesh.cube(size: 1.0, color: effect.color));
      _effectTransform.position.setFrom(effect.position);
      _effectTransform.scale.setValues(sz, sz, sz);
      renderer.render(em, _effectTransform, camera);
    }

    // Particle layer (fire, smoke, ability bursts).
    renderer.renderParticles(_fireSystem.particles.particles, camera);

    // Pass 2: blit FBO to screen with heat distortion.
    if (useHeat) renderer.endHeatPass(_heatIntensity);
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
          cockpit.buildCockpitHud(
            _state,
            showAnnunciator: _settings.showAnnunciator,
            showTelemetry:   _settings.showTelemetry,
            showActionBar:   _settings.showActionBar,
            showTutorial:    _settings.showTutorial,
            settings:        _settings,
            onLayoutChanged: () { _settings.save(); setState(() {}); },
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
            onDeleteWaypoint:    (i) => setState(() => _state.removeWaypoint(i)),
            onAnnunciatorChange: () => setState(() {}),
            onThrottleModeToggle: () => setState(_state.stepThrottleMode),
            onThrottleChange: (v) => setState(() => _state.throttle = v.clamp(0.0, 1.0)),
            onAuxPage: (p) => setState(() => _state.auxDisplayPage = p),
            onAuxMirrorScroll: (d) => setState(() => _state.scrollAuxMirror(d)),
            onAuxVideoScroll: (d) => setState(() => _state.scrollAuxVideo(d)),
            onManeuverScroll:  (d) => setState(() {
              final n = ManeuverSystem.catalog.length;
              _state.selectedManeuverIdx = (_state.selectedManeuverIdx + d + n) % n;
            }),
            onManeuverExecute: ()  => setState(() => _state.startManeuver(_state.selectedManeuverIdx)),
            onManeuverStop:    ()  => setState(() => _state.stopManeuver()),
          ),

          Positioned(
            top: 12, right: 12,
            child: Row(children: [
              _menuButton('⊞ HANGAR',   _showHangar,   () { setState(() { _showHangar   = !_showHangar;  _showSettings = false; }); }),
              _menuButton('⚙ SETTINGS', _showSettings, () { setState(() { _showSettings = !_showSettings; _showHangar  = false;  }); }),
            ]),
          ),

          if (_showSettings)
            Positioned(
              top: 44, right: 12,
              child: SettingsPanel(
                settings: _settings,
                onClose:   () => setState(() => _showSettings = false),
                onChanged: _onSettingChanged,
              ),
            ),

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
