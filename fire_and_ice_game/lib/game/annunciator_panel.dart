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

// 18 non-interactive lights (5×4 grid; first row uses 2 interactive + 3 here).
// ENGINE FIRE replaced by the interactive L/R engine fire lights below.
// MANA EMPTY dropped (covered by ICE LOW + CRYO PRESS).
final List<_Light> _lights = [

  // ── Row 0 trailing 3 — RED critical ──────────────────────────────────────
  _Light('CRYO',  'RUPT',   _red,    (s) => s.mana < 5),
  _Light('HULL',  'BREACH', _red,    (s) => s.health < 30),
  _Light('OVER',  'TEMP',   _red,    (s) => s.health < 50),

  // ── Row 1 — AMBER warning ─────────────────────────────────────────────────
  _Light('ICE',   'LOW',    _amber,  (s) => s.mana < 25 && s.mana > 5),
  _Light('CRYO',  'PRESS',  _amber,  (s) => s.mana < 40 && s.mana >= 25),
  _Light('STALL', 'WARN',   _amber,  (s) => s.isStalling),
  _Light('PITCH', 'LIMIT',  _amber,  (s) => s.flightPitchAngle.abs() > 70),
  _Light('BANK',  'ANGLE',  _amber,  (s) => s.flightBankAngle.abs() > 50),

  // ── Row 2 — YELLOW caution ────────────────────────────────────────────────
  _Light('FIRE',  'PROX',   _yellow,
      (s) => (s.flightAltitude - s.terrainHeight) < 6 && s.gameMode != GameMode.taxi),
  _Light('THRST', 'VEC',    _yellow, (s) => s.isBarrelRolling),
  _Light('WING',  'ICE',    _yellow, (s) => s.flightBankAngle.abs() > 40 && !s.isBarrelRolling),
  _Light('SENS',  'OVR',    _yellow, (s) => s.isBarrelRolling && s.mana < 60),
  _Light('GPWS',  'WARN',   _yellow, (s) => s.isGpwsActive && s.gameMode != GameMode.taxi),

  // ── Row 3 — Gear / mode status ────────────────────────────────────────────
  _Light('GEAR',  'UNSAFE', _red,    (s) => s.gameMode == GameMode.flight && s.gearDeployed),
  _Light('GEAR',  'TRANS',  _amber,  (s) => s.gearMoving),
  _Light('GEAR',  'DOWN',   _yellow,
      (s) => s.gameMode == GameMode.landing && s.gearDeployed && !s.gearMoving),
  _Light('V1',    'ROTATE', _yellow,
      (s) => s.gameMode == GameMode.taxi && s.groundSpeed >= s.cfgLiftoffSpeed * 0.85),
  _Light('TAXI',  'MODE',   _yellow, (s) => s.gameMode == GameMode.taxi),
];

// ── Public widget ─────────────────────────────────────────────────────────────

/// 5 × 4 annunciator panel.
/// Row 0: L-ENG FIRE (interactive) | R-ENG FIRE (interactive) | 3 regular lights
/// Rows 1–3: 5 regular lights each.
Widget buildAnnunciatorPanel(GameState state, {VoidCallback? onChanged}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Row 0: interactive engine-fire pair + 3 regulars
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EngineFireLight(
            isLeft:     true,
            fireActive: state.engineFireL,
            shieldOpen: state.halonShieldL,
            halonFired: state.halonFiredL,
            onTapLight:    onChanged == null ? null : () { state.tapEngineFire(true);  onChanged(); },
            onCloseShield: onChanged == null ? null : () { state.lowerShield(true);    onChanged(); },
          ),
          _EngineFireLight(
            isLeft:     false,
            fireActive: state.engineFireR,
            shieldOpen: state.halonShieldR,
            halonFired: state.halonFiredR,
            onTapLight:    onChanged == null ? null : () { state.tapEngineFire(false); onChanged(); },
            onCloseShield: onChanged == null ? null : () { state.lowerShield(false);   onChanged(); },
          ),
          for (int col = 0; col < 3; col++)
            _cell(_lights[col], _lights[col].check(state)),
        ],
      ),
      // Rows 1–3: regular lights
      for (int row = 1; row < 4; row++) ...[
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (col) {
            final idx = (row - 1) * 5 + col + 3;
            return _cell(_lights[idx], _lights[idx].check(state));
          }),
        ),
      ],
    ],
  );
}

