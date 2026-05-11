import 'package:flutter/material.dart';
import '../data/abilities.dart';
import 'game_state.dart';

/// HudWidgets - Stateless HUD builder functions for Fire & Ice.
///
/// Extracted from game_widget.dart to keep that file under 500 lines.
/// All methods are static and take [GameState] as input so they remain
/// pure functions with no internal state.

/// Build the complete HUD overlay for the given [state].
Widget buildHud(GameState state) {
  return IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          buildTitle(),
          buildVitals(state),
          Positioned(bottom: 0, right: 0, child: buildFlightInfo(state)),
          Positioned(
            bottom: 0,
            left: 0, right: 0,
            child: Center(child: buildActionBar(state)),
          ),
        ],
      ),
    ),
  );
}

/// Top-centre game title banner.
Widget buildTitle() {
  return Align(
    alignment: Alignment.topCenter,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'FIRE & ICE',
        style: TextStyle(
          color:         Color(0xFFE8A020),
          fontSize:      20,
          fontWeight:    FontWeight.bold,
          letterSpacing: 4,
        ),
      ),
    ),
  );
}

/// Top-left health and mana bars.
Widget buildVitals(GameState state) {
  return Align(
    alignment: Alignment.topLeft,
    child: Column(
      mainAxisSize:        MainAxisSize.min,
      crossAxisAlignment:  CrossAxisAlignment.start,
      children: [
        _bar(label: 'HP', value: state.health / GameState.maxHealth,
             color: const Color(0xFFCC2222)),
        const SizedBox(height: 6),
        _bar(label: 'MP', value: state.mana / GameState.maxMana,
             color: const Color(0xFF2266CC)),
      ],
    ),
  );
}

Widget _bar({
  required String label,
  required double value,
  required Color  color,
  double width = 180,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 28,
        child: Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ),
      Container(
        width:  width,
        height: 14,
        decoration: BoxDecoration(
          color:        Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border:       Border.all(color: Colors.white24),
        ),
        child: FractionallySizedBox(
          alignment:   Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('${(value * 100).toInt()}',
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );
}

/// Bottom-right flight telemetry readout.
Widget buildFlightInfo(GameState state) {
  const style = TextStyle(color: Colors.white70, fontSize: 11, height: 1.6);

  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color:        Colors.black54,
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize:       MainAxisSize.min,
      children: [
        Text('ALT   ${state.flightAltitude.toStringAsFixed(1)} m',   style: style),
        Text('SPD   ${state.flightSpeed.toStringAsFixed(1)} u/s',    style: style),
        Text('PCH  ${state.flightPitchAngle.toStringAsFixed(1)}°',   style: style),
        Text('BNK  ${state.flightBankAngle.toStringAsFixed(1)}°',    style: style),
        if (state.isBarrelRolling)
          const Text(
            'BARREL ROLL',
            style: TextStyle(
              color:      Color(0xFFFFAA00),
              fontSize:   11,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    ),
  );
}

/// Bottom-centre 10-slot ability action bar.
Widget buildActionBar(GameState state) {
  return Container(
    margin:  const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color:        Colors.black54,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children:     List.generate(10, (i) => _slot(state, i)),
    ),
  );
}

Widget _slot(GameState state, int index) {
  final slotName = state.actionBarSlots[index];
  final AbilityData? ability =
      slotName.isNotEmpty ? state.abilityByName(slotName) : null;
  final cooldown = ability != null
      ? (state.abilityCooldowns[ability.name] ?? 0.0)
      : 0.0;
  final onCd     = cooldown > 0.0;
  final keyLabel = index == 9 ? '0' : '${index + 1}';

  final borderColor = ability != null
      ? Color.fromRGBO(
          (ability.color.x * 255).toInt(),
          (ability.color.y * 255).toInt(),
          (ability.color.z * 255).toInt(),
          0.8,
        )
      : Colors.white12;

  return Container(
    width:  52,
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color:        onCd ? Colors.black54 : Colors.black38,
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: borderColor, width: 1.5),
    ),
    child: Stack(
      children: [
        // Icon + short name
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ability?.icon ?? '',
                style:     const TextStyle(fontSize: 18),
                textAlign: TextAlign.center),
            if (ability != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ability.name.split(' ').last,
                  style:     const TextStyle(fontSize: 7.5, color: Colors.white70),
                  textAlign: TextAlign.center,
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        // Cooldown overlay
        if (onCd)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color:        Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  cooldown.toStringAsFixed(1),
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        // Slot key badge
        Positioned(
          top: 2, left: 4,
          child: Text(keyLabel,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ),
      ],
    ),
  );
}
