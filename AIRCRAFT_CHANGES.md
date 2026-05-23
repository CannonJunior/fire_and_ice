# Aircraft Changes

Record of modifications to aircraft configurations, cockpit layouts, and related defaults.

---

## 2026-05-23

### Leviathan ART-9 tanker + IceFighter refueling probe

#### Tanker aircraft — Leviathan ART-9 Atmospheric Replenishment Transport

- **New file**: `lib/rendering/tanker_aircraft.dart` — `TankerAircraft` class
- Sci-fi/anime C-130-inspired design: long midnight-blue fuselage, high-mounted straight wings, four engine nacelles in pairs, twin vertical tail fins, glowing cyan belly retardant pod
- Flies a **left-hand racetrack orbit** at **100 AGL** over the airbase complex (X ≈ −45 to +35, Z ≈ −15 to −95) at 2.8 world units/sec
- Trails a rust-colored drogue hose with a **bright orange basket** (Mesh.cube, 0.55 units)
- `drogueWorldPos` getter exposes basket world position for IceFighter probe docking
- Rendered each frame in `game_widget.dart` (body + basket as separate meshes)

#### IceFighter refueling probe

- `lib/rendering/aircraft_builder.dart` — probe `SceneNode` added to `_buildIceFighter()`; `Mesh.strut(length: 1.5, radius: 0.05)` rotated +π/2 around X so it extends forward (−Z)
- `lib/rendering/aircraft_animator.dart` — animates `probe` node: `visible = probeProgress > 0.04`, `position.z` slides outward as `probeProgress` increases 0→1
- `lib/game/game_state.dart` — added `probeDeployed`, `probeMoving`, `probeTargetOut`, `probeProgress`, `probeConnected` fields; `triggerProbe()` method
- `lib/models/game_action.dart` — added `toggleProbe` action
- `lib/systems/input_system.dart` — mapped `toggleProbe` to key **P**
- `lib/game/game_widget.dart` — `_tickTankerAndProbe()` drives probe animation (2.5 s transit), checks probe-tip → drogue distance (≤ 3.5 units) for connection; connected state restores **10 mana/sec**

#### Cockpit UI — PROB lever

- `lib/game/gear_lever.dart` — `buildProbeLever` widget and `_ProbeLeverPainter` added
- Handle is an **oval** (`RRect`, 30 × 16 px with 7 px corner radius) distinguishing it from the circular gear knob
- States: **RET** (cyan `#00CFFF`) → **MOVE** (amber `#FFAA00`) → **OUT** (pale blue `#AADDFF`) → **CONN** (green `#00CC44`)
- `lib/game/cockpit_hud.dart` — `onProbeToggle` callback threaded through; probe lever rendered immediately right of the Gear lever, IceFighter-only
- `lib/game/game_widget.dart` — `onProbeToggle` wired to `_state.triggerProbe()`

---

## 2026-05-12

### Default aircraft changed to IceFighter

- **IceFighter** (`icefighter`) added to the aircraft catalogue as the first entry and set as the default selected aircraft.
- **IceFighter** is now position #1 in the selection list; FireHawk moves to position #2.
- `settings_state.dart` — `selectedAircraft` default changed from `'firefighter'` to `'icefighter'`.

#### IceFighter specification

| Field         | Value |
|---------------|-------|
| ID            | `icefighter` |
| Display name  | IceFighter |
| Icon          | ❄️ |
| Role          | Elemental |
| Unlock RP     | 0 (available from start) |
| Speed         | 0.80 |
| Maneuverability | 0.90 |
| Payload       | 0.40 |
| Durability    | 0.70 |
| Climb rate    | 0.85 |
| Airframe slots | 22 |
| Systems slots | 32 |
| Payload slots | 16 |

**Design notes:** Ice-elemental interceptor optimised for agility and ability amplification over raw payload capacity. High systems slots reflect the emphasis on elemental avionics upgrades.

---

### Flaps lever added to cockpit panel

- `buildFlapsLever` widget added to `gear_lever.dart`.
- Lever placed immediately **left of the landing gear lever** in the centre cockpit column.
- Four detent positions: **UP · T/O · APPR · FULL**, colour-coded cyan → green → amber → red.
- Positioned as a **standalone lever** between the left MFD column and the centre console, directly to the visual left of the landing gear lever.
- Defaults to **FULL (down)** on game start.
- `flapsLevel: int = 3` field and `cycleFlaps()` method added to `GameState`.
- Activated by clicking the lever in cockpit view.

---

## 2026-05-19

### Fire proximity sensor updated with wyvern contact display

- `lib/game/hud_gauges.dart` — `FireProximitySensor` and `_FpsPainter` updated.
- Living fire wyverns now appear as **orange hostile triangles** on the FIRE PROX radar display.
- Triangle colour lerps from red (healthy) to amber (damaged) based on wyvern health fraction.
- Player remains white diamond at radar centre; radar range is 120 world units (configurable via `wyvern.radarRange` in `flight_config.json`).

---

## Template for future entries

```
## YYYY-MM-DD

### <Change title>

- File(s) changed: `path/to/file.dart`
- What changed and why.

#### Aircraft specification (if new aircraft)

| Field | Value |
|-------|-------|
| ...   | ...   |
```
