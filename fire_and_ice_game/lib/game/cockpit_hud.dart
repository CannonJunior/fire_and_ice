import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'hud_widgets.dart' as hud;
import 'mfd_panels.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _kPanelBg  = Color(0xFF141418);
const _kBevel    = Color(0xFF30303C);
const _kOsbBg    = Color(0xFF1A1A22);
const _kOsbBrd   = Color(0xFF3C3C4C);
const _kOsbTxt   = Color(0xFF6A6A8A);
const _kOsbActBrd = Color(0xFFAAAAAA);
const _kOsbActTxt = Color(0xFFCCCCFF);
const _kWarn     = Color(0xFFFF6600);
const _kHudGreen = Color(0xFF00FF88);
const _kHudDim   = Color(0xFF006644);

// ── Public entry ──────────────────────────────────────────────────────────────

/// Build the active HUD, switching between cockpit and third-person modes.
///
/// - **Cockpit** (`ViewMode.cockpit`): full instrument panel + windshield overlay.
/// - **Third-person** (`ViewMode.thirdPerson`): minimal game HUD with action bar.
///
/// [onAbilityActivate] fires with the slot index when an ability OSB is tapped.
Widget buildCockpitHud(
  GameState state, {
  void Function(int index)? onAbilityActivate,
  void Function(int page)?  onLeftPage,
  void Function(int page)?  onRightPage,
  VoidCallback?             onMapZoom,
}) {
  if (state.viewMode == ViewMode.thirdPerson) {
    return Stack(children: [
      hud.buildHud(state),
      Positioned(top: 12, right: 12, child: _viewBadge('🎮 3RD PERSON')),
    ]);
  }

  return Stack(children: [
    IgnorePointer(child: _windshieldHud(state)),
    Align(
      alignment: Alignment.bottomCenter,
      child: _cockpitPanel(state,
          onAbilityActivate: onAbilityActivate,
          onLeftPage: onLeftPage,
          onRightPage: onRightPage,
          onMapZoom: onMapZoom),
    ),
    Positioned(top: 12, right: 12, child: _viewBadge('👁 COCKPIT')),
  ]);
}

/// Small top-right badge showing the active view mode (Tab to toggle).
Widget _viewBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFF334455)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Color(0xFF80DDFF), fontSize: 9, letterSpacing: 1),
    ),
  );
}

// ── Windshield HUD (glass overlay) ────────────────────────────────────────────

Widget _windshieldHud(GameState state) {
  return Stack(children: [
    // Speed readout — left edge, vertically centred in windshield area
    Positioned(left: 24, top: 0, bottom: 300,
        child: Center(child: _hudReadout('SPD',
            state.flightSpeed.toStringAsFixed(1), 'u/s'))),
    // Altitude readout — right edge
    Positioned(right: 24, top: 0, bottom: 300,
        child: Center(child: _hudReadout('ALT',
            state.flightAltitude.toStringAsFixed(1), 'm'))),
    // Heading / pitch strip — top centre
    Align(
      alignment: const Alignment(0, -0.80),
      child: _headingStrip(state),
    ),
    // Centre reticle
    Align(
      alignment: const Alignment(0, -0.10),
      child: CustomPaint(painter: _ReticlePainter(), size: const Size(60, 60)),
    ),
    // Barrel-roll warning
    if (state.isBarrelRolling)
      Align(
        alignment: const Alignment(0, -0.30),
        child: const Text('◀  BARREL ROLL  ▶',
            style: TextStyle(
              color: _kWarn, fontSize: 18,
              fontWeight: FontWeight.bold, letterSpacing: 4,
            )),
      ),
  ]);
}

Widget _hudReadout(String label, String value, String unit) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: _kHudGreen.withValues(alpha: 0.4), width: 1),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: _kHudGreen.withValues(alpha: 0.6), fontSize: 8)),
      Text(value,  style: const TextStyle(color: _kHudGreen, fontSize: 14, fontWeight: FontWeight.bold)),
      Text(unit,   style: const TextStyle(color: _kHudDim, fontSize: 8)),
    ]),
  );
}

