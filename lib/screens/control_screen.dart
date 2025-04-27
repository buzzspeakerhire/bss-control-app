import 'package:flutter/material.dart';
import '../models/panel_model.dart';
import '../models/control_model.dart';
import '../widgets/fader_widget.dart';
import '../widgets/meter_widget.dart';
import '../widgets/button_widget.dart';
import '../widgets/label_widget.dart';
import '../widgets/selector_widget.dart';

class ControlScreen extends StatefulWidget {
  final String venueName;
  final Panel panel;
  final Map<String, dynamic> venueData;

  const ControlScreen({
    super.key,
    required this.venueName,
    required this.panel,
    required this.venueData,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late Panel _panel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  // Map of control IDs to their current values
  final Map<String, dynamic> _controlValues = {};

  @override
  void initState() {
    super.initState();
    _panel = widget.panel;
    _connectToDevices();
    // Initialize control values
    for (final control in _panel.controls) {
      if (control.properties.containsKey('value')) {
        _controlValues[control.id] = control.properties['value'];
      }
    }
  }

  @override
  void dispose() {
    _disconnectFromDevices();
    super.dispose();
  }

  Future<void> _connectToDevices() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      // Get devices from venue data
      final List<dynamic>? devices = widget.venueData['devices'] as List<dynamic>?;
      
      if (devices == null || devices.isEmpty) {
        throw Exception('No devices configured for this venue');
      }

      // TODO: Implement device connection logic using the London Direct Inject protocol
      
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to devices: $e';
        _isConnecting = false;
      });
    }
  }

  void _disconnectFromDevices() {
    // TODO: Implement device disconnection logic
  }

  void _onControlValueChanged(String controlId, dynamic value) {
    setState(() {
      _controlValues[controlId] = value;
    });

    // Find the control and its state variable
    final control = _panel.controls.firstWhere((c) => c.id == controlId);
    
    if (control.stateVariable != null) {
      // TODO: Implement sending the value to the device using the London Direct Inject protocol
      // print('Sending value $value to device for control $controlId');
    }
  }

  Widget _buildControl(Control control) {
    final x = control.x.toDouble();
    final y = control.y.toDouble();
    final width = control.width.toDouble();
    final height = control.height.toDouble();

    Widget controlWidget;
    
    // Get the current value of the control
    final value = _controlValues[control.id] ?? control.properties['value'];

    switch (control.type) {
      case 'FADER':
        controlWidget = FaderWidget(
          min: control.properties['min'] as double,
          max: control.properties['max'] as double,
          value: value as double,
          orientation: control.properties['orientation'] as String,
          onChanged: (newValue) => _onControlValueChanged(control.id, newValue),
        );
        break;
        
      case 'METER':
        controlWidget = MeterWidget(
          min: control.properties['min'] as double,
          max: control.properties['max'] as double,
          value: value as double,
          orientation: control.properties['orientation'] as String,
          segments: control.properties['segments'] as int,
        );
        break;
        
      case 'BUTTON':
        controlWidget = ButtonWidget(
          text: control.properties['text'] as String,
          state: control.properties['state'] as bool,
          buttonType: control.properties['buttonType'] as String,
          onChanged: (newState) => _onControlValueChanged(control.id, newState),
        );
        break;
        
      case 'LABEL':
        controlWidget = LabelWidget(
          text: control.properties['text'] as String,
          textAlignment: control.properties['textAlignment'] as String,
          fontSize: control.properties['fontSize'] as int,
        );
        break;
        
      case 'COMBO':
        controlWidget = SelectorWidget(
          items: List<String>.from(control.properties['items'] as List),
          selectedIndex: control.properties['selectedIndex'] as int,
          onChanged: (newIndex) => _onControlValueChanged(control.id, newIndex),
        );
        break;
        
      default:
        controlWidget = Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red),
          ),
          child: Center(
            child: Text('Unknown control type: ${control.type}'),
          ),
        );
    }

    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: controlWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.panel.name),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              avatar: Icon(
                _isConnected ? Icons.link : Icons.link_off,
                color: _isConnected ? Colors.green : Colors.red,
              ),
              label: Text(_isConnected ? 'Connected' : 'Disconnected'),
              backgroundColor: _isConnected
                  ? Colors.green.withAlpha(50)
                  : Colors.red.withAlpha(50),
            ),
          ),
          // Refresh connection button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isConnecting ? null : _connectToDevices,
            tooltip: 'Reconnect to devices',
          ),
        ],
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _connectToDevices,
                        child: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                )
              : InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    width: _panel.width.toDouble(),
                    height: _panel.height.toDouble(),
                    color: Color(_panel.backgroundColor),
                    child: Stack(
                      children: _panel.controls
                          .map((control) => _buildControl(control))
                          .toList(),
                    ),
                  ),
                ),
    );
  }
}