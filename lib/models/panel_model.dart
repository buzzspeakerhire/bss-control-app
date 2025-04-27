import 'control_model.dart';
import 'state_variable_model.dart';

class Panel {
  String id;
  String name;
  int width;
  int height;
  int backgroundColor;
  int foregroundColor;
  List<StateVariable> stateVariables;
  List<Control> controls;

  Panel({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.stateVariables,
    required this.controls,
  });

  /// Convert the panel to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'width': width,
      'height': height,
      'backgroundColor': backgroundColor,
      'foregroundColor': foregroundColor,
      'stateVariables': stateVariables.map((sv) => sv.toMap()).toList(),
      'controls': controls.map((c) => c.toMap()).toList(),
    };
  }

  /// Create a panel from a map
  factory Panel.fromMap(Map<String, dynamic> map) {
    return Panel(
      id: map['id'] as String,
      name: map['name'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      backgroundColor: map['backgroundColor'] as int,
      foregroundColor: map['foregroundColor'] as int,
      stateVariables: (map['stateVariables'] as List)
          .map((sv) => StateVariable.fromMap(sv as Map<String, dynamic>))
          .toList(),
      controls: (map['controls'] as List)
          .map((c) => Control.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'Panel(id: $id, name: $name, width: $width, height: $height, '
        'stateVariables: ${stateVariables.length}, controls: ${controls.length})';
  }
}