// ── Cell dimensions (match OSB buttons) ──────────────────────────────────────

const double _w = 38;
const double _h = 28;

// ── Interactive engine-fire light with glass shield ───────────────────────────

class _EngineFireLight extends StatefulWidget {
  final bool isLeft;
  final bool fireActive;
  final bool shieldOpen;
  final bool halonFired;
  final VoidCallback? onTapLight;    // first tap: open shield; second: fire halon
  final VoidCallback? onCloseShield; // tap the flipped-up guard tab to close it

  const _EngineFireLight({
    required this.isLeft,
    required this.fireActive,
    required this.shieldOpen,
    required this.halonFired,
    this.onTapLight,
    this.onCloseShield,
  });

  @override
  State<_EngineFireLight> createState() => _EngineFireLightState();
}

class _EngineFireLightState extends State<_EngineFireLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.shieldOpen ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_EngineFireLight old) {
    super.didUpdateWidget(old);
    if (widget.shieldOpen != old.shieldOpen) {
      if (widget.shieldOpen) _ctrl.forward(); else _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final label = widget.isLeft ? 'L-ENG' : 'R-ENG';
    final Color fg, bg, bord;
    if (widget.halonFired) {
      fg   = const Color(0xFF00BB55);
      bg   = const Color(0xFF001A0C);
      bord = const Color(0xFF00BB55).withValues(alpha: 0.7);
    } else if (widget.fireActive) {
      fg   = _red;
      bg   = _red.withValues(alpha: 0.15);
      bord = _red.withValues(alpha: 0.80);
    } else {
      fg   = const Color(0xFF1C1C28);
      bg   = const Color(0xFF0A0A12);
      bord = const Color(0xFF1E1E2C);
    }

    return Container(
      width: _w, height: _h,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // Shield slides from full height (closed) down to a 4px guard tab (open).
          const tab     = 4.0;
          final shieldH = tab + (_h - tab) * (1.0 - _ctrl.value);
          final closed  = _ctrl.value < 0.5;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Fire light — only tappable when shield is open
              GestureDetector(
                onTap: widget.shieldOpen ? widget.onTapLight : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(
                        color: bord, width: widget.fireActive ? 1.0 : 0.5),
                    boxShadow: widget.fireActive
                        ? [BoxShadow(
                            color: _red.withValues(alpha: 0.3), blurRadius: 4)]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, textAlign: TextAlign.center,
                          style: TextStyle(color: fg, fontSize: 6.5,
                              fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                      Text(widget.halonFired ? 'OUT' : 'FIRE',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fg, fontSize: 6.5,
                              fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ),
              // Glass shield guard
              // When closed: covers full cell → tap = open shield (via onTapLight logic)
              // When open:   4px tab at top → tap = close shield
              Positioned(
                top: 0, left: 0, right: 0, height: shieldH,
                child: GestureDetector(
                  onTap: closed ? widget.onTapLight : widget.onCloseShield,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003344)
                          .withValues(alpha: closed ? 0.88 : 0.45),
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFF0099BB).withValues(alpha: 0.8),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: closed && shieldH > 14
                        ? const Text('SAFE',
                            style: TextStyle(
                              color: Color(0xFF00CCDD),
                              fontSize: 5.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ))
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Regular (non-interactive) cell ────────────────────────────────────────────

Widget _cell(_Light light, bool active) {
  final Color fg     = active ? light.color : const Color(0xFF1C1C28);
  final Color bg     = active ? light.color.withValues(alpha: 0.15) : const Color(0xFF0A0A12);
  final Color border = active ? light.color.withValues(alpha: 0.80) : const Color(0xFF1E1E2C);

  return Container(
    width: _w, height: _h,
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
        Text(light.line1, textAlign: TextAlign.center,
            style: TextStyle(color: fg, fontSize: 6.5,
                fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        Text(light.line2, textAlign: TextAlign.center,
            style: TextStyle(color: fg, fontSize: 6.5,
                fontWeight: FontWeight.bold, letterSpacing: 0.3)),
      ],
    ),
  );
}
