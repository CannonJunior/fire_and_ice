"""
Fire & Ice — Cockpit UI Playwright Test Suite
==============================================
Tests every interactive cockpit UI element at http://localhost:8009.
Skipped elements (known broken): FLAPS lever, SUPPRESSION panel.

Viewport: 2200×900
  Wide enough to show Left MFD, Centre column, Right MFD, and partial Aux.
  Cockpit panel is bottom-aligned; panel bottom ≈ y=894 (900-6 px padding).

Coordinate derivation
---------------------
All coordinates were measured empirically by clicking in a headless browser
and checking whether a designated screen region changed by > DIFF_THRESHOLD
pixels.  Coordinates are centre-points of the target UI element.

Element map at 2200×900:
  Left MFD top tabs (ELMT/LOAD/STAT/MODE): x=250/330/410/490, y=405
  Left MFD ability OSBs (INFE/CRYO/HEAT/FROS): x=250/330/410/490, y=848
  Engine-fire annunciator lights (L-ENG / R-ENG): x=830/910, y=25
  Gear key: 'g'
  Throttle up/down keys: ']' / '['
  Right MFD top tabs (NAV/TERR/FIRE/MARK): x=1530/1610/1690/1770, y=403
  Right MFD action OSBs (ZOOM/AUTO/LOCK/CLR): x=1530/1610/1690/1770, y=866
  Aux Display OSBs (bottom row): x≈2070/2150, y=858  (CHAT/VID visible; MAP+ off-screen)
  Fire Prox sensor (persistent, bottom-left overlay): x=72, y=828
  Hull Integrity Arc (persistent, bottom-right overlay): x=2128, y=828
  Settings button: x≈2140, y=22
  Hangar button: x≈2060, y=22
  View-toggle key: Tab
"""

import json
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright, Page

# ── Configuration ──────────────────────────────────────────────────────────────

BASE_URL       = "http://localhost:8009"
SCREENSHOT_DIR = Path("/tmp/test_screenshots")
# Written after every run; served by the Flutter dev server at /test_results.json
RESULTS_JSON   = Path(__file__).parent.parent / "fire_and_ice_game" / "web" / "test_results.json"
VIEWPORT       = {"width": 2200, "height": 900}

# Pixel-diff threshold: a tab/page change affects thousands of pixels;
# a game-animation tick affects far fewer.
DIFF_TAB       = 5_000    # large content change (MFD page switch)
DIFF_STATE     = 1_000    # smaller state change (gear, throttle, mode)
DIFF_VISUAL    = 50       # element is rendered (non-black pixels exist)

# ── Layout constants (measured empirically at 2200×900) ───────────────────────

# Left MFD top OSBs
LMFD_Y_TOP   = 405
LMFD_ELMT_X  = 250
LMFD_LOAD_X  = 330
LMFD_STAT_X  = 410
LMFD_MODE_X  = 490

# Left MFD bottom ability OSBs
LMFD_Y_BOT   = 848
LMFD_INFE_X  = 250
LMFD_CRYO_X  = 330
LMFD_HEAT_X  = 410
LMFD_FROS_X  = 490

# Engine-fire annunciator lights (row 0 of annunciator, interactive)
ANN_LENG_X   = 830
ANN_RENG_X   = 910
ANN_Y        = 25

# Right MFD top OSBs
RMFD_Y_TOP   = 403
RMFD_NAV_X   = 1530
RMFD_TERR_X  = 1610
RMFD_FIRE_X  = 1690
RMFD_MARK_X  = 1770

# Right MFD bottom OSBs
RMFD_Y_BOT   = 866
RMFD_ZOOM_X  = 1530
RMFD_AUTO_X  = 1610
RMFD_LOCK_X  = 1690
RMFD_CLR_X   = 1770

# Aux Display bottom OSBs (CHAT=leftmost, VID=next; MAP+ off-screen at 2200px)
AUX_Y        = 858
AUX_CHAT_X   = 2070
AUX_VID_X    = 2150

# Persistent overlay gauges (always visible in both cockpit and 3rd-person)
FPS_X, FPS_Y = 72,   828   # Fire Prox Sensor centre (bottom-left)
HIA_X, HIA_Y = 2128, 828   # Hull Integrity Arc centre (bottom-right)

# Top-bar buttons
SETTINGS_X, SETTINGS_Y = 2140, 22
HANGAR_X,   HANGAR_Y   = 2060, 22

