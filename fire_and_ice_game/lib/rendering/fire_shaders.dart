// GLSL shader sources for fire, smoke, and heat-distortion rendering.
// All shaders target GLSL ES 1.00 (WebGL 1.0) for broadest compatibility.
// The GPU particle simulation shader targets GLSL ES 3.00 (WebGL 2.0) and
// is only compiled when transform-feedback support is detected.

// ── Particle billboard vertex shader (shared by fire and smoke) ──────────────
// Applies per-particle billboard rotation before camera-axis expansion.
// aRotation: radians; smoke rotates slowly, fire uses 0.
// aFuelFraction: [0..1] passed through as a varying for the fire shader.
const String particleVertShader = '''
attribute vec3 aWorldPos;
attribute vec2 aCorner;
attribute vec4 aColor;
attribute float aSize;
attribute float aRotation;
attribute float aFuelFraction;

uniform mat4 uViewProj;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

varying vec2 vUV;
varying vec4 vColor;
varying float vFuelFraction;

void main() {
  float cosR = cos(aRotation);
  float sinR = sin(aRotation);
  vec2 rotCorner = vec2(
    cosR * aCorner.x - sinR * aCorner.y,
    sinR * aCorner.x + cosR * aCorner.y
  );
  vec3 pos = aWorldPos
    + uCameraRight * rotCorner.x * aSize
    + uCameraUp    * rotCorner.y * aSize;
  vUV          = aCorner * 0.5 + 0.5;
  vColor       = aColor;
  vFuelFraction = aFuelFraction;
  gl_Position  = uViewProj * vec4(pos, 1.0);
}
''';

// ── Shared noise helpers (smoke + heat distortion) ────────────────────────────
const String _noiseGlsl = '''
float _hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float _noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(_hash(i),             _hash(i + vec2(1.0, 0.0)), f.x),
    mix(_hash(i + vec2(0.0,1.0)), _hash(i + vec2(1.0,1.0)), f.x),
    f.y);
}
''';

// ── Fire fragment shader (additive blending) ─────────────────────────────────
// Fire/ember particles (detected by vColor.g < 0.01 && vColor.b < 0.01):
//   vColor.r = temperature [0..1], GPU maps to blackbody RGB.
//   vFuelFraction dims the fire as fuel is consumed.
// Non-fire particles use vColor directly (handled by smokeFragShader; this
// branch is unused in the fire batch but guarded here for safety).
const String fireFragShader = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;
varying float vFuelFraction;
uniform float uTime;

float _fHash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float _fNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(_fHash(i),             _fHash(i + vec2(1.0, 0.0)), f.x),
    mix(_fHash(i + vec2(0.0,1.0)), _fHash(i + vec2(1.0,1.0)), f.x),
    f.y);
}
// iq rotation matrix for domain warp
mat2 _fm = mat2(1.6, 1.2, -1.2, 1.6);
float _fbm(vec2 p) {
  return 0.5 * _fNoise(p) + 0.25 * _fNoise(_fm * p);
}

void main() {
  float d    = length(vUV - 0.5) * 2.0;
  float mask = 1.0 - smoothstep(0.55, 1.0, d);

  // Domain-warped fBm: organic fire turbulence without textures.
  vec2  uv = vUV * 3.5 + vec2(0.0, -uTime * 2.3);
  vec2  q  = vec2(_fbm(uv + 0.1 * uTime));
  float n  = _fbm(uv + 4.0 * q);

  float intensity = mask * n * (1.0 - vUV.y * 0.6);

  if (vColor.g < 0.01 && vColor.b < 0.01) {
    // Fire / ember: blackbody coloring from temperature × fuel fraction.
    float t = vColor.r * vFuelFraction;
    vec3 rgb = vec3(
      clamp(t * 3.0, 0.0, 1.0),
      pow(clamp(t * 3.0 - 0.7, 0.0, 1.0), 2.0) * 0.9,
      pow(clamp(t * 3.0 - 2.0, 0.0, 1.0), 3.0) * 0.7
    );
    float alpha = vColor.a * intensity;
    if (alpha < 0.01) discard;
    gl_FragColor = vec4(rgb, alpha);
  } else {
    vec4 col = vColor;
    col.a   *= intensity;
    if (col.a < 0.01) discard;
    gl_FragColor = col;
  }
}
''';

// ── Smoke fragment shader (standard alpha blending) ──────────────────────────
// Three-octave fBm producing a dense cauliflower billow:
//   • Very opaque core (alpha stays near vColor.a for 60% of radius).
//   • Sharp, lobed silhouette edge (not a soft Gaussian blob).
//   • Noise only adds surface texture; it cannot reduce the core below 0.72.
// Reference: wildfire smoke from billow_01–04 images — the interior of a real
// smoke column is almost completely opaque; only the outer fringes are wispy.
const String smokeFragShader = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;
varying float vFuelFraction;
uniform float uTime;

$_noiseGlsl

void main() {
  float d = length(vUV - 0.5) * 2.0;

  // Dense inner core (d < 0.55) stays fully opaque; lobed fringe beyond that.
  float coreMask = 1.0 - smoothstep(0.55, 1.05, d);
  // Cauliflower outer lobe: steep falloff at the edge.
  float edgeMask = 1.0 - smoothstep(0.72, 1.0, d);
  // Blend: inner core is flat-topped, outer fringe falls off sharply.
  float mask = max(coreMask, edgeMask * 0.60);

  // Three-octave noise for billowing surface texture.
  vec2 nuv = vUV * 2.8 + vec2(uTime * 0.06, -uTime * 0.28);
  float n1 = _noise(nuv);
  float n2 = _noise(nuv * 2.2 + vec2(0.53, 0.79)) * 0.45;
  float n3 = _noise(nuv * 4.7 + vec2(0.11, 0.44)) * 0.20;
  float n  = (n1 + n2 + n3) * (1.0 / 1.65);

  // Noise only modulates edge; the core is held at near-full opacity.
  // This prevents smoke from looking transparent/wispy in the interior.
  float edgeFrac = smoothstep(0.30, 0.85, d);
  float noisedMask = mix(mask, mask * (n * 0.55 + 0.45), edgeFrac);

  float alpha = noisedMask * vColor.a;
  if (alpha < 0.01) discard;
  gl_FragColor = vec4(vColor.rgb, alpha);
}
''';

