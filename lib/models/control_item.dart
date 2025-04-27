enum ControlType {
  fader,
  meter,
  selector,
  button,
  indicator,
  unknown
}

class ControlItem {
  final String name;
  final String displayName;
  final ControlType type;
  final List<Map<String, dynamic>> stateVariables;
  final List<Map<String, dynamic>>? options; // For selectors/combo boxes
  final Map<String, dynamic> properties; // Additional control properties

  ControlItem({
    required this.name,
    required this.displayName,
    required this.type,
    required this.stateVariables,
    this.options,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {};

  // Create from JSON (for restoring saved panels)
  factory ControlItem.fromJson(Map<String, dynamic> json) {
    return ControlItem(
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      type: ControlType.values.firstWhere(
        (e) => e.toString() == 'ControlType.${json['type']}',
        orElse: () => ControlType.unknown,
      ),
      stateVariables: List<Map<String, dynamic>>.from(
        (json['stateVariables'] as List).map(
          (x) => Map<String, dynamic>.from(x as Map),
        ),
      ),
      options: json['options'] != null
          ? List<Map<String, dynamic>>.from(
              (json['options'] as List).map(
                (x) => Map<String, dynamic>.from(x as Map),
              ),
            )
          : null,
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : {},
    );
  }

  // Convert to JSON (for saving panels)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'type': type.toString().split('.').last,
      'stateVariables': stateVariables,
      'options': options,
      'properties': properties,
    };
  }
}