# Right MFD content region (for tab-change comparison)
RMFD_REGION = (1100, 420, 700, 420)   # (x, y, w, h)
# Left MFD content region
LMFD_REGION = (90,   420, 560, 400)

# ── Helpers ────────────────────────────────────────────────────────────────────

def _mkdir():
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

def screenshot(page: Page, name: str) -> str:
    _mkdir()
    path = str(SCREENSHOT_DIR / f"{name}.png")
    page.screenshot(path=path)
    print(f"  [shot] {path}")
    return path

def click(page: Page, x: int, y: int, wait_ms: int = 700):
    page.mouse.click(x, y)
    page.wait_for_timeout(wait_ms)

def key(page: Page, k: str, wait_ms: int = 700):
    page.keyboard.press(k)
    page.wait_for_timeout(wait_ms)

def key_n(page: Page, k: str, n: int, ms: int = 250):
    for _ in range(n):
        page.keyboard.press(k)
        page.wait_for_timeout(ms)

def _snap(page: Page):
    from PIL import Image
    import io
    return Image.open(io.BytesIO(page.screenshot()))

def _rdiff(a, b, x: int, y: int, w: int, h: int) -> int:
    """Pixel difference in a sub-region."""
    ra = a.crop((x, y, x + w, y + h)).tobytes()
    rb = b.crop((x, y, x + w, y + h)).tobytes()
    return sum(1 for p, q in zip(ra, rb) if p != q)

def _full_diff(a, b) -> int:
    return sum(1 for p, q in zip(a.tobytes(), b.tobytes()) if p != q)

def _avg_brightness(img, x: int, y: int, r: int = 30) -> float:
    """Average brightness of pixels in a square region."""
    region = img.crop((x - r, y - r, x + r, y + r)).convert("L")
    pix = list(region.getdata())
    return sum(pix) / len(pix) if pix else 0.0

# ── Test runner ────────────────────────────────────────────────────────────────

_results: list[tuple[str, bool, str]] = []

def run(name: str, fn):
    print(f"\n{'='*60}\n  {name}\n{'='*60}")
    try:
        fn()
        _results.append((name, True, ""))
        print(f"  PASS")
    except Exception as e:
        _results.append((name, False, f"{type(e).__name__}: {e}"))
        print(f"  FAIL: {e}")
        traceback.print_exc()

# ── Individual tests ───────────────────────────────────────────────────────────

def t01_app_loads(page: Page):
    """App reaches localhost:8009 and a Flutter canvas is present."""
    page.goto(BASE_URL, wait_until="networkidle", timeout=30_000)
    page.wait_for_timeout(4_000)
    screenshot(page, "t01_load")
    assert page.locator("canvas").count() > 0, "No <canvas> — Flutter failed to mount"
    print("  canvas found ✓")


def t02_view_toggle(page: Page):
    """Tab key switches between 3rd-person and cockpit view."""
    page.mouse.click(1100, 450)
    page.wait_for_timeout(200)

    before = _snap(page)
    key(page, "Tab", wait_ms=2000)
    after = _snap(page)
    screenshot(page, "t02_cockpit")

    d = _full_diff(before, after)
    assert d > 100_000, f"Tab key: screen barely changed (diff={d}) — view toggle may be broken"
    print(f"  view changed (diff={d}) ✓")

    # Stay in cockpit view for remaining tests
    src = page.content()
    assert "OVERFLOWED" not in src, "Flutter layout overflow detected — panel does not fit"
    print("  no layout overflow ✓")


def t03_lmfd_tab_elmt(page: Page):
    """Left MFD ELMT tab shows different content than LOAD tab."""
    # Switch to LOAD first, capture that state, then switch to ELMT and compare.
    click(page, LMFD_LOAD_X, LMFD_Y_TOP)
    on_load = _snap(page)
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)
    on_elmt = _snap(page)
    screenshot(page, "t03_lmfd_elmt")
    d = _rdiff(on_load, on_elmt, *LMFD_REGION)
    assert d > DIFF_TAB, f"ELMT vs LOAD: region looks identical (diff={d}) — tab may not be switching"
    print(f"  ELMT shows different content than LOAD (diff={d}) ✓")


def t04_lmfd_tab_load(page: Page):
    """Left MFD LOAD tab switches content from ELMT."""
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)
    before = _snap(page)
    click(page, LMFD_LOAD_X, LMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t04_lmfd_load")
    d = _rdiff(before, after, *LMFD_REGION)
    assert d > DIFF_TAB, f"LOAD tab: region unchanged (diff={d}) — button not responding"
    print(f"  LOAD tab changed content (diff={d}) ✓")
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)   # reset


