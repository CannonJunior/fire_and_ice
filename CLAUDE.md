# Fire & Ice - Claude Code Instructions

## Project Overview
Aviation action game with Windwalker flight controls and elemental abilities.
- Language: Dart (Flutter framework), WebGL via dart:html
- Port: ALWAYS 8009
- Entry: fire_and_ice_game/lib/main.dart
- Start: ./start.sh

## Critical Rules
1. Never hardcode tunable values - use JSON configs
2. Max 500 lines per file
3. Character is always in flight - no ground state
4. Config files: config/game_config.json, assets/data/flight_config.json
5. Use dart:html (NOT package:web)
6. All GL constants as hex values (same pattern as Warchief)

## File Map
- lib/main.dart - MaterialApp entry, GameScreen → FireAndIceGame widget
- lib/models/game_action.dart - GameAction enum for input mapping
- lib/data/abilities.dart - AbilityData class + windwalkerAbilities list
- lib/rendering/transform3d.dart - Transform3d: position/rotation/scale, toMatrix()
- lib/rendering/mesh.dart - Mesh class + Mesh.cube() + Mesh.createCharacterMesh()
- lib/rendering/shader_program.dart - ShaderProgram + GLSL shader constants
- lib/rendering/camera3d.dart - Camera3D with rollAngle + third-person follow
- lib/rendering/webgl_renderer.dart - WebGLRenderer using dart:html canvas.getContext3d()
- lib/terrain/terrain_generator.dart - 64x64 heightmap terrain as single Mesh
- lib/game/game_state.dart - GameState: player pos/rot, flight params, abilities, mana/health
- lib/systems/input_system.dart - Static InputSystem: key tracking, isActionActive()
- lib/systems/physics_system.dart - Static PhysicsSystem: full Windwalker flight controls
- lib/systems/ability_system.dart - Static AbilitySystem: cooldowns, activation, visual effects
- lib/game/game_widget.dart - Main game widget: WebGL canvas + HUD overlay + game loop

## Flight System
Controls:
- W: pitch up (climb)
- S: pitch down (dive)
- A: yaw left + bank-enhanced turn
- D: yaw right + bank-enhanced turn
- Q alone: bank left only
- E alone: bank right only
- Q+A together: barrel roll left (360 deg/s continuous)
- E+D together: barrel roll right
- Alt/sprint: 1.5x speed boost
- Space/brake: air brake (slow + upward bump)
- Camera roll follows bank angle for visual feedback

## Aircraft Changes
- All changes to aircraft configurations, cockpit layouts, and defaults MUST be recorded in `AIRCRAFT_CHANGES.md` (project root).
- Default aircraft is **IceFighter** (`icefighter`). Update `settings_state.dart → selectedAircraft` if changing the default.
- Aircraft catalogue order reflects selection-screen display order; IceFighter is always position #1.

## Architecture Notes
- No Riverpod, no Flame - plain Flutter + dart:html WebGL
- Terrain is visual only (no collision system)
- Single mana bar (0-100), drains at 3/sec in flight, regen 5/sec idle
- 10-slot action bar mapped to keys 1-0
- Third-person camera always active with roll following bank angle
