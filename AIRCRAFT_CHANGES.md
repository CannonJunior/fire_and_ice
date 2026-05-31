# Aircraft Changes

Record of modifications to aircraft configurations, cockpit layouts, and related defaults.

---

## 2026-05-30 — Drogue lever + per-aircraft cockpit visibility

### Drogue basket lever

- **New file**: `lib/game/drogue_lever.dart` — `buildDrogueLever` widget and `_DrogueLeverPainter`.
  - Handle is an **oval** (matching the probe lever) to distinguish it from the circular gear knob.
  - States: **RET** (cyan) → **MOVE** (amber) → **OUT** (pale blue) → **CONN** (green).
- `lib/game/cockpit_hud.dart` — drogue lever added to the centre levers row, immediately right of the probe lever.
- `lib/game/game_state.dart` — `drogueProgress`, `drogueDeployed`, `drogueMoving`, `drogueTargetOut`, `drogueConnected` fields; `triggerDrogue()` method.
- `lib/models/game_action.dart` — `toggleDrogue` action.
- `lib/systems/input_system.dart` — `toggleDrogue` mapped to key **O**; `'o'`/`'O'` added to `_maybePreventDefault` game-key set.
- `lib/rendering/aircraft_animator.dart` — animates `drogue` node: visible when `drogueProgress > 0.04`, `position.z` trails backward from tail.

### Per-aircraft cockpit element visibility

- `lib/game/settings_state.dart` — replaced flat `Map<String, bool> cockpitElementVisible` with per-aircraft system:
  - `_defaultHiddenElements` static map: each aircraft ID → set of elements hidden by default.
  - `elementVisible(key)` checks per-aircraft overrides first, then falls back to defaults.
  - localStorage key changed from `fai_elementVisible` to `fai_perAircraftVis`.
- Default hidden elements per aircraft:
  - `icefighter`: drogue
  - `firefighter`: probe, drogue
  - `skytanker`: probe
  - `seabird`: probe, drogue
  - `stormrider`: probe, drogue

### Annunciator panel — smoke / visibility row

- `lib/game/annunciator_panel.dart` — grid expanded from 5×4 to 5×5; Row 4 adds smoke/IMC indicators: SMOK/HAZE, SMOK/LIGHT, SMOK/HEAVY, IMC/COND, VIS/ZERO.
- Panel height increases from 230 → 288 px.

### Test coordinate updates

- `tests/test_cockpit_ui.py` — `LEVERS_Y`, `LVR_LEVER_X`, `THR_GD_TOP`, `THR_TRACK_H`, `TQ_CLICK_Y` updated to match new layout positions after panel height change.
- Suite passes 32/33 (T26 AUX MAP pre-existing failure unchanged).

---

## 2026-05-30 — NPC tanker speed fix + SkyTanker unlocked

### Leviathan ART-9 NPC cruise speed

- `lib/rendering/tanker_aircraft.dart` — `_speed` raised from **2.8 → 8.0** world units/sec.
  - At 2.8 u/s the tanker was flying well below minimum sustainable lift speed (≈ 7.8 u/s for kLift 0.55, mass 1.8).
  - `_legTime` reduced from 120.0 → 42.0 s so the north-leg orbit footprint (≈ 336 units) remains the same.
  - The player IceFighter (cfgFlightSpeed 7.0, boost 10.5) can now approach and dock at the faster tanker speed.

### SkyTanker — player-selectable from start

- `lib/game/aircraft_config.dart` — `_skyTanker.unlockRp` changed from **2000 → 0**.
  - SkyTanker now appears unlocked in the Hangar from the very first session.
  - Aero config unchanged: maxThrust 8.0, kLift 0.55, mass 1.8 — sustains level flight at cfgFlightSpeed 7.0 with throttle ≈ 22 %, AoA ≈ 5.8°, well clear of the 13° stall limit.

---

## 2026-05-24 (Mana Arc redesign — circular gauge, 3-tier color, status lights)

### Mana Arc visual overhaul

