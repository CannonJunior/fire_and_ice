import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../game/aircraft_config.dart';
import '../models/aircraft_upgrade.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
const _bg     = Color(0xEE000C1A);
const _panel  = Color(0xFF001428);
const _border = Color(0xFF003A60);
const _lit    = Color(0xFF00AAFF);
const _dim    = Color(0xFF334455);
const _text   = Color(0xFFCCDDEE);
const _gold   = Color(0xFFFFCC44);
const _green  = Color(0xFF00FF99);
const _greenD = Color(0xFF003322);
const _greenB = Color(0xFF00AA77);

Widget buildHangarScreen(
  GameState state, {
  required VoidCallback onClose,
  required void Function(String) onSelectAircraft,
  required void Function(String, String) onEquipUpgrade,
  required void Function(String, String) onUnequipUpgrade,
}) => _HangarScreen(
  state: state, onClose: onClose,
  onSelectAircraft: onSelectAircraft,
  onEquipUpgrade: onEquipUpgrade,
  onUnequipUpgrade: onUnequipUpgrade,
);

class _HangarScreen extends StatefulWidget {
  final GameState state;
  final VoidCallback onClose;
  final void Function(String) onSelectAircraft;
  final void Function(String, String) onEquipUpgrade;
  final void Function(String, String) onUnequipUpgrade;

  const _HangarScreen({
    required this.state, required this.onClose,
    required this.onSelectAircraft, required this.onEquipUpgrade,
    required this.onUnequipUpgrade,
  });

