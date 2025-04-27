import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/panel_model.dart';

class StorageService {
  static const String _venuesKey = 'venues';
  static const String _recentPanelsKey = 'recent_panels';
  
  /// Singleton instance
  static final StorageService _instance = StorageService._internal();
  
  factory StorageService() {
    return _instance;
  }
  
  StorageService._internal();
  
  /// Get the application documents directory
  Future<Directory> get _appDocDir async {
    return await getApplicationDocumentsDirectory();
  }
  
  /// Get the panels directory
  Future<Directory> get _panelsDir async {
    final appDir = await _appDocDir;
    final dir = Directory('${appDir.path}/panels');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
  
  /// Save a panel to storage
  Future<void> savePanel(Panel panel, String filename) async {
    try {
      final panelsDir = await _panelsDir;
      final file = File('${panelsDir.path}/$filename');
      
      // Convert panel to JSON
      final panelJson = jsonEncode(panel.toMap());
      
      // Write to file
      await file.writeAsString(panelJson);
      
      // Add to recent panels
      await _addToRecentPanels(filename);
    } catch (e) {
      throw Exception('Failed to save panel: $e');
    }
  }
  
  /// Load a panel from storage
  Future<Panel> loadPanel(String filename) async {
    try {
      final panelsDir = await _panelsDir;
      final file = File('${panelsDir.path}/$filename');
      
      if (!await file.exists()) {
        throw Exception('Panel file not found: $filename');
      }
      
      // Read file
      final panelJson = await file.readAsString();
      
      // Parse JSON
      final panelMap = jsonDecode(panelJson) as Map<String, dynamic>;
      
      // Convert to Panel object
      final panel = Panel.fromMap(panelMap);
      
      // Add to recent panels
      await _addToRecentPanels(filename);
      
      return panel;
    } catch (e) {
      throw Exception('Failed to load panel: $e');
    }
  }
  
  /// Delete a panel from storage
  Future<void> deletePanel(String filename) async {
    try {
      final panelsDir = await _panelsDir;
      final file = File('${panelsDir.path}/$filename');
      
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from recent panels
      await _removeFromRecentPanels(filename);
    } catch (e) {
      throw Exception('Failed to delete panel: $e');
    }
  }
  
  /// List all saved panels
  Future<List<String>> listPanels() async {
    try {
      final panelsDir = await _panelsDir;
      final files = await panelsDir.list().toList();
      
      return files
          .whereType<File>()
          .map((file) => file.path.split('/').last)
          .toList();
    } catch (e) {
      throw Exception('Failed to list panels: $e');
    }
  }
  
  /// Save venue information
  Future<void> saveVenue(String venueName, Map<String, dynamic> venueData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final venues = await getVenues();
      
      venues[venueName] = venueData;
      
      await prefs.setString(_venuesKey, jsonEncode(venues));
    } catch (e) {
      throw Exception('Failed to save venue: $e');
    }
  }
  
  /// Get all venues
  Future<Map<String, dynamic>> getVenues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final venuesJson = prefs.getString(_venuesKey) ?? '{}';
      
      return jsonDecode(venuesJson) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get venues: $e');
    }
  }
  
  /// Load venues (alias for getVenues for backward compatibility)
  Future<Map<String, dynamic>> loadVenues() async {
    return getVenues();
  }
  
  /// Save venues (alias for saveVenue but for multiple venues)
  Future<void> saveVenues(Map<String, dynamic> venues) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_venuesKey, jsonEncode(venues));
    } catch (e) {
      throw Exception('Failed to save venues: $e');
    }
  }
  
  /// Delete a venue
  Future<void> deleteVenue(String venueName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final venues = await getVenues();
      
      venues.remove(venueName);
      
      await prefs.setString(_venuesKey, jsonEncode(venues));
    } catch (e) {
      throw Exception('Failed to delete venue: $e');
    }
  }
  
  /// Get recent panels
  Future<List<String>> getRecentPanels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPanelsJson = prefs.getStringList(_recentPanelsKey) ?? [];
      
      return recentPanelsJson;
    } catch (e) {
      throw Exception('Failed to get recent panels: $e');
    }
  }
  
  /// Add a panel to recent panels
  Future<void> _addToRecentPanels(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPanels = await getRecentPanels();
      
      // Remove if already exists
      recentPanels.remove(filename);
      
      // Add to beginning of list
      recentPanels.insert(0, filename);
      
      // Limit to 10 recent panels
      if (recentPanels.length > 10) {
        recentPanels.removeLast();
      }
      
      await prefs.setStringList(_recentPanelsKey, recentPanels);
    } catch (e) {
      throw Exception('Failed to add to recent panels: $e');
    }
  }
  
  /// Remove a panel from recent panels
  Future<void> _removeFromRecentPanels(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPanels = await getRecentPanels();
      
      recentPanels.remove(filename);
      
      await prefs.setStringList(_recentPanelsKey, recentPanels);
    } catch (e) {
      throw Exception('Failed to remove from recent panels: $e');
    }
  }
  
  /// Import a panel file from external storage
  Future<String> importPanelFile(File sourceFile) async {
    try {
      final panelsDir = await _panelsDir;
      final filename = sourceFile.path.split('/').last;
      final destFile = File('${panelsDir.path}/$filename');
      
      // Copy the file
      await sourceFile.copy(destFile.path);
      
      // Add to recent panels
      await _addToRecentPanels(filename);
      
      return filename;
    } catch (e) {
      throw Exception('Failed to import panel file: $e');
    }
  }
}