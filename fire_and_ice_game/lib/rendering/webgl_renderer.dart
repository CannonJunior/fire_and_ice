import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../terrain/cloud_system.dart';
import 'atmospheric_smoke_plume.dart';
import 'atmospheric_smoke_renderer.dart';
import 'camera3d.dart';
import 'cloud_renderer.dart';
import 'heat_distortion.dart';
import 'mesh.dart';
import 'gpu_particle_system.dart';
import 'particle_renderer.dart';
import 'particle_system.dart';
import 'scene_node.dart';
import 'shader_program.dart';
import 'transform3d.dart';

/// WebGLRenderer - Core WebGL rendering engine for Fire & Ice.
///
/// Manages the WebGL context obtained from a dart:html CanvasElement.
/// Uploads mesh geometry to GPU buffers (cached per-Mesh object) and
/// draws them with the default Blinn-Phong shader.
///
/// No texture system - vertex colors + lighting only (simpler than Warchief).
///
/// Usage:
/// ```dart
/// final renderer = WebGLRenderer(canvasElement);
/// renderer.clear();
/// renderer.render(mesh, transform, camera);
/// ```
class WebGLRenderer {
  final html.CanvasElement canvas;

  /// WebGL rendering context (dynamic for dart:html compatibility)
  final dynamic gl;

  /// Default lit shader program
  late ShaderProgram shader;

  // ── Lighting uniforms (set once, used every frame) ─────────────────────

  /// World-space directional light position
  Vector3 lightPosition = Vector3(50, 80, 50);

  /// Light RGB intensity (0-1)
  Vector3 lightColor = Vector3(1.0, 0.95, 0.85);

  /// Ambient light (fills in shadow areas)
  Vector3 ambientColor = Vector3(0.25, 0.25, 0.35);

  /// Heat distortion post-process pass (optional; degrades gracefully).
  late HeatDistortionPass heatDistortion;

  /// GPU particle system (WebGL2 only; null if unavailable).
  GpuParticleSystem? gpuParticles;

  /// Billboard quad particle renderer; replaces GL_POINTS when ready.
  ParticleRenderer? _pRenderer;
  bool _useParticleRenderer = false;

  /// Long-range atmospheric smoke plume renderer.
  AtmosphericSmokeRenderer? _atmRenderer;

  /// Cloud billboard renderer.
  CloudRenderer? _cloudRenderer;

  /// Elapsed game time in seconds, used by animated shader effects.
  double _time = 0.0;
  set time(double v) => _time = v;

  /// Fire light positions for dynamic lighting (set each frame by FireEmitter).
  List<(double, double, double, double)>? _fireLights;
  set fireLights(List<(double, double, double, double)> v) => _fireLights = v;

  // ── Particle render state ────────────────────────────────────────────────

  ShaderProgram? _particleShader;
  dynamic _particleVbo;
  Float32List _particleDataBuf = Float32List(0);
  // Cached view into _particleDataBuf — avoids a heap alloc per frame.
  // Invalidated whenever _particleDataBuf is reallocated or needed count changes.
  Float32List? _particleDataView;
  int _particleDataViewLen = 0;
  final Vector4 _cpuColorScratch = Vector4.zero();
  // Cached attrib locations for fallback particle shader — queried once at init.
  int _pFbPosLoc   = -1;
  int _pFbColorLoc = -1;
  int _pFbSizeLoc  = -1;

  // ── Scene graph scratch ───────────────────────────────────────────────────

  final List<SceneNode> _renderablesScratch = [];

  static const String _particleVertSrc = '''
attribute vec3 aPos;
attribute vec4 aColor;
attribute float aSize;
uniform mat4 uViewProj;
varying vec4 vColor;
void main() {
  vColor = aColor;
  gl_Position = uViewProj * vec4(aPos, 1.0);
  gl_PointSize = aSize;
}
''';
  static const String _particleFragSrc = '''
precision mediump float;
varying vec4 vColor;
void main() {
  vec2 c = gl_PointCoord - 0.5;
  if (dot(c, c) > 0.25) discard;
  gl_FragColor = vColor;
}
''';

