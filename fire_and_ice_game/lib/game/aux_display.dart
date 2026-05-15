import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'maneuver_tutorial.dart';
import 'mfd_panels.dart';
import '../terrain/terrain_generator.dart';

// ── Palette (violet accent — distinct from green/blue MFDs) ──────────────────

const _kABg   = Color(0xFF0E0014);
const _kAFg   = Color(0xFFCC88FF);
const _kADim  = Color(0xFF441166);
const _kABord = Color(0xFF2A1040);

const _kOpts = ['ELMT', 'LOAD', 'STAT', 'MODE', 'NAV', 'TERR', 'FIRE', 'MARK'];

// 2× uniform scale factor applied to all layout dimensions
const double _kS = 2.0;

// Video catalogue — index matches GameState.auxVideoIndex
const _kVids = [
  (id: 'fKHEt3jpSyo', name: 'LISA HAYES',  sub: 'TRIBUTE'),
  (id: 'yh4swGLAL9o', name: 'LIN MINMEI', sub: 'DO YOU REMEMBER LOVE'),
];
final _kVidReg = <String>{};

void _regYt(String id) {
  if (_kVidReg.contains(id)) return;
  _kVidReg.add(id);
  ui_web.platformViewRegistry.registerViewFactory(
    'yt-$id',
    (int _) {
      final el = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$id?rel=0&modestbranding=1'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..setAttribute('allow',
            'accelerometer; autoplay; clipboard-write; '
            'encrypted-media; gyroscope; picture-in-picture; web-share')
        ..setAttribute('allowfullscreen', '')
        // tabindex=-1 prevents tab-based focus; focus listener returns
        // keyboard control to the game document so flight keys keep working.
        ..setAttribute('tabindex', '-1');
      el.addEventListener('focus', (e) => html.document.body?.focus());
      return el;
    },
  );
}

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

/// Auxiliary display: 560×400 content + 56px bottom OSB row (2× original).
/// Pages: 0=CHAT  1=VID  2=MAP  3=MIRROR  4=MANUV
Widget buildAuxDisplay(GameState state, {
  void Function(int)? onPage,
  void Function(int)? onMirrorScroll,
  void Function(int)? onVideoScroll,
  void Function(int)? onManeuverScroll,
  void Function()?    onManeuverExecute,
  void Function()?    onManeuverStop,
}) {
  final page = state.auxDisplayPage;
  final mi   = state.auxMirrorIndex.clamp(0, _kOpts.length - 1);

  final Widget pageContent = switch (page) {
    1 => _vidPage(state, onVideoScroll),
    2 => _mapPage(state),
    3 => FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 280, height: 200,
          child: mi < 4 ? buildLeftMFD(state, page: mi) : buildRightMFD(state, page: mi - 4),
        ),
      ),
    4 => ManeuverPage(
        state: state,
        onScroll:  onManeuverScroll,
        onExecute: onManeuverExecute,
        onStop:    onManeuverStop,
      ),
    _ => _chatPage(),
  };

  return Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 280 * _kS, height: 200 * _kS,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: _kABg, border: Border.all(color: _kABord, width: 4)),
      child: pageContent,
    ),
    SizedBox(height: 4 * _kS),
    _bottomRow(page, mi, onPage, onMirrorScroll),
  ]);
}

// ── Bottom OSB row ────────────────────────────────────────────────────────────

Widget _bottomRow(int page, int mi,
    void Function(int)? onPage, void Function(int)? onMirrorScroll) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    _osb('CHAT',  page == 0, () => onPage?.call(0)),
    _osb('VID',   page == 1, () => onPage?.call(1)),
    _osb('MAP',   page == 2, () => onPage?.call(2)),
    _MirrorOsb(label: _kOpts[mi], active: page == 3,
        onTap: () => onPage?.call(3), onScroll: onMirrorScroll),
    _osb('MANUV', page == 4, () => onPage?.call(4)),
  ]);
}

