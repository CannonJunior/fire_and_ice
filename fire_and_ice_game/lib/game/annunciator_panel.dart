import 'package:flutter/material.dart';
import 'game_state.dart';

// ── Light data model ──────────────────────────────────────────────────────────

class _Light {
  final String line1;
  final String line2;
  final Color  color;
  final bool Function(GameState) check;
  const _Light(this.line1, this.line2, this.color, this.check);
}

const _red    = Color(0xFFFF2222);
const _amber  = Color(0xFFFF8800);
const _yellow = Color(0xFFFFDD00);

// 15 lights, row-major (5 per row × 3 rows).
// Sized and styled to match the OSB buttons (38 × 28 px each).
//
// RED    – Immediate action: flight safety or weapon system failure.
// AMBER  – Warning: abnormal condition, investigate soon.
// YELLOW – Caution: advisory / awareness.
final List<_Light> _lights = [

  // ── Row 1 — RED critical ──────────────────────────────────────────────────
  _Light('ENGINE', 'FIRE',   _red,    (s) => s.health < 20),
  _Light('CRYO',   'RUPT',   _red,    (s) => s.mana < 5),
  _Light('HULL',   'BREACH', _red,    (s) => s.health < 30),
  _Light('OVER',   'TEMP',   _red,    (s) => s.health < 50),
  _Light('MANA',   'EMPTY',  _red,    (s) => s.mana <= 0),

  // ── Row 2 — AMBER warning ─────────────────────────────────────────────────
  _Light('ICE',    'LOW',    _amber,  (s) => s.mana < 25 && s.mana > 5),
  _Light('CRYO',   'PRESS',  _amber,  (s) => s.mana < 40 && s.mana >= 25),
  _Light('STALL',  'WARN',   _amber,  (s) => s.isStalling),
  _Light('PITCH',  'LIMIT',  _amber,  (s) => s.flightPitchAngle.abs() > 70),
  _Light('BANK',   'ANGLE',  _amber,  (s) => s.flightBankAngle.abs() > 50),

  // ── Row 3 — YELLOW caution ────────────────────────────────────────────────
  _Light('FIRE',   'PROX',   _yellow, (s) => (s.flightAltitude - s.terrainHeight) < 6 && s.gameMode != GameMode.taxi),
  _Light('THRST',  'VEC',    _yellow, (s) => s.isBarrelRolling),
  _Light('WING',   'ICE',    _yellow, (s) => s.flightBankAngle.abs() > 40 && !s.isBarrelRolling),
  _Light('SENS',   'OVR',    _yellow, (s) => s.isBarrelRolling && s.mana < 60),
  _Light('GPWS',   'WARN',   _yellow, (s) => s.isGpwsActive && s.gameMode != GameMode.taxi),

  // ── Row 4 — Gear / mode status ────────────────────────────────────────────
  _Light('GEAR',   'UNSAFE', _red,    (s) => s.gameMode == GameMode.flight && s.gearDeployed),
  _Light('GEAR',   'TRANS',  _amber,  (s) => s.gearMoving),
  _Light('GEAR',   'DOWN',   _yellow, (s) => s.gameMode == GameMode.landing && s.gearDeployed && !s.gearMoving),
  _Light('V1',     'ROTATE', _yellow, (s) => s.gameMode == GameMode.taxi && s.groundSpeed >= s.cfgLiftoffSpeed * 0.85),
  _Light('TAXI',   'MODE',   _yellow, (s) => s.gameMode == GameMode.taxi),
];

// ── Public widget ─────────────────────────────────────────────────────────────

/// Compact 5 × 4 annunciator panel (rows 1-3 standard, row 4 gear/mode).
Widget buildAnnunciatorPanel(GameState state) {
  final rowCount = (_lights.length / 5).ceil();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (int row = 0; row < rowCount; row++) ...[
        if (row > 0) const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (col) {
            final idx = row * 5 + col;
            if (idx >= _lights.length) return const SizedBox(width: 42, height: 28);
            final light = _lights[idx];
            return _cell(light, light.check(state));
          }),
        ),
      ],
    ],
  );
}

// ── Individual cell ───────────────────────────────────────────────────────────

// Match OSB dimensions exactly.
const double _w = 38;
const double _h = 28;

Widget _cell(_Light light, bool active) {
  final Color fg     = active ? light.color : const Color(0xFF1C1C28);
  final Color bg     = active ? light.color.withValues(alpha: 0.15) : const Color(0xFF0A0A12);
  final Color border = active ? light.color.withValues(alpha: 0.80) : const Color(0xFF1E1E2C);

  return Container(
    width: _w,
    height: _h,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: bg,
      border: Border.all(color: border, width: active ? 1.0 : 0.5),
      boxShadow: active
          ? [BoxShadow(color: light.color.withValues(alpha: 0.3), blurRadius: 4)]
          : null,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          light.line1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: 6.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          light.line2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: 6.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}
