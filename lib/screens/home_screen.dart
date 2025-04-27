import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import 'advanced_control_screen.dart';
import 'control_screen.dart';
import 'panel_import_screen.dart';
import 'venue_edit_screen.dart';
import '../services/panel_parser.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final PanelParser _panelParser = PanelParser();
  
  Map<String, dynamic> _venues = {};
  List<String> _recentPanels = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load venues
      final venues = await _storageService.loadVenues();
      
      // Load recent panels
      final recentPanels = await _storageService.getRecentPanels();
      
      setState(() {
        _venues = venues;
        _recentPanels = recentPanels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importPanel() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PanelImportScreen(),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSS Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorMessage()
              : _buildHomeContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVenueDialog(context),
        tooltip: 'Add Venue',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
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
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVenuesSection(),
        const Divider(),
        _buildRecentPanelsSection(),
      ],
    );
  }

  Widget _buildVenuesSection() {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Venues',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Venue'),
                  onPressed: () => _showAddVenueDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _venues.isEmpty
                  ? const Center(
                      child: Text('No venues found. Add a venue to get started.'),
                    )
                  : ListView.builder(
                      itemCount: _venues.length,
                      itemBuilder: (context, index) {
                        final venueName = _venues.keys.elementAt(index);
                        final venueData = _venues[venueName] as Map<String, dynamic>;
                        return _buildVenueCard(venueName, venueData);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueCard(String venueName, Map<String, dynamic> venueData) {
    final deviceCount = (venueData['devices'] as List?)?.length ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(venueName),
        subtitle: Text('$deviceCount device${deviceCount == 1 ? '' : 's'}'),
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                onPressed: () => _editVenue(venueName, venueData),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                onPressed: () => _deleteVenue(venueName),
              ),
              TextButton.icon(
                icon: const Icon(Icons.file_open),
                label: const Text('Load Panel'),
                onPressed: () => _loadPanel(venueName, venueData),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddVenueDialog(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const VenueEditScreen(),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _editVenue(String venueName, Map<String, dynamic> venueData) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VenueEditScreen(
          venueName: venueName,
          venueData: venueData,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteVenue(String venueName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Venue'),
        content: Text('Are you sure you want to delete "$venueName"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _storageService.deleteVenue(venueName);
        await _loadData();
      } catch (e) {
        setState(() {
          _errorMessage = 'Error deleting venue: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPanel(String venueName, Map<String, dynamic> venueData) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['panel'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final file = File(result.files.first.path!);
        final panel = await _panelParser.parseFromFile(file.path);
        
        // Navigate to control screen
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ControlScreen(
                venueName: venueName,
                panel: panel,
                venueData: venueData,
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error loading panel: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRecentPanelsSection() {
    return Expanded(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Panels',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Panel'),
                  onPressed: _importPanel,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recentPanels.isEmpty
                  ? const Center(
                      child: Text('No recent panels. Import a panel to get started.'),
                    )
                  : ListView.builder(
                      itemCount: _recentPanels.length,
                      itemBuilder: (context, index) {
                        final panelName = _recentPanels[index];
                        return ListTile(
                          leading: const Icon(Icons.file_present),
                          title: Text(panelName),
                          onTap: () => _openRecentPanel(panelName),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecentPanel(String panelName) async {
    if (_venues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a venue first'),
        ),
      );
      return;
    }

    final venueName = _venues.keys.first;
    final venueData = _venues[venueName] as Map<String, dynamic>;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final panel = await _storageService.loadPanel(panelName);
      
      // Choose between regular and advanced control screen
      if (!mounted) return;
      
      final useAdvancedControls = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open Panel'),
          content: const Text('Which control mode would you like to use?'),
          actions: [
            TextButton(
              child: const Text('Regular'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Advanced'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (useAdvancedControls == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdvancedControlScreen(
              venueName: venueName,
              panel: panel,
              venueData: venueData,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ControlScreen(
              venueName: venueName,
              panel: panel,
              venueData: venueData,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error opening panel: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}