Widget _osb(String label, bool active, VoidCallback? onTap) {
  final brd = active ? const Color(0xFF9966FF) : const Color(0xFF3C3C4C);
  final txt = active ? const Color(0xFFCCAAFF) : const Color(0xFF6A6A8A);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38 * _kS, height: 28 * _kS,
      margin: EdgeInsets.symmetric(horizontal: 2 * _kS),
      decoration: BoxDecoration(color: const Color(0xFF1A1A22),
          border: Border.all(color: brd, width: active ? 1.5 : 1.0)),
      child: Center(child: Text(label, style: TextStyle(
          color: txt, fontSize: 7.5 * _kS,
          fontWeight: FontWeight.bold, letterSpacing: 2))),
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
          width: 38 * _kS, height: 28 * _kS,
          margin: EdgeInsets.symmetric(horizontal: 2 * _kS),
          decoration: BoxDecoration(color: const Color(0xFF1A1A22),
              border: Border.all(color: brd, width: active ? 1.5 : 1.0)),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('▲', style: TextStyle(color: arr, fontSize: 4.5 * _kS,
                  height: 1.0, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: txt, fontSize: 6.5 * _kS,
                  fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text('▼', style: TextStyle(color: arr, fontSize: 4.5 * _kS,
                  height: 1.0, fontWeight: FontWeight.bold)),
            ]),
        ),
      ),
    );
  }
}

// ── Shared header / footer ────────────────────────────────────────────────────

Widget _hdr(String title, String badge) => Container(
  height: 20 * _kS,
  padding: EdgeInsets.symmetric(horizontal: 6 * _kS),
  color: _kADim.withValues(alpha: 0.4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: TextStyle(color: _kAFg, fontSize: 9 * _kS, letterSpacing: 4)),
    Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * _kS, vertical: 1 * _kS),
      color: _kAFg.withValues(alpha: 0.2),
      child: Text(badge, style: TextStyle(
          color: _kAFg, fontSize: 8 * _kS, fontWeight: FontWeight.bold)),
    ),
  ]),
);

Widget _ftr(String a, String b, String c) => Container(
  height: 22 * _kS,
  padding: EdgeInsets.symmetric(horizontal: 6 * _kS),
  color: _kADim.withValues(alpha: 0.3),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(a, style: TextStyle(color: _kAFg, fontSize: 8 * _kS)),
    Text(b, style: TextStyle(color: _kAFg, fontSize: 8 * _kS)),
    Text(c, style: TextStyle(color: _kADim, fontSize: 8 * _kS)),
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
        padding: EdgeInsets.symmetric(horizontal: 5 * _kS, vertical: 1 * _kS),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 40 * _kS, child: Text('[$call]',
              style: TextStyle(color: ctrl ? _kAFg : _kADim,
                  fontSize: 7 * _kS, fontWeight: FontWeight.bold))),
          Expanded(child: Text(msg,
              style: TextStyle(color: ctrl ? _kADim : _kAFg, fontSize: 7 * _kS))),
        ]),
      );
    },
  )),
  _ftr('FREQ:127.8', 'MODE:FM', 'CH:ALPHA'),
]);

// ── VIDEO page ────────────────────────────────────────────────────────────────

Widget _vidPage(GameState s, void Function(int)? onScroll) {
  final vi  = s.auxVideoIndex.clamp(0, _kVids.length - 1);
  final vid = _kVids[vi];
  _regYt(vid.id);
  return Listener(
    onPointerSignal: (ev) {
      if (ev is PointerScrollEvent && onScroll != null) {
        onScroll(ev.scrollDelta.dy > 0 ? 1 : -1);
      }
    },
    child: Column(children: [
      _hdr(vid.name, 'VID'),
      Expanded(child: HtmlElementView(viewType: 'yt-${vid.id}')),
      _ftr(vid.sub, '${vi + 1}/${_kVids.length}', '▲▼ SCROLL'),
    ]),
  );
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

    final gp = Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 0.4;
    for (int i = 0; i <= grid; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), gp);
      canvas.drawLine(Offset(0, i * ch), Offset(size.width, i * ch), gp);
    }

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