  @override
  State<_HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<_HangarScreen> {
  int _upgradeTab = 0;
  late String _pendingId; // highlighted in the list — not yet committed

  @override
  void initState() {
    super.initState();
    _pendingId = widget.state.aircraftId;
  }

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
          const SizedBox(height: 12),
          Expanded(child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 270, child: _aircraftList()),
              const SizedBox(width: 14),
              Expanded(child: _upgradePanel()),
            ],
          )),
          _footer(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() => Row(children: [
    const Text('HANGAR', style: TextStyle(
        color: _lit, fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.bold)),
    const SizedBox(width: 16),
    Text('${s.currentAircraft.icon}  ${s.currentAircraft.displayName}  ACTIVE',
        style: const TextStyle(color: _text, fontSize: 10, letterSpacing: 1)),
    const Spacer(),
    GestureDetector(
      onTap: widget.onClose,
      child: const Text('✕ CLOSE', style: TextStyle(color: _dim, fontSize: 10, letterSpacing: 1)),
    ),
  ]);

  Widget _footer() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      const Text('RESEARCH POINTS: ', style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
      Text('${s.totalResearchPoints} RP', style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(width: 16),
      const Text('Earn RP by flying — 2 RP/sec airborne · +50 RP per landing',
          style: TextStyle(color: _dim, fontSize: 8)),
    ]),
  );

  // ── Aircraft list ──────────────────────────────────────────────────────────

  Widget _aircraftList() {
    final pending     = s.aircraftConfigs.firstWhere((a) => a.id == _pendingId,
        orElse: () => s.currentAircraft);
    final isNewSelect = _pendingId != s.aircraftId && s.isAircraftUnlocked(_pendingId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SELECT / CLOSE button
        GestureDetector(
          onTap: () {
            if (isNewSelect) widget.onSelectAircraft(_pendingId);
            else widget.onClose();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isNewSelect ? const Color(0xFF002040) : _panel,
              border: Border.all(color: isNewSelect ? _lit : _dim),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isNewSelect
                  ? '◆  SELECT  ${pending.icon} ${pending.displayName}'
                  : '✕  CLOSE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isNewSelect ? _lit : _dim,
                  fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('SELECT AIRCRAFT',
              style: TextStyle(color: _dim, fontSize: 9, letterSpacing: 1)),
        ),
        ...s.aircraftConfigs.map(_aircraftCard),
      ],
    );
  }

  Widget _aircraftCard(AircraftConfig ac) {
    final isPending = _pendingId == ac.id;
    final isActive  = s.aircraftId == ac.id;
    final locked    = !s.isAircraftUnlocked(ac.id);
    return GestureDetector(
      onTap: locked ? null : () => setState(() => _pendingId = ac.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFF002040) : _panel,
          border: Border.all(color: isPending ? _lit : (locked ? _dim : _border)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(locked ? '🔒' : ac.icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Expanded(child: Text(ac.displayName, style: TextStyle(
                color: locked ? _dim : _text, fontSize: 11,
                fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            if (isPending && !isActive)
              const Text('SELECTED', style: TextStyle(color: _lit, fontSize: 8, letterSpacing: 1)),
            if (isActive)
              const Text('◆ ACTIVE', style: TextStyle(color: _green, fontSize: 8, letterSpacing: 1)),
            if (locked)
              Text('${ac.unlockRp} RP', style: const TextStyle(color: _gold, fontSize: 9)),
          ]),
          const SizedBox(height: 5),
          if (!locked) ...[
            _statBar('SPD', ac.baseStats.speed),
            _statBar('MNV', ac.baseStats.maneuverability),
            _statBar('PLD', ac.baseStats.payload),
            _statBar('DUR', ac.baseStats.durability),
            _statBar('CLB', ac.baseStats.climbRate),
          ],
          if (locked) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Unlock at ${ac.unlockRp} RP',
                style: const TextStyle(color: _dim, fontSize: 8)),
          ),
        ]),
      ),
    );
  }

  Widget _statBar(String label, double value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      SizedBox(width: 22, child: Text(label,
          style: const TextStyle(color: _dim, fontSize: 8, letterSpacing: 0.5))),
      Expanded(child: Stack(children: [
        Container(height: 4, color: _border),
        FractionallySizedBox(widthFactor: value.clamp(0, 1),
            child: Container(height: 4, color: _lit)),
      ])),
    ]),
  );

  // ── Upgrade panel ──────────────────────────────────────────────────────────

  Widget _upgradePanel() {
    final ac       = s.currentAircraft;
    final equipped = s.equippedFor(ac.id);
    final tabs     = ['AIRFRAME', 'SYSTEMS', 'PAYLOAD'];
    final cats     = [UpgradeCategory.airframe, UpgradeCategory.systems, UpgradeCategory.payload];
    final budgets  = [ac.upgradeSlots.airframe, ac.upgradeSlots.systems, ac.upgradeSlots.payload];
    final used     = _calcUsed(equipped, cats);
    final filtered = allUpgrades.where((u) => u.category == cats[_upgradeTab]).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: List.generate(3, (i) => GestureDetector(
          onTap: () => setState(() => _upgradeTab = i),
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _upgradeTab == i ? const Color(0xFF002040) : _panel,
              border: Border.all(color: _upgradeTab == i ? _lit : _border),
            ),
            child: Text(tabs[i], style: TextStyle(
                color: _upgradeTab == i ? _lit : _dim, fontSize: 9, letterSpacing: 1)),
          ),
        ))),
        const SizedBox(height: 7),
        Row(children: [
          Text('SLOTS  ${used[_upgradeTab]} / ${budgets[_upgradeTab]}',
              style: const TextStyle(color: _text, fontSize: 9, letterSpacing: 0.5)),
          const SizedBox(width: 10),
          Expanded(child: Stack(children: [
            Container(height: 4, color: _border),
            FractionallySizedBox(
              widthFactor: (used[_upgradeTab] / budgets[_upgradeTab]).clamp(0, 1),
              child: Container(height: 4,
                  color: used[_upgradeTab] > budgets[_upgradeTab] ? Colors.red : _lit)),
          ])),
        ]),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(child: Column(
          children: filtered.map((u) =>
              _upgradeRow(u, ac.id, equipped, used, budgets, cats)).toList(),
        ))),
      ],
    );
  }

  List<int> _calcUsed(Set<String> equipped, List<UpgradeCategory> cats) {
    final used = [0, 0, 0];
    for (final up in allUpgrades) {
      if (equipped.contains(up.id)) {
        final ci = cats.indexOf(up.category);
        if (ci >= 0) used[ci] += up.slotCost;
      }
    }
    return used;
  }

  Widget _upgradeRow(
    AircraftUpgrade up, String acId, Set<String> equipped,
    List<int> used, List<int> budgets, List<UpgradeCategory> cats,
  ) {
    final isEquipped = equipped.contains(up.id);
    final ci         = cats.indexOf(up.category);
    final prereqsMet = up.prerequisites.every(equipped.contains);
    final slotsOk    = isEquipped || (ci < 0 || used[ci] + up.slotCost <= budgets[ci]);
    final rpOk       = isEquipped || s.totalResearchPoints >= up.researchCost;
    final canEquip   = !isEquipped && prereqsMet && slotsOk && rpOk;

    String hint = '';
    if (!isEquipped) {
      if (!prereqsMet) hint = 'Requires: ${up.prerequisites.join(', ')}';
      else if (!slotsOk) hint = 'Not enough slots';
      else if (!rpOk) hint = '${up.researchCost} RP required';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEquipped ? _greenD : _panel,
        border: Border.all(color: isEquipped ? _greenB : _border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(up.displayName,
              style: TextStyle(color: isEquipped ? _green : _text, fontSize: 10)),
          Text(up.description, style: const TextStyle(color: _dim, fontSize: 8)),
          Text(
            '${up.slotCost} slots · ${up.researchCost} RP'
            '${hint.isNotEmpty ? '  ·  $hint' : ''}',
            style: TextStyle(
                color: hint.isNotEmpty ? Colors.orange.shade700 : _dim, fontSize: 8)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isEquipped
            ? () { widget.onUnequipUpgrade(acId, up.id); setState(() {}); }
            : canEquip
              ? () { widget.onEquipUpgrade(acId, up.id); setState(() {}); }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isEquipped ? _greenD : (canEquip ? const Color(0xFF001E38) : _panel),
              border: Border.all(color: isEquipped ? _greenB : (canEquip ? _lit : _dim)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(isEquipped ? 'REMOVE' : 'EQUIP', style: TextStyle(
                color: isEquipped ? _green : (canEquip ? _lit : _dim),
                fontSize: 9, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }
}
