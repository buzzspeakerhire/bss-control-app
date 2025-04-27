import 'state_variable_model.dart';

class Control {
  String id;
  String name;
  String type;
  int x;
  int y;
  int width;
  int height;
  int zOrder;
  StateVariable? stateVariable;
  Map<String, dynamic> properties;

  Control({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zOrder,
    this.stateVariable,
    required this.properties,
  });

  /// Convert the control to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'zOrder': zOrder,
      'stateVariable': stateVariable?.toMap(),
      'properties': properties,
    };
  }

  /// Create a control from a map
  factory Control.fromMap(Map<String, dynamic> map) {
    return Control(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      x: map['x'] as int,
      y: map['y'] as int,
      width: map['width'] as int,
      height: map['height'] as int,
      zOrder: map['zOrder'] as int,
      stateVariable: map['stateVariable'] != null
          ? StateVariable.fromMap(map['stateVariable'] as Map<String, dynamic>)
          : null,
      properties: Map<String, dynamic>.from(map['properties'] as Map),
    );
  }

  @override
  String toString() {
    return 'Control(id: $id, name: $name, type: $type, '
        'x: $x, y: $y, width: $width, height: $height)';
  }
}