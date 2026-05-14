import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'mfd_panels.dart';
import '../terrain/terrain_generator.dart';

// ── Palette (violet accent — distinct from green/blue MFDs) ──────────────────

const _kABg   = Color(0xFF0E0014);
const _kAFg   = Color(0xFFCC88FF);
const _kADim  = Color(0xFF441166);
const _kABord = Color(0xFF2A1040);

// Mirror option labels across both MFDs (L: 0-3, R: 4-7)
const _kOpts = ['ELMT', 'LOAD', 'STAT', 'MODE', 'NAV', 'TERR', 'FIRE', 'MARK'];

// Static radio log — shown on the CHAT page
const _kLog = [
  ('CTRL', 'Sector ALPHA cleared, no threats'),
  ('A-01', 'Copy, climbing to FL080'),
  ('CTRL', 'CAVOK, vis unrestricted'),
  ('A-01', 'Fire spotted — grid 347-128'),
  ('CTRL', 'Suppression authorized'),
  ('A-01', 'Dropping retardant — 85 % payload'),
  ('CTRL', 'Good spread. RTB on completion'),
  ('A-01', 'Copy, RTB in approx 14 min'),
];

// ── Public builder ────────────────────────────────────────────────────────────

/// Auxiliary display: 280×200 content + 28px bottom OSB row.
/// Pages: 0=CHAT  1=VID  2=MAP  3=MIRROR
Widget buildAuxDisplay(GameState state, {
  void Function(int)? onPage,
  void Function(int)? onMirrorScroll,
}) {
  final page = state.auxDisplayPage;
  final mi   = state.auxMirrorIndex.clamp(0, _kOpts.length - 1);

  // All modes share one fixed 280×200 viewport.
  // clipBehavior: Clip.hardEdge is critical for the VID page — the horizon
  // painter draws rectangles extending ±2× the canvas size; without clipping
  // they overflow the container and make the widget appear larger.
  final Widget pageContent = switch (page) {
    1 => _vidPage(state),
    2 => _mapPage(state),
    3 => mi < 4 ? buildLeftMFD(state, page: mi) : buildRightMFD(state, page: mi - 4),
    _ => _chatPage(),
  };

  return Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 280, height: 200,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: _kABg, border: Border.all(color: _kABord, width: 2)),
      child: pageContent,
    ),
    const SizedBox(height: 4),
    _bottomRow(page, mi, onPage, onMirrorScroll),
  ]);
}

// ── Bottom OSB row ────────────────────────────────────────────────────────────

Widget _bottomRow(int page, int mi,
    void Function(int)? onPage, void Function(int)? onMirrorScroll) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    _osb('CHAT', page == 0, () => onPage?.call(0)),
    _osb('VID',  page == 1, () => onPage?.call(1)),
    _osb('MAP',  page == 2, () => onPage?.call(2)),
    _MirrorOsb(label: _kOpts[mi], active: page == 3,
        onTap: () => onPage?.call(3), onScroll: onMirrorScroll),
  ]);
}

Widget _osb(String label, bool active, VoidCallback? onTap) {
  final brd = active ? const Color(0xFF9966FF) : const Color(0xFF3C3C4C);
  final txt = active ? const Color(0xFFCCAAFF) : const Color(0xFF6A6A8A);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: const Color(0xFF1A1A22),
          border: Border.all(color: brd, width: active ? 1.5 : 1.0)),
      child: Center(child: Text(label, style: TextStyle(
          color: txt, fontSize: 7.5,
          fontWeight: FontWeight.bold, letterSpacing: 0.5))),
    ),
  );
}

// ── Scroll-wheel mirror OSB ───────────────────────────────────────────────────

class _MirrorOsb extends StatelessWidget {
  final String  label;
  final bool    active;
  final VoidCallback?       onTap;
  final void Function(int)? onScroll;
  const _MirrorOsb({
    required this.label, required this.active, this.onTap, this.onScroll});

