# Cockpit UI Mouse-Click Failures — Runbook

This document records every occurrence of the recurring "cockpit buttons stop responding to clicks" bug, its root cause pattern, investigation procedure, and regression tests to prevent recurrence.

---

## Why This Keeps Happening

### Form A — Platform-View Compositing Residue (most severe)

When any `HtmlElementView` is added to the Flutter widget tree, Flutter web switches into **platform-view compositing mode**. In this mode Flutter splits its render tree into multiple layers to interleave Flutter content with the DOM element. When the `HtmlElementView` is removed (widget unmounted), Flutter **does not reliably reset** the compositing state. The render tree continues to treat certain regions as "platform view slices" with broken hit-testing. This causes most or all Flutter `GestureDetector` widgets to stop receiving events — permanently, until the app is reloaded.

**Symptom pattern:** After opening and closing a widget that contains `HtmlElementView`, most cockpit buttons stop responding. Only a handful of widgets in the "bottom-most" render slice (typically the leftmost column) partially survive.

**The only reliable fix:** Never use `HtmlElementView` for overlays that are conditionally added/removed. Use raw DOM manipulation (`initState` → `dispose`) instead — this bypasses Flutter's compositing pipeline entirely.

### Form B — Element Pointer-Event Block (localised)

An `HtmlElementView` DOM element absorbs DOM pointer events in its bounding box. Flutter's `GestureDetector` operates on Flutter pointer events synthesised from DOM events landing on the **Flutter glass pane**. If a DOM element is above the glass pane and has `pointer-events: auto` (browser default), clicks in that region are swallowed before Flutter sees them.

**Symptom:** All clicks in a specific rectangle are silently ignored. The rest of the screen works. Reproducible every frame.

**Fix:** `pointer-events: none` on the DOM element, or use Form A fix (eliminate `HtmlElementView`).

### Form C — Iframe Focus Theft (keyboard only)

Browser gives keyboard focus to an `<iframe>` when clicked. `document.onKeyDown` fires on the iframe document, not the game document. `InputSystem._pressedKeys` is never updated.

**Symptom:** After clicking video, all flight keys are dead. Mouse clicks still work.

**Fix:** `tabindex="-1"` + `focus` event redirect on the iframe factory.

---

## Incident History

### Incident 1 — YouTube Iframe Keyboard Focus Theft  
**Introduced by:** `aux_display.dart` YouTube iframe embedding  
**Symptom:** `S` key stopped pitching aircraft up; most flight keys dead after clicking the VID page.  
**Root cause:** Browser gives keyboard focus to `<iframe>` when clicked; `document.onKeyDown` fires on the iframe, not the game document.  
**Fix applied in `aux_display.dart` → `_regYt()`:**
```dart
..setAttribute('tabindex', '-1')        // blocks tab-based focus
el.addEventListener('focus', (e) => html.document.body?.focus()); // redirect focus back
```
**Also in `game_widget.dart` → `_registerKeyListeners()`:**
```dart
_blurSub = html.window.onBlur.listen((_) {
  InputSystem.clearAll();
  html.window.requestAnimationFrame((_) => html.document.body?.focus());
});
```

### Incident 2 — Controls Map Overlay: Form B then Form A

**Introduced by:** `controls_map_overlay.dart` — first used `HtmlElementView` to display the SVG `<img>`.

**First symptom (Form B):** `<img>` element had `pointer-events: auto` (browser default). Clicks on the cockpit area behind the img (after close) were swallowed. Partial fix attempted: added `pointer-events: none` to the img element.

**Second symptom (Form A) — WORSE:** After the user opened the controls map overlay (causing `HtmlElementView` to mount), then closed it (unmounting the widget), Flutter's platform-view compositing state did not reset. Most cockpit buttons became permanently unresponsive. Only the leftmost ability buttons (in a surviving render slice) partially worked. The `pointer-events: none` fix had no effect on this — it was the wrong layer.

