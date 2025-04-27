import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:logging/logging.dart';
import '../models/state_variable_model.dart';

/// Service for communicating with BSS devices using the London Direct Inject protocol
class DeviceCommunicationService {
  // Create logger for this service
  final _log = Logger('DeviceCommunicationService');
  
  // Singleton instance
  static final DeviceCommunicationService _instance = DeviceCommunicationService._internal();
  
  factory DeviceCommunicationService() {
    return _instance;
  }
  
  DeviceCommunicationService._internal() {
    // Initialize logger
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  }
  
  // Protocol constants
  // ignore: constant_identifier_names
  static const int START_BYTE = 0x02;
  // ignore: constant_identifier_names
  static const int END_BYTE = 0x03;
  // ignore: constant_identifier_names
  static const int ACK_BYTE = 0x06;
  // ignore: constant_identifier_names
  static const int NAK_BYTE = 0x15;
  // ignore: constant_identifier_names
  static const int ESCAPE_BYTE = 0x1B;
  
  // Message types
  // ignore: constant_identifier_names
  static const int SET_RAW = 0x88;
  // ignore: constant_identifier_names
  static const int SUBSCRIBE_RAW = 0x89;
  // ignore: constant_identifier_names
  static const int UNSUBSCRIBE_RAW = 0x8A;
  // ignore: constant_identifier_names
  static const int RECALL_PRESET = 0x8C;
  // ignore: constant_identifier_names
  static const int SET_PERCENT = 0x8D;
  // ignore: constant_identifier_names
  static const int SUBSCRIBE_PERCENT = 0x8E;
  // ignore: constant_identifier_names
  static const int UNSUBSCRIBE_PERCENT = 0x8F;
  // ignore: constant_identifier_names
  static const int BUMP_PERCENT = 0x90;
  
  // Virtual device types
  // ignore: constant_identifier_names
  static const int AUDIO_DEVICE = 0x03;
  // ignore: constant_identifier_names
  static const int LOGIC_DEVICE = 0x02;
  
  // TCP port for Soundweb London devices
  // ignore: constant_identifier_names
  static const int TCP_PORT = 1023;
  
  // Map of device connections (deviceId -> Socket)
  final Map<String, Socket> _connections = {};
  
  // Map of device node addresses
  final Map<String, int> _nodeAddresses = {};
  
  // Event stream for value changes
  final _valueChangedController = StreamController<StateVariableUpdate>.broadcast();
  Stream<StateVariableUpdate> get onValueChanged => _valueChangedController.stream;
  
  // Command queue and processing flag for serial connections
  final Map<String, List<List<int>>> _commandQueues = {};
  final Map<String, bool> _isProcessingCommands = {};
  
  // Connect to a device using TCP/IP
  Future<bool> connectToDevice(String deviceId, String ip, int port, int nodeAddress) async {
    if (_connections.containsKey(deviceId)) {
      await disconnectFromDevice(deviceId);
    }
    
    try {
      // Connect with a timeout
      final socket = await Socket.connect(ip, port == 0 ? TCP_PORT : port, timeout: Duration(seconds: 5));
      
      // Store the connection and node address
      _connections[deviceId] = socket;
      _nodeAddresses[deviceId] = nodeAddress;
      
      // Initialize command queue for this device
      _commandQueues[deviceId] = [];
      _isProcessingCommands[deviceId] = false;
      
      // Set up data handling
      socket.listen(
        (data) => _handleData(deviceId, data),
        onError: (error) => _handleError(deviceId, error),
        onDone: () => _handleDisconnect(deviceId),
      );
      
      _log.info('Connected to BSS device $deviceId at $ip:${port == 0 ? TCP_PORT : port}, Node address: 0x${nodeAddress.toRadixString(16).padLeft(4, '0')}');
      return true;
    } catch (e) {
      _log.severe('Failed to connect to BSS device $deviceId: $e');
      return false;
    }
  }
  
  // Disconnect from a device
  Future<void> disconnectFromDevice(String deviceId) async {
    final socket = _connections[deviceId];
    if (socket != null) {
      await socket.close();
      _connections.remove(deviceId);
      _nodeAddresses.remove(deviceId);
      _commandQueues.remove(deviceId);
      _isProcessingCommands.remove(deviceId);
      _log.info('Disconnected from BSS device $deviceId');
    }
  }
  
  // Disconnect from all devices
  Future<void> disconnectFromAllDevices() async {
    for (final deviceId in List.from(_connections.keys)) {
      await disconnectFromDevice(deviceId);
    }
  }
  
