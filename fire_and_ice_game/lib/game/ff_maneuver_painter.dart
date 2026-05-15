import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../systems/maneuver_system.dart';

const _kBg   = Color(0xFF04100A);
const _kGrid = Color(0x18FF6600);
const _kFire = Color(0xFFFF4400);
const _kDot  = Color(0xFFFFAA00);
const _kPath = Color(0xFFFF6600);
const _kCryo = Color(0xFF00CCFF);

/// Tutorial painter for the 10 fire-fighting maneuvers.
class FfPainter extends CustomPainter {
  final ManeuverType type;
  final double       phase;
  final bool         dropActive;

  const FfPainter(this.type, this.phase, this.dropActive);

  @override
  bool shouldRepaint(FfPainter o) =>
      o.type != type || o.phase != phase || o.dropActive != dropActive;

  @override
  void paint(Canvas c, Size sz) {
    c.drawRect(Offset.zero & sz, Paint()..color = _kBg);
    _grid(c, sz);
    switch (type) {
      case ManeuverType.diveBomb:        _diveBomb(c, sz);
      case ManeuverType.lowPass:         _lowPass(c, sz);
      case ManeuverType.scoopingPass:    _scoopingPass(c, sz);
      case ManeuverType.retardantSpiral: _retardantSpiral(c, sz);
      case ManeuverType.phoenixRoll:     _phoenixRoll(c, sz);
      case ManeuverType.cryoLance:       _cryoLance(c, sz);
      case ManeuverType.vortexSmash:     _vortexSmash(c, sz);
      case ManeuverType.iceCurtain:      _iceCurtain(c, sz);
      case ManeuverType.firebreakRun:    _firebreakRun(c, sz);
      case ManeuverType.thermalLance:    _thermalLance(c, sz);
      default: break;
    }
    if (dropActive) {
      c.drawRect(Rect.fromLTRB(2, 2, sz.width - 2, sz.height - 2),
          Paint()..color = _kFire.withValues(alpha: 0.6)..strokeWidth = 3..style = PaintingStyle.stroke);
    }
  }

  void _grid(Canvas c, Size sz) {
    final p = Paint()..color = _kGrid..strokeWidth = 0.5;
    for (double x = 0; x < sz.width;  x += sz.width  / 6) c.drawLine(Offset(x, 0), Offset(x, sz.height), p);
    for (double y = 0; y < sz.height; y += sz.height / 5) c.drawLine(Offset(0, y), Offset(sz.width, y), p);
  }

  Paint _pp([double alpha = 0.55]) =>
      Paint()..color = _kPath.withValues(alpha: alpha)..strokeWidth = 1.8
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

  void _dot(Canvas c, Offset o) => c.drawCircle(o, 4.5, Paint()..color = _kDot);

  void _lbl(Canvas c, String s, Offset o) {
    (TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout()).paint(c, o);
  }

  void _ground(Canvas c, Size sz, {double frac = 0.82}) {
    final y = sz.height * frac;
    c.drawRect(Rect.fromLTRB(0, y, sz.width, sz.height), Paint()..color = const Color(0x150A2008));
    c.drawLine(Offset(0, y), Offset(sz.width, y), Paint()..color = const Color(0x6600FF44)..strokeWidth = 1.0);
  }