**Root cause:** Using `HtmlElementView` in a conditionally-mounted widget is fundamentally broken in Flutter web. Platform-view compositing mode is entered on mount and not reliably exited on unmount.

**Final fix applied (`controls_map_overlay.dart`):**  
Eliminated `HtmlElementView` entirely. `ControlsMapOverlay` is now a `StatefulWidget` that:
- Creates a raw DOM `<div>` overlay in `initState()` and appends it to `document.body`
- Removes it in `dispose()`
- Returns `SizedBox.shrink()` from `build()` — no Flutter rendering, no platform view, no compositing interference

```dart
// initState:
final backdrop = html.DivElement()
  ..style.position = 'fixed' ..style.zIndex = '9000' /* ... */;
backdrop.onClick.listen((_) => widget.onClose());
html.document.body?.append(backdrop);

// dispose:
_backdrop?.remove();

// build:
return const SizedBox.shrink();
```

This approach has zero interaction with Flutter's rendering pipeline.

---

## Investigation Checklist

When cockpit mouse clicks stop working, run through this list in order:

### Step 1 — Identify the Region

Determine which screen region is affected:
- **Whole screen** → likely a new `Positioned.fill` widget without `IgnorePointer` or an `HtmlElementView` without `pointer-events: none`.
- **Specific instrument** → likely an `IgnorePointer` was accidentally applied to an interactive widget, or a draggable widget's `CockpitDragGroup` is blocking the hit test.
- **All clicks work but keyboard is dead** → Form B (focus theft); skip to Step 4.

### Step 2 — Audit `game_widget.dart` Stack

Open `lib/game/game_widget.dart`, `build()` method. Check the Stack children **in declaration order** (later = higher Z):

```
cockpit.buildCockpitHud(...)          ← interactive: must be reachable
Positioned(top:12, right:12, ...)     ← menu buttons: interactive
if (_showSettings) Positioned(...)    ← settings panel: interactive
if (_showControlsMap) Positioned.fill ← full-screen overlay: must be conditional
if (_showHangar) Positioned.fill      ← full-screen overlay: must be conditional
```

**Red flags:**
- A `Positioned.fill` that is NOT guarded by a condition — it will block all clicks below it.
- A `Positioned.fill` that IS guarded but whose condition can be `true` unexpectedly.
- **Any `HtmlElementView` in a widget that is conditionally mounted/unmounted** — platform-view compositing residue will break hit-testing globally after unmount.

### Step 3 — Audit All `HtmlElementView` Usages

```bash
grep -rn "HtmlElementView\|registerViewFactory" lib/
```

**CRITICAL:** Any `HtmlElementView` in a widget that is conditionally shown (e.g., inside `if (flag)` in a Stack) is a platform-view compositing hazard. The correct pattern is to use raw DOM manipulation instead. See Rule P-1 below.

Current inventory (must be kept up to date):

| View Type | File | Risk level | Status |
|-----------|------|-----------|--------|
| `'yt-fKHEt3jpSyo'` | `aux_display.dart` | Medium — always in tree only on page 1 | ✅ tabindex + focus redirect |
| `'yt-yh4swGLAL9o'` | `aux_display.dart` | Medium — always in tree only on page 1 | ✅ tabindex + focus redirect |
| `controls-map-svg` | ~~controls_map_overlay.dart~~ | Eliminated | ✅ Replaced with DOM StatefulWidget |

### Step 4 — Audit `cockpit_hud.dart` IgnorePointer Wrapping

Open `lib/game/cockpit_hud.dart`, `buildCockpitHud()`. The Stack has three layers:

