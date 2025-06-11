import 'package:flutter/material.dart';
import 'package:testmap/simple_diagnostic_map_widget.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SimpleDiagnosticMapWidget(
        tileServerUrl: 'http://10.194.7.35:8080',
      ),
    );
  }
}