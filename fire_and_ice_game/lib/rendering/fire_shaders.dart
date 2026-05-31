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
// Multi-octave fBm for large volumetric billows matching fire_03/forest_fire_01
// reference aesthetics: sharp-edged cauliflower silhouette, turbulent interior.
const String smokeFragShader = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;
varying float vFuelFraction;
uniform float uTime;

$_noiseGlsl

void main() {
  float d    = length(vUV - 0.5) * 2.0;
  // Sharper outer silhouette → distinct billow edges (not soft blobs).
  float mask = 1.0 - smoothstep(0.18, 0.88, d);
  mask = sqrt(mask);

  // Two-octave turbulence: slow drift on large scale, tighter detail inside.
  vec2 nuv = vUV * 2.6 + vec2(uTime * 0.08, -uTime * 0.34);
  float n1 = _noise(nuv);
  float n2 = _noise(nuv * 2.4 + vec2(0.49, 0.82)) * 0.50;
  float n  = (n1 + n2) * (1.0 / 1.50);
  // Boost contrast → distinct lobes instead of uniform grey mass.
  n = sqrt(n);

  float alpha = mask * n * vColor.a;
  if (alpha < 0.012) discard;
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
