class Venue {
  String name;
  String ipAddress;
  int port;
  bool useTcp; // TCP or UDP
  bool needsWifi;
  Map<String, String> commands; // Map of command names to hex strings
  Map<String, String> customData; // For storing additional data like panel configuration

  Venue({
    required this.name,
    required this.ipAddress,
    required this.port,
    this.useTcp = true,
    this.needsWifi = false,
    Map<String, String>? commands,
    Map<String, String>? customData,
  }) : commands = commands ?? {},
       customData = customData ?? {};

  // Create a Venue from JSON (for saving/loading venues)
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      name: json['name'],
      ipAddress: json['ipAddress'],
      port: json['port'],
      useTcp: json['useTcp'] ?? true,
      needsWifi: json['needsWifi'] ?? false,
      commands: Map<String, String>.from(json['commands'] ?? {}),
      customData: Map<String, String>.from(json['customData'] ?? {}),
    );
  }

  // Convert Venue to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'useTcp': useTcp,
      'needsWifi': needsWifi,
      'commands': commands,
      'customData': customData,
    };
  }

  // Add a new command or update an existing one
  void addCommand(String name, String hexCommand) {
    commands[name] = hexCommand;
  }

  // Remove a command
  void removeCommand(String name) {
    commands.remove(name);
  }
}