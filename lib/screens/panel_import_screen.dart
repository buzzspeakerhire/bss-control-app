import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/panel_parser.dart';
import '../models/panel_model.dart';

class PanelImportScreen extends StatefulWidget {
  const PanelImportScreen({super.key});

  @override
  State<PanelImportScreen> createState() => _PanelImportScreenState();
}

class _PanelImportScreenState extends State<PanelImportScreen> {
  File? _selectedFile;
  bool _isLoading = false;
  String _errorMessage = '';
  Panel? _previewPanel;
  final _filenameController = TextEditingController();
  late StorageService _storageService;
  late PanelParser _panelParser;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _panelParser = PanelParser();
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _previewPanel = null;
    });

    try {
      // Make sure to use any file type without specifying extensions
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Don't restrict to any file type
        allowMultiple: false,
        withData: false,
        withReadStream: false,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final file = File(result.files.first.path!);
        _selectedFile = file;
        
        // Get just the filename from the path
        final filename = file.path.split('/').last.split('\\').last;
        _filenameController.text = filename;

        // Check file extension manually
        if (!filename.toLowerCase().endsWith('.panel')) {
          setState(() {
            _errorMessage = 'Selected file should have a .panel extension';
            _isLoading = false;
          });
          return;
        }

        // Try to parse the panel file
        try {
          final panel = await _panelParser.parseFromFile(file.path);
          setState(() {
            _previewPanel = panel;
          });
        } catch (parseError) {
          setState(() {
            _errorMessage = 'Error parsing panel file: $parseError';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No file selected';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importPanel() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a panel file')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Import the panel file
      await _storageService.importPanelFile(_selectedFile!);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panel imported successfully')),
        );

        // Go back to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error importing panel: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Panel'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _filenameController,
                          decoration: const InputDecoration(
                            labelText: 'Filename',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _pickFile,
                        child: const Text('Select File'),
                      ),
                    ],
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_previewPanel != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Panel Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${_previewPanel!.name}'),
                            Text('Size: ${_previewPanel!.width}x${_previewPanel!.height}'),
                            Text('Controls: ${_previewPanel!.controls.length}'),
                            Text('State Variables: ${_previewPanel!.stateVariables.length}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _previewPanel!.controls.length,
                        itemBuilder: (context, index) {
                          final control = _previewPanel!.controls[index];
                          return Card(
                            child: ListTile(
                              title: Text('${control.name} (${control.type})'),
                              subtitle: Text('Position: (${control.x}, ${control.y}), Size: ${control.width}x${control.height}'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedFile != null ? _importPanel : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Import Panel'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}