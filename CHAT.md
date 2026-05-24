# Fire & Ice — CHAT System Reference

Describes the Radio Comms panel (AUX page 0), how sender styling works, the full
colour palette, and the step-by-step checklist for adding a new participant.

---

## Architecture

```
RadioSystem.tick() / game_widget.dart
  └─ state.chatHistory.add(('assistant', '[PREFIX] message text', 'HH:MM'))

aux_display.dart  _ChatPageState.build() itemBuilder
  └─ detects prefix → selects { rowBg, callsignClr, msgClr, displayCallsign }
  └─ strips prefix from displayed message text
```

### chatHistory tuple

```dart
List<(String role, String content, String ts)>
// role    : 'user' | 'assistant'
// content : raw message, may start with '[PREFIX] '
// ts      : 'HH:MM' wall-clock string
```

User messages always have role `'user'` and no prefix.
All injected radio calls use role `'assistant'` with a prefix.

---

## Prefix Detection Pattern (aux_display.dart)

```dart
final isUser   = role == 'user';
final isTanker = !isUser && rawMsg.startsWith('[TNKR]');
final isSdo    = !isUser && rawMsg.startsWith('[SDO]');
// … add new participants in the same chain …
final isWings  = !isUser && rawMsg.startsWith('[WNGS]');
```

Strip prefix before display:
```dart
final displayMsg = isTanker ? rawMsg.replaceFirst('[TNKR] ', '')
    : isSdo    ? rawMsg.replaceFirst('[SDO] ', '')
    : rawMsg;
```

Prefixes are plain ASCII, uppercase, inside square brackets, followed by a space:
`[XXXX] message text`.  Keep prefixes ≤ 6 characters (fits inside brackets cleanly).

---

## Participant Colour Specification

The CHAT panel sits on a near-black violet background (`_kABg = 0xFF0E0014`).
Every participant has four values:

| field        | role                                              |
|--------------|---------------------------------------------------|
| `rowBg`      | Container background — dark, hue-tinted           |
| `callsignClr`| Bold callsign label — bright, saturated           |
| `msgClr`     | Message body text — lighter, slightly desaturated |
| `callsign`   | Display string shown to the player, e.g. `[HAWK 2]` |

---

## Existing Participants

### [YOU] — Player
```dart
rowBg       = Colors.transparent
callsignClr = _kADim           // Color(0xFF441166)  deep violet
msgClr      = _kAFg            // Color(0xFFCC88FF)  orchid
callsign    = '[YOU]'
```
*Detected by `role == 'user'`; no prefix in content.*

### [AI] — Ollama assistant
```dart
rowBg       = Colors.transparent
callsignClr = _kAFg            // Color(0xFFCC88FF)  orchid
msgClr      = _kADim           // Color(0xFF441166)  deep violet
callsign    = '[AI]'
```
*Detected by `role == 'assistant'` with no recognised prefix.*

### [LEVIATHAN-01] — ART-9 Tanker        `prefix: [TNKR]`
```dart
rowBg       = Color(0xFF142447)  // midnight blue
callsignClr = Color(0xFF4A8ACC)  // steel blue
msgClr      = Color(0xFFAABBCC)  // pale blue-grey
callsign    = '[LEVIATHAN-01]'
```
*Injected by `RadioSystem` on tanker waypoint crossings and docking events.*

### [BASE HOTSHOT] — Squadron Duty Officer   `prefix: [SDO]`
```dart
rowBg       = Color(0xFF3A0A0A)  // deep red
callsignClr = Color(0xFFCC4444)  // alarm red
msgClr      = Color(0xFFCC8888)  // salmon
callsign    = '[BASE HOTSHOT]'
```
*Injected by `RadioSystem` for mission events, mana warnings, base threat, status.*

---

## Reserved Future Palette

Six pre-designed slots cover the remaining hue wheel.  Implement by:
1. Adding a `startsWith` branch in the detection chain (aux_display.dart).
2. Adding the `emit('[PREFIX] …')` call in `radio_system.dart` (or wherever appropriate).
3. No other files need changes.

---

### [HAWK 2] — Wingman                    `prefix: [WNGS]`
Friendly flight element on the same net.
```dart
rowBg       = Color(0xFF081508)  // dark forest
callsignClr = Color(0xFF44BB33)  // lime-green
msgClr      = Color(0xFF88CC77)  // pale lime
callsign    = '[HAWK 2]'         // or squadron-specific
```

---

