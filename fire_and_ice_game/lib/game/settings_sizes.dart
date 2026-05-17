import 'package:flutter/material.dart';
import 'settings_state.dart';

// ── Element catalogue ─────────────────────────────────────────────────────────

// (elementId, display label, isCircular)
const _kElements = [
  ('flaps',        'Flaps',         false),
  ('gear',         'Gear',          false),
  ('throttle',     'Throttle',      false),
  ('tq',           'Throttle Quad', false),
  ('alt',          'Altimeter',     false),
  ('aoa',          'AoA',           true),
  ('fireProx',     'Fire Prox',     true),
  ('suppression',  'Suppression',   false),
  ('centerMfd',    'Centre MFD',    false),
  ('annunciator',  'Annunciator',   false),
  ('attitudeGyro', 'Gyro',          false),
  ('leftMfd',      'Left MFD',      false),
  ('rightMfd',     'Right MFD',     false),
  ('auxDisp',      'Aux Display',   false),
];

// ── Palette (matches settings_panel) ─────────────────────────────────────────

const _kText   = Color(0xFFCCDDEE);
const _kDim    = Color(0xFF556677);
const _kAccent = Color(0xFF00AAFF);
const _kBg2    = Color(0xFF111120);

// ── Public widget ─────────────────────────────────────────────────────────────

/// Body of the COCKPIT SIZES settings section.
///
/// Lists every draggable cockpit element with +/− steppers for width and height
/// scale (or a single uniform scale for circular elements).  Drag-to-resize on
/// the cockpit is the primary interaction; this panel lets the user make precise
/// adjustments and reset individual elements.
class CockpitSizesBody extends StatelessWidget {
  final SettingsState settings;
  final VoidCallback  onChanged;

  const CockpitSizesBody({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final aid = settings.selectedAircraft;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Reset-all button
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Row(children: [
          const Text('All elements', style: TextStyle(color: _kDim, fontSize: 10)),
          const Spacer(),
          _Btn('Reset All Sizes', () {
            settings.resetAllCockpitSizes(aid);
            settings.save();
            onChanged();
          }),
        ]),
      ),
      const Divider(color: Color(0xFF1E2A3A), height: 1),
      // Per-element rows
      for (final (id, label, circular) in _kElements)
        _SizeRow(
          label:      label,
          scale:      settings.cockpitScale(aid, id),
          isCircular: circular,
          onChanged:  (sx, sy) {
            settings.setCockpitScale(aid, id, sx, sy);
            settings.save();
            onChanged();
          },
          onReset: () {
            settings.resetCockpitSize(aid, id);
            settings.save();
            onChanged();
          },
        ),
    ]);
  }
}

// ── Row per element ───────────────────────────────────────────────────────────

class _SizeRow extends StatelessWidget {
  final String label;
  final (double, double) scale;
  final bool isCircular;
  final void Function(double, double) onChanged;
  final VoidCallback onReset;

  const _SizeRow({
    required this.label, required this.scale,
    required this.isCircular,
    required this.onChanged, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const step = 0.1, min = 0.3, max = 5.0;
    final sx = scale.$1, sy = scale.$2;
    final atDefault = (sx - 1.0).abs() < 0.01 && (sy - 1.0).abs() < 0.01;

    return Container(
      color: atDefault ? Colors.transparent : _kBg2.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(children: [
        SizedBox(width: 76,
          child: Text(label,
            style: const TextStyle(color: _kText, fontSize: 10),
            overflow: TextOverflow.ellipsis)),
        if (isCircular) ...[
          _lbl('×'),
          _step('−', () => onChanged(_clamp(sx - step, min, max), _clamp(sx - step, min, max))),
          _val(sx.toStringAsFixed(1)),
          _step('+', () => onChanged(_clamp(sx + step, min, max), _clamp(sx + step, min, max))),
        ] else ...[
          _lbl('W'),
          _step('−', () => onChanged(_clamp(sx - step, min, max), sy)),
          _val(sx.toStringAsFixed(1)),
          _step('+', () => onChanged(_clamp(sx + step, min, max), sy)),
          const SizedBox(width: 6),
          _lbl('H'),
          _step('−', () => onChanged(sx, _clamp(sy - step, min, max))),
          _val(sy.toStringAsFixed(1)),
          _step('+', () => onChanged(sx, _clamp(sy + step, min, max))),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onReset,
          child: Text('↺',
            style: TextStyle(
              color: atDefault
                  ? _kDim.withValues(alpha: 0.4)
                  : _kAccent,
              fontSize: 14)),
        ),
      ]),
    );
  }

  static double _clamp(double v, double mn, double mx) => v.clamp(mn, mx);

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(right: 2),
    child: Text(t, style: const TextStyle(color: _kDim, fontSize: 9)));

  Widget _val(String t) => SizedBox(
    width: 30,
    child: Text(t, textAlign: TextAlign.center,
      style: const TextStyle(color: _kText, fontSize: 10, fontFamily: 'monospace')));

  Widget _step(String t, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(2)),
      child: Center(child: Text(t,
        style: const TextStyle(
          color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold)))));
}

// ── Small labelled button ─────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Btn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(3)),
      child: Text(label,
        style: const TextStyle(color: _kAccent, fontSize: 9,
            fontWeight: FontWeight.bold))));
}
