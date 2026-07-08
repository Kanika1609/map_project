import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MaplibreTestScreen extends StatelessWidget {
  const MaplibreTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapLibre Test')),
      body: MapLibreMap(
        // A free basic raster style pointing at OpenStreetMap tiles.
        // No account or API key needed.
        styleString:
        'https://raw.githubusercontent.com/go2garret/maps/main/src/assets/json/openStreetMap.json',
        initialCameraPosition: const CameraPosition(
          target: LatLng(32.5645, 75.0359),
          zoom: 18,
          tilt: 45, // this is what gives us the 3D angled camera view
          bearing: 0,
        ),
      ),
    );
  }
}