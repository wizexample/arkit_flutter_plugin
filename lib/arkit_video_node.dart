import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/geometries/arkit_geometry.dart';
import 'package:arkit_plugin/light/arkit_light.dart';
import 'package:arkit_plugin/physics/arkit_physics_body.dart';
import 'package:arkit_plugin/utils/update_notifier.dart';
import 'package:arkit_plugin/utils/vector_utils.dart';
import 'package:vector_math/vector_math_64.dart';

class ARKitVideoNode extends ARKitNode {
  ARKitVideoNode({
    ARKitGeometry geometry,
    ARKitPhysicsBody physicsBody,
    ARKitLight light,
    Vector3 position,
    Vector3 scale,
    Vector3 eulerAngles,
    Vector4 rotation,
    String name,
    int renderingOrder,
    bool isHidden,
    bool isPlay,
    this.centralizeOnLostTarget = false,
    this.marginPercent = 5.0,
    this.durationMilliSec = 150.0,
  })  : isPlay = UpdateNotifier(isPlay),
        super(
          geometry: geometry,
          physicsBody: physicsBody,
          light: light,
          position: position,
          scale: scale,
          eulerAngles: eulerAngles,
          rotation: rotation,
          name: name,
          renderingOrder: renderingOrder,
          isHidden: isHidden,
        );

  final bool centralizeOnLostTarget;
  final double marginPercent;
  final double durationMilliSec;

  final UpdateNotifier<bool> isPlay;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'geometry': geometry,
        'position': convertVector3ToMap(position.value),
        'scale': convertVector3ToMap(scale.value),
        'eulerAngles': convertVector3ToMap(eulerAngles.value),
        'rotation': convertVector4ToMap(rotation.value),
        'isHidden': isHidden.value,
        'isPlay': isPlay.value,
        'centralizeOnLostTarget': centralizeOnLostTarget,
        'marginPercent': marginPercent,
        'durationMilliSec': durationMilliSec,
      }
        ..addAll(super.toMap())
        ..removeWhere((String k, dynamic v) => v == null);
}
