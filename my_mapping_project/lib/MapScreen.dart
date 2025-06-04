/*
import 'dart:convert';
import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

class ServerVectorMap extends StatefulWidget {
  const ServerVectorMap({super.key});

  @override
  State<ServerVectorMap> createState() => _ServerVectorMapState();
}

class _ServerVectorMapState extends State<ServerVectorMap> {
  Theme? _theme;
  bool _loaded = false;

  List<_MarkerData> _geojsonMarkers = [];
  List<_PolygonData> _geojsonPolygons = [];
  int? _selectedPolygonIndex;
  int? _selectedMarkerIndex;

  final String styleUrl = 'http://10.184.28.163:8080/styles/aiims/style.json';

  final List<Color> _brightColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.limeAccent,
    Colors.amberAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _loadGeoJsonFeatures();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await StyleReader(
        uri: styleUrl,
        logger: Logger.console(),
      ).read();

      setState(() {
        _theme = style.theme;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Error loading style: $e');
    }
  }

  Future<void> _loadGeoJsonFeatures() async {
    try {
      final data = await rootBundle.loadString('assets/points.geojson');
      final jsonData = json.decode(data);
      final features = jsonData['features'] as List<dynamic>;

      final markers = <_MarkerData>[];
      final polygons = <_PolygonData>[];

      int colorIndex = 0;

      for (final feature in features) {
        final geometry = feature['geometry'];
        final type = geometry['type'];

        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final name = properties['name'] ?? '';

        if (type == 'Point') {
          final pointType = properties['type'] ?? '';
          if (pointType != 'BP') {
            final coords = geometry['coordinates'] as List<dynamic>;
            final lat = coords[1] as double;
            final lng = coords[0] as double;

            markers.add(
              _MarkerData(
                point: LatLng(lat, lng),
                properties: properties,
              ),
            );
          }
        } else if (type == 'Polygon') {
          final coords = geometry['coordinates'][0] as List<dynamic>;
          final latLngs = coords.map<LatLng>((coord) {
            final lon = coord[0] as double;
            final lat = coord[1] as double;
            return LatLng(lat, lon);
          }).toList();

          final fillColorString = properties['fillColor'];
          Color fillColor;
          if (fillColorString != null && fillColorString.isNotEmpty) {
            fillColor = _parseColor(fillColorString);
          } else {
            fillColor = _brightColors[colorIndex % _brightColors.length];
            colorIndex++;
          }

          polygons.add(
            _PolygonData(
              points: latLngs,
              color: fillColor.withOpacity(0.5),
              borderColor: Colors.black,
              borderStrokeWidth: 1.0,
              properties: properties,
            ),
          );
        }
      }

      setState(() {
        _geojsonMarkers = markers;
        _geojsonPolygons = polygons;
      });
    } catch (e) {
      debugPrint('Error loading GeoJSON features: $e');
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // add opacity if missing
    return Color(int.parse(hex, radix: 16));
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      final a = polygon[j];
      final b = polygon[j + 1];
      if (((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude) /
              (b.latitude - a.latitude) + a.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _theme == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vector Tiles + GeoJSON Points & Polygons')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(32.56497, 75.03575),
          initialZoom: 14,
          minZoom: 10,
          maxZoom: 21,
          onTap: (tapPosition, point) {
            bool polygonTapped = false;

            // Check polygons first
            for (int i = 0; i < _geojsonPolygons.length; i++) {
              if (_isPointInPolygon(point, _geojsonPolygons[i].points)) {
                setState(() {
                  _selectedPolygonIndex = i;
                  _selectedMarkerIndex = null;
                });
                print('Selected Polygon Properties: ${_geojsonPolygons[i].properties}');
                polygonTapped = true;
                return;
              }
            }

            // Check nearest marker within threshold
            double thresholdDistance = 30.0; // meters
            int? nearestMarkerIndex;
            double nearestDistance = double.infinity;

            for (int i = 0; i < _geojsonMarkers.length; i++) {
              final markerPoint = _geojsonMarkers[i].point;
              final distance = Distance().as(LengthUnit.Meter, point, markerPoint);
              if (distance < thresholdDistance && distance < nearestDistance) {
                nearestMarkerIndex = i;
                nearestDistance = distance;
              }
            }

            if (nearestMarkerIndex != null) {
              setState(() {
                _selectedMarkerIndex = nearestMarkerIndex;
                _selectedPolygonIndex = null;
              });
              print('Selected Marker Properties: ${_geojsonMarkers[nearestMarkerIndex].properties}');
            } else {
              // Tapped empty space
              setState(() {
                _selectedPolygonIndex = null;
                _selectedMarkerIndex = null;
              });
            }
          },
        ),
        children: [
          VectorTileLayer(
            theme: _theme!,
            tileProviders: TileProviders({
              'combined_with_layers': NetworkVectorTileProvider(
                urlTemplate: 'http://10.184.28.163:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
                maximumZoom: 21,
              ),
            }),
          ),
          PolygonLayer(
            polygons: _geojsonPolygons.asMap().entries.map((entry) {
              final index = entry.key;
              final polyData = entry.value;
              final isSelected = index == _selectedPolygonIndex;
              return Polygon(
                points: polyData.points,
                color: isSelected
                    ? Colors.yellow.withOpacity(0.7)
                    : polyData.color,
                borderColor: isSelected
                    ? Colors.red
                    : polyData.borderColor,
                borderStrokeWidth: isSelected ? 3.0 : polyData.borderStrokeWidth,
              );
            }).toList(),
          ),
          MarkerLayer(
            markers: _geojsonMarkers.asMap().entries.map((entry) {
              final index = entry.key;
              final markerData = entry.value;
              final isSelected = index == _selectedMarkerIndex;
              return Marker(
                point: markerData.point,
                width: 80,
                height: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: isSelected ? Colors.green : Colors.red,
                      size: isSelected ? 40 : 30,
                    ),
                    Flexible(
                      child: Text(
                        markerData.properties['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PolygonData {
  final List<LatLng> points;
  final Color color;
  final Color borderColor;
  final double borderStrokeWidth;
  final Map<String, dynamic> properties;

  _PolygonData({
    required this.points,
    required this.color,
    required this.borderColor,
    required this.borderStrokeWidth,
    required this.properties,
  });
}

class _MarkerData {
  final LatLng point;
  final Map<String, dynamic> properties;

  _MarkerData({
    required this.point,
    required this.properties,
  });
}*/
/*import 'dart:convert';
import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

class ServerVectorMap extends StatefulWidget {
  const ServerVectorMap({super.key});

  @override
  State<ServerVectorMap> createState() => _ServerVectorMapState();
}

class _ServerVectorMapState extends State<ServerVectorMap> {
  Theme? _theme;
  bool _loaded = false;

  List<_MarkerData> _geojsonMarkers = [];
  List<_PolygonData> _geojsonPolygons = [];
  int? _selectedPolygonIndex;
  _MarkerData? _selectedMarker;

  double _currentZoom = 14.0;
  final double _minZoomForMarkers = 16.0;

  final String styleUrl = 'http://192.168.1.6:8080/styles/aiims/style.json';

  final List<Color> _brightColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.limeAccent,
    Colors.amberAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _loadGeoJsonFeatures();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await StyleReader(
        uri: styleUrl,
        logger: Logger.console(),
      ).read();

      setState(() {
        _theme = style.theme;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Error loading style: $e');
    }
  }

  Future<void> _loadGeoJsonFeatures() async {
    try {
      final data = await rootBundle.loadString('assets/points.geojson');
      final jsonData = json.decode(data);
      final features = jsonData['features'] as List<dynamic>;

      final markers = <_MarkerData>[];
      final polygons = <_PolygonData>[];

      int colorIndex = 0;

      for (final feature in features) {
        final geometry = feature['geometry'];
        final type = geometry['type'];

        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final name = properties['name'] ?? '';

        if (type == 'Point') {
          final pointType = properties['type'] ?? '';
          if (pointType != 'BP') {
            final coords = geometry['coordinates'] as List<dynamic>;
            final lat = coords[1] as double;
            final lng = coords[0] as double;

            markers.add(
              _MarkerData(
                point: LatLng(lat, lng),
                properties: properties,
              ),
            );
          }
        } else if (type == 'Polygon') {
          final coords = geometry['coordinates'][0] as List<dynamic>;
          final latLngs = coords.map<LatLng>((coord) {
            final lon = coord[0] as double;
            final lat = coord[1] as double;
            return LatLng(lat, lon);
          }).toList();

          final fillColorString = properties['fillColor'];
          Color fillColor;
          if (fillColorString != null && fillColorString.isNotEmpty) {
            fillColor = _parseColor(fillColorString);
          } else {
            fillColor = _brightColors[colorIndex % _brightColors.length];
            colorIndex++;
          }

          polygons.add(
            _PolygonData(
              points: latLngs,
              color: fillColor.withOpacity(0.5),
              borderColor: Colors.black,
              borderStrokeWidth: 1.0,
              properties: properties,
            ),
          );
        }
      }

      setState(() {
        _geojsonMarkers = markers;
        _geojsonPolygons = polygons;
      });
    } catch (e) {
      debugPrint('Error loading GeoJSON features: $e');
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // add opacity if missing
    return Color(int.parse(hex, radix: 16));
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      final a = polygon[j];
      final b = polygon[j + 1];
      if (((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude) /
              (b.latitude - a.latitude) + a.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  Widget _buildMarker(_MarkerData markerData, bool isSelected) {
    return SizedBox(
      width: 120,
      height: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: isSelected ? Colors.green : Colors.red,
            size: isSelected ? 40 : 30,
          ),
          if (markerData.properties['name'] != null &&
              markerData.properties['name'].toString().isNotEmpty)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 110),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  markerData.properties['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClusterMarker() {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.red, // Changed from Colors.blue.shade600 to Colors.red
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  void _onMarkerTap(_MarkerData markerData) {
    setState(() {
      _selectedMarker = markerData;
      _selectedPolygonIndex = null;
    });
    print('Selected Marker Properties: ${markerData.properties}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _theme == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vector Tiles + Clustered GeoJSON Points'),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(32.56497, 75.03575),
          initialZoom: 14,
          minZoom: 10,
          maxZoom: 21,
          onPositionChanged: (MapCamera position, bool hasGesture) {
            setState(() {
              _currentZoom = position.zoom;
            });
          },
          onTap: (tapPosition, point) {
            // Check polygons first
            for (int i = 0; i < _geojsonPolygons.length; i++) {
              if (_isPointInPolygon(point, _geojsonPolygons[i].points)) {
                setState(() {
                  _selectedPolygonIndex = i;
                  _selectedMarker = null;
                });
                print('Selected Polygon Properties: ${_geojsonPolygons[i].properties}');
                return;
              }
            }

            // If no polygon was tapped, clear selection
            setState(() {
              _selectedPolygonIndex = null;
              _selectedMarker = null;
            });
          },
        ),
        children: [
          VectorTileLayer(
            theme: _theme!,
            tileProviders: TileProviders({
              'combined_with_layers': NetworkVectorTileProvider(
                urlTemplate: 'http://192.168.1.6:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
                maximumZoom: 21,
              ),
            }),
          ),
          PolygonLayer(
            polygons: _geojsonPolygons.asMap().entries.map((entry) {
              final index = entry.key;
              final polyData = entry.value;
              final isSelected = index == _selectedPolygonIndex;
              return Polygon(
                points: polyData.points,
                color: isSelected
                    ? Colors.yellow.withOpacity(0.7)
                    : polyData.color,
                borderColor: isSelected
                    ? Colors.red
                    : polyData.borderColor,
                borderStrokeWidth: isSelected ? 3.0 : polyData.borderStrokeWidth,
              );
            }).toList(),
          ),
          // Only show markers when zoom level is 16 or higher
          if (_currentZoom >= _minZoomForMarkers)
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(35, 35), // Size for cluster marker
                markers: _geojsonMarkers.map((markerData) {
                  final isSelected = _selectedMarker == markerData;
                  return Marker(
                    width: 120,
                    height: 80, // Increased height to prevent overflow
                    point: markerData.point,
                    child: GestureDetector(
                      onTap: () => _onMarkerTap(markerData),
                      child: _buildMarker(markerData, isSelected),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  // Return a single marker icon instead of numbered cluster
                  return _buildClusterMarker();
                },
                onClusterTap: (cluster) {
                  // Extract marker data from the cluster
                  List<_MarkerData> markerDataList = [];
                  for (final marker in cluster.markers) {
                    final markerData = _geojsonMarkers.firstWhere(
                          (data) => data.point == marker.point,
                      orElse: () => _MarkerData(point: marker.point, properties: {}),
                    );
                    markerDataList.add(markerData);
                  }

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Cluster (${cluster.markers.length} markers)'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 300,
                          child: ListView.builder(
                            itemCount: markerDataList.length,
                            itemBuilder: (context, index) {
                              final markerData = markerDataList[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.red),
                                title: Text(markerData.properties['name'] ?? 'Unnamed'),
                                subtitle: Text(
                                  'Lat: ${markerData.point.latitude.toStringAsFixed(6)}, '
                                      'Lng: ${markerData.point.longitude.toStringAsFixed(6)}',
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedMarker = markerData;
                                    _selectedPolygonIndex = null;
                                  });
                                  print('Selected Marker Properties: ${markerData.properties}');
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PolygonData {
  final List<LatLng> points;
  final Color color;
  final Color borderColor;
  final double borderStrokeWidth;
  final Map<String, dynamic> properties;

  _PolygonData({
    required this.points,
    required this.color,
    required this.borderColor,
    required this.borderStrokeWidth,
    required this.properties,
  });
}

class _MarkerData {
  final LatLng point;
  final Map<String, dynamic> properties;

  _MarkerData({
    required this.point,
    required this.properties,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _MarkerData &&
              runtimeType == other.runtimeType &&
              point == other.point &&
              properties.toString() == other.properties.toString();

  @override
  int get hashCode => point.hashCode ^ properties.toString().hashCode;
}*/

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