  // Check if connected to a device
  bool isConnectedToDevice(String deviceId) {
    return _connections.containsKey(deviceId);
  }
  
  // Get a list of connected device IDs
  List<String> getConnectedDeviceIds() {
    return _connections.keys.toList();
  }
  
  // Handle incoming data from a device
  void _handleData(String deviceId, List<int> data) {
    _log.fine('Raw data from $deviceId: ${_bytesToHexString(data)}');
    
    // Process raw data to extract messages
    final messages = _extractMessages(data);
    
    for (final msg in messages) {
      _processMessage(deviceId, msg);
    }
  }
  
  // Extract messages from raw data stream
  List<List<int>> _extractMessages(List<int> data) {
    final messages = <List<int>>[];
    int start = -1;
    
    for (int i = 0; i < data.length; i++) {
      if (data[i] == START_BYTE) {
        start = i;
      } else if (data[i] == END_BYTE && start != -1) {
        messages.add(data.sublist(start, i + 1));
        start = -1;
      }
    }
    
    return messages;
  }
  
  // Process a complete message
  void _processMessage(String deviceId, List<int> message) {
    if (message.length < 3) return; // Too short to be valid
    
    // Remove START_BYTE and END_BYTE
    final body = message.sublist(1, message.length - 1);
    
    // Unescape special bytes
    final unescapedBody = _unescapeMessage(body);
    
    // Check length 
    if (unescapedBody.length < 2) return; // Too short after unescaping
    
    // Extract message type and process accordingly
    final msgType = unescapedBody[0];
    
    _log.fine('Processed message from $deviceId: Type: 0x${msgType.toRadixString(16).padLeft(2, '0')}, Content: ${_bytesToHexString(unescapedBody)}');
    
    // Process based on message type
    switch (msgType) {
      case SET_RAW:
        _handleSetRawResponse(deviceId, unescapedBody);
        break;
      
      case SET_PERCENT:
        _handleSetPercentResponse(deviceId, unescapedBody);
        break;
      
      case ACK_BYTE:
        _log.info('Received ACK from device $deviceId');
        _processNextCommand(deviceId); // Process next command in queue
        break;
      
      case NAK_BYTE:
        _log.warning('Received NAK from device $deviceId - checksum error');
        _processNextCommand(deviceId); // Process next command in queue
        break;
      
      default:
        _log.warning('Unhandled message type: 0x${msgType.toRadixString(16).padLeft(2, '0')}');
    }
  }
  
  // Handle SET_RAW response
  void _handleSetRawResponse(String deviceId, List<int> body) {
    // Need at least 11 bytes: Type + NodeAddr(2) + VirtualDev(1) + ObjID(3) + ParamID(2) + Value(at least 3)
    if (body.length < 11) return;
    
    final nodeAddress = (body[1] << 8) | body[2];
    final virtualDevice = body[3];
    final objectId = (body[4] << 16) | (body[5] << 8) | body[6];
    final parameterId = (body[7] << 8) | body[8];
    
    // Extract the 4-byte value
    final valueBytes = body.sublist(9, 13);
    final value = _extractValueFromBytes(valueBytes);
    
    // Create a unique state variable ID
    final stateVarId = '${nodeAddress}_${virtualDevice}_${objectId}_${parameterId}';
    
    // Notify listeners
    _valueChangedController.add(StateVariableUpdate(
      deviceId: deviceId,
      stateVariableId: stateVarId,
      value: value,
      objectId: objectId,
      parameterId: parameterId,
    ));
    
    _log.info('Parameter update: Node:0x${nodeAddress.toRadixString(16).padLeft(4, '0')}, ' 
        'Obj:0x${objectId.toRadixString(16).padLeft(6, '0')}, '
        'Param:0x${parameterId.toRadixString(16).padLeft(4, '0')}, '
        'Value:$value');
  }
  