  void _fire(Canvas c, Offset center, double r) {
    c.drawCircle(center, r, Paint()..color = _kFire.withValues(alpha: 0.18));
    c.drawCircle(center, r, Paint()..color = _kFire.withValues(alpha: 0.7)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    c.drawCircle(center, r * 0.45, Paint()..color = const Color(0x55FFFF00));
  }

  void _impact(Canvas c, Offset p, [Color? col]) {
    final paint = Paint()..color = (col ?? _kCryo).withValues(alpha: 0.9)..strokeWidth = 1.5;
    c.drawLine(Offset(p.dx - 7, p.dy - 7), Offset(p.dx + 7, p.dy + 7), paint);
    c.drawLine(Offset(p.dx + 7, p.dy - 7), Offset(p.dx - 7, p.dy + 7), paint);
    c.drawCircle(p, 9, Paint()..color = (col ?? _kCryo).withValues(alpha: 0.2));
  }

  void _diveBomb(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.84);
    final fp  = Offset(sz.width * 0.65, sz.height * 0.84);
    _fire(c, fp, 22);
    final ey  = sz.height * 0.22;
    final dx  = sz.width  * 0.40;
    final ix  = fp.dx - 4;
    final iy  = sz.height * 0.75;
    c.drawLine(Offset(0, ey), Offset(dx, ey), _pp(0.3));
    c.drawLine(Offset(dx, ey), Offset(ix, iy), _pp());
    final pa = Path()..moveTo(ix, iy);
    pa.arcTo(Rect.fromCenter(center: Offset(ix + 38, iy), width: 76, height: 70), math.pi, -math.pi / 2, false);
    c.drawPath(pa, _pp(0.4));
    _impact(c, Offset(ix, iy + 6));
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    final t = phase.clamp(0.0, 1.0);
    if (t < 0.35) {
      _dot(c, Offset(sz.width * 0.38 * t / 0.35, ey));
    } else if (t < 0.65) {
      final u = (t - 0.35) / 0.30;
      _dot(c, Offset(dx + (ix - dx) * u, ey + (iy - ey) * u));
    } else {
      final u = (t - 0.65) / 0.35;
      _dot(c, Offset(ix + 38 * math.sin(u * math.pi / 2), iy - 35 * (1 - math.cos(u * math.pi / 2))));
    }
  }

