import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/light/arkit_light.dart';
import 'package:arkit_plugin/physics/arkit_physics_body.dart';
import 'package:arkit_plugin/utils/vector_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

///  Node that references an external serialized node graph.
class ARKitObjectNode extends ARKitNode {
  ARKitObjectNode({
    @required this.localPath,
    ARKitPhysicsBody physicsBody,
    ARKitLight light,
    Vector3 position,
    Vector3 scale,
    Vector3 eulerAngles,
    String name,
    int renderingOrder,
  }) : super(
          physicsBody: physicsBody,
          light: light,
          position: position,
          scale: scale,
          eulerAngles: eulerAngles,
          name: name,
          renderingOrder: renderingOrder,
        );

  /// Node localPath at bundle.
  final String localPath;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'localPath': localPath,
        'position': convertVector3ToMap(position.value),
        'scale': convertVector3ToMap(scale.value),
        'eulerAngles': convertVector3ToMap(eulerAngles.value),
      }..addAll(super.toMap());
}
