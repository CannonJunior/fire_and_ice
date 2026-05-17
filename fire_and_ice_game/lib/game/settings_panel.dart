import 'package:flutter/material.dart';
import 'aircraft_config.dart';
import 'settings_state.dart';
import 'test_status_widget.dart';

// ── Palette (matches cockpit instrument aesthetic) ────────────────────────────

const _kBg      = Color(0xFF0A0A14);
const _kBg2     = Color(0xFF111120);
const _kBorder  = Color(0xFF1E2A3A);
const _kAccent  = Color(0xFF00AAFF);
const _kDimBlue = Color(0xFF003366);
const _kText    = Color(0xFFCCDDEE);
const _kDim     = Color(0xFF556677);

// ── Public widget ─────────────────────────────────────────────────────────────

/// Settings overlay panel — modelled after the Green dashboard settings pattern.
///
/// Five collapsible sections: Flight, Camera, HUD, Controls, and Key Bindings.
/// All changes call [onChanged] immediately so the caller can apply them to
/// the live game state without waiting for the panel to close.
class SettingsPanel extends StatefulWidget {
  final SettingsState settings;
  final VoidCallback   onClose;

  /// Called every time any setting value changes.  The caller should call
  /// [SettingsState.save], [SettingsState.applyFlight], and
  /// [SettingsState.applyCamera] in response.
  final VoidCallback   onChanged;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onClose,
    required this.onChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  // Track which sections are open — aircraft expanded by default.
  final Map<String, bool> _open = {
    'aircraft': true,
    'flight':   false,
    'camera':   false,
    'hud':      false,
    'controls': false,
    'bindings': false,
    'tests':    false,
  };

  SettingsState get s => widget.settings;

  void _changed() => widget.onChanged();