  // Handle SET_PERCENT response
  void _handleSetPercentResponse(String deviceId, List<int> body) {
    // Similar to SET_RAW but the value represents a percentage
    if (body.length < 11) return;
    
    final nodeAddress = (body[1] << 8) | body[2];
    final virtualDevice = body[3];
    final objectId = (body[4] << 16) | (body[5] << 8) | body[6];
    final parameterId = (body[7] << 8) | body[8];
    
    // Extract the 4-byte value as a percentage (0-65536 -> 0-100%)
    final valueBytes = body.sublist(9, 13);
    int rawValue = _bytesToInt(valueBytes);
    double percentValue = (rawValue / 65536) * 100;
    
    // Create a unique state variable ID
    final stateVarId = '${nodeAddress}_${virtualDevice}_${objectId}_${parameterId}';
    
    // Notify listeners
    _valueChangedController.add(StateVariableUpdate(
      deviceId: deviceId,
      stateVariableId: stateVarId,
      value: percentValue,
      objectId: objectId,
      parameterId: parameterId,
    ));
    
    _log.info('Parameter update (percent): Node:0x${nodeAddress.toRadixString(16).padLeft(4, '0')}, '
        'Obj:0x${objectId.toRadixString(16).padLeft(6, '0')}, '
        'Param:0x${parameterId.toRadixString(16).padLeft(4, '0')}, '
        'Value:${percentValue.toStringAsFixed(2)}%');
  }
  
  // Handle socket errors
  void _handleError(String deviceId, dynamic error) {
    _log.severe('Socket error for device $deviceId: $error');
    _handleDisconnect(deviceId);
  }
  
  // Handle socket disconnection
  void _handleDisconnect(String deviceId) {
    _connections.remove(deviceId);
    _nodeAddresses.remove(deviceId);
    _commandQueues.remove(deviceId);
    _isProcessingCommands.remove(deviceId);
    _log.info('Device $deviceId disconnected');
  }

  // Set a parameter value using raw value
  Future<bool> setParameterRaw(String deviceId, int objectId, int parameterId, int value) async {
    final socket = _connections[deviceId];
    final nodeAddress = _nodeAddresses[deviceId];
    
    if (socket == null || nodeAddress == null) return false;
    
    try {
      // Create the message
      final messageBody = [
        // Message type
        SET_RAW,
        
        // Node address (2 bytes)
        (nodeAddress >> 8) & 0xFF,
        nodeAddress & 0xFF,
        
        // Virtual device (always AUDIO_DEVICE for now)
        AUDIO_DEVICE,
        
        // Object ID (3 bytes)
        (objectId >> 16) & 0xFF,
        (objectId >> 8) & 0xFF,
        objectId & 0xFF,
        
        // Parameter ID (2 bytes)
        (parameterId >> 8) & 0xFF,
        parameterId & 0xFF,
        
        // Value (4 bytes)
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];
      
      // Calculate checksum
      int checksum = 0;
      for (int byte in messageBody) {
        checksum ^= byte; // XOR all bytes
      }
      
      // Add checksum
      messageBody.add(checksum);
      
      // Prepare the full message with escape sequences
      final escapedMessage = _escapeMessage(messageBody);
      final fullMessage = [START_BYTE, ...escapedMessage, END_BYTE];
      
      // Log the message
      _log.fine('Sending SET_RAW to $deviceId: ${_bytesToHexString(fullMessage)}');
      
      // Send the message
      socket.add(fullMessage);
      
      return true;
    } catch (e) {
      _log.severe('Error sending parameter to device $deviceId: $e');
      return false;
    }
  }
  
  // Set a parameter value using percentage
  Future<bool> setParameterPercent(String deviceId, int objectId, int parameterId, double percent) async {
    // Convert percent (0-100) to raw value (0-65536)
    final rawValue = (percent * 65536 / 100).round();
    
    final socket = _connections[deviceId];
    final nodeAddress = _nodeAddresses[deviceId];
    
    if (socket == null || nodeAddress == null) return false;
    
    try {
      // Create the message
      final messageBody = [
        // Message type
        SET_PERCENT,
        
        // Node address (2 bytes)
        (nodeAddress >> 8) & 0xFF,
        nodeAddress & 0xFF,
        
        // Virtual device (always AUDIO_DEVICE for now)
        AUDIO_DEVICE,
        
        // Object ID (3 bytes)
        (objectId >> 16) & 0xFF,
        (objectId >> 8) & 0xFF,
        objectId & 0xFF,
        
        // Parameter ID (2 bytes)
        (parameterId >> 8) & 0xFF,
        parameterId & 0xFF,
        
        // Value (4 bytes)
        (rawValue >> 24) & 0xFF,
        (rawValue >> 16) & 0xFF,
        (rawValue >> 8) & 0xFF,
        rawValue & 0xFF,
      ];
      
      // Calculate checksum
      int checksum = 0;
      for (int byte in messageBody) {
        checksum ^= byte; // XOR all bytes
      }
      
      // Add checksum
      messageBody.add(checksum);
      
      // Prepare the full message with escape sequences
      final escapedMessage = _escapeMessage(messageBody);
      final fullMessage = [START_BYTE, ...escapedMessage, END_BYTE];
      
      // Log the message
      _log.fine('Sending SET_PERCENT to $deviceId: ${_bytesToHexString(fullMessage)}');
      
      // Send the message
      socket.add(fullMessage);
      
      return true;
    } catch (e) {
      _log.severe('Error sending parameter percent to device $deviceId: $e');
      return false;
    }
  }
  
