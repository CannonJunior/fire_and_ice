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

    final ratio   = strength / wind.cfgMaxStrength;
    final opacity = (ratio * 0.45).clamp(0.0, 0.45);
    final len     = wind.cfgParticleLength * ratio;

    // Direction is computed by WindState.updateStreaks each frame.
    final sdx = wind.streakSdx;
    final sdy = wind.streakSdy;

    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final s in wind.streaks) {
      if (s.age >= s.maxAge) continue;

      // Fade in/out over lifetime — use ARGB integer to avoid Color allocation.
      final t    = s.age / s.maxAge;
      final fade = (t < 0.2 ? t / 0.2 : t > 0.8 ? (1 - t) / 0.2 : 1.0)
          .clamp(0.0, 1.0);
      final a = ((opacity * fade).clamp(0.0, 1.0) * 255).round();
      paint.color = Color((a << 24) | 0x00CCDDFF);

      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(s.x - sdx * len, s.y - sdy * len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WindPainter old) =>
      wind.windStrength >= 0.02 || old.wind.windStrength >= 0.02;
}
