// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/venue.dart';

class StorageService {
  static const String _venuesKey = 'bss_venues';
  
  // Save venues to SharedPreferences
  Future<bool> saveVenues(List<Venue> venues) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final venuesJson = venues.map((venue) => jsonEncode(venue.toJson())).toList();
      
      await prefs.setStringList(_venuesKey, venuesJson);
      return true;
    } catch (e) {
      print('Error saving venues: $e');
      return false;
    }
  }
  
  // Load venues from SharedPreferences
  Future<List<Venue>> loadVenues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final venuesJson = prefs.getStringList(_venuesKey) ?? [];
      
      return venuesJson
          .map((venueJson) => Venue.fromJson(jsonDecode(venueJson)))
          .toList();
    } catch (e) {
      print('Error loading venues: $e');
      return [];
    }
  }
}