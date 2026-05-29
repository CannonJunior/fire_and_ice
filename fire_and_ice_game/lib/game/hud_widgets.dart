import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'hud_ability_hex.dart';
import 'hud_gauges.dart';
import 'hud_tutorial.dart';

/// Build the complete third-person HUD overlay for the given [state].
///
/// Layout (HUD_DESIGN_RESEARCH.md §1):
///  - Top-left:     FlightDataCluster (ALT / SPD / HDG)
///  - Top-centre:   WarningTextZone (STALL, LOW MANA, etc.)
///  - Bottom-right: HullIntegrityArc (10-segment arc gauge)
///  - Bottom-centre: ManaSegmentBar + AbilityHexRow
///
/// [showActionBar] controls the ability row + mana bar.
/// [showTelemetry] is retained for API compatibility.
/// [showTutorial] overlays explainer cards on every element.
Widget buildHud(
  GameState state, {
  bool showTelemetry = true,
  bool showActionBar = true,
  bool showTutorial  = false,
}) {
  return IgnorePointer(
    child: Stack(
      children: [
        // Top-left: airspeed / altitude / heading
        Positioned(
          top: 12, left: 12,
          child: FlightDataCluster(state: state),
        ),

        // Top-centre: stall / low-mana / hull-critical warnings
        WarningTextZone(state: state),

        // Bottom-right: hull integrity arc (replaces health bar)
        Positioned(
          bottom: 12, right: 12,
          child: HullIntegrityArc(state: state),
        ),

        // Bottom-centre: mana segments + ability hex row
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

        // Target indicator (top-right, below mode badges)
        if (state.currentTarget != null)
          Positioned(top: 48, right: 115, child: _targetChip(state)),

        // Tutorial explainer cards (topmost layer)
        if (showTutorial) buildTutorialOverlay(state),
      ],
    ),
  );
}

Widget _targetChip(GameState state) {
  final t = state.currentTarget!;
  final dx = t.wx - state.playerPosition.x;
  final dz = t.wz - state.playerPosition.z;
  final dist = math.sqrt(dx * dx + dz * dz);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x991A0800),
      border: Border.all(color: const Color(0xFFFF8800)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text('◎ ${t.label}  ${dist.toStringAsFixed(0)} m',
      style: const TextStyle(
        color: Color(0xFFFF8800), fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}
