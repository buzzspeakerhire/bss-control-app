class StateVariable {
  String id;
  String name;
  String type;
  int deviceIndex;
  int objectIndex;
  int channel;
  dynamic value;

  StateVariable({
    required this.id,
    required this.name,
    required this.type,
    this.deviceIndex = -1,
    this.objectIndex = -1,
    this.channel = -1,
    this.value,
  });

  /// Convert the state variable to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'deviceIndex': deviceIndex,
      'objectIndex': objectIndex,
      'channel': channel,
      'value': value,
    };
  }

  /// Create a state variable from a map
  factory StateVariable.fromMap(Map<String, dynamic> map) {
    return StateVariable(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      deviceIndex: map['deviceIndex'] as int,
      objectIndex: map['objectIndex'] as int,
      channel: map['channel'] as int,
      value: map['value'],
    );
  }

  @override
  String toString() {
    return 'StateVariable(id: $id, name: $name, type: $type, '
        'deviceIndex: $deviceIndex, objectIndex: $objectIndex, channel: $channel, value: $value)';
  }
}