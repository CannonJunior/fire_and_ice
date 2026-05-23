import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;

/// A deployable mission sortie dispatched from the TOC.
class MissionDef {
  final String id;
  final String name;
  final String briefing;
  final List<int> targetZones; // indices into GameState.firePositions
  final String type;           // 'suppress' | 'defend'
  final int rpReward;

  const MissionDef({
    required this.id,
    required this.name,
    required this.briefing,
    required this.targetZones,
    required this.type,
    required this.rpReward,
  });

  factory MissionDef.fromJson(Map<String, dynamic> j) => MissionDef(
    id:          j['id']       as String,
    name:        j['name']     as String,
    briefing:    j['briefing'] as String,
    targetZones: (j['targetZones'] as List<dynamic>).map((e) => e as int).toList(),
    type:        j['type']     as String,
    rpReward:    (j['rpReward'] as num).toInt(),
  );
}

enum MissionStatus { available, active, complete }

/// Mission state embedded in GameState. Owns the available-mission list, the
/// active mission pointer, and the loading logic from game_config.json.
class MissionState {
  List<MissionDef> available = [];
  String?          activeId;
  MissionStatus    status = MissionStatus.available;

  Future<void> loadFromConfig() async {
    try {
      final raw  = await rootBundle.loadString('config/game_config.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['missions'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        available = list
            .map((e) => MissionDef.fromJson(e as Map<String, dynamic>))
            .toList();
        return;
      }
    } catch (e) {
      debugPrint('[MissionState] game_config.json load failed: $e');
    }
    _useDefaults();
  }

  void _useDefaults() {
    available = const [
      MissionDef(
        id: 'scramble_alpha', name: 'SCRAMBLE ALPHA',
        briefing: 'Zone 0 is advancing on the apron. Suppress before it reaches the hangar.',
        targetZones: [0], type: 'suppress', rpReward: 200,
      ),
      MissionDef(
        id: 'scramble_bravo', name: 'SCRAMBLE BRAVO',
        briefing: 'Zone 1 southeast — critical suppression sortie. Base perimeter at risk.',
        targetZones: [1], type: 'suppress', rpReward: 180,
      ),
      MissionDef(
        id: 'defend_base', name: 'DEFEND THE BASE',
        briefing: 'Multiple zones encircling HQ. Suppress ALL active fires — last chance.',
        targetZones: [0, 1, 2, 3, 4], type: 'defend', rpReward: 500,
      ),
    ];
  }

  MissionDef? get active =>
      activeId == null ? null
      : available.firstWhere((m) => m.id == activeId, orElse: () => available.first);

  void dispatch(String id) {
    activeId = id;
    status   = MissionStatus.active;
  }

  void cancel() {
    activeId = null;
    status   = MissionStatus.available;
  }

  bool isComplete(List<bool> fireExtinguished) {
    final m = active;
    if (m == null) return false;
    return m.targetZones.every((i) => i < fireExtinguished.length && fireExtinguished[i]);
  }
}
