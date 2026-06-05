import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'hud_ability_hex.dart';
import 'hud_gauges.dart';
import 'hud_tutorial.dart';

/// Build the complete third-person HUD overlay for the given [state].
Widget buildHud(
  GameState state, {
  bool showTelemetry    = true,
  bool showActionBar    = true,
  bool showTutorial     = false,
  Offset? hostileScreenPos,
  Offset? friendlyScreenPos,
  double screenW = 0,
  double screenH = 0,
}) {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return IgnorePointer(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 12, left: 12,
          child: FlightDataCluster(state: state),
        ),
        WarningTextZone(state: state),
        Positioned(
          bottom: 12, right: 12,
          child: HullIntegrityArc(state: state),
        ),
        if (showActionBar)
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ManaSegmentBar(state: state),
                  const SizedBox(height: 6),
                  AbilityHexRow(state: state),
                ],
              ),
            ),
          ),

        // ── Target info panels (top-right / top-left) ──────────────────────
        if (state.currentTarget != null)
          Positioned(
            top: 90, right: 12,
            child: _AnimeTargetLock(
              isHostile: true,
              targetName: state.currentTarget!.label,
              distance: _dist2d(state.currentTarget!, state),
              extraLine: _hostileExtra(state.currentTarget!, state),
              animMs: ms,
            ),
          ),

        if (state.currentFriendlyTarget != null)
          Positioned(
            top: 120, left: 12,
            child: _AnimeTargetLock(
              isHostile: false,
              targetName: state.currentFriendlyTarget!.label,
              distance: _dist2d(state.currentFriendlyTarget!, state),
              extraLine: _friendlyExtra(state.currentFriendlyTarget!, state),
              animMs: ms,
            ),
          ),

        // ── World-space target brackets ─────────────────────────────────────
        if (hostileScreenPos != null)
          ..._worldIndicator(
            screenPos: hostileScreenPos,
            isHostile: true,
            label: state.currentTarget!.label,
            distance: _dist2d(state.currentTarget!, state),
            animMs: ms,
            screenW: screenW,
            screenH: screenH,
          ),

        if (friendlyScreenPos != null)
          ..._worldIndicator(
            screenPos: friendlyScreenPos,
            isHostile: false,
            label: state.currentFriendlyTarget!.label,
            distance: _dist2d(state.currentFriendlyTarget!, state),
            animMs: ms,
            screenW: screenW,
            screenH: screenH,
          ),

        if (showTutorial) buildTutorialOverlay(state),
      ],
    ),
  );
}

// ── World-space indicator ─────────────────────────────────────────────────────

const double _boxHalf  = 38.0;  // half-size of the bracket box
const double _boxSize  = _boxHalf * 2;
const double _edgePad  = 20.0;  // padding from screen edge for off-screen arrow

/// Returns one or two Positioned widgets: bracket (on-screen) or edge arrow (off-screen).
List<Widget> _worldIndicator({
  required Offset screenPos,
  required bool isHostile,
  required String label,
  required double distance,
  required int animMs,
  required double screenW,
  required double screenH,
}) {
  final Color primary = isHostile ? const Color(0xFFFF5500) : const Color(0xFF00DDBB);
  final bool onScreen = screenW > 0 && screenH > 0 &&
      screenPos.dx >= 0 && screenPos.dx <= screenW &&
      screenPos.dy >= 0 && screenPos.dy <= screenH;

  if (onScreen) {
    return [
      Positioned(
        left: screenPos.dx - _boxHalf,
        top:  screenPos.dy - _boxHalf,
        child: _OnScreenBracket(
          primary: primary,
          isHostile: isHostile,
          label: label,
          distance: distance,
          animMs: animMs,
        ),
      ),
    ];
  }

  // Off-screen: clamp to edge and show directional arrow.
  if (screenW <= 0 || screenH <= 0) return const [];
  final cx = screenW / 2, cy = screenH / 2;
  final dx = screenPos.dx - cx, dy = screenPos.dy - cy;
  final angle = math.atan2(dy, dx);
  final cos = math.cos(angle), sin = math.sin(angle);

  // Intersect the ray from center with the screen rect (padded inward by _edgePad).
  final maxX = cx - _edgePad, maxY = cy - _edgePad;
  double t = double.infinity;
  if (cos.abs() > 0.0001) t = math.min(t, maxX / cos.abs());
  if (sin.abs() > 0.0001) t = math.min(t, maxY / sin.abs());
  final ex = cx + cos * t;
  final ey = cy + sin * t;

  return [
    Positioned(
      left: ex - 12,
      top:  ey - 12,
      child: CustomPaint(
        size: const Size(24, 24),
        painter: _EdgeArrowPainter(angle: angle, color: primary),
      ),
    ),
  ];
}

// ── On-screen bracket widget ──────────────────────────────────────────────────

