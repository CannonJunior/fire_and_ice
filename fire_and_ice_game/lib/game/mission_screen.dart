import 'package:flutter/material.dart';
import 'game_state.dart';
import 'mission_state.dart';

// ── Palette (matches hangar_screen) ────────────────────────────────────────
const _bg     = Color(0xEE000C1A);
const _panel  = Color(0xFF001428);
const _border = Color(0xFF003A60);
const _lit    = Color(0xFF00AAFF);
const _dim    = Color(0xFF334455);
const _text   = Color(0xFFCCDDEE);
const _gold   = Color(0xFFFFCC44);
const _green  = Color(0xFF00FF99);
const _greenD = Color(0xFF001C0C);
const _red    = Color(0xFFFF4422);
const _amber  = Color(0xFFFFAA22);

Widget buildMissionScreen(
  GameState state, {
  required VoidCallback onClose,
  required void Function(String) onDispatch,
  required VoidCallback onRTB,
  required VoidCallback onCancelMission,
}) => _MissionScreen(
  state: state, onClose: onClose,
  onDispatch: onDispatch, onRTB: onRTB,
  onCancelMission: onCancelMission,
);

class _MissionScreen extends StatefulWidget {
  final GameState state;
  final VoidCallback onClose;
  final void Function(String) onDispatch;
  final VoidCallback onRTB;
  final VoidCallback onCancelMission;

  const _MissionScreen({
    required this.state, required this.onClose,
    required this.onDispatch, required this.onRTB,
    required this.onCancelMission,
  });

  @override
  State<_MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<_MissionScreen> {
  GameState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          _threatBar(),
          const SizedBox(height: 12),
          Expanded(child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _missionList()),
              const SizedBox(width: 14),
              SizedBox(width: 260, child: _statusPanel()),
            ],
          )),
          _footer(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() => Row(children: [
    const Text('TACTICAL OPERATIONS CENTER', style: TextStyle(
        color: _lit, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
    const SizedBox(width: 12),
    const Text('SQUADRON COMMAND', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
    const Spacer(),
    GestureDetector(
      onTap: widget.onClose,
      child: const Text('✕ CLOSE', style: TextStyle(color: _dim, fontSize: 10, letterSpacing: 1)),
    ),
  ]);

  // ── Threat bar ─────────────────────────────────────────────────────────────

  Widget _threatBar() {
    final level = s.airbaseThreatLevel;
    final col   = level > 0.7 ? _red : level > 0.35 ? _amber : _green;
    final label = level > 0.7 ? 'CRITICAL' : level > 0.35 ? 'ELEVATED' : 'NOMINAL';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('BASE THREAT  ', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
        Text(label, style: TextStyle(color: col, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
        const Text('   │   NEAREST FIRE  ', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
        Text(
          s.closestFireToBase.isInfinite ? '--' : '${s.closestFireToBase.toStringAsFixed(0)} u',
          style: TextStyle(color: col, fontSize: 9, letterSpacing: 1),
        ),
      ]),
      const SizedBox(height: 4),
      Stack(children: [
        Container(height: 6, color: _panel),
        FractionallySizedBox(
          widthFactor: level.clamp(0.0, 1.0),
          child: Container(height: 6, color: col),
        ),
      ]),
    ]);
  }

  // ── Mission list ───────────────────────────────────────────────────────────

  Widget _missionList() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AVAILABLE MISSIONS',
            style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
        const SizedBox(height: 8),
        ...s.missions.available.map(_missionCard),
      ],
    ),
  );

  Widget _missionCard(MissionDef m) {
    final isActive  = s.missions.activeId == m.id;
    final isDone    = isActive && s.missions.isComplete(s.fireExtinguished);
    final active    = m.targetZones.where((i) => !s.fireExtinguished[i]).length;
    final borderCol = isActive ? (isDone ? _green : _amber) : _border;
    final titleCol  = isActive ? (isDone ? _green : _amber) : _text;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? _greenD : _panel,
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(m.type == 'defend' ? '⚠ ' : '▶ ',
              style: TextStyle(color: borderCol, fontSize: 11)),
          Expanded(child: Text(m.name, style: TextStyle(
              color: titleCol, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
          Text('+${m.rpReward} RP', style: const TextStyle(color: _gold, fontSize: 9)),
        ]),
        const SizedBox(height: 4),
        Text(m.briefing, style: const TextStyle(color: _dim, fontSize: 8, height: 1.4)),
        const SizedBox(height: 6),
        Row(children: [
          Text('ZONES: ${m.targetZones.length}   ACTIVE: $active',
              style: TextStyle(color: isActive ? _amber : _dim, fontSize: 8, letterSpacing: 0.5)),
          const Spacer(),
          if (isDone)
            const Text('◆ COMPLETE', style: TextStyle(color: _green, fontSize: 9, letterSpacing: 1))
          else if (isActive)
            _btn('CANCEL', _dim, 80, () { widget.onCancelMission(); setState(() {}); })
          else
            _btn('DISPATCH', _lit, 80, () { widget.onDispatch(m.id); setState(() {}); }),
        ]),
      ]),
    );
  }

  // ── Status panel ───────────────────────────────────────────────────────────

  Widget _statusPanel() {
    final activeMission = s.missions.active;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FIRE STATUS', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 6),
          ...List.generate(GameState.firePositions.length, (i) {
            final (fx, fz) = GameState.firePositions[i];
            final out      = s.fireExtinguished[i];
            final targeted = activeMission?.targetZones.contains(i) ?? false;
            final col      = out ? _dim : (targeted ? _red : _amber);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text(out ? '○' : '●', style: TextStyle(color: col, fontSize: 10)),
                const SizedBox(width: 6),
                Text(
                  'ZONE $i   ${fx.toStringAsFixed(0)}, ${fz.toStringAsFixed(0)}',
                  style: TextStyle(color: col, fontSize: 8),
                ),
                if (targeted && !out) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    color: const Color(0xFF330000),
                    child: const Text('TGT', style: TextStyle(color: _red, fontSize: 7)),
                  ),
                ],
              ]),
            );
          }),
          const SizedBox(height: 16),
          const Text('NAVIGATION', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: s.rtbActive ? null : () { widget.onRTB(); setState(() {}); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _panel,
                border: Border.all(color: s.rtbActive ? _amber : _lit),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                s.rtbActive ? '◀ RTB ENGAGED' : '◀ RETURN TO BASE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: s.rtbActive ? _amber : _lit,
                  fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('HOME BASE  0.0, +72', style: TextStyle(color: _dim, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _btn(String label, Color col, double w, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF001020),
          border: Border.all(color: col),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: col, fontSize: 8, letterSpacing: 1.2)),
      ),
    );

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _footer() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      const Text('ACTIVE FIRES: ', style: TextStyle(color: _dim, fontSize: 9)),
      Text('${s.activeFires}',
          style: const TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(width: 20),
      const Text('AIRBASE: ', style: TextStyle(color: _dim, fontSize: 9)),
      const Text('SECTOR 7-G', style: TextStyle(color: _text, fontSize: 9)),
      const Spacer(),
      if (s.missions.activeId != null)
        Text('MISSION: ${s.missions.active?.name ?? '--'}',
            style: const TextStyle(color: _amber, fontSize: 9, letterSpacing: 0.5)),
    ]),
  );
}
