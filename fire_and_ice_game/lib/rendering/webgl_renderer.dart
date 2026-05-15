import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import 'camera3d.dart';
import 'mesh.dart';
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

  /// Per-mesh GPU buffer cache. Avoids re-uploading static geometry each frame.
  final Map<Mesh, _MeshBuffers> _meshBuffers = {};

  // ── Per-frame state ───────────────────────────────────────────────────────

  /// OES_vertex_array_object extension handle; null if using WebGL2 native VAO.
  dynamic _vaoExt;

  /// True when VAO creation is available (WebGL2 native or OES extension).
  bool _supportsVAO = false;

  /// Currently active shader program — guards redundant useProgram() calls.
  dynamic _activeProgram;

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
  factory WebGLRenderer(html.CanvasElement canvas) {
    final gl = canvas.getContext3d(
      alpha: false,
      depth: true,
      antialias: true,
    );
    if (gl == null) throw Exception('WebGL not supported in this browser');
    return WebGLRenderer._(canvas, gl);
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  void _initialize() {
    gl.enable(0x0B71);  // DEPTH_TEST
    gl.depthFunc(0x0201); // LESS
    gl.enable(0x0B44);  // CULL_FACE
    gl.cullFace(0x0405); // BACK

    // Deep navy sky matches the fire & ice elemental theme
    gl.clearColor(0.05, 0.05, 0.15, 1.0);

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

    debugPrint('[WebGLRenderer] initialized (VAO: $_supportsVAO)');
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

    // Compute projection × view once per frame (camera doesn't change mid-frame).
    if (_viewProjDirty) {
      _scratchViewProj.setFrom(camera.getProjectionMatrix());
      _scratchViewProj.multiply(camera.getViewMatrix());
      _viewProjDirty = false;
    }

    shader.setUniformMatrix4('uViewProj',      _scratchViewProj);
    shader.setUniformMatrix4('uModel',         modelMatrix);
    // mat3(uModel) extracted on CPU — saves per-vertex matrix extraction in GLSL.
    shader.setUniformMatrix3('uNormalMatrix',  modelMatrix.getRotation());

    // Lighting
    shader.setUniformVector3('uLightPos',     lightPosition);
    shader.setUniformVector3('uLightColor',   lightColor);
    shader.setUniformVector3('uAmbientColor', ambientColor);

    if (bufs.vao != null) {
      // VAO path: attrib state was configured at upload time — just bind and draw.
      _bindVAO(bufs.vao);
      // Constant vertex color: not tracked by VAO, must be set per draw call.
      if (bufs.colorBuffer == null) gl.vertexAttrib4f(_colLoc, 1.0, 1.0, 1.0, 1.0);
      gl.drawElements(0x0004, mesh.indices.length, 0x1403, 0); // TRIANGLES, UNSIGNED_SHORT
      _unbindVAO();
    } else {
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
    for (final node in root.renderables) {
      renderWithMatrix(node.mesh!, node.worldMatrix, camera);
    }
  }

  // ── Buffer management ─────────────────────────────────────────────────────

  _MeshBuffers _getOrCreateBuffers(Mesh mesh) {
    if (_meshBuffers.containsKey(mesh)) return _meshBuffers[mesh]!;

    // Upload all buffers before creating VAO (upload unbinds; VAO setup re-binds).
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
