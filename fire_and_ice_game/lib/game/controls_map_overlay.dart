import 'dart:html' as html;
import 'package:flutter/material.dart';

// DO NOT use HtmlElementView here — see original file comment for explanation.

// ── Binding data ───────────────────────────────────────────────────────────────

// (description, category) — category drives key highlight colour
const Map<String, (String, String)> _kDefaultBindings = {
  'w': ('Pitch ↓', 'flight'), 's': ('Pitch ↑', 'flight'),
  'a': ('Yaw ← bnk', 'flight'), 'd': ('Yaw → bnk', 'flight'),
  'q': ('Bank ←', 'flight'), 'e': ('Bank →', 'flight'),
  'Alt': ('Boost ×1.5', 'flight'), 'Space': ('Air brake', 'flight'),
  'Tab': ('View', 'ui'),
  '1': ('Slot 1', 'action'), '2': ('Slot 2', 'action'),
  '3': ('Slot 3', 'action'), '4': ('Slot 4', 'action'),
  '5': ('Slot 5', 'action'), '6': ('Slot 6', 'action'),
  '7': ('Slot 7', 'action'), '8': ('Slot 8', 'action'),
  '9': ('Slot 9', 'action'), '0': ('Slot 10', 'action'),
  ']': ('Thrtl ↑', 'ui'), '[': ('Thrtl ↓', 'ui'),
  'g': ('Gear', 'ui'), 'f': ('Flaps', 'ui'), 'p': ('Probe', 'ui'),
  'Enter': ('Send msg', 'chat'),
};

// ── Key layout rows  (label, keyId|null, widthUnits) ─────────────────────────

typedef _K = (String, String?, double);
const _sp = ('', null, 0.0); // unused — spacers are inline gaps

const List<_K> _fnRow = [
  ('Esc','Escape',1.0), ('','',0.5),
  ('F1','F1',1.0),('F2','F2',1.0),('F3','F3',1.0),('F4','F4',1.0),('','',0.25),
  ('F5','F5',1.0),('F6','F6',1.0),('F7','F7',1.0),('F8','F8',1.0),('','',0.25),
  ('F9','F9',1.0),('F10','F10',1.0),('F11','F11',1.0),('F12','F12',1.0),
];
const List<_K> _numRow = [
  ('`','`',1.0),('1','1',1.0),('2','2',1.0),('3','3',1.0),('4','4',1.0),
  ('5','5',1.0),('6','6',1.0),('7','7',1.0),('8','8',1.0),('9','9',1.0),
  ('0','0',1.0),('-','-',1.0),('=','=',1.0),('⌫','Backspace',2.0),
];
const List<_K> _qRow = [
  ('Tab','Tab',1.5),('Q','q',1.0),('W','w',1.0),('E','e',1.0),('R','r',1.0),
  ('T','t',1.0),('Y','y',1.0),('U','u',1.0),('I','i',1.0),('O','o',1.0),
  ('P','p',1.0),('[','[',1.0),(']',']',1.0),('\\','\\',1.5),
];
const List<_K> _aRow = [
  ('Caps','CapsLock',1.75),('A','a',1.0),('S','s',1.0),('D','d',1.0),('F','f',1.0),
  ('G','g',1.0),('H','h',1.0),('J','j',1.0),('K','k',1.0),('L','l',1.0),
  (';',';',1.0),("'","'",1.0),('↵','Enter',2.25),
];
const List<_K> _zRow = [
  ('⇧','Shift',2.25),('Z','z',1.0),('X','x',1.0),('C','c',1.0),('V','v',1.0),
  ('B','b',1.0),('N','n',1.0),('M','m',1.0),(',',',',1.0),('.','.',1.0),
  ('/','/',1.0),('⇧','Shift',2.75),
];
const List<_K> _botRow = [
  ('Ctrl','Control',1.25),('⊞','Meta',1.25),('Alt','Alt',1.25),
  ('','Space',6.25),
  ('Alt','Alt',1.25),('⊞','Meta',1.25),('≡','ContextMenu',1.25),('Ctrl','Control',1.25),
];
const List<_K> _nav1 = [('Ins','Insert',1.0),('Home','Home',1.0),('PgUp','PageUp',1.0)];
const List<_K> _nav2 = [('Del','Delete',1.0),('End','End',1.0),('PgDn','PageDown',1.0)];
const List<_K> _arrT = [('','',1.0),('↑','ArrowUp',1.0),('','',1.0)];
const List<_K> _arrB = [('←','ArrowLeft',1.0),('↓','ArrowDown',1.0),('→','ArrowRight',1.0)];
const List<_K> _npR0 = [('NL','NumLock',1.0),('/','/',1.0),('*','*',1.0),('−','−',1.0)];
const List<_K> _npR1 = [('7','Numpad7',1.0),('8','Numpad8',1.0),('9','Numpad9',1.0),('+',' +',1.0)];
const List<_K> _npR2 = [('4','Numpad4',1.0),('5','Numpad5',1.0),('6','Numpad6',1.0)];
const List<_K> _npR3 = [('1','Numpad1',1.0),('2','Numpad2',1.0),('3','Numpad3',1.0)];
const List<_K> _npR4 = [('0','Numpad0',2.0),('.','NumpadDecimal',1.0)];