  void _toggle(String key) => setState(() => _open[key] = !(_open[key] ?? false));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: _kBg,
          border: Border.all(color: _kBorder, width: 1),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Section('AIRCRAFT',     'aircraft', _open['aircraft']!, _toggle, _aircraftBody()),
                    _Section('FLIGHT',       'flight',   _open['flight']!,   _toggle, _flightBody()),
                    _Section('CAMERA',       'camera',   _open['camera']!,   _toggle, _cameraBody()),
                    _Section('HUD',          'hud',      _open['hud']!,      _toggle, _hudBody()),
                    _Section('CONTROLS',     'controls', _open['controls']!, _toggle, _controlsBody()),
                    _Section('KEY BINDINGS', 'bindings', _open['bindings']!, _toggle, _bindingsBody()),
                    _Section('TEST STATUS',  'tests',    _open['tests']!,    _toggle, const TestStatusWidget()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel header ────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          const Text('⚙  SETTINGS',
              style: TextStyle(color: _kAccent, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: const Text('✕',
                style: TextStyle(color: _kDim, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Aircraft section ────────────────────────────────────────────────────────

  Widget _aircraftBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: s.aircraftConfigs.map((cfg) => _aircraftCard(cfg)).toList(),
      ),
    );
  }

  Widget _aircraftCard(AircraftConfig cfg) {
    final selected = s.selectedAircraft == cfg.id;
    return GestureDetector(
      onTap: () {
        setState(() { s.selectedAircraft = cfg.id; });
        _changed();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:  selected ? _kDimBlue : const Color(0xFF0E0E1C),
          border: Border.all(
            color: selected ? _kAccent : _kBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Text(cfg.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cfg.displayName, style: TextStyle(
                color: selected ? _kAccent : _kText,
                fontSize: 12, fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 2),
              Text(cfg.description,
                  style: const TextStyle(color: _kDim, fontSize: 9)),
            ],
          )),
          if (selected)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('✓', style: TextStyle(
                  color: _kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }

  // ── Flight section ──────────────────────────────────────────────────────────

  Widget _flightBody() => Column(mainAxisSize: MainAxisSize.min, children: [
    _SliderRow('Flight Speed',    s.flightSpeed,    3.0,  15.0, '%.1f u/s', (v) { s.flightSpeed    = v; _changed(); }),
    _SliderRow('Pitch Rate',      s.pitchRate,      30,   120,  '%.0f °/s', (v) { s.pitchRate      = v; _changed(); }),
    _SliderRow('Bank Rate',       s.bankRate,       60,   240,  '%.0f °/s', (v) { s.bankRate       = v; _changed(); }),
    _SliderRow('Boost ×',         s.boostMultiplier,1.1,  2.5,  '%.1f×',   (v) { s.boostMultiplier= v; _changed(); }),
    _SliderRow('Barrel Roll',     s.barrelRollRate, 180,  720,  '%.0f °/s', (v) { s.barrelRollRate = v; _changed(); }),
    _ToggleRow('Inverted Pitch',  s.invertedPitch,  (v) { s.invertedPitch = v; _changed(); },
        hint: 'W climbs / S dives'),
  ]);

  // ── Camera section ──────────────────────────────────────────────────────────

  Widget _cameraBody() => Column(mainAxisSize: MainAxisSize.min, children: [
    _ToggleRow('Default Cockpit View', s.defaultCockpit, (v) { s.defaultCockpit = v; _changed(); },
        hint: 'Start in cockpit mode'),
    _SliderRow('Distance', s.cameraDistance, 5.0, 20.0, '%.0f u',  (v) { s.cameraDistance = v; _changed(); }),
    _SliderRow('Height',   s.cameraHeight,   1.0, 10.0, '%.1f u',  (v) { s.cameraHeight   = v; _changed(); }),
  ]);

  // ── HUD section ─────────────────────────────────────────────────────────────

  Widget _hudBody() => Column(mainAxisSize: MainAxisSize.min, children: [
    _ToggleRow('Annunciator Panel', s.showAnnunciator, (v) { s.showAnnunciator = v; _changed(); },
        hint: 'Master-warning lights above Flight Data'),
    _ToggleRow('Flight Telemetry', s.showTelemetry, (v) { s.showTelemetry = v; _changed(); },
        hint: 'ALT / SPD / PCH / BNK readout'),
    _ToggleRow('Action Bar',       s.showActionBar, (v) { s.showActionBar = v; _changed(); },
        hint: 'Ability hotbar (3rd-person mode)'),
    _ToggleRow('Tutorial Labels',  s.showTutorial,  (v) { s.showTutorial  = v; _changed(); },
        hint: 'Show explainer tooltips on every UI element'),
    _ToggleRow('Draggable Cockpit', s.cockpitDraggable, (v) { s.cockpitDraggable = v; _changed(); },
        hint: 'Drag grip appears on each cockpit group to reposition it'),
    _ToggleRow('Element Info',      s.showCockpitInfo,  (v) { s.showCockpitInfo  = v; _changed(); },
        hint: 'Show name, position offset, and FIXED / DRAG state per group'),
    _RestoreLayoutRow(
      aircraftName: s.aircraftConfigs
          .firstWhere((a) => a.id == s.selectedAircraft,
              orElse: () => s.aircraftConfigs.first)
          .displayName,
      onRestore: () {
        s.resetCockpitLayout(s.selectedAircraft);
        s.save();
        _changed();
      },
    ),
  ]);

  // ── Controls section ────────────────────────────────────────────────────────

  Widget _controlsBody() => Column(mainAxisSize: MainAxisSize.min, children: [
    _InfoRow('Movement', 'W/S  A/D  Q/E'),
    _InfoRow('Barrel roll', 'Q+A  or  E+D'),
    _InfoRow('Boost / brake', 'Alt  /  Space'),
    _InfoRow('View toggle', 'Tab'),
    _InfoRow('Ability slots', '1 – 0'),
    _InfoRow('Throttle', ']  /  ['),
    _InfoRow('Landing gear', 'G'),
    _InfoRow('Flaps cycle', 'F'),
  ]);

  // ── Key bindings (detailed read-only) ───────────────────────────────────────

  Widget _bindingsBody() {
    final rows = [
      // Flight
      ('W',           'Pitch nose down (dive)',     false),
      ('S',           'Pitch nose up (climb)',       false),
      ('A',           'Yaw left + bank-turn',        false),
      ('D',           'Yaw right + bank-turn',       false),
      ('Q',           'Bank left only',              false),
      ('E',           'Bank right only',             false),
      ('Q + A',       'Barrel roll left',            false),
      ('E + D',       'Barrel roll right',           false),
      ('Alt',         '1.5× speed boost',            false),
      ('Space',       'Air brake + altitude bump',   false),
      // UI
      ('Tab',         'Cockpit ↔ 3rd-person view',   false),
      ('1 – 0',       'Activate ability slots',       false),
      (']',           'Throttle up',                 false),
      ('[',           'Throttle down',               false),
      ('G',           'Landing gear up / down',      false),
      ('F',           'Step flaps (bounces UP↔FULL)',   false),
      // Meta
      ('⚙  button',  'Open / close settings',       true),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((r) {
        final (key, desc, accent) = r;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent ? _kDimBlue : const Color(0xFF18202A),
                border: Border.all(color: accent ? _kAccent : _kBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(key,
                  style: TextStyle(
                    color: accent ? _kAccent : _kText,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(desc,
                style: const TextStyle(color: _kDim, fontSize: 10))),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Section widget ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String   title;
  final String   sectionKey;
  final bool     open;
  final void Function(String) onToggle;
  final Widget   body;

  const _Section(this.title, this.sectionKey, this.open, this.onToggle, this.body);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Section header (Green's .sp-section-hdr)
      GestureDetector(
        onTap: () => onToggle(sectionKey),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Text(title,
                style: const TextStyle(
                    color: _kDim, fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const Spacer(),
            AnimatedRotation(
              turns: open ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: const Text('▶',
                  style: TextStyle(color: _kDim, fontSize: 9)),
            ),
          ]),
        ),
      ),
      // Section body
      if (open)
        Container(
          color: _kBg2,
          child: body,
        ),
      // Separator
      Container(height: 1, color: _kBorder),
    ]);
  }
}

// ── Slider row ────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String   label;
  final double   value;
  final double   min;
  final double   max;
  final String   fmt;        // printf-style: '%.1f u/s'
  final ValueChanged<double> onChanged;

  const _SliderRow(this.label, this.value, this.min, this.max, this.fmt, this.onChanged);

  String _format(double v) {
    if (fmt.contains('.1f')) return v.toStringAsFixed(1) + fmt.substring(fmt.indexOf('f') + 1);
    return v.toStringAsFixed(0) + fmt.substring(fmt.indexOf('f') + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(color: _kText, fontSize: 11)),
            const Spacer(),
            Text(_format(value),
                style: const TextStyle(color: _kAccent, fontSize: 11,
                    fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   _kAccent,
              inactiveTrackColor: _kBorder,
              thumbColor:         _kAccent,
              overlayColor:       _kAccent.withValues(alpha: 0.15),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min, max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String   label;
  final bool     value;
  final ValueChanged<bool> onChanged;
  final String?  hint;

  const _ToggleRow(this.label, this.value, this.onChanged, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(color: _kText, fontSize: 11)),
            const Spacer(),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: _kAccent,
                activeTrackColor: _kDimBlue,
                inactiveThumbColor: _kDim,
                inactiveTrackColor: _kBorder,
              ),
            ),
          ]),
          if (hint != null)
            Text(hint!,
                style: const TextStyle(color: _kDim, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Info row (read-only label + value) ───────────────────────────────────────

// ── Restore cockpit layout row ────────────────────────────────────────────────

class _RestoreLayoutRow extends StatelessWidget {
  final String      aircraftName;
  final VoidCallback onRestore;
  const _RestoreLayoutRow({required this.aircraftName, required this.onRestore});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: Row(children: [
      Text('$aircraftName layout', style: const TextStyle(color: _kText, fontSize: 11)),
      const Spacer(),
      GestureDetector(
        onTap: onRestore,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:  const Color(0xFF1A0808),
            border: Border.all(color: const Color(0xFF664444)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text('Restore Defaults',
              style: TextStyle(color: Color(0xFFCC5555), fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );
}

// ── Info row (read-only label + value) ───────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: _kDim, fontSize: 10)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: _kText, fontSize: 10,
                fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
