import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../systems/maneuver_system.dart';

// Shared palette (matches maneuver_tutorial.dart)
const _kBg   = Color(0xFF040818);
const _kGrid = Color(0x1800BBFF);
const _kPath = Color(0xFF00CCFF);
const _kDot  = Color(0xFF00FF88);

/// Tutorial painter for the 13 aerobatic maneuvers.
class AerobaticPainter extends CustomPainter {
  final ManeuverType type;
  final double       phase;
  final bool         live;

  const AerobaticPainter(this.type, this.phase, this.live);

  @override
  bool shouldRepaint(AerobaticPainter o) =>
      o.type != type || o.phase != phase || o.live != live;

  @override
  void paint(Canvas c, Size sz) {
    c.drawRect(Offset.zero & sz, Paint()..color = _kBg);
    _drawGrid(c, sz);
    switch (type) {
      case ManeuverType.loop:          _loop(c, sz);
      case ManeuverType.barrelRoll:    _barrelRoll(c, sz);
      case ManeuverType.immelmann:     _immelmann(c, sz);
      case ManeuverType.splitS:        _splitS(c, sz);
      case ManeuverType.cubanEight:    _cubanEight(c, sz);
      case ManeuverType.wingOver:      _wingOver(c, sz);
      case ManeuverType.hammerhead:    _hammerhead(c, sz);
      case ManeuverType.snapRoll:      _snapRoll(c, sz);
      case ManeuverType.chandelle:     _chandelle(c, sz);
      case ManeuverType.tacticalTurn:  _tacticalTurn(c, sz);
      case ManeuverType.breakTurn:     _breakTurn(c, sz);
      case ManeuverType.jink:          _jink(c, sz);
      case ManeuverType.cloverleaf:    _cloverleaf(c, sz);
      default: break;
    }
  }

  void _drawGrid(Canvas c, Size sz) {
    final p = Paint()..color = _kGrid..strokeWidth = 0.5;
    for (double x = 0; x < sz.width;  x += sz.width  / 6) c.drawLine(Offset(x, 0), Offset(x, sz.height), p);
    for (double y = 0; y < sz.height; y += sz.height / 5) c.drawLine(Offset(0, y), Offset(sz.width, y), p);
    c.drawLine(Offset(0, sz.height * 0.65), Offset(sz.width, sz.height * 0.65),
        Paint()..color = const Color(0x3300FF88)..strokeWidth = 1);
  }

  Paint _pathPaint([double alpha = 0.45]) =>
      Paint()..color = _kPath.withValues(alpha: alpha)..strokeWidth = 1.5
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

  void _dot(Canvas c, Offset o, [Color? col]) =>
      c.drawCircle(o, 4, Paint()..color = (col ?? _kDot));

  void _label(Canvas c, String s, Offset o) {
    (TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout()).paint(c, o);
  }

  Offset _pathAt(List<Offset> pts, double t) {
    if (pts.isEmpty) return Offset.zero;
    final n = pts.length;
    final f = (t * n) % n;
    final i = f.floor() % n;
    return Offset.lerp(pts[i], pts[(i + 1) % n], f - f.floor())!;
  }

