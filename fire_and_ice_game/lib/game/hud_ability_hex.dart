import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/abilities.dart';
import 'game_state.dart';
import 'hud_gauges.dart';

// ── Mana Segment Bar ──────────────────────────────────────────────────────────

/// Segmented mana bar centred above the ability row.
///
/// Divided into N segments where N = maxMana / firstAbility.manaCost.
/// Filled segments glow kManaFill; empty segments use kPolarNight.
class ManaSegmentBar extends StatelessWidget {
  final GameState state;
  const ManaSegmentBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    AbilityData? ref;
    for (final name in state.actionBarSlots) {
      if (name.isNotEmpty) {
        ref = state.abilityByName(name);
        if (ref != null) break;
      }
    }
    if (ref == null) return const SizedBox.shrink();

    final segCount = (GameState.maxMana / ref.manaCost).floor().clamp(1, 20);
    final filled   = (state.mana / ref.manaCost).floor().clamp(0, segCount);

    return SizedBox(
      width: 280,
      height: 8,
      child: CustomPaint(
        painter: _ManaBarPainter(total: segCount, filled: filled),
      ),
    );
  }
}

class _ManaBarPainter extends CustomPainter {
  final int total;
  final int filled;
  const _ManaBarPainter({required this.total, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    const divW = 3.0;
    final segW = (size.width - divW * (total - 1)) / total;
    final r    = size.height / 2;

    for (int i = 0; i < total; i++) {
      final x    = i * (segW + divW);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, segW, size.height), Radius.circular(r));
      canvas.drawRRect(rect,
        Paint()..color = i < filled ? kManaFill : kPolarNight);
    }
  }

  @override
  bool shouldRepaint(_ManaBarPainter o) =>
      o.total != total || o.filled != filled;
}

// ── Ability Hex Row ───────────────────────────────────────────────────────────

/// Horizontal row of hexagonal ability tiles for the bottom-centre HUD.
///
/// Shows up to 6 filled action-bar slots. Each tile displays the ability icon,
/// a radial cooldown sweep, a mana cost arc, and a ready-state border glow.
class AbilityHexRow extends StatelessWidget {
  final GameState state;
  const AbilityHexRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (int i = 0;
        i < state.actionBarSlots.length && tiles.length < 11;
        i++) {
      final name = state.actionBarSlots[i];
      if (name.isEmpty) continue;
      final ab = state.abilityByName(name);
      if (ab == null) continue;
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 4));
      tiles.add(_HexTile(ability: ab, state: state, slotIndex: i));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAbyssNavy.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: tiles),
    );
  }
}

// ── Single Hex Tile ───────────────────────────────────────────────────────────

class _HexTile extends StatelessWidget {
  final AbilityData ability;
  final GameState   state;
  final int         slotIndex;

  const _HexTile({
    required this.ability,
    required this.state,
    required this.slotIndex,
  });

  @override
  Widget build(BuildContext context) {
    final cd     = state.abilityCooldowns[ability.name] ?? 0.0;
    final cdMax  = ability.cooldown.clamp(0.01, double.infinity);
    final cdFrac = (cd / cdMax).clamp(0.0, 1.0);
    final ready  = cd <= 0.0;
    final mana   = state.hasManaFor(ability);

    final abColor = Color.fromRGBO(
      (ability.color.x * 255).toInt(),
      (ability.color.y * 255).toInt(),
      (ability.color.z * 255).toInt(),
      1.0,
    );

    return SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hex shape with cooldown sweep and mana arc
          Positioned.fill(
            child: CustomPaint(
              painter: _HexPainter(
                abilityColor:  abColor,
                cdFrac:        cdFrac,
                hasMana:       mana,
                isReady:       ready,
                manaCostFrac:  ability.manaCost / GameState.maxMana,
              ),
            ),
          ),

          // Ability icon (desaturated on cooldown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: cdFrac > 0 ? 0.35 : 1.0,
              child: Text(
                ability.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),

          // Cooldown countdown text
          if (cdFrac > 0.01)
            Text(
              cd.toStringAsFixed(1),
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.bold,
              ),
            ),

          // Slot-number badge (top-left corner)
          Positioned(
            top: 4, left: 7,
            child: Text(
              slotIndex == 9 ? '0' : '${slotIndex + 1}',
              style: const TextStyle(color: kIceShelf, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hex CustomPainter ─────────────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  final Color  abilityColor;
  final double cdFrac;
  final bool   hasMana;
  final bool   isReady;
  final double manaCostFrac; // ability.manaCost / maxMana

  const _HexPainter({
    required this.abilityColor,
    required this.cdFrac,
    required this.hasMana,
    required this.isReady,
    required this.manaCostFrac,
  });

  /// Pointy-top hexagon path centred at (cx, cy) with circumradius r.
  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * 60 - 90) * math.pi / 180.0;
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    // Circumradius: fit within both width and height, with 2px margin.
    final r  = math.min(size.width  / math.sqrt(3),
                        size.height / 2) - 2;

    final hex = _hexPath(cx, cy, r);

    // Background fill
    canvas.drawPath(hex, Paint()..color = kAbyssNavy);

    // Cooldown pie overlay (dark blue, swept clockwise from top)
    if (cdFrac > 0.01) {
      canvas.save();
      canvas.clipPath(hex);
      final pie = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r * 2),
          -math.pi / 2,          // start at top
          cdFrac * 2 * math.pi,  // sweep CW proportional to remaining CD
          false,
        )
        ..close();
      canvas.drawPath(pie,
        Paint()..color = const Color(0xFF001830).withValues(alpha: 0.65));
      canvas.restore();
    }

    // Mana cost arc at bottom of hex.
    // Arc span scales with manaCostFrac (max 140° for 100% cost).
    final arcSpan  = manaCostFrac * math.pi * 1.4;
    final arcStart = math.pi / 2 - arcSpan / 2; // centre arc on bottom
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy + 2), radius: r - 5),
      arcStart, arcSpan, false,
      Paint()
        ..color = hasMana ? kManaFill : kDanger
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Border: ability color when ready, danger when out of mana, dim otherwise
    final borderColor =
        !hasMana ? kDanger : isReady ? abilityColor : kIceShelf;
    canvas.drawPath(hex,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isReady ? 2.0 : 1.0);
  }

  @override
  bool shouldRepaint(_HexPainter o) =>
      o.cdFrac   != cdFrac   ||
      o.hasMana  != hasMana  ||
      o.isReady  != isReady;
}
