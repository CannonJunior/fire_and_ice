# Aircraft Changes

Record of modifications to aircraft configurations, cockpit layouts, and related defaults.

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
