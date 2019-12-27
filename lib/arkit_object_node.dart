import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/light/arkit_light.dart';
import 'package:arkit_plugin/physics/arkit_physics_body.dart';
import 'package:arkit_plugin/utils/vector_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

///  Node that references an external serialized node graph.
class ARKitObjectNode {
  ARKitObjectNode({
    @required this.localPath,
    this.renderingOrder = 0,
    Vector3 position,
    Vector3 scale,
    Vector4 rotation,
    Vector3 eulerAngles,
    bool isHidden,
  }) : isHidden = (isHidden == null) ? ValueNotifier(false) : ValueNotifier(isHidden),
        position = ValueNotifier(position),
        scale = ValueNotifier(scale),
        rotation = ValueNotifier(rotation),
        eulerAngles = ValueNotifier(eulerAngles);
        

  /// Node localPath at bundle.
  final String localPath;

  final int renderingOrder;

  final ValueNotifier<Vector3> position;

  final ValueNotifier<Vector3> scale;

  final ValueNotifier<Vector4> rotation;

  final ValueNotifier<Vector3> eulerAngles;

  final ValueNotifier<bool> isHidden;



  Map<String, dynamic> toMap() => <String, dynamic>{
        'localPath': localPath,
        'position': convertVector3ToMap(position.value),
        'scale': convertVector3ToMap(scale.value),
        'eulerAngles': convertVector3ToMap(eulerAngles.value),
        'isHidden': isHidden.value
      }..removeWhere((String k, dynamic v) => v == null);
}
