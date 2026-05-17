// GLSL shader sources for fire, smoke, and heat-distortion rendering.
// All shaders target GLSL ES 1.00 (WebGL 1.0) for broadest compatibility.
// The GPU particle simulation shader targets GLSL ES 3.00 (WebGL 2.0) and
// is only compiled when transform-feedback support is detected.

// ── Particle billboard vertex shader (shared by fire and smoke) ──────────────
// Expands a world-space point into a camera-facing quad using the camera's
// right and up axes, avoiding an inverse-VP decomposition on the GPU.
const String particleVertShader = '''
attribute vec3 aWorldPos;
attribute vec2 aCorner;
attribute vec4 aColor;
attribute float aSize;

uniform mat4 uViewProj;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

varying vec2 vUV;
varying vec4 vColor;

void main() {
  vec3 pos = aWorldPos
    + uCameraRight * aCorner.x * aSize
    + uCameraUp    * aCorner.y * aSize;
  vUV         = aCorner * 0.5 + 0.5;
  vColor      = aColor;
  gl_Position = uViewProj * vec4(pos, 1.0);
}
''';

// ── Shared noise helpers (inlined per shader to avoid GLSL include limits) ───

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
// Procedural animated noise gives organic turbulent fire without textures.
// Rendered with SRC_ALPHA, ONE blending so overlapping particles bloom bright.
const String fireFragShader = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;
uniform float uTime;

$_noiseGlsl

void main() {
  float d    = length(vUV - 0.5) * 2.0;
  float mask = 1.0 - smoothstep(0.55, 1.0, d);
  vec2  nuv  = vUV * 3.5 + vec2(0.0, -uTime * 2.3);
  float n    = _noise(nuv) * 0.6 + _noise(nuv * 2.1 + vec2(0.5, 0.5)) * 0.4;
  float intensity = mask * n * (1.0 - vUV.y * 0.6);
  vec4  col  = vColor;
  col.a *= intensity;
  if (col.a < 0.01) discard;
  gl_FragColor = col;
}
''';

// ── Smoke fragment shader (standard alpha blending) ──────────────────────────
// Softer edge, slower animation, cooler grey tones supplied via vColor.
const String smokeFragShader = '''
precision mediump float;

varying vec2 vUV;
varying vec4 vColor;
uniform float uTime;

$_noiseGlsl

void main() {
  float d    = length(vUV - 0.5) * 2.0;
  float mask = 1.0 - smoothstep(0.3, 1.0, d);
  vec2  nuv  = vUV * 2.0 + vec2(uTime * 0.12, -uTime * 0.5);
  float n    = _noise(nuv) * 0.7 + _noise(nuv * 3.0 + vec2(0.3, 0.7)) * 0.3;
  float alpha = mask * n * vColor.a;
  if (alpha < 0.02) discard;
  gl_FragColor = vec4(vColor.rgb, alpha);
}
''';

// ── Heat-distortion pass shaders ─────────────────────────────────────────────
// The vertex shader renders a full-screen NDC quad (-1..1).
// The fragment shader samples the scene texture with a noise-driven UV offset
// scaled by uHeat (0=no distortion, 1=max distortion near fire zones).
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
// Runs per-particle physics entirely on the GPU via transform feedback.
// Reads from the current-frame particle buffer; writes updated state to the
// next-frame buffer without any CPU round-trip.
//
// Particle record layout (13 floats): pos(3) vel(3) age(1) lifetime(1) size(1) color(4)
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

  // Fire (red-dominant at birth) rises; smoke (grey) has lighter buoyancy.
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

// GPU rendering vertex shader for instanced billboard from transform-feedback buffer.
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
  // Fade out in final 30% of life
  float alpha = aColor.a * (1.0 - smoothstep(0.7, 1.0, t));
  vec3 pos = aPos
    + uCameraRight * aCorner.x * aSize
    + uCameraUp    * aCorner.y * aSize;
  vUV         = aCorner * 0.5 + 0.5;
  vColor      = vec4(aColor.rgb, alpha);
  gl_Position = uViewProj * vec4(pos, 1.0);
}
''';

// Reuse fire/smoke frag shaders for GPU path — same visual, different update path.
const String gpuFireFragShader = fireFragShader;
const String gpuSmokeFragShader = smokeFragShader;
