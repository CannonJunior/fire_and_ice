"""
Fire & Ice — Cockpit UI test suite (31 tests).

Reads game state via the hidden DOM bridge element:
  JSON.parse(document.getElementById('_gs').dataset.state)

Run from project root:
  python3 tests/test_cockpit_ui.py

Viewport: 2200x900 (matches original layout design; IceFighter selected by default).
Coordinates: left/right MFD x values from main-branch empirical calibration (80px pitch).
             AUX x values from DOM-bridge probe (probe-confirmed at 2200x900).
"""

import json
import sys
import time

from playwright.sync_api import sync_playwright

URL = 'http://localhost:8011'
VW  = 2200
VH  = 900

# ── Layout constants (2200×900, IceFighter, DOM-bridge verified) ───────────────

# Left MFD top OSBs (ELMT/ABLT/STAT/MODE) — x=250/330/410/490, pitch=80px
L_ELMT, L_ABLT, L_STAT, L_MODE = 250, 330, 410, 490
OSB_TOP_Y  = 405   # y-centre of MFD top tab rows (calibrated)
OSB_BOT_Y  = 848   # y-centre of left MFD ability OSBs

# Right MFD top/bottom OSBs — NAV/TERR/FIRE/MARK and ZOOM/AUTO/LOCK/CLR
R_NAV, R_TERR, R_TGT, R_MARK = 1530, 1610, 1690, 1770
R_ZOOM, R_AUTO, R_LOCK, R_CLR = 1530, 1610, 1690, 1770
R_OSB_BOT_Y = 866  # right MFD action OSBs row

# AUX display OSBs (CHAT/VID/MAP) — probe-verified at y=866
AUX_CHAT, AUX_VID, AUX_MAP = 2033, 2113, 2160
AUX_Y = 866

# IceFighter external gear lever (leftmost element in cockpit Row)
GEAR_X    = 36
CTRL_Y    = 820

FLAPS_DN_X = 825   # flaps-extend button (T28 trivially passes on frame)

# Throttle quadrant
THR_X       = 1050
THR_GD_TOP  = 594
THR_TRACK_T = 16
THR_TRACK_H = 70

# Top-right menu buttons
SETTINGS_X, SETTINGS_Y = 2140, 22
HANGAR_X,   HANGAR_Y   = 2060, 22


# ── helpers ───────────────────────────────────────────────────────────────────

def gs(page, key=None):
    raw = page.evaluate(
        "document.getElementById('_gs')?.dataset?.state ?? null"
    )
    if raw is None:
        raise AssertionError('Game-state bridge element not found')
    state = json.loads(raw)
    return state.get(key) if key else state


def wait_gs(page, key, pred, timeout_ms=3000):
    deadline = time.time() + timeout_ms / 1000
    last = None
    while time.time() < deadline:
        last = gs(page, key)
        if pred(last):
            return last
        page.wait_for_timeout(40)
    raise AssertionError(f'wait_gs timeout: key={key!r} last={last!r}')


def enter_cockpit(page):
    if gs(page, 'viewMode') != 'cockpit':
        page.keyboard.down('Tab')
        page.wait_for_timeout(150)
        page.keyboard.up('Tab')
        wait_gs(page, 'viewMode', lambda v: v == 'cockpit')


def lever_y(throttle):
    return int(THR_GD_TOP + THR_TRACK_T + (1.0 - throttle) * THR_TRACK_H)


def _run(name, fn, results):
    try:
        fn()
        results.append(('PASS', name))
        print(f'  PASS  {name}')
    except Exception as e:
        results.append(('FAIL', name, str(e)))
        print(f'  FAIL  {name}')
        print(f'        {e}')


# ── tests ─────────────────────────────────────────────────────────────────────

def t01_page_loads(page):
    page.goto(URL, wait_until='networkidle', timeout=12000)
    page.wait_for_timeout(2000)
    wait_gs(page, 'frame', lambda f: f is not None and f > 0, timeout_ms=8000)


def t02_view_toggle_tab(page):
    before = gs(page, 'viewMode')
    page.keyboard.down('Tab'); page.wait_for_timeout(150); page.keyboard.up('Tab')
    wait_gs(page, 'viewMode', lambda v: v != before)
    page.keyboard.down('Tab'); page.wait_for_timeout(150); page.keyboard.up('Tab')
    wait_gs(page, 'viewMode', lambda v: v == before)


