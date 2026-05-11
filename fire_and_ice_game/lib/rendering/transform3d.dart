import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

/// Transform3d - Represents position, rotation, and scale in 3D space.
///
/// Foundation for all 3D objects (player, camera, terrain, effects).
/// Rotation is stored as Euler angles (pitch, yaw, roll) in degrees
/// and converted to a 4x4 matrix for GPU upload.
///
/// Coordinate system:
/// - +X is right
/// - +Y is up
/// - -Z is forward (into the screen)
///
/// Usage:
/// ```dart
/// final t = Transform3d(
///   position: Vector3(0, 15, 0),
///   rotation: Vector3(10, 45, -30), // pitch, yaw, roll
/// );
/// shader.setUniformMatrix4('uModel', t.toMatrix());
/// ```
class Transform3d {
  /// World-space position (x, y, z)
  Vector3 position;

  /// Euler rotation in degrees: x=pitch, y=yaw, z=roll
  Vector3 rotation;

  /// Non-uniform scale
  Vector3 scale;

  Transform3d({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
  })  : position = position ?? Vector3.zero(),
        rotation = rotation ?? Vector3.zero(),
        scale = scale ?? Vector3(1, 1, 1);

  /// Build a 4x4 model matrix: Translate * RotateY * RotateX * RotateZ * Scale.
  ///
  /// Rotation order (Y → X → Z) produces standard aircraft-style Euler angles:
  /// yaw around world-up, pitch around local right, roll around local forward.
  Matrix4 toMatrix() {
    final matrix = Matrix4.identity();

    matrix.translateByVector3(position);

    final yawRad   = radians(rotation.y);
    final pitchRad = radians(rotation.x);
    final rollRad  = radians(rotation.z);

    matrix.rotateY(yawRad);
    matrix.rotateX(pitchRad);
    matrix.rotateZ(rollRad);

    matrix.scaleByVector3(scale);

    return matrix;
  }

  /// Forward direction vector computed from yaw and pitch.
  ///
  /// In our coordinate system forward is -Z (same as OpenGL default).
  Vector3 get forward {
    final yawRad   = radians(rotation.y);
    final pitchRad = radians(rotation.x);

    return Vector3(
      -math.sin(yawRad) * math.cos(pitchRad),
       math.sin(pitchRad),
      -math.cos(yawRad) * math.cos(pitchRad),
    ).normalized();
  }

  /// Right direction vector computed from yaw only.
  Vector3 get right {
    final yawRad = radians(rotation.y);
    return Vector3(
       math.cos(yawRad),
       0,
      -math.sin(yawRad),
    ).normalized();
  }

  /// Up direction vector (cross product of forward and right).
  Vector3 get up => forward.cross(right).normalized();

  /// Move position by a delta vector.
  void translate(Vector3 delta) {
    position += delta;
  }

  /// Add delta rotation angles (degrees). Keeps angles in [-360, 360].
  void rotate(Vector3 deltaRotation) {
    rotation += deltaRotation;
    rotation.x = rotation.x % 360;
    rotation.y = rotation.y % 360;
    rotation.z = rotation.z % 360;
  }

  /// Deep copy of this transform.
  Transform3d clone() {
    return Transform3d(
      position: Vector3.copy(position),
      rotation: Vector3.copy(rotation),
      scale:    Vector3.copy(scale),
    );
  }

  /// Linear interpolation toward another transform.
  ///
  /// t=0 returns this, t=1 returns [other].
  Transform3d lerp(Transform3d other, double t) {
    return Transform3d(
      position: position * (1 - t) + other.position * t,
      rotation: rotation * (1 - t) + other.rotation * t,
      scale:    scale    * (1 - t) + other.scale    * t,
    );
  }

  @override
  String toString() =>
      'Transform3d(pos: $position, rot: $rotation, scale: $scale)';
}
