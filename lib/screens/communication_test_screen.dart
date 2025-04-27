import 'package:flutter/material.dart';
import '../services/device_communication_service.dart';


class CommunicationTestScreen extends StatefulWidget {
  const CommunicationTestScreen({super.key});

  @override
  State<CommunicationTestScreen> createState() => _CommunicationTestScreenState();
}

class _CommunicationTestScreenState extends State<CommunicationTestScreen> {
  final DeviceCommunicationService _communicationService = DeviceCommunicationService();
  bool _isConnected = false;
  String _statusMessage = 'Not connected';
  String _deviceIp = '';
  int _devicePort = 1023; // Default BSS port
  int _nodeAddress = 1; // Default node address
  double _faderValue = 0.0;
  bool _buttonValue = false;

  @override
  void initState() {
    super.initState();
    // Listen for value changes from the device
    _communicationService.onValueChanged.listen(_handleValueChanged);
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _statusMessage = 'Connecting...';
    });

    try {
      final success = await _communicationService.connectToDevice(
        'testDevice', // Simple ID for this test
        _deviceIp,
        _devicePort,
        _nodeAddress,
      );

      setState(() {
        _isConnected = success;
        _statusMessage = success ? 'Connected successfully' : 'Connection failed';
      });

      if (success) {
        // You can subscribe to some parameters here if needed
        // For example:
        // await _communicationService.subscribeToParameter('testDevice', 0x010203, 0);
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _handleValueChanged(StateVariableUpdate update) {
    // Handle updates from the device
    print('Received update: ${update.stateVariableId} = ${update.value}');
    
    // You could update UI controls based on these updates
  }

  Future<void> _sendFaderValue() async {
    if (!_isConnected) {
      setState(() {
        _statusMessage = 'Not connected. Cannot send value.';
      });
      return;
    }

    try {
      // Example: Send to object ID 0x010203, parameter 0
      final success = await _communicationService.setParameterPercent(
        'testDevice',
        0x010203, // Replace with actual object ID
        0, // Usually 0 for the primary parameter
        _faderValue,
      );

      setState(() {
        _statusMessage = success 
            ? 'Sent fader value: $_faderValue' 
            : 'Failed to send fader value';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending fader value: $e';
      });
    }
  }

  Future<void> _sendButtonValue() async {
    if (!_isConnected) {
      setState(() {
        _statusMessage = 'Not connected. Cannot send value.';
      });
      return;
    }

    try {
      // Example: Send to object ID 0x020304, parameter 0
      final success = await _communicationService.setParameterRaw(
        'testDevice',
        0x020304, // Replace with actual object ID
        0, // Usually 0 for the primary parameter
        _buttonValue ? 1 : 0,
      );

      setState(() {
        _statusMessage = success 
            ? 'Sent button state: $_buttonValue' 
            : 'Failed to send button state';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending button state: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSS Communication Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Device IP Address',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _deviceIp = value;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Port (Default: 1023)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _devicePort = int.tryParse(value) ?? 1023;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Node Address (Default: 1)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _nodeAddress = int.tryParse(value) ?? 1;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _connectToDevice,
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 16),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: $_statusMessage'),
            const Divider(),
            const Text(
              'Test Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Test Fader:'),
            Slider(
              min: 0.0,
              max: 100.0,
              value: _faderValue,
              label: _faderValue.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _faderValue = value;
                });
              },
              onChangeEnd: (value) {
                _sendFaderValue();
              },
            ),
            const SizedBox(height: 16),
            const Text('Test Button:'),
            Switch(
              value: _buttonValue,
              onChanged: (value) {
                setState(() {
                  _buttonValue = value;
                });
                _sendButtonValue();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Make sure to disconnect when leaving the screen
    if (_isConnected) {
      _communicationService.disconnectFromDevice('testDevice');
    }
    super.dispose();
  }
}