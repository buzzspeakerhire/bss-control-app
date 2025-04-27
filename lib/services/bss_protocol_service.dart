import 'dart:typed_data';

/// Service for creating and parsing BSS London Direct Inject protocol messages
class BssProtocolService {
  // Message types
  static const int SET = 0x88;
  static const int SUBSCRIBE = 0x89;
  static const int UNSUBSCRIBE = 0x8A;
  static const int RECALL_PRESET = 0x8C;
  static const int SET_PERCENT = 0x8D;
  static const int SUBSCRIBE_PERCENT = 0x8E;
  static const int UNSUBSCRIBE_PERCENT = 0x8F;
  static const int BUMP_PERCENT = 0x90;

  // Special bytes
  static const int STX = 0x02; // Start of message
  static const int ETX = 0x03; // End of message
  static const int ESC = 0x1B; // Escape character
  static const int ACK = 0x06; // Acknowledge
  static const int NAK = 0x15; // Not acknowledge

  // Special byte substitutions
  static final Map<int, List<int>> _substitutions = {
    0x02: [0x1B, 0x82],
    0x03: [0x1B, 0x83],
    0x06: [0x1B, 0x86],
    0x15: [0x1B, 0x95],
    0x1B: [0x1B, 0x9B],
  };

  /// Create a SET command to set a parameter value
  /// [nodeAddress] - The device's node address (1-65534)
  /// [virtualDevice] - Usually 0x03 for Audio objects
  /// [objectId] - The object ID (e.g., 0x0100 for a gain)
  /// [parameterId] - The parameter ID within the object
  /// [value] - The raw value to set (32-bit signed integer)
  List<int> createSetCommand({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
    required int value,
  }) {
    // Create the body of the message
    final List<int> body = [
      SET,
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
      // Value (4 bytes - 32 bit signed integer)
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

    // Calculate the checksum
    final int checksum = _calculateChecksum(body);
    
    // Return the complete message with substitution
    return _createMessage(body, checksum);
  }

  /// Create a SUBSCRIBE command to monitor a parameter
  List<int> createSubscribeCommand({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
  }) {
    // Create the body of the message
    final List<int> body = [
      SUBSCRIBE,
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

    // Calculate the checksum
    final int checksum = _calculateChecksum(body);
    
    // Return the complete message with substitution
    return _createMessage(body, checksum);
  }

  /// Create an UNSUBSCRIBE command to stop monitoring a parameter
  List<int> createUnsubscribeCommand({
    required int nodeAddress,
    required int virtualDevice,
    required int objectId,
    required int parameterId,
  }) {
    // Create the body of the message
    final List<int> body = [
      UNSUBSCRIBE,
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

    // Calculate the checksum
    final int checksum = _calculateChecksum(body);
    
    // Return the complete message with substitution
    return _createMessage(body, checksum);
  }

  /// Create a RECALL_PRESET command to recall a Soundweb London Preset
  List<int> createRecallPresetCommand({
    required int presetId,
  }) {
    // Create the body of the message
    final List<int> body = [
      RECALL_PRESET,
      // Preset ID (4 bytes)
      (presetId >> 24) & 0xFF,
      (presetId >> 16) & 0xFF,
      (presetId >> 8) & 0xFF,
      presetId & 0xFF,
    ];

    // Calculate the checksum
    final int checksum = _calculateChecksum(body);
    
    // Return the complete message with substitution
    return _createMessage(body, checksum);
  }

  /// Parse a response message from the device
  Map<String, dynamic>? parseResponse(List<int> data) {
    try {
      // Remove byte substitutions
      final List<int> originalData = _removeByteSubstitutions(data);
      
      // Check if message is valid (starts with STX, ends with ETX)
      if (originalData.length < 3 || originalData.first != STX || originalData.last != ETX) {
        return null;
      }
      
      // Extract message type and body (without STX, ETX, and checksum)
      final List<int> body = originalData.sublist(1, originalData.length - 2);
      final int checksum = originalData[originalData.length - 2];
      
      // Verify checksum
      if (checksum != _calculateChecksum(body)) {
        return null;
      }
      
      // Parse based on message type
      final int messageType = body.first;
      
      if (messageType == SET) {
        // Parse SET response
        if (body.length >= 13) {
          final int nodeAddress = (body[1] << 8) | body[2];
          final int virtualDevice = body[3];
          final int objectId = (body[4] << 16) | (body[5] << 8) | body[6];
          final int parameterId = (body[7] << 8) | body[8];
          final int value = (body[9] << 24) | (body[10] << 16) | (body[11] << 8) | body[12];
          
          return {
            'type': 'SET',
            'nodeAddress': nodeAddress,
            'virtualDevice': virtualDevice,
            'objectId': objectId,
            'parameterId': parameterId,
            'value': value,
          };
        }
      } else if (messageType == SET_PERCENT) {
        // Parse SET_PERCENT response
        if (body.length >= 13) {
          final int nodeAddress = (body[1] << 8) | body[2];
          final int virtualDevice = body[3];
          final int objectId = (body[4] << 16) | (body[5] << 8) | body[6];
          final int parameterId = (body[7] << 8) | body[8];
          final int value = (body[9] << 24) | (body[10] << 16) | (body[11] << 8) | body[12];
          
          return {
            'type': 'SET_PERCENT',
            'nodeAddress': nodeAddress,
            'virtualDevice': virtualDevice,
            'objectId': objectId,
            'parameterId': parameterId,
            'value': value,
          };
        }
      }
      
      // Return null for unrecognized or incomplete messages
      return null;
    } catch (e) {
      print('Error parsing response: $e');
      return null;
    }
  }

  /// Convert a raw parameter value to its dB representation (for gain and meter parameters)
  double rawToDB(int rawValue, bool isMeter) {
    if (isMeter) {
      // Meter parameters: -80dB to +40dB, linear scale
      // dB value = Raw / 10,000
      return rawValue / 10000;
    } else {
      // Gain parameters: -80dB to +10dB, logarithmic from -inf to -10dB, linear above
      if (rawValue <= -280617) {
        return double.negativeInfinity;
      } else if (rawValue == 0) {
        return 0; // Unity gain (0dB)
      } else {
        // Approximation - in a real implementation, you'd use the exact scaling law
        return rawValue / 10000;
      }
    }
  }

  /// Convert a dB value to raw parameter value (for gain parameters)
  int dbToRaw(double dbValue) {
    if (dbValue == double.negativeInfinity) {
      return -280617; // Minimum value (-80dB)
    } else if (dbValue == 0) {
      return 0; // Unity gain (0dB)
    } else if (dbValue > 0) {
      // Positive values (0dB to +10dB)
      return (dbValue * 10000).round();
    } else {
      // Negative values (-80dB to 0dB)
      // Approximation - in a real implementation, you'd use the exact scaling law
      return (dbValue * 10000).round();
    }
  }

  /// Convert a percentage (0-100) to raw value for a parameter
  int percentToRaw(double percent) {
    // As per documentation: Raw = percentage value x 65536
    return (percent * 65536).round();
  }

  /// Convert a raw value to percentage (0-100)
  double rawToPercent(int rawValue) {
    // As per documentation: percent = Raw / 65536
    return rawValue / 65536;
  }

  /// Create a complete message with STX, body, checksum, ETX, and byte substitution
  List<int> _createMessage(List<int> body, int checksum) {
    final List<int> rawMessage = [STX, ...body, checksum, ETX];
    
    // Apply byte substitution
    final List<int> substitutedMessage = [];
    for (int i = 0; i < rawMessage.length; i++) {
      final int byte = rawMessage[i];
      
      // Only substitute bytes in the body and checksum (not STX and ETX)
      if (i != 0 && i != rawMessage.length - 1 && _substitutions.containsKey(byte)) {
        substitutedMessage.addAll(_substitutions[byte]!);
      } else {
        substitutedMessage.add(byte);
      }
    }
    
    return substitutedMessage;
  }

  /// Remove byte substitutions from a received message
  List<int> _removeByteSubstitutions(List<int> data) {
    final List<int> result = [];
    int i = 0;
    
    while (i < data.length) {
      if (data[i] == ESC && i + 1 < data.length) {
        // Check which special character this is
        final int nextByte = data[i + 1];
        bool substitutionFound = false;
        
        for (final entry in _substitutions.entries) {
          if (entry.value[1] == nextByte) {
            result.add(entry.key);
            substitutionFound = true;
            break;
          }
        }
        
        if (substitutionFound) {
          i += 2; // Skip both the ESC and the next byte
        } else {
          // If not a recognized substitution, just add the ESC
          result.add(data[i]);
          i++;
        }
      } else {
        result.add(data[i]);
        i++;
      }
    }
    
    return result;
  }

  /// Calculate the checksum for a message body
  /// The checksum is the XOR of all bytes in the body
  int _calculateChecksum(List<int> body) {
    int checksum = 0;
    for (final byte in body) {
      checksum ^= byte;
    }
    return checksum;
  }

  /// Parse a hex string (like "02,88,00,01,1B,83...") into a byte list
  static List<int> hexStringToBytes(String hexString) {
    final List<String> byteStrings = hexString.split(',');
    final List<int> bytes = [];
    
    for (final byteString in byteStrings) {
      final trimmed = byteString.trim();
      if (trimmed.isNotEmpty) {
        bytes.add(int.parse(trimmed, radix: 16));
      }
    }
    
    return bytes;
  }

  /// Convert a byte list to a hex string (like "02,88,00,01,1B,83...")
  static String bytesToHexString(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(',');
  }
}