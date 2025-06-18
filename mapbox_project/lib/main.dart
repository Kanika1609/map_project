import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Paste your Mapbox access token here
const String mapboxAccessToken = 'pk.eyJ1IjoiaXdheXBsdXMiLCJhIjoiY2xlanhwaW5nMGZ0aDN4cGRmaDZpemNwZiJ9.CkW1qt9oR5UC7S4NjWsrdA';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxAccessToken);
  runApp(const MaterialApp(home: MapPage()));
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? _mapboxMap;
  bool _isStyleLoaded = false;

  @override
  void dispose() {
    _mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIIMS Jammu Map'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri: 'http://10.194.2.53:8080/styles/aiims/style.json',
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),

          if (!_isStyleLoaded)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map style...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    _mapboxMap!.setCamera(CameraOptions(
      center: Point(coordinates: Position(75.0321, 32.5645)),
      zoom: 18.0,
    ));

    debugPrint('Map created');
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    setState(() {
      _isStyleLoaded = true;
    });

    debugPrint('Style loaded');

    // Optional: list available layers for debugging
    Future.delayed(const Duration(milliseconds: 300), () {
      // _listAvailableLayers();
    });
  }

  void _listAvailableLayers() async {
    if (_mapboxMap == null) return;

    final layerIds = [
      'background',
      'combined_with_layers-fill',
      'combined_with_layers-line',
    ];

    for (final layerId in layerIds) {
      try {
        await _mapboxMap!.style.getStyleLayerProperty(layerId, 'visibility');
        debugPrint('Layer found: $layerId');
      } catch (e) {
        debugPrint('Layer not found: $layerId');
      }
    }
  }
}