```dart
Stack(children: [
  IgnorePointer(child: _windshieldHud(state)),   // ← CORRECT: HUD graphics, not interactive
  Align(..., child: _cockpitPanel(...)),          // ← CORRECT: interactive, no IgnorePointer
  IgnorePointer(child: Stack(children: [         // ← CORRECT: warning text, gauges (read-only)
    WarningTextZone(...),
    Positioned(child: HullIntegrityArc(...)),
    if (showTutorial) buildTutorialOverlay(...),
  ])),
])
```

**Red flag:** `_cockpitPanel` (or any of its drag groups) accidentally wrapped in `IgnorePointer`.

### Step 5 — Browser DevTools Verification

1. Open Chrome DevTools → **Elements** panel.
2. Use the element picker (⌘+Shift+C) and click the area where taps are failing.
3. If the highlighted element is a `<flt-platform-view>` container, `<iframe>`, or `<img>` rather than `<flt-glass-pane>`, a DOM element is intercepting the click.
4. In the **Styles** panel, check `pointer-events` on that element. If it is not `none`, that is the bug.

---

## Prevention: Rules For New Code

### Rule P-1 (MOST IMPORTANT): Never use `HtmlElementView` in a conditionally-mounted widget

Platform-view compositing mode is entered on mount and NOT reliably exited on unmount. Even a brief mount/unmount cycle permanently corrupts Flutter's hit-testing for the entire app until page reload.

```dart
// WRONG — compositing residue after unmount destroys hit-testing globally
if (_showOverlay)
  SomeWidget(child: HtmlElementView(viewType: 'my-view')),

// CORRECT — use raw DOM manipulation; Flutter never enters compositing mode
class _MyOverlayState extends State<MyOverlay> {
  html.Element? _el;

  @override
  void initState() {
    super.initState();
    _el = html.DivElement()..style.position = 'fixed' /* ...etc */;
    html.document.body?.append(_el!);
  }

  @override
  void dispose() { _el?.remove(); _el = null; super.dispose(); }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

`HtmlElementView` is only safe in widgets that are **always in the tree** (e.g., the YouTube iframe on the AUX display VID page switch, which is always inside the cockpit panel's widget subtree).

### Rule P-2: All display-only DOM elements must set `pointer-events: none`

```dart
// CORRECT — SVG, static image, non-interactive canvas
..style.pointerEvents = 'none';

// CORRECT — iframe where user must click (video controls)
..style.pointerEvents = 'auto';   // but add tabindex='-1' + focus redirect
```

### Rule P-3: All `Positioned.fill` widgets must be guarded by a condition

```dart
// CORRECT
if (_showOverlay)
  Positioned.fill(child: MyOverlay(...)),

// WRONG — blocks entire game indefinitely
Positioned.fill(child: MyOverlay(...)),
```

### Rule P-3: Overlays that contain `HtmlElementView` must NOT rely solely on Flutter conditional rendering to "hide" the DOM element

Flutter's `if (condition) HtmlElementView(...)` removes the widget from the tree when false, which *should* clean up the DOM element — but there is typically a 1-2 frame window where the element persists. Do not depend on this for pointer-event safety. The DOM element must have `pointer-events: none` independently.

### Rule P-4: Test click-through after every new overlay or `HtmlElementView`

Manual smoke test: open the new overlay/widget, close it, then immediately click a cockpit button (gear lever, flaps lever, any MFD OSB). If it responds, the fix is clean.

---

## Regression Tests

Flutter web does not support widget-level integration testing for pointer events across the DOM/Flutter boundary. The following tests are the closest practical equivalents.

### Test T-1: HtmlElementView DOM element has `pointer-events: none` (unit test)

```dart
// test/pointer_events_test.dart
// Validate that every non-interactive platform view factory sets pointer-events:none.
// Run with: flutter test --platform chrome test/pointer_events_test.dart

import 'dart:html' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_and_ice_game/game/controls_map_overlay.dart';

