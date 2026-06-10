import 'package:vector_math/vector_math.dart';
import '../rendering/particle_system.dart';

/// Common interface for all ice breath emitter variants.
abstract class IceBreathEmitterBase {
  Vector3 origin;
  Vector3 direction;
  bool   active     = false;
  double chargeTime = 0.0;

  IceBreathEmitterBase({required this.origin, required this.direction});

  double get rangeScale;
  void startBreath();
  void stopBreath();
  void tick(ParticleSystem system, double dt, Vector3 wind);
}
