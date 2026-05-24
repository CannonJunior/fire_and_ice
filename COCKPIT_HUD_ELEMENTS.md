# Cockpit HUD Elements — Registration Guide

Every cockpit UI element must be wired up in **three places** so that it gains Settings-panel visibility toggle, draggability, and persistent layout offset. Missing any step leaves the element partially broken.

---

## The Four-Step Checklist

### 1. Add to `settings_panel.dart` — `_kElements`

```dart
// fire_and_ice_game/lib/game/settings_panel.dart  ~line 201
static const _kElements = [
  ('leftMfd',      'Left MFD'),
  ('annunciator',  'Annunciator'),
  ('centerMfd',    'Centre MFD'),
  ('suppression',  'Suppression'),
  ('flaps',        'Flaps'),
  ('gear',         'Gear'),
  ('probe',        'Refuel Probe'),
  ('throttle',     'Throttle'),
  ('tq',           'Throttle Quad'),
  ('alt',          'Altimeter'),
  ('aoa',          'AoA Indicator'),
  ('attitudeGyro', 'Attitude Gyro'),
  ('fireProx',     'Fire Proximity'),
  ('manaArc',      'Mana Arc'),
  ('rightMfd',     'Right MFD'),
  ('auxDisp',      'Aux Display'),
  // ← add new elements here; tuple = (elementKey, settingsLabel)
];
```

The `_cockpitElementsBody()` method automatically renders a toggle switch for every entry. No other changes needed in this file.

### 2. Wrap in `cockpit_hud.dart` — `keep(vis(key), drag(key, label, child))`

Inside `_cockpitPanel()` place the widget using the exact same key string:

```dart
keep(vis('myElement'), Row(mainAxisSize: MainAxisSize.min, children: [
  const SizedBox(width: 8),                          // gap from neighbour
  drag('myElement', 'My Display Name', buildMyWidget(state)),
])),
```

- **`vis(key)`** — reads `settings.elementVisible(key)` (defaults `true`).
- **`keep(bool, child)`** — resolves to `show ? child : SizedBox.shrink()`. When `false`, removes the child entirely from the tree so `CockpitDragGroup.dispose()` tears down the OverlayEntry. **Do NOT use `Visibility(maintainSize/maintainState: true)` here** — that keeps the overlay alive and breaks the Settings toggle.
- **`drag(key, label, child)`** — wraps in `CockpitDragGroup`; loads/saves per-aircraft drag offset automatically.

### 3. No changes needed in `settings_state.dart`

`elementVisible(key)` defaults to `true` for any unknown key.
`cockpitOffset(aircraftId, elementId)` defaults to `(0.0, 0.0)` for any unknown key.
Both are persisted automatically via SharedPreferences.

**Resetting a position:** `resetElementOffset(aircraftId, elementId)` removes one element's stored offset so it returns to its natural layout slot. The Settings → Cockpit Elements list shows a ↺ button per element. "Restore Defaults" (via `resetCockpitLayout`) wipes all offsets for the aircraft.

### 4. Key naming rules

- Must be **identical** across all three usages: `_kElements` tuple, `vis('key')`, `drag('key', …)`.
- Use lowerCamelCase, no spaces, no hyphens.
- The key becomes a SharedPreferences JSON key — treat it as permanent once shipped.

---

## Circular Instrument Style (AoA / FPS / ManaArc pattern)

All three circular dial instruments follow this exact spec:

| Property | Value |
|---|---|
| Widget size | `SizedBox(width: 120, height: 120)` inside a `Column` |
| Header label | `Padding(left: 4, bottom: 2)` — `fontSize: 8, letterSpacing: 1.5, color: kIceShelf` |
| Canvas center | `cx = width/2`, `cy = height/2` (no offset) |
| Radius | `r = width/2 - 5.0` → **55 px** |
| Background | `RadialGradient([0xFF0D1F35, 0xFF080C14])` drawn as filled circle at `r` |
| Outer border | `kIceShelf` (0xFF1C3D5A), `PaintingStyle.stroke`, `strokeWidth: 1.5` drawn last |
| Range rings (optional) | Two circles at `r * 0.33` and `r * 0.66`, `kIceShelf` 0.3 alpha, 0.5 px stroke |

```dart
// Minimum paint() scaffold for a new circular instrument
void paint(Canvas canvas, Size size) {
  final cx = size.width  / 2;
  final cy = size.height / 2;
  final r  = size.width  / 2 - 5.0;

  // Background
  canvas.drawCircle(Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [const Color(0xFF0D1F35), const Color(0xFF080C14)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

  // ... instrument-specific drawing here ...

  // Outer border — always last
  canvas.drawCircle(Offset(cx, cy), r,
      Paint()..color = kIceShelf..style = PaintingStyle.stroke..strokeWidth = 1.5);
}
```

Import `hud_gauges.dart` for `kIceShelf` and other shared palette constants.

---

## Architecture Notes

- `CockpitDragGroup` (in `hud_widgets.dart`) stores offsets in `SettingsState.cockpitLayouts[aircraftId][elementId]` and calls `onOffsetChanged` on every drag end.
- Visibility and offsets are each serialised to their own SharedPreferences key (`${prefix}elementVisible` and `${prefix}cockpitLayouts`).
- The `keep()` helper is local to `_cockpitPanel()` — do not use `Visibility` directly, as `keep()` also sets `maintainAnimation` and `maintainState`.
