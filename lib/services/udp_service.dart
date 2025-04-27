import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class UdpService {
  // Singleton pattern
  static final UdpService _instance = UdpService._internal();
  
  factory UdpService() {
    return _instance;
  }
  
  UdpService._internal();
  
  // Protocol constants
  static const int STX = 0x02; // Start of message
  static const int ETX = 0x03; // End of message
  static const int ACK = 0x06; // Acknowledge
  static const int NAK = 0x15; // Not acknowledge
  static const int ESC = 0x1B; // Escape character
  
  // Message types
  static const int SET_RAW = 0x88;
  static const int SUBSCRIBE_RAW = 0x89;
  static const int UNSUBSCRIBE_RAW = 0x8A;
  static const int RECALL_PRESET = 0x8C;
  static const int SET_PERCENT = 0x8D;
  static const int SUBSCRIBE_PERCENT = 0x8E;
  static const int UNSUBSCRIBE_PERCENT = 0x8F;
  static const int BUMP_PERCENT = 0x90;
  
  // Storage for active connections
  final Map<String, RawDatagramSocket> _sockets = {};
  
  // Controller for emitting received data
  final StreamController<UdpMessage> _messageController = StreamController<UdpMessage>.broadcast();
  Stream<UdpMessage> get messageStream => _messageController.stream;
  
  // Initialize a UDP socket for a specific device
  Future<bool> initializeSocket(String deviceId, String ipAddress, int port) async {
    try {
      // Close existing socket if any
      await closeSocket(deviceId);
      
      // Create a new UDP socket
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      // Store the socket with the device ID
      _sockets[deviceId] = socket;
      
      // Listen for incoming data
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final data = datagram.data;
            _handleReceivedData(deviceId, data);
          }
        }
      });
      
      return true;
    } catch (e) {
      print('Error initializing UDP socket: $e');
      return false;
    }
  }
  
  // Close a specific socket
  Future<void> closeSocket(String deviceId) async {
    final socket = _sockets[deviceId];
    if (socket != null) {
      socket.close();
      _sockets.remove(deviceId);
    }
  }
  
  // Close all sockets
  Future<void> closeAllSockets() async {
    for (final deviceId in _sockets.keys.toList()) {
      await closeSocket(deviceId);
    }
  }
  
  // Send a UDP message
  Future<bool> sendMessage(String deviceId, String ipAddress, int port, List<int> message) async {
    try {
      final socket = _sockets[deviceId];
      if (socket == null) {
        print('Socket for device $deviceId not initialized');
        return false;
      }
      
      final sent = socket.send(Uint8List.fromList(message), InternetAddress(ipAddress), port);
      return sent > 0;
    } catch (e) {
      print('Error sending UDP message: $e');
      return false;
    }
  }
  
  // Handle received data
  void _handleReceivedData(String deviceId, List<int> data) {
    // Extract messages from the received data
    final messages = _extractMessages(data);
    
    // Process each message
    for (final message in messages) {
      // Unescape any byte substitutions
      final unescapedMessage = _unescapeMessage(message);
      
      // Extract the message body (between STX and ETX)
      if (unescapedMessage.length >= 3) {
        final body = unescapedMessage.sublist(1, unescapedMessage.length - 1);
        
        // Calculate checksum
        final calculatedChecksum = _calculateChecksum(body.sublist(0, body.length - 1));
        final receivedChecksum = body[body.length - 1];
        
        // Verify checksum
        if (calculatedChecksum == receivedChecksum) {
          // Send ACK for serial connections (not needed for UDP/TCP)
          
          // Extract message type
          if (body.isNotEmpty) {
            final messageType = body[0];
            
            // Create UdpMessage object and emit it
            final udpMessage = UdpMessage(
              deviceId: deviceId,
              messageType: messageType,
              data: body,
            );
            
            _messageController.add(udpMessage);
          }
        } else {
          // Invalid checksum
          print('Invalid checksum received from $deviceId');
        }
      }
    }
  }
  
  // Extract complete messages from a data stream
  List<List<int>> _extractMessages(List<int> data) {
    final messages = <List<int>>[];
    int startIndex = -1;
    
    for (int i = 0; i < data.length; i++) {
      if (data[i] == STX) {
        startIndex = i;
      } else if (data[i] == ETX && startIndex >= 0) {
        messages.add(data.sublist(startIndex, i + 1));
        startIndex = -1;
      }
    }
    
    return messages;
  }
  
  // Unescape special bytes
  List<int> _unescapeMessage(List<int> message) {
    final result = <int>[];
    int i = 0;
    
    while (i < message.length) {
      if (message[i] == ESC && i + 1 < message.length) {
        // Handle escape sequences
        switch (message[i + 1]) {
          case 0x82:
            result.add(STX);
            i += 2;
            break;
          case 0x83:
            result.add(ETX);
            i += 2;
            break;
          case 0x86:
            result.add(ACK);
            i += 2;
            break;
          case 0x95:
            result.add(NAK);
            i += 2;
            break;
          case 0x9B:
            result.add(ESC);
            i += 2;
            break;
          default:
            // Not a valid escape sequence
            result.add(message[i]);
            i++;
            break;
        }
      } else {
        // Regular byte
        result.add(message[i]);
        i++;
      }
    }
    
    return result;
  }
  
  // Apply byte substitution (escape special bytes)
  List<int> _escapeMessage(List<int> message) {
    final result = <int>[];
    
    for (final byte in message) {
      switch (byte) {
        case STX:
          result.add(ESC);
          result.add(0x82);
          break;
        case ETX:
          result.add(ESC);
          result.add(0x83);
          break;
        case ACK:
          result.add(ESC);
          result.add(0x86);
          break;
        case NAK:
          result.add(ESC);
          result.add(0x95);
          break;
        case ESC:
          result.add(ESC);
          result.add(0x9B);
          break;
        default:
          result.add(byte);
          break;
      }
    }
    
    return result;
  }
  
  // Calculate checksum (XOR of all bytes)
  int _calculateChecksum(List<int> data) {
    int checksum = 0;
    for (final byte in data) {
      checksum ^= byte;
    }
    return checksum;
  }
  
  // Create a SET_RAW message
  List<int> createSetRawMessage({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
    required int value,
  }) {
    // Create message body
    final body = <int>[
      SET_RAW,
      // Node Address (2 bytes)
      (nodeAddress >> 8) & 0xFF,
      nodeAddress & 0xFF,
      // Virtual Device (1 byte)
      virtualDevice,
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
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Create a SET_PERCENT message
  List<int> createSetPercentMessage({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
    required double percent,
  }) {
    // Convert percent (0-100) to raw value
    final int rawValue = (percent * 65536 / 100).round();
    
    // Create message body
    final body = <int>[
      SET_PERCENT,
      // Node Address (2 bytes)
      (nodeAddress >> 8) & 0xFF,
      nodeAddress & 0xFF,
      // Virtual Device (1 byte)
      virtualDevice,
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
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Create a SUBSCRIBE_RAW message
  List<int> createSubscribeRawMessage({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
  }) {
    // Create message body
    final body = <int>[
      SUBSCRIBE_RAW,
      // Node Address (2 bytes)
      (nodeAddress >> 8) & 0xFF,
      nodeAddress & 0xFF,
      // Virtual Device (1 byte)
      virtualDevice,
      // Object ID (3 bytes)
      (objectId >> 16) & 0xFF,
      (objectId >> 8) & 0xFF,
      objectId & 0xFF,
      // Parameter ID (2 bytes)
      (parameterId >> 8) & 0xFF,
      parameterId & 0xFF,
    ];
    
    // Calculate checksum
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Create a SUBSCRIBE_PERCENT message
  List<int> createSubscribePercentMessage({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
  }) {
    // Create message body
    final body = <int>[
      SUBSCRIBE_PERCENT,
      // Node Address (2 bytes)
      (nodeAddress >> 8) & 0xFF,
      nodeAddress & 0xFF,
      // Virtual Device (1 byte)
      virtualDevice,
      // Object ID (3 bytes)
      (objectId >> 16) & 0xFF,
      (objectId >> 8) & 0xFF,
      objectId & 0xFF,
      // Parameter ID (2 bytes)
      (parameterId >> 8) & 0xFF,
      parameterId & 0xFF,
    ];
    
    // Calculate checksum
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Create an UNSUBSCRIBE_RAW message
  List<int> createUnsubscribeRawMessage({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
  }) {
    // Create message body
    final body = <int>[
      UNSUBSCRIBE_RAW,
      // Node Address (2 bytes)
      (nodeAddress >> 8) & 0xFF,
      nodeAddress & 0xFF,
      // Virtual Device (1 byte)
      virtualDevice,
      // Object ID (3 bytes)
      (objectId >> 16) & 0xFF,
      (objectId >> 8) & 0xFF,
      objectId & 0xFF,
      // Parameter ID (2 bytes)
      (parameterId >> 8) & 0xFF,
      parameterId & 0xFF,
    ];
    
    // Calculate checksum
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Create a RECALL_PRESET message
  List<int> createRecallPresetMessage({
    required int presetId,
  }) {
    // Create message body
    final body = <int>[
      RECALL_PRESET,
      // Preset ID (4 bytes)
      (presetId >> 24) & 0xFF,
      (presetId >> 16) & 0xFF,
      (presetId >> 8) & 0xFF,
      presetId & 0xFF,
    ];
    
    // Calculate checksum
    final checksum = _calculateChecksum(body);
    body.add(checksum);
    
    // Apply byte substitution
    final escapedBody = _escapeMessage(body);
    
    // Add STX and ETX
    return [STX] + escapedBody + [ETX];
  }
  
  // Parse a string of comma-separated hex values
  static List<int> parseHexString(String hexString) {
    final hexValues = hexString.split(',');
    final bytes = <int>[];
    
    for (final hex in hexValues) {
      final trimmedHex = hex.trim();
      if (trimmedHex.startsWith('0x')) {
        bytes.add(int.parse(trimmedHex.substring(2), radix: 16));
      } else {
        bytes.add(int.parse(trimmedHex, radix: 16));
      }
    }
    
    return bytes;
  }
  
  // Convert a list of bytes to a hex string
  static String bytesToHexString(List<int> bytes) {
    return bytes.map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}').join(', ');
  }
  
  // Dispose resources
  void dispose() {
    closeAllSockets();
    _messageController.close();
  }
}

// Class to represent a received UDP message
class UdpMessage {
  final String deviceId;
  final int messageType;
  final List<int> data;
  
  UdpMessage({
    required this.deviceId,
    required this.messageType,
    required this.data,
  });
  
  // Extract node address
  int get nodeAddress {
    if (data.length >= 3) {
      return (data[1] << 8) | data[2];
    }
    return 0;
  }
  
  // Extract virtual device
  int get virtualDevice {
    if (data.length >= 4) {
      return data[3];
    }
    return 0;
  }
  
  // Extract object ID
  int get objectId {
    if (data.length >= 7) {
      return (data[4] << 16) | (data[5] << 8) | data[6];
    }
    return 0;
  }
  
  // Extract parameter ID
  int get parameterId {
    if (data.length >= 9) {
      return (data[7] << 8) | data[8];
    }
    return 0;
  }
  
  // Extract value (for SET_RAW and SET_PERCENT)
  int get rawValue {
    if (data.length >= 13) {
      return (data[9] << 24) | (data[10] << 16) | (data[11] << 8) | data[12];
    }
    return 0;
  }
  
  // Convert raw value to percentage
  double get percentValue {
    return rawValue / 65536 * 100;
  }
}