### [FALCON GND] — JTAC                   `prefix: [JTAC]`
Joint Terminal Attack Controller / ground forward observer.
```dart
rowBg       = Color(0xFF001A18)  // deep teal
callsignClr = Color(0xFF00BBAA)  // vivid teal
msgClr      = Color(0xFF66DDCC)  // pale cyan
callsign    = '[FALCON GND]'     // or mission-assigned
```

---

### [EAGLE HQ] — Command / AWACS          `prefix: [CMDR]`
High command, mission authority, or AWACS controller.
```dart
rowBg       = Color(0xFF141100)  // dark amber-brown
callsignClr = Color(0xFFDDAA00)  // gold
msgClr      = Color(0xFFEECC66)  // pale amber
callsign    = '[EAGLE HQ]'       // or callsign-assigned
```

---

### [ALPHA TOWER] — Air Traffic Control   `prefix: [TOWR]`
Procedural calls, clearances, airspace management.
```dart
rowBg       = Color(0xFF150800)  // dark burnt-orange
callsignClr = Color(0xFFCC7700)  // amber-orange
msgClr      = Color(0xFFEEAA44)  // pale orange
callsign    = '[ALPHA TOWER]'    // or base name
```

---

### [** INTCPT **] — Hostile Intercept    `prefix: [INTC]`
Enemy transmissions pulled off the air (distinct from SDO's pure-red).
```dart
rowBg       = Color(0xFF1A0800)  // dark orange-brown  ← NOT the same red as SDO
callsignClr = Color(0xFFEE4400)  // ember orange-red
msgClr      = Color(0xFFFF8844)  // salmon-orange
callsign    = '[** INTCPT **]'
```

---

### [** MAYDAY **] — Distress / Emergency `prefix: [DSTR]`
Highest-priority emergency channel — magenta so it cannot be confused with any
other sender.
```dart
rowBg       = Color(0xFF160516)  // dark magenta-black
callsignClr = Color(0xFFFF44EE)  // hot magenta
msgClr      = Color(0xFFDDA0CC)  // pale pink
callsign    = '[** MAYDAY **]'
```

---

## Hue-wheel Summary

| Hue approx. | Participant        | callsignClr  |
|-------------|--------------------|--------------|
| 0°          | SDO (BASE HOTSHOT) | `0xFFCC4444` |
| 20°         | Intercept [INTC]   | `0xFFEE4400` |
| 40°         | Tower [TOWR]       | `0xFFCC7700` |
| 60°         | Command [CMDR]     | `0xFFDDAA00` |
| 120°        | Wingman [WNGS]     | `0xFF44BB33` |
| 180°        | JTAC [JTAC]        | `0xFF00BBAA` |
| 210°        | Tanker (LEVIATHAN) | `0xFF4A8ACC` |
| 260°        | AI / User          | `0xFFCC88FF` |
| 300°        | Distress [DSTR]    | `0xFFFF44EE` |

No two adjacent slots share a hue segment, so all participants remain immediately
distinguishable even in a mixed-traffic scroll.

---

## Checklist: Adding a New Participant

- [ ] **Choose a prefix** from the reserved table above (or define a new one that fits a
      gap in the hue wheel).
- [ ] In `aux_display.dart` `_ChatPageState.build()` itemBuilder, add a `startsWith`
      detection bool in the chain after the existing `isTanker`/`isSdo` lines.
- [ ] Extend the `callsign`, `displayMsg`, `rowBg`, `callsignClr`, `msgClr` switch
      chains with the new branch (follow the exact `final X = … : … : X` pattern).
- [ ] In `radio_system.dart` (or wherever the message originates), emit with the
      correct prefix: `emit('[WNGS] HAWK 2, TALLY — two contacts, engaging');`
- [ ] Run `python3 tests/test_cockpit_ui.py` — 30/31 must pass (T28 known-broken).

---

## Design Rules

1. `rowBg` must be dark enough that `_kAFg` timestamp text (`0xFF441166`) remains
   readable — keep luminance below ~10 % (`0xFF1A1A1A` equivalent).
2. `callsignClr` saturation ≥ 60 % so callsigns pop against the dim violet panel bg.
3. `msgClr` should be a lighter (higher-value) tint of the same hue as `callsignClr`.
4. Never reuse a hue within 30° of an existing slot — see the hue-wheel table above.
5. Test contrast: callsign + message must both be readable on both the transparent bg
   and the tinted `rowBg`.