- `lib/game/mana_arc.dart` — complete rewrite:
  - Widget structure now matches `buildAoaIndicator`: Column with label header + 120×120 `SizedBox` (no rectangular Container border)
  - 3-tier segment color: annunciator red (`#FF2222`) ≤25%, heat amber 25–50%, glacier blue >50%
  - Tanking override: all filled segments switch to glacier blue when probe connected
  - "100% MANA" centre text removed; status lights repositioned as vertical stack inside arc centre
  - `REDY` label renamed to `RDY`
  - Status lights (IceFighter only): RDY (blue `#0099FF`), FLOW (green `#00CC44`), FULL (amber `#FFAA00`)
- `lib/game/attitude_gyro.dart` — width reduced 360 → 284 px to keep the instrument row within the lever-row width constraint after ManaArc was added
- `lib/game/cockpit_hud.dart` — ManaArc added to instrument row with `keep(vis('manaArc'), ...)`

#### Test updates

- Suite passes 30/31 (T14 pre-existing failure unchanged)

---

## 2026-05-24 (cockpit panel layout fix + Mana Arc repositioning)

### Cockpit panel overflow fix and Mana Arc moved to instrument row

#### Overflow fix

- `lib/game/throttle_quadrant.dart` — `_trackH` reduced 144 → 70 px; saves 74 px from the lever row
- `lib/game/attitude_gyro.dart` — body `SizedBox` height reduced 172 → 100 px; saves 72 px from the instrument row
- Combined savings (146 px) bring the center column from ~1040 px to ~890 px, fitting the 900 px viewport with no overflow

#### Mana Arc repositioning

- `lib/game/cockpit_hud.dart` — `ManaArc` removed from the persistent screen overlays (both cockpit and third-person stacks)
- `ManaArc` added to the instrument row alongside AoA indicator / attitude gyro / fire proximity sensor, wrapped in a dark-bordered cockpit-style `Container` so it matches the other panel instruments
- The arc is now cockpit-view-only (consistent with AoA, not with HullIntegrityArc overlay)
- The `FireProximitySensor` duplicate that existed in both the overlay and the panel row was consolidated to the panel row only

#### Test updates

- `tests/test_cockpit_ui.py` — `THR_TRACK_H` updated 144 → 70; `THR_GD_TOP` updated 610 → 594 to match new TQ position
- Suite now passes 30/31 (T14 ability OSB pre-existing failure unchanged)

---

## 2026-05-23 (mana arc + MANA TANKING mode)

### Mana arc gauge + aerial-refueling mode

#### Cockpit UI — Mana Arc

- **New file**: `lib/game/mana_arc.dart` — `ManaArc` widget and supporting painters
- 270° segmented arc gauge (10 segments, same geometry as HullIntegrityArc) placed bottom-right of screen, immediately left of HullIntegrityArc
- Centre text shows percentage + resource label (default `MANA`; rename via `resourceLabel` param)
- Colour convention (inspired by aviation AR displays): blue fill → amber at 100% → red below 20%
- Pulsing green outer ring while probe is connected (mirrors real "AR contact" status light)
- **Three-light status strip** (shown for IceFighter only — hidden for other aircraft):
  - **REDY** (blue): probe extended and ready to dock
  - **FLOW** (green): probe connected, resource actively flowing
  - **FULL** (amber): resource at maximum capacity
- Gauge persists across cockpit ↔ third-person view toggle (rendered in both IgnorePointer stacks)

#### GameMode — MANA TANKING

- `lib/game/game_state.dart` — added `GameMode.manaTanking` to the `GameMode` enum
- Transitions: `FLIGHT → MANA TANKING` when `probeConnected` becomes true; `MANA TANKING → FLIGHT` when probe disconnects
- `lib/game/cockpit_hud.dart` — mode badge shows `MANA TANKING` in arctic cyan (`#00EEFF`)
- `lib/game/game_widget.dart` — `_checkModeTransitions` extended with `manaTanking` case (flight physics unchanged); `_tickTankerAndProbe` drives mode transitions and uses `cfgManaFillRate`
- RP accrual continues during `manaTanking` (same as flight/landing)

#### Config

- `assets/data/flight_config.json` — added `manaFillRate: 10.0` under `flight` (units/sec)
- `lib/game/game_state.dart` — added `cfgManaFillRate = 10.0`, loaded from JSON; replaces previously hardcoded `10.0` in `_tickTankerAndProbe`

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
