import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';
import 'camera3d.dart';
import 'fire_shaders.dart';
import 'shader_program.dart';

// ── Particle data ─────────────────────────────────────────────────────────────

class Particle {
  Vector3 position;
  Vector3 velocity;
  double lifetime;
  double age;
  double size;
  bool isFire;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifetime,
    required this.size,
    required this.isFire,
  }) : age = 0.0;

  bool get isDead => age >= lifetime;
  double get t => (age / lifetime).clamp(0.0, 1.0);

  // Age-driven color: fire = black→red→orange→yellow; smoke = warm-grey→dark-grey.
  Vector4 get color {
    if (isFire) {
      if (t < 0.25) return Vector4(1.0, 0.15 + t * 1.4, 0.0,       1.0 - t * 0.3);
      if (t < 0.55) return Vector4(1.0, 0.5  + t * 0.8, 0.05,      0.85 - t * 0.6);
      return             Vector4(0.9, 0.7,              0.3 + t,   (1.0 - t) * 0.6);
    } else {
      final g = (0.25 + t * 0.15).clamp(0.0, 1.0);
      return Vector4(g, g, g, (1.0 - t) * 0.55);
    }
  }
}

// ── CPU particle system ───────────────────────────────────────────────────────

class ParticleSystem {
  final int maxParticles;
  final List<Particle> _particles = [];
  final math.Random _rng = math.Random();

  // Config knobs (loaded from fire_config.json via FireEmitter)
  double buoyancy        = 5.2;
  double turbulenceStr   = 0.8;
  double windInfluence   = 0.55;
  double windRadius      = 40.0;
  double smokeTransition = 0.6;  // fraction of fire lifetime at which smoke spawns
  double smokeFadeAlt    = 35.0;

  ParticleSystem({this.maxParticles = 5000});

  List<Particle> get particles => _particles;