  void _lowPass(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.80);
    _fire(c, Offset(sz.width * 0.5, sz.height * 0.80), 28);
    final passY = sz.height * 0.72;
    c.drawLine(Offset(0, passY), Offset(sz.width, passY), _pp());
    c.drawLine(Offset(sz.width * 0.5, passY), Offset(sz.width * 0.5, sz.height * 0.80), _pp(0.4));
    _impact(c, Offset(sz.width * 0.5, sz.height * 0.80));
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    _lbl(c, 'FAST + LOW', Offset(4, sz.height - 14));
    _dot(c, Offset(sz.width * phase.clamp(0.0, 1.0), passY));
  }

  void _scoopingPass(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.90);
    _fire(c, Offset(sz.width * 0.5, sz.height * 0.88), 32);
    final passY = sz.height * 0.82;
    c.drawLine(Offset(0, passY), Offset(sz.width, passY), _pp());
    final dp = Paint()..color = _kPath.withValues(alpha: 0.22)..strokeWidth = 1;
    for (double x = sz.width * 0.18; x < sz.width * 0.82; x += 14) {
      c.drawLine(Offset(x, passY), Offset(x, sz.height * 0.88), dp);
    }
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    _lbl(c, 'SLOW — HEAT DANGER', Offset(4, sz.height - 14));
    _dot(c, Offset(sz.width * phase.clamp(0.0, 1.0), passY));
  }

  void _retardantSpiral(Canvas c, Size sz) {
    final cx = sz.width * 0.5, cy = sz.height * 0.5;
    _fire(c, Offset(cx, cy), 18);
    for (final r in [18.0, 36.0, 54.0]) {
      c.drawCircle(Offset(cx, cy), r, Paint()..color = _kFire.withValues(alpha: 0.10)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
    final sp = Path();
    for (int i = 0; i <= 120; i++) {
      final t   = i / 120.0;
      final ang = t * 3.0 * 2 * math.pi;
      final r   = 54.0 * (1 - t) + 8.0 * t;
      final px  = cx + r * math.cos(ang), py = cy + r * math.sin(ang);
      i == 0 ? sp.moveTo(px, py) : sp.lineTo(px, py);
    }
    c.drawPath(sp, _pp(0.5));
    _lbl(c, 'TOP VIEW', Offset(4, 2));
    _lbl(c, 'SPIRAL DESCENT', Offset(4, sz.height - 14));
    final t2 = phase.clamp(0.0, 1.0);
    final ang = t2 * 3.0 * 2 * math.pi;
    final r2  = 54.0 * (1 - t2) + 8.0 * t2;
    _dot(c, Offset(cx + r2 * math.cos(ang), cy + r2 * math.sin(ang)));
  }

  void _phoenixRoll(Canvas c, Size sz) {
    final cx = sz.width * 0.5, cy = sz.height * 0.44;
    final rx = sz.width * 0.32, ry = sz.height * 0.27;
    _fire(c, Offset(cx, sz.height * 0.82), 22);
    c.drawPath(Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2)), _pp());
    final sp = Paint()..color = _kPath.withValues(alpha: 0.28)..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(Offset(cx + rx * 0.6 * math.cos(a), cy + ry * 0.6 * math.sin(a)),
                 Offset(cx + (rx + 14) * math.cos(a), cy + (ry + 10) * math.sin(a)), sp);
    }
    c.drawLine(Offset(cx, cy + ry), Offset(cx, sz.height * 0.78), _pp(0.25));
    _lbl(c, 'FRONT VIEW', Offset(4, 2));
    _lbl(c, 'CENTRIFUGAL SPRAY', Offset(4, sz.height - 14));
    final t = phase * 2 * math.pi;
    _dot(c, Offset(cx + rx * math.cos(t), cy + ry * math.sin(t)));
  }

  void _cryoLance(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.84);
    final fp  = Offset(sz.width * 0.58, sz.height * 0.84);
    _fire(c, fp, 22);
    final ep  = Offset(sz.width * 0.15, sz.height * 0.14);
    final sp  = Offset(sz.width * 0.38, sz.height * 0.60);
    c.drawLine(ep, sp, _pp());
    c.drawLine(sp, fp, Paint()..color = _kCryo.withValues(alpha: 0.85)..strokeWidth = 2.0..style = PaintingStyle.stroke);
    final bp = Paint()..color = _kCryo.withValues(alpha: 0.5)..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(fp, Offset(fp.dx + 14 * math.cos(a), fp.dy + 14 * math.sin(a)), bp);
    }
    _impact(c, fp, _kCryo);
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    _lbl(c, 'CRYO-BEAM', Offset(4, sz.height - 14));
    final t = phase.clamp(0.0, 1.0);
    _dot(c, t < 0.65 ? Offset.lerp(ep, sp, t / 0.65)! : sp);
  }

  void _vortexSmash(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.84);
    final fp  = Offset(sz.width * 0.50, sz.height * 0.84);
    _fire(c, fp, 22);
    final top = Offset(sz.width * 0.50, sz.height * 0.10);
    final bot = Offset(sz.width * 0.50, sz.height * 0.76);
    c.drawLine(top, bot, _pp());
    final vp = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
    for (int i = 1; i <= 3; i++) {
      vp.color = _kFire.withValues(alpha: 0.13 + i * 0.11);
      c.drawOval(Rect.fromCenter(center: bot, width: i * 24.0, height: i * 11.0), vp);
    }
    final po = Path()..moveTo(bot.dx, bot.dy);
    po.arcTo(Rect.fromCenter(center: Offset(bot.dx + 44, bot.dy), width: 88, height: 80), math.pi, -math.pi / 2, false);
    c.drawPath(po, _pp(0.35));
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    _lbl(c, 'SHOCKWAVE VORTEX', Offset(4, sz.height - 14));
    final t = phase.clamp(0.0, 1.0);
    if (t < 0.55) {
      _dot(c, Offset(top.dx, top.dy + (bot.dy - top.dy) * (t / 0.55)));
    } else {
      final u = (t - 0.55) / 0.45;
      _dot(c, Offset(bot.dx + 44 * math.sin(u * math.pi / 2), bot.dy - 40 * (1 - math.cos(u * math.pi / 2))));
    }
  }

  void _iceCurtain(Canvas c, Size sz) {
    final ys = [sz.height * 0.28, sz.height * 0.50, sz.height * 0.70];
    c.drawRect(Rect.fromLTRB(0, sz.height * 0.88, sz.width, sz.height), Paint()..color = _kFire.withValues(alpha: 0.15));
    c.drawLine(Offset(0, sz.height * 0.88), Offset(sz.width, sz.height * 0.88),
        Paint()..color = _kFire.withValues(alpha: 0.6)..strokeWidth = 1.2);
    final ip = Paint()..color = _kCryo.withValues(alpha: 0.6)..strokeWidth = 1.5;
    for (final y in ys) {
      c.drawLine(Offset(0, y), Offset(sz.width, y), ip);
      final cp = Paint()..color = _kCryo.withValues(alpha: 0.35)..strokeWidth = 0.8;
      for (double x = 10; x < sz.width; x += 18) {
        c.drawLine(Offset(x - 5, y - 5), Offset(x + 5, y + 5), cp);
        c.drawLine(Offset(x + 5, y - 5), Offset(x - 5, y + 5), cp);
      }
    }
    _lbl(c, 'FRONT VIEW', Offset(4, 2));
    _lbl(c, 'ICE WALL × 3', Offset(4, sz.height - 14));
    final pass = (phase * 3).floor().clamp(0, 2);
    final pt   = (phase * 3) % 1.0;
    _dot(c, Offset(sz.width * (pass.isEven ? pt : 1 - pt), ys[pass]));
  }

  void _firebreakRun(Canvas c, Size sz) {
    final yT = sz.height * 0.35, yB = sz.height * 0.65;
    _fire(c, Offset(sz.width * 0.5, sz.height * 0.5), 24);
    c.drawLine(Offset(0, yT), Offset(sz.width, yT), _pp());
    final arc = Path()..moveTo(sz.width - 1, yT);
    arc.arcTo(Rect.fromCenter(center: Offset(sz.width - 1, (yT + yB) / 2), width: yB - yT, height: yB - yT),
        -math.pi / 2, math.pi, false);
    c.drawPath(arc, _pp(0.35));
    c.drawLine(Offset(sz.width, yB), Offset(0, yB), _pp());
    final dp = Paint()..color = _kPath.withValues(alpha: 0.22)..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (double x = 8; x < sz.width; x += 20) {
      c.drawCircle(Offset(x, yT), 2, dp);
      c.drawCircle(Offset(sz.width - x, yB), 2, dp);
    }
    _lbl(c, 'TOP VIEW', Offset(4, 2));
    _lbl(c, 'SUPPRESSION GRID', Offset(4, sz.height - 14));
    final t  = phase.clamp(0.0, 1.0);
    final r2 = (yB - yT) / 2;
    final my = (yT + yB) / 2;
    if (t < 0.45) {
      _dot(c, Offset(sz.width * (t / 0.45), yT));
    } else if (t < 0.55) {
      final u = (t - 0.45) / 0.10;
      _dot(c, Offset(sz.width + r2 * math.sin(u * math.pi), my - r2 * math.cos(u * math.pi)));
    } else {
      _dot(c, Offset(sz.width * (1 - (t - 0.55) / 0.45), yB));
    }
  }

  void _thermalLance(Canvas c, Size sz) {
    _ground(c, sz, frac: 0.84);
    final fp  = Offset(sz.width * 0.35, sz.height * 0.84);
    _fire(c, fp, 22);
    final ep  = Offset(sz.width * 0.85, sz.height * 0.18);
    final lb  = Offset(sz.width * 0.58, sz.height * 0.58);
    c.drawLine(ep, lb, _pp());
    c.drawLine(lb, fp, Paint()..color = const Color(0xFFFF6600).withValues(alpha: 0.9)..strokeWidth = 2.5..style = PaintingStyle.stroke);
    c.drawLine(lb, fp, Paint()..color = const Color(0xFFFFFF00).withValues(alpha: 0.3)..strokeWidth = 0.8..style = PaintingStyle.stroke);
    if (dropActive) {
      c.drawCircle(fp, 10, Paint()..color = const Color(0x55FFFFFF));
    }
    _impact(c, fp, const Color(0xFFFF6600));
    _lbl(c, 'SIDE VIEW', Offset(4, 2));
    _lbl(c, 'COUNTER-FIRE LANCE', Offset(4, sz.height - 14));
    final t = phase.clamp(0.0, 1.0);
    _dot(c, t < 0.70 ? Offset.lerp(ep, lb, t / 0.70)! : lb);
  }
}
