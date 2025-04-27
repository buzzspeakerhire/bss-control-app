import 'package:flutter/material.dart';
import '../models/panel_model.dart';
import '../models/control_model.dart';
import '../models/state_variable_model.dart';

class AdvancedControlScreen extends StatefulWidget {
  final String venueName;
  final Panel panel;
  final Map<String, dynamic> venueData;

  const AdvancedControlScreen({
    super.key,
    required this.venueName,
    required this.panel,
    required this.venueData,
  });

  @override
  State<AdvancedControlScreen> createState() => _AdvancedControlScreenState();
}

class _AdvancedControlScreenState extends State<AdvancedControlScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  
  // Maps to store current values
  final Map<String, dynamic> _controlValues = {};
  final Map<String, dynamic> _stateVariableValues = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _connectToDevices();
    
    // Initialize control values
    for (final control in widget.panel.controls) {
      if (control.properties.containsKey('value')) {
        _controlValues[control.id] = control.properties['value'];
      }
    }
    
    // Initialize state variable values
    for (final stateVar in widget.panel.stateVariables) {
      _stateVariableValues[stateVar.id] = stateVar.value;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final control = widget.panel.controls.firstWhere((c) => c.id == controlId);
    
    if (control.stateVariable != null) {
      final stateVarId = control.stateVariable!.id;
      setState(() {
        _stateVariableValues[stateVarId] = value;
      });
      
      // TODO: Implement sending the value to the device using the London Direct Inject protocol
      // Logging would be added here
    }
  }

  void _onStateVariableValueChanged(String stateVarId, dynamic value) {
    setState(() {
      _stateVariableValues[stateVarId] = value;
    });
    
    // Update any controls that use this state variable
    for (final control in widget.panel.controls) {
      if (control.stateVariable?.id == stateVarId) {
        setState(() {
          _controlValues[control.id] = value;
        });
      }
    }
    
    // TODO: Implement sending the value to the device using the London Direct Inject protocol
    // Logging would be added here
  }

  Widget _buildControlsList() {
    return ListView.builder(
      itemCount: widget.panel.controls.length,
      itemBuilder: (context, index) {
        final control = widget.panel.controls[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            title: Text('${control.name} (${control.type})'),
            subtitle: Text('Position: (${control.x}, ${control.y}), Size: ${control.width}x${control.height}'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${control.id}'),
                    Text('Z-Order: ${control.zOrder}'),
                    if (control.stateVariable != null)
                      Text('State Variable: ${control.stateVariable!.name}'),
                    const Divider(),
                    const Text('Properties:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._buildPropertyList(control.properties),
                    const SizedBox(height: 16),
                    _buildControlValueEditor(control),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPropertyList(Map<String, dynamic> properties) {
    final widgets = <Widget>[];
    
    properties.forEach((key, value) {
      // Skip displaying some common properties that are already shown or handled separately
      if (['id', 'name', 'value'].contains(key)) {
        return;
      }
      
      String valueStr;
      if (value is List) {
        valueStr = value.join(', ');
      } else {
        valueStr = value.toString();
      }
      
      widgets.add(Text('$key: $valueStr'));
    });
    
    return widgets;
  }

  Widget _buildControlValueEditor(Control control) {
    // Get the current value of the control
    final value = _controlValues[control.id];
    
    if (value == null) {
      return const Text('No value available');
    }
    
    switch (control.type) {
      case 'FADER':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Value: $value'),
            Slider(
              min: control.properties['min'] as double,
              max: control.properties['max'] as double,
              value: value as double,
              onChanged: (newValue) => _onControlValueChanged(control.id, newValue),
            ),
          ],
        );
        
      case 'BUTTON':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State: ${value ? 'On' : 'Off'}'),
            Switch(
              value: value as bool,
              onChanged: (newState) => _onControlValueChanged(control.id, newState),
            ),
          ],
        );
        
      case 'COMBO':
        final items = List<String>.from(control.properties['items'] as List);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selected: ${items[value]}'),
            DropdownButton<int>(
              value: value,
              items: List.generate(items.length, (index) {
                return DropdownMenuItem<int>(
                  value: index,
                  child: Text(items[index]),
                );
              }),
              onChanged: (newIndex) {
                if (newIndex != null) {
                  _onControlValueChanged(control.id, newIndex);
                }
              },
            ),
          ],
        );
        
      default:
        return Text('Value: $value');
    }
  }

  Widget _buildStateVariablesList() {
    return ListView.builder(
      itemCount: widget.panel.stateVariables.length,
      itemBuilder: (context, index) {
        final stateVar = widget.panel.stateVariables[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            title: Text(stateVar.name),
            subtitle: Text('Type: ${stateVar.type}'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${stateVar.id}'),
                    Text('Device Index: ${stateVar.deviceIndex}'),
                    Text('Object Index: ${stateVar.objectIndex}'),
                    Text('Channel: ${stateVar.channel}'),
                    const SizedBox(height: 16),
                    _buildStateVariableValueEditor(stateVar),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateVariableValueEditor(StateVariable stateVar) {
    final value = _stateVariableValues[stateVar.id];
    
    if (value == null) {
      return const Text('No value available');
    }
    
    switch (stateVar.type.toLowerCase()) {
      case 'integer':
      case 'int':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Value: $value'),
            Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: value.toDouble(),
              onChanged: (newValue) => _onStateVariableValueChanged(stateVar.id, newValue.toInt()),
            ),
          ],
        );
        
      case 'float':
      case 'double':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Value: $value'),
            Slider(
              min: 0,
              max: 1,
              value: value as double,
              onChanged: (newValue) => _onStateVariableValueChanged(stateVar.id, newValue),
            ),
          ],
        );
        
      case 'boolean':
      case 'bool':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Value: ${value ? 'True' : 'False'}'),
            Switch(
              value: value as bool,
              onChanged: (newState) => _onStateVariableValueChanged(stateVar.id, newState),
            ),
          ],
        );
        
      default:
        return Text('Value: $value');
    }
  }

  Widget _buildDevicesList() {
    final List<dynamic>? devices = widget.venueData['devices'] as List<dynamic>?;
    
    if (devices == null || devices.isEmpty) {
      return const Center(
        child: Text('No devices configured for this venue'),
      );
    }
    
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final ip = device['ip'] as String;
        final port = device['port'] as String;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Icon(
              _isConnected ? Icons.device_hub : Icons.device_unknown,
              color: _isConnected ? Colors.green : Colors.grey,
            ),
            title: Text('Device ${index + 1}'),
            subtitle: Text('IP: $ip, Port: $port'),
            trailing: _isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.error, color: Colors.red),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Control - ${widget.panel.name}'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Controls'),
            Tab(text: 'State Variables'),
            Tab(text: 'Devices'),
          ],
        ),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildControlsList(),
                    _buildStateVariablesList(),
                    _buildDevicesList(),
                  ],
                ),
    );
  }
}