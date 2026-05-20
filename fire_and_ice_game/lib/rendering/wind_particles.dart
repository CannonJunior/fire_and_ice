import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/wind_state.dart';

/// Cockpit windshield wind-streak overlay.
///
/// Renders semi-transparent white streaks that move across the screen in the
/// direction the wind appears to come from relative to the aircraft heading.
/// Only visible in cockpit view — hidden in third-person mode.
///
/// Particle positions live in [WindState]; this widget just draws them.
class WindParticleOverlay extends StatelessWidget {
  final GameState state;
  const WindParticleOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.viewMode != ViewMode.cockpit) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _WindPainter(state.windState),
        ),
      ),
    );
  }
}

class _WindPainter extends CustomPainter {
  final WindState wind;
  _WindPainter(this.wind);

  @override
  void paint(Canvas canvas, Size size) {
    final strength = wind.windStrength;
    if (strength < 0.02) return;

    // Opacity scales with wind strength (subtle even at max).
    final opacity = (strength / wind.cfgMaxStrength * 0.45).clamp(0.0, 0.45);

    final paint = Paint()
      ..color = const Color(0xFFCCDDFF).withValues(alpha: opacity)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Screen-space direction the streaks travel (unit vector).
    final yawDeg = 0.0; // direction is baked into streak positions via updateStreaks
    final relAngle = wind.windAngle - yawDeg * (math.pi / 180.0);
    final sdx = math.sin(relAngle);
    final sdy = -math.cos(relAngle);

    final len = wind.cfgParticleLength * (strength / wind.cfgMaxStrength);

    for (final s in wind.streaks) {
      if (s.age >= s.maxAge) continue;

      // Fade in/out over lifetime.
      final t = s.age / s.maxAge;
      final fade = (t < 0.2 ? t / 0.2 : t > 0.8 ? (1 - t) / 0.2 : 1.0)
          .clamp(0.0, 1.0);

      final x2 = s.x - sdx * len;
      final y2 = s.y - sdy * len;

      paint.color = const Color(0xFFCCDDFF)
          .withValues(alpha: (opacity * fade).clamp(0.0, 1.0));
      canvas.drawLine(Offset(s.x, s.y), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_WindPainter old) => true;
}
