import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../systems/maneuver_system.dart';
import 'aerobatic_painter.dart';
import 'ff_maneuver_painter.dart';
import 'game_state.dart';

const _kBg  = Color(0xFF040818);
const _kFg  = Color(0xFFCC88FF);
const _kDim = Color(0xFF441166);
const _kAct = Color(0xFFFFAA00);
const _kDot = Color(0xFF00FF88);
const _kFF  = Color(0xFFFF6600);  // firefighting accent
const double _kS = 2.0;

// ── ManeuverPage widget ───────────────────────────────────────────────────────

class ManeuverPage extends StatefulWidget {
  final GameState            state;
  final void Function(int)?  onScroll;
  final void Function()?     onExecute;
  final void Function()?     onStop;

  const ManeuverPage({
    super.key,
    required this.state,
    this.onScroll,
    this.onExecute,
    this.onStop,
  });

  @override
  State<ManeuverPage> createState() => _ManeuverPageState();
}

class _ManeuverPageState extends State<ManeuverPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s       = widget.state;
    final catalog = ManeuverSystem.catalog;
    final selIdx  = s.selectedManeuverIdx.clamp(0, catalog.length - 1);
    final def     = catalog[selIdx];
    final actIdx  = s.activeManeuverIdx;
    final isActive = actIdx != null && actIdx == selIdx;
    final isFF     = def.category == ManeuverCategory.firefighting;
    final animT    = isActive
        ? (s.maneuverTimer / def.totalDur).clamp(0.0, 1.0)
        : _anim.value;

    final painter = isFF
        ? FfPainter(def.type, animT, s.maneuverDropWindowActive)
        : AerobaticPainter(def.type, animT, isActive);

    return Row(children: [
      // ── Left: scrollable maneuver list ────────────────────────────────────
      Listener(
        onPointerSignal: (ev) {
          if (ev is PointerScrollEvent) widget.onScroll?.call(ev.scrollDelta.dy > 0 ? 1 : -1);
        },
        child: Container(
          width: 168 * _kS,
          color: _kBg,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: catalog.length,
            itemBuilder: (_, i) {
              final sel = i == selIdx;
              final act = actIdx == i;
              final ff  = catalog[i].category == ManeuverCategory.firefighting;
              final col = act ? _kAct : (sel ? _kFg : _kDim);
              final pfx = act ? '▶' : (sel ? '›' : ' ');
              return GestureDetector(
                onTap: () { final d = i - selIdx; if (d != 0) widget.onScroll?.call(d); },
                child: Container(
                  height: 22 * _kS,
                  padding: EdgeInsets.symmetric(horizontal: 6 * _kS),
                  color: sel ? _kDim.withValues(alpha: 0.55) : Colors.transparent,
                  child: Row(children: [
                    Text(pfx, style: TextStyle(color: col, fontSize: 7 * _kS, fontWeight: FontWeight.bold)),
                    SizedBox(width: 2 * _kS),
                    Text(ff ? '🔥' : '◈',
                        style: TextStyle(color: ff ? _kFF : const Color(0xFF00CCFF), fontSize: 6 * _kS)),
                    SizedBox(width: 3 * _kS),
                    Expanded(child: Text(catalog[i].name,
                        style: TextStyle(color: col, fontSize: 6.5 * _kS,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),

      // ── Right: description + animation + controls ─────────────────────────
      Expanded(
        child: Column(children: [
          // Description + ARM warning
          Container(
            height: 30 * _kS,
            padding: EdgeInsets.symmetric(horizontal: 6 * _kS, vertical: 2 * _kS),
            color: _kDim.withValues(alpha: 0.30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.desc, style: TextStyle(color: _kFg, fontSize: 5.5 * _kS), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (isFF && !s.suppressionArmed)
                Text('⚠ ARM suppression before executing',
                    style: TextStyle(color: _kFF, fontSize: 5 * _kS)),
            ]),
          ),

          // Tutorial animation
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(painter: painter, child: const SizedBox.expand()),
            ),
          ),

          // Execute / status / stop row
          Container(
            height: 20 * _kS,
            color: _kDim.withValues(alpha: 0.20),
            padding: EdgeInsets.symmetric(horizontal: 6 * _kS),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn('EXECUTE', isActive ? null : widget.onExecute, isFF ? _kFF : _kDot),
              s.maneuverDropWindowActive
                  ? Text('◆ DROP NOW ◆',
                      style: TextStyle(color: const Color(0xFFFF4400), fontSize: 6 * _kS, fontWeight: FontWeight.bold))
                  : Text('${selIdx + 1}/${catalog.length}',
                      style: TextStyle(color: _kFg, fontSize: 6 * _kS)),
              _btn('STOP', actIdx != null ? widget.onStop : null, _kAct),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _btn(String label, VoidCallback? onTap, Color col) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * _kS, vertical: 2 * _kS),
        decoration: BoxDecoration(
          color: active ? col.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: active ? col : _kDim, width: active ? 1.5 : 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label, style: TextStyle(
          color: active ? col : _kDim, fontSize: 6 * _kS,
          fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}