const _kMainRows = [_numRow, _qRow, _aRow, _zRow, _botRow];
const _kNavRows  = [_nav1, _nav2, <_K>[], _arrT, _arrB];
const _kNpRows   = [_npR0, _npR1, _npR2, _npR3, _npR4];

// ── Widget ────────────────────────────────────────────────────────────────────

class KeyboardMapOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const KeyboardMapOverlay({super.key, required this.onClose});
  @override
  State<KeyboardMapOverlay> createState() => _KeyboardMapOverlayState();
}

class _KeyboardMapOverlayState extends State<KeyboardMapOverlay> {
  html.Element? _backdrop;

  @override
  void initState() { super.initState(); _mount(); }

  @override
  void dispose() { _backdrop?.remove(); _backdrop = null; super.dispose(); }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void _mount() {
    String ff         = 'full';
    bool   useDefault = true;

    final backdrop = html.DivElement()
      ..style.cssText = 'position:fixed;inset:0;z-index:9000;'
          'background:rgba(0,0,0,0.88);display:flex;'
          'align-items:center;justify-content:center;cursor:pointer';

    final frame = html.DivElement()
      ..style.cssText = 'position:relative;cursor:default;'
          'background:#0A0A14;border:1px solid #1E2A3A;border-radius:6px;'
          'box-shadow:0 0 40px #000;max-height:92vh;'
          'display:flex;flex-direction:column;overflow:hidden';
    frame.addEventListener('click', (html.Event e) => e.stopPropagation());

    // ── Header ────────────────────────────────────────────────────────────────
    final header = html.DivElement()
      ..style.cssText = 'display:flex;align-items:center;gap:12px;'
          'padding:10px 14px;border-bottom:1px solid #1E2A3A;flex-shrink:0';

    final title = html.SpanElement()
      ..text = 'KEYBOARD MAP'
      ..style.cssText = 'color:#AABBCC;font:bold 10px monospace;letter-spacing:2px;flex:1';

    // Form factor dropdown
    final ffSelect = html.SelectElement()
      ..style.cssText = 'background:#111120;color:#AABBCC;border:1px solid #1E2A3A;'
          'border-radius:3px;font:9px monospace;padding:3px 6px;cursor:pointer';
    for (final (label, val) in [
      ('Full-size', 'full'), ('Tenkeyless', 'tkl'),
      ('75% Compact', '75'), ('65%', '65'), ('60%', '60'),
    ]) {
      ffSelect.append(html.OptionElement(data: label, value: val));
    }

    // Default / Current toggle
    html.ButtonElement makeToggleBtn(String label, bool active) {
      final btn = html.ButtonElement()
        ..text = label
        ..style.cssText = 'padding:3px 10px;font:bold 9px monospace;cursor:pointer;'
            'border-radius:3px;border:1px solid;transition:background 0.15s';
      _styleToggleBtn(btn, active);
      return btn;
    }
    final btnDef = makeToggleBtn('DEFAULT', true);
    final btnCur = makeToggleBtn('CURRENT', false);

    final toggleWrap = html.DivElement()
      ..style.cssText = 'display:flex;gap:2px';
    toggleWrap..append(btnDef)..append(btnCur);

    final closeBtn = html.DivElement()
      ..text = '✕  CLOSE'
      ..style.cssText = 'padding:3px 8px;background:#1A1A2A;border:1px solid #334455;'
          'border-radius:3px;color:#6688AA;font:bold 9px monospace;cursor:pointer';

    header..append(title)..append(ffSelect)..append(toggleWrap)..append(closeBtn);

    // ── Keyboard wrapper (scrollable) ─────────────────────────────────────────
    final kbWrap = html.DivElement()
      ..style.cssText = 'overflow:auto;padding:12px 16px;flex:1';

    void rebuild() {
      if (_backdrop == null) return;
      kbWrap.children.clear();
      final bindings = useDefault ? _kDefaultBindings : _kDefaultBindings;
      kbWrap.append(_buildKeyboard(ff, bindings));
    }

    // ── Legend ────────────────────────────────────────────────────────────────
    final legend = _buildLegend();

    // ── Event listeners ───────────────────────────────────────────────────────
    backdrop.onClick.listen((_) => widget.onClose());
    closeBtn.onClick.listen((_) => widget.onClose());

    ffSelect.onChange.listen((e) {
      ff = (e.target as html.SelectElement).value ?? 'full';
      rebuild();
    });

    btnDef.onClick.listen((_) {
      useDefault = true;
      _styleToggleBtn(btnDef, true);
      _styleToggleBtn(btnCur, false);
      rebuild();
    });
    btnCur.onClick.listen((_) {
      useDefault = false;
      _styleToggleBtn(btnDef, false);
      _styleToggleBtn(btnCur, true);
      rebuild();
    });

    rebuild();

    frame..append(header)..append(kbWrap)..append(legend);
    backdrop.append(frame);
    html.document.body?.append(backdrop);
    _backdrop = backdrop;
  }

