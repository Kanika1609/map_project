// import 'package:flutter/material.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
//
// // Paste your Mapbox access token here
// const String mapboxAccessToken = 'pk.eyJ1IjoiaXdheXBsdXMiLCJhIjoiY2xlanhwaW5nMGZ0aDN4cGRmaDZpemNwZiJ9.CkW1qt9oR5UC7S4NjWsrdA';
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   MapboxOptions.setAccessToken(mapboxAccessToken);
//   runApp(const MaterialApp(home: MapPage()));
// }
//
// class MapPage extends StatefulWidget {
//   const MapPage({super.key});
//
//   @override
//   State<MapPage> createState() => _MapPageState();
// }
//
// class _MapPageState extends State<MapPage> {
//   MapboxMap? _mapboxMap;
//   bool _isStyleLoaded = false;
//
//   @override
//   void dispose() {
//     _mapboxMap = null;
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AIIMS Jammu Map'),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           MapWidget(
//             key: const ValueKey("mapWidget"),
//             styleUri: 'http://10.194.2.53:8080/styles/aiims/style.json',
//             onMapCreated: _onMapCreated,
//             onStyleLoadedListener: _onStyleLoaded,
//           ),
//
//           if (!_isStyleLoaded)
//             const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 16),
//                   Text('Loading map style...'),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   void _onMapCreated(MapboxMap mapboxMap) {
//     _mapboxMap = mapboxMap;
//
//     _mapboxMap!.setCamera(CameraOptions(
//       center: Point(coordinates: Position(75.0321, 32.5645)),
//       zoom: 18.0,
//     ));
//
//     debugPrint('Map created');
//   }
//
//   void _onStyleLoaded(StyleLoadedEventData data) {
//     setState(() {
//       _isStyleLoaded = true;
//     });
//
//     debugPrint('Style loaded');
//
//     // Optional: list available layers for debugging
//     Future.delayed(const Duration(milliseconds: 300), () {
//       // _listAvailableLayers();
//     });
//   }
//
//   void _listAvailableLayers() async {
//     if (_mapboxMap == null) return;
//
//     final layerIds = [
//       'background',
//       'combined_with_layers-fill',
//       'combined_with_layers-line',
//     ];
//
//     for (final layerId in layerIds) {
//       try {
//         await _mapboxMap!.style.getStyleLayerProperty(layerId, 'visibility');
//         debugPrint('Layer found: $layerId');
//       } catch (e) {
//         debugPrint('Layer not found: $layerId');
//       }
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
//
// // Paste your Mapbox access token here
// const String mapboxAccessToken = 'pk.eyJ1IjoiaXdheXBsdXMiLCJhIjoiY2xlanhwaW5nMGZ0aDN4cGRmaDZpemNwZiJ9.CkW1qt9oR5UC7S4NjWsrdA';
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   MapboxOptions.setAccessToken(mapboxAccessToken);
//   runApp(const MaterialApp(home: MapPage()));
// }
//
// class MapPage extends StatefulWidget {
//   const MapPage({super.key});
//
//   @override
//   State<MapPage> createState() => _MapPageState();
// }
//
// class _MapPageState extends State<MapPage> {
//   MapboxMap? _mapboxMap;
//   bool _isStyleLoaded = false;
//   String _selectedFloor = 'floor_0';
//
//   final List<String> _floorIds = [
//     'floor_-1',
//     'floor_0',
//     'floor_1',
//     'floor_2',
//     'floor_3',
//     'floor_4',
//     'floor_5',
//     'floor_6',
//   ];
//
//   final Map<String, String> _floorLabels = {
//     'floor_-1': 'Floor -1',
//     'floor_0': 'Ground Floor',
//     'floor_1': 'Floor 1',
//     'floor_2': 'Floor 2',
//     'floor_3': 'Floor 3',
//     'floor_4': 'Floor 4',
//     'floor_5': 'Floor 5',
//     'floor_6': 'Floor 6',
//   };
//
//   @override
//   void dispose() {
//     _mapboxMap = null;
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AIIMS Jammu Indoor Map'),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           MapWidget(
//             key: const ValueKey("mapWidget"),
//             // Use a fallback style if your custom style is not accessible
//             styleUri: 'http://10.194.6.154:8080/styles/aiims/style.json',
//             // Alternative fallback: MapboxStyles.MAPBOX_STREETS,
//             onMapCreated: _onMapCreated,
//             onStyleLoadedListener: _onStyleLoaded,
//           ),
//           if (!_isStyleLoaded)
//             const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 16),
//                   Text('Loading map style...'),
//                 ],
//               ),
//             ),
//           if (_isStyleLoaded)
//             Positioned(
//               top: 16,
//               right: 16,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.2),
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: DropdownButton<String>(
//                   value: _selectedFloor,
//                   underline: Container(),
//                   items: _floorIds
//                       .map((floor) => DropdownMenuItem(
//                     value: floor,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       child: Text(_floorLabels[floor] ?? floor),
//                     ),
//                   ))
//                       .toList(),
//                   onChanged: (value) {
//                     if (value != null) {
//                       setState(() => _selectedFloor = value);
//                       _updateVisibleFloor(value);
//                     }
//                   },
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   void _onMapCreated(MapboxMap mapboxMap) {
//     _mapboxMap = mapboxMap;
//
//     // Set initial camera position for AIIMS Jammu
//     _mapboxMap!.setCamera(CameraOptions(
//       center: Point(coordinates: Position(75.0321, 32.5645)),
//       zoom: 18.0,
//     ));
//
//     debugPrint('Map created');
//   }
//
//   void _onStyleLoaded(StyleLoadedEventData data) {
//     setState(() {
//       _isStyleLoaded = true;
//     });
//
//     debugPrint('Style loaded successfully');
//
//     // Wait a bit for the style to fully initialize, then set initial floor
//     Future.delayed(const Duration(milliseconds: 500), () {
//       _updateVisibleFloor(_selectedFloor);
//     });
//   }
//
//   void _updateVisibleFloor(String selectedFloor) async {
//     if (_mapboxMap == null || !_isStyleLoaded) {
//       debugPrint('Map or style not ready yet');
//       return;
//     }
//
//     debugPrint('Updating visible floor to: $selectedFloor');
//
//     for (String floor in _floorIds) {
//       // Each floor has two layers: rooms and outlines
//       String roomsLayerId = '${floor}-rooms';
//       String outlinesLayerId = '${floor}-outlines';
//
//       String visibility = floor == selectedFloor ? 'visible' : 'none';
//
//       try {
//         // Update rooms layer
//         await _mapboxMap!.style.setStyleLayerProperty(
//           roomsLayerId,
//           'visibility',
//           visibility,
//         );
//         debugPrint('Updated $roomsLayerId visibility to $visibility');
//
//         // Update outlines layer
//         await _mapboxMap!.style.setStyleLayerProperty(
//           outlinesLayerId,
//           'visibility',
//           visibility,
//         );
//         debugPrint('Updated $outlinesLayerId visibility to $visibility');
//
//       } catch (e) {
//         debugPrint('Failed to update layer visibility for $floor: $e');
//       }
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// import 'dart:convert' show json;
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Mapbox Terrain App',
//       home: MyMapScreen(),
//     );
//   }
// }
//
// class MyMapScreen extends StatefulWidget {
//   @override
//   _MyMapScreenState createState() => _MyMapScreenState();
// }
//
// class _MyMapScreenState extends State<MyMapScreen> {
//   MapboxMap? myMap;
//
//   // Put your Mapbox access token here
//   final String accessToken = "pk.eyJ1IjoiaXdheXBsdXMiLCJhIjoiY2xlanhwaW5nMGZ0aDN4cGRmaDZpemNwZiJ9.CkW1qt9oR5UC7S4NjWsrdA";
//
//   @override
//   void initState() {
//     super.initState();
//     // Set the access token
//     MapboxOptions.setAccessToken(accessToken);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Terrain Map')),
//       body: MapWidget(
//         key: ValueKey("mapWidget"),
//         cameraOptions: CameraOptions(
//           center: Point(coordinates: Position(-122.4194, 37.7749)),
//           zoom: 12.0,
//           pitch: 45.0, // This shows 3D effect
//         ),
//         styleUri: MapboxStyles.OUTDOORS, // Good style for terrain
//         textureView: true,
//         onMapCreated: (MapboxMap map) {
//           myMap = map;
//           addTerrain();
//         },
//       ),
//     );
//   }
//
//   void addTerrain() async {
//     await Future.delayed(Duration(seconds: 2));
//
//     try {
//       // Add terrain source
//       var terrainSource = {
//         "type": "raster-dem",
//         "url": "mapbox://mapbox.terrain-rgb",
//         "tileSize": 514
//       };
//
//       await myMap?.style.addStyleSource("terrain-source", json.encode(terrainSource));
//
//       // Set terrain
//       await myMap?.style.setStyleTerrain(json.encode({
//         "source": "terrain-source",
//         "exaggeration": 1.5
//       }));
//
//       print("Terrain added successfully!");
//
//     } catch (e) {
//       print("Error adding terrain: $e");
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'zoo_map_page.dart';

// Put your actual Mapbox token here
const String mapboxAccessToken = 'pk.eyJ1IjoiaXdheXBsdXMiLCJhIjoiY2xlanhwaW5nMGZ0aDN4cGRmaDZpemNwZiJ9.CkW1qt9oR5UC7S4NjWsrdA';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxAccessToken);
  runApp(const MaterialApp(home: ZooMapPage()));
}