  /// Per-mesh GPU buffer cache. Avoids re-uploading static geometry each frame.
  final Map<Mesh, _MeshBuffers> _meshBuffers = {};

  // ── Per-frame state ───────────────────────────────────────────────────────

  /// OES_vertex_array_object extension handle; null if using WebGL2 native VAO.
  dynamic _vaoExt;

  /// True when VAO creation is available (WebGL2 native or OES extension).
  bool _supportsVAO = false;

  /// Currently active shader program — guards redundant useProgram() calls.
  dynamic _activeProgram;

  /// Currently bound VAO — deferred unbind: stays bound across consecutive mesh
  /// draws (binding a new VAO auto-unbinds the previous one). Unbound at the
  /// start of particle/smoke/cloud passes that set their own attribute state.
  dynamic _activeVAO;

  /// Pre-allocated normal matrix — avoids a Matrix3 allocation per draw call.
  final Matrix3 _normalMatrixScratch = Matrix3.zero();

  /// Cached attribute locations (queried once after shader compile).
  late int _posLoc, _normLoc, _colLoc;

  /// Pre-multiplied projection × view matrix, recomputed once per frame in clear().
  final Matrix4 _scratchViewProj = Matrix4.identity();

  /// Set true by clear(); cleared on first renderWithMatrix() call per frame.
  bool _viewProjDirty = true;

  WebGLRenderer._(this.canvas, this.gl) {
    _initialize();
  }

