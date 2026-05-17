import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Bezel geometry ────────────────────────────────────────────────────────────

/// Padding added on every side of the instrument face.
/// Total dimension increase per element: 2 × kBezelWidth.
const kBezelWidth = 4.0;

// ── Palette ───────────────────────────────────────────────────────────────────
//
// Real aircraft instrument panels are finished in charcoal / anthracite
// (Federal Standard 595 color 36118 "Instrument Black").  The bezel has a
// slight bevel: a lighting model with the source at the top-left (standard
// for aviation UI conventions) means the top and left edges are a shade
// lighter than the bottom-right, creating the 3-D raised-frame illusion.

const _kHighlight = Color(0xFF2C2E3C); // top-left: machined chamfer
const _kMid       = Color(0xFF1A1C26); // body of the frame
const _kShadow    = Color(0xFF09090E); // bottom-right: shadow side
const _kEdge      = Color(0xFF3C3E52); // outer machined rim line
const _kRecess    = Color(0xFF05060A); // inner mounting-ring line

// ── Widget ────────────────────────────────────────────────────────────────────

/// Wraps any cockpit instrument in a physically accurate bezel.
///
/// The bezel simulates a machined aluminium / anodised steel frame:
/// • A bevel gradient (top-left lighter → bottom-right darker) creates the
///   raised 3-D effect of a machined chamfer.
/// • A drop shadow separates the bezel from the panel behind it.
/// • An outer rim line represents the machined outer edge.
/// • An inner recess line represents the gasket / mounting ring.
///
/// [isCircular] controls corner radius: round instruments (AoA, Fire Prox)
/// get a larger radius so the bezel visually echoes the circular face inside.
///
/// The bezel does NOT change the *layout identity* of the child — the child
/// is always rectangular.  `isCircular` is purely a style hint.
class CockpitBezel extends StatelessWidget {
  final Widget child;
  final bool   isCircular;

  const CockpitBezel({super.key, required this.child, this.isCircular = false});

  @override
  Widget build(BuildContext context) {
    if (isCircular) return _buildCircular();
    return _buildRectangular();
  }

  // ── Circular bezel (AoA, Fire Prox) ─────────────────────────────────────────

  Widget _buildCircular() {
    // A SweepGradient simulates a turned-metal ring lit from directly above:
    // top (270° from 3-o'clock = -π/2) is brightest; bottom (90° = π/2) darkest.
    // Flutter SweepGradient: 0 = 3 o'clock, increasing clockwise.
    return Container(
      padding: const EdgeInsets.all(kBezelWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          startAngle: 0,
          endAngle:   math.pi * 2,
          colors: const [
            Color(0xFF252737), // 0° / 360°  (right)       — mid
            Color(0xFF0B0C12), // 90°         (bottom)      — shadow
            Color(0xFF1D1F2E), // 180°        (left)        — mid-dark
            Color(0xFF31334C), // 270°        (top)         — highlight
            Color(0xFF252737), // 360°        (right again) — mid
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        border: Border.all(color: _kEdge, width: 0.75),
        boxShadow: const [
          BoxShadow(color: Color(0xEE000000), blurRadius: 10, offset: Offset(3, 4)),
          BoxShadow(color: Color(0x0CFFFFFF), blurRadius: 1,  offset: Offset(-1, -1)),
        ],
      ),
      // Inner mounting ring clips child to a circle.
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kRecess, width: 1),
        ),
        child: ClipOval(child: child),
      ),
    );
  }

  // ── Rectangular bezel (all other instruments) ─────────────────────────────

  Widget _buildRectangular() {
    const outerR = 4.0;
    const innerR = 0.0; // outerR - kBezelWidth (clamped to 0)

    return Container(
      padding: const EdgeInsets.all(kBezelWidth),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [_kHighlight, _kMid, _kShadow],
          stops:  [0.0,         0.45,  1.0],
        ),
        borderRadius: BorderRadius.circular(outerR),
        border: Border.all(color: _kEdge, width: 0.75),
        boxShadow: const [
          BoxShadow(color: Color(0xEE000000), blurRadius: 10, offset: Offset(3, 4)),
          BoxShadow(color: Color(0x0CFFFFFF), blurRadius: 1,  offset: Offset(-1, -1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerR),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerR),
            border: Border.all(color: _kRecess, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