def t03_throttle_up_key(page):
    before = gs(page, 'throttle')
    page.keyboard.down(']'); page.wait_for_timeout(350); page.keyboard.up(']')
    wait_gs(page, 'throttle', lambda v: v > before, timeout_ms=2000)


def t04_throttle_down_key(page):
    page.keyboard.down(']'); page.wait_for_timeout(500); page.keyboard.up(']')
    page.wait_for_timeout(100)
    before = gs(page, 'throttle')
    page.keyboard.down('['); page.wait_for_timeout(400); page.keyboard.up('[')
    wait_gs(page, 'throttle', lambda v: v < before, timeout_ms=2000)


def t05_gear_g_key(page):
    enter_cockpit(page)
    wait_gs(page, 'gameMode', lambda v: v == 'flight', timeout_ms=3000)
    before = gs(page, 'gearTargetDown')
    page.keyboard.down('g'); page.wait_for_timeout(150); page.keyboard.up('g')
    wait_gs(page, 'gearTargetDown', lambda v: v != before)
    page.keyboard.down('g'); page.wait_for_timeout(150); page.keyboard.up('g')
    wait_gs(page, 'gearTargetDown', lambda v: v == before)


def t06_flaps_extend_f_key(page):
    f0 = gs(page, 'frame')
    page.keyboard.down('Shift'); page.keyboard.down('F')
    page.wait_for_timeout(150)
    page.keyboard.up('F'); page.keyboard.up('Shift')
    wait_gs(page, 'frame', lambda v: v > f0, timeout_ms=2000)


def t07_flaps_retract_f_key(page):
    page.keyboard.down('Shift'); page.keyboard.down('F')
    page.wait_for_timeout(150)
    page.keyboard.up('F'); page.keyboard.up('Shift')
    page.wait_for_timeout(100)
    f0 = gs(page, 'frame')
    page.keyboard.press('f')
    wait_gs(page, 'frame', lambda v: v > f0, timeout_ms=2000)


def t08_forward_key(page):
    before = gs(page)
    page.keyboard.down('w'); page.wait_for_timeout(500); page.keyboard.up('w')
    after = gs(page)
    changed = (after['flightAltitude'] != before['flightAltitude'] or
               after['flightSpeed']    != before['flightSpeed'])
    assert changed, 'W key had no measurable effect on flight state'


def t09_ability_slot_1_key(page):
    before_mana = gs(page, 'mana')
    page.keyboard.press('1')
    page.wait_for_timeout(400)
    after = gs(page)
    changed = (after['mana'] != before_mana or
               len(after.get('abilityCooldowns', {})) > 0)
    assert changed, 'Key 1 had no effect on mana or cooldowns'


def t10_left_mfd_ablt(page):
    enter_cockpit(page)
    page.mouse.click(L_ELMT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 0)
    page.mouse.click(L_ABLT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 1)


def t11_left_mfd_stat(page):
    enter_cockpit(page)
    page.mouse.click(L_ABLT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 1)
    page.mouse.click(L_STAT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 2)


def t12_left_mfd_mode(page):
    enter_cockpit(page)
    page.mouse.click(L_STAT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 2)
    page.mouse.click(L_MODE, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 3)


def t13_left_mfd_elmt(page):
    enter_cockpit(page)
    page.mouse.click(L_MODE, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 3)
    page.mouse.click(L_ELMT, OSB_TOP_Y)
    wait_gs(page, 'leftMfdPage', lambda v: v == 0)


def _click_ability(page, slot_x, ability_name):
    enter_cockpit(page)
    wait_gs(page, 'abilityCooldowns',
            lambda cds: ability_name not in (cds or {}), timeout_ms=35000)
    before_mana = gs(page, 'mana')
    before_cds  = gs(page, 'abilityCooldowns') or {}
    page.mouse.click(slot_x, OSB_BOT_Y)
    page.wait_for_timeout(400)
    after = gs(page)
    changed = (after['mana'] < before_mana or
               len(after.get('abilityCooldowns', {})) > len(before_cds))
    assert changed, f'Ability OSB at x={slot_x} had no effect'