class _OnScreenBracket extends StatelessWidget {
  final Color primary;
  final bool isHostile;
  final String label;
  final double distance;
  final int animMs;

  const _OnScreenBracket({
    required this.primary,
    required this.isHostile,
    required this.label,
    required this.distance,
    required this.animMs,
  });

  @override
  Widget build(BuildContext context) {
    final double glow   = (math.sin(animMs / 600.0) + 1) / 2;
    final double rotate = (animMs % 4000) / 4000.0 * 2 * math.pi;
    final double breath = 1.0 + math.sin(animMs / 900.0) * 0.04; // subtle scale pulse

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: breath,
          child: SizedBox(
            width: _boxSize,
            height: _boxSize,
            child: Stack(
              children: [
                // Corner brackets
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TargetBracketPainter(color: primary, glow: glow),
                  ),
                ),
                // Rotating diamond reticle in center
                Center(
                  child: Transform.rotate(
                    angle: rotate,
                    child: CustomPaint(
                      size: const Size(12, 12),
                      painter: _DiamondPainter(color: primary, glow: glow),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Label tag below bracket
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.15),
            border: Border.all(color: primary.withOpacity(0.5), width: 0.5),
          ),
          child: Text(
            '${label}  ${distance.toStringAsFixed(0)}m',
            style: TextStyle(
              color: primary,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Target bracket painter (L-shaped corners + mid-side ticks) ────────────────

class _TargetBracketPainter extends CustomPainter {
  final Color color;
  final double glow; // 0..1

  const _TargetBracketPainter({required this.color, required this.glow});

  static const double _arm  = 14.0;
  static const double _tick = 5.0;
  static const double _lw   = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (0.6 + 0.4 * glow).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withOpacity(alpha)
      ..strokeWidth = _lw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width, h = size.height;

    // Corner L-brackets
    // Top-left
    canvas.drawLine(Offset(0, _arm), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(_arm, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - _arm, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, _arm), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - _arm), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(_arm, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - _arm, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - _arm), paint);

    // Mid-side tick marks
    final tickPaint = Paint()
      ..color = color.withOpacity(alpha * 0.5)
      ..strokeWidth = _lw * 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w / 2 - _tick, 0), Offset(w / 2 + _tick, 0), tickPaint);
    canvas.drawLine(Offset(w / 2 - _tick, h), Offset(w / 2 + _tick, h), tickPaint);
    canvas.drawLine(Offset(0, h / 2 - _tick), Offset(0, h / 2 + _tick), tickPaint);
    canvas.drawLine(Offset(w, h / 2 - _tick), Offset(w, h / 2 + _tick), tickPaint);

    // Glow layer
    if (glow > 0.2) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.08 * glow)
        ..strokeWidth = _lw + 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);
    }
  }

  @override
  bool shouldRepaint(_TargetBracketPainter old) =>
      old.glow != glow || old.color != color;
}

// ── Rotating diamond reticle ──────────────────────────────────────────────────

class _DiamondPainter extends CustomPainter {
  final Color color;
  final double glow;

  const _DiamondPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy);
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.9 + 0.1 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.2 * glow)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.glow != glow || old.color != color;
}

// ── Off-screen edge arrow ─────────────────────────────────────────────────────

class _EdgeArrowPainter extends CustomPainter {
  final double angle; // radians: direction from screen center to target
  final Color color;

  const _EdgeArrowPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    // Arrow tip points in the direction of the target
    const tip  = 10.0;
    const base = 7.0;
    final path = Path()
      ..moveTo(tip, 0)
      ..lineTo(-base / 2, -base / 2)
      ..lineTo(-base / 2,  base / 2)
      ..close();
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_EdgeArrowPainter old) =>
      old.angle != angle || old.color != color;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _dist2d(
  ({String id, String label, double wx, double wz, double wy}) t,
  GameState state,
) {
  final dx = t.wx - state.playerPosition.x;
  final dz = t.wz - state.playerPosition.z;
  return math.sqrt(dx * dx + dz * dz);
}

String _hostileExtra(
  ({String id, String label, double wx, double wz, double wy}) t,
  GameState state,
) {
  if (t.id.startsWith('fire_')) {
    final idx = int.tryParse(t.id.substring(5)) ?? 0;
    final (fx, fz) = GameState.firePositions[idx];
    final dx = fx - 0.0, dz = fz - (-55.0);
    final dist = math.sqrt(dx * dx + dz * dz);
    final threat = dist < 40 ? 'CRITICAL' : dist < 70 ? 'ELEVATED' : 'MODERATE';
    return 'BASE RISK ▸ $threat';
  }
  try {
    final w = state.wyverns.firstWhere((w) => w.id == t.id);
    final hp = (w.health / w.maxHealth * 100).round();
    return 'INTEGRITY ▸ $hp%';
  } catch (_) {
    return '';
  }
}