  /// Obtain a WebGL context from [canvas] and create the renderer.
  ///
  /// Throws if WebGL is unavailable in the current browser.
  ///
  /// Prefers WebGL2 so that VAO state correctly tracks the element array buffer
  /// binding (OES_vertex_array_object on WebGL1 does not track it, causing
  /// silent draw failures). Falls back to WebGL1 if WebGL2 is unavailable.
  factory WebGLRenderer(html.CanvasElement canvas) {
    final attrs = {'alpha': false, 'depth': true, 'antialias': true};
    var gl = canvas.getContext('webgl2', attrs);
    gl ??= canvas.getContext('webgl', attrs);
    if (gl == null) throw Exception('WebGL not supported in this browser');
    return WebGLRenderer._(canvas, gl);
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  void _initialize() {
    gl.enable(0x0B71);  // DEPTH_TEST
    gl.depthFunc(0x0201); // LESS
    gl.enable(0x0B44);   // CULL_FACE
    gl.cullFace(0x0405); // BACK

    gl.clearColor(0.25, 0.50, 0.80, 1.0);

    shader = ShaderProgram.fromSource(gl, defaultVertexShader, defaultFragmentShader);

    // Cache attrib locations once — used during VAO setup and fallback draws.
    _posLoc  = shader.getAttribLocation('aPosition');
    _normLoc = shader.getAttribLocation('aNormal');
    _colLoc  = shader.getAttribLocation('aColor');

    // Detect VAO support: prefer WebGL2 native, fall back to OES extension.
    try {
      final testVao = gl.createVertexArray();
      if (testVao != null) {
        gl.deleteVertexArray(testVao);
        _supportsVAO = true;
      }
    } catch (_) {
      _vaoExt = gl.getExtension('OES_vertex_array_object');
      if (_vaoExt != null) _supportsVAO = true;
    }

    heatDistortion = HeatDistortionPass(gl);

    // Attempt billboard renderer at init (not lazily) so failures surface early.
    _pRenderer = ParticleRenderer(gl);
    _useParticleRenderer = _pRenderer!.isReady;

    _atmRenderer   = AtmosphericSmokeRenderer(gl);
    _cloudRenderer = CloudRenderer(gl);

    debugPrint('[WebGLRenderer] initialized (VAO: $_supportsVAO, billboardParticles: $_useParticleRenderer)');
  }

  // ── VAO helpers ───────────────────────────────────────────────────────────

  dynamic _createVAO() => _vaoExt != null
      ? _vaoExt.createVertexArrayOES()
      : gl.createVertexArray();

  void _bindVAO(dynamic vao) => _vaoExt != null
      ? _vaoExt.bindVertexArrayOES(vao)
      : gl.bindVertexArray(vao);

  void _unbindVAO() => _vaoExt != null
      ? _vaoExt.bindVertexArrayOES(null)
      : gl.bindVertexArray(null);

  void _deleteVAO(dynamic vao) => _vaoExt != null
      ? _vaoExt.deleteVertexArrayOES(vao)
      : gl.deleteVertexArray(vao);

  // ── Frame operations ─────────────────────────────────────────────────────

  /// Clear colour and depth buffers. Call at the start of each frame.
  void clear() {
    // COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT
    gl.clear(0x00004000 | 0x00000100);
    // Reset per-frame render state
    _viewProjDirty = true;
    _activeProgram = null;
    _unbindActiveVAO();
  }

  void _unbindActiveVAO() {
    if (_activeVAO != null) {
      _unbindVAO();
      _activeVAO = null;
    }
  }

  /// Draw [mesh] at world-space [transform] as seen by [camera].
  void render(Mesh mesh, Transform3d transform, Camera3D camera) =>
      renderWithMatrix(mesh, transform.toMatrix(), camera);

  /// Draw [mesh] using a raw world-space [modelMatrix].
  ///
  /// Used by [renderSceneGraph] to avoid wrapping every SceneNode in a
  /// Transform3d.  Uploads geometry to GPU on first call (cached thereafter).
  void renderWithMatrix(Mesh mesh, Matrix4 modelMatrix, Camera3D camera) {
    final bufs = _getOrCreateBuffers(mesh);

    // Guard: skip useProgram() if the shader is already active.
    if (_activeProgram != shader.program) {
      shader.use();
      _activeProgram = shader.program;
    }

    // Compute projection × view and upload static-per-frame uniforms once per frame.
    if (_viewProjDirty) {
      _scratchViewProj.setFrom(camera.getProjectionMatrix());
      _scratchViewProj.multiply(camera.getViewMatrix());
      shader.setUniformVector3('uLightPos',     lightPosition);
      shader.setUniformVector3('uLightColor',   lightColor);
      shader.setUniformVector3('uAmbientColor', ambientColor);
      _viewProjDirty = false;
    }

    shader.setUniformMatrix4('uViewProj',      _scratchViewProj);
    shader.setUniformMatrix4('uModel',         modelMatrix);
    // Extract rotation in-place — avoids Matrix3 allocation on every draw call.
    modelMatrix.copyRotation(_normalMatrixScratch);
    shader.setUniformMatrix3('uNormalMatrix',  _normalMatrixScratch);

    if (bufs.vao != null) {
      // VAO path: only rebind when the VAO changes — binding a new VAO
      // auto-unbinds the previous one. Explicit unbind is deferred to clear().
      if (bufs.vao != _activeVAO) {
        _bindVAO(bufs.vao);
        _activeVAO = bufs.vao;
      }
      // Constant vertex color: not tracked by VAO, must be set per draw call.
      if (bufs.colorBuffer == null) gl.vertexAttrib4f(_colLoc, 1.0, 1.0, 1.0, 1.0);
      gl.drawElements(0x0004, mesh.indices.length, 0x1403, 0); // TRIANGLES, UNSIGNED_SHORT
    } else {
      // Fallback: ensure no VAO is bound before manual attribute setup.
      _unbindActiveVAO();
      // Fallback: per-draw-call attribute setup (no VAO support).
      if (_posLoc >= 0) {
        gl.bindBuffer(0x8892, bufs.vertexBuffer); // ARRAY_BUFFER
        gl.enableVertexAttribArray(_posLoc);
        gl.vertexAttribPointer(_posLoc, 3, 0x1406, false, 0, 0); // FLOAT
      }
      if (_normLoc >= 0 && bufs.normalBuffer != null) {
        gl.bindBuffer(0x8892, bufs.normalBuffer);
        gl.enableVertexAttribArray(_normLoc);
        gl.vertexAttribPointer(_normLoc, 3, 0x1406, false, 0, 0);
      }
      if (_colLoc >= 0) {
        if (bufs.colorBuffer != null) {
          gl.bindBuffer(0x8892, bufs.colorBuffer);
          gl.enableVertexAttribArray(_colLoc);
          gl.vertexAttribPointer(_colLoc, 4, 0x1406, false, 0, 0);
        } else {
          gl.disableVertexAttribArray(_colLoc);
          gl.vertexAttrib4f(_colLoc, 1.0, 1.0, 1.0, 1.0);
        }
      }
      gl.bindBuffer(0x8893, bufs.indexBuffer); // ELEMENT_ARRAY_BUFFER
      gl.drawElements(0x0004, mesh.indices.length, 0x1403, 0);
      if (_posLoc  >= 0) gl.disableVertexAttribArray(_posLoc);
      if (_normLoc >= 0) gl.disableVertexAttribArray(_normLoc);
      if (_colLoc  >= 0) gl.disableVertexAttribArray(_colLoc);
    }
  }

  /// Walk a SceneNode scene graph and render every node that carries a mesh.
  ///
  /// Call after [SceneNode.updateWorldMatrix] has been called on the root.
  /// One draw call per node with a mesh — typically ~8–12 for a full aircraft.
  void renderSceneGraph(SceneNode root, Camera3D camera) {
    _renderablesScratch.clear();
    root.collectRenderables(_renderablesScratch);
    for (final node in _renderablesScratch) {
      renderWithMatrix(node.mesh!, node.worldMatrix, camera);
    }
  }

  // ── Buffer management ─────────────────────────────────────────────────────

  _MeshBuffers _getOrCreateBuffers(Mesh mesh) {
    if (_meshBuffers.containsKey(mesh)) return _meshBuffers[mesh]!;

    // Unbind any active VAO before uploads: _upload calls gl.bindBuffer(target, null)
    // which would corrupt the active VAO's element-array-buffer binding.
    _unbindActiveVAO();
    final vertexBuffer = _upload(0x8892, mesh.vertices); // ARRAY_BUFFER
    final indexBuffer  = _upload(0x8893, mesh.indices);  // ELEMENT_ARRAY_BUFFER
    final normalBuffer = mesh.normals != null ? _upload(0x8892, mesh.normals!) : null;
    final colorBuffer  = mesh.colors  != null ? _upload(0x8892, mesh.colors!)  : null;

    dynamic vao;
    if (_supportsVAO) {
      vao = _createVAO();
      _bindVAO(vao);

      // Record attrib pointers and index buffer into VAO state.
      if (_posLoc >= 0) {
        gl.bindBuffer(0x8892, vertexBuffer);
        gl.enableVertexAttribArray(_posLoc);
        gl.vertexAttribPointer(_posLoc, 3, 0x1406, false, 0, 0);
      }
      if (_normLoc >= 0 && normalBuffer != null) {
        gl.bindBuffer(0x8892, normalBuffer);
        gl.enableVertexAttribArray(_normLoc);
        gl.vertexAttribPointer(_normLoc, 3, 0x1406, false, 0, 0);
      }
      if (_colLoc >= 0 && colorBuffer != null) {
        gl.bindBuffer(0x8892, colorBuffer);
        gl.enableVertexAttribArray(_colLoc);
        gl.vertexAttribPointer(_colLoc, 4, 0x1406, false, 0, 0);
      }
      // ELEMENT_ARRAY_BUFFER binding IS tracked by VAO state.
      gl.bindBuffer(0x8893, indexBuffer);

      _unbindVAO();
      _activeVAO = null; // VAO was unbound; reset tracking so next draw always rebinds
    }

    final bufs = _MeshBuffers(
      vertexBuffer: vertexBuffer,
      indexBuffer:  indexBuffer,
      normalBuffer: normalBuffer,
      colorBuffer:  colorBuffer,
      vao:          vao,
    );
    _meshBuffers[mesh] = bufs;
    return bufs;
  }

  /// Create a GPU buffer, bind it, and upload [data] as STATIC_DRAW.
  dynamic _upload(int target, dynamic data) {
    final buf = gl.createBuffer();
    if (buf == null) throw Exception('Failed to create GL buffer');
    gl.bindBuffer(target, buf);
    gl.bufferData(target, data, 0x88E4); // STATIC_DRAW
    gl.bindBuffer(target, null);
    return buf;
  }

  /// Release GPU buffers for a mesh that is no longer needed.
  void deleteMeshBuffers(Mesh mesh) {
    final bufs = _meshBuffers.remove(mesh);
    if (bufs == null) return;
    if (bufs.vao != null) _deleteVAO(bufs.vao);
    gl.deleteBuffer(bufs.vertexBuffer);
    gl.deleteBuffer(bufs.indexBuffer);
    if (bufs.normalBuffer != null) gl.deleteBuffer(bufs.normalBuffer);
    if (bufs.colorBuffer  != null) gl.deleteBuffer(bufs.colorBuffer);
  }

  // ── Smoke / sky tinting ───────────────────────────────────────────────────

  /// Shift sky clear-colour toward ash-brown as smoke density rises [0..1].
  void updateSmoke(double smoke) {
    final r = (0.25 + smoke * 0.22).clamp(0.0, 1.0);
    final g = (0.50 - smoke * 0.30).clamp(0.0, 1.0);
    final b = (0.80 - smoke * 0.64).clamp(0.0, 1.0);
    gl.clearColor(r, g, b, 1.0);
  }

  // ── Heat distortion pass ──────────────────────────────────────────────────

  /// Redirect subsequent scene draws into the heat FBO.
  void beginHeatPass() => heatDistortion.bindFbo();

  /// Blit the heat FBO to screen with distortion.
  void endHeatPass(double intensity) => heatDistortion.apply(intensity, _time);

  // ── CPU particle rendering ────────────────────────────────────────────────

  /// Render CPU particles — billboard quads when available, GL_POINTS fallback.
  void renderParticles(List<Particle> particles, Camera3D camera) {
    if (particles.isEmpty) return;
    _unbindActiveVAO(); // particle shader sets its own attribute state
    if (_useParticleRenderer && _pRenderer != null) {
      _pRenderer!.render(particles, camera, _time);
      return;
    }
    if (_particleShader == null) {
      _particleShader = ShaderProgram.fromSource(gl, _particleVertSrc, _particleFragSrc);
      _pFbPosLoc   = _particleShader!.getAttribLocation('aPos');
      _pFbColorLoc = _particleShader!.getAttribLocation('aColor');
      _pFbSizeLoc  = _particleShader!.getAttribLocation('aSize');
    }
    _particleVbo ??= gl.createBuffer();

    const stride = 8; // x,y,z, r,g,b,a, size
    final needed = particles.length * stride;
    if (_particleDataBuf.length < needed) {
      _particleDataBuf = Float32List(needed + stride * 100);
      _particleDataView = null; // backing buffer replaced — invalidate cached view
    }
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      p.writeColor(_cpuColorScratch);
      final b = i * stride;
      _particleDataBuf[b]     = p.position.x;
      _particleDataBuf[b + 1] = p.position.y;
      _particleDataBuf[b + 2] = p.position.z;
      _particleDataBuf[b + 3] = _cpuColorScratch.r;
      _particleDataBuf[b + 4] = _cpuColorScratch.g;
      _particleDataBuf[b + 5] = _cpuColorScratch.b;
      _particleDataBuf[b + 6] = _cpuColorScratch.a;
      _particleDataBuf[b + 7] = p.size;
    }

    gl.bindBuffer(0x8892, _particleVbo); // ARRAY_BUFFER
    if (_particleDataView == null || _particleDataViewLen != needed) {
      _particleDataView   = Float32List.view(_particleDataBuf.buffer, 0, needed);
      _particleDataViewLen = needed;
    }
    gl.bufferData(0x8892, _particleDataView!, 0x88E8); // DYNAMIC_DRAW

    _particleShader!.use();
    _activeProgram = _particleShader!.program;

    if (_viewProjDirty) {
      _scratchViewProj.setFrom(camera.getProjectionMatrix());
      _scratchViewProj.multiply(camera.getViewMatrix());
      _viewProjDirty = false;
    }
    _particleShader!.setUniformMatrix4('uViewProj', _scratchViewProj);

    const byteStride = stride * 4;
    if (_pFbPosLoc   >= 0) { gl.enableVertexAttribArray(_pFbPosLoc);   gl.vertexAttribPointer(_pFbPosLoc,   3, 0x1406, false, byteStride, 0);  }
    if (_pFbColorLoc >= 0) { gl.enableVertexAttribArray(_pFbColorLoc); gl.vertexAttribPointer(_pFbColorLoc, 4, 0x1406, false, byteStride, 12); }
    if (_pFbSizeLoc  >= 0) { gl.enableVertexAttribArray(_pFbSizeLoc);  gl.vertexAttribPointer(_pFbSizeLoc,  1, 0x1406, false, byteStride, 28); }

    gl.enable(0x0BE2); // BLEND
    gl.blendFunc(0x0302, 0x0303); // SRC_ALPHA, ONE_MINUS_SRC_ALPHA
    gl.drawArrays(0x0000, 0, particles.length); // POINTS
    gl.disable(0x0BE2);

    if (_pFbPosLoc   >= 0) gl.disableVertexAttribArray(_pFbPosLoc);
    if (_pFbColorLoc >= 0) gl.disableVertexAttribArray(_pFbColorLoc);
    if (_pFbSizeLoc  >= 0) gl.disableVertexAttribArray(_pFbSizeLoc);
    gl.bindBuffer(0x8892, null);
    _activeProgram = null;
  }