  @override
  Widget build(BuildContext context) {
    final brd = active ? const Color(0xFF9966FF) : const Color(0xFF3C3C4C);
    final txt = active ? const Color(0xFFCCAAFF) : const Color(0xFF6A6A8A);
    final arr = active ? const Color(0xFF8855DD) : const Color(0xFF444455);
    return Listener(
      onPointerSignal: (ev) {
        if (ev is PointerScrollEvent && onScroll != null) {
          onScroll!(ev.scrollDelta.dy > 0 ? 1 : -1);
          onTap?.call();
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: const Color(0xFF1A1A22),
              border: Border.all(color: brd, width: active ? 1.5 : 1.0)),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('▲', style: TextStyle(color: arr, fontSize: 4.5,
                  height: 1.0, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: txt, fontSize: 6.5,
                  fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              Text('▼', style: TextStyle(color: arr, fontSize: 4.5,
                  height: 1.0, fontWeight: FontWeight.bold)),
            ]),
        ),
      ),
    );
  }
}

// ── Shared header / footer ────────────────────────────────────────────────────

Widget _hdr(String title, String badge) => Container(
  height: 20,
  padding: const EdgeInsets.symmetric(horizontal: 6),
  color: _kADim.withValues(alpha: 0.4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: TextStyle(color: _kAFg, fontSize: 9, letterSpacing: 1)),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      color: _kAFg.withValues(alpha: 0.2),
      child: Text(badge, style: TextStyle(
          color: _kAFg, fontSize: 8, fontWeight: FontWeight.bold)),
    ),
  ]),
);

Widget _ftr(String a, String b, String c) => Container(
  height: 22,
  padding: const EdgeInsets.symmetric(horizontal: 6),
  color: _kADim.withValues(alpha: 0.3),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(a, style: TextStyle(color: _kAFg, fontSize: 8)),
    Text(b, style: TextStyle(color: _kAFg, fontSize: 8)),
    Text(c, style: TextStyle(color: _kADim, fontSize: 8)),
  ]),
);

// ── CHAT page ─────────────────────────────────────────────────────────────────

Widget _chatPage() => Column(children: [
  _hdr('RADIO COMMS', 'CHAT'),
  Expanded(child: ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _kLog.length,
    itemBuilder: (_, i) {
      final (call, msg) = _kLog[i];
      final ctrl = call == 'CTRL';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 40, child: Text('[$call]',
              style: TextStyle(color: ctrl ? _kAFg : _kADim,
                  fontSize: 7, fontWeight: FontWeight.bold))),
          Expanded(child: Text(msg,
              style: TextStyle(color: ctrl ? _kADim : _kAFg, fontSize: 7))),
        ]),
      );
    },
  )),
  _ftr('FREQ:127.8', 'MODE:FM', 'CH:ALPHA'),
]);

// ── VIDEO page ────────────────────────────────────────────────────────────────

Widget _vidPage(GameState s) => Column(children: [
  _hdr('FORWARD CAM', 'VID'),
  Expanded(child: CustomPaint(
    painter: _VidPainter(pitch: s.flightPitchAngle, bank: s.flightBankAngle,
        alt: s.flightAltitude, spd: s.flightSpeed),
    child: const SizedBox.expand(),
  )),
  _ftr('CAM:FWD', 'ZOOM:1×', 'MODE:EO'),
]);

class _VidPainter extends CustomPainter {
  final double pitch, bank, alt, spd;
  const _VidPainter({required this.pitch, required this.bank,
      required this.alt, required this.spd});

  void _txt(Canvas c, String s, Offset o) {
    (TextPainter(
      text: TextSpan(text: s,
          style: const TextStyle(color: Color(0xFF44FF44), fontSize: 7)),
      textDirection: TextDirection.ltr,
    )..layout()).paint(c, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF071307));