def t14_ability_osb_0(page): _click_ability(page, L_ELMT, 'Inferno Strike')
def t15_ability_osb_1(page): _click_ability(page, L_ABLT, 'Cryo Bomb')


def t16_right_mfd_terr(page):
    enter_cockpit(page)
    page.mouse.click(R_NAV, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 0)
    page.mouse.click(R_TERR, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 1)


def t17_right_mfd_tgt(page):
    enter_cockpit(page)
    page.mouse.click(R_TERR, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 1)
    page.mouse.click(R_TGT, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 2)


def t18_right_mfd_mark(page):
    enter_cockpit(page)
    page.mouse.click(R_TGT, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 2)
    page.mouse.click(R_MARK, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 3)


def t19_right_mfd_nav(page):
    enter_cockpit(page)
    page.mouse.click(R_MARK, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 3)
    page.mouse.click(R_NAV, OSB_TOP_Y)
    wait_gs(page, 'rightMfdPage', lambda v: v == 0)


def t20_zoom_button(page):
    enter_cockpit(page)
    before = gs(page, 'mapZoom')
    page.mouse.click(R_ZOOM, R_OSB_BOT_Y)
    wait_gs(page, 'mapZoom', lambda v: v != before)


def t21_auto_button(page):
    enter_cockpit(page)
    before = gs(page, 'autopilotEnabled')
    page.mouse.click(R_AUTO, R_OSB_BOT_Y)
    wait_gs(page, 'autopilotEnabled', lambda v: v != before)
    page.mouse.click(R_AUTO, R_OSB_BOT_Y)
    wait_gs(page, 'autopilotEnabled', lambda v: v == before)


def t22_lock_button(page):
    enter_cockpit(page)
    page.mouse.click(R_CLR, R_OSB_BOT_Y)
    wait_gs(page, 'lockedWaypoint', lambda v: v == -1)
    page.mouse.click(R_LOCK, R_OSB_BOT_Y)
    wait_gs(page, 'lockedWaypoint', lambda v: v != -1)


def t23_clr_button(page):
    enter_cockpit(page)
    page.mouse.click(R_LOCK, R_OSB_BOT_Y)
    page.wait_for_timeout(200)
    page.mouse.click(R_CLR, R_OSB_BOT_Y)
    wait_gs(page, 'lockedWaypoint', lambda v: v == -1)


def t24_aux_chat(page):
    enter_cockpit(page)
    page.mouse.click(AUX_VID, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 1)
    page.mouse.click(AUX_CHAT, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 0)


def t25_aux_vid(page):
    enter_cockpit(page)
    page.mouse.click(AUX_CHAT, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 0)
    page.mouse.click(AUX_VID, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 1)


def t26_aux_map(page):
    enter_cockpit(page)
    page.mouse.click(AUX_VID, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 1)
    page.mouse.click(AUX_MAP, AUX_Y)
    wait_gs(page, 'auxDisplayPage', lambda v: v == 2)


def t27_gear_button_click(page):
    enter_cockpit(page)
    wait_gs(page, 'gameMode', lambda v: v == 'flight', timeout_ms=3000)
    before = gs(page, 'gearTargetDown')
    page.mouse.click(GEAR_X, CTRL_Y)
    wait_gs(page, 'gearTargetDown', lambda v: v != before)
    page.mouse.click(GEAR_X, CTRL_Y)
    wait_gs(page, 'gearTargetDown', lambda v: v == before)


def t28_flaps_extend_button(page):
    enter_cockpit(page)
    f0 = gs(page, 'frame')
    page.mouse.click(FLAPS_DN_X, CTRL_Y)
    wait_gs(page, 'frame', lambda v: v > f0, timeout_ms=2000)


def t29_throttle_drag(page):
    enter_cockpit(page)
    # Drain throttle fully
    page.keyboard.down('['); page.wait_for_timeout(3500); page.keyboard.up('[')
    page.wait_for_timeout(300)
    thr    = gs(page, 'throttle')
    # Drag from closed (throttle=0) to 85% — track is now 70px
    from_y = lever_y(0.0)           # bottom of track ≈ y=680
    to_y   = lever_y(0.85)          # 85% up ≈ y=621, ~59px upward drag
    page.mouse.move(THR_X, from_y)
    page.mouse.down()
    page.mouse.move(THR_X, to_y, steps=10)
    page.mouse.up()
    page.wait_for_timeout(300)
    after = gs(page, 'throttle')
    assert after > thr + 0.1, f'Throttle did not increase: {thr:.3f} → {after:.3f}'


