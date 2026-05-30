import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import 'camera3d.dart';
import 'fire_shaders.dart';
import 'particle_system.dart';
import 'shader_program.dart';

// ── GPU particle system (WebGL 2.0 transform feedback) ───────────────────────

class GpuParticleSystem {
  final dynamic gl;
  final int maxParticles;

  static const int _recordFloats = 13; // pos(3)+vel(3)+age(1)+life(1)+size(1)+color(4)

  late ShaderProgram _simShader;
  late ShaderProgram _drawShader;

  late dynamic _vboA;
  late dynamic _vboB;
  late dynamic _tfo;
  late dynamic _cornersVbo;
  late dynamic _ibo;

  late Float32List _cpuBuffer;
  int _liveCount = 0;
  bool _ready = false;

  late int _simPosLoc, _simVelLoc, _simAgeLoc, _simLifeLoc, _simSizeLoc, _simColorLoc;
  late int _drwPosLoc, _drwColorLoc, _drwSizeLoc, _drwAgeLoc, _drwLifeLoc, _drwCornerLoc;

  final List<Float32List> _pendingInject = [];

  GpuParticleSystem(this.gl, {this.maxParticles = 20000}) {
    try {
      _init();
    } catch (e) {
      debugPrint('[GpuParticleSystem] init failed (WebGL 2.0 required): $e');
    }
  }

  void _init() {
    _simShader = ShaderProgram.fromSourceWithVaryings(
      gl, gpuSimVertShader, 'void main(){}',
      ['outPos', 'outVel', 'outAge', 'outLifetime', 'outSize', 'outColor'],
    );
    _drawShader = ShaderProgram.fromSource(gl, gpuBillboardVertShader, gpuFireFragShader);

    _simPosLoc   = _simShader.getAttribLocation('aPos');
    _simVelLoc   = _simShader.getAttribLocation('aVel');
    _simAgeLoc   = _simShader.getAttribLocation('aAge');
    _simLifeLoc  = _simShader.getAttribLocation('aLifetime');
    _simSizeLoc  = _simShader.getAttribLocation('aSize');
    _simColorLoc = _simShader.getAttribLocation('aColor');

    _drwPosLoc    = _drawShader.getAttribLocation('aPos');
    _drwColorLoc  = _drawShader.getAttribLocation('aColor');
    _drwSizeLoc   = _drawShader.getAttribLocation('aSize');
    _drwAgeLoc    = _drawShader.getAttribLocation('aAge');
    _drwLifeLoc   = _drawShader.getAttribLocation('aLifetime');
    _drwCornerLoc = _drawShader.getAttribLocation('aCorner');

    _cpuBuffer = Float32List(maxParticles * _recordFloats);
    _vboA = _createDynamicBuffer(_cpuBuffer);
    _vboB = _createDynamicBuffer(_cpuBuffer);

    _tfo         = gl.createTransformFeedback();
    _cornersVbo  = _buildCornersBuffer();
    _ibo         = _buildIndexBuffer();

    _ready = true;
    debugPrint('[GpuParticleSystem] ready (max $maxParticles particles)');
  }

  dynamic _createDynamicBuffer(Float32List data) {
    final buf = gl.createBuffer();
    gl.bindBuffer(0x8892, buf);
    gl.bufferData(0x8892, data, 0x88E8);
    gl.bindBuffer(0x8892, null);
    return buf;
  }

  dynamic _buildCornersBuffer() {
    final data = Float32List.fromList([-1, -1, 1, -1, 1, 1, -1, 1]);
    final buf  = gl.createBuffer();
    gl.bindBuffer(0x8892, buf);
    gl.bufferData(0x8892, data, 0x88E4);
    gl.bindBuffer(0x8892, null);
    return buf;
  }

  dynamic _buildIndexBuffer() {
    final indices = Uint16List(maxParticles * 6);
    for (int i = 0; i < maxParticles; i++) {
      final vb = i * 4; final ib = i * 6;
      indices[ib] = vb; indices[ib+1] = vb+1; indices[ib+2] = vb+2;
      indices[ib+3] = vb; indices[ib+4] = vb+2; indices[ib+5] = vb+3;
    }
    final buf = gl.createBuffer();
    gl.bindBuffer(0x8893, buf);
    gl.bufferData(0x8893, indices, 0x88E4);
    gl.bindBuffer(0x8893, null);
    return buf;
  }

  bool get isReady => _ready;

  void inject(List<Particle> particles) {
    for (final p in particles) {
      final col = p.color;
      _pendingInject.add(Float32List.fromList([
        p.position.x, p.position.y, p.position.z,
        p.velocity.x, p.velocity.y, p.velocity.z,
        0.0, p.lifetime, p.size,
        col.r, col.g, col.b, col.a,
      ]));
    }
  }

