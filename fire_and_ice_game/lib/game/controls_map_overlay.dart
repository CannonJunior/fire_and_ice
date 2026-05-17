import 'dart:html' as html;
import 'package:flutter/material.dart';

// DO NOT use HtmlElementView here.
//
// HtmlElementView forces Flutter web into platform-view compositing mode,
// which splits the render tree into layers.  When the view is removed,
// Flutter's compositing state fails to fully reset, permanently breaking
// hit-testing for most of the cockpit panel.  Instead, the overlay lives
// entirely in the raw DOM (initState → dispose) and never touches Flutter's
// rendering pipeline.  See POINTER_EVENT_BUGS.md for full explanation.

class ControlsMapOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const ControlsMapOverlay({super.key, required this.onClose});

  @override
  State<ControlsMapOverlay> createState() => _ControlsMapOverlayState();
}

class _ControlsMapOverlayState extends State<ControlsMapOverlay> {
  html.Element? _backdrop;

  @override
  void initState() {
    super.initState();
    _mount();
  }

  void _mount() {
    final backdrop = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0' ..style.right = '0'
      ..style.bottom = '0' ..style.left = '0'
      ..style.zIndex = '9000'
      ..style.backgroundColor = 'rgba(0,0,0,0.87)'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.cursor = 'pointer';
    backdrop.onClick.listen((_) => widget.onClose());

    // Inner frame — stops propagation so clicking the image doesn't close.
    final frame = html.DivElement()
      ..style.position = 'relative'
      ..style.cursor = 'default'
      ..style.lineHeight = '0';
    frame.addEventListener('click', (html.Event e) => e.stopPropagation());

    final img = html.ImageElement()
      ..src = 'controls_map.svg'
      ..style.display = 'block'
      ..style.width = '860px'
      ..style.height = '530px'
      ..style.borderRadius = '6px'
      ..style.pointerEvents = 'none';

    final closeBtn = html.DivElement()
      ..style.position = 'absolute'
      ..style.top = '6px' ..style.right = '8px'
      ..style.padding = '3px 8px'
      ..style.background = '#1A1A2A'
      ..style.border = '1px solid #334455'
      ..style.borderRadius = '3px'
      ..style.color = '#6688AA'
      ..style.fontSize = '9px'
      ..style.fontFamily = 'monospace'
      ..style.fontWeight = 'bold'
      ..style.cursor = 'pointer'
      ..text = '✕  CLOSE';
    closeBtn.onClick.listen((_) => widget.onClose());

    frame..append(img)..append(closeBtn);
    backdrop.append(frame);
    html.document.body?.append(backdrop);
    _backdrop = backdrop;
  }

  @override
  void dispose() {
    _backdrop?.remove();
    _backdrop = null;
    super.dispose();
  }

  // Flutter renders nothing — the visual lives entirely in the DOM overlay.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
