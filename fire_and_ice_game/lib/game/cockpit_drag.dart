import 'package:flutter/material.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kBg      = Color(0xFF06100A);
const _kAccent  = Color(0xFF3AB7FF);
const _kDim     = Color(0xFF334455);
const _kDrag    = Color(0xFF00AAFF);
const _kFixed   = Color(0xFF445566);
const _kHeaderH = 32.0;

// ── CockpitDragGroup ──────────────────────────────────────────────────────────

/// Wraps a cockpit instrument with optional drag repositioning and an info bar.
///
/// ## Why Overlay?
/// `Transform.translate` keeps the element in its original Row/Column layout
/// slot.  Flutter's `RenderBox.hitTest` guards every ancestor with a size-
/// contains check, so once the visual content is translated outside the Row's
/// allocated bounds, the Row's own hit-test guard rejects the pointer and the
/// element silently stops responding.  Moving the draggable content into an
/// [OverlayEntry] lifts it above the Row/Column hierarchy entirely, so hit
/// testing works at any screen position.
///
/// An invisible [Opacity] placeholder stays in the original Row/Column slot to
/// preserve layout dimensions.  Positions are persisted via [onOffsetChanged].
class CockpitDragGroup extends StatefulWidget {
  final String label;
  final Widget child;
  final bool   draggable;
  final bool   showInfo;
  /// Persisted offset loaded from SettingsState for the current aircraft.
  final Offset initialOffset;
  /// Fired on drag-end and on ↺ reset so the caller can save the position.
  final ValueChanged<Offset>? onOffsetChanged;

  const CockpitDragGroup({
    super.key,
    required this.label,
    required this.child,
    this.draggable       = false,
    this.showInfo        = false,
    this.initialOffset   = Offset.zero,
    this.onOffsetChanged,
  });

  @override
  State<CockpitDragGroup> createState() => _CockpitDragGroupState();
}

