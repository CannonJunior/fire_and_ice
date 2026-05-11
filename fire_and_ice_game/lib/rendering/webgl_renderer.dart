import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import 'camera3d.dart';
import 'mesh.dart';
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
    debugPrint('[WebGLRenderer] initialized');
  }

  // ── Frame operations ─────────────────────────────────────────────────────

  /// Clear colour and depth buffers. Call at the start of each frame.
  void clear() {
    // COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT
    gl.clear(0x00004000 | 0x00000100);
  }

  /// Draw [mesh] at world-space [transform] as seen by [camera].
  ///
  /// Uploads geometry on first call for this mesh; subsequent calls use
  /// the cached GPU buffers for O(1) draw setup.
  void render(Mesh mesh, Transform3d transform, Camera3D camera) {
    final bufs = _getOrCreateBuffers(mesh);

    shader.use();

    // MVP matrices
    shader.setUniformMatrix4('uProjection', camera.getProjectionMatrix());
    shader.setUniformMatrix4('uView',       camera.getViewMatrix());
    shader.setUniformMatrix4('uModel',      transform.toMatrix());

    // Lighting
    shader.setUniformVector3('uLightPos',     lightPosition);
    shader.setUniformVector3('uLightColor',   lightColor);
    shader.setUniformVector3('uAmbientColor', ambientColor);

    // Bind position attribute
    final posLoc = shader.getAttribLocation('aPosition');
    if (posLoc >= 0) {
      gl.bindBuffer(0x8892, bufs.vertexBuffer); // ARRAY_BUFFER
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(posLoc, 3, 0x1406, false, 0, 0); // FLOAT
    }

    // Bind normal attribute
    final normLoc = shader.getAttribLocation('aNormal');
    if (normLoc >= 0 && bufs.normalBuffer != null) {
      gl.bindBuffer(0x8892, bufs.normalBuffer);
      gl.enableVertexAttribArray(normLoc);
      gl.vertexAttribPointer(normLoc, 3, 0x1406, false, 0, 0);
    }

    // Bind color attribute
    final colLoc = shader.getAttribLocation('aColor');
    if (colLoc >= 0) {
      if (bufs.colorBuffer != null) {
        gl.bindBuffer(0x8892, bufs.colorBuffer);
        gl.enableVertexAttribArray(colLoc);
        gl.vertexAttribPointer(colLoc, 4, 0x1406, false, 0, 0);
      } else {
        // Default white if no per-vertex color supplied
        gl.disableVertexAttribArray(colLoc);
        gl.vertexAttrib4f(colLoc, 1.0, 1.0, 1.0, 1.0);
      }
    }

    // Draw
    gl.bindBuffer(0x8893, bufs.indexBuffer); // ELEMENT_ARRAY_BUFFER
    gl.drawElements(0x0004, mesh.indices.length, 0x1403, 0); // TRIANGLES, UNSIGNED_SHORT

    // Cleanup attribute state
    if (posLoc  >= 0) gl.disableVertexAttribArray(posLoc);
    if (normLoc >= 0) gl.disableVertexAttribArray(normLoc);
    if (colLoc  >= 0) gl.disableVertexAttribArray(colLoc);
  }

  // ── Buffer management ─────────────────────────────────────────────────────

  _MeshBuffers _getOrCreateBuffers(Mesh mesh) {
    if (_meshBuffers.containsKey(mesh)) return _meshBuffers[mesh]!;

    final bufs = _MeshBuffers(
      vertexBuffer: _upload(0x8892, mesh.vertices),  // ARRAY_BUFFER
      indexBuffer:  _upload(0x8893, mesh.indices),   // ELEMENT_ARRAY_BUFFER
      normalBuffer: mesh.normals != null
          ? _upload(0x8892, mesh.normals!)
          : null,
      colorBuffer: mesh.colors != null
          ? _upload(0x8892, mesh.colors!)
          : null,
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

  const _MeshBuffers({
    required this.vertexBuffer,
    required this.indexBuffer,
    this.normalBuffer,
    this.colorBuffer,
  });
}
