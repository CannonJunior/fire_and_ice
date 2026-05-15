import 'package:flutter/material.dart';
import 'game_state.dart';

/// Builds a twin-engine throttle quadrant widget.
///
/// The quadrant shows two ganged throttle levers (one per simulated engine)
/// that the pilot can drag vertically to set engine power.
///
/// Detent / gate behaviour (matching real turbofan quadrants):
///   • Levers move freely from TOGA (100%) down to IDLE (~5%).
///   • A physical gate (amber bar) blocks further travel at IDLE.
///   • To pass through the gate into ENGINE CUTOFF (0%), the pilot must first
///     "lift" the gate by dragging the grip horizontally, then slide down.
///   • Dragging back above IDLE automatically re-locks the gate.
Widget buildThrottleQuadrant(
  GameState state, {
  required void Function(double) onThrottle,
}) => _ThrottleQuadrant(state: state, onThrottle: onThrottle);

// ── Constants ─────────────────────────────────────────────────────────────────

const _kIdleThresh = 0.06; // below this value we are in the gate zone
const _kHousing    = Color(0xFF16181E);
const _kChrome     = Color(0xFF3A3C48);
const _kTrack      = Color(0xFF0C0E12);
const _kGate       = Color(0xFFFFAA00); // idle gate line
const _kGateLifted = Color(0xFFFF4400); // gate lifted = danger red
const _kLever      = Color(0xFF5A5C6A);
const _kGrip       = Color(0xFF7A7C8A);
const _kCutZone    = Color(0x33FF0000);
const _kDim        = Color(0xFF334455);
const _kText       = Color(0xFF889AAA);

// ── StatefulWidget ────────────────────────────────────────────────────────────

class _ThrottleQuadrant extends StatefulWidget {
  final GameState state;
  final void Function(double) onThrottle;
  const _ThrottleQuadrant({required this.state, required this.onThrottle});

  @override
  State<_ThrottleQuadrant> createState() => _TQState();
}

class _TQState extends State<_ThrottleQuadrant> {
  bool   _gateLifted = false;
  double _dragStart  = 0.0; // local Y at drag start
  double _tStart     = 0.0; // throttle at drag start

  // Track height in local pixels — set from layout
  static const double _trackH = 144.0;

  double get _throttle => widget.state.throttle;

  void _onPanStart(DragStartDetails d) {
    _dragStart = d.localPosition.dy;
    _tStart    = _throttle;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Horizontal delta lifts the gate (simulates lateral gate shift)
    if (!_gateLifted && _throttle <= _kIdleThresh + 0.04) {
      if (d.delta.dx.abs() > d.delta.dy.abs() * 1.5 && d.delta.dx.abs() > 1.5) {
        setState(() => _gateLifted = true);
      }
    }

    final dy    = d.localPosition.dy - _dragStart;
    var   newT  = (_tStart - dy / _trackH).clamp(0.0, 1.0);
    if (!_gateLifted) newT = newT.clamp(_kIdleThresh, 1.0);

    setState(() {});
    widget.onThrottle(newT);
  }

  void _onPanEnd(DragEndDetails _) {
    if (_throttle > _kIdleThresh) setState(() => _gateLifted = false);
  }