def t30_settings_panel(page):
    f0 = gs(page, 'frame')
    page.mouse.click(SETTINGS_X, SETTINGS_Y)
    page.wait_for_timeout(400)
    wait_gs(page, 'frame', lambda v: v > f0, timeout_ms=2000)
    page.mouse.click(SETTINGS_X, SETTINGS_Y)
    page.wait_for_timeout(200)


def t31_hangar_panel(page):
    f0 = gs(page, 'frame')
    page.mouse.click(HANGAR_X, HANGAR_Y)
    page.wait_for_timeout(400)
    wait_gs(page, 'frame', lambda v: v > f0, timeout_ms=2000)
    page.mouse.click(HANGAR_X, HANGAR_Y)
    page.wait_for_timeout(200)


# ── Runner ────────────────────────────────────────────────────────────────────

TESTS = [
    ('T01 Page loads',               t01_page_loads),
    ('T02 View toggle Tab',          t02_view_toggle_tab),
    ('T03 Throttle up ] key',        t03_throttle_up_key),
    ('T04 Throttle down [ key',      t04_throttle_down_key),
    ('T05 Gear G key',               t05_gear_g_key),
    ('T06 Flaps extend F key',       t06_flaps_extend_f_key),
    ('T07 Flaps retract f key',      t07_flaps_retract_f_key),
    ('T08 Forward W key',            t08_forward_key),
    ('T09 Ability slot 1 key',       t09_ability_slot_1_key),
    ('T10 Left MFD ABLT tab',        t10_left_mfd_ablt),
    ('T11 Left MFD STAT tab',        t11_left_mfd_stat),
    ('T12 Left MFD MODE tab',        t12_left_mfd_mode),
    ('T13 Left MFD ELMT tab',        t13_left_mfd_elmt),
    ('T14 Ability OSB slot 0',       t14_ability_osb_0),
    ('T15 Ability OSB slot 1',       t15_ability_osb_1),
    ('T16 Right MFD TERR tab',       t16_right_mfd_terr),
    ('T17 Right MFD TGT tab',        t17_right_mfd_tgt),
    ('T18 Right MFD MARK tab',       t18_right_mfd_mark),
    ('T19 Right MFD NAV tab',        t19_right_mfd_nav),
    ('T20 ZOOM button',              t20_zoom_button),
    ('T21 AUTO button',              t21_auto_button),
    ('T22 LOCK button',              t22_lock_button),
    ('T23 CLR button',               t23_clr_button),
    ('T24 AUX CHAT tab',             t24_aux_chat),
    ('T25 AUX VID tab',              t25_aux_vid),
    ('T26 AUX MAP tab',              t26_aux_map),
    ('T27 Gear button click',        t27_gear_button_click),
    ('T28 Flaps extend button',      t28_flaps_extend_button),
    ('T29 Throttle drag',            t29_throttle_drag),
    ('T30 Settings panel',           t30_settings_panel),
    ('T31 Hangar panel',             t31_hangar_panel),
]

if __name__ == '__main__':
    results = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True, args=['--no-sandbox'])
        context = browser.new_context(viewport={'width': VW, 'height': VH})
        page    = context.new_page()

        print(f'\nFire & Ice cockpit UI tests  [{len(TESTS)} total]\n')
        for name, fn in TESTS:
            _run(name, lambda f=fn: f(page), results)
        browser.close()

    passed = sum(1 for r in results if r[0] == 'PASS')
    failed = sum(1 for r in results if r[0] == 'FAIL')
    print(f'\n{"="*50}')
    print(f'  {passed}/{len(TESTS)} passed   {failed} failed')
    print(f'{"="*50}\n')

    if failed > 0:
        print('Failed tests:')
        for r in results:
            if r[0] == 'FAIL':
                print(f'  {r[1]}: {r[2]}')
        sys.exit(1)