class _CockpitDragGroupState extends State<CockpitDragGroup> {
  /// Persisted offset (saved on pan-end / reset).
  late Offset _offset;
  /// Live drag delta — drives the overlay via ValueListenableBuilder so
  /// panning never calls markNeedsBuild() or setState() on every event.
  late final ValueNotifier<Offset> _live;
  /// Keeps the overlay child live so parent setState() propagates into it.
  late final ValueNotifier<Widget> _childNotifier;
  final _key  = GlobalKey();
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _offset          = widget.initialOffset;
    _live            = ValueNotifier<Offset>(widget.initialOffset);
    _childNotifier   = ValueNotifier<Widget>(widget.child);
  }

  @override
  void dispose() {
    _entry?.remove();
    _childNotifier.dispose();
    _live.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CockpitDragGroup old) {
    super.didUpdateWidget(old);
    // Propagate new child into the overlay so game-state rebuilds stay live.
    _childNotifier.value = widget.child;
    if (old.initialOffset != widget.initialOffset) {
      _offset     = widget.initialOffset;
      _live.value = widget.initialOffset;
      // Restore Defaults → offset is now zero. If nothing else needs the
      // overlay, remove it so the placeholder becomes visible again.
      if (_entry != null && !widget.draggable && !widget.showInfo &&
          _offset == Offset.zero) _unmount();
    }
    if (old.draggable != widget.draggable || old.showInfo != widget.showInfo) {
      if (widget.draggable) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _mount());
      } else {
        _unmount();
      }
    }
  }

  // ── Overlay lifecycle ─────────────────────────────────────────────────────

  void _mount() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;

    final base = box.localToGlobal(Offset.zero);
    final sz   = box.size;

    _live.value = _offset;
    _entry?.remove();

    // The overlay is used exclusively for draggable mode so the GestureDetector
    // can receive pointer events at any screen position without being clipped
    // by the cockpit Row's hit-test bounds.  Non-draggable rendering stays in
    // the normal widget tree (see build()) so game-state updates are live.
    final body = Material(
      color: Colors.transparent,
      child: GestureDetector(
        onPanUpdate: (d) => _live.value = _live.value + d.delta,
        onPanEnd: (_) { _offset = _live.value; widget.onOffsetChanged?.call(_offset); },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header rebuilds on every drag tick via ValueListenableBuilder.
            ValueListenableBuilder<Offset>(
              valueListenable: _live,
              builder: (_, off, __) => SizedBox(width: sz.width,
                child: _InfoHeader(label: widget.label, offset: off,
                  draggable: true, showInfo: widget.showInfo,
                  onReset: off != Offset.zero ? _reset : null)),
            ),
            ValueListenableBuilder<Widget>(
              valueListenable: _childNotifier,
              builder: (_, child, __) =>
                  SizedBox(width: sz.width, height: sz.height, child: child),
            ),
          ]),
        ),
      ),
    );

    // Outer ValueListenableBuilder repositions the Positioned without
    // rebuilding the GestureDetector or instrument body on every drag tick.
    _entry = OverlayEntry(builder: (_) => ValueListenableBuilder<Offset>(
      valueListenable: _live,
      builder: (_, off, child) => Positioned(
        left: base.dx + off.dx,
        top:  base.dy + off.dy - _kHeaderH,
        child: child!,
      ),
      child: body,
    ));

    Overlay.of(context).insert(_entry!);
    if (mounted) setState(() {});
  }

  void _unmount() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _reset() {
    _offset     = Offset.zero;
    _live.value = Offset.zero;   // repositions via ValueListenableBuilder
    widget.onOffsetChanged?.call(Offset.zero);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Non-draggable: always render inline so every game-state rebuild
    // (throttle, gear, etc.) is immediately reflected.  The saved offset is
    // applied via Transform.translate.  Hit-testing works for any displacement
    // that stays within the cockpit panel bounds — the usual case for cockpit
    // layout tweaks.
    if (!widget.draggable) {
      Widget child = widget.showInfo
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              _InfoHeader(label: widget.label, offset: _offset,
                  draggable: false, showInfo: true),
              widget.child,
            ])
          : widget.child;
      return _offset == Offset.zero
          ? child
          : Transform.translate(offset: _offset, child: child);
    }

    // Draggable → overlay so the GestureDetector works at any screen position.
    if (_entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _entry == null) _mount();
      });
    }
    // Visible for one frame before the overlay mounts, invisible thereafter.
    return Opacity(key: _key, opacity: _entry == null ? 1.0 : 0.0,
        child: widget.child);
  }
}

// ── Info / drag-indicator header bar ─────────────────────────────────────────

class _InfoHeader extends StatelessWidget {
  final String   label;
  final Offset   offset;
  final bool     draggable;
  final bool     showInfo;
  final VoidCallback? onReset;

  const _InfoHeader({
    required this.label, required this.offset,
    required this.draggable, required this.showInfo,
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
  Widget build(BuildContext context) => Container(
    height: _kHeaderH, color: _kBg,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (draggable)
          const Padding(padding: EdgeInsets.only(right: 4),
            child: Text('⠿', style: TextStyle(
                color: _kDim, fontSize: 18, height: 1.0))),
        Text(label.toUpperCase(), style: const TextStyle(
            color: _kAccent, fontSize: 13,
            fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        if (showInfo) ...[
          const SizedBox(width: 6),
          Text(_posText, style: const TextStyle(
              color: _kDim, fontSize: 13, fontFamily: 'monospace')),
          const SizedBox(width: 5),
          _ModeBadge(draggable: draggable),
        ],
        if (onReset != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onReset,
            child: const Text('↺', style: TextStyle(
                color: _kAccent, fontSize: 20, height: 1.0)),
          ),
        ],
      ],
    ),
  );
}

// ── Mode badge ────────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final bool draggable;
  const _ModeBadge({required this.draggable});

  @override
  Widget build(BuildContext context) {
    final color = draggable ? _kDrag : _kFixed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:  color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(draggable ? 'DRAG' : 'FIXED', style: TextStyle(
          color: color, fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}
