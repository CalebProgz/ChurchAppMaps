import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const ChurchApp());
}

class ChurchApp extends StatelessWidget {
  const ChurchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
