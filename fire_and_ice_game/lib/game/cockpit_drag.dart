import 'package:flutter/material.dart';

// ── Design tokens (matches cockpit palette) ───────────────────────────────────

const _kBg     = Color(0xFF06100A);
const _kAccent = Color(0xFF3AB7FF);
const _kDim    = Color(0xFF334455);
const _kDrag   = Color(0xFF00AAFF);
const _kFixed  = Color(0xFF445566);

// ── CockpitDragGroup ──────────────────────────────────────────────────────────

/// Wraps a cockpit instrument group to support optional drag repositioning
/// and an element-info header bar.
///
/// Both behaviours are driven by [Settings → HUD → Cockpit Draggable] and
/// [Settings → HUD → Element Info].  When neither is active this widget is
/// a transparent pass-through with zero overhead.
///
/// The drag offset is session-local; it resets on page reload.  Tap ↺ in
/// the info header to snap a group back to its default position.
class CockpitDragGroup extends StatefulWidget {
  /// Short display name shown in the info header (e.g. "Left MFD").
  final String label;
  final Widget child;
  final bool   draggable;
  final bool   showInfo;

  const CockpitDragGroup({
    super.key,
    required this.label,
    required this.child,
    this.draggable = false,
    this.showInfo  = false,
  });

  @override
  State<CockpitDragGroup> createState() => _CockpitDragGroupState();
}

class _CockpitDragGroupState extends State<CockpitDragGroup> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    // Pass-through when both features are disabled.
    if (!widget.draggable && !widget.showInfo) return widget.child;

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DragHeader(
          label:     widget.label,
          offset:    _offset,
          draggable: widget.draggable,
          showInfo:  widget.showInfo,
          onPanUpdate: widget.draggable
              ? (d) => setState(() => _offset += d.delta)
              : null,
          onReset: widget.draggable && _offset != Offset.zero
              ? () => setState(() => _offset = Offset.zero)
              : null,
        ),
        widget.child,
      ],
    );

    return Transform.translate(offset: _offset, transformHitTests: true, child: body);
  }
}

// ── Drag / info header bar ────────────────────────────────────────────────────

class _DragHeader extends StatelessWidget {
  final String   label;
  final Offset   offset;
  final bool     draggable;
  final bool     showInfo;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final VoidCallback? onReset;

  const _DragHeader({
    required this.label,
    required this.offset,
    required this.draggable,
    required this.showInfo,
    this.onPanUpdate,
    this.onReset,
  });

  String get _posText {
    if (offset == Offset.zero) return 'HOME';
    final sx = offset.dx >= 0 ? '+' : '';
    final sy = offset.dy >= 0 ? '+' : '';
    return 'Δx$sx${offset.dx.toStringAsFixed(0)}'
        '  Δy$sy${offset.dy.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: onPanUpdate,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: draggable ? SystemMouseCursors.grab : MouseCursor.defer,
        child: Container(
          height: 16,
          color: _kBg,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag grip dots
              if (draggable)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('⠿', style: TextStyle(
                      color: _kDim, fontSize: 9, height: 1.0)),
                ),

              // Element name
              Text(label.toUpperCase(), style: const TextStyle(
                  color: _kAccent, fontSize: 6.5,
                  fontWeight: FontWeight.bold, letterSpacing: 0.8)),

              if (showInfo) ...[
                // Offset / position from default
                const SizedBox(width: 6),
                Text(_posText, style: const TextStyle(
                    color: _kDim, fontSize: 6.5,
                    fontFamily: 'monospace')),

                // FIXED / DRAG mode badge
                const SizedBox(width: 5),
                _ModeBadge(draggable: draggable),
              ],

              // Reset button — only when dragged away from home
              if (onReset != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onReset,
                  child: const Text('↺', style: TextStyle(
                      color: _kAccent, fontSize: 10, height: 1.0)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode badge (FIXED / DRAG) ─────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final bool draggable;
  const _ModeBadge({required this.draggable});

  @override
  Widget build(BuildContext context) {
    final color = draggable ? _kDrag : _kFixed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color:  color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        draggable ? 'DRAG' : 'FIXED',
        style: TextStyle(
          color:       color,
          fontSize:    5.5,
          fontWeight:  FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