  // Subscribe to a parameter for updates
  Future<bool> subscribeToParameter(String deviceId, int objectId, int parameterId) async {
    final socket = _connections[deviceId];
    final nodeAddress = _nodeAddresses[deviceId];
    
    if (socket == null || nodeAddress == null) return false;
    
    try {
      // Create the message
      final messageBody = [
        // Message type
        SUBSCRIBE_RAW,
        
        // Node address (2 bytes)
        (nodeAddress >> 8) & 0xFF,
        nodeAddress & 0xFF,
        
        // Virtual device (always AUDIO_DEVICE for now)
        AUDIO_DEVICE,
        
        // Object ID (3 bytes)
        (objectId >> 16) & 0xFF,
        (objectId >> 8) & 0xFF,
        objectId & 0xFF,
        
        // Parameter ID (2 bytes)
        (parameterId >> 8) & 0xFF,
        parameterId & 0xFF,
      ];
      
      // Calculate checksum
      int checksum = 0;
      for (int byte in messageBody) {
        checksum ^= byte; // XOR all bytes
      }
      
      // Add checksum
      messageBody.add(checksum);
      
      // Prepare the full message with escape sequences
      final escapedMessage = _escapeMessage(messageBody);
      final fullMessage = [START_BYTE, ...escapedMessage, END_BYTE];
      
      // Log the message
      _log.fine('Sending SUBSCRIBE to $deviceId: ${_bytesToHexString(fullMessage)}');
      
      // Send the message
      socket.add(fullMessage);
      
      return true;
    } catch (e) {
      _log.severe('Error subscribing to parameter on device $deviceId: $e');
      return false;
    }
  }
  
  // Unsubscribe from a parameter
  Future<bool> unsubscribeFromParameter(String deviceId, int objectId, int parameterId) async {
    final socket = _connections[deviceId];
    final nodeAddress = _nodeAddresses[deviceId];
    
    if (socket == null || nodeAddress == null) return false;
    
    try {
      // Create the message
      final messageBody = [
        // Message type
        UNSUBSCRIBE_RAW,
        
        // Node address (2 bytes)
        (nodeAddress >> 8) & 0xFF,
        nodeAddress & 0xFF,
        
        // Virtual device (always AUDIO_DEVICE for now)
        AUDIO_DEVICE,
        
        // Object ID (3 bytes)
        (objectId >> 16) & 0xFF,
        (objectId >> 8) & 0xFF,
        objectId & 0xFF,
        
        // Parameter ID (2 bytes)
        (parameterId >> 8) & 0xFF,
        parameterId & 0xFF,
      ];
      
      // Calculate checksum
      int checksum = 0;
      for (int byte in messageBody) {
        checksum ^= byte; // XOR all bytes
      }
      
      // Add checksum
      messageBody.add(checksum);
      
      // Prepare the full message with escape sequences
      final escapedMessage = _escapeMessage(messageBody);
      final fullMessage = [START_BYTE, ...escapedMessage, END_BYTE];
      
      // Log the message
      _log.fine('Sending UNSUBSCRIBE to $deviceId: ${_bytesToHexString(fullMessage)}');
      
      // Send the message
      socket.add(fullMessage);
      
      return true;
    } catch (e) {
      _log.severe('Error unsubscribing from parameter on device $deviceId: $e');
      return false;
    }
  }
  