// ── Heat-distortion pass shaders ─────────────────────────────────────────────
const String heatDistortVertShader = '''
attribute vec2 aPosition;
attribute vec2 aTexCoord;

varying vec2 vTexCoord;

void main() {
  vTexCoord   = aTexCoord;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}
''';

const String heatDistortFragShader = '''
precision mediump float;

varying vec2 vTexCoord;
uniform sampler2D uScene;
uniform float uHeat;
uniform float uTime;

$_noiseGlsl

void main() {
  vec2  uv   = vTexCoord;
  vec2  nuv  = uv * 6.0 + vec2(uTime * 0.3, uTime * 0.17);
  float nx   = _noise(nuv);
  float ny   = _noise(nuv + vec2(1.7, 0.4));
  vec2  off  = (vec2(nx, ny) - 0.5) * uHeat * 0.018;
  gl_FragColor = texture2D(uScene, uv + off);
}
''';

// ── GPU particle simulation shader (WebGL 2.0 / GLSL ES 3.00) ───────────────
const String gpuSimVertShader = '''#version 300 es
in vec3 aPos;
in vec3 aVel;
in float aAge;
in float aLifetime;
in float aSize;
in vec4 aColor;

out vec3 outPos;
out vec3 outVel;
out float outAge;
out float outLifetime;
out float outSize;
out vec4 outColor;

uniform float uDt;
uniform vec3  uWind;
uniform float uWindRadius;
uniform vec3  uPlayerPos;
uniform float uBuoyancy;
uniform float uTurbStrength;
uniform float uTime;

float ghash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
  if (aAge >= aLifetime) {
    outPos = aPos; outVel = aVel; outAge = aAge;
    outLifetime = aLifetime; outSize = aSize; outColor = aColor;
    return;
  }

  float d       = length(aPos - uPlayerPos);
  float wFactor = max(0.0, 1.0 - d / uWindRadius);
  vec3 windForce = uWind * wFactor * 0.55;

  float h   = ghash(aPos.xz + vec2(uTime * 0.3, uTime * 0.17));
  float h2  = ghash(aPos.xz * 1.7 + vec2(uTime * 0.2));
  vec3 turb = vec3(h * 2.0 - 1.0, 0.0, h2 * 2.0 - 1.0) * uTurbStrength;

  float isFire = step(0.5, aColor.r - aColor.b);
  float netUp  = uBuoyancy * isFire + uBuoyancy * 0.3 * (1.0 - isFire) - 9.8;

  vec3 accel = vec3(0.0, netUp, 0.0) + windForce + turb;
  outVel     = aVel + accel * uDt;
  outPos     = aPos + outVel * uDt;
  outAge     = aAge + uDt;
  outLifetime = aLifetime;
  outSize    = aSize;
  outColor   = aColor;
}
''';

const String gpuBillboardVertShader = '''#version 300 es
in vec3 aPos;
in vec4 aColor;
in float aSize;
in float aAge;
in float aLifetime;
in vec2 aCorner;

uniform mat4 uViewProj;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

out vec2 vUV;
out vec4 vColor;

void main() {
  float t  = aAge / max(aLifetime, 0.001);
  float alpha = aColor.a * (1.0 - smoothstep(0.7, 1.0, t));
  vec3 pos = aPos
    + uCameraRight * aCorner.x * aSize
    + uCameraUp    * aCorner.y * aSize;
  vUV         = aCorner * 0.5 + 0.5;
  vColor      = vec4(aColor.rgb, alpha);
  gl_Position = uViewProj * vec4(pos, 1.0);
}
''';

const String gpuFireFragShader  = fireFragShader;
const String gpuSmokeFragShader = smokeFragShader;

