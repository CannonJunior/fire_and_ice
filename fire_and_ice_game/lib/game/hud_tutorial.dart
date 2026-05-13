import 'package:flutter/material.dart';
import 'game_state.dart';
import 'hud_gauges.dart'; // color tokens

// ── Tutorial overlay ──────────────────────────────────────────────────────────

/// Overlay that labels every HUD element with a brief explanation.
///
/// Activated via Settings → HUD → Tutorial Labels. Rendered as an
/// [IgnorePointer] Stack so it never captures input.  All card positions
/// are fixed offsets that mirror the known layout from hud_widgets.dart
/// and cockpit_hud.dart.
Widget buildTutorialOverlay(GameState state) {
  final cards = <Widget>[];

  if (state.viewMode == ViewMode.thirdPerson) {
    cards.addAll(_thirdPersonCards());
  } else {
    cards.addAll(_cockpitCards());
  }

  return IgnorePointer(child: Stack(children: cards));
}

// ── Third-person labels ────────────────────────────────────────────────────────

List<Widget> _thirdPersonCards() => [
  // FlightDataCluster — top-left, sits below the cluster (starts ~80px from top)
  _card(
    left: 14, top: 108,
    title: 'Flight Data',
    body:  'ALT · SPD · HDG readouts.\nPCH shows when pitching > 0.5°.',
  ),

  // FireProximitySensor — bottom-left (120 × 120px).
  // Card appears to its right, at the same vertical centre.
  _card(
    left: 140, bottom: 30,
    title: 'Fire Proximity Sensor',
    body:  'Circular threat display.\nEmber dots = fire elementals.\n'
           'Arc fill = combined heat.\nRed ring = danger zone.',
  ),

  // HullIntegrityArc — bottom-right (100 × 88px).
  // Card appears to its left.
  _card(
    right: 120, bottom: 30,
    title: 'Hull Integrity',
    body:  '10 arc segments = ice armour.\nBlue → purple → orange as damaged.\n'
           'Regen pauses near fire elementals.',
    alignRight: true,
  ),

  // ManaSegmentBar — bottom-centre, 8px tall bar above the ability row.
  // Card appears above it.
  _centredCard(
    bottom: 118,
    title: 'Mana Reserve',
    body:  'Each segment = one ability cast.\nFills continuously during flight.',
  ),

  // AbilityHexRow — bottom-centre, hex tiles.
  // Card appears above the mana bar card (so not blocking the row itself).
  _centredCard(
    bottom: 190,
    title: 'Abilities  ·  keys 1 – 4',
    body:  'Hex border glows when ready.\nCooldown sweep shows recharge time.\n'
           'Red border = insufficient mana.\nMana cost arc at hex bottom.',
  ),

  // WarningTextZone hint — top-centre
  _centredCard(
    top: 12,
    title: 'Warning Zone',
    body:  'Alerts appear here: STALL · PULL UP\nLOW MANA · HULL CRITICAL',
  ),
];

// ── Cockpit view labels ───────────────────────────────────────────────────────

List<Widget> _cockpitCards() => [
  // Windshield SPD readout — left edge, vertically centred
  _card(
    left: 14, top: 140,
    title: 'Airspeed',
    body:  'Current flight speed in u/s.',
  ),

  // Windshield ALT readout — right edge
  _card(
    right: 14, top: 140,
    title: 'Altitude',
    body:  'Height above terrain in metres.',
    alignRight: true,
  ),

  // Heading strip — near top-centre
  _centredCard(
    top: 60,
    title: 'Heading / Pitch / Bank',
    body:  'Live attitude strip at top of windshield.',
  ),

  // Left MFD — bottom-left area of cockpit panel
  _card(
    left: 14, bottom: 220,
    title: 'Left MFD',
    body:  'ELMT: elements page\nLOAD: payload status\n'
           'STAT: system status\nMODE: flight modes\n\n'
           'Ability buttons below: 1–4.',
  ),

  // Center column — bottom-centre
  _centredCard(
    bottom: 290,
    title: 'Centre Panel',
    body:  'Annunciator: master-warning lights\n'
           'Suppression: retardant controls\n'
           'Gear lever · Throttle · Attitude gyro',
  ),

  // Right MFD — bottom-right area
  _card(
    right: 14, bottom: 220,
    title: 'Right MFD',
    body:  'NAV: navigation map\nTERR: terrain awareness\n'
           'FIRE: fire elemental sensor\nMARK: waypoint management\n\n'
           'ZOOM · AUTO (autopilot) · LOCK · CLR',
    alignRight: true,
  ),

  // FireProximitySensor (also shown in cockpit view, bottom-left corner)
  _card(
    left: 140, bottom: 30,
    title: 'Fire Proximity Sensor',
    body:  'Persists in both views.\nEmber dots = fire elementals.\nArc = heat intensity.',
  ),

  // HullIntegrityArc (also shown in cockpit view, bottom-right corner)
  _card(
    right: 120, bottom: 30,
    title: 'Hull Integrity',
    body:  'Ice armour segments.\nPersists in both views.',
    alignRight: true,
  ),

  // WarningTextZone
  _centredCard(
    top: 12,
    title: 'Warning Zone',
    body:  'STALL · PULL UP · LOW MANA · HULL CRITICAL',
  ),
];

// ── Card builders ─────────────────────────────────────────────────────────────

Widget _card({
  double? left,
  double? right,
  double? top,
  double? bottom,
  required String title,
  required String body,
  bool alignRight = false,
}) {
  return Positioned(
    left:   left,
    right:  right,
    top:    top,
    bottom: bottom,
    child: _TutorialCard(title: title, body: body, alignRight: alignRight),
  );
}

Widget _centredCard({
  double? top,
  double? bottom,
  required String title,
  required String body,
}) {
  return Positioned(
    left: 0, right: 0,
    top: top, bottom: bottom,
    child: Center(
      child: _TutorialCard(title: title, body: body),
    ),
  );
}

// ── Tutorial card widget ──────────────────────────────────────────────────────

class _TutorialCard extends StatelessWidget {
  final String title;
  final String body;
  final bool   alignRight;

  const _TutorialCard({
    required this.title,
    required this.body,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kAbyssNavy.withValues(alpha: 0.92),
        border: Border.all(color: kManaFill.withValues(alpha: 0.7), width: 1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color:      kManaFill,
              fontSize:   9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color:    kFrostWhite.withValues(alpha: 0.80),
              fontSize: 9,
              height:   1.4,
            ),
          ),
        ],
      ),
    );
  }
}
