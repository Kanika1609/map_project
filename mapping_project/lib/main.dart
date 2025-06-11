// main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class FloorMarker {
  final LatLng point;
  final int floor;
  final String name;
  FloorMarker(this.point, this.floor, this.name);
}

class FloorPolygon {
  final List<List<LatLng>> pointsList;
  final int floor;
  final String subtype;
  FloorPolygon(this.pointsList, this.floor, this.subtype);
}

class FloorPolyline {
  final List<LatLng> points;
  final int floor;
  final String subtype;
  FloorPolyline(this.points, this.floor, this.subtype);
}

int parseFloor(dynamic floorValue) {
  if (floorValue == null) return 0;
  if (floorValue is int) return floorValue;
  if (floorValue is String) {
    switch (floorValue.toLowerCase()) {
      case 'ground':
      case '0':
        return 0;
      case 'first':
      case '1':
        return 1;
      case 'second':
      case '2':
        return 2;
      case 'third':
      case '3':
        return 3;
      case 'fourth':
      case '4':
        return 4;
      case 'fifth':
      case '5':
        return 5;
      case 'sixth':
      case '6':
        return 6;
      default:
        return 0;
    }
  }
  return 0;
}

Future<List<FloorMarker>> loadLandmarkPoints() async {
  final raw = await rootBundle.loadString('assets/landmarks_output.geojson');
  final Map<String, dynamic> data = jsonDecode(raw);
  List<FloorMarker> points = [];

  if (data['features'] != null) {
    for (final feature in data['features']) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry != null &&
          geometry['type'] == 'Point' &&
          properties != null) {
        final coords = geometry['coordinates'];
        final floor = parseFloor(properties['floor']);
        final name = properties['name'] ?? 'Unknown';
        points.add(FloorMarker(LatLng(coords[1], coords[0]), floor, name));
      }
    }
  }
  return points;
}

Future<List<FloorPolygon>> loadPolygonsFromLineStrings() async {
  final raw = await rootBundle.loadString('assets/polyline_output.geojson');
  final Map<String, dynamic> data = jsonDecode(raw);
  List<FloorPolygon> polygons = [];

  if (data['features'] != null) {
    for (final feature in data['features']) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry != null &&
          geometry['type'] == 'LineString' &&
          properties != null) {
        final coords = geometry['coordinates'] as List<dynamic>;
        if (coords.isNotEmpty) {
          final first = coords.first;
          final last = coords.last;
          if (first[0] == last[0] && first[1] == last[1]) {
            final floor = parseFloor(properties['floor']);
            final subtype = (properties['polygonType'] ?? 'Unknown').toString();
            final polygonPoints = coords
                .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                .toList();
            polygons.add(FloorPolygon([polygonPoints], floor, subtype));
          }
        }
      }
    }
  }
  return polygons;
}

Color getColorForSubtype(String subtype) {
  final key = subtype.toLowerCase();
  final Map<String, Color> mapLower = {
    'cubicle': Colors.orange,
    'room': Colors.green,
    'waypoints': Colors.blueGrey,
    'unknown': Colors.grey,
  };
  return mapLower[key] ?? Colors.blue;
}