  static void _styleToggleBtn(html.ButtonElement btn, bool active) {
    btn.style
      ..background = active ? '#003366' : '#111120'
      ..color      = active ? '#00AAFF' : '#556677'
      ..borderColor = active ? '#00AAFF' : '#1E2A3A';
  }

  // ── Keyboard builder ──────────────────────────────────────────────────────

  static html.DivElement _buildKeyboard(String ff, Map<String, (String, String)> bindings) {
    final outer = html.DivElement()
      ..style.cssText = 'display:flex;gap:10px;align-items:flex-start';

    // Main block
    final showFn  = ff != '60' && ff != '65';
    final mainRows = showFn ? [_fnRow, ..._kMainRows] : [..._kMainRows];
    final showArrows = ff != '60';
    if (showArrows && !showFn) {
      // 65%: replace bottom row with version that has arrows at right
      final modBot = [..._botRow, ('','',0.5), ..._arrB];
      final rows65 = [_numRow, _qRow, _aRow, _zRow, modBot as List<_K>];
      outer.append(_buildSection(rows65, bindings));
    } else {
      outer.append(_buildSection(mainRows, bindings));
    }

    // Nav cluster (full, tkl, 75%)
    if (ff == 'full' || ff == 'tkl') {
      final sep = html.DivElement()
        ..style.cssText = 'width:1px;background:#1E2A3A;align-self:stretch;margin:0 4px';
      outer.append(sep);
      outer.append(_buildSection(_kNavRows, bindings));
    }

    // Numpad (full only)
    if (ff == 'full') {
      final sep2 = html.DivElement()
        ..style.cssText = 'width:1px;background:#1E2A3A;align-self:stretch;margin:0 4px';
      outer.append(sep2);
      outer.append(_buildSection(_kNpRows, bindings));
    }

    return outer;
  }

