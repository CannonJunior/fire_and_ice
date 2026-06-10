import 'dart:html' as html;
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

import '../rendering/aircraft_animator.dart';
import '../rendering/aircraft_builder.dart';
import '../rendering/tanker_aircraft.dart';
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
import '../systems/wyvern_system.dart';
import '../terrain/airbase_generator.dart';
import '../terrain/airfield_generator.dart';
import '../terrain/cloud_system.dart';
import '../terrain/infinite_terrain_manager.dart';
import '../terrain/terrain_generator.dart';
import '../models/game_action.dart';
import '../rendering/wind_particles.dart';
import 'fire_emitter.dart';
import 'game_over_overlay.dart';
import 'game_state.dart';
import 'ice_breath_base.dart';
import 'ice_breath_emitter.dart';
import 'ice_breath_helix.dart';
import 'ice_breath_cascade.dart';
import 'ice_breath_storm.dart';
import 'hangar_screen.dart';
import 'mission_screen.dart';
import 'mission_state.dart';
import 'settings_panel.dart';
import 'settings_state.dart';
import 'cockpit_hud.dart' as cockpit;
import 'smoke_overlay.dart';
import 'game_state_bridge.dart';
import 'ollama_client.dart';
import 'radio_system.dart';
import 'controls_map_overlay.dart';
import '../terrain/lake_generator.dart';
import '../terrain/tree_system.dart';
import '../rendering/tree_renderer.dart';
import '../data/abilities.dart';

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
  // E-W runway is baked into the same airfield mesh (generated together)

  Mesh?        _lakeMesh;
  Transform3d? _lakeTransform;

  // Airbase buildings
  Mesh? _apronMesh;      Transform3d? _apronTransform;
  Mesh? _mainHgrMesh;    Transform3d? _mainHgrTransform;
  Mesh? _secHgrMesh;     Transform3d? _secHgrTransform;
  Mesh? _tocMesh;        Transform3d? _tocTransform;
  Mesh? _towerMesh;      Transform3d? _towerTransform;
  // Pre-built pairs — avoids a literal-list allocation every render frame.
  List<(Mesh, Transform3d)> _airbasePairs = const [];

  SceneNode?             _aircraftRoot;
  Map<String, SceneNode> _aircraftParts = {};
  final AircraftAnimator _animator = AircraftAnimator();

  late final TankerAircraft _tanker;

  // ── Canvas ────────────────────────────────────────────────────────────────

  html.CanvasElement? _canvas;

  // ── Timing ────────────────────────────────────────────────────────────────

  double _lastTimestamp = 0.0;
  bool   _running       = false;
  double _gameTime      = 0.0;
  int    _frameCount    = 0;

  // ── Settings ─────────────────────────────────────────────────────────────

  final SettingsState _settings = SettingsState();
  bool _showSettings = false, _showHangar = false, _showMission = false;
  bool _showKeyboardMap = false;

  // ── Input listener subscriptions ─────────────────────────────────────────

  StreamSubscription<html.KeyboardEvent>? _keyDownSub;
  StreamSubscription<html.KeyboardEvent>? _keyUpSub;
  StreamSubscription<html.Event>?         _blurSub;

  // ── Effect rendering pool ─────────────────────────────────────────────────

  final Map<int, Mesh> _effectMeshCache = {};

  static int _colorKey(Vector3 c) =>
      (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round();
  late final Mesh _wyvernMesh;
  final Transform3d _effectTransform = Transform3d();

  // ── Trees ─────────────────────────────────────────────────────────────────

  final TreeSystem   _treeSystem   = TreeSystem();
  final TreeRenderer _treeRenderer = TreeRenderer();
  final Map<int, FireEmitter> _treeEmitters = {};
  // Cached snapshot rebuilt only when tree states change (avoids O(n) alloc every HUD frame).
  List<(double, double, int)> _treeSnapshotCache = const [];

  // ── Fire / particle system ────────────────────────────────────────────────

  late FireEmitterSystem _fireSystem;
  double _heatIntensity     = 0.0;
  bool   _heatDistortEnabled = true;

  // ── Cloud system ──────────────────────────────────────────────────────────

  final CloudSystem _cloudSystem = CloudSystem();
  double _cloudOverlayOpacity    = 0.0; // fly-through mist alpha (lerped)

  // ── Ice Breath ────────────────────────────────────────────────────────────

  late final List<IceBreathEmitterBase> _allEmitters;
  IceBreathEmitterBase get _iceBreathEmitter => _allEmitters[_state.iceBreathVariant];
  bool   _iceBreathActive     = false;
  double _iceBreathSupprTimer = 0.0;
  final Vector3 _iceBreathFwdScratch = Vector3.zero();
  static const double _iceBreathManaDrain = 18.0; // mana/sec while beam held

  // ── Edge detection ────────────────────────────────────────────────────────

  final List<bool> _prevAbilityKeys = List.filled(10, false);
  bool _prevToggleView          = false;
  bool _prevToggleGear          = false;
  bool _prevToggleFlaps         = false;
  bool _prevToggleProbe         = false;
  bool _prevToggleDrogue        = false;
  bool _prevCycleTarget         = false;
  bool _prevCycleFriendlyTarget = false;

  // ── Canvas size tracking ──────────────────────────────────────────────────

  int _lastCanvasW = 0;
  int _lastCanvasH = 0;

  // ── Gear + probe transit times ────────────────────────────────────────────

  static const double _gearTransitTime  = 3.0;
  static const double _probeTransitTime = 2.5;

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
    await _treeSystem.loadConfig();
    _buildScene();
    await _initFireSystem();
    await _cloudSystem.loadConfig();
    _cloudSystem.generate(150.0); // 150 world-unit radius around origin
    await WyvernSystem.loadConfig();
    WyvernSystem.spawnDefault(_state);
    RadioSystem.reset();
    _startLoop();
    if (mounted) setState(() {});
  }

  Future<void> _initFireSystem() async {
    final renderer = _renderer;
    final ps = ParticleSystem(maxParticles: renderer != null ? 6000 : 100);
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

    _camera = Camera3D(aspectRatio: 1600 / 900, fov: 90.0, far: 2000.0);
  }

  void _registerKeyListeners() {
    _keyDownSub = html.document.onKeyDown.listen(_onKeyDown);
    _keyUpSub   = html.document.onKeyUp.listen(_onKeyUp);
    _blurSub = html.window.onBlur.listen((_) {
      InputSystem.clearAll();
      html.window.requestAnimationFrame((_) => html.document.body?.focus());
    });
  }

  void _onKeyDown(html.KeyboardEvent event) {
    if (_state.chatInputActive) { _handleChatKeyDown(event); return; }
    if (event.key == 'Escape') {
      event.preventDefault();
      setState(() => _state.clearTargets());
      return;
    }
    if (event.shiftKey && event.key == 'Enter') {
      event.preventDefault();
      setState(() { _state.chatInputActive = true; _state.auxDisplayPage = 0; });
      return;
    }
    InputSystem.handleKeyDown(event);
  }

  void _onKeyUp(html.KeyboardEvent event) {
    if (_state.chatInputActive) return;
    InputSystem.handleKeyUp(event);
  }

  void _handleChatKeyDown(html.KeyboardEvent event) {
    event.preventDefault();
    final key = event.key ?? '';
    if (key == 'Enter') {
      final msg = _state.chatInputBuffer.trim();
      setState(() { _state.chatInputActive = false; _state.chatInputBuffer = ''; });
      if (msg.isNotEmpty) _sendChatMessage(msg);
    } else if (key == 'Escape') {
      setState(() { _state.chatInputActive = false; _state.chatInputBuffer = ''; });
    } else if (key == 'Backspace') {
      if (_state.chatInputBuffer.isNotEmpty) {
        setState(() => _state.chatInputBuffer =
            _state.chatInputBuffer.substring(0, _state.chatInputBuffer.length - 1));
      }
    } else if (key.length == 1) {
      setState(() => _state.chatInputBuffer += key);
    }
  }

  String _nowHHMM() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendChatMessage(String msg) async {
    final history = _state.chatHistory.map((h) => (h.$1, h.$2)).toList();
    setState(() { _state.chatHistory.add(('user', msg, _nowHHMM())); _state.chatPending = true; });
    final reply = await OllamaClient.chat(msg, history);
    if (mounted) setState(() { _state.chatHistory.add(('assistant', reply, _nowHHMM())); _state.chatPending = false; });
  }

  void _buildScene() {
    final abX = _state.cfgRunwayStartX; // airfield X offset (also used below)
    _terrain = InfiniteTerrainManager()
      ..addFlatZone(abX, 0.0, 95.0, blend: 50.0)  // suppress hills under airfield+buildings
      ..preload(_state.playerPosition);
    final airfield = AirfieldGenerator.generate();
    _airfieldMesh      = airfield.mesh;
    _airfieldTransform = airfield.transform;

    final lake = LakeGenerator.generate();
    _lakeMesh      = lake.mesh;
    _lakeTransform = lake.transform;

    // Airbase complex — offset west so the airbase is clear of all fire zones.
    final apron  = AirbaseGenerator.generateApron();
    _apronMesh = apron.mesh; _apronTransform = apron.transform;
    final mh = AirbaseGenerator.generateMainHangar();
    _mainHgrMesh = mh.mesh; _mainHgrTransform = mh.transform;
    final sh = AirbaseGenerator.generateSecondaryHangar();
    _secHgrMesh = sh.mesh; _secHgrTransform = sh.transform;
    final toc = AirbaseGenerator.generateTOC();
    _tocMesh = toc.mesh; _tocTransform = toc.transform;
    final ct = AirbaseGenerator.generateControlTower();
    _towerMesh = ct.mesh; _towerTransform = ct.transform;
    for (final t in [
      _airfieldTransform, _apronTransform, _mainHgrTransform,
      _secHgrTransform, _tocTransform, _towerTransform,
    ]) { t?.position.x += abX; }
    _airbasePairs = [
      if (_apronMesh    != null && _apronTransform    != null) (_apronMesh!,    _apronTransform!),
      if (_mainHgrMesh  != null && _mainHgrTransform  != null) (_mainHgrMesh!,  _mainHgrTransform!),
      if (_secHgrMesh   != null && _secHgrTransform   != null) (_secHgrMesh!,   _secHgrTransform!),
      if (_tocMesh      != null && _tocTransform      != null) (_tocMesh!,      _tocTransform!),
      if (_towerMesh    != null && _towerTransform    != null) (_towerMesh!,    _towerTransform!),
    ];

    _treeSystem.generate(seed: 42);
    _treeRenderer.prebuild(_treeSystem); // avoids first-frame blocking rebuild
    _treeSnapshotCache = _treeSystem.treeSnapshot();
    _tanker = TankerAircraft();
    final _ibo = Vector3.copy(_state.playerPosition);
    final _ibd = Vector3(0.0, 0.0, 1.0);
    _allEmitters = [
      IceBreathEmitter(origin: _ibo,              direction: _ibd),
      IceBreathDragonEmitter(origin: Vector3.copy(_ibo), direction: Vector3.copy(_ibd)),
      IceBreathFlamethrowerEmitter(origin: Vector3.copy(_ibo), direction: Vector3.copy(_ibd)),
      IceBreathStormEmitter(origin: Vector3.copy(_ibo), direction: Vector3.copy(_ibd)),
    ];
    _rebuildAircraftScene();
    for (final ab in _state.abilities) {
      final key = _colorKey(ab.color);
      _effectMeshCache[key] ??= Mesh.cube(size: 1.0, color: ab.color);
    }
    _wyvernMesh = Mesh.cube(size: 2.5, color: Vector3(1.0, 0.25, 0.05));
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
    if (_terrain != null && _renderer != null) {
      for (final m in _terrain!.drainRemovedMeshes()) {
        _renderer!.deleteMeshBuffers(m);
      }
    }
    _state.windState.update(dt);
    AbilitySystem.update(_state, dt);
    WyvernSystem.tick(_state, dt);
    _tickFireSystem(dt);
    _tickTrees(dt);
    _cloudSystem.tick(dt, _state.windState.windVector3, _state.playerPosition);
    _tickCloudTurbulence(dt);
    _state.tickAirbaseThreat(dt);
    _checkMissionCompletion();
    if (_state.rtbActive && !_state.autopilotEnabled) _state.rtbActive = false;
    _tickTankerAndProbe(dt);
    _syncAircraftSceneGraph(dt);
    _renderFrame(dt);
    _scheduleHudRebuild();
    writeGameStateBridge(_state, _frameCount++);

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

    // Ice breath: update nose position/direction and tick emitter while held.
    if (_iceBreathActive) {
      final yaw  = _state.playerRotation.y * math.pi / 180.0;
      final pit  = _state.flightPitchAngle  * math.pi / 180.0;
      final cosP = math.cos(pit);
      _iceBreathFwdScratch.setValues(-math.sin(yaw) * cosP, math.sin(pit), -math.cos(yaw) * cosP);
      _iceBreathFwdScratch.normalize();
      _iceBreathEmitter
        ..origin.setFrom(_state.playerPosition + _iceBreathFwdScratch.scaled(2.5))
        ..direction.setFrom(_iceBreathFwdScratch);
      _iceBreathEmitter.tick(_fireSystem.particles, dt, _state.apparentWind);
    }

    _fireSystem.tick(_state, dt, TerrainGenerator.heightAt);
    _state.tickAutoSuppress(dt);
    _updateSmokeOpacity(dt);

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

  // ── Cloud turbulence ──────────────────────────────────────────────────────

  void _tickCloudTurbulence(double dt) {
    _cloudOverlayOpacity = _cloudSystem.flyThroughOpacity;
    if (_cloudSystem.isInCB(_state.playerPosition)) {
      // CB turbulence: sinusoidal vertical jitter on the aircraft.
      _state.playerPosition.y +=
          0.45 * math.sin(_gameTime * 11.3 + _state.playerPosition.x) * dt;
    }
  }

  // ── Smoke density ─────────────────────────────────────────────────────────

  void _updateSmokeOpacity(double dt) {
    double raw = 0.0;
    final pp = _state.playerPosition;
    final fs = _fireSystem;

    for (int i = 0; i < GameState.firePositions.length; i++) {
      if (_state.fireExtinguished[i]) continue;
      final (fx, fz) = GameState.firePositions[i];
      final dx = pp.x - fx, dz = pp.z - fz;
      final hDist = math.sqrt(dx * dx + dz * dz);
      final smokeR = fs.zoneRadius(i) * fs.smokeRadiusMult;
      if (hDist >= smokeR) continue;
      // Horizontal: squared falloff so density drops sharply away from the zone.
      final hf = math.pow(1.0 - hDist / smokeR, 1.5) as double;
      // Vertical: rises from ground, peak at smokePeakAlt, fades to zero at smokeTopAlt.
      final alt = pp.y;
      final vf  = alt < 3.0
          ? alt / 3.0
          : alt > fs.smokeTopAlt
              ? 0.0
              : alt <= fs.smokePeakAlt
                  ? 1.0
                  : 1.0 - (alt - fs.smokePeakAlt) / (fs.smokeTopAlt - fs.smokePeakAlt);
      raw += hf * vf.clamp(0.0, 1.0);
    }
    raw += _treeEmitters.length * fs.treeContrib;

    final target = raw.clamp(0.0, 1.0);
    final rate   = target > _state.smokeOpacity ? fs.smokeRiseRate : fs.smokeClearRate;
    _state.smokeOpacity =
        (_state.smokeOpacity + (target - _state.smokeOpacity) * rate * dt)
            .clamp(0.0, 1.0);
  }

  // ── Mission completion ────────────────────────────────────────────────────

  void _checkMissionCompletion() {
    if (_state.missions.status != MissionStatus.active) return;
    if (!_state.missions.isComplete(_state.fireExtinguished)) return;
    final rp = _state.missions.active?.rpReward ?? 0;
    _state.earnResearchPoints(rp);
    _state.missions.status = MissionStatus.complete;
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

    // Aircraft–tree collision: contact ignites the tree and applies crash damage.
    if (_state.gameMode != GameMode.taxi) {
      final hit = _treeSystem.checkAircraftCollision(
          _state.playerPosition.x, _state.playerPosition.y, _state.playerPosition.z);
      if (hit != null && hit.state == TreeState.alive) {
        _treeSystem.igniteTree(hit);
        _state.takeDamage(_state.cfgCrashDamageRate * 0.3 * dt);
      }
    }

    const slotActions = [
      GameAction.actionBar1, GameAction.actionBar2, GameAction.actionBar3,
      GameAction.actionBar4, GameAction.actionBar5, GameAction.actionBar6,
      GameAction.actionBar7, GameAction.actionBar8, GameAction.actionBar9,
      GameAction.actionBar10,
    ];

    // Slot 0 (key "1"): Ice Breath — hold for sustained beam, no cooldown.
    final iceHeld = InputSystem.isActionActive(slotActions[0]);
    if (iceHeld && _state.mana > 0) {
      if (!_iceBreathActive) {
        _iceBreathActive = true;
        _iceBreathEmitter.startBreath();
      }
      _state.spendMana(_iceBreathManaDrain * dt);
      _iceBreathSupprTimer -= dt;
      if (_iceBreathSupprTimer <= 0) {
        _iceBreathSupprTimer = 0.5;
        _state.suppressFiresInRadius(28.0 * _iceBreathEmitter.rangeScale);
        _treeSystem.suppressInRadius(_state.playerPosition, 18.0 * math.min(_iceBreathEmitter.rangeScale, 3.0));
        // Damage wyverns in beam range — damageTick=false so WyvernSystem picks it up
        AbilitySystem.activeEffects.add(VisualEffect(
          position: Vector3.copy(_state.playerPosition),
          color:    Vector3(0.0, 0.3, 1.0),
          lifetime: 0.4,
        )..emitted = true); // emitted=true skips the particle burst (IceBreathEmitter owns visuals)
      }
    } else if (_iceBreathActive) {
      _iceBreathActive = false;
      _iceBreathEmitter.stopBreath();
    }
    _prevAbilityKeys[0] = iceHeld;

    // Slots 1–9: normal edge-detect activation.
    for (int i = 1; i < slotActions.length; i++) {
      final pressed = InputSystem.isActionActive(slotActions[i]);
      if (pressed && !_prevAbilityKeys[i]) {
        final fired = AbilitySystem.activateAbility(_state, i);
        if (fired != null) _applyAbilityTreeEffect(fired);
      }
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

    final probeNow = InputSystem.isActionActive(GameAction.toggleProbe);
    if (probeNow && !_prevToggleProbe) setState(() => _state.triggerProbe());
    _prevToggleProbe = probeNow;

    final drogueNow = InputSystem.isActionActive(GameAction.toggleDrogue);
    if (drogueNow && !_prevToggleDrogue) setState(() => _state.triggerDrogue());
    _prevToggleDrogue = drogueNow;

    final cycleNow = InputSystem.isActionActive(GameAction.cycleTarget);
    if (cycleNow && !_prevCycleTarget) _state.cycleTarget();
    _prevCycleTarget = cycleNow;

    final cycleFriendlyNow = InputSystem.isActionActive(GameAction.cycleFriendlyTarget);
    if (cycleFriendlyNow && !_prevCycleFriendlyTarget) _state.cycleFriendlyTarget();
    _prevCycleFriendlyTarget = cycleFriendlyNow;
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

  // ── Tanker orbit + probe animation ────────────────────────────────────────

  void _emitRadio(String msg) {
    if (!mounted) return;
    setState(() { _state.chatHistory.add(('assistant', msg, _nowHHMM())); });
  }

  void _tickTankerAndProbe(double dt) {
    _tanker.tick(dt);
    _state.tankerPosition = (_tanker.position.x, _tanker.position.y, _tanker.position.z);
    RadioSystem.tick(_state, _tanker.crossedWaypoint, _tanker.crossNorthbound, dt, _emitRadio);

    // Probe deploy / retract animation
    final rate = 1.0 / _probeTransitTime;
    if (_state.probeTargetOut) {
      _state.probeProgress = (_state.probeProgress + rate * dt).clamp(0.0, 1.0);
      if (_state.probeProgress >= 1.0) {
        _state.probeMoving   = false;
        _state.probeDeployed = true;
      }
    } else {
      _state.probeProgress = (_state.probeProgress - rate * dt).clamp(0.0, 1.0);
      if (_state.probeProgress <= 0.0) {
        _state.probeMoving    = false;
        _state.probeDeployed  = false;
        _state.probeConnected = false;
      }
    }

    // Probe connection: tip must reach the drogue basket within 3.5 world units.
    // Probe tip in aircraft local space: (0, 0, -(2.0 + probeProgress*1.5 + 1.5))
    // World: apply yaw-only rotation (level flight assumption).
    if (_state.aircraftId == 'icefighter') {
      final yawRad = _state.playerRotation.y * math.pi / 180.0;
      final lz     = -(3.5 + _state.probeProgress * 1.5);
      final tipX   = _state.playerPosition.x + math.sin(yawRad) * lz;
      final tipZ   = _state.playerPosition.z + math.cos(yawRad) * lz;
      final tipY   = _state.playerPosition.y;
      final drogue = _tanker.drogueWorldPos;
      final dx = tipX - drogue.x;
      final dy = tipY - drogue.y;
      final dz = tipZ - drogue.z;
      _state.probeConnected =
          _state.probeProgress >= 0.99 && (dx*dx + dy*dy + dz*dz) < 12.25; // 3.5² = 12.25
      if (_state.probeConnected) {
        _state.restoreMana(_state.cfgManaFillRate * dt);
        if (_state.gameMode == GameMode.flight || _state.gameMode == GameMode.landing) {
          _state.gameMode = GameMode.manaTanking;
        }
      } else if (_state.gameMode == GameMode.manaTanking) {
        _state.gameMode = GameMode.flight;
      }
    }

    // Drogue deploy / retract animation (SkyTanker)
    if (_state.aircraftId == 'skytanker') {
      if (_state.drogueTargetOut) {
        _state.drogueProgress = (_state.drogueProgress + rate * dt).clamp(0.0, 1.0);
        if (_state.drogueProgress >= 1.0) {
          _state.drogueMoving   = false;
          _state.drogueDeployed = true;
        }
      } else {
        _state.drogueProgress = (_state.drogueProgress - rate * dt).clamp(0.0, 1.0);
        if (_state.drogueProgress <= 0.0) {
          _state.drogueMoving    = false;
          _state.drogueDeployed  = false;
          _state.drogueConnected = false;
        }
      }
    }
  }

  // ── Mode transitions ──────────────────────────────────────────────────────

  void _checkModeTransitions() {
    switch (_state.gameMode) {
      case GameMode.taxi:
        if (_state.groundSpeed >= _state.cfgLiftoffSpeed) {
          _state.gameMode    = GameMode.flight;
          _state.flightSpeed = _state.groundSpeed;
          debugPrint('[Game] Liftoff → FLIGHT');
        }
      case GameMode.landing:
        // Gear retracted mid-approach → abort, return to flight
        if (!_state.gearDeployed && !_state.gearMoving) {
          _state.gameMode = GameMode.flight;
          debugPrint('[Game] Gear up → FLIGHT (abort approach)');
          break;
        }
        final lndH       = _state.terrainHeight;
        final touchFloor = math.max(lndH, 0.5);
        if (_state.playerPosition.y <= touchFloor + 0.1 && lndH < 0.6) {
          final sinkRate = -_state.verticalSpeed;
          final bankAbs  = _state.flightBankAngle.abs();
          final crash    = sinkRate > _state.cfgLandingSinkRateCrash ||
                           bankAbs  > _state.cfgLandingMaxBankDeg;
          if (crash && !_state.gameOver) {
            final reason = sinkRate > _state.cfgLandingSinkRateCrash
                ? 'HARD LANDING — SINK RATE ${sinkRate.toStringAsFixed(1)} U/S'
                : 'RUNWAY EXCURSION — BANK ${bankAbs.toStringAsFixed(0)}°';
            setState(() => _state.triggerGameOver(reason));
          } else if (!_state.gameOver) {
            _state.playerPosition.y = touchFloor;
            _state.gameMode         = GameMode.taxi;
            _state.groundSpeed      = _state.flightSpeed;
            _state.throttle = _state.flightPitchAngle = _state.flightBankAngle = 0.0;
            _state.gearTargetDown = _state.gearDeployed = true;
            _state.gearProgress   = 1.0;
            _state.gearMoving     = false;
            debugPrint('[Game] Touchdown → TAXI  sink=${sinkRate.toStringAsFixed(2)} bank=${bankAbs.toStringAsFixed(1)}°');
          }
        }
      case GameMode.flight:
        // Gear deployed → enter landing mode
        if (_state.gearDeployed && !_state.gearMoving) {
          _state.gameMode = GameMode.landing;
          debugPrint('[Game] Gear down → LANDING');
        }
      case GameMode.manaTanking:
        break; // physics unchanged; mode reverts to flight when probe disconnects
    }
  }

  // ── Aircraft scene graph sync ─────────────────────────────────────────────

  void _syncAircraftSceneGraph(double dt) {
    final root = _aircraftRoot;
    if (root == null) return;
    _animator.update(root, _aircraftParts, _state, dt);
  }

  // ── WebGL rendering ───────────────────────────────────────────────────────

  void _renderFrame(double dt) {
    final cw = (_canvas?.clientWidth  ?? 1600).toDouble();
    final ch = (_canvas?.clientHeight ?? 900).toDouble();
    _state.windState.updateStreaks(dt, cw, ch, _state.playerRotation.y);

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

    final cwi = cw.toInt(), chi = ch.toInt();
    if (cwi > 0 && chi > 0 && (cwi != _lastCanvasW || chi != _lastCanvasH)) {
      camera.aspectRatio = cw / ch;
      renderer.resize(cwi, chi);
      renderer.heatDistortion.resize(cwi, chi);
      _lastCanvasW = cwi;
      _lastCanvasH = chi;
    }

    renderer.updateSmoke(_settings.disableHaze ? 0.0 : _state.smokeOpacity);

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
    if (_lakeMesh != null && _lakeTransform != null) {
      renderer.render(_lakeMesh!, _lakeTransform!, camera);
    }
    // Airbase buildings (pre-built at scene init — no allocation per frame)
    for (final (mesh, transform) in _airbasePairs) {
      renderer.render(mesh, transform, camera);
    }
    if (_state.viewMode != ViewMode.cockpit && _aircraftRoot != null) {
      renderer.renderSceneGraph(_aircraftRoot!, camera);
    }

    // Tanker ART-9 + drogue basket
    renderer.render(_tanker.bodyMesh,   _tanker.transform,       camera);
    renderer.render(_tanker.basketMesh, _tanker.basketTransform, camera);

    // Wyvern entities — orange cubes scaled by health (shrink as damaged).
    for (final w in _state.wyverns) {
      final s = w.isDying
          ? (0.5 + w.healthFraction).clamp(0.1, 1.0)
          : (0.7 + w.healthFraction * 0.3);
      _effectTransform.position.setFrom(w.position);
      _effectTransform.scale.setValues(s * 2.5, s * 2.5, s * 2.5);
      renderer.render(_wyvernMesh, _effectTransform, camera);
    }

    // Cube ability effects (kept for HUD feedback; particles play on top).
    for (final effect in AbilitySystem.activeEffects) {
      final sz  = 0.5 * effect.scale.clamp(0.2, 4.0);
      final key = _colorKey(effect.color);
      final em  = _effectMeshCache[key]
          ?? (_effectMeshCache[key] = Mesh.cube(size: 1.0, color: effect.color));
      _effectTransform.position.setFrom(effect.position);
      _effectTransform.scale.setValues(sz, sz, sz);
      renderer.render(em, _effectTransform, camera);
    }

    // Trees (batched: alive / burning / charred).
    _treeRenderer.render(renderer, _treeSystem, camera);

    // Atmospheric smoke plumes — far-field macro billboards rendered before
    // close-range particles so near particles composite on top.
    renderer.renderAtmosphericSmoke(
        _fireSystem.atmosphericSmokeBillboards(camera.position), camera);

    // Particle layer (fire, smoke, ability bursts).
    renderer.renderParticles(_fireSystem.particles.particles, camera);

    // Cloud billboards — rendered last among 3D objects (above smoke).
    renderer.renderClouds(_cloudSystem.chunks, camera);

    // Pass 2: blit FBO to screen with heat distortion.
    if (useHeat) renderer.endHeatPass(_heatIntensity);
  }

  // ── Tree system ───────────────────────────────────────────────────────────

  void _tickTrees(double dt) {
    final wasDirty = _treeSystem.dirty;
    _treeSystem.update(dt, _state.windState.windVector3);
    if (wasDirty || _treeSystem.dirty) {
      _treeSnapshotCache = _treeSystem.treeSnapshot();
    }

    for (final id in _treeSystem.newlyBurningIds) {
      if (_treeEmitters.containsKey(id)) continue;
      final t = _treeSystem.trees[id];
      _treeEmitters[id] = FireEmitter(
        worldX: t.wx, worldZ: t.wz,
        radius: t.canopyRadius * 0.7,
        intensity: 1.0,
      )..emitRate = 30.0;
    }
    _treeSystem.newlyBurningIds.clear();

    for (final id in _treeSystem.newlyCharredIds) {
      _treeEmitters.remove(id);
    }
    _treeSystem.newlyCharredIds.clear();

    final wind = _state.windState.windVector3;
    for (final entry in _treeEmitters.entries) {
      final t = _treeSystem.trees[entry.key];
      entry.value.tick(
          _fireSystem.particles, dt, t.wy, wind);
    }
  }

  /// Project a world position to a Flutter screen-space [Offset].
  /// Returns null if behind the camera; out-of-bounds values are returned as-is
  /// so the HUD can clamp them to the screen edge for the off-screen indicator.
  Offset? _project(double wx, double wy, double wz) {
    final cam = _camera;
    if (cam == null || _lastCanvasW == 0) return null;
    final r = cam.worldToScreen(
        Vector3(wx, wy, wz), _lastCanvasW.toDouble(), _lastCanvasH.toDouble());
    return r == null ? null : Offset(r.$1, r.$2);
  }

  void _applyAbilityTreeEffect(AbilityData fired) {
    if (fired.suppressRadius != null) {
      // Ice / cryo suppression: extinguish burning trees nearby.
      _treeSystem.suppressInRadius(_state.playerPosition, fired.suppressRadius!);
    } else if (fired.color.r > 0.6 && fired.color.g < 0.6) {
      // Fire ability: ignite trees in range.
      _treeSystem.igniteInRadius(_state.playerPosition, 14.0);
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
          WindParticleOverlay(state: _state),
          if (!_settings.disableHaze) SmokeOverlay(state: _state),
          if (_cloudOverlayOpacity > 0.01)
            IgnorePointer(
              child: Container(
                color: const Color(0xFFDDE8F0).withValues(alpha: _cloudOverlayOpacity),
              ),
            ),
          // World-space target brackets — only meaningful in 3rd-person view.
          Builder(builder: (ctx) {
            final hostile  = _state.viewMode == ViewMode.thirdPerson ? _state.currentTarget         : null;
            final friendly = _state.viewMode == ViewMode.thirdPerson ? _state.currentFriendlyTarget : null;
            final sw = _lastCanvasW.toDouble(), sh = _lastCanvasH.toDouble();
            return cockpit.buildCockpitHud(
            _state,
            showAnnunciator: _settings.showAnnunciator,
            showTelemetry:   _settings.showTelemetry,
            showActionBar:   _settings.showActionBar,
            showTutorial:    _settings.showTutorial,
            settings:        _settings,
            onLayoutChanged: () { _settings.save(); setState(() {}); },
            hostileScreenPos:  hostile  != null ? _project(hostile.wx,  hostile.wy,  hostile.wz)  : null,
            friendlyScreenPos: friendly != null ? _project(friendly.wx, friendly.wy, friendly.wz) : null,
            screenW: sw, screenH: sh,
            onAbilityActivate: (i) {
              final fired = AbilitySystem.activateAbility(_state, i);
              if (fired != null) _applyAbilityTreeEffect(fired);
            },
            onLeftPage:   (p) => setState(() => _state.leftMfdPage  = p),
            onRightPage:  (p) => setState(() => _state.rightMfdPage = p),
            onMapZoom:      ()  => setState(() => _state.mapZoom = (_state.mapZoom + 1) % 7),
            onZoomDelta:    (d) => setState(() => _state.mapZoom = (_state.mapZoom + d).clamp(0, 6)),
            onGearToggle:   ()  => setState(() => _state.triggerGear()),
            onFlapsToggle:  ()  => setState(() => _state.cycleFlaps()),
            onProbeToggle:  ()  => setState(() => _state.triggerProbe()),
            onDrogueToggle: ()  => setState(() => _state.triggerDrogue()),
            onAutopilot:    ()  => setState(() => _state.toggleAutopilot()),
            onWaypointLock: ()  => setState(() => _state.toggleTargetIntercept()),
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
            onOrientToggle:      ()  => setState(() => _state.toggleMapOrientation()),
            onLvrToggle:         ()  => setState(() => _state.toggleLvr()),
            onToggleNavSidebar:  ()  => setState(() => _state.toggleNavSidebar()),
            onToggleFireHeatmap: ()  => setState(() => _state.toggleNavFireHeatmap()),
            onToggleTreeHeatmap: ()  => setState(() => _state.toggleNavTreeHeatmap()),
            onToggleNavLabels:   ()  => setState(() => _state.toggleNavLabels()),
            treeSnapshot:        _treeSnapshotCache,
            onChatWaypointTap: (name, wx, wz) =>
                setState(() => _state.setNavFromChat(name, wx, wz)),
            onChatEntityTap: (id) =>
                setState(() => _state.selectEntityFromChat(id)),
            onSlot1Scroll: (delta) => setState(() {
              if (_iceBreathActive) _iceBreathEmitter.stopBreath();
              _state.iceBreathVariant =
                  (_state.iceBreathVariant + delta + _allEmitters.length) %
                  _allEmitters.length;
              if (_iceBreathActive) _iceBreathEmitter.startBreath();
            }),
          );
          }),  // Builder

          Positioned(
            top: 12, right: 12,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              cockpit.buildStatusBadgeRow(_state, disableHaze: _settings.disableHaze),
              const SizedBox(width: 8),
              _menuButton('⊞ HANGAR',   _showHangar,   () { setState(() { _showHangar   = !_showHangar;  _showSettings = false; _showMission = false; }); }),
              _menuButton('⚡ TOC',     _showMission,  () { setState(() { _showMission  = !_showMission; _showHangar   = false;  _showSettings = false; }); }),
              _menuButton('⚙ SETTINGS', _showSettings, () { setState(() { _showSettings = !_showSettings; _showHangar  = false; _showMission  = false; }); }),
            ]),
          ),

          if (_showSettings)
            Positioned(
              top: 44, right: 12,
              child: SettingsPanel(
                settings:      _settings,
                onClose:       () => setState(() => _showSettings = false),
                onChanged:     _onSettingChanged,
                onKeyboardMap: () => setState(() => _showKeyboardMap = true),
              ),
            ),

          if (_showKeyboardMap)
            KeyboardMapOverlay(onClose: () => setState(() => _showKeyboardMap = false)),

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

          if (_showMission)
            Positioned.fill(child: buildMissionScreen(
              _state,
              onClose:         () => setState(() => _showMission = false),
              onDispatch:      (id) => setState(() => _state.missions.dispatch(id)),
              onRTB:           () => setState(() => _state.activateRTB()),
              onCancelMission: () => setState(() => _state.missions.cancel()),
            )),

          if (_state.gameOver)
            Positioned.fill(child: GameOverOverlay(
              reason:    _state.gameOverReason,
              onRestart: () => setState(() => _state.resetGameOver()),
            )),
        ],
      ),
    );
  }
}