  // ── Atmospheric smoke + cloud rendering ───────────────────────────────────

  /// Render long-range atmospheric smoke plume billboards.
  /// Call after scene meshes and trees, before close-range particles.
  void renderAtmosphericSmoke(
      List<SmokeColumnBillboard> billboards, Camera3D camera) {
    _unbindActiveVAO();
    _atmRenderer?.render(billboards, camera, _time);
  }

  /// Render cloud billboard chunks.
  /// Call after close-range particles (clouds are highest in the scene).
  void renderClouds(List<CloudChunk> chunks, Camera3D camera) {
    _unbindActiveVAO();
    _cloudRenderer?.render(chunks, camera, _time);
  }

  /// Update canvas + viewport dimensions on window resize.
  void resize(int width, int height) {
    canvas.width  = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
  }

  /// Release all GPU resources.
  void dispose() {
    for (final b in _meshBuffers.values) {
      if (b.vao != null) _deleteVAO(b.vao);
      gl.deleteBuffer(b.vertexBuffer);
      gl.deleteBuffer(b.indexBuffer);
      if (b.normalBuffer != null) gl.deleteBuffer(b.normalBuffer);
      if (b.colorBuffer  != null) gl.deleteBuffer(b.colorBuffer);
    }
    _meshBuffers.clear();
    shader.dispose();
    _particleShader?.dispose();
    if (_particleVbo != null) gl.deleteBuffer(_particleVbo);
    _pRenderer?.dispose();
    _pRenderer = null;
    _atmRenderer?.dispose();
    _atmRenderer = null;
    _cloudRenderer?.dispose();
    _cloudRenderer = null;
    heatDistortion.dispose();
    debugPrint('[WebGLRenderer] disposed');
  }
}

/// GPU buffer handles for one Mesh.
class _MeshBuffers {
  final dynamic vertexBuffer;
  final dynamic indexBuffer;
  final dynamic normalBuffer;
  final dynamic colorBuffer;

  /// VAO handle; null if VAO is not supported.
  final dynamic vao;

  const _MeshBuffers({
    required this.vertexBuffer,
    required this.indexBuffer,
    this.normalBuffer,
    this.colorBuffer,
    this.vao,
  });
}