    canvas.save();
    canvas.translate(cx, cy + pitch * 1.2);
    canvas.rotate(bank * math.pi / 180);
    canvas.drawRect(Rect.fromLTRB(-size.width * 2, 0, size.width * 2, size.height * 2),
        Paint()..color = const Color(0xFF0A1A06));
    canvas.drawRect(Rect.fromLTRB(-size.width * 2, -size.height * 2, size.width * 2, 0),
        Paint()..color = const Color(0xFF0D2A0D));
    canvas.drawLine(Offset(-size.width * 2, 0), Offset(size.width * 2, 0),
        Paint()..color = const Color(0xFF44FF44)..strokeWidth = 0.8);
    for (final d in [-10.0, -5.0, 5.0, 10.0]) {
      canvas.drawLine(Offset(-16, d * 1.2), Offset(16, d * 1.2),
          Paint()..color = const Color(0x7744FF44)..strokeWidth = 0.5);
    }
    canvas.restore();

    final cp = Paint()..color = const Color(0xFF44FF44)..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 22, cy), Offset(cx - 7, cy), cp);
    canvas.drawLine(Offset(cx + 7,  cy), Offset(cx + 22, cy), cp);
    canvas.drawLine(Offset(cx, cy - 22), Offset(cx, cy - 7), cp);
    canvas.drawLine(Offset(cx, cy + 7),  Offset(cx, cy + 22), cp);
    canvas.drawCircle(Offset(cx, cy), 4,
        Paint()..color = const Color(0xFF44FF44)
            ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    _txt(canvas, 'ALT ${alt.toStringAsFixed(0)} m', const Offset(5, 5));
    _txt(canvas, 'SPD ${spd.toStringAsFixed(1)} u/s', const Offset(5, 14));

    final scan = Paint()..color = const Color(0x18000000);
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
  }

  @override
  bool shouldRepaint(_VidPainter o) =>
      o.pitch != pitch || o.bank != bank || o.alt != alt || o.spd != spd;
}

// ── MAP page ──────────────────────────────────────────────────────────────────

Widget _mapPage(GameState s) => Column(children: [
  _hdr('TERRAIN MAP', 'MAP'),
  Expanded(child: CustomPaint(
    painter: _MapPainter(px: s.playerPosition.x, pz: s.playerPosition.z,
        heading: s.playerRotation.y),
    child: Container(),
  )),
  _ftr('X:${s.playerPosition.x.toStringAsFixed(0)}',
       'Z:${s.playerPosition.z.toStringAsFixed(0)}', 'RNG:120'),
]);

class _MapPainter extends CustomPainter {
  final double px, pz, heading;
  const _MapPainter({required this.px, required this.pz, required this.heading});

  static Color _hc(double h) {
    if (h < 0.6) return const Color(0xFF1A3A1A);
    if (h < 3)   return const Color(0xFF2E6E2E);
    if (h < 8)   return const Color(0xFF4A8C3A);
    if (h < 15)  return const Color(0xFF8B7014);
    if (h < 25)  return const Color(0xFF6B3A14);
    return const Color(0xFFAAAAAA);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const range = 120.0;
    const grid  = 20;
    const step  = range * 2 / grid;
    final cw = size.width  / grid;
    final ch = size.height / grid;

    for (int gx = 0; gx < grid; gx++) {
      for (int gz = 0; gz < grid; gz++) {
        canvas.drawRect(
          Rect.fromLTWH(gx * cw, gz * ch, cw + 0.5, ch + 0.5),
          Paint()..color = _hc(TerrainGenerator.heightAt(
            px - range + (gx + 0.5) * step,
            pz - range + (gz + 0.5) * step,
          )),
        );
      }
    }

    // Subtle grid overlay
    final gp = Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 0.4;
    for (int i = 0; i <= grid; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), gp);
      canvas.drawLine(Offset(0, i * ch), Offset(size.width, i * ch), gp);
    }

    // Aircraft marker
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hr = heading * math.pi / 180.0;
    final path = Path()
      ..moveTo(cx + math.sin(hr) * 7,       cy - math.cos(hr) * 7)
      ..lineTo(cx + math.sin(hr + 2.5) * 4, cy - math.cos(hr + 2.5) * 4)
      ..lineTo(cx + math.sin(hr - 2.5) * 4, cy - math.cos(hr - 2.5) * 4)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MapPainter o) =>
      o.px != px || o.pz != pz || o.heading != heading;
}
