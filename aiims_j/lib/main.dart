// import 'package:flutter/material.dart' hide Theme;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart';
//
// void main() {
//   runApp(const MaterialApp(home: VectorTileMap()));
// }
//
// class VectorTileMap extends StatefulWidget {
//   const VectorTileMap({super.key});
//
//   @override
//   State<VectorTileMap> createState() => _VectorTileMapState();
// }
//
// class _VectorTileMapState extends State<VectorTileMap> {
//   Theme? _theme;
//   final MapController _mapController = MapController();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   Future<void> _loadStyle() async {
//     try {
//       final style = await StyleReader(
//         uri: 'http://172.18.32.1:8080/styles/aiims/style.json',
//         logger: Logger.console(),
//       ).read();
//
//       setState(() {
//         _theme = style.theme;
//       });
//
//       debugPrint('Style loaded successfully');
//       debugPrint('Theme layers: ${_theme?.layers.length}');
//     } catch (e) {
//       debugPrint('Error loading style: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_theme == null) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Loading AIIMS Map...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("AIIMS Jammu Vector Map"),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(32.56497, 75.03575),
//               initialZoom: 17,
//               minZoom: 10,
//               maxZoom: 21,
//               onTap: (tapPosition, point) {
//                 debugPrint('Tapped at: ${point.latitude}, ${point.longitude}');
//               },
//             ),
//             children: [
//               VectorTileLayer(
//                 theme: _theme!,
//                 tileProviders: TileProviders({
//                   'combined_with_layers': NetworkVectorTileProvider(
//                     urlTemplate:
//                     'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
//                     maximumZoom: 21,
//                   ),
//                   'indooraiimsj': NetworkVectorTileProvider(
//                     urlTemplate:
//                     'http://172.18.32.1:8080/data/indooraiimsj/{z}/{x}/{y}.pbf',
//                     maximumZoom: 21,
//                   ),
//                 }),
//                 layerMode: VectorTileLayerMode.vector,
//               ),
//             ],
//           ),
//           // Informational label
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: const Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.layers, color: Colors.white, size: 16),
//                   SizedBox(width: 6),
//                   Text(
//                     'All Floors Visible',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _mapController.move(LatLng(32.56497, 75.03575), 17);
//         },
//         backgroundColor: Colors.blue.shade800,
//         child: const Icon(Icons.my_location, color: Colors.white),
//       ),
//     );
//   }
// }
//

// import 'package:flutter/material.dart' hide Theme;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart';
//
// void main() {
//   runApp(const MaterialApp(home: VectorTileMap()));
// }
//
// class VectorTileMap extends StatefulWidget {
//   const VectorTileMap({super.key});
//
//   @override
//   State<VectorTileMap> createState() => _VectorTileMapState();
// }
//
// class _VectorTileMapState extends State<VectorTileMap> {
//   Theme? _theme;
//   final MapController _mapController = MapController();
//
//   bool _showIndoorOnly = false; // false = combined, true = indoor only
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   Future<void> _loadStyle() async {
//     try {
//       final style = await StyleReader(
//         uri: 'http://172.18.32.1:8080/styles/aiims/style.json',
//         logger: Logger.console(),
//       ).read();
//
//       setState(() {
//         _theme = style.theme;
//       });
//
//       debugPrint('Style loaded successfully');
//       debugPrint('Theme layers: ${_theme?.layers.length}');
//     } catch (e) {
//       debugPrint('Error loading style: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_theme == null) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Loading AIIMS Map...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     // Only one tile provider at a time
//     final tileProviders = _showIndoorOnly
//         ? TileProviders({
//       'floor_6': NetworkVectorTileProvider(
//         urlTemplate:
//         'http://172.18.32.1:8080/data/floor_6/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//     })
//         : TileProviders({
//       'combined_with_layers': NetworkVectorTileProvider(
//         urlTemplate:
//         'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//     });
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("AIIMS Jammu Vector Map"),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(32.56497, 75.03575),
//               initialZoom: 17,
//               minZoom: 10,
//               maxZoom: 21,
//               onTap: (tapPosition, point) {
//                 debugPrint('Tapped at: ${point.latitude}, ${point.longitude}');
//               },
//             ),
//             children: [
//               VectorTileLayer(
//                 key: ValueKey(_showIndoorOnly), // Forces rebuild on toggle
//                 theme: _theme!,
//                 tileProviders: tileProviders,
//                 layerMode: VectorTileLayerMode.vector,
//               ),
//             ],
//           ),
//           // Informational label and toggle button
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.black87,
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.3),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         _showIndoorOnly ? Icons.home : Icons.layers,
//                         color: Colors.white,
//                         size: 16,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         _showIndoorOnly ? 'Indoor Only' : 'Combined Map',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue.shade800,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   ),
//                   icon: Icon(_showIndoorOnly ? Icons.layers : Icons.home),
//                   label: Text(_showIndoorOnly ? 'Show Combined' : 'Show Indoor Only'),
//                   onPressed: () {
//                     setState(() {
//                       _showIndoorOnly = !_showIndoorOnly;
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _mapController.move(LatLng(32.56497, 75.03575), 17);
//         },
//         backgroundColor: Colors.blue.shade800,
//         child: const Icon(Icons.my_location, color: Colors.white),
//       ),
//     );
//   }
// }
//