Color customDarkenColor(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

List<LatLng> computeConvexHull(List<LatLng> points) {
  final filteredPoints =
  points.where((p) => p.latitude != 0 && p.longitude != 0).toList();
  if (filteredPoints.length < 3) return filteredPoints;

  int leftMost = 0;
  for (int i = 1; i < filteredPoints.length; i++) {
    if (filteredPoints[i].longitude < filteredPoints[leftMost].longitude) {
      leftMost = i;
    }
  }

  List<LatLng> hull = [];
  int p = leftMost;
  do {
    hull.add(filteredPoints[p]);
    int q = (p + 1) % filteredPoints.length;
    for (int i = 0; i < filteredPoints.length; i++) {
      if (orientation(
          filteredPoints[p], filteredPoints[i], filteredPoints[q]) ==
          -1) {
        q = i;
      }
    }
    p = q;
  } while (p != leftMost);
  return hull;
}

int orientation(LatLng p, LatLng q, LatLng r) {
  final val = (q.longitude - p.longitude) * (r.latitude - q.latitude) -
      (q.latitude - p.latitude) * (r.longitude - q.longitude);
  if (val == 0) return 0;
  return (val > 0) ? 1 : -1;
}

List<LatLng> filterOutliers(List<LatLng> points, double maxDistanceMeters) {
  if (points.isEmpty) return [];
  final Distance distance = Distance();
  double avgLat =
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  double avgLng =
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
  final centroid = LatLng(avgLat, avgLng);
  final filtered =
  points.where((p) => distance(centroid, p) <= maxDistanceMeters).toList();
  return filtered.length >= 3 ? filtered : points;
}

bool isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
  int intersectCount = 0;
  for (int j = 0; j < polygon.length - 1; j++) {
    LatLng p1 = polygon[j];
    LatLng p2 = polygon[j + 1];

    if (((p1.latitude > point.latitude) != (p2.latitude > point.latitude)) &&
        (point.longitude <
            (p2.longitude - p1.longitude) *
                (point.latitude - p1.latitude) /
                (p2.latitude - p1.latitude) +
                p1.longitude)) {
      intersectCount++;
    }
  }
  return (intersectCount % 2) == 1;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  List<FloorMarker> _allFloorMarkers = [];
  List<FloorPolygon> _allFloorPolygons = [];
  int _selectedFloor = 0;
  final int _maxFloor = 6;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadData();
  }

  Future<void> _loadData() async {
    final points = await loadLandmarkPoints();
    final polygons = await loadPolygonsFromLineStrings();

    setState(() {
      _allFloorMarkers = points;
      _allFloorPolygons = polygons;
    });
  }

  List<Polygon> get _allArPolygons {
    List<Polygon> polygons = [];
    final floors = _allFloorMarkers.map((m) => m.floor).toSet();

    for (final floor in floors) {
      final arPoints = _allFloorMarkers
          .where((m) =>
      m.floor == floor && m.name.toLowerCase().startsWith('ar'))
          .map((m) => m.point)
          .toList();

      if (arPoints.length >= 3) {
        final filteredPoints = filterOutliers(arPoints, 100);
        final hullPoints = computeConvexHull(filteredPoints);

        polygons.add(
          Polygon(
            points: hullPoints,
            color: Colors.white,
            borderColor: Colors.black,
            borderStrokeWidth: 2,
          ),
        );
      }
    }
    return polygons;
  }

  List<Marker> get _filteredMarkers {
    final roomAndCubiclePolygons = _allFloorPolygons
        .where((p) =>
    p.floor == _selectedFloor &&
        (p.subtype.toLowerCase() == 'room' ||
            p.subtype.toLowerCase() == 'cubicle'))
        .toList();

    return _allFloorMarkers.where((m) {
      return roomAndCubiclePolygons.any((polygon) =>
          isPointInsidePolygon(m.point, polygon.pointsList.first));
    }).map((m) {
      return Marker(
        point: m.point,
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 30),
            Flexible(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(blurRadius: 3, color: Colors.black26)
                  ],
                ),
                child: Text(
                  m.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Polygon> get _filteredPolygons {
    return _allFloorPolygons
        .where((p) =>
    p.floor == _selectedFloor &&
        (p.subtype.toLowerCase() == 'room' ||
            p.subtype.toLowerCase() == 'cubicle'))
        .map((p) {
      final color = getColorForSubtype(p.subtype);
      return Polygon(
        points: p.pointsList.first,
        color: color.withOpacity(0.5),
        borderColor: customDarkenColor(color, 0.3),
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultCenter = _currentPosition ?? LatLng(51.5074, -0.1278);
    final floorsAvailable = List<int>.generate(_maxFloor + 1, (i) => i);

    return Scaffold(
      appBar: AppBar(
        title: Text('Floor ${_selectedFloor == 0 ? "Ground" : _selectedFloor} Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<int>(
              dropdownColor: Colors.blue,
              value: _selectedFloor,
              underline: const SizedBox(),
              iconEnabledColor: Colors.white,
              items: floorsAvailable.map((floor) {
                final label = floor == 0 ? 'Ground' : floor.toString();
                return DropdownMenuItem(
                  value: floor,
                  child: Text(
                    'Floor $label',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFloor = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: defaultCenter,
          initialZoom: 17,
          maxZoom: 22,
          minZoom: 3,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.mapping_project',
          ),
          PolygonLayer(polygons: _allArPolygons),
          PolygonLayer(polygons: _filteredPolygons),
          MarkerLayer(
            markers: [
              if (_currentPosition != null)
                Marker(
                  point: _currentPosition!,
                  width: 50,
                  height: 50,
                  child: Icon(Icons.my_location,
                      color: Colors.blue.shade700, size: 40),
                ),
              ..._filteredMarkers,
            ],
          ),
        ],
      ),
    );
  }
}