  static html.DivElement _buildSection(List<List<_K>> rows, Map<String, (String, String)> bindings) {
    final col = html.DivElement()
      ..style.cssText = 'display:flex;flex-direction:column;gap:3px';
    for (final row in rows) {
      col.append(_buildRow(row, bindings));
    }
    return col;
  }

  static html.DivElement _buildRow(List<_K> row, Map<String, (String, String)> bindings) {
    const u = 30.0; // 1 unit = 30px
    const g = 3.0;  // gap between keys
    final rowEl = html.DivElement()
      ..style.cssText = 'display:flex;gap:3px;align-items:flex-end;min-height:${u + 10}px';
    for (final (label, keyId, width) in row) {
      final px = (u * width + (width > 1 ? g * (width - 1) : 0)).round();
      if (label.isEmpty && keyId == null) {
        // invisible spacer
        rowEl.append(html.DivElement()
          ..style.cssText = 'width:${px}px;flex-shrink:0');
        continue;
      }
      // Look up binding (try exact, then lowercase)
      final (String, String)? bind = keyId != null
          ? (bindings[keyId] ?? bindings[keyId.toLowerCase()])
          : null;
      final category = bind?.$2;
      final desc     = bind?.$1;
      rowEl.append(_buildKey(label, desc, category, px));
    }
    return rowEl;
  }

  static html.DivElement _buildKey(
      String label, String? desc, String? category, int widthPx) {
    final (bg, border, bb, fg) = switch (category) {
      'flight' => ('#0A2040', '#0066AA', '#003366', '#00AAFF'),
      'action' => ('#1A1800', '#554400', '#221100', '#FFCC00'),
      'ui'     => ('#001A0A', '#004422', '#001108', '#44CC88'),
      'chat'   => ('#1A0A1A', '#440044', '#110011', '#CC44CC'),
      _        => ('#111826', '#1E2A3A', '#0A0F18', '#445566'),
    };

    final key = html.DivElement()
      ..style.cssText = 'display:flex;flex-direction:column;'
          'justify-content:${desc != null ? "space-between" : "center"};'
          'align-items:center;width:${widthPx}px;min-width:${widthPx}px;'
          'height:40px;padding:3px 2px 4px;box-sizing:border-box;'
          'background:$bg;border:1px solid $border;border-bottom:3px solid $bb;'
          'border-radius:3px;font-family:monospace;cursor:default;flex-shrink:0';

    if (desc != null) {
      key.append(html.SpanElement()
        ..text = desc
        ..style.cssText = 'font-size:6px;color:$fg;opacity:0.75;'
            'line-height:1.1;text-align:center;pointer-events:none;'
            'overflow:hidden;max-width:100%');
    }
    key.append(html.SpanElement()
      ..text = label
      ..style.cssText = 'font-size:${label.length > 3 ? "7" : "9"}px;'
          'font-weight:bold;color:$fg;line-height:1;pointer-events:none');

    return key;
  }

  static html.DivElement _buildLegend() {
    final legend = html.DivElement()
      ..style.cssText = 'display:flex;gap:16px;padding:8px 16px;'
          'border-top:1px solid #1E2A3A;flex-shrink:0';

    for (final (label, color) in [
      ('FLIGHT', '#00AAFF'), ('ACTION BAR', '#FFCC00'),
      ('UI / SYSTEMS', '#44CC88'), ('CHAT', '#CC44CC'),
    ]) {
      final dot = html.DivElement()
        ..style.cssText = 'width:8px;height:8px;border-radius:2px;'
            'background:$color;opacity:0.85;flex-shrink:0;margin-top:1px';
      final lbl = html.SpanElement()
        ..text = label
        ..style.cssText = 'font:9px monospace;color:#556677;letter-spacing:1px';
      final item = html.DivElement()
        ..style.cssText = 'display:flex;align-items:center;gap:5px';
      item..append(dot)..append(lbl);
      legend.append(item);
    }
    return legend;
  }
}
