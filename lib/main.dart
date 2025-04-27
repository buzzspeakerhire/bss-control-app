import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BssControlApp());
}

class BssControlApp extends StatelessWidget {
  const BssControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSS Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}