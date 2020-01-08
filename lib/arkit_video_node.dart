import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/light/arkit_light.dart';
import 'package:arkit_plugin/physics/arkit_physics_body.dart';
import 'package:arkit_plugin/utils/vector_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:arkit_plugin/geometries/arkit_geometry.dart';

class ARKitVideoNode extends ARKitNode {
  ARKitVideoNode({
    @required this.localPath,
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
    bool isLoop,
    bool isPlay,
  })  : isLoop =
            (isLoop == null) ? ValueNotifier(false) : ValueNotifier(isLoop),
        isPlay =
            (isPlay == null) ? ValueNotifier(false) : ValueNotifier(isPlay),
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

  /// Node localPath at bundle.
  final String localPath;

  final ValueNotifier<bool> isPlay;
  final ValueNotifier<bool> isLoop;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'geometry': geometry,
        'localPath': localPath,
        'position': convertVector3ToMap(position.value),
        'scale': convertVector3ToMap(scale.value),
        'eulerAngles': convertVector3ToMap(eulerAngles.value),
        'rotation': convertVector4ToMap(rotation.value),
        'isHidden': isHidden.value,
        'isPlay': isPlay.value,
        'isLoop': isLoop.value,
      }
        ..addAll(super.toMap())
        ..removeWhere((String k, dynamic v) => v == null);
}