  @override
  Widget build(BuildContext context) {
    final gateColor = _gateLifted ? _kGateLifted : _kGate;

    return Container(
      width: 176,
      decoration: BoxDecoration(
        color: _kHousing,
        border: Border.all(color: _kChrome, width: 2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1018),
            border: const Border(bottom: BorderSide(color: _kChrome)),
          ),
          child: const Center(child: Text('THROTTLE QUAD',
            style: TextStyle(color: _kText, fontSize: 12, letterSpacing: 1.5,
                fontWeight: FontWeight.bold))),
        ),
        // Gate status indicator
        Container(
          height: 22,
          color: const Color(0xFF0A0C10),
          child: Center(child: Text(
            _gateLifted ? '⚠  GATE LIFTED  ⚠' : 'IDLE GATE LOCKED',
            style: TextStyle(color: gateColor, fontSize: 12, letterSpacing: 0.8))),
        ),
        // Lever area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: GestureDetector(
            onPanStart:  _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd:    _onPanEnd,
            child: SizedBox(
              height: _trackH + 60, // extra 60 for labels
              child: CustomPaint(
                painter: _TQPainter(
                  throttle:   _throttle,
                  gateLifted: _gateLifted,
                  gateColor:  gateColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        // N1 readout strip
        Container(
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0C10),
            border: Border(top: BorderSide(color: _kChrome)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('N1 ', style: const TextStyle(color: _kDim, fontSize: 7)),
              Text('${(widget.state.engineN1 * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFF00CC44), fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const Text('  EGT ', style: TextStyle(color: _kDim, fontSize: 7)),
              Text('${(widget.state.engineEgt * 850 + 200).toStringAsFixed(0)}°',
                  style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _TQPainter extends CustomPainter {
  final double throttle;
  final bool   gateLifted;
  final Color  gateColor;

  const _TQPainter({
    required this.throttle,
    required this.gateLifted,
    required this.gateColor,
  });

  // Track metrics
  static const _trackH   = _TQState._trackH;
  static const _trackTop = 16.0;  // Y where TOGA is
  static const _trackW   = 20.0;
  static const _gripW    = 44.0;
  static const _gripH    = 24.0;
  static const _gateY    = _trackTop + _trackH * (1 - _kIdleThresh);

  double _leverY(double t) => _trackTop + _trackH * (1 - t);

  void _drawLever(Canvas canvas, Offset center, double t) {
    final ly = _leverY(t);
    final lx = center.dx;

    // Shaft
    canvas.drawLine(Offset(lx, _trackTop), Offset(lx, ly),
        Paint()..color = _kLever..strokeWidth = _trackW * 0.6..strokeCap = StrokeCap.butt);

    // Grip (T-bar handle)
    final gripRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(lx, ly - _gripH / 2),
          width: _gripW, height: _gripH),
      const Radius.circular(3),
    );
    canvas.drawRRect(gripRect, Paint()..color = _kGrip);
    canvas.drawRRect(gripRect,
        Paint()..color = const Color(0xFFAAAAAA)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Grip serration lines
    final sp = Paint()..color = const Color(0xFF333344)..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final gx = lx - 14.0 + i * 14.0;
      canvas.drawLine(Offset(gx, ly - _gripH + 6), Offset(gx, ly - 6), sp);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cx1 = 36.0; // left lever X
    final cx2 = size.width - 36.0; // right lever X

    for (final cx in [cx1, cx2]) {
      // Track slot
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - _trackW / 2, _trackTop, cx + _trackW / 2, _trackTop + _trackH + 28),
          const Radius.circular(2)),
        Paint()..color = _kTrack,
      );

      // Cutoff zone (below gate) — red tint
      canvas.drawRect(
        Rect.fromLTRB(cx - _trackW / 2, _gateY, cx + _trackW / 2, _trackTop + _trackH + 28),
        Paint()..color = _kCutZone,
      );
    }

    // Scale markings (right side of right track)
    final scaleX = cx2 + _trackW / 2 + 6;
    final markStyle = const TextStyle(color: _kDim, fontSize: 6);
    void mark(String lbl, double t) {
      final y = _leverY(t) - 3;
      canvas.drawLine(Offset(scaleX, y + 3), Offset(scaleX + 8, y + 3),
          Paint()..color = _kDim..strokeWidth = 0.8);
      final tp = TextPainter(text: TextSpan(text: lbl, style: markStyle),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(scaleX + 10, y - 1));
    }
    mark('MCT',  0.95);
    mark('CLB',  0.75);
    mark('CRZ',  0.50);
    mark('IDLE', _kIdleThresh);
    // CUT label below gate
    final tp = TextPainter(
        text: TextSpan(text: 'CUT', style: const TextStyle(color: Color(0xFFAA3322), fontSize: 6)),
        textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(scaleX + 10, _gateY + 8));

    // Gate line — across both tracks
    final gp = Paint()..color = gateColor..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx1 - _trackW / 2 - 4, _gateY),
        Offset(cx2 + _trackW / 2 + 4, _gateY), gp);
    // Gate "latch" markers
    for (final cx in [cx1, cx2]) {
      final latchR = const Radius.circular(2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, _gateY), width: _trackW + 8, height: 8), latchR),
        Paint()..color = gateLifted ? _kGateLifted : _kGate,
      );
    }

    // Levers (drawn after gate so they appear on top)
    _drawLever(canvas, Offset(cx1, 0), throttle);
    _drawLever(canvas, Offset(cx2, 0), throttle);

    // "SHIFT TO UNLOCK" hint when near gate but not lifted
    if (!gateLifted && throttle < _kIdleThresh + 0.10) {
      final hint = TextPainter(
          text: const TextSpan(text: '← SHIFT →',
              style: TextStyle(color: _kGate, fontSize: 11)),
          textDirection: TextDirection.ltr)..layout();
      hint.paint(canvas,
          Offset((size.width - hint.width) / 2, _gateY + 12));
    }

    // Left label column
    final lStyle = const TextStyle(color: _kDim, fontSize: 6);
    final lx = cx1 - _trackW / 2 - 3;
    void lmark(String lbl, double t) {
      final tp2 = TextPainter(text: TextSpan(text: lbl, style: lStyle),
          textDirection: TextDirection.ltr)..layout();
      tp2.paint(canvas, Offset(lx - tp2.width, _leverY(t) - tp2.height / 2));
    }
    lmark('▲', 1.0);
    lmark('▼', 0.0);
  }

  @override
  bool shouldRepaint(_TQPainter o) =>
      o.throttle != throttle || o.gateLifted != gateLifted;
}