// import 'dart:convert';
// import 'package:flutter/material.dart' hide Theme;
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart';
//
// void main() {
//   runApp(const MaterialApp(home: VectorTileMap()));
// }
//
// // Helper classes for marker and polygon data
// class _MarkerData {
//   final LatLng point;
//   final Map<String, dynamic> properties;
//
//   _MarkerData({
//     required this.point,
//     required this.properties,
//   });
//
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//           other is _MarkerData &&
//               runtimeType == other.runtimeType &&
//               point == other.point &&
//               properties.toString() == other.properties.toString();
//
//   @override
//   int get hashCode => point.hashCode ^ properties.toString().hashCode;
// }
//
// class _PolygonData {
//   final List<LatLng> points;
//   final Map<String, dynamic> properties;
//
//   _PolygonData({
//     required this.points,
//     required this.properties,
//   });
// }
//
// class VectorTileMap extends StatefulWidget {
//   const VectorTileMap({super.key});
//
//   @override
//   State<VectorTileMap> createState() => _VectorTileMapState();
// }
//
// class _VectorTileMapState extends State<VectorTileMap> {
//   Theme? _theme;
//   final MapController _mapController = MapController();
//   int _currentFloor = 0;
//   final List<int> _floors = [-1, 0, 1, 2, 3, 4, 5, 6];
//   final Map<String, List<_MarkerData>> _geoJsonMarkers = {};
//   final Map<String, List<_PolygonData>> _geoJsonPolygons = {};
//   double _currentZoom = 17.0;
//
//   // Selection state
//   _MarkerData? _selectedMarker;
//   int? _selectedPolygonIndex;
//   String? _selectedPolygonFloor;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle().then((_) => _loadGeoJsonMarkers());
//   }
//
//   Future<void> _loadStyle() async {
//     try {
//       final style = await StyleReader(
//         uri: 'http://10.194.22.156:8080/styles/aiims/style.json',
//         logger: Logger.console(),
//       ).read();
//
//       setState(() {
//         _theme = style.theme;
//       });
//
//       debugPrint('Style loaded successfully');
//     } catch (e) {
//       debugPrint('Error loading style: $e');
//     }
//   }
//
//   Future<void> _loadGeoJsonMarkers() async {
//     final List<String> keys = [
//       'combined_with_layers',
//       'floor_-1',
//       'floor_0',
//       'floor_1',
//       'floor_2',
//       'floor_3',
//       'floor_4',
//       'floor_5',
//       'floor_6',
//     ];
//
//     for (final key in keys) {
//       try {
//         final String path = 'assets/$key.geojson';
//         final String data = await rootBundle.loadString(path);
//         final geojson = json.decode(data);
//
//         List<_MarkerData> markers = [];
//         List<_PolygonData> polygons = [];
//
//         for (var feature in geojson['features']) {
//           final geometry = feature['geometry'];
//           final properties = feature['properties'] ?? {};
//           final type = geometry['type'];
//
//           if (type == 'Point') {
//             final coords = geometry['coordinates'];
//             final name = properties['name'] ?? 'Landmark';
//             final pointType = properties['type'] ?? '';
//             final element = properties['element'] ?? {};
//             final subType = element['subType'] ?? '';
//
//             // Skip BP type points in combined_with_layers
//             if (key == 'combined_with_layers' && pointType == 'BP') {
//               continue;
//             }
//
//             // Skip subType=AR in floor_0
//             if (key == 'floor_0' && subType == 'AR') {
//               continue;
//             }
//
//             markers.add(
//               _MarkerData(
//                 point: LatLng(coords[1], coords[0]),
//                 properties: properties,
//               ),
//             );
//           } else if (type == 'Polygon') {
//             final coords = geometry['coordinates'][0] as List<dynamic>;
//             final latLngs = coords.map<LatLng>((coord) {
//               final lon = coord[0] as double;
//               final lat = coord[1] as double;
//               return LatLng(lat, lon);
//             }).toList();
//
//             polygons.add(
//               _PolygonData(
//                 points: latLngs,
//                 properties: properties,
//               ),
//             );
//           }
//         }
//
//         _geoJsonMarkers[key] = markers;
//         _geoJsonPolygons[key] = polygons;
//       } catch (e) {
//         debugPrint('Failed to load $key.geojson: $e');
//       }
//     }
//
//     setState(() {});
//   }
//
//   TileProviders _getTileProviders() {
//     return TileProviders({
//       'combined_with_layers': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_-1': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_-1/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_0': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_0/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_1': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_1/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_2': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_2/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_3': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_3/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_4': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_4/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_5': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_5/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//       'floor_6': NetworkVectorTileProvider(
//         urlTemplate: 'http://10.194.22.156:8080/data/floor_6/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//     });
//   }
//
//   Theme _getFilteredTheme() {
//     if (_theme == null) return Theme(id: 'filtered', version: '8', layers: []);
//     final suffix = _currentFloor == -1 ? '_-1' : '_$_currentFloor';
//
//     final filtered = _theme!.layers.where((layer) {
//       if (layer.id == 'background' || layer.id.startsWith('combined_with_layers')) {
//         return true;
//       }
//       return layer.id.startsWith('floor$suffix');
//     }).toList();
//
//     return Theme(id: 'filtered', version: '8', layers: filtered);
//   }
//
//   String _getFloorDisplayName(int floor) {
//     switch (floor) {
//       case -1:
//         return 'Basement';
//       case 0:
//         return 'Ground Floor';
//       default:
//         return 'Floor $floor';
//     }
//   }
//
//   // Improved point-in-polygon algorithm with better handling for edge cases
//   bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
//     if (polygon.length < 3) return false;
//
//     int intersectCount = 0;
//     final double x = point.longitude;
//     final double y = point.latitude;
//
//     for (int i = 0; i < polygon.length; i++) {
//       final j = (i + 1) % polygon.length;
//       final xi = polygon[i].longitude;
//       final yi = polygon[i].latitude;
//       final xj = polygon[j].longitude;
//       final yj = polygon[j].latitude;
//
//       if (((yi > y) != (yj > y)) &&
//           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
//         intersectCount++;
//       }
//     }
//
//     return (intersectCount % 2) == 1;
//   }
//
//   void _onMarkerTap(_MarkerData markerData) {
//     setState(() {
//       _selectedMarker = markerData;
//       _selectedPolygonIndex = null;
//       _selectedPolygonFloor = null;
//     });
//
//     // Show marker info
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Selected: ${markerData.properties['name'] ?? 'Unnamed Location'}'),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//
//     debugPrint('Selected Marker Properties: ${markerData.properties}');
//   }
//
//   void _onPolygonTap(int polygonIndex, String floorKey, _PolygonData polygonData) {
//     setState(() {
//       _selectedPolygonIndex = polygonIndex;
//       _selectedPolygonFloor = floorKey;
//       _selectedMarker = null;
//     });
//
//     // Show polygon info
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Selected Polygon: ${polygonData.properties['name'] ?? 'Unnamed Area'}'),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//
//     debugPrint('Selected Polygon Properties: ${polygonData.properties}');
//   }
//
//   Widget _buildMarker(_MarkerData markerData, bool isSelected) {
//     Color markerColor = isSelected ? Colors.orange : Colors.red;
//     double markerSize = isSelected ? 35 : 30;
//
//     return SizedBox(
//       width: 120,
//       height: 80,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.location_on,
//             color: markerColor,
//             size: markerSize,
//           ),
//           if (markerData.properties['name'] != null &&
//               markerData.properties['name'].toString().isNotEmpty)
//             Flexible(
//               child: Container(
//                 constraints: const BoxConstraints(maxWidth: 110),
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(color: Colors.grey.shade300, width: 1),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 3,
//                       offset: Offset(0, 1),
//                     ),
//                   ],
//                 ),
//                 child: Text(
//                   markerData.properties['name'] ?? '',
//                   style: const TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                   textAlign: TextAlign.center,
//                   maxLines: 2,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildClusterMarker(List<Marker> markers) {
//     return Container(
//       width: 35,
//       height: 35,
//       decoration: BoxDecoration(
//         color: Colors.red,
//         shape: BoxShape.circle,
//         border: Border.all(color: Colors.white, width: 2),
//         boxShadow: const [
//           BoxShadow(
//             color: Colors.black26,
//             blurRadius: 4,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: const Icon(
//         Icons.location_on,
//         color: Colors.white,
//         size: 20,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_theme == null) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Loading AIIMS Map Style...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     // Prepare markers for the current floor + combined layer (only show at zoom >= 15)
//     final markersForClustering = <Marker>[];
//     if (_currentZoom >= 15.0) {
//       final combinedMarkers = _geoJsonMarkers['combined_with_layers'] ?? [];
//       final floorMarkers = _geoJsonMarkers['floor_$_currentFloor'] ?? [];
//
//       // Convert _MarkerData to Marker widgets
//       for (final markerData in [...combinedMarkers, ...floorMarkers]) {
//         final isSelected = _selectedMarker == markerData;
//         markersForClustering.add(
//           Marker(
//             width: 120,
//             height: 80,
//             point: markerData.point,
//             child: GestureDetector(
//               onTap: () => _onMarkerTap(markerData),
//               child: _buildMarker(markerData, isSelected),
//             ),
//           ),
//         );
//       }
//     }
//
//     // Get polygons for current floor AND combined layers
//     final currentFloorKey = 'floor_$_currentFloor';
//     final floorPolygons = _geoJsonPolygons[currentFloorKey] ?? [];
//     final combinedPolygons = _geoJsonPolygons['combined_with_layers'] ?? [];
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("AIIMS Jammu Indoor Map"),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//         elevation: 2,
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(32.56497, 75.03575),
//               initialZoom: 17,
//               minZoom: 10,
//               maxZoom: 21,
//               onPositionChanged: (position, hasGesture) {
//                 setState(() {
//                   _currentZoom = position.zoom;
//                 });
//               },
//               onTap: (tapPosition, point) {
//                 debugPrint('Map tapped at: ${point.latitude}, ${point.longitude}');
//
//                 bool polygonTapped = false;
//
//                 // Check polygons from combined_with_layers first
//                 final combinedPolygons = _geoJsonPolygons['combined_with_layers'] ?? [];
//                 for (int i = 0; i < combinedPolygons.length; i++) {
//                   if (_isPointInPolygon(point, combinedPolygons[i].points)) {
//                     debugPrint('Combined layer polygon $i tapped!');
//                     _onPolygonTap(i, 'combined_with_layers', combinedPolygons[i]);
//                     polygonTapped = true;
//                     break;
//                   }
//                 }
//
//                 // If no combined polygon was tapped, check floor-specific polygons
//                 if (!polygonTapped) {
//                   final floorPolygons = _geoJsonPolygons[currentFloorKey] ?? [];
//                   for (int i = 0; i < floorPolygons.length; i++) {
//                     if (_isPointInPolygon(point, floorPolygons[i].points)) {
//                       debugPrint('Floor polygon $i tapped!');
//                       _onPolygonTap(i, currentFloorKey, floorPolygons[i]);
//                       polygonTapped = true;
//                       break;
//                     }
//                   }
//                 }
//
//                 // If no polygon was tapped, clear selection
//                 if (!polygonTapped) {
//                   debugPrint('No polygon tapped, clearing selection');
//                   setState(() {
//                     _selectedPolygonIndex = null;
//                     _selectedPolygonFloor = null;
//                     _selectedMarker = null;
//                   });
//                 }
//               },
//             ),
//             children: [
//               // Vector tile layer - this preserves the original MBTiles colors
//               VectorTileLayer(
//                 key: Key('floor_$_currentFloor'),
//                 theme: _getFilteredTheme(),
//                 tileProviders: _getTileProviders(),
//                 layerMode: VectorTileLayerMode.vector,
//               ),
//
//               // Selection overlay layer - only for highlighting selected polygons
//               // This layer uses transparent overlays to show selection without changing original colors
//               if (combinedPolygons.isNotEmpty || floorPolygons.isNotEmpty)
//                 PolygonLayer(
//                   polygons: [
//                     // Combined layer polygons - only show selection overlay
//                     ...combinedPolygons.asMap().entries.where((entry) {
//                       final index = entry.key;
//                       return index == _selectedPolygonIndex &&
//                           'combined_with_layers' == _selectedPolygonFloor;
//                     }).map((entry) {
//                       final polyData = entry.value;
//
//                       return Polygon(
//                         points: polyData.points,
//                         color: Colors.yellow.withOpacity(0.4), // Semi-transparent highlight
//                         borderColor: Colors.red,
//                         borderStrokeWidth: 3.0,
//                         isFilled: true,
//                       );
//                     }),
//                     // Floor-specific polygons - only show selection overlay
//                     ...floorPolygons.asMap().entries.where((entry) {
//                       final index = entry.key;
//                       return index == _selectedPolygonIndex &&
//                           currentFloorKey == _selectedPolygonFloor;
//                     }).map((entry) {
//                       final polyData = entry.value;
//
//                       return Polygon(
//                         points: polyData.points,
//                         color: Colors.yellow.withOpacity(0.4), // Semi-transparent highlight
//                         borderColor: Colors.red,
//                         borderStrokeWidth: 3.0,
//                         isFilled: true,
//                       );
//                     }),
//                   ],
//                 ),
//
//               // Marker clustering layer (only visible at zoom >= 15)
//               if (markersForClustering.isNotEmpty)
//                 MarkerClusterLayerWidget(
//                   options: MarkerClusterLayerOptions(
//                     maxClusterRadius: 45,
//                     size: const Size(35, 35),
//                     markers: markersForClustering,
//                     polygonOptions: const PolygonOptions(
//                       borderColor: Colors.blueAccent,
//                       color: Color(0x33FFFFFF),
//                       borderStrokeWidth: 3,
//                     ),
//                     builder: (context, markers) {
//                       return _buildClusterMarker(markers);
//                     },
//                     onClusterTap: (node) {
//                       final markersInCluster = node.markers;
//
//                       showDialog(
//                         context: context,
//                         builder: (context) {
//                           return AlertDialog(
//                             title: Text('Cluster (${markersInCluster.length} markers)'),
//                             content: SizedBox(
//                               width: double.maxFinite,
//                               height: 300,
//                               child: ListView.builder(
//                                 itemCount: markersInCluster.length,
//                                 itemBuilder: (context, index) {
//                                   final marker = markersInCluster.elementAt(index);
//
//                                   // Find the corresponding _MarkerData
//                                   _MarkerData? markerData;
//                                   final allMarkers = [
//                                     ...(_geoJsonMarkers['combined_with_layers'] ?? []),
//                                     ...(_geoJsonMarkers['floor_$_currentFloor'] ?? []),
//                                   ];
//
//                                   for (final data in allMarkers) {
//                                     if (data.point == marker.point) {
//                                       markerData = data;
//                                       break;
//                                     }
//                                   }
//
//                                   final name = markerData?.properties['name'] ?? 'Unnamed';
//
//                                   return ListTile(
//                                     leading: const Icon(
//                                       Icons.location_on,
//                                       color: Colors.red,
//                                     ),
//                                     title: Text(name),
//                                     subtitle: Text(
//                                       'Lat: ${marker.point.latitude.toStringAsFixed(6)}, '
//                                           'Lng: ${marker.point.longitude.toStringAsFixed(6)}',
//                                     ),
//                                     onTap: () {
//                                       Navigator.of(context).pop();
//                                       _mapController.move(marker.point, 19);
//                                       if (markerData != null) {
//                                         _onMarkerTap(markerData);
//                                       }
//                                     },
//                                   );
//                                 },
//                               ),
//                             ),
//                             actions: [
//                               TextButton(
//                                 onPressed: () => Navigator.of(context).pop(),
//                                 child: const Text('Close'),
//                               ),
//                             ],
//                           );
//                         },
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//
//           // Floor Selector
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.black87,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(Icons.layers, color: Colors.white, size: 16),
//                       const SizedBox(width: 6),
//                       Text(
//                         _getFloorDisplayName(_currentFloor),
//                         style: const TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: DropdownButton<int>(
//                     value: _currentFloor,
//                     icon: const Icon(Icons.arrow_drop_down),
//                     underline: Container(),
//                     borderRadius: BorderRadius.circular(20),
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     items: _floors.map((floor) {
//                       return DropdownMenuItem<int>(
//                         value: floor,
//                         child: Row(
//                           children: [
//                             Icon(
//                               floor == -1 ? Icons.home_work : Icons.layers_outlined,
//                               size: 16,
//                               color: Colors.blue.shade800,
//                             ),
//                             const SizedBox(width: 8),
//                             Text(
//                               _getFloorDisplayName(floor),
//                               style: TextStyle(
//                                 color: Colors.blue.shade800,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     }).toList(),
//                     onChanged: (int? newFloor) {
//                       if (newFloor != null) {
//                         setState(() {
//                           _currentFloor = newFloor;
//                           // Clear selections when changing floors
//                           _selectedMarker = null;
//                           _selectedPolygonIndex = null;
//                           _selectedPolygonFloor = null;
//                         });
//                       }
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _mapController.move(LatLng(32.56497, 75.03575), 17);
//         },
//         backgroundColor: Colors.blue.shade800,
//         child: const Icon(Icons.my_location, color: Colors.white),
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIIMS Jammu Indoor Map',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const VectorTileMap(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum SelectionMode { normal, selectingSource, selectingDestination, selectingStop }

class _MarkerData {
  final LatLng point;
  final Map<String, dynamic> properties;
  _MarkerData({required this.point, required this.properties});
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


class _PolygonData {
  final List<LatLng> points;
  final Map<String, dynamic> properties;
  _PolygonData({required this.points, required this.properties});
}



class VectorTileMap extends StatefulWidget {
  const VectorTileMap({super.key});
  @override
  State<VectorTileMap> createState() => _VectorTileMapState();
}

class _VectorTileMapState extends State<VectorTileMap> {
  Theme? _theme;
  final MapController _mapController = MapController();
  int _currentFloor = 0;
  final List<int> _floors = [-1, 0, 1, 2, 3, 4, 5, 6];
  final Map<String, List<_MarkerData>> _geoJsonMarkers = {};
  final Map<String, List<_PolygonData>> _geoJsonPolygons = {};
  double _currentZoom = 17.0;

  _MarkerData? _selectedMarker;
  int? _selectedPolygonIndex;
  String? _selectedPolygonFloor;

  SelectionMode _selectionMode = SelectionMode.normal;
  _MarkerData? _sourceMarker;
  _MarkerData? _destinationMarker;
  List<_MarkerData> _stopMarkers = [];
  List<LatLng> _shortestPath = [];
  List<String> _shortestPathNodeKeys = [];
  double? _shortestDistance;
  double? _estimatedTime;
  Map<String, List<String>> _graphEdges = {};
  int _landmarksOnPath = 0;
  List<_MarkerData> _pathLandmarks = [];

  @override
  void initState() {
    super.initState();
    _loadStyle().then((_) => _loadGeoJsonMarkers());
    _loadGraphData();
  }

  int? _getFloorFromNodeKey(String nodeKey) {
    final parts = nodeKey.split(',');
    if (parts.length >= 3) return int.tryParse(parts[2]);
    return null;
  }

  void _clearPathResults() {
    setState(() {
      _shortestPath.clear();
      _shortestPathNodeKeys.clear();
      _shortestDistance = null;
      _estimatedTime = null;
      _landmarksOnPath = 0;
      _pathLandmarks = [];
    });
  }

  void _showNoPathDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Path Found'),
          content: const Text(
              'No valid path could be found for your selected points.\n\n'
                  'Please make a U-turn or select a different route.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadStyle() async {
    try {
      final style = await StyleReader(
        uri: 'http://10.194.22.156:8080/styles/aiims/style.json',
        logger: Logger.console(),
      ).read();
      setState(() {
        _theme = style.theme;
      });
      debugPrint('Style loaded successfully');
    } catch (e) {
      debugPrint('Error loading style: $e');
    }
  }

  Future<void> _loadGeoJsonMarkers() async {
    final List<String> keys = [
      'combined_with_layers',
      'floor_-1',
      'floor_0',
      'floor_1',
      'floor_2',
      'floor_3',
      'floor_4',
      'floor_5',
      'floor_6',
    ];

    for (final key in keys) {
      try {
        final String path = 'assets/$key.geojson';
        final String data = await rootBundle.loadString(path);
        final geojson = json.decode(data);

        List<_MarkerData> markers = [];
        List<_PolygonData> polygons = [];

        for (var feature in geojson['features']) {
          final geometry = feature['geometry'];
          final properties = feature['properties'] ?? {};
          final type = geometry['type'];

          if (type == 'Point') {
            final coords = geometry['coordinates'];
            final name = properties['name'] ?? 'Landmark';
            final pointType = properties['type'] ?? '';
            final element = properties['element'] ?? {};
            final subType = element['subType'] ?? '';

            if (key == 'combined_with_layers' && pointType == 'BP') continue;
            if (key == 'floor_0' && subType == 'AR') continue;
            if (subType == 'beacons') continue;

            markers.add(
              _MarkerData(point: LatLng(coords[1], coords[0]), properties: properties),
            );
          } else if (type == 'Polygon') {
            final coords = geometry['coordinates'][0] as List<dynamic>;
            final latLngs = coords.map<LatLng>((coord) {
              final lon = coord[0] as double;
              final lat = coord[1] as double;
              return LatLng(lat, lon);
            }).toList();

            polygons.add(
              _PolygonData(points: latLngs, properties: properties),
            );
          }
        }
        _geoJsonMarkers[key] = markers;
        _geoJsonPolygons[key] = polygons;
      } catch (e) {
        debugPrint('Failed to load $key.geojson: $e');
      }
    }
    setState(() {});
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

  TileProviders _getTileProviders() {
    return TileProviders({
      'combined_with_layers': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_-1': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_-1/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_0': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_0/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_1': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_1/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_2': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_2/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_3': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_3/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_4': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_4/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_5': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_5/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_6': NetworkVectorTileProvider(
        urlTemplate: 'http://10.194.22.156:8080/data/floor_6/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
    });
  }

  Theme _getFilteredTheme() {
    if (_theme == null) return Theme(id: 'filtered', version: '8', layers: []);
    final suffix = _currentFloor == -1 ? '_-1' : '_$_currentFloor';
    final filtered = _theme!.layers.where((layer) {
      if (layer.id == 'background' || layer.id.startsWith('combined_with_layers')) return true;
      return layer.id.startsWith('floor$suffix');
    }).toList();
    return Theme(id: 'filtered', version: '8', layers: filtered);
  }

  String _getFloorDisplayName(int floor) {
    switch (floor) {
      case -1: return 'Basement';
      case 0: return 'Ground Floor';
      default: return 'Floor $floor';
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    int intersectCount = 0;
    final double x = point.longitude;
    final double y = point.latitude;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  // --- Pathfinding logic ---

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

  bool _isPathValid(List<String> path) {
    for (int i = 0; i < path.length - 1; i++) {
      final node = path[i];
      final nextNode = path[i + 1];
      if (!_graphEdges.containsKey(node) || !_graphEdges[node]!.contains(nextNode)) {
        return false;
      }
    }
    return true;
  }

  ///here
  void _calculatePathWithStops() {
    if (_sourceMarker == null || _destinationMarker == null) return;

    if (_stopMarkers.isEmpty) {
      // Direct path from source to destination
      final startNode = _findClosestGraphNode(_sourceMarker!.point);
      final endNode = _findClosestGraphNode(_destinationMarker!.point);
      if (startNode == null || endNode == null) {
        _clearPathResults();
        _showNoPathDialog();
        return;
      }

      final path = _findShortestPath(startNode, endNode);
      if (path == null || path.isEmpty || !_isPathValid(path)) {
        _clearPathResults();
        _showNoPathDialog();
        return;
      }

      _updatePathResults(path);
      return;
    }

    // Find optimal order for visiting all stops
    final optimalOrder = _findOptimalStopOrder();
    final allPointsInOrder = [_sourceMarker!, ...optimalOrder, _destinationMarker!];

    List<String> fullPath = [];
    double totalDistance = 0.0;

    for (int i = 0; i < allPointsInOrder.length - 1; i++) {
      final startNode = _findClosestGraphNode(allPointsInOrder[i].point);
      final endNode = _findClosestGraphNode(allPointsInOrder[i + 1].point);
      if (startNode == null || endNode == null) {
        _clearPathResults();
        _showNoPathDialog();
        return;
      }

      final segment = _findShortestPath(startNode, endNode);
      if (segment == null || segment.isEmpty || !_isPathValid(segment)) {
        _clearPathResults();
        _showNoPathDialog();
        return;
      }

      // Remove duplicate node if not the first segment
      if (fullPath.isNotEmpty && segment.isNotEmpty) {
        segment.removeAt(0);
      }
      fullPath.addAll(segment);
    }

    _updatePathResults(fullPath);
  }

  List<_MarkerData> _findOptimalStopOrder() {
    if (_stopMarkers.length <= 1) return List.from(_stopMarkers);

    // For small number of stops (≤ 8), use brute force for optimal solution
    if (_stopMarkers.length <= 8) {
      return _findOptimalOrderBruteForce();
    }

    // For larger sets, use nearest neighbor heuristic
    return _findOptimalOrderNearestNeighbor();
  }

  List<_MarkerData> _findOptimalOrderBruteForce() {
    final stops = List<_MarkerData>.from(_stopMarkers);
    final allPermutations = _generatePermutations(stops);

    double shortestDistance = double.infinity;
    List<_MarkerData> bestOrder = stops;

    for (final permutation in allPermutations) {
      final totalDistance = _calculateTotalPathDistance([_sourceMarker!, ...permutation, _destinationMarker!]);
      if (totalDistance < shortestDistance) {
        shortestDistance = totalDistance;
        bestOrder = permutation;
      }
    }

    return bestOrder;
  }

  List<_MarkerData> _findOptimalOrderNearestNeighbor() {
    final unvisited = Set<_MarkerData>.from(_stopMarkers);
    final orderedStops = <_MarkerData>[];
    _MarkerData currentLocation = _sourceMarker!;

    while (unvisited.isNotEmpty) {
      _MarkerData? nearest;
      double shortestDistance = double.infinity;

      for (final stop in unvisited) {
        final distance = _calculateDirectDistance(currentLocation.point, stop.point);
        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = stop;
        }
      }

      if (nearest != null) {
        orderedStops.add(nearest);
        unvisited.remove(nearest);
        currentLocation = nearest;
      }
    }

    return orderedStops;
  }

// Generate all permutations of a list
  List<List<_MarkerData>> _generatePermutations(List<_MarkerData> items) {
    if (items.length <= 1) return [items];

    final result = <List<_MarkerData>>[];

    for (int i = 0; i < items.length; i++) {
      final current = items[i];
      final remaining = [...items.sublist(0, i), ...items.sublist(i + 1)];
      final perms = _generatePermutations(remaining);

      for (final perm in perms) {
        result.add([current, ...perm]);
      }
    }

    return result;
  }

// Calculate total distance for a complete path including all waypoints
  double _calculateTotalPathDistance(List<_MarkerData> waypoints) {
    double totalDistance = 0.0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final startNode = _findClosestGraphNode(waypoints[i].point);
      final endNode = _findClosestGraphNode(waypoints[i + 1].point);

      if (startNode != null && endNode != null) {
        final path = _findShortestPath(startNode, endNode);
        if (path != null && path.isNotEmpty) {
          totalDistance += _calculatePathDistance(path);
        }
      }
    }

    return totalDistance;
  }

// Calculate distance for a path of node keys
  double _calculatePathDistance(List<String> pathNodes) {
    double distance = 0.0;

    for (int i = 0; i < pathNodes.length - 1; i++) {
      final point1 = _nodeKeyToLatLng(pathNodes[i]);
      final point2 = _nodeKeyToLatLng(pathNodes[i + 1]);

      if (point1 != null && point2 != null) {
        distance += _calculateDistance(point1, point2);
      }
    }

    return distance;
  }

// Direct distance calculation (as the crow flies)
  double _calculateDirectDistance(LatLng point1, LatLng point2) {
    return _calculateDistance(point1, point2);
  }

// Helper method to update path results
  void _updatePathResults(List<String> fullPath) {
    List<LatLng> pathPoints = [];
    double totalDistance = 0.0;

    for (int i = 0; i < fullPath.length; i++) {
      final point = _nodeKeyToLatLng(fullPath[i]);
      if (point != null) {
        pathPoints.add(point);
        if (i > 0) {
          totalDistance += _calculateDistance(pathPoints[i - 1], pathPoints[i]);
        }
      }
    }

    final estimatedTimeSeconds = totalDistance / 1.4;

    setState(() {
      _shortestPath = pathPoints;
      _shortestPathNodeKeys = fullPath;
      _shortestDistance = totalDistance;
      _estimatedTime = estimatedTimeSeconds;
    });

    _countLandmarksOnPath();

    final stopCount = _stopMarkers.length;
    final stopText = stopCount > 0 ? ' via $stopCount stop${stopCount > 1 ? 's' : ''}' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Optimized path found$stopText: ${totalDistance.toStringAsFixed(1)} m (${_formatTime(estimatedTimeSeconds)}) - $_landmarksOnPath landmarks'
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showStopOrderDialog() {
    if (_stopMarkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stops added to show order')),
      );
      return;
    }

    final optimalOrder = _stopMarkers.length <= 8
        ? _findOptimalOrderBruteForce()
        : _findOptimalOrderNearestNeighbor();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Optimized Stop Order (${_stopMarkers.length} stops)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stopMarkers.length <= 8
                      ? 'Using optimal solution (exact)'
                      : 'Using nearest neighbor heuristic (approximation)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: optimalOrder.length + 2, // +2 for source and destination
                    itemBuilder: (context, index) {
                      IconData icon;
                      String title;
                      Color color;

                      if (index == 0) {
                        icon = Icons.play_arrow;
                        title = 'Source: ${_sourceMarker?.properties['name'] ?? 'Unnamed'}';
                        color = Colors.green;
                      } else if (index == optimalOrder.length + 1) {
                        icon = Icons.stop;
                        title = 'Destination: ${_destinationMarker?.properties['name'] ?? 'Unnamed'}';
                        color = Colors.blue;
                      } else {
                        icon = Icons.radio_button_checked;
                        title = 'Stop ${index}: ${optimalOrder[index - 1].properties['name'] ?? 'Unnamed'}';
                        color = Colors.purple;
                      }

                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(
                          title,
                          style: TextStyle(color: color, fontWeight: FontWeight.w500),
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
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

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c * 1000;
  }

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

  List<String>? _findShortestPath(String startNode, String endNode) {
    if (!_graphEdges.containsKey(startNode) || !_graphEdges.containsKey(endNode)) return null;
    Map<String, double> distances = {};
    Map<String, String?> previous = {};
    Set<String> unvisited = {};
    for (String node in _graphEdges.keys) {
      distances[node] = double.infinity;
      previous[node] = null;
      unvisited.add(node);
    }
    distances[startNode] = 0;
    while (unvisited.isNotEmpty) {
      String currentNode = unvisited.reduce((a, b) => distances[a]! < distances[b]! ? a : b);
      if (distances[currentNode] == double.infinity) break;
      unvisited.remove(currentNode);
      if (currentNode == endNode) break;
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
    List<String> path = [];
    String? currentNode = endNode;
    while (currentNode != null) {
      path.insert(0, currentNode);
      currentNode = previous[currentNode];
    }
    return path.isNotEmpty && path.first == startNode ? path : null;
  }

  void _countLandmarksOnPath() {
    final allMarkers = [
      ...(_geoJsonMarkers['combined_with_layers'] ?? []),
      ...(_geoJsonMarkers['floor_$_currentFloor'] ?? []),
    ];
    if (_shortestPath.isEmpty) {
      setState(() {
        _landmarksOnPath = 0;
        _pathLandmarks = [];
      });
      return;
    }
    List<_MarkerData> landmarksOnPath = [];
    const double proximityThreshold = 50.0;
    for (_MarkerData marker in allMarkers) {
      if (marker == _sourceMarker || marker == _destinationMarker) continue;
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
  }

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

  // --- UI and selection logic ---

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
      if (_destinationMarker != null) _calculatePathWithStops();
    } else if (_selectionMode == SelectionMode.selectingDestination) {
      setState(() {
        _destinationMarker = markerData;
        _selectionMode = SelectionMode.normal;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destination selected: ${markerData.properties['name'] ?? 'Unnamed'}')),
      );
      if (_sourceMarker != null) _calculatePathWithStops();
    } else if (_selectionMode == SelectionMode.selectingStop) {
      setState(() {
        if (!_stopMarkers.contains(markerData) &&
            markerData != _sourceMarker &&
            markerData != _destinationMarker) {
          _stopMarkers.add(markerData);
        }
        _selectionMode = SelectionMode.normal;
        _shortestPath.clear();
        _shortestDistance = null;
        _estimatedTime = null;
        _landmarksOnPath = 0;
        _pathLandmarks = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop added: ${markerData.properties['name'] ?? 'Unnamed'}')),
      );
      if (_sourceMarker != null && _destinationMarker != null) _calculatePathWithStops();
    } else {
      setState(() {
        _selectedMarker = markerData;
        _selectedPolygonIndex = null;
        _selectedPolygonFloor = null;
      });
      debugPrint('Selected Marker Properties: ${markerData.properties}');
    }
  }

  void _onPolygonTap(int polygonIndex, String floorKey, _PolygonData polygonData) {
    setState(() {
      _selectedPolygonIndex = polygonIndex;
      _selectedPolygonFloor = floorKey;
      _selectedMarker = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected Polygon: ${polygonData.properties['name'] ?? 'Unnamed Area'}'),
        duration: const Duration(seconds: 2),
      ),
    );
    debugPrint('Selected Polygon Properties: ${polygonData.properties}');
  }

  void _showMarkerSelectionDialog({bool? isSource}) {
    final allMarkers = <_MarkerData>[
      ...(_geoJsonMarkers['combined_with_layers'] ?? []),
      ..._floors.expand((floor) => _geoJsonMarkers['floor_$floor'] ?? []),
    ];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select ${isSource == true ? 'Source' : isSource == false ? 'Destination' : 'Stop'}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: allMarkers.length,
              itemBuilder: (context, index) {
                final marker = allMarkers[index];
                final name = marker.properties['name'] ?? 'Unnamed Location';
                final floor = marker.properties['floor'] ?? 'N/A';
                final isSelected = isSource == true
                    ? (_sourceMarker == marker)
                    : isSource == false
                    ? (_destinationMarker == marker)
                    : _stopMarkers.contains(marker);
                Color color = Colors.grey;
                if (isSelected) {
                  color = isSource == true
                      ? Colors.green
                      : isSource == false
                      ? Colors.blue
                      : Colors.purple;
                }
                return ListTile(
                  leading: Icon(Icons.location_on, color: color),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: color,
                    ),
                  ),
                  subtitle: Text(
                    'Floor: $floor | Lat: ${marker.point.latitude.toStringAsFixed(4)}, Lng: ${marker.point.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: color) : null,
                  onTap: () {
                    setState(() {
                      if (isSource == true) {
                        _sourceMarker = marker;
                      } else if (isSource == false) {
                        _destinationMarker = marker;
                      } else {
                        if (!_stopMarkers.contains(marker) &&
                            marker != _sourceMarker &&
                            marker != _destinationMarker) {
                          _stopMarkers.add(marker);
                        }
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
                        content: Text(
                            '${isSource == true ? 'Source' : isSource == false ? 'Destination' : 'Stop'} selected: $name'),
                        backgroundColor: color,
                      ),
                    );
                    if (_sourceMarker != null && _destinationMarker != null) {
                      _calculatePathWithStops();
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

  void _showSelectionOptionsDialog({bool? isSource}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select ${isSource == true ? 'Source' : isSource == false ? 'Destination' : 'Stop'} From'),
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
                    _selectionMode = isSource == true
                        ? SelectionMode.selectingSource
                        : isSource == false
                        ? SelectionMode.selectingDestination
                        : SelectionMode.selectingStop;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tap a marker on the map to select as ${isSource == true ? 'source' : isSource == false ? 'destination' : 'stop'}'),
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
          title: Text('Landmarks on Path ($_landmarksOnPath)'),
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
    } else if (_stopMarkers.contains(markerData)) {
      markerColor = Colors.purple;
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
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
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

  // Replace your existing _buildControlPanel method with this updated version

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

          // First row of buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSelectionOptionsDialog(isSource: true),
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                  label: const Text('Source', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSelectionOptionsDialog(isSource: false),
                  icon: const Icon(Icons.stop, color: Colors.white, size: 16),
                  label: const Text('Dest', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSelectionOptionsDialog(isSource: null),
                  icon: const Icon(Icons.add_location_alt, color: Colors.white, size: 16),
                  label: const Text('Add Stop', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sourceMarker = null;
                      _destinationMarker = null;
                      _stopMarkers.clear();
                      _shortestPath.clear();
                      _shortestPathNodeKeys.clear();
                      _shortestDistance = null;
                      _estimatedTime = null;
                      _landmarksOnPath = 0;
                      _pathLandmarks = [];
                      _selectionMode = SelectionMode.normal;
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.white, size: 16),
                  label: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          // Second row of buttons (if there are stops)
          if (_stopMarkers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showStopOrderDialog,
                    icon: const Icon(Icons.route, color: Colors.white, size: 16),
                    label: const Text('Stop Order', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_landmarksOnPath > 0)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showLandmarksDialog,
                      icon: const Icon(Icons.place, color: Colors.white, size: 16),
                      label: Text('Landmarks ($_landmarksOnPath)', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Status information
          if (_sourceMarker != null || _destinationMarker != null || _stopMarkers.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_sourceMarker != null)
              Text(
                'Source: ${_sourceMarker!.properties['name'] ?? 'Unnamed'}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            if (_stopMarkers.isNotEmpty)
              Text(
                'Stops: ${_stopMarkers.length} location${_stopMarkers.length > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            if (_destinationMarker != null)
              Text(
                'Destination: ${_destinationMarker!.properties['name'] ?? 'Unnamed'}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            if (_shortestDistance != null)
              Text(
                'Distance: ${_shortestDistance!.toStringAsFixed(1)} m',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            if (_estimatedTime != null)
              Text(
                'Estimated Time: ${_formatTime(_estimatedTime!)}',
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            if (_landmarksOnPath > 0 && _stopMarkers.isEmpty)
              GestureDetector(
                onTap: _showLandmarksDialog,
                child: Text(
                  'Landmarks: $_landmarksOnPath (tap to view)',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],

          // Individual stop management
          if (_stopMarkers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _stopMarkers.length,
                itemBuilder: (context, index) {
                  final stop = _stopMarkers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Stop ${index + 1}: ${stop.properties['name'] ?? 'Unnamed'}',
                            style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w400, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                          tooltip: 'Remove Stop',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () {
                            setState(() {
                              _stopMarkers.remove(stop);
                              if (_sourceMarker != null && _destinationMarker != null) {
                                _calculatePathWithStops();
                              } else {
                                _shortestPath.clear();
                                _shortestDistance = null;
                                _estimatedTime = null;
                                _landmarksOnPath = 0;
                                _pathLandmarks = [];
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_theme == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading AIIMS Map Style...'),
            ],
          ),
        ),
      );
    }

    final markersForClustering = <Marker>[];
    if (_currentZoom >= 15.0) {
      final combinedMarkers = _geoJsonMarkers['combined_with_layers'] ?? [];
      final floorMarkers = _geoJsonMarkers['floor_$_currentFloor'] ?? [];
      for (final markerData in [...combinedMarkers, ...floorMarkers]) {
        final isSelected = _selectedMarker == markerData;
        markersForClustering.add(
          Marker(
            width: 120,
            height: 80,
            point: markerData.point,
            child: GestureDetector(
              onTap: () => _onMarkerTap(markerData),
              child: _buildMarker(markerData, isSelected),
            ),
          ),
        );
      }
    }

    final currentFloorKey = 'floor_$_currentFloor';
    final floorPolygons = _geoJsonPolygons[currentFloorKey] ?? [];
    final combinedPolygons = _geoJsonPolygons['combined_with_layers'] ?? [];

    List<LatLng> pathForCurrentFloor = [];
    if (_shortestPathNodeKeys.isNotEmpty) {
      for (int i = 0; i < _shortestPathNodeKeys.length - 1; i++) {
        final floor1 = _getFloorFromNodeKey(_shortestPathNodeKeys[i]);
        final floor2 = _getFloorFromNodeKey(_shortestPathNodeKeys[i + 1]);
        if (floor1 == _currentFloor && floor2 == _currentFloor) {
          pathForCurrentFloor.add(_shortestPath[i]);
          pathForCurrentFloor.add(_shortestPath[i + 1]);
        }
      }
      pathForCurrentFloor = pathForCurrentFloor.toSet().toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("AIIMS Jammu Indoor Map"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(32.56497, 75.03575),
              initialZoom: 17,
              minZoom: 10,
              maxZoom: 21,
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              },
              onTap: (tapPosition, point) {
                if (_selectionMode != SelectionMode.normal) return;
                bool polygonTapped = false;
                final combinedPolygons = _geoJsonPolygons['combined_with_layers'] ?? [];
                for (int i = 0; i < combinedPolygons.length; i++) {
                  if (_isPointInPolygon(point, combinedPolygons[i].points)) {
                    _onPolygonTap(i, 'combined_with_layers', combinedPolygons[i]);
                    polygonTapped = true;
                    break;
                  }
                }
                if (!polygonTapped) {
                  final floorPolygons = _geoJsonPolygons[currentFloorKey] ?? [];
                  for (int i = 0; i < floorPolygons.length; i++) {
                    if (_isPointInPolygon(point, floorPolygons[i].points)) {
                      _onPolygonTap(i, currentFloorKey, floorPolygons[i]);
                      polygonTapped = true;
                      break;
                    }
                  }
                }
                if (!polygonTapped) {
                  setState(() {
                    _selectedPolygonIndex = null;
                    _selectedPolygonFloor = null;
                    _selectedMarker = null;
                  });
                }
              },
            ),
            children: [
              VectorTileLayer(
                key: Key('floor_$_currentFloor'),
                theme: _getFilteredTheme(),
                tileProviders: _getTileProviders(),
                layerMode: VectorTileLayerMode.vector,
              ),

              if (pathForCurrentFloor.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pathForCurrentFloor,
                      strokeWidth: 4.0,
                      color: Colors.red,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              if (combinedPolygons.isNotEmpty || floorPolygons.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    ...combinedPolygons.asMap().entries.where((entry) {
                      final index = entry.key;
                      return index == _selectedPolygonIndex &&
                          'combined_with_layers' == _selectedPolygonFloor;
                    }).map((entry) {
                      final polyData = entry.value;
                      return Polygon(
                        points: polyData.points,
                        color: Colors.yellow.withOpacity(0.4),
                        borderColor: Colors.red,
                        borderStrokeWidth: 3.0,
                        isFilled: true,
                      );
                    }),
                    ...floorPolygons.asMap().entries.where((entry) {
                      final index = entry.key;
                      return index == _selectedPolygonIndex &&
                          currentFloorKey == _selectedPolygonFloor;
                    }).map((entry) {
                      final polyData = entry.value;
                      return Polygon(
                        points: polyData.points,
                        color: Colors.yellow.withOpacity(0.4),
                        borderColor: Colors.red,
                        borderStrokeWidth: 3.0,
                        isFilled: true,
                      );
                    }),
                  ],
                ),
              if (markersForClustering.isNotEmpty)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(35, 35),
                    markers: markersForClustering,
                    polygonOptions: const PolygonOptions(
                      borderColor: Colors.blueAccent,
                      color: Color(0x33FFFFFF),
                      borderStrokeWidth: 3,
                    ),
                    builder: (context, markers) {
                      return Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildControlPanel(),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _getFloorDisplayName(_currentFloor),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButton<int>(
                    value: _currentFloor,
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: Container(),
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    items: _floors.map((floor) {
                      return DropdownMenuItem<int>(
                        value: floor,
                        child: Row(
                          children: [
                            Icon(
                              floor == -1 ? Icons.home_work : Icons.layers_outlined,
                              size: 16,
                              color: Colors.blue.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getFloorDisplayName(floor),
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (int? newFloor) {
                      if (newFloor != null) {
                        setState(() {
                          _currentFloor = newFloor;
                          _selectedMarker = null;
                          _selectedPolygonIndex = null;
                          _selectedPolygonFloor = null;
                          _selectionMode = SelectionMode.normal;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
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
                      : _selectionMode == SelectionMode.selectingDestination
                      ? Colors.blue.withOpacity(0.9)
                      : Colors.purple.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectionMode == SelectionMode.selectingSource
                      ? 'Tap a marker to select as SOURCE'
                      : _selectionMode == SelectionMode.selectingDestination
                      ? 'Tap a marker to select as DESTINATION'
                      : 'Tap a marker to add as STOP',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(LatLng(32.56497, 75.03575), 17);
        },
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