  void tick(double dt, Vector3 wind, Vector3 playerPos) {
    for (final p in _particles) {
      if (p.isDead) continue;

      // Wind influence attenuated by distance from aircraft
      final dist = (p.position - playerPos).length;
      final wFactor = (1.0 - dist / windRadius).clamp(0.0, 1.0);
      final windForce = wind.scaled(windInfluence * wFactor);

      // Turbulence: lightweight hash noise on XZ position
      final hx = _hash(p.position.x * 3.7 + p.age * 0.8);
      final hz = _hash(p.position.z * 5.1 + p.age * 0.6);
      final turb = Vector3(hx * 2 - 1, 0, hz * 2 - 1)..scale(turbulenceStr);

      // Net vertical force: buoyancy - gravity
      final gravity = -9.8;
      final netUp = p.isFire ? (buoyancy + gravity) : (buoyancy * 0.3 + gravity);
      final accel = Vector3(0, netUp, 0) + windForce + turb;

      p.velocity.add(accel.scaled(dt));
      p.position.add(p.velocity.scaled(dt));
      p.age += dt;

      // Spawn smoke at the top of fire particle lifetime
      if (p.isFire && p.t >= smokeTransition && !p.isDead) {
        _maybeTurnToSmoke(p);
      }
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _maybeTurnToSmoke(Particle p) {
    // Convert this fire particle to smoke in-place (once, at transition)
    if (p.isFire && p.t >= smokeTransition) {
      p.isFire   = false;
      p.lifetime = p.age + _rng.nextDouble() * 3.0 + 3.0;
      p.size    *= 1.6;
      p.velocity.y *= 0.4;
    }
  }

  bool emit(Particle p) {
    if (_particles.length >= maxParticles) return false;
    _particles.add(p);
    return true;
  }

  void emitMany(List<Particle> ps) {
    for (final p in ps) {
      if (!emit(p)) break;
    }
  }

  void clear() => _particles.clear();

  static double _hash(double v) => (math.sin(v * 127.1) * 43758.5453).abs() % 1.0;
}

// ── Particle renderer ─────────────────────────────────────────────────────────
// Handles GPU buffer management and two-pass draw (additive fire, alpha smoke).

class ParticleRenderer {
  final dynamic gl;

  late ShaderProgram _fireShader;
  late ShaderProgram _smokeShader;
  late int _fPosLoc, _fCornerLoc, _fColorLoc, _fSizeLoc;
  late int _sPosLoc, _sCornerLoc, _sColorLoc, _sSizeLoc;

  // Interleaved VBO: [worldPosX,Y,Z, cornerX,Y, r,g,b,a, size] = 10 floats/vertex
  // 4 vertices per particle, index buffer with 6 indices per particle.
  static const int _floatsPerVertex = 10;
  static const int _vertsPerQuad    = 4;
  static const int _indicesPerQuad  = 6;
  static const int _maxQuads        = 8000;

  late dynamic _vbo;
  late dynamic _ibo;
  late Float32List _vboData;

  // Corner offsets for a billboard quad (CCW winding).
  static const List<double> _corners = [-1,-1, 1,-1, 1,1, -1,1];

  ParticleRenderer(this.gl) {
    _fireShader  = ShaderProgram.fromSource(gl, particleVertShader, fireFragShader);
    _smokeShader = ShaderProgram.fromSource(gl, particleVertShader, smokeFragShader);

    _fPosLoc    = _fireShader.getAttribLocation('aWorldPos');
    _fCornerLoc = _fireShader.getAttribLocation('aCorner');
    _fColorLoc  = _fireShader.getAttribLocation('aColor');
    _fSizeLoc   = _fireShader.getAttribLocation('aSize');

    _sPosLoc    = _smokeShader.getAttribLocation('aWorldPos');
    _sCornerLoc = _smokeShader.getAttribLocation('aCorner');
    _sColorLoc  = _smokeShader.getAttribLocation('aColor');
    _sSizeLoc   = _smokeShader.getAttribLocation('aSize');

    _vboData = Float32List(_maxQuads * _vertsPerQuad * _floatsPerVertex);

    _vbo = gl.createBuffer();
    _ibo = _buildIndexBuffer();
    debugPrint('[ParticleRenderer] initialized (max $_maxQuads quads)');
  }

  dynamic _buildIndexBuffer() {
    final indices = Uint16List(_maxQuads * _indicesPerQuad);
    for (int i = 0; i < _maxQuads; i++) {
      final vb = i * _vertsPerQuad;
      final ib = i * _indicesPerQuad;
      indices[ib]   = vb;     indices[ib+1] = vb+1; indices[ib+2] = vb+2;
      indices[ib+3] = vb;     indices[ib+4] = vb+2; indices[ib+5] = vb+3;
    }
    final buf = gl.createBuffer();
    gl.bindBuffer(0x8893, buf);
    gl.bufferData(0x8893, indices, 0x88E4); // STATIC_DRAW
    gl.bindBuffer(0x8893, null);
    return buf;
  }

  void render(List<Particle> particles, Camera3D camera, double time) {
    if (particles.isEmpty) return;

    final viewMat = camera.getViewMatrix();
    // Extract camera right (column 0) and up (column 1) from view matrix.
    final camRight = Vector3(viewMat[0], viewMat[4], viewMat[8]);
    final camUp    = Vector3(viewMat[1], viewMat[5], viewMat[9]);

    final viewProj = camera.getProjectionMatrix()..multiply(camera.getViewMatrix());

    // Depth-sort: fire first (additive is order-independent), smoke after (alpha-sorted).
    final fire  = particles.where((p) => p.isFire).toList();
    final smoke = particles.where((p) => !p.isFire).toList();
    // Sort smoke back-to-front for correct alpha blending.
    final camPos = Vector3(viewMat[12], viewMat[13], viewMat[14]);
    smoke.sort((a, b) {
      final da = (a.position - camPos).length2;
      final db = (b.position - camPos).length2;
      return db.compareTo(da);
    });

    gl.depthMask(false);

    // ── Fire pass: additive blending ─────────────────────────────────────────
    gl.enable(0x0BE2);               // BLEND
    gl.blendFunc(0x0302, 0x0001);    // SRC_ALPHA, ONE
    _drawBatch(fire, _fireShader, _fPosLoc, _fCornerLoc, _fColorLoc, _fSizeLoc,
        viewProj, camRight, camUp, time);

    // ── Smoke pass: standard alpha blending ──────────────────────────────────
    gl.blendFunc(0x0302, 0x0303);    // SRC_ALPHA, ONE_MINUS_SRC_ALPHA
    _drawBatch(smoke, _smokeShader, _sPosLoc, _sCornerLoc, _sColorLoc, _sSizeLoc,
        viewProj, camRight, camUp, time);

    gl.disable(0x0BE2);
    gl.depthMask(true);
  }

  void _drawBatch(
    List<Particle> batch,
    ShaderProgram shader,
    int posLoc, int cornerLoc, int colorLoc, int sizeLoc,
    Matrix4 viewProj, Vector3 camRight, Vector3 camUp,
    double time,
  ) {
    if (batch.isEmpty) return;

    int quadCount = 0;
    final limit = math.min(batch.length, _maxQuads);

    for (int qi = 0; qi < limit; qi++) {
      final p   = batch[qi];
      final col = p.color;
      final base = qi * _vertsPerQuad * _floatsPerVertex;

      for (int vi = 0; vi < _vertsPerQuad; vi++) {
        final offset = base + vi * _floatsPerVertex;
        _vboData[offset]   = p.position.x;
        _vboData[offset+1] = p.position.y;
        _vboData[offset+2] = p.position.z;
        _vboData[offset+3] = _corners[vi * 2];
        _vboData[offset+4] = _corners[vi * 2 + 1];
        _vboData[offset+5] = col.r;
        _vboData[offset+6] = col.g;
        _vboData[offset+7] = col.b;
        _vboData[offset+8] = col.a;
        _vboData[offset+9] = p.size;
      }
      quadCount++;
    }

    gl.bindBuffer(0x8892, _vbo);
    gl.bufferData(0x8892, _vboData, 0x88E8); // DYNAMIC_DRAW

    shader.use();
    shader.setUniformMatrix4('uViewProj', viewProj);
    shader.setUniformVector3('uCameraRight', camRight);
    shader.setUniformVector3('uCameraUp',    camUp);
    shader.setUniformFloat('uTime', time);

    const int stride = _floatsPerVertex * 4; // bytes
    if (posLoc >= 0) {
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(posLoc, 3, 0x1406, false, stride, 0);
    }
    if (cornerLoc >= 0) {
      gl.enableVertexAttribArray(cornerLoc);
      gl.vertexAttribPointer(cornerLoc, 2, 0x1406, false, stride, 12);
    }
    if (colorLoc >= 0) {
      gl.enableVertexAttribArray(colorLoc);
      gl.vertexAttribPointer(colorLoc, 4, 0x1406, false, stride, 20);
    }
    if (sizeLoc >= 0) {
      gl.enableVertexAttribArray(sizeLoc);
      gl.vertexAttribPointer(sizeLoc, 1, 0x1406, false, stride, 36);
    }

    gl.bindBuffer(0x8893, _ibo);
    gl.drawElements(0x0004, quadCount * _indicesPerQuad, 0x1403, 0);

    if (posLoc    >= 0) gl.disableVertexAttribArray(posLoc);
    if (cornerLoc >= 0) gl.disableVertexAttribArray(cornerLoc);
    if (colorLoc  >= 0) gl.disableVertexAttribArray(colorLoc);
    if (sizeLoc   >= 0) gl.disableVertexAttribArray(sizeLoc);

    gl.bindBuffer(0x8892, null);
    gl.bindBuffer(0x8893, null);
  }

  void dispose() {
    gl.deleteBuffer(_vbo);
    gl.deleteBuffer(_ibo);
    _fireShader.dispose();
    _smokeShader.dispose();
  }
}

// ── GPU particle system (WebGL 2.0 transform feedback) ───────────────────────

class GpuParticleSystem {
  final dynamic gl;
  final int maxParticles;

  static const int _recordFloats = 13; // pos(3)+vel(3)+age(1)+life(1)+size(1)+color(4)

  late ShaderProgram _simShader;
  late ShaderProgram _drawShader;

  late dynamic _vboA;          // current frame
  late dynamic _vboB;          // next frame
  late dynamic _tfo;           // transform feedback object
  late dynamic _cornersVbo;
  late dynamic _ibo;

  late Float32List _cpuBuffer; // for initial uploads and new-particle injection
  int _liveCount = 0;
  bool _ready = false;

  // Attrib locations on the simulation shader
  late int _simPosLoc, _simVelLoc, _simAgeLoc, _simLifeLoc, _simSizeLoc, _simColorLoc;
  // Attrib locations on the draw shader
  late int _drwPosLoc, _drwColorLoc, _drwSizeLoc, _drwAgeLoc, _drwLifeLoc, _drwCornerLoc;

  // Pending particle records to inject next tick
  final List<Float32List> _pendingInject = [];

  GpuParticleSystem(this.gl, {this.maxParticles = 20000}) {
    try {
      _init();
    } catch (e) {
      debugPrint('[GpuParticleSystem] init failed (WebGL 2.0 required): $e');
    }
  }

  void _init() {
    _simShader  = ShaderProgram.fromSourceWithVaryings(
      gl, gpuSimVertShader, 'void main(){}',
      ['outPos','outVel','outAge','outLifetime','outSize','outColor'],
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

    _tfo = gl.createTransformFeedback();

    _cornersVbo = _buildCornersBuffer();
    _ibo        = _buildIndexBuffer();

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
    final data = Float32List.fromList([-1,-1, 1,-1, 1,1, -1,1]);
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
      indices[ib]=vb; indices[ib+1]=vb+1; indices[ib+2]=vb+2;
      indices[ib+3]=vb; indices[ib+4]=vb+2; indices[ib+5]=vb+3;
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

    // Flush pending injections into the CPU buffer
    for (final rec in _pendingInject) {
      if (_liveCount >= maxParticles) break;
      final offset = _liveCount * _recordFloats;
      for (int i = 0; i < _recordFloats; i++) _cpuBuffer[offset + i] = rec[i];
      _liveCount++;
    }
    _pendingInject.clear();

    if (_pendingInject.isEmpty && _liveCount > 0) {
      gl.bindBuffer(0x8892, _vboA);
      gl.bufferSubData(0x8892, 0, _cpuBuffer);
      gl.bindBuffer(0x8892, null);
    }

    // GPU simulation pass (transform feedback)
    _simShader.use();
    _simShader.setUniformFloat('uDt', dt);
    _simShader.setUniformVector3('uWind', wind);
    _simShader.setUniformFloat('uWindRadius', 40.0);
    _simShader.setUniformVector3('uPlayerPos', playerPos);
    _simShader.setUniformFloat('uBuoyancy', 5.2);
    _simShader.setUniformFloat('uTurbStrength', 0.8);
    _simShader.setUniformFloat('uTime', time);

    gl.enable(0x8C89);   // RASTERIZER_DISCARD
    gl.bindTransformFeedback(0x8E22, _tfo);
    gl.bindBufferBase(0x8C8F, 0, _vboB); // TRANSFORM_FEEDBACK_BUFFER
    gl.beginTransformFeedback(0x0000);   // POINTS

    _bindSimAttribs(_vboA);
    gl.drawArrays(0x0000, 0, _liveCount);
    _unbindSimAttribs();

    gl.endTransformFeedback();
    gl.bindTransformFeedback(0x8E22, null);
    gl.disable(0x8C89);

    // Ping-pong
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
    for (final loc in [_simPosLoc, _simVelLoc, _simAgeLoc, _simLifeLoc, _simSizeLoc, _simColorLoc]) {
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
    // Rendering uses the current VBO A (after ping-pong swap it holds fresh data).
    final viewMat  = camera.getViewMatrix();
    final viewProj = camera.getProjectionMatrix()..multiply(viewMat);
    final camRight = Vector3(viewMat[0], viewMat[4], viewMat[8]);
    final camUp    = Vector3(viewMat[1], viewMat[5], viewMat[9]);

    gl.depthMask(false);
    gl.enable(0x0BE2);
    gl.blendFunc(0x0302, 0x0001);

    _drawShader.use();
    _drawShader.setUniformMatrix4('uViewProj', viewProj);
    _drawShader.setUniformVector3('uCameraRight', camRight);
    _drawShader.setUniformVector3('uCameraUp',    camUp);
    _drawShader.setUniformFloat('uTime', time);

    // Per-instance: particle state from VBO A (one record per particle)
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

    // Per-vertex: 4 billboard corners
    gl.bindBuffer(0x8892, _cornersVbo);
    _enableAttrib(_drwCornerLoc, 2, 8, 0);
    gl.vertexAttribDivisor(_drwCornerLoc, 0);

    gl.bindBuffer(0x8893, _ibo);
    gl.drawElementsInstanced(0x0004, 6, 0x1403, 0, _liveCount);

    // Reset divisors
    for (final loc in [_drwPosLoc, _drwAgeLoc, _drwLifeLoc, _drwSizeLoc, _drwColorLoc]) {
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
