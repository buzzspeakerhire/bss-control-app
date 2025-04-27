import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class VenueEditScreen extends StatefulWidget {
  final String? venueName;
  final Map<String, dynamic>? venueData;

  const VenueEditScreen({
    super.key,
    this.venueName,
    this.venueData,
  });

  @override
  State<VenueEditScreen> createState() => _VenueEditScreenState();
}

class _VenueEditScreenState extends State<VenueEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venueNameController = TextEditingController();
  final _deviceIpController = TextEditingController();
  final _devicePortController = TextEditingController();
  final List<Map<String, String>> _devices = [];
  bool _isEditing = false;
  late StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _isEditing = widget.venueName != null;

    if (_isEditing && widget.venueData != null) {
      _venueNameController.text = widget.venueName!;
      
      // Load devices from venue data
      final devices = widget.venueData!['devices'] as List<dynamic>?;
      if (devices != null) {
        for (final device in devices) {
          _devices.add({
            'ip': device['ip'] as String,
            'port': device['port'] as String,
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _venueNameController.dispose();
    _deviceIpController.dispose();
    _devicePortController.dispose();
    super.dispose();
  }

  Future<void> _saveVenue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final venueName = _venueNameController.text.trim();
    
    if (venueName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue name cannot be empty')),
      );
      return;
    }

    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one device')),
      );
      return;
    }

    try {
      // Create venue data
      final venueData = {
        'name': venueName,
        'devices': _devices,
      };

      // Save venue
      await _storageService.saveVenue(venueName, venueData);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venue ${_isEditing ? 'updated' : 'created'} successfully')),
        );

        // Go back to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving venue: $e')),
        );
      }
    }
  }

  void _addDevice() {
    final ip = _deviceIpController.text.trim();
    final port = _devicePortController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP and port cannot be empty')),
      );
      return;
    }

    setState(() {
      _devices.add({
        'ip': ip,
        'port': port,
      });
      _deviceIpController.clear();
      _devicePortController.clear();
    });
  }

  void _removeDevice(int index) {
    setState(() {
      _devices.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Venue' : 'Create Venue'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _venueNameController,
                decoration: const InputDecoration(
                  labelText: 'Venue Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a venue name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Devices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _deviceIpController,
                      decoration: const InputDecoration(
                        labelText: 'Device IP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _devicePortController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addDevice,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return Card(
                      child: ListTile(
                        title: Text('IP: ${device['ip']}'),
                        subtitle: Text('Port: ${device['port']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeDevice(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveVenue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isEditing ? 'Update Venue' : 'Create Venue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}