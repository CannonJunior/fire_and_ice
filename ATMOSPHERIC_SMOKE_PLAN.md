# Atmospheric Smoke & Cloud System — Implementation Plan

Two parallel sessions contributed to this document:
- **Session A** (`f51e1b60-…`) — long-range atmospheric plume design
- **Session B** (current) — close-range smoke improvements (already implemented)

---

## Status

| Work Item | Status |
|-----------|--------|
| Close-range smoke: larger billows, opaque core, wind drift | **Done** |
| Close-range smoke: dark-base → cream-top colour gradient | **Done** |
| Close-range smoke: wind-directional overlay | **Done** |
| Close-range smoke config tuning | **Done** |
| Long-range atmospheric plume system | Planned |
| Cloud system | Planned |

---

## Existing Infrastructure (current state after Session B changes)

| System | File | Key Facts |
|--------|------|-----------|
| CPU Particles | `lib/rendering/particle_system.dart` | Max 5000, smoke wind influence 0.88 (separate from fire's 0.60), wind radius 60 units |
| Billboard Renderer | `lib/rendering/particle_renderer.dart` | 8000 max quads, two-pass fire (additive) + smoke (alpha blend), back-to-front sort |
| Fire Shaders | `lib/rendering/fire_shaders.dart` | Smoke: opaque core (d<0.55 flat-topped), 3-octave fBm only at fringe, cauliflower silhouette |
| Fire Emitter | `lib/game/fire_emitter.dart` | 5 static zones, 90 particles/sec/zone, smoke size 10–28 units, lifetime 22–40 s |
| GPU Particles | `lib/rendering/gpu_particle_system.dart` | WebGL2 transform feedback, 20k max, optional |
| Smoke Overlay | `lib/game/smoke_overlay.dart` | 30 billows, max alpha 0.80, wind-directional drift, dark-base/cream-top colour split |
| Game State | `lib/game/game_state.dart` | Fire zones `(-45,28) (22,-60) (55,42) (-72,-18) (8,95)`, radius 20 units |
| Config | `assets/data/fire_config.json` | Smoke peak 80 units, top 200 units; new `atmosphericSmoke` section pending |

**What's still missing for long-range smoke:**
- No macro-billboard / impostor system
- No LOD (level of detail) for distant effects
- No atmospheric perspective shader
- No pyrocumulus cloud cap
- No ambient sky-haze post-process pass

---

## Close-Range Smoke — What Changed (Session B)

### `fire_config.json`

| Parameter | Before | After |
|---|---|---|
| `smokeSizeMin/Max` | 3.5–9.0 | 10–28 world units |
| `smokeLifetimeMin/Max` | 5–9 s | 22–40 s |
| `smokeSizeGrowth` | 0.15 u/s | 0.9 u/s |
| `smokeInitSizeMult` | 2.2× | 5.0× |
| `smokeWindInfluence` | (shared w/ fire) | **0.88** new field |
| `smokeTransitionAge` | 0.42 | 0.30 |
| `windRadius` | 40 | 60 |
| `smokeFadeAltitude` | 80 | 200 |
| `smoke.peakAltitude` | 35 | 80 |
| `smoke.topAltitude` | 70 | 200 |
| `emitRatePerSecond` | 60 | 90 |

### Shader change (`smokeFragShader`)

- Inner core (d < 0.55): flat-topped, fully opaque — smoke interior is solid mass
- Cauliflower fringe: steep smoothstep at 0.72–1.0
- 3-octave fBm noise modulates fringe only; core alpha is never reduced
- Result: each billow reads as a solid rounded mass, not a soft Gaussian blob

### Particle colour (`particle_system.dart`)

Dark soot at birth → medium gray at 40% life → cream/tan at death, matching aerial reference images. Alpha held at 0.92 for first 70% of lifetime, sharp fade in final 30%.

### Smoke overlay (`smoke_overlay.dart`)

30 billows (was 14), max per-billow alpha 0.80 (was 0.45), drift follows `windState.windAngle`, dark soot/ash at lower screen, cream/tan at upper screen, dense curtain at `smokeOpacity > 0.55`.

---

## Long-Range Atmospheric Plume — Design (Session A)

Real forest fire plumes at distance behave like a **geological feature**, not a particle effect.

### Scale

- Base diameter: 1–3 km → 100–300 world units
- Height: 5–15 km → 100–300 world units vertically
- Visible from: 20–100+ units depending on intensity
- Wind tilt: 10–30° lean from vertical, spreading wider at altitude

### Colour Stratification (bottom → top)

| Layer | Height | RGB | Opacity |
|-------|--------|-----|---------|
| 0 | Ground | `(0.15, 0.12, 0.10)` soot | 1.0 |
| 1 | Low | `(0.40, 0.38, 0.35)` dark grey | 0.8 |
| 2 | Mid | `(0.65, 0.63, 0.60)` mid grey | 0.6 |
| 3 | High | `(0.85, 0.83, 0.80)` light grey | 0.3 |
| 4 | Top | `(0.95, 0.95, 0.95)` cream | 0.1 |

*Note: this stratification now aligns with the close-range particle colour gradient implemented in Session B.*

### Movement

- Billowing cycle: 0.1–0.3 Hz (massive — the plume must feel immovable)
- Wind drift: plume base drifts with `apparentWind` at 0.3–0.5× wind speed
- Internal rise velocity decreases from base (fast) to top (near zero)

### Atmospheric Effects

- **Distance fade**: colours shift toward blue-grey beyond ~50 units, lose contrast
- **Sky haze**: amber/orange screen tint `(1.0, 0.8, 0.4, 0.15)` when fire within ~50 units
- **IMC trigger**: when plume opacity at aircraft altitude exceeds 0.85 (already in `GameState`)

---

## Long-Range Architecture — New Files

### Render Order

```
terrain → scene meshes
  → atmospheric plumes     (far, back-to-front alpha blend)   ← NEW
  → close-range particles  (near, additive + alpha blend)     ← existing
  → heat distortion post-process
```

### `lib/rendering/atmospheric_smoke_plume.dart` (~500 lines)

```dart
class SmokeColumnParticle {
  Vector3 position;   // world-space center of this billboard segment
  double width;       // horizontal extent (world units)
  double height;      // vertical extent of this segment
  Vector4 color;      // rgb + base opacity
  double layerIndex;  // 0.0 (base dark) .. 4.0 (top cream)
  double swirlAngle;  // slow rotation for visual variation
}

class AtmosphericSmokePlume {
  int    zoneIndex;
  double sourceX, sourceZ;
  double intensity;        // 0..1, driven by fire state
  double currentHeight;    // grows with fire duration
  List<SmokeColumnParticle> segments; // 50 stacked billboards

  void tick(double intensity, Vector3 wind, double dt) { ... }
}

class AtmosphericSmokeSystem {
  List<AtmosphericSmokePlume> plumes;
  void addPlume(int zoneIdx, double x, double z) { ... }
  void tickPlume(int idx, double intensity, Vector3 wind, double dt) { ... }
  List<SmokeColumnParticle> getAllBillboards() { ... }
}
```

### `lib/rendering/atmospheric_smoke_renderer.dart` (~400 lines)

Mirrors `ParticleRenderer` structure:

- Max 1000 billboards (5 zones × 200 segments with LOD)
- VBO: `worldPos(3), corner(2), color(4), width(1), height(1), layerIndex(1)` = 12 floats/vertex
- Back-to-front sort by camera Z distance before upload
- Single draw call with `SRC_ALPHA / ONE_MINUS_SRC_ALPHA`

### GLSL additions to `lib/rendering/fire_shaders.dart`

```glsl
// ── atmosphericSmokeVertSrc ─────────────────────────────────────────────────
attribute vec3  aWorldPos;
attribute vec2  aCorner;
attribute vec4  aColor;
attribute float aWidth;
attribute float aHeight;
attribute float aLayerIndex;

uniform mat4  uViewProj;
uniform vec3  uCameraRight;
uniform vec3  uCameraUp;
uniform float uTime;

varying vec2  vUV;
varying vec4  vColor;
varying float vHeightFactor;

void main() {
  vec3 pos = aWorldPos
    + uCameraRight * aCorner.x * aWidth
    + uCameraUp    * aCorner.y * aHeight;
  vUV = aCorner * 0.5 + 0.5;
  vColor = aColor;
  vHeightFactor = aLayerIndex / 4.0;
  gl_Position = uViewProj * vec4(pos, 1.0);
}

// ── atmosphericSmokeFragSrc ─────────────────────────────────────────────────
// 4-octave fBm, slow billowing (0.04 rad/s), altitude fade.
// Core is solid; fringe wispy — same principle as close-range smokeFragShader.
void main() {
  float d = length(vUV - 0.5);
  float circleMask = 1.0 - smoothstep(0.35, 0.55, d);

  vec2  billowUV  = vUV * 2.5 + vec2(uTime * 0.04, sin(uTime * 0.03) * 0.3);
  float billowing = fbm(billowUV);     // 4-octave fBm helper

  float altFade = smoothstep(0.0, 0.5, 1.0 - vHeightFactor)
                * smoothstep(1.2, 0.5, vHeightFactor);

  float alpha = vColor.a * circleMask * (0.4 + billowing * 0.6) * altFade;
  if (alpha < 0.02) discard;
  gl_FragColor = vec4(vColor.rgb, alpha);
}
```

### Modified Files

**`lib/game/fire_emitter.dart`** — add `AtmosphericSmokeSystem` to `initZones()` and `tick()`:

```dart
AtmosphericSmokeSystem? _atmosphericSmoke;

void initZones(GameState state) {
  _atmosphericSmoke = AtmosphericSmokeSystem();
  for (int i = 0; i < GameState.firePositions.length; i++) {
    final (fx, fz) = GameState.firePositions[i];
    _zoneEmitters.add(FireEmitter(worldX: fx, worldZ: fz, ...));
    _atmosphericSmoke!.addPlume(i, fx, fz);
  }
}

// In tick():
for (int i = 0; i < _zoneEmitters.length; i++) {
  final intensity = state.fireExtinguished[i] ? 0.0 : 1.0;
  _atmosphericSmoke!.tickPlume(i, intensity, state.apparentWind, dt);
}

List<SmokeColumnParticle> get atmosphericSmokeBillboards =>
    _atmosphericSmoke?.getAllBillboards() ?? [];
```

**`lib/rendering/webgl_renderer.dart`** — add `AtmosphericSmokeRenderer`, call after terrain, before particles.

**`lib/game/game_widget.dart`** — pass billboards to renderer each frame:

```dart
final atmSmoke = _fireSystem.atmosphericSmokeBillboards;
_renderer?.renderAtmosphericSmoke(atmSmoke, _camera);
```

---

## `fire_config.json` Extension

```json
"atmosphericSmoke": {
  "enabled": true,
  "segmentsPerPlume": 50,
  "baseWidth": 100.0,
  "topWidth": 200.0,
  "minHeight": 20.0,
  "maxHeight": 100.0,
  "billowingFrequency": 0.05,
  "windDriftScale": 0.5,
  "colorLayers": [
    [0.15, 0.12, 0.10],
    [0.40, 0.38, 0.35],
    [0.65, 0.63, 0.60],
    [0.85, 0.83, 0.80],
    [0.95, 0.95, 0.95]
  ],
  "opacityProfile": [1.0, 0.8, 0.6, 0.3, 0.1]
}
```

## LOD Strategy

| Camera Distance | Segments/Plume | Billboards (5 zones) |
|----------------|----------------|----------------------|
| < 20 units | 50 (full) | 250 |
| 20–50 units | 30 | 150 |
| 50–150 units | 15 | 75 |
| > 150 units | 5–8 (silhouette) | 25–40 |

GPU cost is minimal — 250 quads is negligible vs. 5000 CPU particles.

---

## Cloud System Plan (Session B)

### Research Summary

| Technique | Used By | WebGL Viable? |
|-----------|---------|---------------|
| Volumetric raymarching | MSFS 2020, DCS modern | No — needs compute shaders |
| Billboard clusters | FSX, X-Plane 10, most arcade sims | **Yes — use this** |
| Slice-based volumetric | No Man's Sky | Yes but expensive (overdraw) |
| Impostor pre-rendered | DCS older | Yes but needs asset pipeline |

**Recommendation:** billboard cluster system reusing `ParticleRenderer` + billboard shader. Each cloud is a `CloudChunk` of 20–60 quads arranged in an ellipsoid. Fly-through effect uses the same screen-space overlay mechanism as `SmokeOverlay`.

### Cloud Types

**Cumulus** — puffy white daytime clouds
- 20–40 billboard quads per chunk, oblate ellipsoid shape
- Color: white/cream sunlit tops, blue-gray shadowed bases
- Altitude: 60–120 world units above terrain
- Fly-through: brief white mist overlay, clears in ~2 s

**Cumulonimbus (CB)** — storm cell, anvil top
- 60–100 quads, tall 3:1 height:width aspect
- Dark gray base → white anvil flattened by wind shear at top
- Altitude: base 40 units, top 200+ units
- Fly-through: physics turbulence jitter + white-out + optional lightning screen-flash

**Stratus/Overcast** — flat gray ceiling layer
- Not a particle cluster — a single horizontal translucent plane mesh with Perlin noise shader
- Player below sees gray ceiling; above sees cloud top (bright featureless white)
- Fly-through: white IMC overlay while within the layer altitude band

**Cirrus** — high wispy ice-crystal streaks
- Reuse wind-streak particle system: long thin quads at 250–400+ world units altitude
- Very low opacity (0.10–0.20), pure white; no fly-through effect

**Pyrocumulus** — fire-induced cloud (auto-triggered)
- Auto-spawns when `smokeOpacity > 0.75` with multiple active zones
- Smoke column top transitions to CB-shaped chunk; dark base connects to particle column

### New Files

- `lib/rendering/cloud_renderer.dart` — per-frame billboard render, back-to-front sort
- `lib/terrain/cloud_system.dart` — chunk generation, weather state, wind drift
- `assets/data/cloud_config.json` — all tunable values per cloud type
- Cloud GLSL added to `fire_shaders.dart` — brighter, less turbulent than smoke shader

### Key Data Structures

```dart
enum CloudType { cumulus, cumulonimbus, stratus, cirrus, pyrocumulus }
enum WeatherState { clear, scattered, broken, overcast }

class CloudBillboard { Vector3 offset; double size, opacity, rotation; }

class CloudChunk {
  CloudType type;
  Vector3   center;
  double    radiusH, radiusV;   // bounding ellipsoid for fly-through detection
  List<CloudBillboard> quads;
}

class CloudSystem {
  WeatherState weather = WeatherState.scattered;
  List<CloudChunk> chunks = [];
}
```

### Implementation Phases

| Phase | Scope |
|-------|-------|
| **1** | `cloud_config.json`, data structures, `CloudRenderer`, cumulus type, fly-through mist overlay |
| **2** | Cumulonimbus (turbulence + lightning), stratus plane mesh, cirrus streaks |
| **3** | Weather state machine, pyrocumulus auto-trigger, cloud shadow on terrain |

---

## Merge Notes

- **Keep systems separate**: macro atmospheric billboards render in their own pass; CPU particles unchanged
- **Shared wind state**: all three systems (particles, atmospheric plumes, clouds) read `GameState.windState`
- **Shared fire intensity signal**: `state.fireExtinguished[i]` drives both particle and atmospheric systems
- **Colour continuity**: atmospheric plume colour layers were designed independently but happen to match the new close-range particle colour gradient — no adjustment needed
- **Blend order**: atmospheric plumes → close-range particles → clouds (clouds are above smoke; render last among scene objects)
- **`ParticleRenderer`** is the structural template for both `AtmosphericSmokeRenderer` and `CloudRenderer`
- **Sky haze**: amber screen tint `(1.0, 0.8, 0.4, 0.15)` can be added to the `HeatDistortionPass` chain as a third optional pass
- **File size**: `atmospheric_smoke_plume.dart` and `atmospheric_smoke_renderer.dart` should each stay under 500 lines (CLAUDE.md rule)
