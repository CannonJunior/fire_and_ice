import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

/// Full-screen animated smoke overlay driven by GameState.smokeOpacity.
///
/// Smoke billows drift in the current wind direction. Two colour zones match
/// real wildfire plumes: dark charcoal/soot near the bottom of the screen
/// (proximal to the fire base) and cream/tan rising billows higher up.
///
/// Levels:
///   0.00–0.10  clear (no overlay)
///   0.10–0.40  haze — brownish vignette + sparse billows
///   0.40–0.65  light smoke — drifting billows spread inward, visibility reduced
///   0.65–0.85  heavy smoke — dense layered cover, ground obscured
///   0.85–1.00  IMC — near-total grey-brown cover, fly instruments
class SmokeOverlay extends StatefulWidget {
  final GameState state;
  const SmokeOverlay({super.key, required this.state});

  @override
  State<SmokeOverlay> createState() => _SmokeOverlayState();
}

class _SmokeOverlayState extends State<SmokeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    if (widget.state.smokeOpacity >= 0.05) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.smokeOpacity < 0.05) return const SizedBox.shrink();
    final ws = widget.state.windState;
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _SmokePainter(
            time:          _ctrl.value * 30.0,
            opacity:       widget.state.smokeOpacity,
            windAngle:     ws.windAngle,
            windStrength:  ws.windStrength,
            windMaxStr:    ws.cfgMaxStrength,
          ),
        ),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  final double time;
  final double opacity;
  final double windAngle;
  final double windStrength;
  final double windMaxStr;

  const _SmokePainter({
    required this.time,
    required this.opacity,
    required this.windAngle,
    required this.windStrength,
    required this.windMaxStr,
  });

  // Colour palette matching wildfire reference images.
  static const _kSoot  = Color(0xFF0E0B08); // near-black base soot
  static const _kAsh   = Color(0xFF2A2018); // dark warm charcoal
  static const _kGray  = Color(0xFF4A3E32); // medium brown-gray
  static const _kTan   = Color(0xFFB8A080); // warm tan mid-column
  static const _kCream = Color(0xFFD8C8A8); // pale cream rising billow
  static const _kIMC   = Color(0xFF080604); // near-black IMC fill

  @override
  void paint(Canvas canvas, Size size) {
    _drawVignette(canvas, size);
    if (opacity > 0.10) _drawBillows(canvas, size);
    if (opacity > 0.55) _drawDenseCurtain(canvas, size);
  }

  void _drawVignette(Canvas canvas, Size size) {
    final vigA = (opacity * 0.96).clamp(0.0, 0.96);
    final cx   = size.width  * 0.5;
    final cy   = size.height * 0.5;
    final r    = math.sqrt(cx * cx + cy * cy) * 1.30;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _kSoot.withValues(alpha: 0.0),
            _kAsh.withValues(alpha:  vigA * 0.45),
            _kSoot.withValues(alpha: vigA),
          ],
          stops: const [0.0, 0.40, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
  }

  void _drawBillows(Canvas canvas, Size size) {
    final billow = ((opacity - 0.10) / 0.90).clamp(0.0, 1.0);

    // Wind drift: project wind direction onto screen.
    // Wind angle = world XZ direction; project to screen as horizontal offset.
    final windNorm  = (windStrength / windMaxStr).clamp(0.0, 1.0);
    final driftX    =  math.cos(windAngle) * windNorm * 0.055;
    final driftY    =  math.sin(windAngle) * windNorm * 0.028; // Y is gentler

    final rng = math.Random(0x5A1E3B7C);
    final paint = Paint()..blendMode = BlendMode.srcOver;

    // 30 billows arranged in two altitude bands (lower = dark, upper = cream).
    for (int i = 0; i < 30; i++) {
      final bx     = rng.nextDouble();
      final by     = rng.nextDouble();
      final br     = 0.08 + rng.nextDouble() * 0.18;
      final speed  = 0.20 + rng.nextDouble() * 0.50;
      final phase  = rng.nextDouble() * math.pi * 2;
      final isLow  = by > 0.45; // lower half of screen = darker base

      // Drift primarily in wind direction; tiny circular wander for animation.
      final wanderX = math.cos(time * speed * 0.045 + phase) * 0.04;
      final wanderY = math.sin(time * speed * 0.030 + phase + 1.1) * 0.03;
      final cx = ((bx + driftX * time * speed + wanderX).clamp(0.0, 1.0)) * size.width;
      final cy = ((by + driftY * time * speed + wanderY).clamp(0.0, 1.0)) * size.height;
      final r  = br * size.width;

      // Base billow alpha: high — real wildfire smoke is thick.
      final pulse = 0.72 + 0.28 * math.sin(time * 0.14 + phase);
      final alpha = billow * (isLow ? 0.80 : 0.70) * pulse;

      // Colour: dark soot/ash near bottom, gray → cream rising.
      final Color inner, outer;
      if (isLow) {
        inner = _kAsh;
        outer = _kSoot;
      } else if (by < 0.30) {
        inner = _kCream;
        outer = _kTan;
      } else {
        inner = _kGray;
        outer = _kAsh;
      }

      paint.shader = RadialGradient(
        colors: [
          inner.withValues(alpha: (alpha * 1.30).clamp(0.0, 1.0)),
          inner.withValues(alpha: alpha * 0.80),
          outer.withValues(alpha: alpha * 0.25),
          outer.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.40, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _drawDenseCurtain(Canvas canvas, Size size) {
    final fill  = ((opacity - 0.55) / 0.45).clamp(0.0, 1.0);

    // Dark base layer covers the lower third of screen (fire base / ground).
    final baseH = size.height * (0.35 + fill * 0.30);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - baseH, size.width, baseH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [
            _kSoot.withValues(alpha: (fill * 0.95).clamp(0.0, 0.95)),
            _kAsh.withValues(alpha:  (fill * 0.70).clamp(0.0, 0.70)),
            _kAsh.withValues(alpha:  0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, size.height - baseH, size.width, baseH)),
    );

    // Mid-screen general fill (overall visibility reduction).
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _kAsh.withValues(alpha: (fill * 0.62).clamp(0.0, 0.62)),
    );

    // Horizontal smoke streaks drifting in wind direction.
    final streakCount = (fill * 9).ceil().clamp(4, 9);
    final windNorm    = (windStrength / windMaxStr).clamp(0.0, 1.0);
    for (int i = 0; i < streakCount; i++) {
      // Wind-shifted vertical position: streaks drift downward on screen with wind.
      final windShift = windNorm * time * 0.006 * (1.0 + i * 0.2);
      final yFrac     = ((i / streakCount) + windShift) % 1.0;
      final sh        = size.height * (0.06 + 0.10 * math.sin(i * 2.1 + 0.7));
      final y         = yFrac * size.height;
      final sAlpha    = fill * 0.45 * (0.60 + 0.40 * math.sin(time * 0.22 + i * 2.3));
      final c         = i.isEven ? _kAsh : _kGray;

      canvas.drawRect(
        Rect.fromLTWH(0, y - sh * 0.5, size.width, sh),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: 0.0),
              c.withValues(alpha: sAlpha),
              c.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, y - sh * 0.5, size.width, sh)),
      );
    }

    // IMC: near-total blackout above 0.85.
    if (opacity > 0.85) {
      final imcA = ((opacity - 0.85) / 0.15).clamp(0.0, 1.0);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _kIMC.withValues(alpha: (imcA * 0.90).clamp(0.0, 0.90)),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) =>
      old.time         != time        ||
      old.opacity      != opacity     ||
      old.windAngle    != windAngle   ||
      old.windStrength != windStrength;
}
