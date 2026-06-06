import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  final String reason;
  final VoidCallback onRestart;

  const GameOverOverlay({super.key, required this.reason, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Color(0xFFFF2200),
                fontSize: 72,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                shadows: [Shadow(color: Color(0xFFFF0000), blurRadius: 40)],
              ),
            ),
            const SizedBox(height: 20),
            if (reason.isNotEmpty)
              Text(
                reason,
                style: const TextStyle(
                  color: Color(0xFFFF8800),
                  fontSize: 20,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onRestart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0000),
                  border: Border.all(color: const Color(0xFFFF4400), width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CONTINUE FLYING',
                  style: TextStyle(
                    color: Color(0xFFFF8800),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
