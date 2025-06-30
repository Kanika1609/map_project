import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Put your actual Mapbox token here
const String mapboxAccessToken = 'pk.your_actual_paid_token_here';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxAccessToken);
  runApp(const MaterialApp(home: ZooMapPage()));
}

class ZooMapPage extends StatefulWidget {
  const ZooMapPage({super.key});

  @override
  State<ZooMapPage> createState() => _ZooMapPageState();
}

class _ZooMapPageState extends State<ZooMapPage> {
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
        title: const Text('Delhi Zoo Map'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri: 'http://10.184.22.136:8080/styles/zoo/style.json',
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
      center: Point(coordinates: Position(77.248, 28.607)),
      zoom: 17.0,
    ));

    debugPrint('Map created');
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    setState(() {
      _isStyleLoaded = true;
    });

    debugPrint('Style loaded');
  }
}