// ── Atmospheric smoke plume vertex shader ─────────────────────────────────────
// Each billboard segment has an independent width/height for the stacked column.
// aLayerIndex drives the fragment altitude fade (0 = soot base, 4 = cream top).
const String atmosphericSmokeVertSrc = '''
attribute vec3  aWorldPos;
attribute vec2  aCorner;
attribute vec4  aColor;
attribute float aWidth;
attribute float aHeight;
attribute float aLayerIndex;

uniform mat4 uViewProj;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

varying vec2  vUV;
varying vec4  vColor;
varying float vHeightFactor;

void main() {
  vec3 pos = aWorldPos
    + uCameraRight * aCorner.x * aWidth
    + uCameraUp    * aCorner.y * aHeight;
  vUV          = aCorner * 0.5 + 0.5;
  vColor       = aColor;
  vHeightFactor = aLayerIndex / 4.0;
  gl_Position  = uViewProj * vec4(pos, 1.0);
}
''';

// ── Atmospheric smoke plume fragment shader ────────────────────────────────────
// Dense core (flat-topped), slow 4-octave fBm, altitude fade top and bottom.
// Designed for far-field plumes that must read as solid geological features.
const String atmosphericSmokeFragSrc = '''
precision mediump float;

varying vec2  vUV;
varying vec4  vColor;
varying float vHeightFactor;

uniform float uTime;

float ahash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float anoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float n0 = mix(ahash(i),             ahash(i + vec2(1.0, 0.0)), f.x);
  float n1 = mix(ahash(i + vec2(0.0,1.0)), ahash(i + vec2(1.0,1.0)), f.x);
  return mix(n0, n1, f.y);
}
float afbm(vec2 p) {
  float r = 0.0; float a = 0.5;
  for (int i = 0; i < 4; i++) { r += a * anoise(p); p *= 2.0; a *= 0.5; }
  return r;
}

void main() {
  float d = length(vUV - 0.5);

  // Dense flat-topped core; sharp lobed fringe.
  float core = 1.0 - smoothstep(0.28, 0.50, d);
  float edge = 1.0 - smoothstep(0.42, 0.68, d);
  float mask = max(core, edge * 0.70);

  // Very slow billowing (massive plume must feel geological).
  vec2  billowUV = vUV * 2.0 + vec2(uTime * 0.03, sin(uTime * 0.02) * 0.22);
  float billowing = afbm(billowUV);

  // Altitude fade: solid at low layers, wispy near the top.
  float altFade = smoothstep(0.0, 0.25, 1.0 - vHeightFactor)
                * smoothstep(1.1, 0.55, vHeightFactor);

  float alpha = vColor.a * mask * (0.45 + billowing * 0.55) * altFade;
  if (alpha < 0.015) discard;
  gl_FragColor = vec4(vColor.rgb, alpha);
}
''';

// ── Cloud billboard vertex shader ─────────────────────────────────────────────
// Shared by cumulus, CB, cirrus, and pyrocumulus billboard quads.
// Supports per-billboard rotation for visual variety.
const String cloudVertSrc = '''
attribute vec3  aWorldPos;
attribute vec2  aCorner;
attribute vec4  aColor;
attribute float aSize;
attribute float aRotation;

uniform mat4 uViewProj;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

varying vec2 vUV;
varying vec4 vColor;

void main() {
  float cosR = cos(aRotation);
  float sinR = sin(aRotation);
  vec2  rc   = vec2(cosR * aCorner.x - sinR * aCorner.y,
                    sinR * aCorner.x + cosR * aCorner.y);
  vec3 pos = aWorldPos
    + uCameraRight * rc.x * aSize
    + uCameraUp    * rc.y * aSize;
  vUV         = aCorner * 0.5 + 0.5;
  vColor      = aColor;
  gl_Position = uViewProj * vec4(pos, 1.0);
}
''';

// ── Cloud billboard fragment shader ──────────────────────────────────────────
// Fluffy cumulus shape: opaque rounded core, small-scale bumps on silhouette,
// gentle interior shading. Same non-texture approach as the fire/smoke shaders.
const String cloudFragSrc = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;

uniform float uTime;

float chash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float cnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float n0 = mix(chash(i),             chash(i + vec2(1.0, 0.0)), f.x);
  float n1 = mix(chash(i + vec2(0.0,1.0)), chash(i + vec2(1.0,1.0)), f.x);
  return mix(n0, n1, f.y);
}

void main() {
  float d = length(vUV - 0.5) * 2.0;

  // Rounded core + edge bumps → cauliflower silhouette
  float core = 1.0 - smoothstep(0.42, 0.98, d);
  vec2  edgeUV = vUV * 4.5 + vec2(uTime * 0.018, uTime * 0.012);
  float bump = cnoise(edgeUV) * 0.20;
  float mask = clamp(core + bump * (1.0 - core), 0.0, 1.0);

  // Gentle interior shading (clouds are brighter near the light-facing centre).
  vec2  intUV   = vUV * 3.0 + vec2(uTime * 0.009, -uTime * 0.007);
  float interior = cnoise(intUV) * 0.22 + 0.78;

  float alpha = mask * interior * vColor.a;
  if (alpha < 0.008) discard;
  gl_FragColor = vec4(vColor.rgb, alpha);
}
''';