def t05_lmfd_tab_stat(page: Page):
    """Left MFD STAT tab switches content."""
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)
    before = _snap(page)
    click(page, LMFD_STAT_X, LMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t05_lmfd_stat")
    d = _rdiff(before, after, *LMFD_REGION)
    assert d > DIFF_TAB, f"STAT tab: region unchanged (diff={d}) — button not responding"
    print(f"  STAT tab changed content (diff={d}) ✓")
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)


def t06_lmfd_tab_mode(page: Page):
    """Left MFD MODE tab switches content."""
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)
    before = _snap(page)
    click(page, LMFD_MODE_X, LMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t06_lmfd_mode")
    d = _rdiff(before, after, *LMFD_REGION)
    assert d > DIFF_TAB, f"MODE tab: region unchanged (diff={d}) — button not responding"
    print(f"  MODE tab changed content (diff={d}) ✓")
    click(page, LMFD_ELMT_X, LMFD_Y_TOP)


def t07_lmfd_ability_infe(page: Page):
    """Left MFD INFE ability OSB activates an ability."""
    before = _snap(page)
    click(page, LMFD_INFE_X, LMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t07_ability_infe")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"INFE ability: screen unchanged (diff={d}) — button not responding"
    print(f"  INFE activated (diff={d}) ✓")


def t08_lmfd_ability_cryo(page: Page):
    """Left MFD CRYO ability OSB is interactive."""
    before = _snap(page)
    click(page, LMFD_CRYO_X, LMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t08_ability_cryo")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"CRYO ability: screen unchanged (diff={d})"
    print(f"  CRYO activated (diff={d}) ✓")


def t09_lmfd_ability_heat(page: Page):
    """Left MFD HEAT ability OSB is interactive."""
    before = _snap(page)
    click(page, LMFD_HEAT_X, LMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t09_ability_heat")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"HEAT ability: screen unchanged (diff={d})"
    print(f"  HEAT activated (diff={d}) ✓")


def t10_lmfd_ability_fros(page: Page):
    """Left MFD FROS ability OSB is interactive."""
    before = _snap(page)
    click(page, LMFD_FROS_X, LMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t10_ability_fros")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"FROS ability: screen unchanged (diff={d})"
    print(f"  FROS activated (diff={d}) ✓")


def t11_annunciator_leng(page: Page):
    """Annunciator L-ENG FIRE light is interactive (opens/closes halon shield)."""
    before = _snap(page)
    click(page, ANN_LENG_X, ANN_Y, wait_ms=400)
    after = _snap(page)
    screenshot(page, "t11_ann_leng")
    d = _rdiff(before, after, ANN_LENG_X - 50, ANN_Y - 15, 100, 80)
    assert d > DIFF_STATE, f"L-ENG light: region unchanged (diff={d}) — light not interactive"
    print(f"  L-ENG light responded (diff={d}) ✓")
    click(page, ANN_LENG_X, ANN_Y, wait_ms=400)  # reset


def t12_annunciator_reng(page: Page):
    """Annunciator R-ENG FIRE light is interactive."""
    before = _snap(page)
    click(page, ANN_RENG_X, ANN_Y, wait_ms=400)
    after = _snap(page)
    screenshot(page, "t12_ann_reng")
    d = _rdiff(before, after, ANN_RENG_X - 50, ANN_Y - 15, 100, 80)
    assert d > DIFF_STATE, f"R-ENG light: region unchanged (diff={d}) — light not interactive"
    print(f"  R-ENG light responded (diff={d}) ✓")
    click(page, ANN_RENG_X, ANN_Y, wait_ms=400)  # reset


def t13_annunciator_visual(page: Page):
    """Annunciator panel renders non-black content (lights are drawn)."""
    img = _snap(page)
    screenshot(page, "t13_ann_visual")
    # Annunciator row 0 spans roughly x=750-1050, y=10-60 at 2200×900
    region = img.crop((750, 10, 1050, 65)).convert("RGB")
    pixels = list(region.getdata())
    bright = sum(1 for r, g, b in pixels if r + g + b > 60)
    assert bright > 50, f"Annunciator appears blank — only {bright} bright pixels found"
    print(f"  Annunciator has {bright} lit pixels ✓")


def t14_gear_key(page: Page):
    """G key toggles gear state (visible change in gear lever / annunciator)."""
    before = _snap(page)
    key(page, "g", wait_ms=1200)   # gear transit takes ~3s; wait for start
    after = _snap(page)
    screenshot(page, "t14_gear")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"G key: screen unchanged (diff={d}) — gear toggle not working"
    print(f"  Gear state changed (diff={d}) ✓")
    key(page, "g", wait_ms=1200)   # toggle back


def t15_throttle_up_key(page: Page):
    """'] ' key increases throttle (THR gauge / N1 readout changes)."""
    page.mouse.click(1100, 450)
    page.wait_for_timeout(200)
    before = _snap(page)
    key_n(page, "BracketRight", 6, ms=200)
    page.wait_for_timeout(400)
    after = _snap(page)
    screenshot(page, "t15_thr_up")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"Throttle ]: screen unchanged (diff={d}) — key not working"
    print(f"  Throttle increased (diff={d}) ✓")


def t16_throttle_down_key(page: Page):
    """'[' key decreases throttle back toward zero."""
    before = _snap(page)
    key_n(page, "BracketLeft", 6, ms=200)
    page.wait_for_timeout(400)
    after = _snap(page)
    screenshot(page, "t16_thr_down")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"Throttle [: screen unchanged (diff={d}) — key not working"
    print(f"  Throttle decreased (diff={d}) ✓")


def t17_throttle_drag(page: Page):
    """Throttle quadrant lever responds to vertical drag."""
    # Throttle quad is roughly x=960-1060, y=490-810 at 2200×900.
    tq_cx, tq_cy = 1010, 650
    before = _snap(page)
    # Drag lever upward (increase throttle)
    page.mouse.move(tq_cx, tq_cy)
    page.mouse.down()
    page.mouse.move(tq_cx, tq_cy - 80, steps=10)
    page.wait_for_timeout(300)
    page.mouse.up()
    page.wait_for_timeout(500)
    after = _snap(page)
    screenshot(page, "t17_tq_drag")
    d = _rdiff(before, after, 900, 480, 200, 340)
    assert d > DIFF_STATE, f"Throttle drag: quadrant region unchanged (diff={d})"
    print(f"  Throttle quadrant responded to drag (diff={d}) ✓")
    # Reset: drag back down
    page.mouse.move(tq_cx, tq_cy - 80)
    page.mouse.down()
    page.mouse.move(tq_cx, tq_cy, steps=10)
    page.mouse.up()
    page.wait_for_timeout(400)


def t18_rmfd_tab_terr(page: Page):
    """Right MFD TERR tab changes content from NAV."""
    click(page, RMFD_NAV_X, RMFD_Y_TOP)   # ensure on NAV
    before = _snap(page)
    click(page, RMFD_TERR_X, RMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t18_rmfd_terr")
    d = _rdiff(before, after, *RMFD_REGION)
    assert d > DIFF_TAB, f"Right MFD TERR tab: region unchanged (diff={d}) — button not responding"
    print(f"  TERR tab changed content (diff={d}) ✓")
    click(page, RMFD_NAV_X, RMFD_Y_TOP)   # reset


def t19_rmfd_tab_fire(page: Page):
    """Right MFD FIRE tab changes content."""
    click(page, RMFD_NAV_X, RMFD_Y_TOP)
    before = _snap(page)
    click(page, RMFD_FIRE_X, RMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t19_rmfd_fire")
    d = _rdiff(before, after, *RMFD_REGION)
    assert d > DIFF_TAB, f"Right MFD FIRE tab: region unchanged (diff={d})"
    print(f"  FIRE tab changed content (diff={d}) ✓")
    click(page, RMFD_NAV_X, RMFD_Y_TOP)


def t20_rmfd_tab_mark(page: Page):
    """Right MFD MARK tab changes content."""
    click(page, RMFD_NAV_X, RMFD_Y_TOP)
    before = _snap(page)
    click(page, RMFD_MARK_X, RMFD_Y_TOP)
    after = _snap(page)
    screenshot(page, "t20_rmfd_mark")
    d = _rdiff(before, after, *RMFD_REGION)
    assert d > DIFF_TAB, f"Right MFD MARK tab: region unchanged (diff={d})"
    print(f"  MARK tab changed content (diff={d}) ✓")
    click(page, RMFD_NAV_X, RMFD_Y_TOP)


def t21_rmfd_zoom(page: Page):
    """Right MFD ZOOM button (bottom OSB) responds."""
    before = _snap(page)
    click(page, RMFD_ZOOM_X, RMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t21_rmfd_zoom")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"ZOOM button: screen unchanged (diff={d})"
    print(f"  ZOOM responded (diff={d}) ✓")


def t22_rmfd_auto(page: Page):
    """Right MFD AUTO button toggles autopilot."""
    before = _snap(page)
    click(page, RMFD_AUTO_X, RMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t22_rmfd_auto")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"AUTO button: screen unchanged (diff={d})"
    print(f"  AUTO (autopilot) responded (diff={d}) ✓")
    # toggle back off
    click(page, RMFD_AUTO_X, RMFD_Y_BOT)


def t23_rmfd_clr(page: Page):
    """Right MFD CLR button responds."""
    before = _snap(page)
    click(page, RMFD_CLR_X, RMFD_Y_BOT)
    after = _snap(page)
    screenshot(page, "t23_rmfd_clr")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"CLR button: screen unchanged (diff={d})"
    print(f"  CLR responded (diff={d}) ✓")


def t24_aux_chat(page: Page):
    """Aux Display CHAT tab is interactive."""
    before = _snap(page)
    click(page, AUX_CHAT_X, AUX_Y)
    after = _snap(page)
    screenshot(page, "t24_aux_chat")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"AUX CHAT: screen unchanged (diff={d}) — button not responding"
    print(f"  AUX CHAT responded (diff={d}) ✓")


def t25_aux_vid(page: Page):
    """Aux Display VID tab is interactive."""
    before = _snap(page)
    click(page, AUX_VID_X, AUX_Y)
    after = _snap(page)
    screenshot(page, "t25_aux_vid")
    d = _full_diff(before, after)
    assert d > DIFF_STATE, f"AUX VID: screen unchanged (diff={d}) — button not responding"
    print(f"  AUX VID responded (diff={d}) ✓")
    # Reset to CHAT
    click(page, AUX_CHAT_X, AUX_Y)


def t26_fire_prox_visible(page: Page):
    """Fire Proximity Sensor renders as a non-black circle at bottom-left."""
    img = _snap(page)
    screenshot(page, "t26_fireprox")
    brightness = _avg_brightness(img, FPS_X, FPS_Y, r=40)
    assert brightness > 5, (
        f"Fire Prox at ({FPS_X},{FPS_Y}): avg brightness={brightness:.1f} — "
        "sensor appears completely black/absent"
    )
    print(f"  Fire Prox sensor visible (brightness={brightness:.1f}) ✓")


def t27_hull_integrity_visible(page: Page):
    """Hull Integrity Arc renders as a non-black arc at bottom-right."""
    img = _snap(page)
    screenshot(page, "t27_hull")
    brightness = _avg_brightness(img, HIA_X, HIA_Y, r=40)
    assert brightness > 5, (
        f"Hull Integrity Arc at ({HIA_X},{HIA_Y}): avg brightness={brightness:.1f} — "
        "gauge appears completely black/absent"
    )
    print(f"  Hull Integrity Arc visible (brightness={brightness:.1f}) ✓")


def t28_settings_panel(page: Page):
    """Settings panel opens when the ⚙ SETTINGS button is clicked."""
    before = _snap(page)
    click(page, SETTINGS_X, SETTINGS_Y, wait_ms=500)
    after = _snap(page)
    screenshot(page, "t28_settings")
    d = _full_diff(before, after)
    assert d > DIFF_TAB, f"Settings button: screen unchanged (diff={d}) — panel did not open"
    print(f"  Settings panel opened (diff={d}) ✓")
    # Close it
    click(page, SETTINGS_X, SETTINGS_Y, wait_ms=400)


def t29_hangar_panel(page: Page):
    """Hangar panel opens when the ⊞ HANGAR button is clicked."""
    before = _snap(page)
    click(page, HANGAR_X, HANGAR_Y, wait_ms=500)
    after = _snap(page)
    screenshot(page, "t29_hangar")
    d = _full_diff(before, after)
    assert d > DIFF_TAB, f"Hangar button: screen unchanged (diff={d}) — panel did not open"
    print(f"  Hangar panel opened (diff={d}) ✓")
    click(page, HANGAR_X, HANGAR_Y, wait_ms=400)  # close


def t30_view_toggle_back(page: Page):
    """Tab key returns to 3rd-person view and canvas survives."""
    page.mouse.click(1100, 450)
    page.wait_for_timeout(200)
    before = _snap(page)
    key(page, "Tab", wait_ms=2000)
    after = _snap(page)
    screenshot(page, "t30_3rdperson")
    d = _full_diff(before, after)
    # In headless mode the 3D background is always dark, so the diff is mainly
    # from HUD elements disappearing.  Use a lower threshold than the cockpit→3rd
    # switch (which removes the entire cockpit panel).
    assert d > 10_000, f"Tab (return): view barely changed (diff={d}) — toggle broken?"
    assert page.locator("canvas").count() > 0, "Canvas gone after view toggle — crash?"
    print(f"  Returned to 3rd-person (diff={d}) ✓")


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    _mkdir()

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--use-gl=swiftshader",
                "--enable-webgl",
                "--ignore-gpu-blocklist",
                "--disable-web-security",
            ],
        )
        ctx  = browser.new_context(
            viewport={"width": VIEWPORT["width"], "height": VIEWPORT["height"]}
        )
        page = ctx.new_page()

        run("T01 App loads",                      lambda: t01_app_loads(page))
        run("T02 View toggle (Tab)",              lambda: t02_view_toggle(page))
        run("T03 Left MFD tab — ELMT",            lambda: t03_lmfd_tab_elmt(page))
        run("T04 Left MFD tab — LOAD",            lambda: t04_lmfd_tab_load(page))
        run("T05 Left MFD tab — STAT",            lambda: t05_lmfd_tab_stat(page))
        run("T06 Left MFD tab — MODE",            lambda: t06_lmfd_tab_mode(page))
        run("T07 Left MFD ability — INFE",        lambda: t07_lmfd_ability_infe(page))
        run("T08 Left MFD ability — CRYO",        lambda: t08_lmfd_ability_cryo(page))
        run("T09 Left MFD ability — HEAT",        lambda: t09_lmfd_ability_heat(page))
        run("T10 Left MFD ability — FROS",        lambda: t10_lmfd_ability_fros(page))
        run("T11 Annunciator L-ENG FIRE light",   lambda: t11_annunciator_leng(page))
        run("T12 Annunciator R-ENG FIRE light",   lambda: t12_annunciator_reng(page))
        run("T13 Annunciator panel renders",      lambda: t13_annunciator_visual(page))
        run("T14 Gear toggle (G key)",            lambda: t14_gear_key(page))
        run("T15 Throttle up (] key)",            lambda: t15_throttle_up_key(page))
        run("T16 Throttle down ([ key)",          lambda: t16_throttle_down_key(page))
        run("T17 Throttle quadrant drag",         lambda: t17_throttle_drag(page))
        run("T18 Right MFD tab — TERR",           lambda: t18_rmfd_tab_terr(page))
        run("T19 Right MFD tab — FIRE",           lambda: t19_rmfd_tab_fire(page))
        run("T20 Right MFD tab — MARK",           lambda: t20_rmfd_tab_mark(page))
        run("T21 Right MFD action — ZOOM",        lambda: t21_rmfd_zoom(page))
        run("T22 Right MFD action — AUTO",        lambda: t22_rmfd_auto(page))
        run("T23 Right MFD action — CLR",         lambda: t23_rmfd_clr(page))
        run("T24 Aux Display — CHAT tab",         lambda: t24_aux_chat(page))
        run("T25 Aux Display — VID tab",          lambda: t25_aux_vid(page))
        run("T26 Fire Prox sensor visible",       lambda: t26_fire_prox_visible(page))
        run("T27 Hull Integrity Arc visible",     lambda: t27_hull_integrity_visible(page))
        run("T28 Settings panel opens",           lambda: t28_settings_panel(page))
        run("T29 Hangar panel opens",             lambda: t29_hangar_panel(page))
        run("T30 View toggle back to 3rd-person", lambda: t30_view_toggle_back(page))

        ctx.close()
        browser.close()

    passed = sum(1 for _, ok, _ in _results if ok)
    total  = len(_results)
    print(f"\n{'='*60}")
    print(f"RESULTS: PASSED {passed}/{total} tests")
    print(f"{'='*60}")
    if passed < total:
        print("\nFAILURES:")
        for name, ok, detail in _results:
            if not ok:
                print(f"  FAIL  {name}")
                print(f"        {detail}")
    print(f"\nScreenshots: {SCREENSHOT_DIR}")

    # Write machine-readable results for the in-game Settings > TEST STATUS panel.
    payload = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "passed": passed,
        "total": total,
        "tests": [
            {"name": name, "passed": ok, "detail": detail}
            for name, ok, detail in _results
        ],
    }
    RESULTS_JSON.write_text(json.dumps(payload, indent=2))
    print(f"Results written to {RESULTS_JSON}")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
