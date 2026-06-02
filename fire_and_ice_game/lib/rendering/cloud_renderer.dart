import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import '../terrain/cloud_system.dart';
import 'camera3d.dart';
import 'fire_shaders.dart';
import 'shader_program.dart';

/// Renders [CloudChunk] billboard quads for all cloud types.
///
/// VBO layout — 11 floats/vertex, stride = 44 bytes:
///   aWorldPos(3)  aCorner(2)  aColor(4)  aSize(1)  aRotation(1)
///   byte off: 0       12         20         36          40
///
/// Chunks are sorted back-to-front by camera distance before upload so that
/// translucent quads blend correctly without depth writes.
class CloudRenderer {
  final dynamic gl;

  ShaderProgram? _shader;
  dynamic _vbo, _ibo;
  Float32List _vboData = Float32List(0);
  bool _ready = false;

  static const int _floatsPerVertex = 11;
  static const int _vertsPerQuad    = 4;
  static const int _indicesPerQuad  = 6;
  static const int _maxQuads        = 1200;

  late int _posLoc, _cornerLoc, _colorLoc, _sizeLoc, _rotLoc;

  static const List<double> _corners = [-1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0];

  bool get isReady => _ready;

  CloudRenderer(this.gl) {
    try { _init(); }
    catch (e) { debugPrint('[CloudRenderer] init failed: $e'); }
  }

  void _init() {
    _shader = ShaderProgram.fromSource(gl, cloudVertSrc, cloudFragSrc);
    _posLoc    = _shader!.getAttribLocation('aWorldPos');
    _cornerLoc = _shader!.getAttribLocation('aCorner');
    _colorLoc  = _shader!.getAttribLocation('aColor');
    _sizeLoc   = _shader!.getAttribLocation('aSize');
    _rotLoc    = _shader!.getAttribLocation('aRotation');

    _vboData = Float32List(_maxQuads * _vertsPerQuad * _floatsPerVertex);
    _vbo     = gl.createBuffer();
    _ibo     = _buildIndexBuffer();
    _ready   = true;
    debugPrint('[CloudRenderer] ready (max $_maxQuads quads)');
  }

  dynamic _buildIndexBuffer() {
    final idx = Uint16List(_maxQuads * _indicesPerQuad);
    for (int i = 0; i < _maxQuads; i++) {
      final vb = i * 4, ib = i * 6;
      idx[ib] = vb; idx[ib+1] = vb+1; idx[ib+2] = vb+2;
      idx[ib+3] = vb; idx[ib+4] = vb+2; idx[ib+5] = vb+3;
    }
    final buf = gl.createBuffer();
    gl.bindBuffer(0x8893, buf);
    gl.bufferData(0x8893, idx, 0x88E4);
    gl.bindBuffer(0x8893, null);
    return buf;
  }

  void render(List<CloudChunk> chunks, Camera3D camera, double time) {
    final s = _shader;
    if (!_ready || s == null || chunks.isEmpty) return;

    final viewMat  = camera.getViewMatrix();
    final viewProj = Matrix4.copy(camera.getProjectionMatrix())..multiply(viewMat);
    final camRight = Vector3(viewMat[0], viewMat[4], viewMat[8]);
    final camUp    = Vector3(viewMat[1], viewMat[5], viewMat[9]);
    final camPos   = camera.position;

    // Collect all billboard world positions (chunk.center + billboard.offset),
    // sorted back-to-front for correct alpha blending.
    final all = <_CloudQuad>[];
    for (final chunk in chunks) {
      for (final b in chunk.quads) {
        final wp = chunk.center + b.offset;
        all.add(_CloudQuad(wp, b.color, b.size, b.opacity, b.rotation));
      }
    }
    all.sort((a, b) {
      final da = (a.pos - camPos).length2;
      final db = (b.pos - camPos).length2;
      return db.compareTo(da);
    });

    final count = all.length.clamp(0, _maxQuads);
    const stride = _floatsPerVertex;

    for (int i = 0; i < count; i++) {
      final q  = all[i];
      final vi = i * _vertsPerQuad * stride;
      for (int v = 0; v < _vertsPerQuad; v++) {
        final base = vi + v * stride;
        _vboData[base]     = q.pos.x;
        _vboData[base + 1] = q.pos.y;
        _vboData[base + 2] = q.pos.z;
        _vboData[base + 3] = _corners[v * 2];
        _vboData[base + 4] = _corners[v * 2 + 1];
        _vboData[base + 5] = q.color.x;
        _vboData[base + 6] = q.color.y;
        _vboData[base + 7] = q.color.z;
        _vboData[base + 8] = q.opacity;
        _vboData[base + 9] = q.size;
        _vboData[base + 10] = q.rotation;
      }
    }

    gl.bindBuffer(0x8892, _vbo);
    gl.bufferData(0x8892,
        Float32List.view(_vboData.buffer, 0, count * _vertsPerQuad * stride),
        0x88E8);
    gl.bindBuffer(0x8892, null);

    gl.depthMask(false);
    gl.enable(0x0BE2);
    gl.blendFunc(0x0302, 0x0303);

    s.use();
    s.setUniformMatrix4('uViewProj',    viewProj);
    s.setUniformVector3('uCameraRight', camRight);
    s.setUniformVector3('uCameraUp',    camUp);
    s.setUniformFloat('uTime', time);

    const byteStride = stride * 4;
    gl.bindBuffer(0x8892, _vbo);
    _enable(_posLoc,    3, byteStride,  0);
    _enable(_cornerLoc, 2, byteStride, 12);
    _enable(_colorLoc,  4, byteStride, 20);
    _enable(_sizeLoc,   1, byteStride, 36);
    _enable(_rotLoc,    1, byteStride, 40);

    gl.bindBuffer(0x8893, _ibo);
    gl.drawElements(0x0004, count * _indicesPerQuad, 0x1403, 0);

    for (final loc in [_posLoc, _cornerLoc, _colorLoc, _sizeLoc, _rotLoc]) {
      if (loc >= 0) gl.disableVertexAttribArray(loc);
    }
    gl.bindBuffer(0x8892, null);
    gl.bindBuffer(0x8893, null);
    gl.disable(0x0BE2);
    gl.depthMask(true);
  }

  void _enable(int loc, int size, int stride, int offset) {
    if (loc < 0) return;
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, size, 0x1406, false, stride, offset);
  }

  void dispose() {
    if (!_ready) return;
    _shader?.dispose();
    gl.deleteBuffer(_vbo);
    gl.deleteBuffer(_ibo);
    _ready = false;
    debugPrint('[CloudRenderer] disposed');
  }
}

class _CloudQuad {
  final Vector3 pos;
  final Vector3 color;
  final double  size, opacity, rotation;
  _CloudQuad(this.pos, this.color, this.size, this.opacity, this.rotation);
}