  void tick(double dt, Vector3 wind, Vector3 playerPos, double time) {
    if (!_ready) return;

    for (final rec in _pendingInject) {
      if (_liveCount >= maxParticles) break;
      final offset = _liveCount * _recordFloats;
      for (int i = 0; i < _recordFloats; i++) _cpuBuffer[offset + i] = rec[i];
      _liveCount++;
    }
    _pendingInject.clear();

    if (_liveCount > 0) {
      gl.bindBuffer(0x8892, _vboA);
      gl.bufferSubData(0x8892, 0, _cpuBuffer);
      gl.bindBuffer(0x8892, null);
    }

    _simShader.use();
    _simShader.setUniformFloat('uDt', dt);
    _simShader.setUniformVector3('uWind', wind);
    _simShader.setUniformFloat('uWindRadius', 40.0);
    _simShader.setUniformVector3('uPlayerPos', playerPos);
    _simShader.setUniformFloat('uBuoyancy', 5.2);
    _simShader.setUniformFloat('uTurbStrength', 0.8);
    _simShader.setUniformFloat('uTime', time);

    gl.enable(0x8C89);
    gl.bindTransformFeedback(0x8E22, _tfo);
    gl.bindBufferBase(0x8C8F, 0, _vboB);
    gl.beginTransformFeedback(0x0000);

    _bindSimAttribs(_vboA);
    gl.drawArrays(0x0000, 0, _liveCount);
    _unbindSimAttribs();

    gl.endTransformFeedback();
    gl.bindTransformFeedback(0x8E22, null);
    gl.disable(0x8C89);

    final tmp = _vboA; _vboA = _vboB; _vboB = tmp;
  }

  void _bindSimAttribs(dynamic vbo) {
    const stride = _recordFloats * 4;
    gl.bindBuffer(0x8892, vbo);
    _enableAttrib(_simPosLoc,   3, stride, 0);
    _enableAttrib(_simVelLoc,   3, stride, 12);
    _enableAttrib(_simAgeLoc,   1, stride, 24);
    _enableAttrib(_simLifeLoc,  1, stride, 28);
    _enableAttrib(_simSizeLoc,  1, stride, 32);
    _enableAttrib(_simColorLoc, 4, stride, 36);
  }

  void _unbindSimAttribs() {
    for (final loc in [_simPosLoc, _simVelLoc, _simAgeLoc,
                        _simLifeLoc, _simSizeLoc, _simColorLoc]) {
      if (loc >= 0) gl.disableVertexAttribArray(loc);
    }
    gl.bindBuffer(0x8892, null);
  }

  void _enableAttrib(int loc, int size, int stride, int offsetBytes) {
    if (loc < 0) return;
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, size, 0x1406, false, stride, offsetBytes);
  }

  void render(Camera3D camera, double time) {
    if (!_ready || _liveCount == 0) return;
    final viewMat  = camera.getViewMatrix();
    final viewProj = camera.getProjectionMatrix()..multiply(viewMat);
    final camRight = Vector3(viewMat[0], viewMat[4], viewMat[8]);
    final camUp    = Vector3(viewMat[1], viewMat[5], viewMat[9]);

    gl.depthMask(false);
    gl.enable(0x0BE2);
    gl.blendFunc(0x0302, 0x0001);

    _drawShader.use();
    _drawShader.setUniformMatrix4('uViewProj',    viewProj);
    _drawShader.setUniformVector3('uCameraRight', camRight);
    _drawShader.setUniformVector3('uCameraUp',    camUp);
    _drawShader.setUniformFloat('uTime', time);

    const pStride = _recordFloats * 4;
    gl.bindBuffer(0x8892, _vboA);
    _enableAttrib(_drwPosLoc,   3, pStride, 0);
    _enableAttrib(_drwAgeLoc,   1, pStride, 24);
    _enableAttrib(_drwLifeLoc,  1, pStride, 28);
    _enableAttrib(_drwSizeLoc,  1, pStride, 32);
    _enableAttrib(_drwColorLoc, 4, pStride, 36);
    gl.vertexAttribDivisor(_drwPosLoc,   1);
    gl.vertexAttribDivisor(_drwAgeLoc,   1);
    gl.vertexAttribDivisor(_drwLifeLoc,  1);
    gl.vertexAttribDivisor(_drwSizeLoc,  1);
    gl.vertexAttribDivisor(_drwColorLoc, 1);

    gl.bindBuffer(0x8892, _cornersVbo);
    _enableAttrib(_drwCornerLoc, 2, 8, 0);
    gl.vertexAttribDivisor(_drwCornerLoc, 0);

    gl.bindBuffer(0x8893, _ibo);
    gl.drawElementsInstanced(0x0004, 6, 0x1403, 0, _liveCount);

    for (final loc in [_drwPosLoc, _drwAgeLoc, _drwLifeLoc,
                        _drwSizeLoc, _drwColorLoc]) {
      if (loc >= 0) { gl.vertexAttribDivisor(loc, 0); gl.disableVertexAttribArray(loc); }
    }
    if (_drwCornerLoc >= 0) gl.disableVertexAttribArray(_drwCornerLoc);
    gl.bindBuffer(0x8892, null);
    gl.bindBuffer(0x8893, null);
    gl.disable(0x0BE2);
    gl.depthMask(true);
  }

  void dispose() {
    if (!_ready) return;
    gl.deleteBuffer(_vboA);
    gl.deleteBuffer(_vboB);
    gl.deleteBuffer(_cornersVbo);
    gl.deleteBuffer(_ibo);
    gl.deleteTransformFeedback(_tfo);
    _simShader.dispose();
    _drawShader.dispose();
  }
}