  // Recall a preset
  Future<bool> recallPreset(int presetId) async {
    if (_connections.isEmpty) return false;
    
    try {
      // Create the message
      final messageBody = [
        // Message type
        RECALL_PRESET,
        
        // Preset ID (4 bytes)
        (presetId >> 24) & 0xFF,
        (presetId >> 16) & 0xFF,
        (presetId >> 8) & 0xFF,
        presetId & 0xFF,
      ];
      
      // Calculate checksum
      int checksum = 0;
      for (int byte in messageBody) {
        checksum ^= byte; // XOR all bytes
      }
      
      // Add checksum
      messageBody.add(checksum);
      
      // Prepare the full message with escape sequences
      final escapedMessage = _escapeMessage(messageBody);
      final fullMessage = [START_BYTE, ...escapedMessage, END_BYTE];
      
      // Log the message
      _log.fine('Sending RECALL_PRESET: ${_bytesToHexString(fullMessage)}');
      
      // Send to all connected devices (presets are not device-specific)
      for (final socket in _connections.values) {
        socket.add(fullMessage);
      }
      
      return true;
    } catch (e) {
      _log.severe('Error recalling preset: $e');
      return false;
    }
  }
  
  // Process the next command in the queue
  void _processNextCommand(String deviceId) {
    if (!_commandQueues.containsKey(deviceId) || _commandQueues[deviceId]!.isEmpty) {
      _isProcessingCommands[deviceId] = false;
      return;
    }
    
    final socket = _connections[deviceId];
    if (socket == null) {
      _commandQueues[deviceId]!.clear();
      _isProcessingCommands[deviceId] = false;
      return;
    }
    
    final command = _commandQueues[deviceId]!.removeAt(0);
    socket.add(command);
    
    // Process next command after a short delay
    Future.delayed(Duration(milliseconds: 50), () {
      _processNextCommand(deviceId);
    });
  }
  
  // Enqueue a command (for serial communication)
  // ignore: unused_element
  void _enqueueCommand(String deviceId, List<int> command) {
    if (!_commandQueues.containsKey(deviceId)) {
      _commandQueues[deviceId] = [];
    }
    
    _commandQueues[deviceId]!.add(command);
    
    // Start processing if not already processing
    if (_isProcessingCommands[deviceId] != true) {
      _isProcessingCommands[deviceId] = true;
      _processNextCommand(deviceId);
    }
  }
  
  // Helper method to escape special characters in a message
  List<int> _escapeMessage(List<int> message) {
    final escapedMessage = <int>[];
    
    for (final byte in message) {
      if (byte == START_BYTE) {
        escapedMessage.add(ESCAPE_BYTE);
        escapedMessage.add(0x82);
      } else if (byte == END_BYTE) {
        escapedMessage.add(ESCAPE_BYTE);
        escapedMessage.add(0x83);
      } else if (byte == ACK_BYTE) {
        escapedMessage.add(ESCAPE_BYTE);
        escapedMessage.add(0x86);
      } else if (byte == NAK_BYTE) {
        escapedMessage.add(ESCAPE_BYTE);
        escapedMessage.add(0x95);
      } else if (byte == ESCAPE_BYTE) {
        escapedMessage.add(ESCAPE_BYTE);
        escapedMessage.add(0x9B);
      } else {
        escapedMessage.add(byte);
      }
    }
    
    return escapedMessage;
  }
  
  // Helper method to unescape special characters in a message
  List<int> _unescapeMessage(List<int> message) {
    final unescapedMessage = <int>[];
    int i = 0;
    
    while (i < message.length) {
      if (message[i] == ESCAPE_BYTE && i + 1 < message.length) {
        switch (message[i + 1]) {
          case 0x82:
            unescapedMessage.add(START_BYTE);
            break;
          case 0x83:
            unescapedMessage.add(END_BYTE);
            break;
          case 0x86:
            unescapedMessage.add(ACK_BYTE);
            break;
          case 0x95:
            unescapedMessage.add(NAK_BYTE);
            break;
          case 0x9B:
            unescapedMessage.add(ESCAPE_BYTE);
            break;
          default:
            // Unknown escape sequence, add both bytes
            unescapedMessage.add(message[i]);
            unescapedMessage.add(message[i + 1]);
        }
        i += 2;
      } else {
        unescapedMessage.add(message[i]);
        i += 1;
      }
    }
    
    return unescapedMessage;
  }
  
  // Helper method to extract a value from 4 bytes
  dynamic _extractValueFromBytes(List<int> bytes) {
    if (bytes.length != 4) return null;
    
    // Combine bytes into an int
    final value = _bytesToInt(bytes);
    
    // For now, just return the raw value
    // In a real implementation, you would convert based on the parameter type
    return value;
  }
  
  // Helper method to convert bytes to a signed integer
  int _bytesToInt(List<int> bytes) {
    if (bytes.length != 4) return 0;
    
    int value = 0;
    for (int i = 0; i < 4; i++) {
      value = (value << 8) | bytes[i];
    }
    
    // Handle sign bit (two's complement)
    if ((value & 0x80000000) != 0) {
      value = value - 0x100000000;
    }
    
    return value;
  }
  
