import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class SimpleDiagnosticMapWidget extends StatefulWidget {
  final String tileServerUrl;

  const SimpleDiagnosticMapWidget({
    Key? key,
    required this.tileServerUrl,
  }) : super(key: key);

  @override
  State<SimpleDiagnosticMapWidget> createState() => _SimpleDiagnosticMapWidgetState();
}

class _SimpleDiagnosticMapWidgetState extends State<SimpleDiagnosticMapWidget> {
  late final MapController _mapController;
  String _currentTileUrl = '';
  String _statusMessage = 'Starting...';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentTileUrl = '${widget.tileServerUrl}/styles/basic-preview/{z}/{x}/{y}.png';
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final response = await http.get(Uri.parse(widget.tileServerUrl));
      setState(() {
        _statusMessage = 'Server Status: ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection Error: $e';
      });
    }
  }

  void _switchTileUrl(String newUrl) {
    setState(() {
      _currentTileUrl = newUrl;
      _statusMessage = 'Switched to: $newUrl';
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map Test'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $_statusMessage'),
                SizedBox(height: 10),
                Text('Current URL: $_currentTileUrl'),
                SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _switchTileUrl('${widget.tileServerUrl}/styles/basic-preview/{z}/{x}/{y}.png'),
                      child: Text('Basic'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _switchTileUrl('${widget.tileServerUrl}/styles/klokantech-basic/{z}/{x}/{y}.png'),
                      child: Text('Klokan'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _switchTileUrl('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      child: Text('OSM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(28.6139, 77.2090), // New Delhi
                initialZoom: 10.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: _currentTileUrl,
                  errorTileCallback: (tile, error, httpResponse) {
                    print('Tile Error: $error');
                    //print('HTTP Status: ${httpResponse?.statusCode()}');
                    print('Tile URL: ${tile.toString()}');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testConnection,
        child: Icon(Icons.refresh),
      ),
    );
  }
}