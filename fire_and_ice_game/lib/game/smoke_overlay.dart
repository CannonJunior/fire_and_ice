import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';

/// Full-screen animated smoke overlay driven by GameState.smokeOpacity.
///
/// Positioned in the Flutter stack between wind streaks and the cockpit
/// instrument panel — so instruments remain readable at all smoke levels
/// while the external view (WebGL canvas) is progressively obscured.
///
/// Levels:
///   0.00–0.20  clear (no overlay rendered)
///   0.20–0.40  haze — brownish vignette at edges
///   0.40–0.65  light smoke — drifting billows spread inward
///   0.65–0.85  heavy smoke — significant visibility reduction
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
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _SmokePainter(
            time: _ctrl.value * 30.0,
            opacity: widget.state.smokeOpacity,
          ),
        ),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  final double time;
  final double opacity;

  const _SmokePainter({required this.time, required this.opacity});

  static const _kBase = Color(0xFF2C2520); // dark warm charcoal
  static const _kAsh  = Color(0xFF18150F); // near-black ash
  static const _kIMC  = Color(0xFF0C0A08); // almost black IMC fill

  @override
  void paint(Canvas canvas, Size size) {
    _drawVignette(canvas, size);
    if (opacity > 0.20) _drawBillows(canvas, size);
    if (opacity > 0.65) _drawDenseCurtain(canvas, size);
  }

  void _drawVignette(Canvas canvas, Size size) {
    final vigA  = (opacity * 0.94).clamp(0.0, 0.94);
    final cx    = size.width * 0.5;
    final cy    = size.height * 0.5;
    final r     = math.sqrt(cx * cx + cy * cy) * 1.25;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kBase.withValues(alpha: 0.0),
          _kBase.withValues(alpha: vigA * 0.50),
          _kAsh.withValues(alpha: vigA),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawBillows(Canvas canvas, Size size) {
    final billow = ((opacity - 0.20) / 0.80).clamp(0.0, 1.0);
    final paint  = Paint()..blendMode = BlendMode.srcOver;
    final rng    = math.Random(0x5A1E3B7C); // seeded → stable base positions

    for (int i = 0; i < 14; i++) {
      final bx    = rng.nextDouble();
      final by    = rng.nextDouble();
      final br    = 0.07 + rng.nextDouble() * 0.14;
      final speed = 0.25 + rng.nextDouble() * 0.45;
      final phase = rng.nextDouble() * math.pi * 2;

      final cx = ((bx + math.cos(time * speed * 0.055 + phase) * 0.13)
          .clamp(0.0, 1.0)) * size.width;
      final cy = ((by + math.sin(time * speed * 0.040 + phase + 1.1) * 0.09)
          .clamp(0.0, 1.0)) * size.height;
      final r   = br * size.width;
      final pulse = 0.5 + 0.5 * math.sin(time * 0.18 + phase);
      final alpha = billow * (0.18 + rng.nextDouble() * 0.27) * pulse;

      final c = Color.lerp(_kBase, _kAsh, rng.nextDouble())!;
      paint.shader = RadialGradient(
        colors: [
          c.withValues(alpha: (alpha * 1.5).clamp(0.0, 1.0)),
          c.withValues(alpha: alpha * 0.55),
          c.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _drawDenseCurtain(Canvas canvas, Size size) {
    final fill  = ((opacity - 0.65) / 0.35).clamp(0.0, 1.0);
    final baseA = (fill * 0.90).clamp(0.0, 0.90);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _kAsh.withValues(alpha: baseA * 0.72),
    );

    // Horizontal smoke streaks that drift slowly across screen.
    final streakCount = (fill * 7).ceil().clamp(3, 7);
    for (int i = 0; i < streakCount; i++) {
      final yFrac  = ((i / streakCount) + time * 0.008 * (1.0 + i * 0.3)) % 1.0;
      final sh     = size.height * (0.05 + 0.09 * math.sin(i * 1.9 + 0.5));
      final y      = yFrac * size.height;
      final sAlpha = fill * 0.38 * (0.65 + 0.35 * math.sin(time * 0.25 + i * 2.1));

      canvas.drawRect(
        Rect.fromLTWH(0, y - sh * 0.5, size.width, sh),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kIMC.withValues(alpha: 0.0),
              _kIMC.withValues(alpha: sAlpha),
              _kIMC.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, y - sh * 0.5, size.width, sh)),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) =>
      old.time != time || old.opacity != opacity;
}