  // Convert int to bytes
  // ignore: unused_element
  List<int> _intToBytes(int value, int numBytes) {
    final bytes = <int>[];
    for (var i = numBytes - 1; i >= 0; i--) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }
  
  // Convert bytes to hex string for logging
  String _bytesToHexString(List<int> bytes) {
    return bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ');
  }
  
  // Parse an ObjectId string from Audio Architect in format [major.minor.id]
  int parseObjectIdString(String objectIdStr) {
    // Remove brackets and split by dots
    final parts = objectIdStr.replaceAll('[', '').replaceAll(']', '').split('.');
    
    if (parts.length != 3) {
      _log.warning('Invalid object ID format: $objectIdStr');
      return 0;
    }
    
    try {
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final id = int.parse(parts[2], radix: 16); // Assuming ID part is hex
      
      // Combine into a single value as seen in the protocol
      return (major << 16) | (minor << 8) | id;
    } catch (e) {
      _log.warning('Error parsing object ID: $objectIdStr - $e');
      return 0;
    }
  }
  
  // Higher-level methods for state variables
  
  // Set a state variable value
  Future<bool> setStateVariableValue(String deviceId, StateVariable stateVar, dynamic value) async {
    // For the BSS system, we need to:
    // 1. Convert the StateVariable to objectId and parameterId
    // 2. Convert the value to the appropriate format
    // 3. Send the command
    
    // The objectId is typically stored in stateVar.objectIndex
    final objectId = stateVar.objectIndex;
    // The parameterId is typically 0 for most controls
    final parameterId = 0;
    
    // Convert the value based on its type
    if (value is bool) {
      // Boolean values (like mute) are represented as 0/1
      return setParameterRaw(deviceId, objectId, parameterId, value ? 1 : 0);
    } else if (value is int) {
      // Integer values (like source selectors)
      return setParameterRaw(deviceId, objectId, parameterId, value);
    } else if (value is double) {
      // For gain values, we need to convert to the BSS representation
      // This depends on the specific parameter type
      
      // For gain parameters in dB:
      if (stateVar.type.toLowerCase() == 'gain') {
        // Convert dB to the BSS format: Unity gain (0dB) is 0, -80dB is -280617, +10dB is 100000
        int rawValue;
        if (value <= -80.0) {
          rawValue = -280617; // -∞dB (minimum)
        } else if (value >= 10.0) {
          rawValue = 100000; // +10dB (maximum)
        } else if (value < -10.0) {
          // Logarithmic scale from -inf to -10dB
          double normalized = (value + 80.0) / 70.0; // 0.0 to 1.0
          rawValue = (normalized * 280617 - 280617).round();
        } else {
          // Linear scale from -10dB to +10dB
          double normalized = (value + 10.0) / 20.0; // 0.0 to 1.0
          rawValue = (normalized * 100000).round();
        }
        return setParameterRaw(deviceId, objectId, parameterId, rawValue);
      } else {
        // For other numeric parameters, use percent
        return setParameterPercent(deviceId, objectId, parameterId, value);
      }
    } else {
      _log.warning('Unsupported value type: ${value.runtimeType}');
      return false;
    }
  }
  
  // Subscribe to a state variable
  Future<bool> subscribeToStateVariable(String deviceId, StateVariable stateVar) async {
    final objectId = stateVar.objectIndex;
    final parameterId = 0; // Usually 0 for most parameters
    
    return subscribeToParameter(deviceId, objectId, parameterId);
  }
  
  // Unsubscribe from a state variable
  Future<bool> unsubscribeFromStateVariable(String deviceId, StateVariable stateVar) async {
    final objectId = stateVar.objectIndex;
    final parameterId = 0; // Usually 0 for most parameters
    
    return unsubscribeFromParameter(deviceId, objectId, parameterId);
  }
  
  // Dispose the service
  void dispose() {
    disconnectFromAllDevices();
    _valueChangedController.close();
  }
}

/// Class representing a state variable update
class StateVariableUpdate {
  final String deviceId;
  final String stateVariableId;
  final dynamic value;
  final int objectId;
  final int parameterId;
  
  StateVariableUpdate({
    required this.deviceId,
    required this.stateVariableId,
    required this.value,
    required this.objectId,
    required this.parameterId,
  });
}