// Enum for selection mode
enum SelectionMode { normal, selectingSource, selectingDestination }

class ServerVectorMap extends StatefulWidget {
  const ServerVectorMap({super.key});

  @override
  State<ServerVectorMap> createState() => _ServerVectorMapState();
}

class _ServerVectorMapState extends State<ServerVectorMap> {
  Theme? _theme;
  bool _loaded = false;

  List<_MarkerData> _geojsonMarkers = [];
  List<_PolygonData> _geojsonPolygons = [];
  int? _selectedPolygonIndex;
  _MarkerData? _selectedMarker;

  // New properties for pathfinding
  SelectionMode _selectionMode = SelectionMode.normal;
  _MarkerData? _sourceMarker;
  _MarkerData? _destinationMarker;
  List<LatLng> _shortestPath = [];
  double? _shortestDistance;
  double? _estimatedTime; // New property for time calculation
  Map<String, List<String>> _graphEdges = {};

  // New property for landmark counting
  int _landmarksOnPath = 0;
  List<_MarkerData> _pathLandmarks = [];

  double _currentZoom = 14.0;
  final double _minZoomForMarkers = 16.0;

  // Average human walking speed in meters per second (1.4 m/s = 5 km/h)
  static const double _averageWalkingSpeed = 1.4;

  final String styleUrl = 'http://172.18.32.1:8080/styles/aiims/style.json';

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _loadGeoJsonFeatures();
    _loadGraphData();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await StyleReader(
        uri: styleUrl,
        logger: Logger.console(),
      ).read();