String _friendlyExtra(
  ({String id, String label, double wx, double wz, double wy}) t,
  GameState state,
) {
  if (t.id == 'tanker') {
    return state.probeConnected ? 'STATUS ▸ CONNECTED' : 'STATUS ▸ AVAILABLE';
  }
  if (t.id == 'airbase') {
    final level = state.airbaseThreatLevel;
    final status = level > 0.6 ? 'UNDER THREAT' : level > 0.2 ? 'ALERT' : 'NOMINAL';
    return 'STATUS ▸ $status';
  }
  return '';
}

// ── Anime Target Lock info panel ──────────────────────────────────────────────

class _AnimeTargetLock extends StatelessWidget {
  final bool isHostile;
  final String targetName;
  final double distance;
  final String extraLine;
  final int animMs;

  const _AnimeTargetLock({
    required this.isHostile,
    required this.targetName,
    required this.distance,
    required this.extraLine,
    required this.animMs,
  });

  static const double _maxRange = 180.0;

  @override
  Widget build(BuildContext context) {
    final Color primary    = isHostile ? const Color(0xFFFF5500) : const Color(0xFF00DDBB);
    final Color accent     = isHostile ? const Color(0xFFFFAA00) : const Color(0xFF00AAFF);
    final Color bg         = isHostile ? const Color(0xCC100500) : const Color(0xCC001018);
    final String lockLabel = isHostile ? 'TARGET LOCK' : 'IFF CONFIRM';
    final String icon      = isHostile ? '◉' : '◈';

    final double glow  = (math.sin(animMs / 500.0) + 1) / 2;
    final bool blink   = (animMs % 700) < 450;
    final double scan  = (animMs % 1200) / 1200.0;
    final double prox  = (1.0 - (distance / _maxRange)).clamp(0.0, 1.0);
    final int barFull  = (prox * 8).round();

    return CustomPaint(
      painter: _BracketPainter(color: primary, glow: glow),
      child: Container(
        width: 210,
        color: bg,
        child: Stack(
          children: [
            Positioned(
              left: 0, right: 0,
              top: 72 * scan,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    primary.withOpacity(0.25 * glow),
                    primary.withOpacity(0.15 * glow),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('$icon ', style: TextStyle(color: primary, fontSize: 9)),
                    Text(lockLabel,
                      style: TextStyle(color: primary, fontSize: 9,
                          letterSpacing: 1.8, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (blink) Text('▪', style: TextStyle(color: accent, fontSize: 10)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(width: 4, height: 1, color: primary),
                      Container(width: 100, height: 1, color: primary.withOpacity(0.35)),
                      Container(width: 4, height: 1, color: primary),
                    ]),
                  ),
                  Text(targetName,
                    style: TextStyle(color: accent, fontSize: 14,
                        fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Text('DIST', style: TextStyle(color: primary.withOpacity(0.7),
                        fontSize: 9, letterSpacing: 1.2)),
                    const SizedBox(width: 4),
                    Text('▸', style: TextStyle(color: primary, fontSize: 9)),
                    const SizedBox(width: 5),
                    Text('${distance.toStringAsFixed(1)} m',
                      style: const TextStyle(color: Colors.white70, fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                  const SizedBox(height: 4),
                  _ProxBar(filled: barFull, total: 8, color: primary, accent: accent),
                  if (extraLine.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(extraLine, style: TextStyle(color: primary.withOpacity(0.8),
                        fontSize: 9, letterSpacing: 0.8)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Proximity bar ─────────────────────────────────────────────────────────────

class _ProxBar extends StatelessWidget {
  final int filled, total;
  final Color color, accent;

  const _ProxBar({
    required this.filled, required this.total,
    required this.color,  required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('PROX ', style: TextStyle(color: color.withOpacity(0.7),
            fontSize: 8, letterSpacing: 1)),
        ...List.generate(total, (i) {
          final active = i < filled;
          return Container(
            width: 14, height: 6,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: active
                  ? (i >= total - 2 ? accent : color.withOpacity(0.85))
                  : color.withOpacity(0.15),
              border: Border.all(
                  color: color.withOpacity(active ? 0.8 : 0.3), width: 0.5),
            ),
          );
        }),
      ],
    );
  }
}

// ── Info-panel corner bracket painter ────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Color color;
  final double glow;

  const _BracketPainter({required this.color, required this.glow});

  static const double _arm = 14.0;
  static const double _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (0.55 + 0.45 * glow).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withOpacity(alpha)
      ..strokeWidth = _width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width, h = size.height;
    canvas.drawLine(Offset(0, _arm), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(_arm, 0), paint);
    canvas.drawLine(Offset(w - _arm, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, _arm), paint);
    canvas.drawLine(Offset(0, h - _arm), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(_arm, h), paint);
    canvas.drawLine(Offset(w - _arm, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - _arm), paint);

    if (glow > 0.3) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()
        ..color = color.withOpacity(0.12 * glow)
        ..strokeWidth = _width + 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.glow != glow || old.color != color;
}