  void _loop(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.65, r = sz.height * 0.28;
    c.drawPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy - r), radius: r)), _pathPaint());
    c.drawLine(Offset(cx - r * 1.8, cy), Offset(cx - r, cy), _pathPaint(0.25));
    _label(c, 'SIDE VIEW', Offset(4, 2));
    _label(c, 'LOOP', Offset(4, sz.height - 14));
    final t = phase * 2 * math.pi;
    _dot(c, Offset(cx + r * math.sin(t), (cy - r) + r * math.cos(t)));
  }

  void _barrelRoll(Canvas c, Size sz) {
    final cx = sz.width * 0.5, cy = sz.height * 0.5;
    final rx = sz.width * 0.35, ry = sz.height * 0.30;
    c.drawPath(Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2)), _pathPaint());
    c.drawLine(Offset(cx - rx, cy), Offset(cx + rx, cy), _pathPaint(0.2));
    _label(c, 'FRONT VIEW', Offset(4, 2));
    final t = phase * 2 * math.pi;
    _dot(c, Offset(cx + rx * math.cos(t), cy + ry * math.sin(t)));
  }

  void _immelmann(Canvas c, Size sz) {
    final cx = sz.width * 0.45, cy = sz.height * 0.65, r = sz.height * 0.28;
    final arc = Path()..moveTo(cx - r, cy);
    arc.arcTo(Rect.fromCircle(center: Offset(cx, cy - r), radius: r), math.pi / 2, -math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawPath(Path()..moveTo(cx, cy - 2 * r)..lineTo(cx - r * 1.5, cy - 2 * r), _pathPaint(0.5));
    c.drawLine(Offset(cx + r * 1.8, cy), Offset(cx + r, cy), _pathPaint(0.25));
    _label(c, 'SIDE VIEW', Offset(4, 2));
    if (phase < 0.5) {
      final a = math.pi / 2 - (phase / 0.5) * math.pi;
      _dot(c, Offset(cx + r * math.cos(a), (cy - r) - r * math.sin(a)));
    } else {
      _dot(c, Offset(cx - r * 1.5 * ((phase - 0.5) / 0.5), cy - 2 * r));
    }
  }

  void _splitS(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.35, r = sz.height * 0.28;
    c.drawLine(Offset(cx + r * 1.8, cy), Offset(cx + r, cy), _pathPaint(0.25));
    final arc = Path()..moveTo(cx + r, cy);
    arc.arcTo(Rect.fromCircle(center: Offset(cx, cy + r), radius: r), -math.pi / 2, math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx - r, cy + 2 * r), Offset(cx - r * 1.8, cy + 2 * r), _pathPaint(0.25));
    _label(c, 'SIDE VIEW', Offset(4, 2));
    if (phase < 0.2) {
      _dot(c, Offset(cx + r * 1.8 - r * 0.8 * (phase / 0.2), cy));
    } else {
      final a = -math.pi / 2 + ((phase - 0.2) / 0.8) * math.pi;
      _dot(c, Offset(cx + r * math.cos(a), (cy + r) + r * math.sin(a)));
    }
  }

  void _cubanEight(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.60, r = sz.height * 0.22;
    final cx1 = cx - r * 0.8, cx2 = cx + r * 0.8, cy1 = cy - r;
    c.drawPath(Path()..addOval(Rect.fromCircle(center: Offset(cx1, cy1), radius: r)), _pathPaint(0.3));
    c.drawPath(Path()..addOval(Rect.fromCircle(center: Offset(cx2, cy1), radius: r)), _pathPaint(0.3));
    final t = (phase * 2 * math.pi) % (2 * math.pi);
    _dot(c, phase < 0.5
        ? Offset(cx1 + r * math.sin(t), cy1 - r * math.cos(t))
        : Offset(cx2 + r * math.sin(t), cy1 - r * math.cos(t)));
    _label(c, 'SIDE VIEW', Offset(4, 2));
  }

  void _wingOver(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.55;
    final r  = math.min(sz.width, sz.height) * 0.30;
    final arc = Path()..moveTo(cx + r, cy);
    arc.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0, -math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx, cy + r * 0.5), Offset(cx + r, cy), _pathPaint(0.25));
    c.drawLine(Offset(cx - r, cy), Offset(cx, cy - r * 0.5), _pathPaint(0.25));
    _label(c, 'TOP VIEW', Offset(4, 2));
    final a = phase * math.pi;
    _dot(c, Offset(cx + r * math.cos(math.pi - a), cy - r * math.sin(a)));
  }

  void _hammerhead(Canvas c, Size sz) {
    final cx = sz.width * 0.50, bot = sz.height * 0.85, top = sz.height * 0.15;
    final kx = sz.width * 0.25;
    c.drawLine(Offset(cx, bot), Offset(cx, top), _pathPaint());
    final arc = Path()..moveTo(cx, top);
    arc.arcTo(Rect.fromCenter(center: Offset(cx - kx * 0.5, top), width: kx, height: sz.height * 0.12), 0, -math.pi / 2, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx - kx, top + sz.height * 0.06), Offset(cx - kx, bot), _pathPaint());
    _label(c, 'SIDE VIEW', Offset(4, 2));
    if (phase < 0.45) {
      _dot(c, Offset(cx, bot - (bot - top) * (phase / 0.45)));
    } else if (phase < 0.55) {
      _dot(c, Offset(cx - kx * ((phase - 0.45) / 0.10), top + sz.height * 0.03));
    } else {
      _dot(c, Offset(cx - kx, top + sz.height * 0.06 + (bot - top - sz.height * 0.06) * ((phase - 0.55) / 0.45)));
    }
  }

  void _snapRoll(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.50, r = sz.height * 0.28;
    c.drawPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)), _pathPaint());
    final dp = Paint()..color = _kPath.withValues(alpha: 0.3)..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
                 Offset(cx + (r + 8) * math.cos(a), cy + (r + 8) * math.sin(a)), dp);
    }
    _label(c, 'FRONT VIEW', Offset(4, 2));
    final t = phase * 2 * math.pi;
    _dot(c, Offset(cx + r * math.cos(t), cy + r * math.sin(t)));
  }

  void _chandelle(Canvas c, Size sz) {
    final cx = sz.width * 0.55, cy = sz.height * 0.65;
    final rx = sz.width * 0.35, ry = sz.height * 0.35;
    final arc = Path()..moveTo(cx + rx, cy);
    arc.arcTo(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), 0, -math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx + rx * 1.4, cy + 2), Offset(cx + rx, cy), _pathPaint(0.25));
    _label(c, 'TOP+SIDE VIEW', Offset(4, 2));
    final a = phase * math.pi;
    _dot(c, Offset(cx + rx * math.cos(math.pi - a), cy - ry * math.sin(a)));
  }

  void _tacticalTurn(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.55;
    final r  = math.min(sz.width, sz.height) * 0.28;
    final arc = Path()..moveTo(cx + r, cy);
    arc.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0, -math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx - r, cy), Offset(cx - r * 1.5, cy), _pathPaint(0.3));
    c.drawLine(Offset(cx + r, cy), Offset(cx + r * 1.5, cy), _pathPaint(0.3));
    _label(c, 'TOP VIEW', Offset(4, 2));
    _label(c, 'MAX-G', Offset(cx - 18, cy - r - 14));
    final a = phase * math.pi;
    _dot(c, Offset(cx + r * math.cos(math.pi - a), cy - r * math.sin(a)));
  }

  void _breakTurn(Canvas c, Size sz) {
    final cx = sz.width * 0.45, cy = sz.height * 0.55;
    final r  = math.min(sz.width, sz.height) * 0.28;
    final arc = Path()..moveTo(cx - r, cy);
    arc.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi, false);
    c.drawPath(arc, _pathPaint());
    c.drawLine(Offset(cx - r * 1.5, cy), Offset(cx - r, cy), _pathPaint(0.25));
    _label(c, 'TOP VIEW', Offset(4, 2));
    _label(c, 'BREAK →', Offset(cx - 14, cy - r - 14));
    final a = phase * math.pi;
    _dot(c, Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
  }

  void _jink(Canvas c, Size sz) {
    final pts = <Offset>[
      Offset(sz.width * 0.10, sz.height * 0.50),
      Offset(sz.width * 0.25, sz.height * 0.30),
      Offset(sz.width * 0.40, sz.height * 0.65),
      Offset(sz.width * 0.55, sz.height * 0.30),
      Offset(sz.width * 0.70, sz.height * 0.60),
      Offset(sz.width * 0.85, sz.height * 0.35),
      Offset(sz.width * 0.95, sz.height * 0.50),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
    c.drawPath(path, _pathPaint());
    _label(c, 'TOP VIEW', Offset(4, 2));
    _dot(c, _pathAt(pts, phase));
  }

  void _cloverleaf(Canvas c, Size sz) {
    final cx = sz.width * 0.50, cy = sz.height * 0.50;
    final r  = math.min(sz.width, sz.height) * 0.22;
    final p  = Paint()..color = _kPath.withValues(alpha: 0.35)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a  = i * math.pi / 2;
      c.drawOval(Rect.fromCenter(center: Offset(cx + r * math.cos(a), cy + r * math.sin(a)), width: r * 1.2, height: r * 1.2), p);
    }
    c.drawLine(Offset(cx - r * 2, cy), Offset(cx + r * 2, cy), Paint()..color = _kGrid..strokeWidth = 0.5);
    c.drawLine(Offset(cx, cy - r * 2), Offset(cx, cy + r * 2), Paint()..color = _kGrid..strokeWidth = 0.5);
    _label(c, 'TOP VIEW', Offset(4, 2));
    final leaf = (phase * 4).floor() % 4;
    final la   = leaf * math.pi / 2;
    final lc   = Offset(cx + r * math.cos(la), cy + r * math.sin(la));
    final da   = ((phase * 4) % 1.0) * 2 * math.pi;
    _dot(c, Offset(lc.dx + r * 0.6 * math.cos(da), lc.dy + r * 0.6 * math.sin(da)));
  }
}