      setState(() {
        _theme = style.theme;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Error loading style: $e');
    }
  }

  Future<void> _loadGraphData() async {
    try {
      final data = await rootBundle.loadString('assets/mastergraphAiimsJ.json');
      final jsonData = json.decode(data);
      final edges = jsonData['edges'] as Map<String, dynamic>;

      setState(() {
        _graphEdges = edges.map((key, value) => MapEntry(key, List<String>.from(value)));
      });

      debugPrint('Loaded graph with ${_graphEdges.length} nodes');
    } catch (e) {
      debugPrint('Error loading graph data: $e');
    }
  }

  Future<void> _loadGeoJsonFeatures() async {
    try {
      final data = await rootBundle.loadString('assets/points.geojson');
      final jsonData = json.decode(data);
      final features = jsonData['features'] as List<dynamic>;

      final markers = <_MarkerData>[];
      final polygons = <_PolygonData>[];

      int colorIndex = 0;

      for (final feature in features) {
        final geometry = feature['geometry'];
        final type = geometry['type'];

        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final name = properties['name'] ?? '';

        if (type == 'Point') {
          final pointType = properties['type'] ?? '';
          if (pointType != 'BP') {
            final coords = geometry['coordinates'] as List<dynamic>;
            final lat = coords[1] as double;
            final lng = coords[0] as double;

            markers.add(
              _MarkerData(
                point: LatLng(lat, lng),
                properties: properties,
              ),
            );
          }
        } else if (type == 'Polygon') {
          final coords = geometry['coordinates'][0] as List<dynamic>;
          final latLngs = coords.map<LatLng>((coord) {
            final lon = coord[0] as double;
            final lat = coord[1] as double;
            return LatLng(lat, lon);
          }).toList();

          final fillColorString = properties['fillColor'];
          Color fillColor;
          if (fillColorString != null && fillColorString.isNotEmpty) {
            fillColor = _parseColor(fillColorString);
          } else {
            return;
          }

          polygons.add(
            _PolygonData(
              points: latLngs,
              color: fillColor.withOpacity(0.5),
              borderColor: Colors.black,
              borderStrokeWidth: 1.0,
              properties: properties,
            ),
          );
        }
      }

      setState(() {
        _geojsonMarkers = markers;
        _geojsonPolygons = polygons;
      });
    } catch (e) {
      debugPrint('Error loading GeoJSON features: $e');
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // add opacity if missing
    return Color(int.parse(hex, radix: 16));
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      final a = polygon[j];
      final b = polygon[j + 1];
      if (((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude) /
              (b.latitude - a.latitude) + a.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  // Find the closest graph node to a given point
  String? _findClosestGraphNode(LatLng point) {
    String? closestNode;
    double minDistance = double.infinity;

    for (String nodeKey in _graphEdges.keys) {
      final parts = nodeKey.split(',');
      if (parts.length >= 2) {
        final nodeLng = double.tryParse(parts[0]);
        final nodeLat = double.tryParse(parts[1]);

        if (nodeLng != null && nodeLat != null) {
          final nodePoint = LatLng(nodeLat, nodeLng);
          final distance = _calculateDistance(point, nodePoint);

          if (distance < minDistance) {
            minDistance = distance;
            closestNode = nodeKey;
          }
        }
      }
    }

    return closestNode;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c * 1000; // Return distance in meters
  }

  // Convert node key to LatLng
  LatLng? _nodeKeyToLatLng(String nodeKey) {
    final parts = nodeKey.split(',');
    if (parts.length >= 2) {
      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lng != null && lat != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  // Helper method to format time duration
  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(0)} sec';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).floor();
      if (remainingSeconds == 0) {
        return '${minutes} min';
      } else {
        return '${minutes} min ${remainingSeconds} sec';
      }
    } else {
      final hours = (seconds / 3600).floor();
      final remainingMinutes = ((seconds % 3600) / 60).floor();
      if (remainingMinutes == 0) {
        return '${hours} hr';
      } else {
        return '${hours} hr ${remainingMinutes} min';
      }
    }
  }

  // New method to count landmarks along the path
  void _countLandmarksOnPath() {
    if (_shortestPath.isEmpty) {
      setState(() {
        _landmarksOnPath = 0;
        _pathLandmarks = [];
      });
      return;
    }

    List<_MarkerData> landmarksOnPath = [];
    const double proximityThreshold = 50.0; // meters - adjust as needed

    for (_MarkerData marker in _geojsonMarkers) {
      // Skip source and destination markers
      if (marker == _sourceMarker || marker == _destinationMarker) {
        continue;
      }

      // Check if marker is close to any point on the path
      bool isOnPath = false;
      for (LatLng pathPoint in _shortestPath) {
        double distance = _calculateDistance(marker.point, pathPoint);
        if (distance <= proximityThreshold) {
          isOnPath = true;
          break;
        }
      }

      if (isOnPath) {
        landmarksOnPath.add(marker);
      }
    }

    setState(() {
      _landmarksOnPath = landmarksOnPath.length;
      _pathLandmarks = landmarksOnPath;
    });

    debugPrint('Found ${_landmarksOnPath} landmarks on path');
    for (var landmark in _pathLandmarks) {
      debugPrint('- ${landmark.properties['name'] ?? 'Unnamed'}');
    }
  }

  // Dijkstra's algorithm for shortest path
  List<String>? _findShortestPath(String startNode, String endNode) {
    if (!_graphEdges.containsKey(startNode) || !_graphEdges.containsKey(endNode)) {
      return null;
    }

    Map<String, double> distances = {};
    Map<String, String?> previous = {};
    Set<String> unvisited = {};

    // Initialize distances
    for (String node in _graphEdges.keys) {
      distances[node] = double.infinity;
      previous[node] = null;
      unvisited.add(node);
    }
    distances[startNode] = 0;

    while (unvisited.isNotEmpty) {
      // Find unvisited node with minimum distance
      String currentNode = unvisited.reduce((a, b) =>
      distances[a]! < distances[b]! ? a : b);

      if (distances[currentNode] == double.infinity) break;

      unvisited.remove(currentNode);

      if (currentNode == endNode) break;

      // Check neighbors
      if (_graphEdges.containsKey(currentNode)) {
        for (String neighbor in _graphEdges[currentNode]!) {
          if (unvisited.contains(neighbor)) {
            final currentLatLng = _nodeKeyToLatLng(currentNode);
            final neighborLatLng = _nodeKeyToLatLng(neighbor);

            if (currentLatLng != null && neighborLatLng != null) {
              final distance = _calculateDistance(currentLatLng, neighborLatLng);
              final tentativeDistance = distances[currentNode]! + distance;

              if (tentativeDistance < distances[neighbor]!) {
                distances[neighbor] = tentativeDistance;
                previous[neighbor] = currentNode;
              }
            }
          }
        }
      }
    }

    // Reconstruct path
    List<String> path = [];
    String? currentNode = endNode;

    while (currentNode != null) {
      path.insert(0, currentNode);
      currentNode = previous[currentNode];
    }

    return path.isNotEmpty && path.first == startNode ? path : null;
  }

  void _calculateShortestPath() {
    if (_sourceMarker == null || _destinationMarker == null) return;

    final sourceNode = _findClosestGraphNode(_sourceMarker!.point);
    final destNode = _findClosestGraphNode(_destinationMarker!.point);

    if (sourceNode == null || destNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find path nodes')),
      );
      return;
    }

    final pathNodes = _findShortestPath(sourceNode, destNode);

    if (pathNodes == null || pathNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No path found between selected points')),
      );
      return;
    }

    // Convert path nodes to LatLng points and calculate distance
    List<LatLng> pathPoints = [];
    double totalDistance = 0.0;

    for (int i = 0; i < pathNodes.length; i++) {
      final point = _nodeKeyToLatLng(pathNodes[i]);
      if (point != null) {
        pathPoints.add(point);
        if (i > 0) {
          totalDistance += _calculateDistance(pathPoints[i-1], pathPoints[i]);
        }
      }
    }

    // Calculate estimated walking time
    final estimatedTimeSeconds = totalDistance / _averageWalkingSpeed;

    setState(() {
      _shortestPath = pathPoints;
      _shortestDistance = totalDistance;
      _estimatedTime = estimatedTimeSeconds;
    });

    // Count landmarks on the path after setting the path
    _countLandmarksOnPath();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Path found: ${totalDistance.toStringAsFixed(1)} m (${_formatTime(estimatedTimeSeconds)}) - ${_landmarksOnPath} landmarks'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Show marker selection dialog
  void _showMarkerSelectionDialog({required bool isSource}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select ${isSource ? 'Source' : 'Destination'}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: _geojsonMarkers.length,
              itemBuilder: (context, index) {
                final marker = _geojsonMarkers[index];
                final name = marker.properties['name'] ?? 'Unnamed Location';
                final isSelected = isSource ? (_sourceMarker == marker) : (_destinationMarker == marker);

                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: isSelected ? (isSource ? Colors.green : Colors.blue) : Colors.grey,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? (isSource ? Colors.green : Colors.blue) : null,
                    ),
                  ),
                  subtitle: Text(
                    'Lat: ${marker.point.latitude.toStringAsFixed(4)}, Lng: ${marker.point.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: isSource ? Colors.green : Colors.blue) : null,
                  onTap: () {
                    setState(() {
                      if (isSource) {
                        _sourceMarker = marker;
                      } else {
                        _destinationMarker = marker;
                      }
                      _shortestPath.clear();
                      _shortestDistance = null;
                      _estimatedTime = null;
                      _landmarksOnPath = 0;
                      _pathLandmarks = [];
                    });
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isSource ? 'Source' : 'Destination'} selected: $name'),
                        backgroundColor: isSource ? Colors.green : Colors.blue,
                      ),
                    );

                    // Auto-calculate path if both source and destination are selected
                    if (_sourceMarker != null && _destinationMarker != null) {
                      _calculateShortestPath();
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Show selection options dialog
  void _showSelectionOptionsDialog({required bool isSource}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select ${isSource ? 'Source' : 'Destination'} From'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: const Text('Marker List'),
                subtitle: const Text('Choose from available markers'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showMarkerSelectionDialog(isSource: isSource);
                },
              ),
              ListTile(
                leading: const Icon(Icons.touch_app, color: Colors.green),
                title: const Text('Tap on Map'),
                subtitle: const Text('Select by tapping markers on map'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _selectionMode = isSource ? SelectionMode.selectingSource : SelectionMode.selectingDestination;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tap a marker on the map to select as ${isSource ? 'source' : 'destination'}'),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // New method to show landmarks list dialog
  void _showLandmarksDialog() {
    if (_pathLandmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No landmarks found on current path')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Landmarks on Path (${_landmarksOnPath})'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: _pathLandmarks.length,
              itemBuilder: (context, index) {
                final landmark = _pathLandmarks[index];
                final name = landmark.properties['name'] ?? 'Unnamed Location';

                return ListTile(
                  leading: const Icon(Icons.place, color: Colors.orange),
                  title: Text(name),
                  subtitle: Text(
                    'Lat: ${landmark.point.latitude.toStringAsFixed(4)}, Lng: ${landmark.point.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    // You could add functionality to focus on this landmark on the map
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Landmark: $name')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMarker(_MarkerData markerData, bool isSelected) {
    Color markerColor = Colors.red;
    double markerSize = 30;

    if (markerData == _sourceMarker) {
      markerColor = Colors.green;
      markerSize = 35;
    } else if (markerData == _destinationMarker) {
      markerColor = Colors.blue;
      markerSize = 35;
    } else if (_pathLandmarks.contains(markerData)) {
      markerColor = Colors.orange;
      markerSize = 32;
    } else if (isSelected) {
      markerColor = Colors.orange;
      markerSize = 35;
    }

    return SizedBox(
      width: 120,
      height: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: markerColor,
            size: markerSize,
          ),
          if (markerData.properties['name'] != null &&
              markerData.properties['name'].toString().isNotEmpty)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 110),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  markerData.properties['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClusterMarker() {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  void _onMarkerTap(_MarkerData markerData) {
    if (_selectionMode == SelectionMode.selectingSource) {
      setState(() {
        _sourceMarker = markerData;
        _selectionMode = SelectionMode.normal;
        _shortestPath.clear();
        _shortestDistance = null;
        _estimatedTime = null;
        _landmarksOnPath = 0;
        _pathLandmarks = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source selected: ${markerData.properties['name'] ?? 'Unnamed'}')),
      );
    } else if (_selectionMode == SelectionMode.selectingDestination) {
      setState(() {
        _destinationMarker = markerData;
        _selectionMode = SelectionMode.normal;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destination selected: ${markerData.properties['name'] ?? 'Unnamed'}')),
      );
      _calculateShortestPath();
    } else {
      setState(() {
        _selectedMarker = markerData;
        _selectedPolygonIndex = null;
      });
      print('Selected Marker Properties: ${markerData.properties}');
    }
  }

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pathfinding Controls',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSelectionOptionsDialog(isSource: true),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Source', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSelectionOptionsDialog(isSource: false),
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text('Dest', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sourceMarker = null;
                      _destinationMarker = null;
                      _shortestPath.clear();
                      _shortestDistance = null;
                      _estimatedTime = null;
                      _landmarksOnPath = 0;
                      _pathLandmarks = [];
                      _selectionMode = SelectionMode.normal;
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.white),
                  label: const Text('Clear', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (_sourceMarker != null || _destinationMarker != null) ...[
            const SizedBox(height: 8),
            if (_sourceMarker != null)
              Text(
                'Source: ${_sourceMarker!.properties['name'] ?? 'Unnamed'}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            if (_destinationMarker != null)
              Text(
                'Destination: ${_destinationMarker!.properties['name'] ?? 'Unnamed'}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
              ),
            if (_shortestDistance != null)
              Text(
                'Distance: ${_shortestDistance!.toStringAsFixed(1)} m',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            if (_estimatedTime != null)
              Text(
                'Estimated Time: ${_formatTime(_estimatedTime!)}',
                style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
              ),
            if (_landmarksOnPath > 0) ...[
              GestureDetector(
                onTap: _showLandmarksDialog,
                child: Text(
                  'Landmarks: $_landmarksOnPath (tap to view)',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _theme == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vector Tiles + Pathfinding'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(32.56497, 75.03575),
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 21,
              onPositionChanged: (MapCamera position, bool hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              },
              onTap: (tapPosition, point) {
                if (_selectionMode != SelectionMode.normal) return;

                // Check polygons first
                for (int i = 0; i < _geojsonPolygons.length; i++) {
                  if (_isPointInPolygon(point, _geojsonPolygons[i].points)) {
                    setState(() {
                      _selectedPolygonIndex = i;
                      _selectedMarker = null;
                    });
                    print('Selected Polygon Properties: ${_geojsonPolygons[i].properties}');
                    return;
                  }
                }

                // If no polygon was tapped, clear selection
                setState(() {
                  _selectedPolygonIndex = null;
                  _selectedMarker = null;
                });
              },
            ),
            children: [
              VectorTileLayer(
                theme: _theme!,
                tileProviders: TileProviders({
                  'combined_with_layers': NetworkVectorTileProvider(
                    urlTemplate: 'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
                    maximumZoom: 21,
                  ),
                }),
              ),
              // Shortest path polyline
              if (_shortestPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _shortestPath,
                      strokeWidth: 4.0,
                      color: Colors.red,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              PolygonLayer(
                polygons: _geojsonPolygons.asMap().entries.map((entry) {
                  final index = entry.key;
                  final polyData = entry.value;
                  final isSelected = index == _selectedPolygonIndex;
                  return Polygon(
                    points: polyData.points,
                    color: isSelected
                        ? Colors.yellow.withOpacity(0.7)
                        : polyData.color,
                    borderColor: isSelected
                        ? Colors.red
                        : polyData.borderColor,
                    borderStrokeWidth: isSelected ? 3.0 : polyData.borderStrokeWidth,
                  );
                }).toList(),
              ),
              // Only show markers when zoom level is 16 or higher
              if (_currentZoom >= _minZoomForMarkers)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(35, 35),
                    markers: _geojsonMarkers.map((markerData) {
                      final isSelected = _selectedMarker == markerData;
                      return Marker(
                        width: 120,
                        height: 80,
                        point: markerData.point,
                        child: GestureDetector(
                          onTap: () => _onMarkerTap(markerData),
                          child: _buildMarker(markerData, isSelected),
                        ),
                      );
                    }).toList(),
                    builder: (context, markers) {
                      return _buildClusterMarker();
                    },
                    onClusterTap: (cluster) {
                      List<_MarkerData> markerDataList = [];
                      for (final marker in cluster.markers) {
                        final markerData = _geojsonMarkers.firstWhere(
                              (data) => data.point == marker.point,
                          orElse: () => _MarkerData(point: marker.point, properties: {}),
                        );
                        markerDataList.add(markerData);
                      }

                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Cluster (${cluster.markers.length} markers)'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 300,
                              child: ListView.builder(
                                itemCount: markerDataList.length,
                                itemBuilder: (context, index) {
                                  final markerData = markerDataList[index];
                                  return ListTile(
                                    leading: const Icon(Icons.location_on, color: Colors.red),
                                    title: Text(markerData.properties['name'] ?? 'Unnamed'),
                                    subtitle: Text(
                                      'Lat: ${markerData.point.latitude.toStringAsFixed(6)}, '
                                          'Lng: ${markerData.point.longitude.toStringAsFixed(6)}',
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _onMarkerTap(markerData);
                                    },
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          // Control panel overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildControlPanel(),
          ),
          // Selection mode indicator
          if (_selectionMode != SelectionMode.normal)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectionMode == SelectionMode.selectingSource
                      ? Colors.green.withOpacity(0.9)
                      : Colors.blue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectionMode == SelectionMode.selectingSource
                      ? 'Tap a marker to select as SOURCE'
                      : 'Tap a marker to select as DESTINATION',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PolygonData {
  final List<LatLng> points;
  final Color color;
  final Color borderColor;
  final double borderStrokeWidth;
  final Map<String, dynamic> properties;

  _PolygonData({
    required this.points,
    required this.color,
    required this.borderColor,
    required this.borderStrokeWidth,
    required this.properties,
  });
}

class _MarkerData {
  final LatLng point;
  final Map<String, dynamic> properties;

  _MarkerData({
    required this.point,
    required this.properties,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _MarkerData &&
              runtimeType == other.runtimeType &&
              point == other.point &&
              properties.toString() == other.properties.toString();

  @override
  int get hashCode => point.hashCode ^ properties.toString().hashCode;
}