Widget _headingStrip(GameState state) {
  final hdg = ((state.playerRotation.y % 360) + 360) % 360;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: _kHudGreen.withValues(alpha: 0.4), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('HDG ', style: const TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${hdg.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      const Text('   PCH ', style: TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${state.flightPitchAngle.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      const Text('   BNK ', style: TextStyle(color: _kHudDim, fontSize: 8)),
      Text('${state.flightBankAngle.toStringAsFixed(0)}°',
          style: const TextStyle(color: _kHudGreen, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()..style = PaintingStyle.stroke;
    // Dim outer ring
    canvas.drawCircle(c, 24, stroke..color = _kHudDim..strokeWidth = 1);
    // Inner dot
    canvas.drawCircle(c, 2.5,
        Paint()..color = _kHudGreen..style = PaintingStyle.fill);
    // Cross hairs
    stroke.color = _kHudGreen; stroke.strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx - 30, c.dy), Offset(c.dx - 10, c.dy), stroke);
    canvas.drawLine(Offset(c.dx + 10, c.dy), Offset(c.dx + 30, c.dy), stroke);
    canvas.drawLine(Offset(c.dx, c.dy - 30), Offset(c.dx, c.dy - 10), stroke);
    canvas.drawLine(Offset(c.dx, c.dy + 10), Offset(c.dx, c.dy + 30), stroke);
  }

  @override
  bool shouldRepaint(_ReticlePainter _) => false;
}

// ── Cockpit Panel ─────────────────────────────────────────────────────────────

Widget _cockpitPanel(GameState state, {
  void Function(int)? onAbilityActivate,
  void Function(int)? onLeftPage,
  void Function(int)? onRightPage,
  VoidCallback?       onMapZoom,
}) {
  final lp = state.leftMfdPage;
  final rp = state.rightMfdPage;
  return Container(
    decoration: BoxDecoration(
      color: _kPanelBg,
      border: Border(top: BorderSide(color: _kBevel, width: 2)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Left MFD column
        Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: _osbRow([
            _Osb('ELMT', active: lp == 0, onTap: () => onLeftPage?.call(0)),
            _Osb('ABLT', active: lp == 1, onTap: () => onLeftPage?.call(1)),
            _Osb('STAT', active: lp == 2, onTap: () => onLeftPage?.call(2)),
            _Osb('MODE', active: lp == 3, onTap: () => onLeftPage?.call(3)),
          ])),
          const SizedBox(height: 4),
          buildLeftMFD(state, page: lp),
          const SizedBox(height: 4),
          Center(child: _abilityOsbRow(state, onAbilityActivate)),
        ]),
        const SizedBox(width: 20),
        // Center column
        Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 32),
          buildCenterMFD(state),
          const SizedBox(height: 4),
          _centerButtonCluster(),
        ]),
        const SizedBox(width: 20),
        // Right MFD column
        Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: _osbRow([
            _Osb('NAV',  active: rp == 0, onTap: () => onRightPage?.call(0)),
            _Osb('TERR', active: rp == 1, onTap: () => onRightPage?.call(1)),
            _Osb('TGT',  active: rp == 2, onTap: () => onRightPage?.call(2)),
            _Osb('MARK', active: rp == 3, onTap: () => onRightPage?.call(3)),
          ])),
          const SizedBox(height: 4),
          buildRightMFD(state, page: rp),
          const SizedBox(height: 4),
          Center(child: _osbRow([
            _Osb('ZOOM', onTap: onMapZoom),
            _Osb('AUTO'),
            _Osb('LOCK'),
            _Osb('CLR'),
          ])),
        ]),
      ]),
    ),
  );
}

// ── OSB helpers ───────────────────────────────────────────────────────────────

class _Osb {
  final String label;
  final bool active;
  final bool alert;
  final VoidCallback? onTap;
  _Osb(this.label, {this.active = false, this.alert = false, this.onTap});
}

Widget _osbRow(List<_Osb> buttons) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: buttons.map((b) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _osbButton(b),
    )).toList(),
  );
}

Widget _osbButton(_Osb b) {
  final borderColor = b.alert ? _kWarn : (b.active ? _kOsbActBrd : _kOsbBrd);
  final textColor   = b.alert ? _kWarn : (b.active ? _kOsbActTxt : _kOsbTxt);
  return GestureDetector(
    onTap: b.onTap,
    child: Container(
      width: 38, height: 28,
      decoration: BoxDecoration(
        color: _kOsbBg,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(child: Text(
        b.label,
        style: TextStyle(
          color: textColor, fontSize: 7.5,
          fontWeight: FontWeight.bold, letterSpacing: 0.5,
        ),
      )),
    ),
  );
}

/// Bottom OSB row for the left MFD, wired to ability slot activation.
Widget _abilityOsbRow(GameState state, void Function(int)? onActivate) {
  final osbs = List.generate(math.min(state.abilities.length, 4), (i) {
    final ab    = state.abilities[i];
    final cd    = state.abilityCooldowns[ab.name] ?? 0.0;
    final ready = cd <= 0.0;
    final label = _abilityOsbLabel(ab.name);
    return _Osb(
      label,
      active: ready,
      alert: !ready,
      onTap: ready ? () => onActivate?.call(i) : null,
    );
  });
  while (osbs.length < 4) osbs.add(_Osb('----'));
  return _osbRow(osbs);
}

/// Derive a ≤4-char OSB label from an ability name.
///
/// Prefers the first word when it is 4+ characters (e.g. "Fire" → "FIRE"),
/// otherwise falls back to the last word (e.g. "Ice" → "NOVA").
String _abilityOsbLabel(String name) {
  final parts = name.split(' ');
  final word  = (parts.first.length >= 4) ? parts.first : parts.last;
  return word.substring(0, math.min(4, word.length)).toUpperCase();
}

/// 2×4 grid of small system buttons in the centre console.
Widget _centerButtonCluster() {
  const row1 = ['SYS', 'PWR', 'FLGT', 'WPNS'];
  const row2 = ['CONF', 'AUTO', 'RDY ', 'RST '];
  return Column(mainAxisSize: MainAxisSize.min, children: [
    Row(mainAxisSize: MainAxisSize.min, children: row1.map(_smallBtn).toList()),
    const SizedBox(height: 3),
    Row(mainAxisSize: MainAxisSize.min, children: row2.map(_smallBtn).toList()),
  ]);
}

Widget _smallBtn(String label) {
  return Container(
    width: 28, height: 22,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(
      color: const Color(0xFF181820),
      border: Border.all(color: const Color(0xFF383848), width: 1),
    ),
    child: Center(child: Text(
      label.trim(),
      style: const TextStyle(
        color: Color(0xFF505070), fontSize: 5.5, fontWeight: FontWeight.bold,
      ),
    )),
  );
}
