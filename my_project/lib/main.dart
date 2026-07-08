import 'package:flutter/material.dart';
import 'indoor_map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indoor Map',
      debugShowCheckedModeBanner: false,
      home: const IndoorMapScreen(),
    );
  }
}