void main() {
  test('controls-map img has pointer-events none', () {
    // Force factory registration
    _ensureRegistered(); // exported or made @visibleForTesting

    // Invoke the registered factory
    // (In actual test, use platformViewRegistry.creationParamsForViewType or
    //  mock the factory call directly)
    final el = html.document.createElement('img') as html.ImageElement
      ..style.pointerEvents = 'none'; // replicate factory logic
    expect(el.style.pointerEvents, equals('none'));
  });
}
```

### Test T-2: Overlay `Positioned.fill` is conditional (static analysis / code review)

Add this grep to your pre-commit hook or CI script:

```bash
#!/bin/bash
# Check for unconditional Positioned.fill in game_widget.dart build()
# Every Positioned.fill should be preceded by 'if (' on the previous non-blank line.

FILE="lib/game/game_widget.dart"
VIOLATIONS=$(awk '
  /Positioned\.fill/ {
    if (prev !~ /^[[:space:]]*if[[:space:]]*\(/) {
      print NR": "$0
    }
  }
  /[^[:space:]]/ { prev = $0 }
' "$FILE")

if [ -n "$VIOLATIONS" ]; then
  echo "ERROR: Unconditional Positioned.fill found in $FILE:"
  echo "$VIOLATIONS"
  exit 1
fi
echo "OK: All Positioned.fill are guarded."
```

### Test T-3: Audit for `HtmlElementView` in conditionally-mounted widgets

```bash
#!/bin/bash
# Find any HtmlElementView usage and flag it for manual review.
# ANY HtmlElementView in a conditionally-mounted widget is a compositing hazard.
FOUND=$(grep -rn "HtmlElementView" lib/)
if [ -n "$FOUND" ]; then
  echo "HtmlElementView usages found — verify NONE are in conditionally-mounted widgets:"
  echo "$FOUND"
  echo ""
  echo "Allowed (always-in-tree) usages:"
  echo "  aux_display.dart — YouTube iframes (only shown on VID page, but parent always mounted)"
  echo ""
  echo "FORBIDDEN pattern: if (flag) SomeWidget(child: HtmlElementView(...))"
fi
```

### Test T-4: Manual smoke test checklist (run after any HUD or overlay change)

```
□ Start game fresh (page reload)
□ Open Settings → CONTROLS → VIEW CONTROLS MAP
□ The SVG image appears in a dark overlay
□ Click ✕ CLOSE button → overlay disappears
□ Click the gear lever → status toggles (UP/DOWN)
□ Click the flaps lever above the knob → level decreases
□ Click the flaps lever below the knob → level increases
□ Click an MFD OSB button (ELMT → LOAD) → page changes
□ Click an AUX display tab (VID, MAP, etc.) → page changes
□ Press W → aircraft pitches up
□ Press S → aircraft pitches down
□ Open controls map AGAIN, click backdrop (not ✕) → overlay disappears
□ Repeat gear lever click → must still respond (compositing residue test)
□ Open AUX → VID page, click video to start playback
□ Press W → flight controls must still respond (keyboard focus not stolen)
```

---

## Quick Fix Reference

| Symptom | Severity | First check | Fix |
|---------|----------|-------------|-----|
| Most cockpit clicks dead after opening/closing an overlay | CRITICAL | Does the overlay use `HtmlElementView`? | Replace with raw DOM `StatefulWidget` (Rule P-1) |
| Clicks in a specific rectangle silently ignored | HIGH | DevTools picker — is `<flt-platform-view>` or `<img>` highlighted? | `pointer-events: none` on DOM element (Rule P-2) |
| All clicks dead (full screen) | HIGH | Is a `Positioned.fill` always in the Stack without condition? | Wrap in `if (flag)` guard (Rule P-3) |
| Keyboard dead after clicking video | MEDIUM | `InputSystem._pressedKeys` empty? | `tabindex='-1'` + focus redirect on iframe |
| Specific instrument unresponsive | LOW | Is it wrapped in `IgnorePointer` in `cockpit_hud.dart`? | Remove `IgnorePointer` from interactive element |
